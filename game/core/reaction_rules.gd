# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os numeros vem dos ReactionDef.
## Reacoes elementais (M14). Sem Node nem IO. Unico consumo de Dice: as chances de estado da reacao
## (so quando ela acontece). O dano da reacao nao passa de novo pela afinidade e nao marca (sem cadeia).
class_name ReactionRules
extends RefCounted

## Reacao do par nao ordenado (x, y) na tabela, ou null. Compara por id de elemento.
static func find(table: ReactionTable, x: ElementDef, y: ElementDef) -> ReactionDef:
	if table == null or x == null or y == null:
		return null
	for d: ReactionDef in table.reactions:
		if d != null and _is_pair(d, x, y):
			return d
	return null

static func _is_pair(d: ReactionDef, x: ElementDef, y: ElementDef) -> bool:
	if d.a == null or d.b == null:
		return false
	return (d.a.id == x.id and d.b.id == y.id) or (d.a.id == y.id and d.b.id == x.id)

## Erros de dados da tabela contra a lista de elementos (vazio = ok): par repetido, elemento nulo ou igual no par,
## elemento que nao reage, `keep` fora do par e par faltando entre os elementos que reagem.
static func errors(table: ReactionTable, elements: Array[ElementDef]) -> Array[String]:
	var errs: Array[String] = []
	var seen: Dictionary = {}
	for i: int in table.reactions.size():
		var d: ReactionDef = table.reactions[i]
		var label: String = String(d.id) if d != null and d.id != &"" else "#%d" % i
		if d == null or d.a == null or d.b == null:
			errs.append("reacao %s: elemento nulo" % label)
			continue
		if d.a.id == d.b.id:
			errs.append("reacao %s: par com o mesmo elemento (%s)" % [label, d.a.id])
			continue
		if not d.a.reacts:
			errs.append("reacao %s: %s nao reage" % [label, d.a.id])
		if not d.b.reacts:
			errs.append("reacao %s: %s nao reage" % [label, d.b.id])
		var key: String = _key(d.a, d.b)
		if seen.has(key):
			errs.append("reacao %s: par repetido (%s)" % [label, key])
		seen[key] = true
		if d.keep != null and d.keep.id != d.a.id and d.keep.id != d.b.id:
			errs.append("reacao %s: keep fora do par (%s)" % [label, d.keep.id])
	var reacting: Array[ElementDef] = []
	for e: ElementDef in elements:
		if e != null and e.reacts:
			reacting.append(e)
	for i: int in reacting.size():
		for j: int in range(i + 1, reacting.size()):
			if not seen.has(_key(reacting[i], reacting[j])):
				errs.append("par faltando: %s + %s" % [reacting[i].id, reacting[j].id])
	return errs

static func _key(x: ElementDef, y: ElementDef) -> String:
	var ids: Array[String] = [String(x.id), String(y.id)]
	ids.sort()
	return "%s+%s" % [ids[0], ids[1]]

## Aplica `def` depois do golpe completo (o chamador ja checou que ha marca de outro elemento, que o novo golpe
## marcaria e que `t` ainda esta de pe). `base` e o dano final do golpe (antes da barreira). Ordem: dano extra,
## area, estados do alvo, ATB, estados do atacante, curas, remocao de estados, consumo da marca.
## Se o dano extra derruba `t`, os passos que so servem ao alvo (estados, ATB, remocao, marca) sao pulados.
## `defer_attacker_atb`: o ATB do atacante vai para `atb_bonus` (a barra dele zera no fim da acao).
## Devolve `reaction_effects` para a UI; a chave "downed" lista quem caiu pela area (o chamador trata).
static func apply(def: ReactionDef, actor: Combatant, t: Combatant, base: int, b: BattleState, credit: StringName, defer_attacker_atb: bool) -> Dictionary:
	var fx: Dictionary = {"extra_damage": 0, "area": [], "statuses": [], "atb": {"target": 0.0, "attacker": 0.0}, "heal_attacker": 0, "heal_allies": [], "removed": 0, "downed": []}
	var enemies_alive: Array[Combatant] = b.living(b.enemies)
	# 1. dano extra: a barreira absorve o que sobrou dela.
	var extra: int = floori(float(base) * def.bonus_pct)
	if extra > 0:
		fx["extra_damage"] = ActionExecutor.deal_damage(actor, t, extra, b, credit)
	# 2. area: neutra, sem marca e sem reacao; so os outros aliados do alvo dentro do raio.
	if def.area_radius > 0.0 and (def.area_pct > 0.0 or not def.area_statuses.is_empty()):
		var victims: Array[Combatant] = []
		for o: Combatant in b.allies_of(t):
			if o != t and not o.is_down() and o.position.distance_to(t.position) <= def.area_radius:
				victims.append(o)
		var area_dmg: int = floori(float(base) * def.area_pct)
		for o: Combatant in victims:
			var dealt: int = 0
			if area_dmg > 0:
				dealt = ActionExecutor.deal_damage(actor, o, area_dmg, b, credit)
			(fx["area"] as Array).append({"target_id": o.id, "amount": dealt})
			if o.is_down():
				(fx["downed"] as Array).append(o)
				continue
			for s: StatusDef in def.area_statuses:
				_status(fx, actor, o, s, def.status_chance, b, enemies_alive)
	var t_up: bool = not t.is_down()
	# 3. estados do alvo.
	if t_up:
		for s: StatusDef in def.target_statuses:
			_status(fx, actor, t, s, def.status_chance, b, enemies_alive)
	# 4. ATB.
	if t_up and def.target_atb != 0.0:
		fx["atb"]["target"] = shift_atb(t, def.target_atb, b)
	if def.attacker_atb != 0.0 and not actor.is_down():
		if defer_attacker_atb:
			actor.atb_bonus += def.attacker_atb
			fx["atb"]["attacker"] = def.attacker_atb
		else:
			fx["atb"]["attacker"] = shift_atb(actor, def.attacker_atb, b)
	# 5. estados do atacante: sem sorteio.
	if not actor.is_down():
		for s: StatusDef in def.attacker_statuses:
			var res: int = b.statuses.apply_forced(actor, s)
			(fx["statuses"] as Array).append({"target_id": actor.id, "status_id": s.id, "result": res})
	# 6. curas: pelo teto normal, sem contribuicao.
	if def.heal_attacker_pct > 0.0 and not actor.is_down():
		fx["heal_attacker"] = ActionExecutor.restore(floori(float(base) * def.heal_attacker_pct), actor, b)
	if def.heal_allies_pct > 0.0:
		var each: int = floori(float(base) * def.heal_allies_pct)
		for o: Combatant in b.allies_of(actor):
			if o.is_down():
				continue
			var healed: int = ActionExecutor.restore(each, o, b)
			(fx["heal_allies"] as Array).append({"target_id": o.id, "amount": healed})
	# 7. remocao de estados do alvo.
	if t_up and not def.remove_target_statuses.is_empty():
		fx["removed"] = b.statuses.remove_many(t, def.remove_target_statuses)
	# 8. consumo: a marca vira `keep` (renovada) ou some.
	if t_up:
		if def.keep != null:
			MarkRules.set_mark(t, def.keep, b.cfg.mark_turns)
		else:
			MarkRules.clear(t)
	return fx

static func _status(fx: Dictionary, actor: Combatant, t: Combatant, s: StatusDef, chance: float, b: BattleState, enemies_alive: Array[Combatant]) -> void:
	var res: int = b.statuses.apply(t, s, actor, chance, enemies_alive)
	(fx["statuses"] as Array).append({"target_id": t.id, "status_id": s.id, "result": res})

## Soma `delta` (fracao da barra) ao ATB de `c`, entre 0 e cheio, e devolve a variacao real. Quem esta cheio e fora
## da fila (agindo, em menu ou parado) nao muda. Atrasar tira da fila; encher poe na fila (se nao esta parado).
static func shift_atb(c: Combatant, delta: float, b: BattleState) -> float:
	if c.is_down() or (c.atb >= 1.0 and not b.queue.has(c)):
		return 0.0
	var before: float = c.atb
	c.atb = clampf(before + delta, 0.0, 1.0)
	if c.atb < 1.0:
		b.queue.remove(c)
	elif not b.queue.has(c) and not c.is_stopped():
		b.queue.push(c, b.tick)
	return c.atb - before

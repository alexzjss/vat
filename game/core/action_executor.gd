# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name ActionExecutor
extends RefCounted

static func apply(a: PendingAction, b: BattleState) -> ActionResult:
	var r := ActionResult.new()
	var effects: Array[EffectDef] = a.effects()
	var center: Combatant = Targeting.redirect(a.shape(), a.side(), effects, a.actor, a.center, a.center_pos, b)
	if center == null:
		r.fizzled = true
		return r
	r.targets = Targeting.area(a.shape(), a.side(), effects, a.radius(), a.width(), a.actor, center, b)
	var credit: StringName = a.turn_owner().id
	# Marca e reacao uma vez por habilidade por alvo (M14): guarda quem ja foi tratado.
	var handled: Dictionary = {}
	# O ATB do atacante so vale depois da acao se ela zera a barra dele no fim (nao e contra-ataque nem Suporte).
	var defer_atb: bool = a.actor == a.turn_owner() and not a.is_counter
	for t: Combatant in r.targets:
		for e: EffectDef in effects:
			_apply_effect(e, a.actor, t, b, r, credit, a.ability, handled, defer_atb)
	# Chefe com nucleo: a queda do ultimo nucleo derruba as partes junto.
	for p: Combatant in b.collapse_parts():
		if not r.downed.has(p):
			r.downed.append(p)
	return r

static func _hit(r: ActionResult, t: Combatant, kind: EffectDef.Kind, amount: int, dodged: bool, status_result: int, missed: bool = false, shielded: bool = false, element: StringName = &"", affinity: int = ElementMath.Affinity.NEUTRAL, extra: Dictionary = {}) -> void:
	# Campos de elemento para a UI (M13): `lifesteal` (HP que o atacante roubou), `self_damage` (HP que o atacante
	# perdeu, Radioativo), `contamination` (nivel do alvo apos o golpe) e `burst` (dano do estouro; > 0 = estourou).
	# Marcas e reacoes (M14): `mark` (id da marca que o alvo carrega depois do golpe; vazio = nenhuma), `reaction` (id da
	# reacao disparada; vazio = nenhuma) e `reaction_effects` (o que a reacao fez, para a UI; vazio sem reacao):
	# {extra_damage, area: [{target_id, amount}], statuses: [{target_id, status_id, result}], atb: {target, attacker},
	# heal_attacker, heal_allies: [{target_id, amount}], removed}.
	var hit: Dictionary = {"target_id": t.id, "kind": kind, "amount": amount, "dodged": dodged, "status_result": status_result, "missed": missed, "shielded": shielded, "element": element, "affinity": affinity, "lifesteal": 0, "self_damage": 0, "contamination": 0, "burst": 0, "mark": MarkRules.id_of(t), "reaction": &"", "reaction_effects": {}}
	hit.merge(extra, true)
	r.hits.append(hit)

static func _scaled(e: EffectDef, actor: Combatant, attr: StringName, cfg: BalanceConfig) -> int:
	if e.scale == EffectDef.Scale.FIXED:
		return EffectMath.heal_amount(e, 0)
	return EffectMath.heal_amount(e, StatCalculator.effective(actor, attr, cfg))

## `credit` e quem recebe a contribuicao (o chamador, no Suporte; senao o ator).
static func _apply_effect(e: EffectDef, actor: Combatant, t: Combatant, b: BattleState, r: ActionResult, credit: StringName, ability: AbilityDef = null, handled: Dictionary = {}, defer_atb: bool = false) -> void:
	var enemies_alive: Array[Combatant] = b.living(b.enemies)
	match e.kind:
		EffectDef.Kind.DAMAGE:
			if t.is_down():
				return
			# Cegueira: erra antes da esquiva, só em dano de Força ("Errou").
			if e.scale == EffectDef.Scale.STRENGTH and actor.is_blind() and b.dice.roll() < b.cfg.blind_miss_chance:
				_hit(r, t, e.kind, 0, false, -1, true)
				return
			if e.dodgeable and b.dice.roll() < StatCalculator.dodge_chance(t, b.cfg, actor):
				_hit(r, t, e.kind, 0, true, -1)
				return
			var attr: StringName = &"aura" if e.scale == EffectDef.Scale.AURA else &"strength"
			var dmg: int = EffectMath.damage(e, StatCalculator.effective(actor, attr, b.cfg), StatCalculator.effective(t, &"vitality", b.cfg), t.equipment_mods.vitality, b.cfg, b.dice)
			# Elemento (M13): bonus de mesmo elemento e afinidade, depois da variacao e antes do escudo do nucleo e da barreira.
			var element: ElementDef = ElementMath.element_of(ability, actor)
			var el_id: StringName = element.id if element != null else &""
			var res: Dictionary = ElementMath.resolve(dmg, element, actor, t, b.cfg)
			dmg = res["damage"]
			var affinity: int = res["affinity"]
			if affinity == ElementMath.Affinity.ABSORB:
				# Absorver cura o alvo: sem barreira, Limite nem contribuicao.
				_hit(r, t, EffectDef.Kind.HEAL, restore(int(res["heal"]), t, b), false, -1, false, false, el_id, affinity)
				return
			# Nucleo protegido por uma parte: dano reduzido (minimo 1 se havia dano).
			var shielded: bool = dmg > 0 and b.core_shielded(t)
			if shielded:
				dmg = maxi(1, floori(float(dmg) * b.cfg.core_shield_mult))
			# Dano final do golpe (base da reacao), antes da barreira.
			var final_dmg: int = dmg
			var eff: int = deal_damage(actor, t, dmg, b, credit)
			var extra: Dictionary = {}
			if eff > 0 and element != null:
				extra = _element_rules(element, actor, t, eff, b, credit)
			# Marca e reacao (M14): so o primeiro golpe da habilidade que chegou ao alvo; quem caiu nao marca nem reage.
			var area_downed: Array = []
			if not handled.has(t) and MarkRules.marks(element, affinity):
				handled[t] = true
				if not t.is_down():
					var rdef: ReactionDef = ReactionRules.find(b.reactions, t.mark, element) if MarkRules.has_other(t, element) else null
					if rdef != null:
						var fx: Dictionary = ReactionRules.apply(rdef, actor, t, final_dmg, b, credit, defer_atb)
						area_downed = fx["downed"]
						fx.erase("downed")
						extra["reaction"] = rdef.id
						extra["reaction_effects"] = fx
					else:
						MarkRules.set_mark(t, element, b.cfg.mark_turns)
				extra["mark"] = MarkRules.id_of(t)
			_hit(r, t, e.kind, eff, false, -1, false, shielded, el_id, affinity, extra)
			if t.is_down():
				_on_down(t, b, r)
			for d: Combatant in area_downed:
				_on_down(d, b, r)
		EffectDef.Kind.HEAL:
			if t.is_down():
				return
			var restored: int = restore(_scaled(e, actor, &"aura", b.cfg), t, b)
			_credit_heal(actor, credit, t, restored, b, enemies_alive)
			_hit(r, t, e.kind, restored, false, -1)
		EffectDef.Kind.REVIVE:
			if not t.is_down():
				return
			var hpm: int = StatCalculator.hp_max(t, b.cfg)
			t.hp = EffectMath.revive_hp(e, hpm, b.cfg)
			t.atb = 0.0
			_credit_heal(actor, credit, t, t.hp, b, enemies_alive)
			_hit(r, t, e.kind, t.hp, false, -1)
		EffectDef.Kind.RESTORE_AP:
			# Sem contribuição ([P-plano] 16): Éter não gera XP.
			if t.is_down():
				return
			var before: int = t.ap
			t.ap = mini(StatCalculator.ap_max(t, b.cfg), t.ap + EffectMath.restore_ap_amount(e))
			_hit(r, t, e.kind, maxi(0, t.ap - before), false, -1)
		EffectDef.Kind.APPLY_STATUS:
			if t.is_down() or e.status == null:
				return
			var res: int = b.statuses.apply(t, e.status, actor, e.chance, enemies_alive)
			_hit(r, t, e.kind, 0, false, res)
		EffectDef.Kind.REMOVE_STATUS:
			var count: int = 0
			if e.status == null and e.statuses.is_empty():
				count = b.statuses.remove_negative(t)
			else:
				count = b.statuses.remove_many(t, e.statuses)
				if e.status != null and b.statuses.remove(t, e.status.id):
					count += 1
			_hit(r, t, e.kind, count, false, -1)

## Regras especiais do elemento depois do dano efetivo `eff` (> 0): Sangue rouba vida; Radioativo contamina
## (estoura no limite) e fere o atacante. Devolve os campos extras do hit. Nao consome Dice.
static func _element_rules(element: ElementDef, actor: Combatant, t: Combatant, eff: int, b: BattleState, credit: StringName) -> Dictionary:
	var extra: Dictionary = {}
	match element.rule:
		ElementDef.Rule.BLOOD:
			# Sem contribuicao de cura: o golpe ja gerou a de dano.
			if not actor.is_down():
				extra["lifesteal"] = restore(floori(float(eff) * b.cfg.blood_lifesteal), actor, b)
		ElementDef.Rule.RADIOACTIVE:
			var self_dmg: int = clampi(floori(float(eff) * b.cfg.rad_self_pct), 0, maxi(0, actor.hp - 1))
			actor.hp -= self_dmg
			extra["self_damage"] = self_dmg
			if not t.is_down():
				t.contamination += 1
				if t.contamination >= b.cfg.rad_threshold:
					# Zera antes de medir: o estouro usa o HP maximo sem a corrosao.
					t.contamination = 0
					t.contam_actions = 0
					var burst: int = mini(maxi(1, floori(float(StatCalculator.hp_max(t, b.cfg)) * b.cfg.rad_burst_pct)), t.hp)
					t.hp -= burst
					if actor.team == Combatant.Team.HERO and t.team == Combatant.Team.ENEMY:
						b.ledger.add(credit, t.id, float(burst))
					elif t.team == Combatant.Team.HERO and actor.team == Combatant.Team.ENEMY:
						t.damage_taken_from[actor.id] = int(t.damage_taken_from.get(actor.id, 0)) + burst
					t.gain_limit(burst, StatCalculator.hp_max(t, b.cfg), b.cfg)
					extra["burst"] = burst
			extra["contamination"] = t.contamination
	return extra

## Cura `amount` em `t` pelo teto do HP maximo; devolve quanto curou de fato.
## Dano direto de `actor` em `t`: a barreira absorve primeiro; credito de contribuicao (heroi contra inimigo) ou de
## dano sofrido (inimigo contra heroi), Limite e despertar de Sono/Confusao. Devolve o dano efetivo no HP.
static func deal_damage(actor: Combatant, t: Combatant, dmg: int, b: BattleState, credit: StringName) -> int:
	var left: int = b.statuses.absorb_with_barrier(t, dmg, actor)
	var eff: int = mini(left, t.hp)
	t.hp -= eff
	if actor.team == Combatant.Team.HERO and t.team == Combatant.Team.ENEMY:
		b.ledger.add(credit, t.id, float(eff))
	elif t.team == Combatant.Team.HERO and actor.team == Combatant.Team.ENEMY:
		t.damage_taken_from[actor.id] = int(t.damage_taken_from.get(actor.id, 0)) + eff
	if eff > 0:
		t.gain_limit(eff, StatCalculator.hp_max(t, b.cfg), b.cfg)
		b.statuses.on_hp_damage(t)
	return eff

## Quem caiu: sem estados, marca nem ATB, fora da fila e da preparacao.
static func _on_down(t: Combatant, b: BattleState, r: ActionResult) -> void:
	b.statuses.clear_all(t)
	t.atb = 0.0
	t.charging = null
	b.queue.remove(t)
	if not r.downed.has(t):
		r.downed.append(t)

static func restore(amount: int, t: Combatant, b: BattleState) -> int:
	var restored: int = maxi(0, mini(amount, StatCalculator.hp_max(t, b.cfg) - t.hp))
	t.hp += restored
	return restored

static func _credit_heal(actor: Combatant, credit: StringName, t: Combatant, amount: int, b: BattleState, enemies_alive: Array[Combatant]) -> void:
	if actor.team == Combatant.Team.HERO and t.team == Combatant.Team.HERO:
		b.ledger.add_ally_benefit(credit, t, float(amount), enemies_alive)

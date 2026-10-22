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
	for t: Combatant in r.targets:
		for e: EffectDef in effects:
			_apply_effect(e, a.actor, t, b, r, credit, a.ability)
	# Chefe com nucleo: a queda do ultimo nucleo derruba as partes junto.
	for p: Combatant in b.collapse_parts():
		if not r.downed.has(p):
			r.downed.append(p)
	return r

static func _hit(r: ActionResult, t: Combatant, kind: EffectDef.Kind, amount: int, dodged: bool, status_result: int, missed: bool = false, shielded: bool = false, element: StringName = &"", affinity: int = ElementMath.Affinity.NEUTRAL, extra: Dictionary = {}) -> void:
	# Campos de elemento para a UI (M13): `lifesteal` (HP que o atacante roubou).
	var hit: Dictionary = {"target_id": t.id, "kind": kind, "amount": amount, "dodged": dodged, "status_result": status_result, "missed": missed, "shielded": shielded, "element": element, "affinity": affinity, "lifesteal": 0}
	hit.merge(extra, true)
	r.hits.append(hit)

static func _scaled(e: EffectDef, actor: Combatant, attr: StringName, cfg: BalanceConfig) -> int:
	if e.scale == EffectDef.Scale.FIXED:
		return EffectMath.heal_amount(e, 0)
	return EffectMath.heal_amount(e, StatCalculator.effective(actor, attr, cfg))

## `credit` e quem recebe a contribuicao (o chamador, no Suporte; senao o ator).
static func _apply_effect(e: EffectDef, actor: Combatant, t: Combatant, b: BattleState, r: ActionResult, credit: StringName, ability: AbilityDef = null) -> void:
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
				_hit(r, t, EffectDef.Kind.HEAL, _restore(int(res["heal"]), t, b), false, -1, false, false, el_id, affinity)
				return
			# Nucleo protegido por uma parte: dano reduzido (minimo 1 se havia dano).
			var shielded: bool = dmg > 0 and b.core_shielded(t)
			if shielded:
				dmg = maxi(1, floori(float(dmg) * b.cfg.core_shield_mult))
			dmg = b.statuses.absorb_with_barrier(t, dmg, actor)
			var eff: int = mini(dmg, t.hp)
			t.hp -= eff
			if actor.team == Combatant.Team.HERO and t.team == Combatant.Team.ENEMY:
				b.ledger.add(credit, t.id, float(eff))
			elif t.team == Combatant.Team.HERO and actor.team == Combatant.Team.ENEMY:
				t.damage_taken_from[actor.id] = int(t.damage_taken_from.get(actor.id, 0)) + eff
			if eff > 0:
				t.gain_limit(eff, StatCalculator.hp_max(t, b.cfg), b.cfg)
				b.statuses.on_hp_damage(t)
			var extra: Dictionary = {}
			if eff > 0 and element != null:
				extra = _element_rules(element, actor, t, eff, b, credit)
			_hit(r, t, e.kind, eff, false, -1, false, shielded, el_id, affinity, extra)
			if t.is_down():
				b.statuses.clear_all(t)
				t.atb = 0.0
				t.charging = null
				b.queue.remove(t)
				if not r.downed.has(t):
					r.downed.append(t)
		EffectDef.Kind.HEAL:
			if t.is_down():
				return
			var restored: int = _restore(_scaled(e, actor, &"aura", b.cfg), t, b)
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

## Regras especiais do elemento depois do dano efetivo `eff` (> 0): Sangue rouba vida. Devolve os campos extras do hit. Nao consome Dice.
static func _element_rules(element: ElementDef, actor: Combatant, t: Combatant, eff: int, b: BattleState, credit: StringName) -> Dictionary:
	var extra: Dictionary = {}
	match element.rule:
		ElementDef.Rule.BLOOD:
			# Sem contribuicao de cura: o golpe ja gerou a de dano.
			if not actor.is_down():
				extra["lifesteal"] = _restore(floori(float(eff) * b.cfg.blood_lifesteal), actor, b)
	return extra

static func _restore(amount: int, t: Combatant, b: BattleState) -> int:
	var restored: int = maxi(0, mini(amount, StatCalculator.hp_max(t, b.cfg) - t.hp))
	t.hp += restored
	return restored

static func _credit_heal(actor: Combatant, credit: StringName, t: Combatant, amount: int, b: BattleState, enemies_alive: Array[Combatant]) -> void:
	if actor.team == Combatant.Team.HERO and t.team == Combatant.Team.HERO:
		b.ledger.add_ally_benefit(credit, t, float(amount), enemies_alive)

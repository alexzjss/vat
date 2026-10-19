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
	for t: Combatant in r.targets:
		for e: EffectDef in effects:
			_apply_effect(e, a.actor, t, b, r)
	return r

static func _hit(r: ActionResult, t: Combatant, kind: EffectDef.Kind, amount: int, dodged: bool, status_result: int) -> void:
	r.hits.append({"target_id": t.id, "kind": kind, "amount": amount, "dodged": dodged, "status_result": status_result})

static func _scaled(e: EffectDef, actor: Combatant, attr: StringName, cfg: BalanceConfig) -> int:
	if e.scale == EffectDef.Scale.FIXED:
		return EffectMath.heal_amount(e, 0)
	return EffectMath.heal_amount(e, StatCalculator.effective(actor, attr, cfg))

static func _apply_effect(e: EffectDef, actor: Combatant, t: Combatant, b: BattleState, r: ActionResult) -> void:
	var enemies_alive: Array[Combatant] = b.living(b.enemies)
	match e.kind:
		EffectDef.Kind.DAMAGE:
			if t.is_down():
				return
			if e.dodgeable and b.dice.roll() < StatCalculator.dodge_chance(t, b.cfg):
				_hit(r, t, e.kind, 0, true, -1)
				return
			var attr: StringName = &"aura" if e.scale == EffectDef.Scale.AURA else &"strength"
			var gross: int = _scaled(e, actor, attr, b.cfg)
			var defense: int = int(floor(StatCalculator.effective(t, &"vitality", b.cfg) * b.cfg.defense_per_vitality))
			var dmg: int = maxi(1, gross - defense)
			dmg = b.statuses.absorb_with_barrier(t, dmg, actor)
			var eff: int = mini(dmg, t.hp)
			t.hp -= eff
			if actor.team == Combatant.Team.HERO and t.team == Combatant.Team.ENEMY:
				b.ledger.add(actor.id, t.id, float(eff))
			elif t.team == Combatant.Team.HERO and actor.team == Combatant.Team.ENEMY:
				t.damage_taken_from[actor.id] = int(t.damage_taken_from.get(actor.id, 0)) + eff
			if eff > 0:
				b.statuses.on_hp_damage(t)
			_hit(r, t, e.kind, eff, false, -1)
			if t.is_down():
				b.statuses.clear_all(t)
				t.atb = 0.0
				b.queue.remove(t)
				if not r.downed.has(t):
					r.downed.append(t)
		EffectDef.Kind.HEAL:
			if t.is_down():
				return
			var restored: int = _restore(_scaled(e, actor, &"aura", b.cfg), t, b)
			_credit_heal(actor, t, restored, b, enemies_alive)
			_hit(r, t, e.kind, restored, false, -1)
		EffectDef.Kind.REVIVE:
			if not t.is_down():
				return
			var hpm: int = StatCalculator.hp_max(t, b.cfg)
			t.hp = EffectMath.revive_hp(e, hpm)
			t.atb = 0.0
			_credit_heal(actor, t, t.hp, b, enemies_alive)
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
			if e.status == null:
				return
			var removed: bool = b.statuses.remove(t, e.status.id)
			_hit(r, t, e.kind, 1 if removed else 0, false, -1)

static func _restore(amount: int, t: Combatant, b: BattleState) -> int:
	var restored: int = maxi(0, mini(amount, StatCalculator.hp_max(t, b.cfg) - t.hp))
	t.hp += restored
	return restored

static func _credit_heal(actor: Combatant, t: Combatant, amount: int, b: BattleState, enemies_alive: Array[Combatant]) -> void:
	if actor.team == Combatant.Team.HERO and t.team == Combatant.Team.HERO:
		b.ledger.add_ally_benefit(actor.id, t, float(amount), enemies_alive)

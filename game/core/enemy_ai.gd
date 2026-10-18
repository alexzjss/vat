# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name EnemyAI
extends RefCounted

static func decide(actor: Combatant, b: BattleState) -> PendingAction:
	if actor.enemy_def != null:
		for rule: AiRule in actor.enemy_def.ai_rules:
			if rule.ability == null or rule.ability.ap_cost > actor.ap:
				continue
			if not _condition_holds(rule, actor, b):
				continue
			var center: Combatant = _pick_center(rule, actor, b)
			if center == null:
				continue
			actor.ap -= rule.ability.ap_cost
			return _make(actor, rule.ability, center)
	if actor.basic_attack == null:
		push_error("EnemyAI: %s sem ataque basico" % actor.id)
		return null
	var target: Combatant = null
	for h: Combatant in b.living(b.foes_of(actor)):
		if target == null or h.hp < target.hp:
			target = h
	if target == null:
		return null
	return _make(actor, actor.basic_attack, target)

static func _make(actor: Combatant, ability: AbilityDef, center: Combatant) -> PendingAction:
	var pa := PendingAction.new()
	pa.actor = actor
	pa.ability = ability
	pa.center = center
	pa.center_pos = center.position
	return pa

static func _condition_holds(rule: AiRule, actor: Combatant, b: BattleState) -> bool:
	if rule.condition == AiRule.Condition.ALLY_HP_BELOW:
		for c: Combatant in b.living(b.allies_of(actor)):
			if float(c.hp) < rule.threshold * float(StatCalculator.hp_max(c, b.cfg)):
				return true
		return false
	return true

static func _pick_center(rule: AiRule, actor: Combatant, b: BattleState) -> Combatant:
	var a: AbilityDef = rule.ability
	var cands: Array[Combatant] = Targeting.candidates(a.shape, a.side, a.effects, actor, b)
	if cands.is_empty():
		return null
	match rule.pick:
		AiRule.TargetPick.SELF:
			return actor if cands.has(actor) else null
		AiRule.TargetPick.RANDOM_ENEMY:
			return cands[b.dice.pick_index(cands.size())]
	var best: Combatant = null
	for c: Combatant in cands:
		if best == null or c.hp < best.hp:
			best = c
	return best

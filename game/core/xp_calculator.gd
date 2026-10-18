class_name XpCalculator
extends RefCounted

static func combat_xp(ledger: ContributionLedger, defeated: Array[Combatant], heroes: Array[Combatant], fled: bool) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for h: Combatant in heroes:
		result[h.id] = 0
	if fled:
		return result
	for e: Combatant in defeated:
		var total: float = ledger.total_against(e.id)
		if total <= 0.0:
			continue
		var xp_base: int = e.enemy_def.xp_base
		for h: Combatant in heroes:
			var pts: float = ledger.get_points(h.id, e.id)
			result[h.id] += floori(float(xp_base) * pts / total)
	return result

static func xp_for_level(level: int, cfg: BalanceConfig) -> int:
	return cfg.xp_coef * (level - 1) * (level - 1)

static func points_for_level(level: int) -> int:
	return 1 + (2 if level % 5 == 0 else 0)

static func grant(h: HeroState, xp: int, cfg: BalanceConfig) -> int:
	h.xp += xp
	var gained: int = 0
	while h.xp >= xp_for_level(h.level + 1, cfg):
		h.level += 1
		h.pending_points += points_for_level(h.level)
		gained += 1
	return gained

static func allocate(h: HeroState, attr: StringName, n: int) -> bool:
	if n <= 0 or n > h.pending_points or not Stats.ATTRS.has(attr):
		return false
	match attr:
		&"strength": h.allocated.strength += n
		&"speed": h.allocated.speed += n
		&"vitality": h.allocated.vitality += n
		&"aura": h.allocated.aura += n
	h.pending_points -= n
	return true

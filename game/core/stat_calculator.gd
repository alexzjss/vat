# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name StatCalculator
extends RefCounted

static func diminishing(raw: int, cfg: BalanceConfig) -> int:
	if raw <= cfg.dr_soft_cap:
		return raw
	return cfg.dr_soft_cap + int(floor((raw - cfg.dr_soft_cap) * cfg.dr_factor))

static func effective(c: Combatant, attr: StringName, cfg: BalanceConfig) -> int:
	var raw: int = c.base.get_attr(attr) + c.allocated.get_attr(attr) + c.equipment_mods.get_attr(attr)
	var total: int = diminishing(raw, cfg)
	for s: ActiveStatus in c.statuses:
		if s.def.kind == StatusDef.Kind.ATTR_MOD and s.def.attr == attr:
			total += s.def.potency
	return maxi(0, total)

static func hp_max(c: Combatant, cfg: BalanceConfig) -> int:
	return effective(c, &"vitality", cfg) * cfg.hp_per_vitality + c.level * cfg.hp_per_level

static func ap_max(c: Combatant, cfg: BalanceConfig) -> int:
	return effective(c, &"aura", cfg) * cfg.ap_per_aura

static func atb_rate(c: Combatant, cfg: BalanceConfig) -> float:
	var rate: float = cfg.atb_base_rate + effective(c, &"speed", cfg) * cfg.atb_rate_per_speed
	for s: ActiveStatus in c.statuses:
		if s.def.kind == StatusDef.Kind.HASTE:
			rate *= 1.0 + s.def.potency / 100.0
		elif s.def.kind == StatusDef.Kind.SLOW:
			rate *= 1.0 - s.def.potency / 100.0
	return maxf(cfg.atb_min_rate, rate)

static func dodge_chance(c: Combatant, cfg: BalanceConfig) -> float:
	return minf(cfg.dodge_cap, effective(c, &"speed", cfg) * cfg.dodge_per_speed)

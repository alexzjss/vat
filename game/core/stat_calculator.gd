# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name StatCalculator
extends RefCounted

static func diminishing(raw: int, cfg: BalanceConfig) -> int:
	if cfg.dr_mode == BalanceConfig.DrMode.B:
		if raw <= cfg.dr_band2_start:
			return raw
		var band2: int = mini(raw, cfg.dr_band3_start) - cfg.dr_band2_start
		var total: int = cfg.dr_band2_start + int(floor(band2 * cfg.dr_band2_factor))
		if raw > cfg.dr_band3_start:
			total += int(floor((raw - cfg.dr_band3_start) * cfg.dr_band3_factor))
		return total
	if cfg.dr_mode == BalanceConfig.DrMode.C:
		if raw <= 0:
			return raw
		return floori(cfg.dr_smooth_limit * raw / (raw + cfg.dr_smooth_k))
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
	var vit: int = effective(c, &"vitality", cfg)
	if cfg.hp_mode == BalanceConfig.HpMode.B:
		return cfg.hp_base + vit * cfg.hp_vit_a + c.level * cfg.hp_lvl_b + floori(vit * c.level * cfg.hp_vit_lvl_c)
	if cfg.hp_mode == BalanceConfig.HpMode.C:
		return floori((cfg.hp_base + vit * cfg.hp_vit_a) * (1.0 + c.level * cfg.hp_c_level_mult))
	return vit * cfg.hp_per_vitality + c.level * cfg.hp_per_level

static func ap_max(c: Combatant, cfg: BalanceConfig) -> int:
	var aura: int = effective(c, &"aura", cfg)
	if cfg.ap_mode == BalanceConfig.ApMode.B:
		return aura * cfg.ap_aura_a + c.level * cfg.ap_lvl_b
	if cfg.ap_mode == BalanceConfig.ApMode.C:
		return floori(aura * cfg.ap_aura_a * (1.0 + c.level * cfg.ap_c_level_mult))
	return aura * cfg.ap_per_aura

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

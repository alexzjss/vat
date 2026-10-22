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
	var modded: bool = false
	for s: ActiveStatus in c.statuses:
		if s.def.kind == StatusDef.Kind.ATTR_MOD and s.def.attr == attr:
			total += s.def.potency
			modded = true
	# Radioativo (M13): a contaminacao corroi a Vitalidade (so quando ha contaminacao).
	if attr == &"vitality" and c.contamination > 0 and total > 0:
		total = maxi(1, floori(float(total) * maxf(0.0, 1.0 - cfg.rad_corrode_per_stack * float(c.contamination))))
	# Queimadura (M15): a Forca efetiva cai enquanto queima.
	if attr == &"strength" and total > 0 and c.has_kind(StatusDef.Kind.BURN):
		total = maxi(1, floori(float(total) * maxf(0.0, 1.0 - cfg.burn_str_pct)))
	# Berserk (M15): a Forca efetiva sobe enquanto em Berserk.
	if attr == &"strength" and total > 0 and c.has_kind(StatusDef.Kind.BERSERK):
		total = floori(float(total) * (1.0 + cfg.berserk_str_pct))
	# Buff/debuff nunca zera o atributo (minimo 1); sem estado, o valor base segue como era.
	return maxi(1 if modded else 0, total)

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

## field_avg_speed: media da Vel efetiva dos vivos (so o modo B usa); < 0 = nao informada.
static func atb_rate(c: Combatant, cfg: BalanceConfig, field_avg_speed: float = -1.0) -> float:
	var spd: int = effective(c, &"speed", cfg)
	var rate: float = cfg.atb_base_rate + spd * cfg.atb_rate_per_speed
	if cfg.atb_mode == BalanceConfig.AtbMode.B and field_avg_speed >= 0.0:
		rate = cfg.atb_base_rate * (spd + 1.0) / (field_avg_speed + 1.0)
	elif cfg.atb_mode == BalanceConfig.AtbMode.C:
		rate = 1.0 / (cfg.atb_turn_time * cfg.atb_c_r / (cfg.atb_c_r + spd))
	for s: ActiveStatus in c.statuses:
		if s.def.kind == StatusDef.Kind.HASTE:
			rate *= 1.0 + s.def.potency / 100.0
		elif s.def.kind == StatusDef.Kind.SLOW:
			rate *= 1.0 - s.def.potency / 100.0
	return maxf(cfg.atb_min_rate, rate)

static func dodge_chance(c: Combatant, cfg: BalanceConfig, attacker: Combatant = null) -> float:
	if c.is_stopped():
		return 0.0
	if cfg.dodge_mode == BalanceConfig.DodgeMode.C:
		return 0.0
	if cfg.dodge_mode == BalanceConfig.DodgeMode.B and attacker != null:
		var diff: int = effective(c, &"speed", cfg) - effective(attacker, &"speed", cfg)
		return clampf(diff * cfg.dodge_per_speed, 0.0, cfg.dodge_cap)
	return minf(cfg.dodge_cap, effective(c, &"speed", cfg) * cfg.dodge_per_speed)

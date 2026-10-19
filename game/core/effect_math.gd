## Formulas de efeito compartilhadas entre combate (ActionExecutor) e campo (FieldActions).
## Somente calculo: clamps ficam com quem aplica.
class_name EffectMath
extends RefCounted

static func heal_amount(e: EffectDef, user_aura_effective: int) -> int:
	if e.scale == EffectDef.Scale.FIXED:
		return int(floor(e.potency))
	return int(floor(e.potency * user_aura_effective))

static func revive_hp(e: EffectDef, hp_max: int, cfg: BalanceConfig = null) -> int:
	if cfg != null:
		match cfg.revive_mode:
			BalanceConfig.ReviveMode.B:
				return maxi(1, floori(hp_max * cfg.revive_b))
			BalanceConfig.ReviveMode.C:
				return maxi(1, cfg.revive_c_flat + floori(hp_max * cfg.revive_c_pct))
	return maxi(1, int(floor(hp_max * e.potency)))

static func restore_ap_amount(e: EffectDef) -> int:
	return int(floor(e.potency))

## Dano final (antes da barreira). `attr_effective` = atributo efetivo do atacante;
## `target_vit_effective` / `target_equip_vit` = Vitalidade efetiva e bonus de equipamento do alvo.
## Variacao so consome o Dice nos modos B/C (modo A nao consome rolagem).
static func damage(e: EffectDef, attr_effective: int, target_vit_effective: int, target_equip_vit: int, cfg: BalanceConfig, dice: Dice) -> int:
	var gross: int = 0
	if e.scale == EffectDef.Scale.FIXED:
		gross = int(floor(e.potency))
	else:
		gross = int(floor(e.potency * attr_effective))
	var defense: float = target_vit_effective * cfg.defense_per_vitality
	var dmg: int = 0
	match cfg.damage_mode:
		BalanceConfig.DamageMode.B:
			dmg = floori(gross * cfg.dmg_ratio_k / (cfg.dmg_ratio_k + defense))
		BalanceConfig.DamageMode.C:
			dmg = gross - floori(defense + target_equip_vit * cfg.dmg_c_equip_factor)
		_:
			dmg = gross - int(floor(defense))
	var amplitude: float = 0.0
	match cfg.variance_mode:
		BalanceConfig.VarianceMode.B:
			amplitude = cfg.variance_b
		BalanceConfig.VarianceMode.C:
			amplitude = cfg.variance_c
	if amplitude > 0.0:
		dmg = floori(dmg * (1.0 + (dice.roll() * 2.0 - 1.0) * amplitude))
	return maxi(1, dmg)

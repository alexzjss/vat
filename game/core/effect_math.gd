## Formulas de efeito compartilhadas entre combate (ActionExecutor) e campo (FieldActions).
## Somente calculo: clamps ficam com quem aplica.
class_name EffectMath
extends RefCounted

static func heal_amount(e: EffectDef, user_aura_effective: int) -> int:
	if e.scale == EffectDef.Scale.FIXED:
		return int(floor(e.potency))
	return int(floor(e.potency * user_aura_effective))

static func revive_hp(e: EffectDef, hp_max: int) -> int:
	return maxi(1, int(floor(hp_max * e.potency)))

static func restore_ap_amount(e: EffectDef) -> int:
	return int(floor(e.potency))

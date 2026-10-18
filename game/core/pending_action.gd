# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name PendingAction
extends RefCounted

var actor: Combatant
var ability: AbilityDef
var item: ItemDef
var center: Combatant
var center_pos: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var impacted: bool = false

func shape() -> AbilityDef.Shape:
	return item.shape if item != null else ability.shape

func side() -> AbilityDef.Side:
	return item.side if item != null else ability.side

func effects() -> Array[EffectDef]:
	return item.effects if item != null else ability.effects

func radius() -> float:
	return 0.0 if item != null else ability.radius

func width() -> float:
	return 0.0 if item != null else ability.width

func cast_time(cfg: BalanceConfig) -> float:
	return cfg.item_cast_time if item != null else ability.cast_time

func impact_time(cfg: BalanceConfig) -> float:
	return cfg.item_impact_time if item != null else ability.impact_time

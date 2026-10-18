class_name AbilityDef
extends Resource

enum Shape { SINGLE, GROUP, ALL, CIRCLE_TARGET, CIRCLE_SELF, LINE }
enum Side { ENEMIES, ALLIES, BOTH }

@export var id: StringName
@export var display_name: String = ""
@export var ap_cost: int = 0
@export var shape: Shape = Shape.SINGLE
@export var side: AbilityDef.Side = AbilityDef.Side.ENEMIES
@export var radius: float = 0.0
@export var width: float = 0.0
@export var cast_time: float = 1.0
@export var impact_time: float = 0.5
@export var effects: Array[EffectDef] = []

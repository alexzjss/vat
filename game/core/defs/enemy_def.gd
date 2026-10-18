class_name EnemyDef
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var level: int = 1
@export var base: Stats
@export var xp_base: int = 100
@export var abilities: Array[AbilityDef] = []
@export var ai_rules: Array[AiRule] = []
@export var immunities: Array[StringName] = []
## 0..1 = redução da chance.
@export var resistances: Dictionary[StringName, float] = {}

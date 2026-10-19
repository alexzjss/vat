class_name EncounterDef
extends Resource

@export var id: StringName
@export var enemies: Array[EnemyDef] = []
## false (chefes): segurar a tecla de fuga não faz nada.
@export var can_flee: bool = true

class_name CharacterDef
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var base: Stats
@export var basic_attack: AbilityDef
## Técnicas do herói, na ordem de aprendizado (M9). `level` 0 = só por evento.
@export var learnset: Array[LearnEntry] = []
## Golpe de Limite (M8): sem custo de AP, liberado com a barra cheia.
@export var limit_ability: AbilityDef
## Tipos de arma que o herói usa; vazio = não usa armas com tipo.
@export var weapon_types: Array[StringName] = []
@export var starting_equipment: Array[EquipmentDef] = []

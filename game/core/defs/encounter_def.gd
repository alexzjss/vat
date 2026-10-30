class_name EncounterDef
extends Resource

@export var id: StringName
@export var enemies: Array[EnemyDef] = []
## false (chefes): segurar a tecla de fuga não faz nada.
@export var can_flee: bool = true
## Chefes: id gravado em GameState.defeated ao vencer; o mapa não os instancia de novo (vazio = comum).
@export var unique_id: StringName = &""
## Musica de batalha (M19): id no SoundBank. Vazio = a musica de batalha padrao (BalanceConfig).
@export var music: StringName = &""

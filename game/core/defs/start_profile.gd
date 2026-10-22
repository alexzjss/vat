class_name StartProfile
extends Resource

## Perfil de início de um Novo jogo (M12): quem está no grupo, o que carrega, quanto dinheiro tem e onde começa.
## `data/test/start_teste.tres` é o perfil das demos e dos testes; `data/fatia/start.tres`, o da fatia vertical.
## Os heróis além de GameState.MAX_ACTIVE vão para a reserva. Contagens e listas andam em paralelo.

@export var party: Array[CharacterDef] = []
@export var items: Array[ItemDef] = []
@export var item_counts: Array[int] = []
## Mochila inicial de equipamento (o equipamento vestido vem de CharacterDef.starting_equipment).
@export var equipment: Array[EquipmentDef] = []
@export var equipment_counts: Array[int] = []
@export var money: int = 0
@export var map: StringName = &"overworld"
@export var spawn: StringName = &"Start"

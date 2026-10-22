class_name Overworld
extends Node2D

## Mapa-múndi de teste: o jogador anda livre e entra em zonas de local (sem inimigos).

signal location_entered(zone_id: StringName, spawn: StringName)

const MAP_RECT: Rect2 = Rect2(0, 0, 2560, 1440)

var state: GameState

@onready var player: Player = $Player
@onready var camera: MapCamera = $MapCamera

func _ready() -> void:
	for child: Node in get_children():
		var zone: Zone = child as Zone
		if zone != null:
			zone.entered.connect(_on_zone_entered.bind(zone.spawn))

## Posiciona o jogador no marcador `spawn` (ou em `Start`, se não existir) e liga a câmera.
func setup(game_state: GameState, spawn: StringName) -> void:
	state = game_state
	player.cfg = state.cfg
	var marker: Node2D = get_node_or_null(NodePath(String(spawn))) as Node2D
	if marker == null:
		push_error("Overworld: marcador '%s' não existe" % spawn)
		marker = $Start as Node2D
	player.global_position = marker.global_position
	camera.follow = player
	camera.set_bounds(MAP_RECT)
	camera.global_position = player.global_position
	camera.reset_smoothing()

## Põe o jogador numa posição exata (restauração de save) e recentra a câmera.
func place_player(pos: Vector2) -> void:
	player.global_position = pos
	camera.global_position = pos
	camera.reset_smoothing()

func _on_zone_entered(zone_id: StringName, spawn: StringName) -> void:
	location_entered.emit(zone_id, spawn)

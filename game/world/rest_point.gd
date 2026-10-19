class_name RestPoint
extends Area2D

## Ponto de descanso: com o jogador dentro da área, a tecla `interact` pede o menu de descanso.
## `spawn_name` é o marcador do mapa gravado no save feito aqui.

signal interacted

@export var spawn_name: StringName = &"RestSpawn"
@export var label_text: String = "Descanso"

## Quem pode usar o ponto (o LocalMap liga o jogador).
var player: Node2D
## Desligado durante batalha/transições (o mapa avisa).
var enabled: bool = true

## Dentro da área? Medido pela posição do jogador (e não por sinais de física): um mapa congelado
## com o menu aberto não dispara body_exited, mas o estado também não depende disso.
var player_inside: bool:
	get:
		return player != null and _shape_rect().has_point(to_local(player.global_position))

func _init() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

func _ready() -> void:
	var rect: Rect2 = _shape_rect()
	var fill := ColorRect.new()
	fill.color = Color(0.3, 0.8, 0.9, 0.25)
	fill.position = rect.position
	fill.size = rect.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	var label := Label.new()
	label.text = "%s (Enter)" % label_text
	label.position = rect.position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and request():
		get_viewport().set_input_as_handled()

## Pede o menu de descanso (devolve false fora da área ou desligado). Os testes chamam direto.
func request() -> bool:
	if not enabled or not player_inside:
		return false
	interacted.emit()
	return true

func _shape_rect() -> Rect2:
	for child: Node in get_children():
		var cs := child as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			var size: Vector2 = (cs.shape as RectangleShape2D).size
			return Rect2(cs.position - size / 2.0, size)
	return Rect2(-16, -16, 32, 32)

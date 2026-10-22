class_name MapLink
extends Area2D

## Ligação entre mapas locais (M12): portas de casas, escadas entre andares e saídas. Quando o jogador entra na área,
## `activated` pede ao Game que leve o jogador para o marcador `target_spawn` do mapa `target_map` (com fade).
## O LocalMap desarma a ligação durante batalhas e eventos (`armed`).

signal activated(target_map: StringName, target_spawn: StringName)

@export var target_map: StringName = &""
@export var target_spawn: StringName = &"Entry"
@export var label_text: String = ""

var armed: bool = true

const COLOR: Color = Color(0.5, 0.9, 0.5, 0.25)

func _init() -> void:
	collision_layer = 0
	collision_mask = 2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var rect: Rect2 = _shape_rect()
	var fill := ColorRect.new()
	fill.color = COLOR
	fill.position = rect.position
	fill.size = rect.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	if label_text != "":
		var label := Label.new()
		label.text = label_text
		label.position = rect.position
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

func _on_body_entered(body: Node2D) -> void:
	if armed and body is Player:
		activated.emit(target_map, target_spawn)

func _shape_rect() -> Rect2:
	for child: Node in get_children():
		var cs := child as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			var size: Vector2 = (cs.shape as RectangleShape2D).size
			return Rect2(cs.position - size / 2.0, size)
	return Rect2(-16, -16, 32, 32)

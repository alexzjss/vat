class_name Zone
extends Area2D

signal entered(zone_id: StringName)

@export var zone_id: StringName = &""
@export var label_text: String = ""

var armed: bool = true

func _init() -> void:
	collision_layer = 0
	collision_mask = 2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var rect: Rect2 = _shape_rect()
	var fill := ColorRect.new()
	fill.color = Color(0.9, 0.8, 0.2, 0.25)
	fill.position = rect.position
	fill.size = rect.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	var label := Label.new()
	label.text = label_text
	label.position = rect.position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _on_body_entered(body: Node2D) -> void:
	if armed and body is Player:
		entered.emit(zone_id)

func _shape_rect() -> Rect2:
	for child: Node in get_children():
		var cs := child as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			var size: Vector2 = (cs.shape as RectangleShape2D).size
			return Rect2(cs.position - size / 2.0, size)
	return Rect2(-16, -16, 32, 32)

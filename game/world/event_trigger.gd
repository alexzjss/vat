class_name EventTrigger
extends Area2D

## Gatilho de evento (M10): roda `event` quando o jogador entra na área; com `once_flag`, só uma vez
## (a flag fica gravada, então vale também para o mapa reinstanciado e o save).

@export var event: EventScript
@export var once_flag: StringName = &""
@export var size: Vector2 = Vector2(48, 120)

func _init() -> void:
	collision_layer = 0
	collision_mask = 2

func _ready() -> void:
	if get_children().is_empty():
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		trigger()

## Roda o evento agora. False se já rodou (once_flag) ou se o mapa está ocupado.
func trigger() -> bool:
	var map: LocalMap = LocalMap.map_of(self)
	if map == null or map.state == null or event == null:
		return false
	if once_flag != &"" and map.state.get_flag(once_flag) != 0:
		return false
	if not map.run_event(event):
		return false
	if once_flag != &"":
		map.state.set_flag(once_flag, 1)
	return true

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

## O disparo foi recusado (mapa ocupado) com o jogador na área: tenta de novo enquanto ele ficar.
var _pending: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not trigger():
		_pending = true

func _process(_delta: float) -> void:
	if not _pending:
		return
	var inside: bool = false
	for b: Node2D in get_overlapping_bodies():
		inside = inside or b is Player
	var map: LocalMap = LocalMap.map_of(self)
	var done: bool = once_flag != &"" and map != null and map.state != null and map.state.get_flag(once_flag) != 0
	if not inside or done or trigger():
		_pending = false

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

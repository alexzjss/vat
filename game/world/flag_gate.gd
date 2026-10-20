class_name FlagGate
extends StaticBody2D

## Portão (M10): bloqueia a passagem enquanto a flag é diferente de `open_value`. Normalmente ligado a um Switch.
## Segue a flag todo quadro, então o mapa reinstanciado e o restore do save o mostram certo.

@export var flag: StringName = &""
@export var open_value: int = 1
@export var size: Vector2 = Vector2(24, 120)

const CLOSED_COLOR: Color = Color(0.55, 0.55, 0.62)
const OPEN_COLOR: Color = Color(0.55, 0.55, 0.62, 0.2)

var _shape: CollisionShape2D
var _drawn_blocking: bool = true
var _synced: bool = false

func _init() -> void:
	collision_layer = 1
	collision_mask = 0

func _ready() -> void:
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	add_child(_shape)
	sync_state()

func _process(_delta: float) -> void:
	sync_state()

## Bloqueando a passagem agora?
func blocking() -> bool:
	var s: GameState = LocalMap.state_of(self)
	return s == null or s.get_flag(flag) != open_value

func sync_state() -> void:
	var b: bool = blocking()
	if _shape != null:
		_shape.set_deferred(&"disabled", not b)
	if b != _drawn_blocking or not _synced:
		_synced = true
		_drawn_blocking = b
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), CLOSED_COLOR if _drawn_blocking else OPEN_COLOR)
	if _drawn_blocking:
		var x: float = -size.x / 2.0
		while x < size.x / 2.0:
			draw_line(Vector2(x, -size.y / 2.0), Vector2(x, size.y / 2.0), Color(0.3, 0.3, 0.35), 2.0)
			x += 8.0

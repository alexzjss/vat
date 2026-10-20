class_name Door
extends Interactable

## Porta (M10): bloqueia a passagem até `open_flag` ser gravada. Se tem `key_item`, precisa dele no inventário;
## a chave é item-chave e NÃO é consumida. Sem a chave mostra "Está trancada.". Aberta, não bloqueia.
## O estado vive só na flag (mapa reinstanciado, save e Game Over → restore refletem).

@export var key_item: ItemDef
@export var open_flag: StringName = &""
@export var size: Vector2 = Vector2(24, 120)
@export var locked_text: String = "Está trancada."

const CLOSED_COLOR: Color = Color(0.45, 0.3, 0.18)
const OPEN_COLOR: Color = Color(0.45, 0.3, 0.18, 0.25)

var _body: StaticBody2D
var _shape: CollisionShape2D
var _synced_open: bool = false

func _init() -> void:
	prompt = "Abrir"

func _ready() -> void:
	super._ready()
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect
	_body.add_child(_shape)
	add_child(_body)
	sync_state()

func _process(delta: float) -> void:
	super._process(delta)
	sync_state()

func is_open() -> bool:
	var s: GameState = game_state()
	return s != null and open_flag != &"" and s.get_flag(open_flag) != 0

## Bloqueio e desenho seguem a flag (chamado todo quadro; público para os testes).
func sync_state() -> void:
	var now_open: bool = is_open()
	if _shape != null:
		_shape.set_deferred(&"disabled", now_open)
	if now_open != _synced_open or not _drawn:
		_synced_open = now_open
		_drawn = true
		queue_redraw()

var _drawn: bool = false

## Bloqueando a passagem agora?
func blocking() -> bool:
	return not is_open()

func can_interact() -> bool:
	return super.can_interact() and not is_open()

func has_key() -> bool:
	var s: GameState = game_state()
	return key_item == null or (s != null and s.inventory.available(key_item.id) > 0)

func _activate() -> void:
	var steps: Array[EventStep] = []
	if has_key():
		steps.append(EventScript.set_flag(open_flag, 1))
		if key_item != null:
			steps.append(EventScript.say("Usou %s. A porta se abriu." % key_item.display_name))
		else:
			steps.append(EventScript.say("A porta se abriu."))
	else:
		steps.append(EventScript.say(locked_text))
	_run_script(EventScript.of(steps))

func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), OPEN_COLOR if _synced_open else CLOSED_COLOR)
	if not _synced_open:
		draw_circle(Vector2(size.x / 2.0 - 5.0, 0.0), 3.0, Color(0.95, 0.8, 0.25))

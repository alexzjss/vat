class_name Chest
extends Interactable

## Baú (M10): ao abrir dá `item` ou `equipment` (x`count`) e grava `opened_flag`. O estado vive só na flag,
## então o mapa reinstanciado, o save e o Game Over → restore mostram o baú certo. Aberto, aparece vazio.

@export var item: ItemDef
@export var equipment: EquipmentDef
@export var count: int = 1
@export var opened_flag: StringName = &""

const CLOSED_COLOR: Color = Color(0.6, 0.4, 0.15)
const OPEN_COLOR: Color = Color(0.3, 0.22, 0.12)
const TRIM_COLOR: Color = Color(0.95, 0.8, 0.25)

var _drawn_open: bool = false

func _init() -> void:
	solid = true
	prompt = "Abrir"

func _process(delta: float) -> void:
	super._process(delta)
	var now_open: bool = is_open()
	if now_open != _drawn_open:
		_drawn_open = now_open
		queue_redraw()

func is_open() -> bool:
	var s: GameState = game_state()
	return s != null and opened_flag != &"" and s.get_flag(opened_flag) != 0

func can_interact() -> bool:
	return super.can_interact() and not is_open()

## Nome e quantidade do conteúdo ("Poção", "Poção x2").
func content_text() -> String:
	var n: String = ""
	if item != null:
		n = item.display_name
	elif equipment != null:
		n = equipment.display_name
	if n != "" and count > 1:
		n += " x%d" % count
	return n

func _activate() -> void:
	var steps: Array[EventStep] = []
	steps.append(EventScript.set_flag(opened_flag, 1))
	if item != null:
		var gi := GiveItemStep.new()
		gi.item = item
		gi.count = count
		steps.append(gi)
	elif equipment != null:
		var ge := GiveEquipmentStep.new()
		ge.equipment = equipment
		ge.count = count
		steps.append(ge)
	var found: String = content_text()
	steps.append(EventScript.say("Encontrou %s!" % found if found != "" else "O baú está vazio."))
	_run_script(EventScript.of(steps))

func _draw() -> void:
	var c: Color = OPEN_COLOR if _drawn_open else CLOSED_COLOR
	draw_rect(Rect2(-16, -10, 32, 22), c)
	draw_rect(Rect2(-16, -10, 32, 8), c.lightened(0.15))
	if not _drawn_open:
		draw_rect(Rect2(-3, -4, 6, 8), TRIM_COLOR)

class_name Switch
extends Interactable

## Interruptor (M10): alterna `flag` entre 0 e 1 a cada uso. Um FlagGate com a mesma flag abre/fecha o portão.
## O estado vive só na flag.

@export var flag: StringName = &""
@export var on_text: String = "Algo se abriu ao longe."
@export var off_text: String = "Algo se fechou ao longe."

var _drawn_on: bool = false

func _init() -> void:
	prompt = "Acionar"

func is_on() -> bool:
	var s: GameState = game_state()
	return s != null and flag != &"" and s.get_flag(flag) != 0

func _process(delta: float) -> void:
	super._process(delta)
	var now_on: bool = is_on()
	if now_on != _drawn_on:
		_drawn_on = now_on
		queue_redraw()

func _activate() -> void:
	var turning_on: bool = not is_on()
	var steps: Array[EventStep] = []
	steps.append(EventScript.set_flag(flag, 1 if turning_on else 0))
	steps.append(EventScript.say(on_text if turning_on else off_text))
	_run_script(EventScript.of(steps))

func _draw() -> void:
	draw_rect(Rect2(-12, 2, 24, 10), Color(0.35, 0.35, 0.4))
	var tip: Vector2 = Vector2(10, -14) if _drawn_on else Vector2(-10, -14)
	draw_line(Vector2(0, 4), tip, Color(0.8, 0.8, 0.85), 4.0)
	draw_circle(tip, 5.0, Color(0.3, 0.9, 0.4) if _drawn_on else Color(0.9, 0.3, 0.3))

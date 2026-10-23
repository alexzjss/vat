class_name Sign
extends Interactable

## Placa (M10): retângulo marrom que mostra `text` (ou o roteiro `event`, se houver) ao interagir.

@export_multiline var text: String = ""

const COLOR: Color = Color(0.55, 0.38, 0.2)

func _init() -> void:
	solid = true

func _activate() -> void:
	if event == null and roteiro == null and text != "":
		var say := SayStep.new()
		say.text = text
		var script := EventScript.new()
		script.steps = [say] as Array[EventStep]
		event = script
	super._activate()

func _draw() -> void:
	draw_rect(Rect2(-14, -12, 28, 20), COLOR)
	draw_rect(Rect2(-2, 8, 4, 10), COLOR.darkened(0.3))

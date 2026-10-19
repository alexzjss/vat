class_name GameOverScreen
extends CanvasLayer

## Tela de Game Over (camada 9): cobre o mapa; Enter volta ao título.

signal dismissed

func _init() -> void:
	layer = 9
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = "Game Over"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Enter: voltar ao título"
	hint.add_theme_font_size_override("font_size", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

func accept() -> void:
	dismissed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		accept()
		get_viewport().set_input_as_handled()

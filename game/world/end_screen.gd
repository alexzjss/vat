class_name EndScreen
extends CanvasLayer

## Tela de fim da demo (M12, camada 9): "Fim da demo", o tempo de jogo e o nível do grupo; Enter volta ao título.

signal dismissed

var _label: Label

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
	title.text = "Fim da demo"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 22)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	var hint := Label.new()
	hint.text = "Enter: voltar ao título"
	hint.add_theme_font_size_override("font_size", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

## Preenche o resumo: tempo de jogo (mm:ss, ou h:mm:ss a partir de uma hora) e nível do grupo.
func setup(play_time: float, party_level: int) -> void:
	_label.text = "Tempo de jogo: %s\nNível do grupo: Nv %d" % [format_time(play_time), party_level]

## Texto completo da tela (título e resumo).
func body_text() -> String:
	return "Fim da demo\n%s" % _label.text

static func format_time(seconds: float) -> String:
	var total: int = maxi(0, int(seconds))
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	return "%d:%02d:%02d" % [h, m, s] if h > 0 else "%02d:%02d" % [m, s]

func accept() -> void:
	dismissed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		accept()
		get_viewport().set_input_as_handled()

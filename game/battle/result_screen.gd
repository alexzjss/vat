class_name ResultScreen
extends PanelContainer

## Tela de resultado: Vitória (XP por herói e níveis) ou Derrota.
## Uma única ação (Enter): "Continuar", "Lutar de novo" ou "Tentar de novo".
## O teclado chama accept(), que também serve aos testes.

signal accepted

enum Mode { HIDDEN, VICTORY, DEFEAT }

const TITLE_COLOR: Color = Color(1.0, 0.85, 0.3)
const DEFEAT_COLOR: Color = Color(0.95, 0.4, 0.4)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)

var mode: Mode = Mode.HIDDEN

var _title: Label
var _list: VBoxContainer
var _action: Label
var _action_text: String = ""
var _lines: PackedStringArray = PackedStringArray()

func _init() -> void:
	visible = false
	custom_minimum_size = Vector2(420.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.16, 0.97)
	style.border_color = Color(0.35, 0.4, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16.0)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_list = VBoxContainer.new()
	box.add_child(_list)
	_action = Label.new()
	_action.add_theme_font_size_override("font_size", 18)
	_action.add_theme_color_override("font_color", TITLE_COLOR)
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_action)

## Vitória: uma linha por herói, "Nome: +N XP (Nv a → b)" ou "(Nv a)" sem subida.
func show_for(xp: Dictionary[StringName, int], before_levels: Dictionary, heroes: Array[HeroState]) -> void:
	mode = Mode.VICTORY
	var rows := PackedStringArray()
	for h: HeroState in heroes:
		var before: int = before_levels.get(h.def.id, h.level)
		var gained: int = xp.get(h.def.id, 0)
		var lv: String = "Nv %d → %d" % [before, h.level] if h.level != before else "Nv %d" % h.level
		rows.append("%s: +%d XP (%s)" % [h.def.display_name, gained, lv])
	_present("Vitória!", TITLE_COLOR, rows, "Continuar")

func show_defeat() -> void:
	mode = Mode.DEFEAT
	_present("Derrota", DEFEAT_COLOR, PackedStringArray(["Todos os heróis caíram."]), "Tentar de novo")

## Troca o texto da ação e reexibe a tela (ex.: "Lutar de novo" após as telas de nível).
func set_action(text: String) -> void:
	_action_text = text
	_action.text = "> %s   (Enter)" % text
	visible = true

func action_label() -> String:
	return _action_text

## Título seguido das linhas de conteúdo.
func lines() -> PackedStringArray:
	var out := PackedStringArray([_title.text])
	out.append_array(_lines)
	return out

func close() -> void:
	mode = Mode.HIDDEN
	visible = false

func accept() -> void:
	if mode == Mode.HIDDEN or not visible:
		return
	accepted.emit()

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.HIDDEN or not visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		accept()

func _present(title: String, color: Color, rows: PackedStringArray, action: String) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_lines = rows
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	for r: String in rows:
		var l := Label.new()
		l.text = r
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", TEXT_COLOR)
		_list.add_child(l)
	set_action(action)

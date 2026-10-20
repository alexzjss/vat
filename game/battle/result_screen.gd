class_name ResultScreen
extends PanelContainer

## Tela de resultado: Vitória (XP por herói e níveis) ou Derrota (título configurável, ex.: "Game Over").
## Uma ou mais ações (↑/↓ escolhe, Enter confirma; a primeira é o padrão), ex.:
## "Continuar"; "Descansar e lutar"/"Lutar de novo"; "Tentar de novo"/"Descansar e tentar de novo".
## O teclado chama move()/accept(), que também servem aos testes.

signal accepted(index: int)

enum Mode { HIDDEN, VICTORY, DEFEAT }

const TITLE_COLOR: Color = Color(1.0, 0.85, 0.3)
const DEFEAT_COLOR: Color = Color(0.95, 0.4, 0.4)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const IDLE_COLOR: Color = Color(0.75, 0.75, 0.8)

var mode: Mode = Mode.HIDDEN

var _title: Label
var _list: VBoxContainer
var _actions_box: VBoxContainer
var _actions: PackedStringArray = PackedStringArray()
## Índice da ação sob o cursor.
var selected: int = 0
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
	_actions_box = VBoxContainer.new()
	box.add_child(_actions_box)

## Vitória: uma linha por herói, "Nome: +N XP (Nv a → b)" ou "(Nv a)" sem subida; depois "Nome aprendeu X!"
## para cada técnica nova (HeroState.last_learned).
func show_for(xp: Dictionary[StringName, int], before_levels: Dictionary, heroes: Array[HeroState]) -> void:
	mode = Mode.VICTORY
	var rows := PackedStringArray()
	for h: HeroState in heroes:
		var before: int = before_levels.get(h.def.id, h.level)
		var gained: int = xp.get(h.def.id, 0)
		var lv: String = "Nv %d → %d" % [before, h.level] if h.level != before else "Nv %d" % h.level
		rows.append("%s: +%d XP (%s)" % [h.def.display_name, gained, lv])
	for h: HeroState in heroes:
		for ab: AbilityDef in h.last_learned:
			rows.append("%s aprendeu %s!" % [h.def.display_name, ab.display_name])
	_present("Vitória!", TITLE_COLOR, rows, PackedStringArray(["Continuar"]))

## Derrota; título e ações configuráveis (ex.: "Game Over"/["Continuar"] no modo mapa).
func show_defeat(title: String = "Derrota",
		actions: PackedStringArray = PackedStringArray(["Tentar de novo", "Descansar e tentar de novo"])) -> void:
	mode = Mode.DEFEAT
	_present(title, DEFEAT_COLOR, PackedStringArray(["Todos os heróis caíram."]), actions)

## Troca as ações (cursor volta à primeira) e reexibe a tela (ex.: após as telas de nível).
func set_actions(texts: PackedStringArray) -> void:
	_actions = texts
	selected = 0
	_render_actions()
	visible = true

func action_labels() -> PackedStringArray:
	return _actions

## Texto da ação sob o cursor.
func action_label() -> String:
	return _actions[selected] if selected < _actions.size() else ""

## Move o cursor entre as ações, com volta circular.
func move(delta: int) -> void:
	if _actions.is_empty():
		return
	selected = posmod(selected + delta, _actions.size())
	_render_actions()

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
	accepted.emit(selected)

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.HIDDEN or not visible:
		return
	if event.is_action_pressed("ui_up"):
		move(-1)
	elif event.is_action_pressed("ui_down"):
		move(1)
	elif event.is_action_pressed("ui_accept"):
		accept()
	else:
		return
	get_viewport().set_input_as_handled()

func _present(title: String, color: Color, rows: PackedStringArray, actions: PackedStringArray) -> void:
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
	set_actions(actions)

func _render_actions() -> void:
	for child: Node in _actions_box.get_children():
		_actions_box.remove_child(child)
		child.free()
	for i: int in _actions.size():
		var l := Label.new()
		var on: bool = i == selected
		l.text = ("> %s" if on else "  %s") % _actions[i]
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", TITLE_COLOR if on else IDLE_COLOR)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_actions_box.add_child(l)
	if _actions.size() > 1:
		var hint := Label.new()
		hint.text = "↑/↓: escolher   Enter: confirmar"
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", IDLE_COLOR)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_actions_box.add_child(hint)

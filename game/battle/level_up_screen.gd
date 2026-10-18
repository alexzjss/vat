class_name LevelUpScreen
extends PanelContainer

## Alocação de pontos de um herói: uma linha por atributo (valor atual e +/−),
## "Confirmar" (aplica via XpCalculator.allocate) e "Depois" (sai; pontos ficam pendentes).
## O rascunho nunca fica negativo: "−" não desce abaixo do valor ao abrir.
## Teclado: ↑/↓ linha, ←/→ −/+, Enter escolhe, Esc = Depois. Os mesmos métodos servem aos testes.

signal opened(h: HeroState)
signal closed(h: HeroState)

const ATTR_NAMES: Dictionary[StringName, String] = {
	&"strength": "Força",
	&"speed": "Velocidade",
	&"vitality": "Vitalidade",
	&"aura": "Aura",
}
const ROW_CONFIRM: int = 4
const ROW_LATER: int = 5
const ROW_COUNT: int = 6
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const ADDED_COLOR: Color = Color(0.5, 0.95, 0.55)

var hero: HeroState
var cursor: int = 0

var _draft: Dictionary[StringName, int] = {}
var _title: Label
var _header: Label
var _list: VBoxContainer
var _hint: Label

func _init() -> void:
	visible = false
	custom_minimum_size = Vector2(360.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.16, 0.97)
	style.border_color = Color(0.35, 0.4, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16.0)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", CURSOR_COLOR)
	box.add_child(_title)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 16)
	_header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	box.add_child(_header)
	_list = VBoxContainer.new()
	box.add_child(_list)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_hint.text = "↑/↓: linha   ←/→: −/+   Enter: escolher   Esc: depois"
	box.add_child(_hint)

func open(h: HeroState) -> void:
	hero = h
	cursor = 0
	_draft = {}
	for attr: StringName in Stats.ATTRS:
		_draft[attr] = 0
	visible = true
	_render()
	opened.emit(h)

## Pontos ainda não distribuídos no rascunho.
func remaining() -> int:
	if hero == null:
		return 0
	var used: int = 0
	for n: int in _draft.values():
		used += n
	return hero.pending_points - used

func draft(attr: StringName) -> int:
	return _draft.get(attr, 0)

## Valor exibido: base + alocado + rascunho.
func shown_value(attr: StringName) -> int:
	return hero.def.base.get_attr(attr) + hero.allocated.get_attr(attr) + draft(attr)

func increment(attr: StringName) -> bool:
	if hero == null or not _draft.has(attr) or remaining() <= 0:
		return false
	_draft[attr] += 1
	_render()
	return true

func decrement(attr: StringName) -> bool:
	if hero == null or draft(attr) <= 0:
		return false
	_draft[attr] -= 1
	_render()
	return true

## Aplica o rascunho; pontos não usados continuam pendentes no HeroState.
func confirm() -> void:
	if hero == null or remaining() < 0:
		return
	for attr: StringName in Stats.ATTRS:
		if _draft[attr] > 0:
			XpCalculator.allocate(hero, attr, _draft[attr])
	_finish()

## Sai sem aplicar: todos os pontos continuam pendentes.
func leave() -> void:
	if hero == null:
		return
	_finish()

func row_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for i: int in ROW_COUNT:
		out.append(_row_text(i))
	return out

func move(delta: int) -> void:
	if hero == null:
		return
	cursor = posmod(cursor + delta, ROW_COUNT)
	_render()

## ←/→ na linha de atributo.
func adjust(delta: int) -> void:
	if hero == null or cursor >= Stats.ATTRS.size():
		return
	var attr: StringName = Stats.ATTRS[cursor]
	if delta > 0:
		increment(attr)
	elif delta < 0:
		decrement(attr)

func accept() -> void:
	if hero == null:
		return
	if cursor < Stats.ATTRS.size():
		increment(Stats.ATTRS[cursor])
	elif cursor == ROW_CONFIRM:
		confirm()
	else:
		leave()

func _unhandled_input(event: InputEvent) -> void:
	if hero == null or not visible:
		return
	if event.is_action_pressed("ui_up"):
		move(-1)
	elif event.is_action_pressed("ui_down"):
		move(1)
	elif event.is_action_pressed("ui_left"):
		adjust(-1)
	elif event.is_action_pressed("ui_right"):
		adjust(1)
	elif event.is_action_pressed("ui_accept"):
		accept()
	elif event.is_action_pressed("ui_cancel"):
		leave()
	else:
		return
	get_viewport().set_input_as_handled()

func _finish() -> void:
	var h: HeroState = hero
	hero = null
	visible = false
	closed.emit(h)

func _row_text(i: int) -> String:
	if i == ROW_CONFIRM:
		return "Confirmar"
	if i == ROW_LATER:
		return "Depois"
	var attr: StringName = Stats.ATTRS[i]
	var d: int = draft(attr)
	var extra: String = "  (+%d)" % d if d > 0 else ""
	return "%-11s %3d  − / +%s" % [ATTR_NAMES[attr], shown_value(attr), extra]

func _render() -> void:
	if hero == null:
		return
	_title.text = "%s — Nv %d" % [hero.def.display_name, hero.level]
	_header.text = "Pontos: %d" % remaining()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	for i: int in ROW_COUNT:
		var l := Label.new()
		l.text = ("> " if i == cursor else "  ") + _row_text(i)
		l.add_theme_font_size_override("font_size", 18)
		var color: Color = CURSOR_COLOR if i == cursor else TEXT_COLOR
		if i < Stats.ATTRS.size() and draft(Stats.ATTRS[i]) > 0 and i != cursor:
			color = ADDED_COLOR
		l.add_theme_color_override("font_color", color)
		_list.add_child(l)

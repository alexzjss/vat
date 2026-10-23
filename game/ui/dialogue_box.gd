class_name DialogueBox
extends CanvasLayer

## Caixa de diálogo do mapa (M10; camada 5, abaixo do Fade): placa de nome (some em texto de sistema), texto revelado a
## `chars_per_second` caracteres por segundo e, para escolhas, a lista de opções. `accept` completa o texto e,
## com ele completo, avança (fala) ou escolhe (opções); cima/baixo movem o cursor.
## O teclado é lido em _input e consumido enquanto a caixa está aberta, então o mesmo `accept`
## nunca chega ao mapa (interact, menu de campo, movimento). A tecla que abriu a caixa, no mesmo quadro, é ignorada.
## O teclado chama accept()/move(), que também servem aos testes; tick() revela o texto.

signal advanced
signal chosen(index: int)

const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const NAME_COLOR: Color = Color(1.0, 0.85, 0.3)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)

var is_open: bool = false
var chars_per_second: float = 60.0
## Opções da escolha em andamento (vazio = fala simples).
var options: PackedStringArray = PackedStringArray()
var cursor: int = 0

var _text: String = ""
var _shown: float = 0.0
var _opened_frame: int = -1

var _root: Control
var _plate: PanelContainer
var _name: Label
var _body: Label
var _list: VBoxContainer
var _more: Label
var _option_labels: Array[Label] = []

## Caracteres por segundo da velocidade de texto `level` (1-based, como GameSettings.text_speed).
static func speed_for(cfg: BalanceConfig, level: int) -> float:
	if cfg.text_speeds.is_empty():
		return 60.0
	return cfg.text_speeds[clampi(level - 1, 0, cfg.text_speeds.size() - 1)]

func _init() -> void:
	layer = 5
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	column.offset_left = 40.0
	column.offset_right = -40.0
	column.offset_bottom = -24.0
	column.offset_top = -200.0
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	_root.add_child(column)
	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override("panel", _style(Color(0.16, 0.18, 0.26, 0.97), 8.0))
	_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_plate)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 18)
	_name.add_theme_color_override("font_color", NAME_COLOR)
	_plate.add_child(_name)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.1, 0.11, 0.16, 0.95), 14.0))
	panel.custom_minimum_size = Vector2(0.0, 120.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", 20)
	_body.add_theme_color_override("font_color", TEXT_COLOR)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)
	_more = Label.new()
	_more.text = "▼"
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_more.add_theme_color_override("font_color", CURSOR_COLOR)
	box.add_child(_more)

static func _style(bg: Color, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(0.35, 0.4, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(margin)
	return style

## Abre com uma fala. `speaker` vazio = texto de sistema (sem placa).
func say(speaker: String, text: String, cps: float = -1.0) -> void:
	_open(speaker, text, PackedStringArray(), cps)

## Abre com uma pergunta e opções; o cursor começa na primeira.
func ask(prompt: String, p_options: PackedStringArray, cps: float = -1.0, speaker: String = "") -> void:
	_open(speaker, prompt, p_options, cps)

func _open(speaker: String, text: String, p_options: PackedStringArray, cps: float) -> void:
	if cps > 0.0:
		chars_per_second = cps
	is_open = true
	visible = true
	_opened_frame = Engine.get_process_frames()
	_text = text
	_shown = 0.0
	options = p_options
	cursor = 0
	_plate.visible = speaker != ""
	_name.text = speaker
	_body.text = text
	_body.visible_characters = 0
	_rebuild_options()
	_refresh()

func close() -> void:
	is_open = false
	visible = false
	options = PackedStringArray()
	_text = ""

## Caracteres já revelados.
func shown_chars() -> int:
	return mini(int(_shown), _text.length())

## O texto ainda está sendo revelado?
func is_revealing() -> bool:
	return is_open and shown_chars() < _text.length()

func tick(delta: float) -> void:
	if not is_open or not is_revealing():
		return
	_shown = minf(_shown + delta * chars_per_second, float(_text.length()))
	_refresh()

func _process(delta: float) -> void:
	tick(delta)

## Completa o texto; se já completo, avança a fala ou confirma a opção.
func accept() -> void:
	if not is_open:
		return
	if is_revealing():
		_shown = float(_text.length())
		_refresh()
		return
	if options.is_empty():
		advanced.emit()
	else:
		chosen.emit(cursor)

## Move o cursor das opções (com o texto completo); `dir` -1 sobe, 1 desce.
func move(dir: int) -> void:
	if not is_open or options.is_empty() or is_revealing():
		return
	cursor = posmod(cursor + dir, options.size())
	_refresh()

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		# A tecla que abriu a caixa (ou a que acabou de avançar para esta fala) não conta.
		if Engine.get_process_frames() != _opened_frame:
			accept()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		move(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		move(1)
		get_viewport().set_input_as_handled()

func _rebuild_options() -> void:
	for l: Label in _option_labels:
		_list.remove_child(l)
		l.queue_free()
	_option_labels = []
	for i: int in options.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 18)
		_list.add_child(l)
		_option_labels.append(l)

func _refresh() -> void:
	var complete: bool = shown_chars() >= _text.length()
	_body.visible_characters = shown_chars()
	_list.visible = complete and not options.is_empty()
	_more.visible = complete and options.is_empty()
	for i: int in _option_labels.size():
		var selected: bool = i == cursor
		_option_labels[i].text = ("> " if selected else "  ") + options[i]
		_option_labels[i].add_theme_color_override("font_color", CURSOR_COLOR if selected else TEXT_COLOR)

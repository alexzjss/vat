class_name FieldMenu
extends CanvasLayer

## Menu de campo (camada 5: acima do mapa, abaixo do Fade). Raiz: lista de comandos + painel do grupo.
## Cada comando abre uma página (um Control filho em `_pages`, preenchido pelas páginas reais).
## O teclado (_unhandled_input) chama move/accept/cancel, que também servem aos testes.
## Esc é "voltar" aqui dentro e sempre é consumido, então nunca reabre o menu.

signal closed

const COMMANDS: Array[String] = ["Itens", "Técnicas", "Status", "Atributos", "Formação", "Fechar"]
const COMMAND_PAGES: Array[StringName] = [&"items", &"techniques", &"status", &"attributes", &"formation", &""]
const PAGE_TITLES: Dictionary[StringName, String] = {
	&"items": "Itens", &"techniques": "Técnicas", &"status": "Status",
	&"attributes": "Atributos", &"formation": "Formação",
}
const ENABLED_COLOR: Color = Color(1.0, 1.0, 1.0)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)

var state: GameState
var is_open: bool = false
var cursor: int = 0
var page: StringName = &"root"
var party_panel: PartyPanel

var _root: Control
var _command_list: VBoxContainer
var _command_labels: Array[Label] = []
var _page_panel: PanelContainer
var _page_title: Label
var _pages: Dictionary[StringName, Control] = {}

func _init() -> void:
	layer = 5
	visible = false
	_build()

func open(s: GameState) -> void:
	state = s
	is_open = true
	visible = true
	cursor = 0
	party_panel.end_pick()
	party_panel.refresh(s)
	_show_page(&"root")

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	party_panel.end_pick()
	page = &"root"
	closed.emit()

func command_labels() -> PackedStringArray:
	return PackedStringArray(COMMANDS)

## Control da página (`&"root"` é o painel do grupo, sempre visível para seleção de alvo);
## as páginas reais (Task 5) preenchem o Control da sua página.
func page_control(p: StringName) -> Control:
	return _pages.get(p, null)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_up"):
		move(-1)
	elif event.is_action_pressed("ui_down"):
		move(1)
	elif event.is_action_pressed("ui_accept"):
		accept()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_menu"):
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()

func move(delta: int) -> void:
	if not is_open or page != &"root":
		return
	cursor = posmod(cursor + delta, COMMANDS.size())
	_render()

func accept() -> void:
	if not is_open or page != &"root":
		return
	var target: StringName = COMMAND_PAGES[cursor]
	if target == &"":
		close()
	else:
		_show_page(target)

## Numa página: volta à raiz (cursor no comando da página). Na raiz: fecha.
func cancel() -> void:
	if not is_open:
		return
	if page == &"root":
		close()
	else:
		_show_page(&"root")

func _show_page(p: StringName) -> void:
	page = p
	for key: StringName in _pages:
		if key != &"root":
			_pages[key].visible = key == p
	_page_panel.visible = p != &"root"
	_page_title.text = PAGE_TITLES.get(p, "")
	_render()

func _render() -> void:
	for i: int in _command_labels.size():
		var l: Label = _command_labels[i]
		var selected: bool = i == cursor
		l.text = ("> " if selected else "  ") + COMMANDS[i]
		l.add_theme_color_override("font_color", CURSOR_COLOR if selected else ENABLED_COLOR)

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	_root.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var commands_panel: PanelContainer = _panel()
	commands_panel.custom_minimum_size = Vector2(220.0, 0.0)
	commands_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(commands_panel)
	var cbox := VBoxContainer.new()
	cbox.add_theme_constant_override("separation", 4)
	commands_panel.add_child(cbox)
	var title := Label.new()
	title.text = "Menu"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", CURSOR_COLOR)
	cbox.add_child(title)
	_command_list = VBoxContainer.new()
	cbox.add_child(_command_list)
	for c: String in COMMANDS:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 18)
		_command_list.add_child(l)
		_command_labels.append(l)
	var hint := Label.new()
	hint.text = "Enter: escolher   Esc: voltar"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	cbox.add_child(hint)

	var party_holder: PanelContainer = _panel()
	party_holder.custom_minimum_size = Vector2(420.0, 0.0)
	party_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(party_holder)
	party_panel = PartyPanel.new()
	party_holder.add_child(party_panel)
	_pages[&"root"] = party_holder

	_page_panel = _panel()
	_page_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_panel.visible = false
	row.add_child(_page_panel)
	var pbox := VBoxContainer.new()
	pbox.add_theme_constant_override("separation", 8)
	_page_panel.add_child(pbox)
	_page_title = Label.new()
	_page_title.add_theme_font_size_override("font_size", 20)
	_page_title.add_theme_color_override("font_color", CURSOR_COLOR)
	pbox.add_child(_page_title)
	for p: StringName in PAGE_TITLES:
		var content := VBoxContainer.new()
		content.name = String(p)
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.visible = false
		pbox.add_child(content)
		_pages[p] = content
	_render()

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.16, 0.95)
	style.border_color = Color(0.35, 0.4, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12.0)
	p.add_theme_stylebox_override("panel", style)
	return p

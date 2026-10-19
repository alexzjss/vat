class_name FieldMenu
extends CanvasLayer

## Menu de campo (camada 5: acima do mapa, abaixo do Fade). Raiz: lista de comandos + painel do grupo.
## Cada comando abre uma página (FieldPage em `_pages`); o menu só roteia: numa página, o teclado vai
## primeiro para o handler registrado em set_page_input, e cancel() deixa a página desfazer um passo
## (seleção de alvo, sub-tela) antes de voltar à raiz. Na raiz, move/accept/cancel servem aos testes.
## Esc é "voltar" aqui dentro e sempre é consumido, então nunca reabre o menu.

signal closed
## Alguma configuração mudou (página Config): quem hospeda persiste e aplica.
signal settings_changed

const COMMANDS: Array[String] = ["Itens", "Técnicas", "Equipar", "Status", "Atributos", "Formação", "Config", "Fechar"]
const COMMAND_PAGES: Array[StringName] = [&"items", &"techniques", &"equip", &"status", &"attributes", &"formation", &"config", &""]
const PAGE_TITLES: Dictionary[StringName, String] = {
	&"items": "Itens", &"techniques": "Técnicas", &"equip": "Equipar", &"status": "Status",
	&"attributes": "Atributos", &"formation": "Formação", &"config": "Config",
}
const ATTRIBUTES_INDEX: int = 4
const ENABLED_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(0.45, 0.45, 0.5)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)

var state: GameState
var is_open: bool = false
var cursor: int = 0
var page: StringName = &"root"
var party_panel: PartyPanel
var item_page: ItemPage
var technique_page: TechniquePage
var equip_page: EquipPage
var status_page: StatusPage
var attributes_page: AttributesPage
var formation_page: FormationPage
var config_page: ConfigPage

var _root: Control
var _command_list: VBoxContainer
var _command_labels: Array[Label] = []
var _page_panel: PanelContainer
var _page_title: Label
var _pages: Dictionary[StringName, Control] = {}
var _page_input: Dictionary[StringName, Callable] = {}
var _page_cancel: Dictionary[StringName, Callable] = {}
var _message: Label

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
	_message.text = ""
	_show_page(&"root")

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	_leave_page()
	party_panel.end_pick()
	page = &"root"
	closed.emit()

func command_labels() -> PackedStringArray:
	return PackedStringArray(COMMANDS)

func command_enabled(i: int) -> bool:
	if i == ATTRIBUTES_INDEX:
		return state != null and AttributesPage.anyone_pending(state)
	return true

## Aviso da raiz (ex.: comando desabilitado).
func message() -> String:
	return _message.text

## Control da página (`&"root"` é o painel do grupo, sempre visível para seleção de alvo).
func page_control(p: StringName) -> Control:
	return _pages.get(p, null)

## Handler de teclado da página `p`: recebe o evento e devolve true se o consumiu.
func set_page_input(p: StringName, handler: Callable) -> void:
	_page_input[p] = handler

## "Voltar" da página `p`: devolve true se desfez um passo interno (o menu fica na página).
func set_page_cancel(p: StringName, handler: Callable) -> void:
	_page_cancel[p] = handler

## Atualiza o painel do grupo e os comandos da raiz após uma ação de página.
func refresh_party() -> void:
	party_panel.refresh(state)
	_render()

func return_to_root() -> void:
	if is_open and page != &"root":
		_leave_page()
		_show_page(&"root")

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if page != &"root" and _page_input.has(page) and bool(_page_input[page].call(event)):
		get_viewport().set_input_as_handled()
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
	_message.text = ""
	_render()

func accept() -> void:
	if not is_open or page != &"root":
		return
	var target: StringName = COMMAND_PAGES[cursor]
	if target == &"":
		close()
	elif not command_enabled(cursor):
		_message.text = "Ninguém tem pontos para distribuir."
	else:
		_message.text = ""
		_show_page(target)

## Numa página: volta à raiz (cursor no comando da página). Na raiz: fecha.
func cancel() -> void:
	if not is_open:
		return
	if page == &"root":
		close()
		return
	if _page_cancel.has(page) and bool(_page_cancel[page].call()):
		return
	_leave_page()
	_show_page(&"root")

func _leave_page() -> void:
	var fp: FieldPage = _pages.get(page, null) as FieldPage
	if fp != null:
		fp.leave()

func _show_page(p: StringName) -> void:
	page = p
	for key: StringName in _pages:
		if key != &"root":
			_pages[key].visible = key == p
	_page_panel.visible = p != &"root"
	_page_title.text = PAGE_TITLES.get(p, "")
	var fp: FieldPage = _pages.get(p, null) as FieldPage
	if fp != null:
		fp.enter()
	_render()

func _render() -> void:
	for i: int in _command_labels.size():
		var l: Label = _command_labels[i]
		var selected: bool = i == cursor
		l.text = ("> " if selected else "  ") + COMMANDS[i]
		var color: Color = CURSOR_COLOR if selected else ENABLED_COLOR
		if not command_enabled(i):
			color = DISABLED_COLOR
		l.add_theme_color_override("font_color", color)

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
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 13)
	_message.add_theme_color_override("font_color", FieldPage.MESSAGE_COLOR)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cbox.add_child(_message)

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
	item_page = ItemPage.new()
	technique_page = TechniquePage.new()
	equip_page = EquipPage.new()
	status_page = StatusPage.new()
	attributes_page = AttributesPage.new()
	formation_page = FormationPage.new()
	config_page = ConfigPage.new()
	var pages: Dictionary[StringName, FieldPage] = {
		&"items": item_page, &"techniques": technique_page, &"equip": equip_page, &"status": status_page,
		&"attributes": attributes_page, &"formation": formation_page,
		&"config": config_page,
	}
	for p: StringName in PAGE_TITLES:
		var content: FieldPage = pages[p]
		content.name = String(p)
		content.visible = false
		content.setup(self)
		pbox.add_child(content)
		_pages[p] = content
		set_page_input(p, content.handle_input)
		set_page_cancel(p, content.cancel)
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

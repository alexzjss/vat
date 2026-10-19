class_name FieldPage
extends VBoxContainer

## Base das páginas do FieldMenu: uma lista com cursor (entradas desabilitadas ficam cinza e não
## podem ser escolhidas), uma linha de aviso e acesso ao menu (estado, painel do grupo).
## O FieldMenu roteia o teclado para handle_input e o "voltar" para cancel; os testes chamam
## move/adjust/accept/cancel diretamente.

const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(0.45, 0.45, 0.5)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)
const MESSAGE_COLOR: Color = Color(0.95, 0.75, 0.45)

var menu: FieldMenu
var state: GameState
var cursor: int = 0

var _entries: Array[String] = []
var _enabled: Array[bool] = []
var _list: VBoxContainer
var _message: Label

func _init() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	add_child(_list)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 14)
	_message.add_theme_color_override("font_color", MESSAGE_COLOR)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)

func setup(m: FieldMenu) -> void:
	menu = m

## Chamado ao abrir a página.
func enter() -> void:
	state = menu.state
	cursor = 0
	_say("")

## Chamado ao sair da página (encerra seleções pendentes).
func leave() -> void:
	if menu.party_panel.picking:
		menu.party_panel.end_pick()

func move(delta: int) -> void:
	if _entries.is_empty():
		return
	cursor = posmod(cursor + delta, _entries.size())
	_render_list()

func adjust(_delta: int) -> void:
	pass

func accept() -> void:
	pass

## Volta um passo dentro da página; false quando não há passo para desfazer (o menu sai da página).
func cancel() -> bool:
	return false

func handle_input(event: InputEvent) -> bool:
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
	else:
		return false
	return true

func entries() -> PackedStringArray:
	return PackedStringArray(_entries)

func entry_enabled(i: int) -> bool:
	return i >= 0 and i < _enabled.size() and _enabled[i]

func message() -> String:
	return _message.text

func _say(text: String) -> void:
	_message.text = text

func _set_entries(texts: Array[String], enabled: Array[bool]) -> void:
	_entries = texts
	_enabled = enabled
	cursor = clampi(cursor, 0, maxi(0, _entries.size() - 1))
	_render_list()

## Lista vazia ou cursor numa entrada válida e habilitada.
func _cursor_ok() -> bool:
	return entry_enabled(cursor)

func _render_list(show_cursor: bool = true) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	for i: int in _entries.size():
		var l := Label.new()
		var selected: bool = show_cursor and i == cursor
		l.text = ("> " if selected else "  ") + _entries[i]
		l.add_theme_font_size_override("font_size", 17)
		var color: Color = TEXT_COLOR if _enabled[i] else DISABLED_COLOR
		if selected and _enabled[i]:
			color = CURSOR_COLOR
		l.add_theme_color_override("font_color", color)
		_list.add_child(l)

func _hero_name(h: HeroState) -> String:
	return h.def.display_name

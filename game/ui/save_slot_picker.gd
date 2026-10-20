class_name SaveSlotPicker
extends VBoxContainer

## Escolha de slot (1..3) para salvar ou carregar. Salvar sobre um slot ocupado pede confirmação.
## Quem hospeda roteia o teclado para handle_input (ou chama move/accept/cancel) e escuta `chosen`/`cancelled`.

signal chosen(slot: int)
signal cancelled

enum Mode { SAVE, LOAD }

const MAP_NAMES: Dictionary[String, String] = {"overworld": "Mapa-múndi", "area_teste": "Área de teste", "dungeon_teste": "Dungeon de teste"}
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(0.45, 0.45, 0.5)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)
const MESSAGE_COLOR: Color = Color(0.95, 0.75, 0.45)

var mode: Mode = Mode.SAVE
## Índice 0-based do slot sob o cursor.
var cursor: int = 0
var confirming: bool = false

var _store: SaveStore
var _summaries: Array[Dictionary] = []
var _list: VBoxContainer
var _message: Label

func _init() -> void:
	add_theme_constant_override("separation", 6)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	add_child(_list)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 14)
	_message.add_theme_color_override("font_color", MESSAGE_COLOR)
	add_child(_message)

func open(store: SaveStore, m: Mode) -> void:
	_store = store
	mode = m
	cursor = 0
	confirming = false
	refresh()

## Relê os resumos dos slots e redesenha.
func refresh() -> void:
	_summaries = []
	for slot: int in range(1, SaveStore.SLOTS + 1):
		_summaries.append(_store.summary(slot) if _store != null else {"status": SaveStore.Status.EMPTY})
	_message.text = ""
	_render()

func slot_count() -> int:
	return _summaries.size()

func slot_text(i: int) -> String:
	return describe(i + 1, _summaries[i])

func slot_enabled(i: int) -> bool:
	if i < 0 or i >= _summaries.size():
		return false
	return mode == Mode.SAVE or int(_summaries[i]["status"]) == SaveStore.Status.OK

func message() -> String:
	return _message.text

func move(delta: int) -> void:
	if _summaries.is_empty():
		return
	cursor = posmod(cursor + delta, _summaries.size())
	confirming = false
	_message.text = ""
	_render()

func accept() -> void:
	if not slot_enabled(cursor):
		return
	var occupied: bool = int(_summaries[cursor]["status"]) != SaveStore.Status.EMPTY
	if mode == Mode.SAVE and occupied and not confirming:
		confirming = true
		_message.text = "Sobrescrever o slot %d? Enter: sim   Esc: não" % (cursor + 1)
		return
	confirming = false
	chosen.emit(cursor + 1)

## Desfaz a confirmação (devolve true) ou, sem nada a desfazer, avisa `cancelled` (devolve false).
func cancel() -> bool:
	if confirming:
		confirming = false
		_message.text = ""
		return true
	cancelled.emit()
	return false

## Mensagem de resultado (ex.: "Salvo no slot 1.") até o próximo movimento.
func say(text: String) -> void:
	_message.text = text

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		move(-1)
	elif event.is_action_pressed("ui_down"):
		move(1)
	elif event.is_action_pressed("ui_accept"):
		accept()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
	else:
		return false
	return true

static func describe(slot: int, summary: Dictionary) -> String:
	match int(summary["status"]):
		SaveStore.Status.OK:
			var map: String = str(summary["map"])
			return "Slot %d: %s  Nv %d  %s  %s" % [slot, str(summary["leader"]), int(summary["level"]),
					format_time(float(summary["play_time"])), MAP_NAMES.get(map, map)]
		SaveStore.Status.CORRUPT:
			return "Slot %d: Dados corrompidos" % slot
	return "Slot %d: Vazio" % slot

static func format_time(seconds: float) -> String:
	var t: int = int(seconds)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]

func _render() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	for i: int in _summaries.size():
		var l := Label.new()
		var selected: bool = i == cursor
		l.text = ("> " if selected else "  ") + slot_text(i)
		l.add_theme_font_size_override("font_size", 17)
		var color: Color = TEXT_COLOR if slot_enabled(i) else DISABLED_COLOR
		if selected and slot_enabled(i):
			color = CURSOR_COLOR
		l.add_theme_color_override("font_color", color)
		_list.add_child(l)

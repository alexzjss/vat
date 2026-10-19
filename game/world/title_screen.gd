class_name TitleScreen
extends CanvasLayer

## Tela de título (camada 8: acima do mapa, abaixo do Fade): Novo jogo / Continuar / Sair.
## Continuar abre a lista dos 3 slots; fica desabilitado sem nenhum slot válido.

signal new_game_requested
signal continue_requested(slot: int)
signal quit_requested

const ENTRIES: Array[String] = ["Novo jogo", "Continuar", "Sair"]
const CONTINUE_INDEX: int = 1
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(0.45, 0.45, 0.5)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)

var cursor: int = 0
var picker: SaveSlotPicker

var _store: SaveStore
var _labels: Array[Label] = []
var _menu_box: VBoxContainer

func _init() -> void:
	layer = 8
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "RPG de Teste"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", CURSOR_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_menu_box = VBoxContainer.new()
	box.add_child(_menu_box)
	for e: String in ENTRIES:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 24)
		_menu_box.add_child(l)
		_labels.append(l)
	picker = SaveSlotPicker.new()
	picker.visible = false
	picker.chosen.connect(func(slot: int) -> void: continue_requested.emit(slot))
	picker.cancelled.connect(_close_picker)
	box.add_child(picker)
	var hint := Label.new()
	hint.text = "Cima/baixo: mover   Enter: escolher   Esc: voltar"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	box.add_child(hint)
	_render()

func setup(store: SaveStore) -> void:
	_store = store
	cursor = 0
	_render()

func entry_enabled(i: int) -> bool:
	return i != CONTINUE_INDEX or (_store != null and _store.has_any_valid())

func picking() -> bool:
	return picker.visible

func move(delta: int) -> void:
	if picking():
		picker.move(delta)
		return
	cursor = posmod(cursor + delta, ENTRIES.size())
	_render()

func accept() -> void:
	if picking():
		picker.accept()
		return
	if not entry_enabled(cursor):
		return
	match cursor:
		0:
			new_game_requested.emit()
		CONTINUE_INDEX:
			picker.open(_store, SaveSlotPicker.Mode.LOAD)
			picker.visible = true
			_menu_box.visible = false
		_:
			quit_requested.emit()

func cancel() -> void:
	if picking():
		picker.cancel()

func _close_picker() -> void:
	picker.visible = false
	_menu_box.visible = true
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		move(-1)
	elif event.is_action_pressed("ui_down"):
		move(1)
	elif event.is_action_pressed("ui_accept"):
		accept()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()

func _render() -> void:
	for i: int in _labels.size():
		var selected: bool = i == cursor
		_labels[i].text = ("> " if selected else "  ") + ENTRIES[i]
		var color: Color = CURSOR_COLOR if selected else TEXT_COLOR
		if not entry_enabled(i):
			color = DISABLED_COLOR
		_labels[i].add_theme_color_override("font_color", color)

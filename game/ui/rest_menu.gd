class_name RestMenu
extends CanvasLayer

## Menu do ponto de descanso (camada 6: acima do menu de campo, abaixo do Fade):
## "Descansar e salvar" (cura todo o roster, grava o ponto e abre os slots), "Reiniciar atributos"
## (gasta um Cristal de Reinício num herói) e "Sair". O mapa fica congelado enquanto aberto.
## Com `price` > 0 (pousada, M12) é o mesmo menu, mas "Descansar e salvar" cobra o preço; sem moeda, recusa.

signal closed

enum Stage { MAIN, PICK_HERO, SLOTS }

const ENTRIES: Array[String] = ["Descansar e salvar", "Reiniciar atributos", "Sair"]
const REST_INDEX: int = 0
const RESET_INDEX: int = 1
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(0.45, 0.45, 0.5)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)
const MESSAGE_COLOR: Color = Color(0.95, 0.75, 0.45)

var game: Game
var is_open: bool = false
var stage: Stage = Stage.MAIN
var cursor: int = 0
var picker: SaveSlotPicker
## Preço do descanso (0 = ponto de descanso grátis; > 0 = pousada).
var price: int = 0

var _list: VBoxContainer
var _title: Label
var _message: Label
var _root: Control

func _init() -> void:
	layer = 6
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.16, 0.95)
	style.border_color = Color(0.35, 0.4, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", CURSOR_COLOR)
	box.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)
	picker = SaveSlotPicker.new()
	picker.visible = false
	picker.chosen.connect(_on_slot_chosen)
	picker.cancelled.connect(_back_from_slots)
	box.add_child(picker)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 14)
	_message.add_theme_color_override("font_color", MESSAGE_COLOR)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)

func open(g: Game, p_price: int = 0) -> void:
	game = g
	price = p_price
	is_open = true
	visible = true
	_go(Stage.MAIN)
	_message.text = ""

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()

func message() -> String:
	return _message.text

## Linhas da lista atual (entradas do menu ou heróis).
func entries() -> PackedStringArray:
	var out := PackedStringArray()
	if stage == Stage.PICK_HERO:
		for h: HeroState in game.state.roster():
			out.append("%s  (pontos distribuídos: %d)" % [h.def.display_name, h.allocated_total()])
	elif stage == Stage.MAIN:
		out.append_array(ENTRIES)
	return out

func entry_enabled(i: int) -> bool:
	match stage:
		Stage.MAIN:
			if i == REST_INDEX:
				return game.state.money >= price
			return i != RESET_INDEX or crystals() > 0
		Stage.PICK_HERO:
			var roster: Array[HeroState] = game.state.roster()
			return i >= 0 and i < roster.size() and roster[i].allocated_total() > 0
	return false

func crystals() -> int:
	return game.state.inventory.available(GameState.RESET_ITEM_ID)

func move(delta: int) -> void:
	if stage == Stage.SLOTS:
		picker.move(delta)
		return
	var n: int = entries().size()
	if n > 0:
		cursor = posmod(cursor + delta, n)
	_message.text = ""
	_render()

func accept() -> void:
	match stage:
		Stage.SLOTS:
			picker.accept()
		Stage.PICK_HERO:
			_reset_hero()
		_:
			_accept_main()

## Volta um passo (seletor de slots/lista de heróis → menu) ou fecha o menu.
func cancel() -> void:
	match stage:
		Stage.SLOTS:
			picker.cancel()
		Stage.PICK_HERO:
			_go(Stage.MAIN, RESET_INDEX)
		_:
			close()

func _accept_main() -> void:
	if not entry_enabled(cursor):
		_message.text = ("Você não tem %s suficientes." % game.state.cfg.currency_name) if cursor == REST_INDEX 				else "Você não tem Cristal de Reinício."
		return
	match cursor:
		REST_INDEX:
			if price > 0:
				game.state.spend_money(price)
			game.rest_here()
			_go(Stage.SLOTS)
			_message.text = "Todos descansaram. Escolha o slot para salvar (Esc: não salvar)."
		RESET_INDEX:
			_go(Stage.PICK_HERO)
		_:
			close()

func _reset_hero() -> void:
	var roster: Array[HeroState] = game.state.roster()
	if not entry_enabled(cursor):
		_message.text = "Esse herói não tem atributos para reiniciar."
		return
	var h: HeroState = roster[cursor]
	if game.state.reset_attributes(h):
		_go(Stage.MAIN, RESET_INDEX)
		_message.text = "%s: atributos reiniciados (%d pontos para distribuir)." % [h.def.display_name, h.pending_points]

func _on_slot_chosen(slot: int) -> void:
	var ok: bool = game.save_to_slot(slot)
	picker.refresh()
	picker.say("Salvo no slot %d." % slot if ok else "Não foi possível salvar.")

func _go(s: Stage, at: int = 0) -> void:
	stage = s
	cursor = at
	picker.visible = s == Stage.SLOTS
	_list.visible = s != Stage.SLOTS
	if s == Stage.SLOTS:
		picker.open(game.store, SaveSlotPicker.Mode.SAVE)
	var base: String = "Ponto de descanso" if price <= 0 else "Pousada (%s: %d)" % [game.state.cfg.currency_name, game.state.money]
	_title.text = base if s != Stage.PICK_HERO else "Reiniciar atributos de quem?"
	_message.text = ""
	_render()

func _back_from_slots() -> void:
	if stage == Stage.SLOTS:
		_go(Stage.MAIN)

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

func _render() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	if stage == Stage.SLOTS:
		return
	var texts: PackedStringArray = entries()
	for i: int in texts.size():
		var l := Label.new()
		var selected: bool = i == cursor
		l.text = ("> " if selected else "  ") + texts[i]
		if stage == Stage.MAIN and i == RESET_INDEX:
			l.text += "  (Cristais: %d)" % crystals()
		if stage == Stage.MAIN and i == REST_INDEX and price > 0:
			l.text += "  (%d %s)" % [price, game.state.cfg.currency_name]
		l.add_theme_font_size_override("font_size", 18)
		var color: Color = TEXT_COLOR
		if not entry_enabled(i):
			color = DISABLED_COLOR
		elif selected:
			color = CURSOR_COLOR
		l.add_theme_color_override("font_color", color)
		_list.add_child(l)

class_name ObstacleMenu
extends CanvasLayer

## Escolha do herói que desfaz um ElementalObstacle (M15), camada 6 (a mesma do descanso e da loja: acima do menu de
## campo, abaixo do Fade). Lista os heróis do grupo que sabem uma técnica do elemento, com o custo de AP; quem não tem
## AP (ou está caído) aparece apagado e não pode ser escolhido. Enter escolhe, Esc cancela sem gastar nada.
## O mapa fica congelado enquanto aberto; a entrada é toda consumida aqui.

signal closed

const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(0.45, 0.45, 0.5)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)
const MESSAGE_COLOR: Color = Color(0.95, 0.75, 0.45)

var obstacle: ElementalObstacle
var is_open: bool = false
var cursor: int = 0

var _options: Array[ElementalObstacle.Option] = []
var _title: Label
var _list: VBoxContainer
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
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 14)
	_message.add_theme_color_override("font_color", MESSAGE_COLOR)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)

func open(o: ElementalObstacle) -> void:
	obstacle = o
	_options = o.options()
	is_open = true
	visible = true
	cursor = 0
	for i: int in _options.size():
		if _options[i].enabled:
			cursor = i
			break
	_title.text = "%s: quem usa a técnica?" % (o.element.display_name if o.element != null else "Obstáculo")
	_message.text = ""
	_render()

func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	closed.emit()

func message() -> String:
	return _message.text

func title_text() -> String:
	return _title.text

## Uma linha por herói: "Nome  Técnica  (AP custo, tem N)".
func entries() -> PackedStringArray:
	var out := PackedStringArray()
	for o: ElementalObstacle.Option in _options:
		out.append("%s  %s  (AP %d, tem %d)%s" % [o.hero.def.display_name, o.ability.display_name, o.ability.ap_cost, o.hero.ap, "  caído" if o.hero.hp <= 0 else ""])
	return out

func entry_enabled(i: int) -> bool:
	return i >= 0 and i < _options.size() and _options[i].enabled

func move(delta: int) -> void:
	if _options.is_empty():
		return
	cursor = posmod(cursor + delta, _options.size())
	_message.text = ""
	_render()

## Escolhe o herói sob o cursor: fecha o menu (o mapa volta) e então o obstáculo gasta o AP, grava a flag e fala.
func accept() -> void:
	if not entry_enabled(cursor):
		_message.text = "Sem AP suficiente para essa técnica."
		return
	var o: ElementalObstacle = obstacle
	var h: HeroState = _options[cursor].hero
	close()
	o.unlock(h)

func cancel() -> void:
	close()

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
	var texts: PackedStringArray = entries()
	for i: int in texts.size():
		var l := Label.new()
		var selected: bool = i == cursor
		l.text = ("> " if selected else "  ") + texts[i]
		l.add_theme_font_size_override("font_size", 18)
		var color: Color = TEXT_COLOR
		if not entry_enabled(i):
			color = DISABLED_COLOR
		elif selected:
			color = CURSOR_COLOR
		l.add_theme_color_override("font_color", color)
		_list.add_child(l)

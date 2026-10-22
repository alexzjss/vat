class_name ShopMenu
extends CanvasLayer

## Menu da loja (M12), camada 6 (mesma do descanso: acima do menu de campo, abaixo do Fade).
## Raiz: Comprar / Vender / Sair. Nas listas, ↑/↓ escolhe, ←/→ muda a quantidade, Enter confirma e Esc volta.
## Comprar lista o estoque da `ShopDef`; equipamento mostra, para cada herói que pode vesti-lo, os atributos
## que mudam (EquipmentRules.preview). Vender lista o que está no inventário e na mochila (o equipamento vestido não
## entra, e item-chave e preço 0 não vendem; regras em ShopRules). O mapa fica congelado enquanto aberto; a
## entrada é toda consumida aqui, então nada vaza para o mapa.

signal closed

enum Stage { MAIN, BUY, SELL }

const ENTRIES: Array[String] = ["Comprar", "Vender", "Sair"]
const BUY_INDEX: int = 0
const SELL_INDEX: int = 1
const TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(0.45, 0.45, 0.5)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)
const MESSAGE_COLOR: Color = Color(0.95, 0.75, 0.45)

var game: Game
var shop: ShopDef
var is_open: bool = false
var stage: Stage = Stage.MAIN
var cursor: int = 0
## Unidades da compra/venda sob o cursor (1..máximo possível).
var quantity: int = 1

## Mercadoria da lista atual (comprar: o estoque; vender: o que a loja compraria).
var _goods: Array[Resource] = []
var _title: Label
var _money: Label
var _list: VBoxContainer
var _detail: VBoxContainer
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
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", CURSOR_COLOR)
	box.add_child(_title)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 15)
	box.add_child(_money)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 1)
	box.add_child(_detail)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 14)
	_message.add_theme_color_override("font_color", MESSAGE_COLOR)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)
	var hint := Label.new()
	hint.text = "↑/↓: escolher   ←/→: quantidade   Enter: confirmar   Esc: voltar"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	box.add_child(hint)

func open(g: Game, s: ShopDef) -> void:
	game = g
	shop = s
	is_open = true
	visible = true
	_go(Stage.MAIN)

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

## Linha da moeda ("Moedas: 35").
func money_text() -> String:
	return _money.text

## Linhas da lista atual (raiz, estoque ou o que dá para vender).
func entries() -> PackedStringArray:
	var out := PackedStringArray()
	if stage == Stage.MAIN:
		out.append_array(ENTRIES)
		return out
	for i: int in _goods.size():
		out.append(_line(i))
	return out

func entry_enabled(i: int) -> bool:
	match stage:
		Stage.MAIN:
			return true
		Stage.BUY:
			return i >= 0 and i < _goods.size() and ShopRules.max_buy(game.state, _goods[i]) > 0
		Stage.SELL:
			return i >= 0 and i < _goods.size() and ShopRules.max_sell(game.state, _goods[i]) > 0
	return false

## Mercadoria sob o cursor (null na raiz ou com a lista vazia).
func current_good() -> Resource:
	if stage == Stage.MAIN or cursor < 0 or cursor >= _goods.size():
		return null
	return _goods[cursor]

## Unidades máximas da mercadoria `i` na lista atual.
func max_quantity(i: int) -> int:
	if i < 0 or i >= _goods.size():
		return 0
	return ShopRules.max_buy(game.state, _goods[i]) if stage == Stage.BUY else ShopRules.max_sell(game.state, _goods[i])

## Comparação do equipamento sob o cursor (só na compra): uma linha por herói que pode vesti-lo,
## com os atributos que mudam; "sem mudança" se nenhum muda.
func compare_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var e: EquipmentDef = current_good() as EquipmentDef
	if stage != Stage.BUY or e == null:
		return out
	for h: HeroState in game.state.roster():
		if not EquipmentRules.can_equip(h.def, e, e.slot):
			continue
		var p: Dictionary = EquipmentRules.preview(h, e.slot, e, game.state.cfg)
		var changes: PackedStringArray = PackedStringArray()
		for k: StringName in EquipmentRules.PREVIEW_KEYS:
			var pair: Array = p[k]
			if int(pair[0]) != int(pair[1]):
				changes.append("%s %d → %d" % [EquipPage.PREVIEW_LABELS[k], int(pair[0]), int(pair[1])])
		out.append("%s: %s" % [h.def.display_name, ", ".join(changes) if not changes.is_empty() else "sem mudança"])
	return out

func move(delta: int) -> void:
	var n: int = ENTRIES.size() if stage == Stage.MAIN else _goods.size()
	if n > 0:
		cursor = posmod(cursor + delta, n)
	quantity = 1
	_message.text = ""
	_render()

## Muda a quantidade (←/→) dentro de 1..máximo possível da mercadoria sob o cursor.
func adjust(delta: int) -> void:
	if stage == Stage.MAIN:
		return
	quantity = clampi(quantity + delta, 1, maxi(1, max_quantity(cursor)))
	_message.text = ""
	_render()

func accept() -> void:
	match stage:
		Stage.MAIN:
			match cursor:
				BUY_INDEX:
					_go(Stage.BUY)
				SELL_INDEX:
					_go(Stage.SELL)
				_:
					close()
		Stage.BUY:
			_buy()
		Stage.SELL:
			_sell()

## Volta um passo (lista → raiz) ou fecha a loja.
func cancel() -> void:
	if stage == Stage.MAIN:
		close()
	else:
		_go(Stage.MAIN, BUY_INDEX if stage == Stage.BUY else SELL_INDEX)

func _buy() -> void:
	var def: Resource = current_good()
	if def == null:
		return
	var cur: String = game.state.cfg.currency_name
	if not entry_enabled(cursor):
		if ShopRules.price_of(def) > game.state.money:
			_message.text = "Você não tem %s suficientes." % cur
		else:
			_message.text = "Você já tem o máximo (%d) disso." % game.state.cfg.max_stack
		return
	var n: int = quantity
	var total: int = ShopRules.price_of(def) * n
	if ShopRules.buy(game.state, def, n):
		quantity = 1
		_refresh_goods()
		_message.text = "Comprou %s x%d (-%d %s)." % [_name(def), n, total, cur]
		_render()

func _sell() -> void:
	var def: Resource = current_good()
	if def == null:
		_message.text = "Nada para vender."
		return
	if not entry_enabled(cursor):
		_message.text = "Isso não pode ser vendido."
		return
	var n: int = quantity
	var gain: int = ShopRules.sell_value(def, game.state.cfg) * n
	if ShopRules.sell(game.state, def, n):
		quantity = 1
		_refresh_goods()
		_message.text = "Vendeu %s x%d (+%d %s)." % [_name(def), n, gain, game.state.cfg.currency_name]
		_render()

func _go(s: Stage, at: int = 0) -> void:
	stage = s
	cursor = at
	quantity = 1
	_message.text = ""
	_refresh_goods()
	match s:
		Stage.MAIN:
			_title.text = shop.display_name if shop != null and shop.display_name != "" else "Loja"
		Stage.BUY:
			_title.text = "Comprar"
		Stage.SELL:
			_title.text = "Vender"
			if _goods.is_empty():
				_message.text = "Nada para vender."
	_render()

## Remonta a lista da etapa atual; o cursor e a quantidade ficam dentro dos limites.
func _refresh_goods() -> void:
	_goods = []
	if stage == Stage.BUY and shop != null:
		for it: ItemDef in shop.items:
			if it != null:
				_goods.append(it)
		for e: EquipmentDef in shop.equipment:
			if e != null:
				_goods.append(e)
	elif stage == Stage.SELL:
		_goods = ShopRules.sellable(game.state)
	if stage != Stage.MAIN:
		cursor = clampi(cursor, 0, maxi(0, _goods.size() - 1))
		quantity = clampi(quantity, 1, maxi(1, max_quantity(cursor)))

func _name(def: Resource) -> String:
	if def is ItemDef:
		return (def as ItemDef).display_name
	return (def as EquipmentDef).display_name

func _line(i: int) -> String:
	var def: Resource = _goods[i]
	var cur: String = game.state.cfg.currency_name
	var have: int = ShopRules.owned(game.state, def)
	if stage == Stage.BUY:
		var text: String = "%s — %d %s  (tem %d)" % [_name(def), ShopRules.price_of(def), cur, have]
		if i == cursor:
			text += "   < %d >  = %d %s" % [quantity, ShopRules.price_of(def) * quantity, cur]
		return text
	var each: int = ShopRules.sell_value(def, game.state.cfg)
	var text2: String = "%s x%d — vende %d %s cada" % [_name(def), have, each, cur]
	if i == cursor:
		text2 += "   < %d >  = %d %s" % [quantity, each * quantity, cur]
	return text2

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
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
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_menu"):
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()

func _render() -> void:
	_money.text = "%s: %d" % [game.state.cfg.currency_name, game.state.money]
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
	for child: Node in _detail.get_children():
		_detail.remove_child(child)
		child.free()
	for line: String in compare_lines():
		var d := Label.new()
		d.text = line
		d.add_theme_font_size_override("font_size", 14)
		d.add_theme_color_override("font_color", TEXT_COLOR)
		_detail.add_child(d)

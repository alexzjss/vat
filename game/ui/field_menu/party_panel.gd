class_name PartyPanel
extends VBoxContainer

## Painel do grupo no menu de campo: um cartão grande por ativo e cartões menores para a reserva.
## Modo de seleção (begin_pick/pick_move/pick_accept/end_pick) destaca um herói habilitado pelo filtro;
## o teclado fica com quem abriu o modo (páginas do FieldMenu), que chama os métodos programáticos.

signal hero_picked(h: HeroState)

const NAME_COLOR: Color = Color(1.0, 1.0, 1.0)
const DIM_COLOR: Color = Color(0.45, 0.45, 0.5)
const DOWNED_COLOR: Color = Color(0.9, 0.35, 0.35)
const PENDING_COLOR: Color = Color(0.5, 0.9, 0.5)
const FIELD_STATUS_COLOR: Color = Color(0.7, 0.45, 0.9)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)
const HP_BAR_COLOR: Color = Color(0.3, 0.8, 0.4)
const AP_BAR_COLOR: Color = Color(0.35, 0.55, 0.95)
const LIMIT_BAR_COLOR: Color = Color(0.95, 0.6, 0.2)

var state: GameState
var picking: bool = false

var _heroes: Array[HeroState] = []
var _cards: Array[PanelContainer] = []
var _texts: Array[String] = []
var _active_count: int = 0
var _filter: Callable
var _pick_index: int = -1
var _active_box: VBoxContainer
var _reserve_title: Label
var _reserve_box: GridContainer
var _money_label: Label

func _init() -> void:
	add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "Grupo"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", CURSOR_COLOR)
	add_child(title)
	_active_box = VBoxContainer.new()
	_active_box.add_theme_constant_override("separation", 6)
	add_child(_active_box)
	_reserve_title = Label.new()
	_reserve_title.text = "Reserva"
	_reserve_title.add_theme_font_size_override("font_size", 14)
	_reserve_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	add_child(_reserve_title)
	_reserve_box = GridContainer.new()
	_reserve_box.columns = 2
	_reserve_box.add_theme_constant_override("h_separation", 6)
	_reserve_box.add_theme_constant_override("v_separation", 6)
	add_child(_reserve_box)
	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 16)
	_money_label.add_theme_color_override("font_color", CURSOR_COLOR)
	add_child(_money_label)

func refresh(s: GameState) -> void:
	state = s
	_heroes = s.roster()
	_active_count = s.heroes.size()
	for c: PanelContainer in _cards:
		c.get_parent().remove_child(c)
		c.queue_free()
	_cards = []
	_texts = []
	for i: int in _heroes.size():
		var small: bool = i >= _active_count
		var card: PanelContainer = _make_card(_heroes[i], small)
		_cards.append(card)
		(_reserve_box if small else _active_box).add_child(card)
	_reserve_title.visible = _heroes.size() > _active_count
	_money_label.text = "%s: %d" % [s.cfg.currency_name, s.money]
	if picking:
		if _pick_index < 0 or _pick_index >= _heroes.size() or not _enabled(_pick_index):
			_pick_index = _first_enabled_from(0, 1)
	_render_pick()

## Linha da moeda do grupo ("Moedas: 35"), atualizada em refresh.
func money_text() -> String:
	return _money_label.text

func active_card_count() -> int:
	return _active_count

func reserve_card_count() -> int:
	return _heroes.size() - _active_count

## Texto completo do cartão i (ordem do roster: ativos, depois reserva).
func card_text(i: int) -> String:
	return _texts[i] if i >= 0 and i < _texts.size() else ""

func begin_pick(filter: Callable) -> void:
	picking = true
	_filter = filter
	_pick_index = _first_enabled_from(0, 1)
	_render_pick()

func pick_move(delta: int) -> void:
	if not picking or _pick_index < 0 or delta == 0:
		return
	var step: int = 1 if delta > 0 else -1
	for _n: int in absi(delta):
		_pick_index = _first_enabled_from(_pick_index + step, step)
	_render_pick()

func picked() -> HeroState:
	if not picking or _pick_index < 0:
		return null
	return _heroes[_pick_index]

func pick_accept() -> void:
	var h: HeroState = picked()
	if h != null:
		hero_picked.emit(h)

func end_pick() -> void:
	picking = false
	_filter = Callable()
	_pick_index = -1
	_render_pick()

## Se o herói i (ordem do roster) pode ser escolhido no modo de seleção atual.
func is_pick_enabled(i: int) -> bool:
	return picking and i >= 0 and i < _heroes.size() and _enabled(i)

func _enabled(i: int) -> bool:
	return not _filter.is_valid() or bool(_filter.call(_heroes[i]))

## Primeiro índice habilitado a partir de `start` andando em `step`, com volta circular; -1 se nenhum.
func _first_enabled_from(start: int, step: int) -> int:
	var n: int = _heroes.size()
	for k: int in n:
		var i: int = posmod(start + k * step, n)
		if _enabled(i):
			return i
	return -1

func _render_pick() -> void:
	for i: int in _cards.size():
		var style: StyleBoxFlat = _cards[i].get_theme_stylebox("panel") as StyleBoxFlat
		var selected: bool = picking and i == _pick_index
		style.border_color = CURSOR_COLOR if selected else Color(0.35, 0.4, 0.55)
		_cards[i].modulate = Color(1, 1, 1, 0.45) if picking and not _enabled(i) else Color(1, 1, 1, 1)

func _make_card(h: HeroState, small: bool) -> PanelContainer:
	var c := Combatant.from_hero(h, Vector2.ZERO)
	var hp_max: int = StatCalculator.hp_max(c, state.cfg)
	var ap_max: int = StatCalculator.ap_max(c, state.cfg)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.15, 0.21, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6.0 if small else 8.0)
	card.add_theme_stylebox_override("panel", style)
	if small:
		card.custom_minimum_size = Vector2(190.0, 0.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var fs: int = 13 if small else 16
	var parts: PackedStringArray = PackedStringArray()

	var top := HBoxContainer.new()
	box.add_child(top)
	var name_text: String = "%s  Nv %d" % [h.def.display_name, h.level]
	parts.append(name_text)
	top.add_child(_label(name_text, fs, NAME_COLOR, true))
	if h.hp <= 0:
		parts.append("Caído")
		top.add_child(_label("Caído", fs, DOWNED_COLOR, false))
	# Estados persistentes (M15): "VEN" no herói envenenado.
	for sid: StringName in h.field_statuses:
		var st: String = _field_status_label(sid)
		parts.append(st)
		top.add_child(_label(st, fs, FIELD_STATUS_COLOR, false))
	if h.pending_points > 0:
		var pts: String = "+%d pts" % h.pending_points
		parts.append(pts)
		top.add_child(_label(pts, fs, PENDING_COLOR, false))

	var hp_text: String = "HP %d/%d" % [h.hp, hp_max]
	var ap_text: String = "AP %d/%d" % [h.ap, ap_max]
	parts.append(hp_text)
	parts.append(ap_text)
	var limit_text: String = "Limite %d%%" % roundi(h.limit * 100.0)
	parts.append(limit_text)
	if small:
		box.add_child(_label("%s   %s   %s" % [hp_text, ap_text, limit_text], fs - 1, Color(0.8, 0.82, 0.9), false))
	else:
		box.add_child(_bar_row(hp_text, h.hp, hp_max, HP_BAR_COLOR))
		box.add_child(_bar_row(ap_text, h.ap, ap_max, AP_BAR_COLOR))
		box.add_child(_bar_row(limit_text, roundi(h.limit * 100.0), 100, LIMIT_BAR_COLOR))
	_texts.append(" ".join(parts))
	return card

## Rótulo curto do estado persistente (o mesmo do HUD da batalha); o id em maiúsculas se o estado é desconhecido.
func _field_status_label(id: StringName) -> String:
	var d: StatusDef = state.cfg.persistent_status(id)
	return CombatantView.STATUS_LABELS.get(d.kind, String(id).to_upper()) if d != null else String(id).to_upper()

func _bar_row(text: String, value: int, max_value: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l: Label = _label(text, 14, Color(0.85, 0.87, 0.93), false)
	l.custom_minimum_size = Vector2(110.0, 0.0)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxf(1.0, float(max_value))
	bar.value = float(value)
	bar.custom_minimum_size = Vector2(0.0, 10.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.12)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	row.add_child(bar)
	return row

func _label(text: String, size: int, color: Color, expand: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

class_name CommandMenu
extends PanelContainer

## Menu de comandos do herói: raiz (Atacar/Habilidade/Item/Suporte), submenus e etapa de alvo.
## Toda decisão passa por SelectionSession; o menu só apresenta e encaminha.
## O teclado (_unhandled_input) chama move/accept/cancel, que também servem aos testes.

signal submitted(a: PendingAction)

enum Mode { CLOSED, ROOT, ABILITIES, ITEMS, SUPPORT_HEROES, SUPPORT_ACTIONS, TARGET }
enum Kind { ATTACK, ABILITIES, ITEMS, ABILITY, ITEM, LIMIT, SUPPORT, SUPPORT_HERO }

const ENABLED_COLOR: Color = Color(1.0, 1.0, 1.0)
const DISABLED_COLOR: Color = Color(0.45, 0.45, 0.5)
const CURSOR_COLOR: Color = Color(1.0, 0.85, 0.3)

class Entry:
	extends RefCounted
	var label: String
	var enabled: bool
	var kind: CommandMenu.Kind
	var ability: AbilityDef
	var item: ItemDef
	var hero: HeroState

	func _init(p_label: String, p_enabled: bool, p_kind: CommandMenu.Kind) -> void:
		label = p_label
		enabled = p_enabled
		kind = p_kind

var ctrl: BattleController
var preview: TargetPreview
var session: SelectionSession
var mode: Mode = Mode.CLOSED
var cursor: int = 0
var target_index: int = 0
## Memória do cursor (Config): lembra o último comando da raiz de cada herói (por def.id) durante a batalha.
var remember_cursor: bool = false

## Nível do menu (ROOT/ABILITIES/ITEMS) e cursor de onde o comando atual foi escolhido;
## Cancelar na etapa de alvo (ou "Sem alvos válidos") volta para lá (spec §4.4: um nível).
var _origin_mode: Mode = Mode.ROOT
var _origin_cursor: int = 0
var _entries: Array[Entry] = []
var _candidates: Array[Combatant] = []
var _last_root: Dictionary[StringName, int] = {}
var _title: Label
var _header: Label
var _list: VBoxContainer
var _hint: Label

func _init() -> void:
	visible = false
	custom_minimum_size = Vector2(280.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.16, 0.95)
	style.border_color = Color(0.35, 0.4, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12.0)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", CURSOR_COLOR)
	box.add_child(_title)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 14)
	_header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	box.add_child(_header)
	_list = VBoxContainer.new()
	box.add_child(_list)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	box.add_child(_hint)

func open(s: SelectionSession) -> void:
	session = s
	visible = true
	_show_root(_remembered_root())

func close() -> void:
	mode = Mode.CLOSED
	session = null
	visible = false
	_candidates = []
	if preview != null:
		preview.hide_preview()

## Silêncio no meio da escolha: volta à raiz (a sessão já desfez a técnica) e reavalia as entradas.
func reset_to_root() -> void:
	if session == null or mode == Mode.CLOSED:
		return
	_show_root(0)

func actor_name() -> String:
	return session.actor.display_name if session != null else ""

func entry_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for e: Entry in _entries:
		out.append(e.label)
	return out

func entry_enabled(i: int) -> bool:
	return i >= 0 and i < _entries.size() and _entries[i].enabled

func header_text() -> String:
	return _header.text

func current_target() -> Combatant:
	if mode != Mode.TARGET or _candidates.is_empty():
		return null
	return _candidates[target_index]

func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.CLOSED or not visible:
		return
	if event.is_action_pressed("ui_up") or (mode == Mode.TARGET and event.is_action_pressed("ui_left")):
		move(-1)
	elif event.is_action_pressed("ui_down") or (mode == Mode.TARGET and event.is_action_pressed("ui_right")):
		move(1)
	elif event.is_action_pressed("ui_accept"):
		accept()
	elif event.is_action_pressed("ui_cancel"):
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()

## Move o cursor (listas) ou alterna o alvo (etapa de alvo), com volta circular.
func move(delta: int) -> void:
	match mode:
		Mode.TARGET:
			if _candidates.is_empty():
				return
			target_index = posmod(target_index + delta, _candidates.size())
			_aim()
		Mode.ROOT, Mode.ABILITIES, Mode.ITEMS, Mode.SUPPORT_HEROES, Mode.SUPPORT_ACTIONS:
			if _entries.is_empty():
				return
			cursor = posmod(cursor + delta, _entries.size())
			_render()

func accept() -> void:
	match mode:
		Mode.TARGET:
			_confirm()
		Mode.ROOT, Mode.ABILITIES, Mode.ITEMS, Mode.SUPPORT_HEROES, Mode.SUPPORT_ACTIONS:
			if not entry_enabled(cursor):
				return
			_pick(_entries[cursor])

func cancel() -> void:
	match mode:
		Mode.TARGET:
			session.back()
			_return_to_origin()
		Mode.ABILITIES:
			_show_root(1)
		Mode.ITEMS:
			_show_root(2)
		Mode.SUPPORT_HEROES:
			_show_root(3)
		Mode.SUPPORT_ACTIONS:
			session.cancel_support()
			_show_support_heroes()

func _pick(e: Entry) -> void:
	_origin_mode = mode
	_origin_cursor = cursor
	if mode == Mode.ROOT:
		_last_root[session.actor.id] = cursor
	match e.kind:
		Kind.ATTACK:
			if session.choose_ability(session.actor.basic_attack):
				_enter_target()
		Kind.LIMIT:
			if session.choose_limit():
				_enter_target()
		Kind.ABILITIES:
			_show_abilities()
		Kind.ITEMS:
			_show_items()
		Kind.SUPPORT:
			_show_support_heroes()
		Kind.SUPPORT_HERO:
			if session.choose_support(e.hero):
				_show_support_actions()
		Kind.ABILITY:
			if session.choose_ability(e.ability):
				_enter_target()
		Kind.ITEM:
			if session.choose_item(e.item):
				_enter_target()

## Cursor inicial da raiz: o último comando do herói, se a memória estiver ligada e a entrada ainda valer.
func _remembered_root() -> int:
	if not remember_cursor or not _last_root.has(session.actor.id):
		return 0
	var at: int = _last_root[session.actor.id]
	return at if _root_enabled(at) else 0

## Esquece o que foi lembrado (nova batalha).
func reset_memory() -> void:
	_last_root = {}

func _root_enabled(at: int) -> bool:
	match at:
		0:
			return session.actor.basic_attack != null
		1:
			return session.techniques_available()
		2:
			return _has_items()
		3:
			return session.can_support()
	return false

func _show_root(at: int) -> void:
	mode = Mode.ROOT
	_entries = []
	# Barra de Limite cheia: "Limite" ocupa o lugar de "Atacar" (mesma posicao, o cursor continua valendo).
	if session.actor.limit_ready():
		_entries.append(Entry.new("Limite", true, Kind.LIMIT))
	else:
		_entries.append(Entry.new("Atacar", session.actor.basic_attack != null, Kind.ATTACK))
	_entries.append(Entry.new("Habilidade", session.techniques_available(), Kind.ABILITIES))
	_entries.append(Entry.new("Item", _has_items(), Kind.ITEMS))
	_entries.append(Entry.new("Suporte", session.can_support(), Kind.SUPPORT))
	cursor = at
	if preview != null:
		preview.hide_preview()
	_render()

func _has_items() -> bool:
	for it: ItemDef in session.b.inventory.listing():
		if not it.key_item and session.b.inventory.available(it.id) > 0:
			return true
	return false

func _show_abilities(at: int = 0) -> void:
	mode = Mode.ABILITIES
	_entries = []
	for ab: AbilityDef in session.actor.abilities:
		var e := Entry.new("%s — %d AP" % [ab.display_name, ab.ap_cost], session.can_use(ab), Kind.ABILITY)
		e.ability = ab
		_entries.append(e)
	cursor = at
	_render()

## Suporte, passo 1: o reserva a chamar.
func _show_support_heroes(at: int = 0) -> void:
	mode = Mode.SUPPORT_HEROES
	_entries = []
	for h: HeroState in session.support_candidates():
		var e := Entry.new("%s — AP %d" % [h.def.display_name, h.ap], true, Kind.SUPPORT_HERO)
		e.hero = h
		_entries.append(e)
	cursor = at
	_render()

## Suporte, passo 2: ataque basico e habilidades do reserva (pagas com o AP dele).
func _show_support_actions(at: int = 0) -> void:
	mode = Mode.SUPPORT_ACTIONS
	_entries = []
	for ab: AbilityDef in session.support_abilities():
		var label: String = "Atacar" if ab == session.support.basic_attack else "%s — %d AP" % [ab.display_name, ab.ap_cost]
		var e := Entry.new(label, session.can_use(ab), Kind.ABILITY)
		e.ability = ab
		_entries.append(e)
	cursor = at
	_render()

func _show_items(at: int = 0) -> void:
	mode = Mode.ITEMS
	_entries = []
	for it: ItemDef in session.b.inventory.listing():
		if it.key_item:
			continue
		var n: int = session.b.inventory.available(it.id)
		var e := Entry.new("%s x%d" % [it.display_name, n], n > 0, Kind.ITEM)
		e.item = it
		_entries.append(e)
	cursor = at
	_render()

## Reabre o nível de onde o comando foi escolhido, com o mesmo cursor.
func _return_to_origin() -> void:
	if preview != null:
		preview.hide_preview()
	match _origin_mode:
		Mode.ABILITIES:
			_show_abilities(_origin_cursor)
		Mode.ITEMS:
			_show_items(_origin_cursor)
		Mode.SUPPORT_ACTIONS:
			_show_support_actions(_origin_cursor)
		_:
			_show_root(_origin_cursor)

func _enter_target() -> void:
	_candidates = session.target_candidates()
	if _candidates.is_empty():
		# Sem alvo válido (ex.: Reviver sem ninguém caído): desfaz (devolve AP/reserva) e fica no nível de origem.
		session.back()
		_return_to_origin()
		_header.text = "Sem alvos válidos"
		return
	mode = Mode.TARGET
	target_index = 0
	_entries = []
	if preview != null:
		preview.show_for(session)
	_aim()

func _aim() -> void:
	session.set_center(_candidates[target_index])
	if preview != null:
		preview.refresh()
	_render()

func _confirm() -> void:
	var target: Combatant = current_target()
	if target == null:
		return
	session.set_center(target)
	var a: PendingAction = session.confirm()
	if a == null:
		return
	var c: BattleController = ctrl
	close()
	submitted.emit(a)
	if c != null:
		c.submit(a)

func _command_name() -> String:
	if session.item != null:
		return session.item.display_name
	if session.ability == session.user().basic_attack:
		return "Atacar"
	return session.ability.display_name

func _render() -> void:
	if session == null:
		return
	_title.text = "%s   AP %d" % [session.actor.display_name, session.actor.ap]
	if session.support != null:
		_title.text = "%s   AP %d" % [session.support.display_name, session.support.ap]
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	match mode:
		Mode.ROOT:
			_header.text = "Comando"
			_hint.text = "Enter: escolher"
		Mode.ABILITIES:
			_header.text = "Habilidade"
			_hint.text = "Enter: escolher   Esc: voltar"
		Mode.ITEMS:
			_header.text = "Item"
			_hint.text = "Enter: escolher   Esc: voltar"
		Mode.SUPPORT_HEROES:
			_header.text = "Suporte — chamar"
			_hint.text = "Enter: escolher   Esc: voltar"
		Mode.SUPPORT_ACTIONS:
			_header.text = "Suporte — ação"
			_hint.text = "Enter: escolher   Esc: voltar"
		Mode.TARGET:
			_header.text = _command_name()
			_hint.text = "←/→: alvo   Enter: confirmar   Esc: cancelar"
			var n: int = session.preview_area().size()
			_add_line("> Alvo: %s" % _candidates[target_index].display_name, CURSOR_COLOR)
			_add_line("  Atinge: %d" % n, ENABLED_COLOR)
			return
	for i: int in _entries.size():
		var e: Entry = _entries[i]
		var prefix: String = "> " if i == cursor else "  "
		var color: Color = DISABLED_COLOR if not e.enabled else (CURSOR_COLOR if i == cursor else ENABLED_COLOR)
		_add_line(prefix + e.label, color)

func _add_line(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	_list.add_child(l)

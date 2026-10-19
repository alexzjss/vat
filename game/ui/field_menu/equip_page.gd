class_name EquipPage
extends FieldPage

## Equipar: escolher herói no painel → lista dos 4 espaços ("Arma: Nome" / "Arma: —") → itens da
## mochila que o herói pode usar nesse espaço ("Nome xN") + "Remover" se ocupado. Mover o cursor na
## lista de itens mostra a prévia (números só de EquipmentRules.preview). Confirmar equipa/remove e
## volta aos espaços. Esc volta um passo: itens → espaços → herói → raiz.

const PREVIEW_LABELS: Dictionary[StringName, String] = {
	&"strength": "Força", &"speed": "Velocidade", &"vitality": "Vitalidade", &"aura": "Aura",
	&"hp_max": "HP máx.", &"ap_max": "AP máx.",
}
const WEAPON_TYPE_LABELS: Dictionary[StringName, String] = {
	&"blade": "Lâmina", &"staff": "Bastão", &"bow": "Arco",
}
## Nome exibido dos estados (StatusDef não tem nome); ids genéricos em inglês e português.
const STATUS_NAMES: Dictionary[StringName, String] = {
	&"poison": "Veneno", &"veneno": "Veneno", &"sleep": "Sono", &"sono": "Sono",
	&"paralysis": "Paralisia", &"paralisia": "Paralisia", &"haste": "Pressa", &"pressa": "Pressa",
	&"slow": "Lentidão", &"lentidao": "Lentidão", &"barrier": "Barreira", &"barreira": "Barreira",
}
const UP_COLOR: Color = Color(0.45, 0.95, 0.45)
const DOWN_COLOR: Color = Color(1.0, 0.45, 0.45)
const REMOVE_TEXT: String = "Remover"
const EMPTY_SLOT: String = "—"

var hero: HeroState = null
var slot: StringName = &""
var _options: Array[EquipmentDef] = []
var _preview: VBoxContainer

func _init() -> void:
	super._init()
	_preview = VBoxContainer.new()
	_preview.add_theme_constant_override("separation", 1)
	add_child(_preview)

func enter() -> void:
	super.enter()
	hero = null
	slot = &""
	_begin_pick()

func leave() -> void:
	hero = null
	slot = &""
	_set_entries([] as Array[String], [] as Array[bool])
	_clear_preview()
	super.leave()

func move(delta: int) -> void:
	if hero == null:
		menu.party_panel.pick_move(delta)
		return
	super.move(delta)
	if slot != &"":
		_update_preview()

func accept() -> void:
	if hero == null:
		var h: HeroState = menu.party_panel.picked()
		if h == null:
			return
		hero = h
		menu.party_panel.end_pick()
		cursor = 0
		_show_slots()
		_say("")
	elif slot == &"":
		_open_slot(EquipmentRules.SLOTS[cursor])
	else:
		_confirm()

func cancel() -> bool:
	if hero == null:
		return false
	if slot != &"":
		var idx: int = EquipmentRules.SLOTS.find(slot)
		slot = &""
		cursor = idx
		_show_slots()
		_say("")
		return true
	hero = null
	_set_entries([] as Array[String], [] as Array[bool])
	_begin_pick()
	return true

## Linhas da prévia atual (vazio fora da lista de itens).
func preview_lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for l: Node in _preview.get_children():
		out.append((l as Label).text)
	return out

func preview_color(i: int) -> Color:
	return (_preview.get_child(i) as Label).get_theme_color("font_color")

## Item do espaço `s` em "Arma: Nome" / "Arma: —".
static func slot_line(h: HeroState, s: StringName) -> String:
	var e: EquipmentDef = h.equipment.get(s)
	return "%s: %s" % [EquipmentRules.SLOT_LABELS[s], e.display_name if e != null else EMPTY_SLOT]

static func status_name(id: StringName) -> String:
	return STATUS_NAMES.get(id, String(id).capitalize())

## "Passivos: Imune a Sono, Resiste a Veneno 50%, Começa com Pressa" (ou "Passivos: —").
static func passives_line(equipment: Dictionary[StringName, EquipmentDef]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var immune: Array[StringName] = EquipmentRules.immunities(equipment)
	for id: StringName in immune:
		parts.append("Imune a %s" % status_name(id))
	var res: Dictionary[StringName, float] = EquipmentRules.resistances(equipment)
	for id: StringName in res:
		if not immune.has(id):
			parts.append("Resiste a %s %d%%" % [status_name(id), roundi(res[id] * 100.0)])
	for st: StatusDef in EquipmentRules.start_statuses(equipment):
		parts.append("Começa com %s" % status_name(st.id))
	return "Passivos: " + (", ".join(parts) if not parts.is_empty() else EMPTY_SLOT)

func _begin_pick() -> void:
	_clear_preview()
	menu.party_panel.begin_pick(Callable())
	_say("Equipar quem?")

func _show_slots() -> void:
	_clear_preview()
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for s: StringName in EquipmentRules.SLOTS:
		texts.append(slot_line(hero, s))
		enabled.append(true)
	_set_entries(texts, enabled)

func _open_slot(s: StringName) -> void:
	_options = []
	for e: EquipmentDef in state.bag.listing():
		if EquipmentRules.can_equip(hero.def, e, s):
			_options.append(e)
	var occupied: bool = hero.equipment.get(s) != null
	if _options.is_empty() and not occupied:
		_say("Nada para equipar aqui.")
		return
	if occupied:
		_options.append(null)
	slot = s
	cursor = 0
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for e: EquipmentDef in _options:
		texts.append(REMOVE_TEXT if e == null else "%s x%d" % [e.display_name, state.bag.count(e.id)])
		enabled.append(true)
	_set_entries(texts, enabled)
	_say("")
	_update_preview()

func _confirm() -> void:
	if cursor < 0 or cursor >= _options.size():
		return
	var e: EquipmentDef = _options[cursor]
	var label: String = EquipmentRules.SLOT_LABELS[slot]
	var ok: bool = state.unequip(hero, slot) if e == null else state.equip(hero, slot, e)
	var idx: int = EquipmentRules.SLOTS.find(slot)
	slot = &""
	cursor = idx
	_show_slots()
	menu.refresh_party()
	if not ok:
		_say("Não foi possível.")
	elif e == null:
		_say("%s removido(a)." % label)
	else:
		_say("%s equipou %s." % [_hero_name(hero), e.display_name])

func _update_preview() -> void:
	_clear_preview()
	if cursor < 0 or cursor >= _options.size():
		return
	var e: EquipmentDef = _options[cursor]
	var p: Dictionary = EquipmentRules.preview(hero, slot, e, state.cfg)
	for k: StringName in EquipmentRules.PREVIEW_KEYS:
		var pair: Array = p[k]
		var before: int = pair[0]
		var after: int = pair[1]
		var color: Color = TEXT_COLOR
		if after > before:
			color = UP_COLOR
		elif after < before:
			color = DOWN_COLOR
		_add_preview("%s %d → %d" % [PREVIEW_LABELS[k], before, after], color)
	if e != null and e.weapon_type != &"":
		_add_preview("Tipo: %s" % WEAPON_TYPE_LABELS.get(e.weapon_type, String(e.weapon_type)), TEXT_COLOR)
	var eq: Dictionary[StringName, EquipmentDef] = hero.equipment.duplicate()
	if e == null:
		eq.erase(slot)
	else:
		eq[slot] = e
	_add_preview(passives_line(eq), TEXT_COLOR)

func _add_preview(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color)
	_preview.add_child(l)

func _clear_preview() -> void:
	for child: Node in _preview.get_children():
		_preview.remove_child(child)
		child.free()

class_name StatusPage
extends FieldPage

## Status: escolher um herói do roster no painel → ficha com nível, XP até o próximo nível,
## HP/AP, atributos "base + alocado = efetivo", equipamento (4 espaços + passivos) e habilidades com custo.

const ATTR_NAMES: Dictionary[StringName, String] = LevelUpScreen.ATTR_NAMES

var hero: HeroState = null
var _detail: Label

func _init() -> void:
	super._init()
	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 16)
	_detail.add_theme_color_override("font_color", TEXT_COLOR)
	add_child(_detail)
	move_child(_detail, 0)

func enter() -> void:
	super.enter()
	_begin()

func leave() -> void:
	hero = null
	_detail.text = ""
	super.leave()

func move(delta: int) -> void:
	if hero == null:
		menu.party_panel.pick_move(delta)

func accept() -> void:
	if hero != null:
		return
	var h: HeroState = menu.party_panel.picked()
	if h == null:
		return
	hero = h
	menu.party_panel.end_pick()
	_detail.text = _build_text(h)
	_say("")

func cancel() -> bool:
	if hero == null:
		return false
	hero = null
	_detail.text = ""
	_begin()
	return true

func detail_text() -> String:
	return _detail.text

func _begin() -> void:
	menu.party_panel.begin_pick(Callable())
	_say("Escolha um herói.")

func _build_text(h: HeroState) -> String:
	var cfg: BalanceConfig = state.cfg
	var c: Combatant = Combatant.from_hero(h, Vector2.ZERO)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s — Nv %d" % [_hero_name(h), h.level])
	lines.append("XP: %d / %d" % [h.xp, XpCalculator.xp_for_level(h.level + 1, cfg)])
	lines.append("HP: %d / %d" % [h.hp, StatCalculator.hp_max(c, cfg)])
	lines.append("AP: %d / %d" % [h.ap, StatCalculator.ap_max(c, cfg)])
	lines.append("Limite: %d%%" % roundi(h.limit * 100.0))
	if h.pending_points > 0:
		lines.append("Pontos a distribuir: %d" % h.pending_points)
	lines.append("")
	for attr: StringName in Stats.ATTRS:
		var base: int = h.def.base.get_attr(attr)
		var alloc: int = h.allocated.get_attr(attr)
		var equip: int = c.equipment_mods.get_attr(attr)
		var eff: int = StatCalculator.effective(c, attr, cfg)
		var line: String = "%s: %d + %d" % [ATTR_NAMES[attr], base, alloc]
		if equip != 0:
			line += " %s %d" % ["+" if equip > 0 else "-", absi(equip)]
		line += " = %d" % eff
		if base + alloc + equip != eff:
			line += " (retornos decrescentes)"
		lines.append(line)
	lines.append("")
	lines.append("Equipamento:")
	for s: StringName in EquipmentRules.SLOTS:
		lines.append("  " + EquipPage.slot_line(h, s))
	lines.append("  " + EquipPage.passives_line(h.equipment))
	lines.append("")
	lines.append("Habilidades:")
	if h.def.abilities.is_empty():
		lines.append("  (nenhuma)")
	for ab: AbilityDef in h.def.abilities:
		lines.append("  %s — %d AP" % [ab.display_name, ab.ap_cost])
	return "\n".join(lines)

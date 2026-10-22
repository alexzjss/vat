extends GutTest
## M13 Task 4: elementos na batalha (popups, menu de comandos, debug) e nos menus de campo.
## Defs em memoria; os ids dos .tres reais (kagutsuchi, indra...) dao nome curto e cor.

const VIEW_SCENE: PackedScene = preload("res://battle/combatant_view.tscn")
const MENU_SCENE: PackedScene = preload("res://ui/field_menu/field_menu.tscn")
const FIRE_ID: StringName = &"kagutsuchi"
const THUNDER_ID: StringName = &"indra"

var fire: ElementDef
var thunder: ElementDef

func before_each() -> void:
	fire = load("res://data/elements/kagutsuchi.tres") as ElementDef
	thunder = load("res://data/elements/indra.tres") as ElementDef

# --- textos puros ---------------------------------------------------------------

func test_affinity_label_text() -> void:
	assert_eq(ElementText.affinity_label(ElementMath.Affinity.NEUTRAL), "")
	assert_eq(ElementText.affinity_label(ElementMath.Affinity.WEAK), "Fraco!")
	assert_eq(ElementText.affinity_label(ElementMath.Affinity.RESIST), "Resistiu")
	assert_eq(ElementText.affinity_label(ElementMath.Affinity.IMMUNE), "Imune")
	assert_eq(ElementText.affinity_label(ElementMath.Affinity.ABSORB), "Absorveu")

func test_resist_text_lists_only_nonzero_with_sign() -> void:
	var d: Dictionary = {FIRE_ID: 0.3, THUNDER_ID: -0.5, &"atlas": 0.0}
	assert_eq(ElementText.resist_text(d), "Fogo 30%, Raio −50%")
	assert_eq(ElementText.resist_text({}), "")
	assert_eq(ElementText.resist_text({FIRE_ID: 0.0}), "")
	assert_eq(ElementText.resist_text({FIRE_ID: 1.0, THUNDER_ID: 1.5}), "Fogo 100%, Raio 150%")

func test_tag_and_natives() -> void:
	assert_eq(ElementText.tag(null), "")
	assert_eq(ElementText.tag(fire), "Fogo")
	assert_eq(ElementText.natives_text([fire, thunder] as Array[ElementDef]), "Fogo, Raio")
	assert_eq(ElementText.natives_text([] as Array[ElementDef]), "")

# --- popups na batalha ----------------------------------------------------------

func _view() -> CombatantView:
	var cfg: BalanceConfig = Fixtures.cfg()
	var c: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 0, 2, 1)), &"x", Vector2.ZERO, cfg)
	var v: CombatantView = VIEW_SCENE.instantiate() as CombatantView
	add_child_autofree(v)
	v.bind(c, cfg)
	return v

func _popups(v: CombatantView) -> Array[Label]:
	var out: Array[Label] = []
	for n: Node in v.get_children():
		if n is Label:
			out.append(n as Label)
	return out

func _texts(v: CombatantView) -> Array[String]:
	var out: Array[String] = []
	for l: Label in _popups(v):
		out.append(l.text)
	return out

func _hit(kind: EffectDef.Kind, amount: int, el: StringName, aff: int, extra: Dictionary = {}) -> Dictionary:
	var h: Dictionary = {"target_id": &"x", "kind": kind, "amount": amount, "dodged": false, "status_result": -1,
			"missed": false, "shielded": false, "element": el, "affinity": aff, "lifesteal": 0, "self_damage": 0,
			"contamination": 0, "burst": 0}
	h.merge(extra, true)
	return h

func _label_color(v: CombatantView, text: String) -> Color:
	for l: Label in _popups(v):
		if l.text == text:
			return l.modulate
	return Color(0, 0, 0, 0)

func test_neutral_hit_has_only_the_number() -> void:
	var v: CombatantView = _view()
	v.show_hit(_hit(EffectDef.Kind.DAMAGE, 7, &"", ElementMath.Affinity.NEUTRAL))
	assert_eq(_texts(v), ["-7"] as Array[String])

func test_weak_hit_shows_label_in_element_color() -> void:
	var v: CombatantView = _view()
	v.show_hit(_hit(EffectDef.Kind.DAMAGE, 12, FIRE_ID, ElementMath.Affinity.WEAK))
	assert_eq(_texts(v), ["-12", "Fraco!"] as Array[String])
	assert_eq(_label_color(v, "Fraco!"), fire.color)

func test_resist_hit_shows_label() -> void:
	var v: CombatantView = _view()
	v.show_hit(_hit(EffectDef.Kind.DAMAGE, 3, FIRE_ID, ElementMath.Affinity.RESIST))
	assert_eq(_texts(v), ["-3", "Resistiu"] as Array[String])
	assert_eq(_label_color(v, "Resistiu"), fire.color)

func test_immune_hit_shows_label_without_blocked() -> void:
	var v: CombatantView = _view()
	v.show_hit(_hit(EffectDef.Kind.DAMAGE, 0, THUNDER_ID, ElementMath.Affinity.IMMUNE))
	assert_eq(_texts(v), ["Imune"] as Array[String])
	assert_eq(_label_color(v, "Imune"), thunder.color)

func test_absorb_hit_shows_green_number_and_label() -> void:
	var v: CombatantView = _view()
	v.show_hit(_hit(EffectDef.Kind.HEAL, 9, FIRE_ID, ElementMath.Affinity.ABSORB))
	assert_eq(_texts(v), ["+9", "Absorveu"] as Array[String])
	assert_eq(_label_color(v, "+9"), ElementText.ABSORB_NUMBER_COLOR)
	assert_eq(_label_color(v, "Absorveu"), fire.color)

func test_plain_heal_has_no_affinity_label() -> void:
	var v: CombatantView = _view()
	v.show_hit(_hit(EffectDef.Kind.HEAL, 9, &"", ElementMath.Affinity.NEUTRAL))
	assert_eq(_texts(v), ["+9"] as Array[String])

func test_dodge_ignores_affinity() -> void:
	var v: CombatantView = _view()
	v.show_hit(_hit(EffectDef.Kind.DAMAGE, 0, FIRE_ID, ElementMath.Affinity.WEAK, {"dodged": true}))
	assert_eq(_texts(v), ["Esquiva"] as Array[String])

func test_burst_shows_contamination_popup_with_damage() -> void:
	var v: CombatantView = _view()
	v.show_hit(_hit(EffectDef.Kind.DAMAGE, 5, &"radioativo", ElementMath.Affinity.NEUTRAL, {"burst": 11}))
	assert_eq(_texts(v), ["-5", "Contaminação! -11"] as Array[String])

func test_no_burst_popup_at_zero() -> void:
	var v: CombatantView = _view()
	v.show_hit(_hit(EffectDef.Kind.DAMAGE, 5, &"radioativo", ElementMath.Affinity.NEUTRAL, {"contamination": 2}))
	assert_eq(_texts(v), ["-5"] as Array[String])

func test_attacker_effects_lifesteal_and_self_damage() -> void:
	var v: CombatantView = _view()
	v.show_attacker_effects(4, 0)
	assert_eq(_texts(v), ["+4"] as Array[String])
	assert_eq(_label_color(v, "+4"), ElementText.ABSORB_NUMBER_COLOR)
	var w: CombatantView = _view()
	w.show_attacker_effects(0, 3)
	assert_eq(_texts(w), ["-3"] as Array[String])
	var n: CombatantView = _view()
	n.show_attacker_effects(0, 0)
	assert_eq(_texts(n).size(), 0)

func test_bleed_tick_shows_number_and_label() -> void:
	var v: CombatantView = _view()
	v.show_bleed(6)
	assert_eq(_texts(v), ["-6", "Sangramento"] as Array[String])

func test_bleed_status_has_a_short_hud_label_and_a_menu_name() -> void:
	var s: StatusDef = Fixtures.status_def(StatusDef.Kind.BLEED, 4, 20)
	s.id = &"bleed"
	assert_eq(CombatantView.status_label(ActiveStatus.create(s, &"x", 0)), "SANG")
	assert_eq(EquipPage.STATUS_NAMES.get(&"bleed"), "Sangramento")

func test_contamination_indicator_hidden_at_zero() -> void:
	var v: CombatantView = _view()
	assert_eq(v.contamination_text(), "")
	v.combatant.contamination = 2
	assert_eq(v.contamination_text(), "Contam. 2")

func test_displayed_hp_is_clamped_to_max_without_touching_core() -> void:
	var v: CombatantView = _view()
	var hp_max: int = StatCalculator.hp_max(v.combatant, v.cfg)
	v.combatant.hp = hp_max + 5
	assert_eq(v.hp_shown(), hp_max)
	assert_eq(v.combatant.hp, hp_max + 5, "nucleo intacto")

# --- menu de comandos -----------------------------------------------------------

func _menu_with(abilities: Array[AbilityDef], weapon_element: ElementDef) -> CommandMenu:
	var cfg: BalanceConfig = Fixtures.cfg()
	var d: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 2))
	Fixtures.set_abilities(d, abilities)
	var h: Combatant = Combatant.from_hero(HeroState.create(d, cfg), Vector2(100, 100))
	h.weapon_element = weapon_element
	var x: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 1)), &"x", Vector2(500, 100), cfg)
	var ctrl := BattleController.new(BattleState.create(cfg, ScriptedDice.new(), [h], [x]))
	var m := CommandMenu.new()
	add_child_autofree(m)
	m.ctrl = ctrl
	ctrl.hero_turn.connect(m.open)
	for i: int in 400:
		ctrl.tick(0.05)
		if ctrl.is_paused():
			break
	return m

func _ab(id: StringName, label: String, el: ElementDef) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(1.0)
	a.id = id
	a.display_name = label
	a.ap_cost = 1
	a.element = el
	return a

func test_command_menu_shows_weapon_element_on_attack() -> void:
	var m: CommandMenu = _menu_with([_ab(&"b1", "Bola", fire)] as Array[AbilityDef], thunder)
	assert_eq(m.entry_labels()[0], "Atacar")
	assert_eq(m.entry_element_text(0), "Raio")
	assert_eq(m.entry_element_color(0), thunder.color)
	assert_eq(m.entry_element_text(1), "", "Habilidade (raiz) nao tem elemento")

func test_command_menu_shows_ability_element() -> void:
	var m: CommandMenu = _menu_with([_ab(&"b1", "Bola", fire), _ab(&"b2", "Soco", null)] as Array[AbilityDef], null)
	m.move(1)
	m.accept()
	assert_eq(m.mode, CommandMenu.Mode.ABILITIES)
	assert_eq(m.entry_labels(), PackedStringArray(["Bola — 1 AP", "Soco — 1 AP"]))
	assert_eq(m.entry_element_text(0), "Fogo")
	assert_eq(m.entry_element_color(0), fire.color)
	assert_eq(m.entry_element_text(1), "")

func test_command_menu_neutral_has_no_element_text() -> void:
	var m: CommandMenu = _menu_with([_ab(&"b1", "Bola", null)] as Array[AbilityDef], null)
	for i: int in 4:
		assert_eq(m.entry_element_text(i), "")
	m.move(1)
	m.accept()
	assert_eq(m.entry_element_text(0), "")

# --- debug ----------------------------------------------------------------------

func _debug_battle() -> BattleController:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: Combatant = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 1)), cfg), Vector2.ZERO)
	var x: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(10, 10, 5, 5)), &"x", Vector2.ZERO, cfg)
	return BattleController.new(BattleState.create(cfg, ScriptedDice.new(), [h], [x]))

func _executing(ctrl: BattleController, ab: AbilityDef) -> void:
	var a := PendingAction.new()
	a.actor = ctrl.b.heroes[0]
	a.ability = ab
	a.center = ctrl.b.enemies[0]
	ctrl.session = SelectionSession.new(a.actor, ctrl.b)
	ctrl.submit(a)

func test_debug_panel_shows_element_multiplier_and_contamination() -> void:
	var ctrl: BattleController = _debug_battle()
	var x: Combatant = ctrl.b.enemies[0]
	x.enemy_def.element_resist[FIRE_ID] = -0.5
	x.contamination = 2
	var p := DebugPanel.new()
	add_child_autofree(p)
	_executing(ctrl, _ab(&"b1", "Bola", fire))
	var t: String = p.build_text(ctrl.b, ctrl)
	assert_string_contains(t, "Elemento: Fogo")
	assert_string_contains(t, "x1.50")
	assert_string_contains(t, "Contaminação")
	assert_string_contains(t, "x: 2")

func test_debug_panel_neutral_adds_nothing() -> void:
	var ctrl: BattleController = _debug_battle()
	var p := DebugPanel.new()
	add_child_autofree(p)
	_executing(ctrl, Fixtures.hit(1.0))
	var t: String = p.build_text(ctrl.b, ctrl)
	assert_false(t.contains("Elemento"))
	assert_false(t.contains("Contaminação"))

# --- menu de campo --------------------------------------------------------------

var g: GameState
var menu: FieldMenu

func _field(heal_el: ElementDef, native: Array[ElementDef], base_resist: Dictionary, bag: Array[EquipmentDef]) -> void:
	var heal := EffectDef.new()
	heal.kind = EffectDef.Kind.HEAL
	heal.scale = EffectDef.Scale.FIXED
	heal.potency = 10.0
	var tech := AbilityDef.new()
	tech.id = &"cura"
	tech.display_name = "Cura"
	tech.ap_cost = 2
	tech.side = AbilityDef.Side.ALLIES
	tech.effects = [heal]
	tech.element = heal_el
	var d: CharacterDef = Fixtures.hero_def(&"Alfa", Stats.make(3, 3, 3, 3))
	d.weapon_types = [&"blade"] as Array[StringName]
	d.elements = native
	for k: StringName in base_resist:
		d.element_resist[k] = base_resist[k]
	Fixtures.set_abilities(d, [tech] as Array[AbilityDef])
	var counts: Array[int] = []
	for e: EquipmentDef in bag:
		counts.append(1)
	g = GameState.new_game(Fixtures.cfg(), [d] as Array[CharacterDef], [] as Array[ItemDef], [] as Array[int], ScriptedDice.new(),
			&"overworld", &"Start", 4, bag, counts)
	menu = MENU_SCENE.instantiate() as FieldMenu
	add_child_autofree(menu)
	menu.open(g)

func _equip(id: StringName, label: String, slot: StringName, el: ElementDef, resist: Dictionary) -> EquipmentDef:
	var e := EquipmentDef.new()
	e.id = id
	e.display_name = label
	e.slot = slot
	e.modifiers = Stats.make(0, 0, 0, 0)
	if slot == &"weapon":
		e.weapon_type = &"blade"
	e.element = el
	for k: StringName in resist:
		e.element_resist[k] = resist[k]
	return e

func _go(page: StringName) -> void:
	menu.cursor = FieldMenu.COMMAND_PAGES.find(page)
	menu.accept()

func test_technique_page_shows_element() -> void:
	_field(fire, [] as Array[ElementDef], {}, [] as Array[EquipmentDef])
	_go(&"techniques")
	menu.technique_page.accept()
	assert_eq(menu.technique_page.entries()[0], "Cura — 2 AP · Fogo")

func test_technique_page_neutral_unchanged() -> void:
	_field(null, [] as Array[ElementDef], {}, [] as Array[EquipmentDef])
	_go(&"techniques")
	menu.technique_page.accept()
	assert_eq(menu.technique_page.entries()[0], "Cura — 2 AP")

func test_equip_preview_shows_weapon_element_and_resist_change() -> void:
	var blade: EquipmentDef = _equip(&"lamina", "Lâmina", &"weapon", fire, {})
	var ring: EquipmentDef = _equip(&"anel", "Anel", &"accessory", null, {FIRE_ID: 0.3, THUNDER_ID: -0.2})
	_field(null, [] as Array[ElementDef], {}, [blade, ring] as Array[EquipmentDef])
	_go(&"equip")
	var page: EquipPage = menu.equip_page
	page.accept()
	page.accept()
	var lines: PackedStringArray = page.preview_lines()
	assert_true(lines.has("Elemento da arma: — → Fogo"), str(lines))
	assert_eq(page.entries()[0], "Lâmina x1 · Fogo")
	assert_eq(lines[lines.size() - 1], "Passivos: —")
	page.cancel()
	page.cursor = 3
	page.accept()
	lines = page.preview_lines()
	assert_true(lines.has("Resistência Fogo: 0% → 30%"), str(lines))
	assert_true(lines.has("Resistência Raio: 0% → −20%"), str(lines))
	assert_false(lines.has("Elemento da arma: — → Fogo"))
	assert_eq(lines[lines.size() - 1], "Passivos: —")

func test_equip_slot_line_shows_weapon_element() -> void:
	var blade: EquipmentDef = _equip(&"lamina", "Lâmina", &"weapon", fire, {})
	_field(null, [] as Array[ElementDef], {}, [blade] as Array[EquipmentDef])
	g.heroes[0].equipment[&"weapon"] = blade
	assert_eq(EquipPage.slot_line(g.heroes[0], &"weapon"), "Arma: Lâmina (Fogo)")

func test_equip_page_neutral_unchanged() -> void:
	var blade: EquipmentDef = _equip(&"lamina", "Lâmina", &"weapon", null, {})
	_field(null, [] as Array[ElementDef], {}, [blade] as Array[EquipmentDef])
	_go(&"equip")
	var page: EquipPage = menu.equip_page
	page.accept()
	page.accept()
	assert_eq(page.entries()[0], "Lâmina x1")
	for l: String in page.preview_lines():
		assert_false(l.contains("Elemento") or l.contains("Resist"), l)
	assert_eq(EquipPage.slot_line(g.heroes[0], &"weapon"), "Arma: —")

func _status_text() -> String:
	_go(&"status")
	menu.status_page.accept()
	return menu.status_page.detail_text()

func test_status_shows_natives_and_total_affinity() -> void:
	var ring: EquipmentDef = _equip(&"anel", "Anel", &"accessory", null, {FIRE_ID: 0.2, THUNDER_ID: -0.5})
	_field(null, [fire] as Array[ElementDef], {FIRE_ID: 0.1, &"atlas": 0.0}, [ring] as Array[EquipmentDef])
	g.heroes[0].equipment[&"accessory"] = ring
	var t: String = _status_text()
	assert_string_contains(t, "Elementos: Fogo")
	assert_string_contains(t, "Resistência (− = fraqueza): Fogo 30%, Raio −50%")
	assert_false(t.contains("Terra"), "entrada zero fica de fora")

func test_status_neutral_has_no_element_lines() -> void:
	_field(null, [] as Array[ElementDef], {}, [] as Array[EquipmentDef])
	var t: String = _status_text()
	assert_false(t.contains("Elementos"))
	assert_false(t.contains("Resistência"))

func test_status_only_natives_no_resist_line() -> void:
	_field(null, [fire, thunder] as Array[ElementDef], {}, [] as Array[EquipmentDef])
	var t: String = _status_text()
	assert_string_contains(t, "Elementos: Fogo, Raio")
	assert_false(t.contains("Resistência"))

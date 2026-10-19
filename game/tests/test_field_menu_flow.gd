extends GutTest

## Fluxos das páginas do menu de campo (Itens, Técnicas, Status, Atributos, Formação).

const SCENE: PackedScene = preload("res://ui/field_menu/field_menu.tscn")
const NAMES: Array[StringName] = [&"Alfa", &"Bravo", &"Carla", &"Delta", &"Ecos"]

var g: GameState
var menu: FieldMenu
var potion: ItemDef
var ether: ItemDef
var reviver: ItemDef
var bomb: ItemDef
var heal_tech: AbilityDef
var group_tech: AbilityDef

func _effect(kind: EffectDef.Kind, potency: float) -> EffectDef:
	var e := EffectDef.new()
	e.kind = kind
	e.scale = EffectDef.Scale.FIXED
	e.potency = potency
	return e

func _item(id: StringName, label: String, e: EffectDef) -> ItemDef:
	var it := ItemDef.new()
	it.id = id
	it.display_name = label
	it.effects = [e]
	return it

func _tech(id: StringName, label: String, cost: int, shape: AbilityDef.Shape) -> AbilityDef:
	var ab := AbilityDef.new()
	ab.id = id
	ab.display_name = label
	ab.ap_cost = cost
	ab.shape = shape
	ab.side = AbilityDef.Side.ALLIES
	ab.effects = [_effect(EffectDef.Kind.HEAL, 15.0)]
	return ab

func before_each() -> void:
	heal_tech = _tech(&"cura", "Cura", 4, AbilityDef.Shape.SINGLE)
	group_tech = _tech(&"cura_grupo", "Cura Grupo", 8, AbilityDef.Shape.GROUP)
	var defs: Array[CharacterDef] = []
	for id: StringName in NAMES:
		defs.append(Fixtures.hero_def(id, Stats.make(1, 1, 3, 2)))
	defs[0].abilities = [heal_tech, group_tech]
	defs[2].abilities = [heal_tech]
	potion = _item(&"pocao", "Poção", _effect(EffectDef.Kind.HEAL, 20.0))
	ether = _item(&"eter", "Éter", _effect(EffectDef.Kind.RESTORE_AP, 5.0))
	reviver = _item(&"reviver", "Reviver", _effect(EffectDef.Kind.REVIVE, 0.5))
	bomb = _item(&"bomba", "Bomba", _effect(EffectDef.Kind.DAMAGE, 5.0))
	var items: Array[ItemDef] = [potion, ether, reviver, bomb]
	var counts: Array[int] = [1, 1, 1, 1]
	g = GameState.new_game(Fixtures.cfg(), defs, items, counts, ScriptedDice.new(), &"overworld", &"Start")
	# HP máximo 35, AP máximo 10.
	g.heroes[1].hp = 10
	g.heroes[3].ap = 2
	menu = SCENE.instantiate() as FieldMenu
	add_child_autofree(menu)
	menu.open(g)

func _go(p: StringName) -> void:
	menu.cursor = FieldMenu.COMMAND_PAGES.find(p)
	menu.accept()

func _item_index(label: String) -> int:
	var rows: PackedStringArray = menu.item_page.entries()
	for i: int in rows.size():
		if rows[i].begins_with(label):
			return i
	return -1

# --- Itens ---

func test_item_flow_heals_target_and_consumes() -> void:
	_go(&"items")
	var page: ItemPage = menu.item_page
	assert_eq(page.entries()[_item_index("Poção")], "Poção x1")
	page.cursor = _item_index("Poção")
	page.accept()
	assert_true(menu.party_panel.picking)
	assert_eq(menu.party_panel.picked(), g.heroes[1], "único ferido é o primeiro alvo")
	page.accept()
	assert_eq(g.heroes[1].hp, 30)
	assert_eq(g.inventory.available(&"pocao"), 0)
	assert_false(menu.party_panel.picking)
	assert_string_contains(menu.party_panel.card_text(1), "HP 30/35")
	assert_string_contains(page.message(), "Bravo")

func test_item_target_filter_disables_no_effect_targets() -> void:
	g.heroes[2].hp = 0
	menu.party_panel.refresh(g)
	_go(&"items")
	var page: ItemPage = menu.item_page
	page.cursor = _item_index("Poção")
	page.accept()
	var panel: PartyPanel = menu.party_panel
	# Só Bravo (ferido, de pé) é alvo: cheios e caídos ficam desabilitados.
	assert_true(panel.is_pick_enabled(1))
	assert_false(panel.is_pick_enabled(0))
	assert_false(panel.is_pick_enabled(2))
	assert_false(panel.is_pick_enabled(4))
	page.move(1)
	assert_eq(panel.picked(), g.heroes[1])
	page.cancel()
	assert_false(panel.picking)
	assert_eq(menu.page, &"items", "cancelar o alvo volta à lista")
	page.cursor = _item_index("Reviver")
	page.accept()
	assert_eq(panel.picked(), g.heroes[2])
	assert_false(panel.is_pick_enabled(1))

func test_item_disabled_entries_and_nobody_needs() -> void:
	_go(&"items")
	var page: ItemPage = menu.item_page
	var bi: int = _item_index("Bomba")
	assert_false(page.entry_enabled(bi))
	page.cursor = bi
	page.accept()
	assert_false(menu.party_panel.picking)
	assert_eq(page.message(), "Não pode ser usado aqui.")
	page.cursor = _item_index("Reviver")
	page.accept()
	assert_false(menu.party_panel.picking)
	assert_eq(page.message(), "Ninguém precisa disso.")

func test_item_disappears_at_zero() -> void:
	_go(&"items")
	var page: ItemPage = menu.item_page
	page.cursor = _item_index("Éter")
	page.accept()
	assert_eq(menu.party_panel.picked(), g.heroes[3])
	page.accept()
	assert_eq(g.heroes[3].ap, 7)
	assert_eq(_item_index("Éter"), -1)
	assert_eq(page.entries().size(), 3)

func test_item_cancel_from_list_leaves_page() -> void:
	_go(&"items")
	menu.cancel()
	assert_eq(menu.page, &"root")

func test_item_cancel_in_pick_via_menu_stays_on_page() -> void:
	_go(&"items")
	menu.item_page.cursor = _item_index("Poção")
	menu.item_page.accept()
	menu.cancel()
	assert_eq(menu.page, &"items")
	assert_false(menu.party_panel.picking)

# --- Técnicas ---

func test_technique_flow_pays_ap_and_heals() -> void:
	_go(&"techniques")
	var page: TechniquePage = menu.technique_page
	assert_eq(page.step, TechniquePage.Step.USER)
	assert_eq(page.entries()[0], "Alfa")
	page.accept()
	assert_eq(page.step, TechniquePage.Step.TECH)
	assert_eq(page.entries(), PackedStringArray(["Cura — 4 AP", "Cura Grupo — 8 AP"]))
	page.accept()
	assert_eq(page.step, TechniquePage.Step.TARGET)
	assert_eq(menu.party_panel.picked(), g.heroes[1])
	page.accept()
	assert_eq(g.heroes[1].hp, 25)
	assert_eq(g.heroes[0].ap, 6)
	assert_eq(page.step, TechniquePage.Step.TECH)
	assert_false(page.entry_enabled(1), "sem AP para a técnica de grupo")
	assert_string_contains(menu.party_panel.card_text(0), "AP 6/10")

func test_technique_group_uses_directly() -> void:
	_go(&"techniques")
	var page: TechniquePage = menu.technique_page
	page.accept()
	page.cursor = 1
	page.accept()
	assert_false(menu.party_panel.picking)
	assert_eq(g.heroes[1].hp, 25)
	assert_eq(g.heroes[0].ap, 2)
	assert_eq(page.step, TechniquePage.Step.TECH)

func test_technique_group_refused_when_nobody_hurt() -> void:
	g.heroes[1].hp = 35
	_go(&"techniques")
	var page: TechniquePage = menu.technique_page
	page.accept()
	page.cursor = 1
	page.accept()
	assert_eq(g.heroes[0].ap, 10)
	assert_eq(page.message(), "Ninguém precisa disso.")

func test_technique_user_list_excludes_downed_and_no_technique() -> void:
	g.heroes[0].hp = 0
	_go(&"techniques")
	var page: TechniquePage = menu.technique_page
	assert_eq(page.entries(), PackedStringArray(["Carla"]))
	page.accept()
	assert_eq(page.entries(), PackedStringArray(["Cura — 4 AP"]))
	page.cancel()
	assert_eq(page.step, TechniquePage.Step.USER)
	menu.cancel()
	assert_eq(menu.page, &"root")

func test_technique_no_users_message() -> void:
	g.heroes[0].hp = 0
	g.heroes[2].hp = 0
	_go(&"techniques")
	var page: TechniquePage = menu.technique_page
	assert_eq(page.entries().size(), 0)
	assert_eq(page.message(), "Ninguém pode usar técnicas.")

func test_technique_target_cancel_returns_to_list() -> void:
	_go(&"techniques")
	var page: TechniquePage = menu.technique_page
	page.accept()
	page.accept()
	menu.cancel()
	assert_eq(page.step, TechniquePage.Step.TECH)
	assert_false(menu.party_panel.picking)
	assert_eq(menu.page, &"techniques")

# --- Status ---

func test_status_page_shows_xp_to_next_and_attributes() -> void:
	g.heroes[2].xp = 4
	g.heroes[2].allocated.strength = 2
	_go(&"status")
	var page: StatusPage = menu.status_page
	assert_true(menu.party_panel.picking)
	page.move(1)
	page.move(1)
	page.accept()
	var t: String = page.detail_text()
	assert_string_contains(t, "Carla — Nv 1")
	assert_string_contains(t, "XP: 4 / 10")
	assert_string_contains(t, "HP: 35 / 35")
	assert_string_contains(t, "AP: 10 / 10")
	assert_string_contains(t, "Força: 1 + 2 = 3")
	assert_string_contains(t, "Vitalidade: 3 + 0 = 3")
	assert_string_contains(t, "Cura — 4 AP")
	page.cancel()
	assert_true(menu.party_panel.picking)
	assert_eq(page.detail_text(), "")

# --- Atributos ---

func test_attributes_opens_level_up_and_applies() -> void:
	g.reserve[0].pending_points = 2
	menu.party_panel.refresh(g)
	_go(&"attributes")
	assert_eq(menu.page, &"attributes")
	var page: AttributesPage = menu.attributes_page
	assert_eq(menu.party_panel.picked(), g.reserve[0])
	page.accept()
	var screen: LevelUpScreen = page.screen
	assert_true(screen.visible)
	assert_eq(screen.hero, g.reserve[0])
	page.adjust(1)
	page.move(1)
	page.adjust(1)
	screen.cursor = LevelUpScreen.ROW_CONFIRM
	page.accept()
	assert_false(screen.visible)
	assert_eq(g.reserve[0].allocated.strength, 1)
	assert_eq(g.reserve[0].allocated.speed, 1)
	assert_eq(g.reserve[0].pending_points, 0)
	assert_false(menu.party_panel.card_text(4).contains("pts"))
	assert_eq(menu.page, &"root", "ninguém mais com pontos: volta à raiz")
	assert_false(menu.command_enabled(3))

func test_attributes_cancel_in_screen_keeps_points() -> void:
	g.heroes[1].pending_points = 1
	menu.party_panel.refresh(g)
	_go(&"attributes")
	var page: AttributesPage = menu.attributes_page
	page.accept()
	menu.cancel()
	assert_false(page.screen.visible)
	assert_eq(menu.page, &"attributes")
	assert_true(menu.party_panel.picking)
	assert_eq(g.heroes[1].pending_points, 1)

func test_attributes_disabled_without_pending_points() -> void:
	assert_false(menu.command_enabled(3))
	_go(&"attributes")
	assert_eq(menu.page, &"root")
	assert_eq(menu.message(), "Ninguém tem pontos para distribuir.")
	g.heroes[0].pending_points = 1
	menu.party_panel.refresh(g)
	menu.close()
	menu.open(g)
	assert_true(menu.command_enabled(3))

# --- Formação ---

func test_formation_swap_active_with_reserve() -> void:
	_go(&"formation")
	var page: FormationPage = menu.formation_page
	page.accept()
	assert_eq(page.selected, g.heroes[0])
	page.cursor = 4
	page.accept()
	assert_eq(g.heroes[0].def.display_name, "Ecos")
	assert_eq(g.reserve[0].def.display_name, "Alfa")
	assert_null(page.selected)
	assert_string_contains(page.entries()[0], "Ecos")
	assert_string_contains(menu.party_panel.card_text(0), "Ecos")

func test_formation_to_reserve_and_back() -> void:
	_go(&"formation")
	var page: FormationPage = menu.formation_page
	page.cursor = 1
	page.accept()
	assert_eq(page.entries()[page.entries().size() - 1], "Para reserva")
	page.cursor = page.entries().size() - 1
	page.accept()
	assert_eq(g.heroes.size(), 3)
	assert_eq(g.reserve[1].def.display_name, "Bravo")
	page.cursor = 4
	page.accept()
	assert_eq(page.entries()[page.entries().size() - 1], "Para o grupo")
	page.cursor = page.entries().size() - 1
	page.accept()
	assert_eq(g.heroes.size(), 4)
	assert_eq(menu.party_panel.active_card_count(), 4)

func test_formation_full_party_message() -> void:
	_go(&"formation")
	var page: FormationPage = menu.formation_page
	page.cursor = 4
	page.accept()
	page.cursor = page.entries().size() - 1
	page.accept()
	assert_eq(page.message(), "Grupo cheio")
	assert_eq(g.reserve.size(), 1)

func test_formation_refuses_empty_party_with_message() -> void:
	for i: int in 3:
		g.to_reserve(g.heroes[1])
	menu.party_panel.refresh(g)
	_go(&"formation")
	var page: FormationPage = menu.formation_page
	page.accept()
	page.cursor = page.entries().size() - 1
	page.accept()
	assert_eq(page.message(), "O grupo precisa de pelo menos 1 herói")
	assert_eq(g.heroes.size(), 1)

func test_formation_leader_marked() -> void:
	_go(&"formation")
	var rows: PackedStringArray = menu.formation_page.entries()
	assert_eq(rows[0], "Alfa — Ativo 1 · Líder")
	assert_eq(rows[1], "Bravo — Ativo 2")
	assert_eq(rows[4], "Ecos — Reserva")
	assert_false(rows[1].contains("Líder"))

func test_formation_cancel_deselects_first() -> void:
	_go(&"formation")
	var page: FormationPage = menu.formation_page
	page.accept()
	menu.cancel()
	assert_null(page.selected)
	assert_eq(menu.page, &"formation")
	menu.cancel()
	assert_eq(menu.page, &"root")

# --- Roteamento de teclado ---

func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	menu._unhandled_input(ev)

func test_keyboard_routes_to_active_page() -> void:
	_go(&"items")
	menu.item_page.cursor = 0
	_press(&"ui_down")
	assert_eq(menu.item_page.cursor, 1)
	assert_eq(menu.cursor, FieldMenu.COMMAND_PAGES.find(&"items"), "raiz não se move")
	_press(&"ui_cancel")
	assert_eq(menu.page, &"root")

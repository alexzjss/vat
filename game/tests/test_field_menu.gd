extends GutTest

const SCENE: PackedScene = preload("res://ui/field_menu/field_menu.tscn")
const LABELS: Array[String] = ["Itens", "Técnicas", "Equipar", "Status", "Atributos", "Formação", "Salvar", "Config", "Fechar"]

var g: GameState
var menu: FieldMenu

func before_each() -> void:
	var defs: Array[CharacterDef] = []
	for id: StringName in [&"a", &"b", &"c", &"d", &"e"]:
		defs.append(Fixtures.hero_def(id, Stats.make(1, 1, 3, 2)))
	g = GameState.new_game(Fixtures.cfg(), defs, [], [], ScriptedDice.new(), &"overworld", &"Start")
	menu = SCENE.instantiate() as FieldMenu
	add_child_autofree(menu)
	menu.open(g)

func _labels() -> Array[String]:
	var out: Array[String] = []
	for s: String in menu.command_labels():
		out.append(s)
	return out

func test_open_shows_commands_and_party_cards() -> void:
	assert_true(menu.is_open)
	assert_true(menu.visible)
	assert_eq(_labels(), LABELS)
	assert_eq(menu.page, &"root")
	var panel: PartyPanel = menu.party_panel
	assert_eq(panel.active_card_count(), 4)
	assert_eq(panel.reserve_card_count(), 1)
	var t: String = panel.card_text(0)
	assert_string_contains(t, "a")
	assert_string_contains(t, "Nv 1")
	assert_string_contains(t, "HP 35/35")
	assert_string_contains(t, "AP 10/10")
	assert_string_contains(panel.card_text(4), "e")

func test_navigation_and_close() -> void:
	# Atributos só abre com alguém com pontos pendentes (Task 5).
	g.reserve[0].pending_points = 1
	menu.party_panel.refresh(g)
	watch_signals(menu)
	menu.move(1)
	assert_eq(menu.cursor, 1)
	menu.move(-2)
	assert_eq(menu.cursor, 8)
	menu.move(1)
	menu.accept()
	assert_eq(menu.page, &"items")
	menu.cancel()
	assert_eq(menu.page, &"root")
	assert_eq(menu.cursor, 0)
	menu.save_allowed = true
	var pages: Array[StringName] = [&"techniques", &"equip", &"status", &"attributes", &"formation", &"save", &"config"]
	for i: int in pages.size():
		menu.move(1)
		menu.accept()
		assert_eq(menu.page, pages[i])
		menu.cancel()
	assert_eq(menu.cursor, 7)
	menu.cancel()
	assert_signal_emitted(menu, "closed")
	assert_false(menu.is_open)
	assert_false(menu.visible)

func test_fechar_closes() -> void:
	watch_signals(menu)
	menu.move(-1)
	menu.accept()
	assert_signal_emit_count(menu, "closed", 1)
	assert_false(menu.is_open)
	menu.cancel()
	menu.accept()
	assert_signal_emit_count(menu, "closed", 1)

func test_close_twice_emits_once() -> void:
	watch_signals(menu)
	menu.close()
	menu.close()
	assert_signal_emit_count(menu, "closed", 1)

func test_reopen_resets_to_root() -> void:
	menu.move(2)
	menu.accept()
	menu.close()
	menu.open(g)
	assert_eq(menu.page, &"root")
	assert_eq(menu.cursor, 0)
	assert_true(menu.is_open)

func test_page_controls_toggle() -> void:
	assert_true(menu.page_control(&"root").visible)
	menu.move(3)
	menu.accept()
	assert_true(menu.page_control(&"status").visible)
	assert_true(menu.page_control(&"root").visible)
	assert_false(menu.page_control(&"items").visible)

func test_card_shows_downed_and_pending_points() -> void:
	g.heroes[1].hp = 0
	g.heroes[2].pending_points = 3
	menu.party_panel.refresh(g)
	assert_string_contains(menu.party_panel.card_text(1), "Caído")
	assert_false(menu.party_panel.card_text(0).contains("Caído"))
	assert_string_contains(menu.party_panel.card_text(2), "+3 pts")
	assert_false(menu.party_panel.card_text(0).contains("pts"))

func test_refresh_follows_formation_changes() -> void:
	g.swap(g.heroes[0], g.reserve[0])
	menu.party_panel.refresh(g)
	assert_string_contains(menu.party_panel.card_text(0), "e")
	assert_string_contains(menu.party_panel.card_text(4), "a")

func test_pick_mode_respects_filter() -> void:
	var panel: PartyPanel = menu.party_panel
	g.heroes[2].hp = 0
	g.reserve[0].hp = 0
	panel.refresh(g)
	watch_signals(panel)
	panel.begin_pick(func(h: HeroState) -> bool: return h.hp <= 0)
	assert_eq(panel.picked(), g.heroes[2])
	panel.pick_move(1)
	assert_eq(panel.picked(), g.reserve[0])
	panel.pick_move(1)
	assert_eq(panel.picked(), g.heroes[2])
	panel.pick_move(-1)
	assert_eq(panel.picked(), g.reserve[0])
	panel.pick_accept()
	assert_signal_emitted_with_parameters(panel, "hero_picked", [g.reserve[0]])
	panel.end_pick()
	assert_null(panel.picked())

func test_pick_mode_with_no_enabled_heroes() -> void:
	var panel: PartyPanel = menu.party_panel
	watch_signals(panel)
	panel.begin_pick(func(h: HeroState) -> bool: return h.hp <= 0)
	assert_null(panel.picked())
	panel.pick_move(1)
	panel.pick_accept()
	assert_signal_not_emitted(panel, "hero_picked")

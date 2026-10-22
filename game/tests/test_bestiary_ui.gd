extends GutTest
## M15 Task 6: paginas Bestiario e Reacoes do menu de campo, textos do Scan e popup do Scan na vista.

const SCENE: PackedScene = preload("res://ui/field_menu/field_menu.tscn")

var g: GameState
var menu: FieldMenu
var cfg: BalanceConfig

func before_each() -> void:
	cfg = Fixtures.cfg()
	var defs: Array[CharacterDef] = [Fixtures.hero_def(&"a", Stats.make(1, 1, 3, 2))]
	g = GameState.new_game(cfg, defs, [], [], ScriptedDice.new(), &"overworld", &"Start")
	menu = SCENE.instantiate() as FieldMenu
	add_child_autofree(menu)
	menu.open(g)

func _enemy(id: StringName, name: String) -> EnemyDef:
	var d: EnemyDef = Fixtures.enemy_def(id, Stats.make(10, 5, 5, 4))
	d.display_name = name
	d.level = 3
	return d

func _three() -> Array[EnemyDef]:
	var a: EnemyDef = _enemy(&"golem", "Golem")
	a.element_resist = {&"kagutsuchi": -0.5}
	var out: Array[EnemyDef] = [a, _enemy(&"slime", "Slime"), _enemy(&"bat", "Morcego")]
	return out

func _open_bestiary(defs: Array[EnemyDef]) -> BestiaryPage:
	menu.bestiary_page.set_defs(defs)
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"bestiary")
	menu.accept()
	return menu.bestiary_page

func _open_reactions(table: ReactionTable = null) -> ReactionsPage:
	if table != null:
		menu.reactions_page.set_table(table)
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"reactions")
	menu.accept()
	return menu.reactions_page

func _reaction(id: StringName, name: String, bonus: float) -> ReactionDef:
	var r := ReactionDef.new()
	r.id = id
	r.display_name = name
	r.a = ElementText.def_of(&"kagutsuchi")
	r.b = ElementText.def_of(&"susanoo")
	r.bonus_pct = bonus
	return r

# --- menu ---

func test_menu_has_both_entries_after_status() -> void:
	var labels: PackedStringArray = menu.command_labels()
	var i: int = labels.find("Status")
	assert_eq(labels[i + 1], "Bestiário")
	assert_eq(labels[i + 2], "Reações")
	assert_eq(FieldMenu.COMMAND_PAGES[i + 1], &"bestiary")
	assert_eq(labels[FieldMenu.ATTRIBUTES_INDEX], "Atributos")
	assert_eq(labels[FieldMenu.SAVE_INDEX], "Salvar")

func test_entries_open_pages_and_esc_returns() -> void:
	_open_bestiary(_three())
	assert_eq(menu.page, &"bestiary")
	assert_true(menu.page_control(&"bestiary").visible)
	menu.cancel()
	assert_eq(menu.page, &"root")
	_open_reactions()
	assert_eq(menu.page, &"reactions")
	menu.cancel()
	assert_eq(menu.page, &"root")

# --- bestiario ---

func test_empty_bestiary_shows_only_unknown() -> void:
	var p: BestiaryPage = _open_bestiary(_three())
	assert_eq(p.entries(), PackedStringArray(["???", "???", "???"]))
	assert_eq(p.count_text(), "Vistos 0/3")
	assert_eq(p.detail_text(), "???")

func test_rows_seen_unseen_and_count() -> void:
	g.bestiary[&"slime"] = {"seen": true, "defeated": 1, "scanned": false}
	var p: BestiaryPage = _open_bestiary(_three())
	assert_eq(p.entries(), PackedStringArray(["???", "Slime", "???"]))
	assert_eq(p.count_text(), "Vistos 1/3")

func test_seen_detail_has_four_lines_and_revealed_has_nine() -> void:
	g.bestiary[&"slime"] = {"seen": true, "defeated": 1, "scanned": false}
	g.bestiary[&"golem"] = {"seen": true, "defeated": 0, "scanned": true}
	var p: BestiaryPage = _open_bestiary(_three())
	assert_eq(p.detail_text().split("\n").size(), 9, "golem revelado")
	assert_string_contains(p.detail_text(), "Fogo −50%")
	p.move(1)
	var lines: PackedStringArray = p.detail_text().split("\n")
	assert_eq(lines.size(), 4, "slime visto")
	assert_eq(lines[0], "Slime")
	assert_string_contains(p.detail_text(), "Derrotado 1x")
	assert_false(p.detail_text().contains("Afinidades"))
	p.move(1)
	assert_eq(p.detail_text(), "???")

func test_navigation_wraps_and_esc_via_input() -> void:
	g.bestiary[&"bat"] = {"seen": true, "defeated": 0, "scanned": false}
	var p: BestiaryPage = _open_bestiary(_three())
	p.move(-1)
	assert_eq(p.cursor, 2)
	assert_string_contains(p.detail_text(), "Morcego")
	p.move(1)
	assert_eq(p.cursor, 0)
	var ev := InputEventAction.new()
	ev.action = "ui_down"
	ev.pressed = true
	assert_true(p.handle_input(ev))
	assert_eq(p.cursor, 1)

func test_default_source_lists_slice_enemies_and_bestiary_extras() -> void:
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"bestiary")
	menu.accept()
	var n: int = menu.bestiary_page.entries().size()
	assert_gt(n, 0, "inimigos da fatia")
	assert_eq(menu.bestiary_page.count_text(), "Vistos 0/%d" % n)
	# Um inimigo fora da fatia que ja esta no bestiario entra na lista (varre res://data).
	var outside: StringName = &""
	for d: EnemyDef in BestiaryPage._scan(BestiaryPage.DATA_ROOT):
		if not BestiaryPage.slice_enemies().any(func(x: EnemyDef) -> bool: return x.id == d.id):
			outside = d.id
			break
	if outside == &"":
		pending("nenhum inimigo fora da fatia em res://data")
		return
	menu.cancel()
	g.bestiary[outside] = {"seen": true, "defeated": 0, "scanned": false}
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"bestiary")
	menu.accept()
	assert_eq(menu.bestiary_page.entries().size(), n + 1)
	assert_eq(menu.bestiary_page.count_text(), "Vistos 1/%d" % (n + 1))

# --- reacoes ---

func test_reactions_default_table_has_28_all_unknown() -> void:
	var p: ReactionsPage = _open_reactions()
	assert_eq(p.entries().size(), 28)
	assert_eq(p.count_text(), "Vistas 0/28")
	assert_eq(p.entries()[0], "???")
	assert_eq(p.detail_text(), "???")

func test_reactions_seen_shows_name_pair_and_summary() -> void:
	var t := ReactionTable.new()
	t.reactions = [_reaction(&"vapor", "Vapor", 0.5), _reaction(&"lama", "Lama", 0.25)]
	g.seen_reactions.append(&"lama")
	var p: ReactionsPage = _open_reactions(t)
	assert_eq(p.entries(), PackedStringArray(["???", "Lama — Fogo + Água"]))
	assert_eq(p.count_text(), "Vistas 1/2")
	assert_eq(p.detail_text(), "???")
	p.move(1)
	assert_string_contains(p.detail_text(), "Lama")
	assert_string_contains(p.detail_text(), "Fogo + Água")
	assert_string_contains(p.detail_text(), "+25% dano")
	p.move(1)
	assert_eq(p.cursor, 0)

func test_reactions_window_scrolls_with_cursor() -> void:
	var p: ReactionsPage = _open_reactions()
	p.move(-1)
	assert_eq(p.cursor, 27)
	assert_lte(p._list.get_child_count(), LorePage.VISIBLE_ROWS)
	assert_true((p._list.get_child(p._list.get_child_count() - 1) as Label).text.begins_with("> "))

# --- Scan ---

func test_scan_text_composes_all_segments() -> void:
	var info: Dictionary = {
		"natives": [&"kagutsuchi"] as Array[StringName],
		"element_resist": {&"kagutsuchi": -0.5, &"susanoo": -0.25, &"atlas": 0.5, &"indra": 1.5, &"fuhaku": 1.0},
		"absorbs": [&"indra"] as Array[StringName],
		"immunities": [&"sleep"] as Array[StringName],
		"resistances": {&"poison": 0.3},
	}
	assert_eq(BestiaryText.scan_text(info), "Scan: Fraco a Fogo, Água · Resiste Terra · Absorve Raio · Imune Vento, Sono · Estados Veneno 30%")

func test_scan_text_without_data() -> void:
	assert_eq(BestiaryText.scan_text({}), "Scan: Sem fraquezas")

func test_view_scan_hit_shows_multiline_panel() -> void:
	var c: Combatant = Combatant.from_enemy(_enemy(&"golem", "Golem"), &"golem", Vector2.ZERO, cfg)
	var v := CombatantView.new()
	add_child_autofree(v)
	v.bind(c, cfg)
	var hit: Dictionary = {"kind": EffectDef.Kind.SCAN, "amount": 0, "dodged": false, "scan": true,
		"scan_info": {"element_resist": {&"kagutsuchi": -0.5}, "immunities": [&"sleep"] as Array[StringName], "absorbs": [] as Array[StringName], "resistances": {}}}
	v.show_hit(hit)
	assert_eq(v.get_child_count(), 1)
	var panel: PanelContainer = v.get_child(0) as PanelContainer
	assert_not_null(panel)
	var label: Label = panel.get_child(0) as Label
	assert_eq(label.text, "Scan\nFraco a Fogo\nImune Sono")

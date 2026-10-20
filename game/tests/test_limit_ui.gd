extends GutTest

## Limite na interface (M8): comando no menu, barra no HUD, painel/Status e politica smart do simulador.

var ctrl: BattleController
var menu: CommandMenu
var h: Combatant
var x: Combatant

func _setup(limit: float) -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var d: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 2))
	Fixtures.set_abilities(d, [Fixtures.hit(1.0)])
	d.limit_ability = Fixtures.hit(3.0)
	d.limit_ability.id = &"golpe_final"
	d.limit_ability.display_name = "Golpe Final"
	var hs := HeroState.create(d, cfg)
	hs.limit = limit
	h = Combatant.from_hero(hs, Vector2(100, 100))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 1)), &"x", Vector2(500, 100), cfg)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	ctrl = BattleController.new(b)
	menu = CommandMenu.new()
	add_child_autofree(menu)
	menu.ctrl = ctrl
	ctrl.hero_turn.connect(menu.open)
	for i: int in 400:
		ctrl.tick(0.05)
		if ctrl.is_paused():
			break

func test_menu_shows_limit_instead_of_attack_when_full() -> void:
	_setup(1.0)
	assert_eq(menu.entry_labels(), PackedStringArray(["Limite", "Habilidade", "Item", "Suporte"]))
	assert_true(menu.entry_enabled(0))

func test_menu_keeps_attack_below_full() -> void:
	_setup(0.99)
	assert_eq(menu.entry_labels()[0], "Atacar")

func test_limit_flow_submits_limit_action() -> void:
	_setup(1.0)
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	menu.accept()
	var a: PendingAction = ctrl.executing
	assert_not_null(a)
	assert_true(a.is_limit)
	assert_eq(h.limit, 0.0)

func test_cancel_from_limit_target_returns_to_root_with_bar() -> void:
	_setup(1.0)
	menu.accept()
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)
	assert_eq(menu.cursor, 0)
	assert_eq(h.limit, 1.0)

func test_cursor_memory_still_works_with_limit() -> void:
	_setup(1.0)
	menu.remember_cursor = true
	menu.move(1)
	menu.accept()
	menu.cancel()
	menu.close()
	menu.open(ctrl.session)
	assert_eq(menu.cursor, 1, "lembra Habilidade mesmo com Limite na posicao 0")

func test_view_limit_bar_blinks_only_when_full() -> void:
	_setup(0.5)
	var v := CombatantView.new()
	add_child_autofree(v)
	v.bind(h, Fixtures.cfg())
	assert_eq(v.limit_color(), CombatantView.LIMIT_COLOR)
	h.limit = 1.0
	var seen: Dictionary = {}
	for i: int in 4:
		seen[v.limit_color()] = true
		OS.delay_msec(130)
	assert_true(seen.size() >= 1)

func test_status_and_panel_show_percent() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var d: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 2))
	var gs := GameState.new()
	gs.cfg = cfg
	var hs := HeroState.create(d, cfg)
	hs.limit = 0.4
	gs.heroes = [hs] as Array[HeroState]
	var panel := PartyPanel.new()
	add_child_autofree(panel)
	panel.refresh(gs)
	assert_string_contains(panel.card_text(0), "Limite 40%")
	var page := StatusPage.new()
	add_child_autofree(page)
	page.state = gs
	assert_string_contains(page._build_text(hs), "Limite: 40%")

func test_smart_policy_uses_limit_and_basic_does_not() -> void:
	_setup(1.0)
	var s := SelectionSession.new(h, ctrl.b)
	var a: PendingAction = SimPolicy.decide(s, ctrl.b, &"smart")
	assert_true(a.is_limit)
	s = SelectionSession.new(h, ctrl.b)
	a = SimPolicy.decide(s, ctrl.b, &"basic")
	assert_false(a.is_limit)
	assert_eq(a.ability, h.basic_attack)

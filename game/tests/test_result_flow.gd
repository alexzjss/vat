extends GutTest

## Fluxo pós-batalha na cena real (auto_battle + Dice semeado): resultado, XP,
## alocação de pontos, "Lutar de novo" e "Tentar de novo".

const SCENE: String = "res://battle/battle_scene.tscn"
const HEROES: Array[String] = ["teste_a", "teste_b", "teste_c"]

var _opened: Array[HeroState] = []

func before_each() -> void:
	_opened = []

func _heroes(cfg: BalanceConfig) -> Array[HeroState]:
	var out: Array[HeroState] = []
	for id: String in HEROES:
		out.append(HeroState.create(load("res://data/test/heroes/%s.tres" % id) as CharacterDef, cfg))
	return out

func _enemies(stats: Stats) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	var ids: Array[StringName] = [&"x", &"y", &"z"]
	var xps: Array[int] = [100, 100, 150]
	for i: int in ids.size():
		out.append(Fixtures.enemy_def(ids[i], Stats.make(stats.strength, stats.speed, stats.vitality, stats.aura), xps[i]))
	return out

func _scene(enemy_stats: Stats) -> BattleScene:
	var packed: PackedScene = load(SCENE) as PackedScene
	var s: BattleScene = packed.instantiate() as BattleScene
	s.balance = Fixtures.cfg()
	s.auto_battle = true
	s.dice_seed = 7
	s.enemy_defs = _enemies(enemy_stats)
	add_child_autofree(s)
	s.set_process(false)
	return s

func _weak() -> Stats:
	return Stats.make(1, 1, 1, 0)

func _strong() -> Stats:
	return Stats.make(80, 40, 60, 0)

func _run_to_end(s: BattleScene) -> void:
	var steps: int = 0
	while s.ctrl.outcome == BattleController.Outcome.ONGOING and steps < 20000:
		s.ctrl.tick(0.1)
		steps += 1
	assert_ne(s.ctrl.outcome, BattleController.Outcome.ONGOING, "batalha terminou")

func _result(s: BattleScene) -> ResultScreen:
	return s.get_node("UI/ResultScreen") as ResultScreen

func _level_up(s: BattleScene) -> LevelUpScreen:
	return s.get_node("UI/LevelUpScreen") as LevelUpScreen

func _on_opened(h: HeroState) -> void:
	_opened.append(h)

## Avança o resultado e sai de todas as telas de nível sem alocar.
func _skip_level_ups(s: BattleScene) -> void:
	_result(s).accept()
	var guard: int = 0
	while _level_up(s).visible and guard < 10:
		_level_up(s).leave()
		guard += 1

func test_victory_xp_per_hero_matches_combat_xp() -> void:
	var s: BattleScene = _scene(_weak())
	var hs: Array[HeroState] = _heroes(s.balance)
	s.start(hs)
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.VICTORY)
	var b: BattleState = s.ctrl.b
	var expected: Dictionary[StringName, int] = XpCalculator.combat_xp(b.ledger, b.enemies, b.heroes, false)
	assert_eq(s.last_xp, expected)
	var r: ResultScreen = _result(s)
	assert_true(r.visible)
	assert_eq(r.mode, ResultScreen.Mode.VICTORY)
	var text: String = "\n".join(r.lines())
	for h: HeroState in hs:
		assert_eq(h.xp, expected[h.def.id], "XP concedida a %s" % h.def.id)
		assert_string_contains(text, "%s: +%d XP (Nv 1" % [h.def.display_name, expected[h.def.id]])
	assert_string_contains(text, "Vitória")

func test_level_change_shown_in_result_line() -> void:
	var s: BattleScene = _scene(_weak())
	var hs: Array[HeroState] = _heroes(s.balance)
	s.start(hs)
	_run_to_end(s)
	var text: String = "\n".join(_result(s).lines())
	for h: HeroState in hs:
		if h.level > 1:
			assert_string_contains(text, "(Nv 1 → %d)" % h.level)
		else:
			assert_string_contains(text, "%s: +%d XP (Nv 1)" % [h.def.display_name, h.xp])

func test_hp_ap_written_back_on_end() -> void:
	var s: BattleScene = _scene(_weak())
	var hs: Array[HeroState] = _heroes(s.balance)
	s.start(hs)
	_run_to_end(s)
	for c: Combatant in s.ctrl.b.heroes:
		assert_eq(c.hero_state.hp, c.hp, "HP de %s" % c.id)
		assert_eq(c.hero_state.ap, c.ap, "AP de %s" % c.id)

func test_hp_ap_written_back_on_defeat_downed_stay_zero() -> void:
	var s: BattleScene = _scene(_strong())
	var hs: Array[HeroState] = _heroes(s.balance)
	s.start(hs)
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.DEFEAT)
	for h: HeroState in hs:
		assert_eq(h.hp, 0, "caído fica com HP 0")

func test_fight_again_keeps_same_hero_states_and_hp_ap() -> void:
	var s: BattleScene = _scene(_weak())
	var hs: Array[HeroState] = _heroes(s.balance)
	hs[1].hp = 9
	hs[2].hp = 0
	s.start(hs)
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.VICTORY)
	var hp_end: Array[int] = []
	var ap_end: Array[int] = []
	for h: HeroState in hs:
		hp_end.append(h.hp)
		ap_end.append(h.ap)
	assert_eq(hs[2].hp, 0, "caído no início continua caído")
	var old_ctrl: BattleController = s.ctrl
	_skip_level_ups(s)
	var r: ResultScreen = _result(s)
	assert_true(r.visible)
	assert_eq(r.action_label(), "Lutar de novo")
	r.accept()
	assert_ne(s.ctrl, old_ctrl, "nova batalha")
	assert_false(r.visible)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.ONGOING)
	for i: int in hs.size():
		var c: Combatant = s.ctrl.b.heroes[i]
		assert_same(c.hero_state, hs[i], "mesmo HeroState")
		assert_eq(c.hp, hp_end[i], "HP persiste")
		assert_eq(c.ap, ap_end[i], "AP persiste")
	for e: Combatant in s.ctrl.b.enemies:
		assert_false(e.is_down(), "inimigos novos")

func test_multi_level_opens_single_screen_with_all_points() -> void:
	var s: BattleScene = _scene(_weak())
	var hs: Array[HeroState] = _heroes(s.balance)
	s.start(hs)
	_level_up(s).opened.connect(_on_opened)
	_run_to_end(s)
	var multi: HeroState = null
	for h: HeroState in hs:
		if h.level >= 3:
			multi = h
	assert_not_null(multi, "algum herói subiu 2+ níveis (cenário do teste)")
	var expected_pts: Dictionary[HeroState, int] = {}
	for h: HeroState in hs:
		var pts: int = 0
		for lv: int in range(2, h.level + 1):
			pts += XpCalculator.points_for_level(lv)
		expected_pts[h] = pts
		assert_eq(h.pending_points, pts)
	assert_false(_level_up(s).visible, "nível só depois do resultado")
	_result(s).accept()
	var guard: int = 0
	while _level_up(s).visible and guard < 10:
		var lu: LevelUpScreen = _level_up(s)
		assert_eq(lu.remaining(), expected_pts[lu.hero], "todos os pontos numa tela")
		lu.leave()
		guard += 1
	var with_points: int = 0
	for h: HeroState in hs:
		if expected_pts[h] > 0:
			with_points += 1
			assert_eq(_opened.count(h), 1, "uma única tela por herói")
	assert_eq(_opened.size(), with_points)

func test_allocation_through_scene_applies() -> void:
	var s: BattleScene = _scene(_weak())
	var hs: Array[HeroState] = _heroes(s.balance)
	s.start(hs)
	_run_to_end(s)
	_result(s).accept()
	var lu: LevelUpScreen = _level_up(s)
	assert_true(lu.visible)
	var h: HeroState = lu.hero
	var pts: int = h.pending_points
	var str0: int = h.allocated.strength
	assert_true(lu.increment(&"strength"))
	lu.confirm()
	assert_eq(h.allocated.strength, str0 + 1)
	assert_eq(h.pending_points, pts - 1)

func _standalone(pending: int) -> LevelUpScreen:
	var lu := LevelUpScreen.new()
	add_child_autofree(lu)
	var h: HeroState = HeroState.create(load("res://data/test/heroes/teste_a.tres") as CharacterDef, Fixtures.cfg())
	h.allocated = Stats.make(2, 0, 0, 0)
	h.pending_points = pending
	lu.open(h)
	return lu

func test_allocation_cannot_go_below_opening_values() -> void:
	var lu: LevelUpScreen = _standalone(3)
	var h: HeroState = lu.hero
	assert_false(lu.decrement(&"strength"), "não abaixo do valor ao abrir")
	assert_eq(lu.shown_value(&"strength"), h.def.base.strength + 2)
	assert_true(lu.increment(&"strength"))
	assert_true(lu.increment(&"strength"))
	assert_true(lu.decrement(&"strength"))
	assert_true(lu.decrement(&"strength"))
	assert_false(lu.decrement(&"strength"), "volta ao valor de abertura e para")
	assert_eq(lu.draft(&"strength"), 0)
	assert_true(lu.increment(&"strength"))
	assert_true(lu.increment(&"speed"))
	assert_true(lu.increment(&"aura"))
	assert_false(lu.increment(&"vitality"), "sem pontos sobrando")
	assert_eq(lu.remaining(), 0)
	assert_eq(h.allocated.strength, 2, "nada aplicado antes de confirmar")
	lu.confirm()
	assert_eq(h.allocated.strength, 3)
	assert_eq(h.allocated.speed, 1)
	assert_eq(h.allocated.aura, 1)
	assert_eq(h.allocated.vitality, 0)
	assert_eq(h.pending_points, 0)
	assert_false(lu.visible)

func test_confirm_partial_keeps_remaining_points() -> void:
	var lu: LevelUpScreen = _standalone(3)
	var h: HeroState = lu.hero
	lu.increment(&"vitality")
	lu.confirm()
	assert_eq(h.allocated.vitality, 1)
	assert_eq(h.pending_points, 2)

func test_leave_keeps_pending_points() -> void:
	var lu: LevelUpScreen = _standalone(2)
	var h: HeroState = lu.hero
	lu.increment(&"speed")
	lu.leave()
	assert_eq(h.allocated.speed, 0)
	assert_eq(h.pending_points, 2)
	assert_false(lu.visible)

func test_keyboard_navigation_allocates() -> void:
	var lu: LevelUpScreen = _standalone(2)
	var h: HeroState = lu.hero
	lu.move(1)
	assert_eq(lu.cursor, 1, "linha Velocidade")
	lu.adjust(1)
	lu.adjust(1)
	lu.adjust(-1)
	assert_eq(lu.draft(&"speed"), 1)
	assert_string_contains("\n".join(lu.row_labels()), "Velocidade")
	lu.move(4 - lu.cursor)
	assert_eq(lu.row_labels()[lu.cursor].strip_edges(), "Confirmar")
	lu.accept()
	assert_eq(h.allocated.speed, 1)
	assert_eq(h.pending_points, 1)

func test_defeat_retry_restores_start_snapshot() -> void:
	var s: BattleScene = _scene(_strong())
	var hs: Array[HeroState] = _heroes(s.balance)
	hs[0].xp = 15
	hs[0].level = 2
	hs[0].pending_points = 1
	hs[0].allocated = Stats.make(1, 0, 0, 0)
	hs[0].hp = 20
	hs[1].ap = 3
	var hp0: Array[int] = []
	var ap0: Array[int] = []
	for h: HeroState in hs:
		hp0.append(h.hp)
		ap0.append(h.ap)
	s.start(hs)
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.DEFEAT)
	var r: ResultScreen = _result(s)
	assert_true(r.visible)
	assert_eq(r.mode, ResultScreen.Mode.DEFEAT)
	assert_string_contains("\n".join(r.lines()), "Derrota")
	assert_eq(r.action_label(), "Tentar de novo")
	assert_eq(hs[0].xp, 15, "derrota não dá XP")
	assert_false(_level_up(s).visible)
	var old_ctrl: BattleController = s.ctrl
	r.accept()
	assert_ne(s.ctrl, old_ctrl)
	assert_eq(hs[0].xp, 15)
	assert_eq(hs[0].level, 2)
	assert_eq(hs[0].pending_points, 1)
	assert_eq(hs[0].allocated.strength, 1)
	for i: int in hs.size():
		assert_eq(hs[i].hp, hp0[i], "HP restaurado")
		assert_eq(hs[i].ap, ap0[i], "AP restaurado")
		assert_eq(s.ctrl.b.heroes[i].hp, hp0[i])
		assert_same(s.ctrl.b.heroes[i].hero_state, hs[i])

func test_snapshot_is_deep_copy() -> void:
	var s: BattleScene = _scene(_strong())
	var hs: Array[HeroState] = _heroes(s.balance)
	s.start(hs)
	hs[0].allocated.strength = 9
	_run_to_end(s)
	_result(s).accept()
	assert_eq(hs[0].allocated.strength, 0, "snapshot não compartilha Stats")

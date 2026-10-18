extends GutTest

## BattleScene no modo MAP: posições/inventário vindos de fora, deslize de entrada,
## "Continuar"/"Game Over" emitindo `finished` sem reiniciar a batalha.

const SCENE: String = "res://battle/battle_scene.tscn"
const HEROES: Array[String] = ["teste_a", "teste_b", "teste_c"]
const HERO_POS: Array[Vector2] = [Vector2(100, 100), Vector2(100, 200), Vector2(100, 300)]

var _finished: Array[BattleController.Outcome] = []

func before_each() -> void:
	_finished = []

func _on_finished(o: BattleController.Outcome) -> void:
	_finished.append(o)

func _heroes(cfg: BalanceConfig) -> Array[HeroState]:
	var out: Array[HeroState] = []
	for id: String in HEROES:
		out.append(HeroState.create(load("res://data/test/heroes/%s.tres" % id) as CharacterDef, cfg))
	return out

func _enemies(stats: Stats, n: int) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for i: int in n:
		out.append(Fixtures.enemy_def(&"x", Stats.make(stats.strength, stats.speed, stats.vitality, stats.aura), 100))
	return out

func _enemy_pos(n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in n:
		out.append(Vector2(500, 150 + 100 * i))
	return out

func _weak() -> Stats:
	return Stats.make(1, 1, 1, 0)

func _strong() -> Stats:
	return Stats.make(80, 40, 60, 0)

func _scene() -> BattleScene:
	var packed: PackedScene = load(SCENE) as PackedScene
	var s: BattleScene = packed.instantiate() as BattleScene
	s.balance = Fixtures.cfg()
	s.auto_battle = true
	s.dice_seed = 7
	add_child_autofree(s)
	s.set_process(false)
	s.mode = BattleScene.Mode.MAP
	s.finished.connect(_on_finished)
	return s

func _start(s: BattleScene, stats: Stats, n: int, inv: Inventory = null, from_pos: Vector2 = Vector2.INF) -> Array[HeroState]:
	var hs: Array[HeroState] = _heroes(s.balance)
	var i: Inventory = inv if inv != null else Inventory.new()
	s.start_with(hs, _enemies(stats, n), HERO_POS, _enemy_pos(n), i, from_pos)
	return hs

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

func _skip_level_ups(s: BattleScene) -> void:
	_result(s).accept()
	var guard: int = 0
	while _level_up(s).visible and guard < 10:
		_level_up(s).leave()
		guard += 1

func test_map_mode_uses_given_positions() -> void:
	var s: BattleScene = _scene()
	_start(s, _weak(), 1)
	var b: BattleState = s.ctrl.b
	for i: int in 3:
		assert_eq(b.heroes[i].position, HERO_POS[i])
		assert_eq(s.views[b.heroes[i].id].position, HERO_POS[i])
	assert_eq(b.enemies.size(), 1)
	assert_eq(b.enemies[0].position, Vector2(500, 150))
	assert_eq(s.views[b.enemies[0].id].position, Vector2(500, 150))

func test_map_mode_enemy_ids_are_unique() -> void:
	var s: BattleScene = _scene()
	_start(s, _weak(), 3)
	var b: BattleState = s.ctrl.b
	assert_eq(b.enemies[0].id, &"x_0")
	assert_eq(b.enemies[2].id, &"x_2")
	assert_eq(s.views.size(), 6, "uma view por combatente, sem colisão de id")

func test_slide_in_delays_ticking() -> void:
	var s: BattleScene = _scene()
	var from: Vector2 = Vector2(640, 360)
	_start(s, _weak(), 1, null, from)
	var b: BattleState = s.ctrl.b
	for v: CombatantView in s.views.values():
		assert_eq(v.position, from, "views começam no ponto de origem")
	var slide: float = s.balance.battle_slide_time
	s._process(slide * 0.25)
	s._process(slide * 0.25)
	assert_eq(b.tick, 0, "sem tick durante o deslize")
	var hv: CombatantView = s.views[b.heroes[0].id]
	assert_ne(hv.position, from, "view se moveu")
	assert_ne(hv.position, HERO_POS[0], "ainda não chegou")
	s._process(slide * 0.5 + 0.01)
	assert_eq(hv.position, HERO_POS[0], "chegou ao fim do deslize")
	assert_eq(s.views[b.enemies[0].id].position, Vector2(500, 150))
	s._process(0.1)
	s._process(0.1)
	assert_gt(b.tick, 0, "ticks avançam após o deslize")

func test_map_mode_victory_emits_finished_after_continue() -> void:
	var s: BattleScene = _scene()
	_start(s, _weak(), 1)
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.VICTORY)
	var r: ResultScreen = _result(s)
	assert_true(r.visible)
	assert_string_contains("\n".join(r.lines()), "XP")
	assert_false((s.get_node("OutcomeLabel") as Label).visible, "OutcomeLabel escondido")
	_skip_level_ups(s)
	assert_true(r.visible)
	assert_eq(r.action_labels(), PackedStringArray(["Continuar"]))
	assert_eq(_finished.size(), 0, "ainda não emitiu")
	var old_ctrl: BattleController = s.ctrl
	r.accept()
	assert_eq(_finished, [BattleController.Outcome.VICTORY] as Array[BattleController.Outcome])
	assert_same(s.ctrl, old_ctrl, "não reinicia a batalha")
	r.accept()
	assert_eq(_finished.size(), 1, "emitido uma vez")

func test_map_mode_defeat_shows_game_over_and_emits() -> void:
	var s: BattleScene = _scene()
	_start(s, _strong(), 3)
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.DEFEAT)
	var r: ResultScreen = _result(s)
	assert_true(r.visible)
	assert_eq(r.lines()[0], "Game Over")
	assert_eq(r.action_labels(), PackedStringArray(["Continuar"]))
	var old_ctrl: BattleController = s.ctrl
	r.accept()
	assert_eq(_finished, [BattleController.Outcome.DEFEAT] as Array[BattleController.Outcome])
	assert_same(s.ctrl, old_ctrl, "a batalha não reinicia")
	assert_eq(s.ctrl.outcome, BattleController.Outcome.DEFEAT)

func test_map_mode_uses_given_inventory() -> void:
	var s: BattleScene = _scene()
	var potion: ItemDef = load("res://data/test/items/pocao.tres") as ItemDef
	var inv := Inventory.new()
	inv.add(potion, 1)
	_start(s, _weak(), 1, inv)
	assert_same(s.ctrl.b.inventory, inv, "mesmo objeto de inventário")
	var ss := SelectionSession.new(s.ctrl.b.heroes[0], s.ctrl.b)
	assert_true(ss.choose_item(potion))
	ss.set_center(ss.target_candidates()[0])
	assert_not_null(ss.confirm())
	assert_eq(inv.available(potion.id), 0)
	_start(s, _weak(), 1, inv)
	assert_same(s.ctrl.b.inventory, inv)
	assert_eq(s.ctrl.b.inventory.available(potion.id), 0, "poção gasta não volta")

func test_map_mode_hides_background() -> void:
	var s: BattleScene = _scene()
	_start(s, _weak(), 1)
	assert_false((s.get_node("Background") as CanvasItem).visible)
	assert_false((s.get_node("OutcomeLabel") as CanvasItem).visible)

func test_standalone_unchanged() -> void:
	var packed: PackedScene = load(SCENE) as PackedScene
	var s: BattleScene = packed.instantiate() as BattleScene
	s.balance = Fixtures.cfg()
	s.auto_battle = true
	s.dice_seed = 7
	var defs: Array[EnemyDef] = []
	for id: StringName in [&"x", &"y", &"z"]:
		defs.append(Fixtures.enemy_def(id, _weak(), 100))
	s.enemy_defs = defs
	add_child_autofree(s)
	s.set_process(false)
	s.finished.connect(_on_finished)
	assert_eq(s.mode, BattleScene.Mode.STANDALONE)
	s.start(_heroes(s.balance))
	assert_true((s.get_node("Background") as CanvasItem).visible)
	assert_eq(s.ctrl.b.enemies[0].id, &"x", "standalone mantém def.id")
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.VICTORY)
	_skip_level_ups(s)
	assert_eq(_result(s).action_labels(), PackedStringArray(["Descansar e lutar", "Lutar de novo"]))
	var old_ctrl: BattleController = s.ctrl
	_result(s).accept()
	assert_ne(s.ctrl, old_ctrl, "standalone reinicia")
	assert_eq(_finished.size(), 0, "standalone não emite finished")

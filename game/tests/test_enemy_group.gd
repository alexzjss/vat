extends GutTest

## Grupo que se junta e chefes únicos (M7).

const SCENE: String = "res://world/local_map.tscn"
const HEROES: Array[String] = ["teste_a", "teste_b", "teste_c"]
const TMP: String = "user://test_saves_group/"

var map: LocalMap
var state: GameState

func before_each() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var defs: Array[CharacterDef] = []
	for id: String in HEROES:
		defs.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	state = GameState.new_game(cfg, defs, items, counts, Dice.new(7), &"local", &"Entry")
	map = _make_map()

func after_each() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _make_map() -> LocalMap:
	var m: LocalMap = (load(SCENE) as PackedScene).instantiate() as LocalMap
	m.auto_battle = true
	m.dice_seed = 7
	add_child_autofree(m)
	m.setup(state, &"Entry")
	return m

func _node(n: String) -> MapEnemy:
	return map.get_node_or_null(n) as MapEnemy

func _weak(id: StringName) -> EncounterDef:
	var e := EncounterDef.new()
	e.id = id
	var list: Array[EnemyDef] = [Fixtures.enemy_def(id, Stats.make(1, 1, 1, 0), 100)]
	e.enemies = list
	return e

func _run_to_end(s: BattleScene) -> void:
	var steps: int = 0
	while s.ctrl.outcome == BattleController.Outcome.ONGOING and steps < 20000:
		s.ctrl.tick(0.1)
		steps += 1

func _accept_all(s: BattleScene) -> void:
	var result: ResultScreen = s.get_node("UI/ResultScreen") as ResultScreen
	var level_up: LevelUpScreen = s.get_node("UI/LevelUpScreen") as LevelUpScreen
	result.accept()
	var guard: int = 0
	while level_up.visible and guard < 10:
		level_up.leave()
		guard += 1
	result.accept()

func _touch(e: MapEnemy) -> BattleScene:
	e.touched.emit(e)
	assert_not_null(map.battle)
	map.battle.set_process(false)
	return map.battle

## Deixa só o par de grupo, com encontros fracos de um inimigo cada.
func _only_group() -> void:
	for n: String in ["Enemy", "Patroller", "Chaser", "Lurker", "Boss"]:
		var e: MapEnemy = _node(n)
		map.remove_child(e)
		e.free()
	_node("GroupA").encounter = _weak(&"ga")
	_node("GroupB").encounter = _weak(&"gb")

func test_group_joins_only_nearby_members() -> void:
	_only_group()
	var a: MapEnemy = _node("GroupA")
	var b: MapEnemy = _node("GroupB")
	b.global_position = a.global_position + Vector2(map.state.cfg.group_join_dist + 50.0, 0)
	var s := _touch(a)
	assert_eq(s.ctrl.b.enemies.size(), 1, "o distante nao entra")
	assert_true(b.visible)

func test_group_nearby_members_join_and_vanish_on_victory() -> void:
	_only_group()
	var a: MapEnemy = _node("GroupA")
	var b: MapEnemy = _node("GroupB")
	b.global_position = a.global_position + Vector2(60, 0)
	var s := _touch(a)
	assert_eq(s.ctrl.b.enemies.size(), 2)
	_run_to_end(s)
	_accept_all(s)
	assert_true(a.is_queued_for_deletion())
	assert_true(b.is_queued_for_deletion())

func test_group_is_limited_to_arena_spots_in_stable_order() -> void:
	_only_group()
	var a: MapEnemy = _node("GroupA")
	var b: MapEnemy = _node("GroupB")
	var c: MapEnemy = a.duplicate() as MapEnemy
	c.name = "GroupC"
	c.encounter = _weak(&"gc")
	map.add_child(c)
	c.player = map.player
	c.setup(state.cfg, state.dice)
	b.global_position = a.global_position + Vector2(40, 0)
	c.global_position = a.global_position + Vector2(80, 0)
	for extra: String in ["EnemySpot3", "EnemySpot4"]:
		var n: Node = map.get_node("Arena/" + extra)
		n.get_parent().remove_child(n)
		n.free()
	var spots: int = (map.get_node("Arena") as BattleArena).enemy_count()
	assert_eq(spots, 2)
	var s := _touch(a)
	assert_eq(s.ctrl.b.enemies.size(), spots)
	assert_eq(s.ctrl.b.enemies[0].id, &"ga_0")
	assert_eq(s.ctrl.b.enemies[1].id, &"gb_1", "ordem da cena: B antes de C")
	assert_true(c.visible, "o que nao coube fica no mapa")
	_run_to_end(s)
	_accept_all(s)
	assert_false(c.is_queued_for_deletion())
	assert_true(c.in_cooldown(), "o que nao coube nao toca de novo na hora")

func test_group_with_unfleeable_member_cannot_flee() -> void:
	_only_group()
	var a: MapEnemy = _node("GroupA")
	var b: MapEnemy = _node("GroupB")
	b.global_position = a.global_position + Vector2(40, 0)
	b.encounter.can_flee = false
	var s := _touch(a)
	assert_false(s.ctrl.can_flee)

# --- Chefes únicos --------------------------------------------------------------------

func _beat_boss() -> void:
	var boss: MapEnemy = _node("Boss")
	boss.encounter = boss.encounter.duplicate() as EncounterDef
	var list: Array[EnemyDef] = [Fixtures.enemy_def(&"z", Stats.make(1, 1, 1, 0), 100)]
	boss.encounter.enemies = list
	var s := _touch(boss)
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.VICTORY)
	_accept_all(s)

func test_boss_cannot_flee_and_is_unique() -> void:
	var boss: MapEnemy = _node("Boss")
	assert_false(boss.encounter.can_flee)
	assert_eq(boss.encounter.unique_id, &"chefe_teste")

func test_boss_does_not_respawn_after_defeat() -> void:
	_beat_boss()
	assert_true(state.is_defeated(&"chefe_teste"))
	map.queue_free()
	await wait_frames(2)
	map = _make_map()
	assert_null(_node("Boss"), "nao e instanciado de novo")
	assert_not_null(_node("Enemy"), "comuns continuam")

func test_boss_does_not_respawn_after_save_and_load() -> void:
	_beat_boss()
	state.save(&"local", &"Entry")
	var store := SaveStore.new(TMP, SaveStore.build_registry(), state.cfg)
	assert_true(store.write(1, state))
	var loaded: GameState = store.read(1, Dice.new(9))
	assert_not_null(loaded)
	assert_true(loaded.is_defeated(&"chefe_teste"))
	state = loaded
	map.queue_free()
	await wait_frames(2)
	map = _make_map()
	assert_null(_node("Boss"))

func test_defeated_is_optional_in_old_saves() -> void:
	var d: Dictionary = state.to_dict()
	assert_false(d.has("defeated"), "vazio nao grava o campo")
	var g: GameState = GameState.from_dict(d, SaveStore.build_registry(), state.cfg, Dice.new(1))
	assert_not_null(g)
	assert_true(g.defeated.is_empty())

func test_game_over_retry_restores_boss() -> void:
	state.save(&"local", &"Entry")
	state.mark_defeated(&"chefe_teste")
	state.restore_save()
	assert_false(state.is_defeated(&"chefe_teste"))

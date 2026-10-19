extends GutTest

## Área local: encontro no mapa (batalha MAP sobre o mapa), vitória/derrota e saída.

const SCENE: String = "res://world/local_map.tscn"
const HEROES: Array[String] = ["teste_a", "teste_b", "teste_c"]

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
	map = (load(SCENE) as PackedScene).instantiate() as LocalMap
	map.auto_battle = true
	map.dice_seed = 7
	add_child_autofree(map)
	map.setup(state, &"Entry")

func _enemy() -> MapEnemy:
	return map.get_node("Enemy") as MapEnemy

func _arena() -> BattleArena:
	return map.get_node("Arena") as BattleArena

func _exit() -> Zone:
	return map.get_node("Exit") as Zone

func _player() -> Player:
	return map.get_node("Player") as Player

func _encounter(stats: Stats) -> EncounterDef:
	var e := EncounterDef.new()
	e.id = &"teste"
	var list: Array[EnemyDef] = []
	for id: StringName in [&"x", &"y"]:
		list.append(Fixtures.enemy_def(id, Stats.make(stats.strength, stats.speed, stats.vitality, stats.aura), 100))
	e.enemies = list
	return e

func _weak() -> EncounterDef:
	return _encounter(Stats.make(1, 1, 1, 0))

func _strong() -> EncounterDef:
	return _encounter(Stats.make(80, 40, 60, 0))

## Toca o inimigo com o encontro dado e desliga o _process da batalha (ticks manuais).
func _touch(enc: EncounterDef) -> BattleScene:
	_enemy().encounter = enc
	_enemy().touched.emit(_enemy())
	assert_not_null(map.battle, "batalha começou")
	map.battle.set_process(false)
	return map.battle

func _run_to_end(s: BattleScene) -> void:
	var steps: int = 0
	while s.ctrl.outcome == BattleController.Outcome.ONGOING and steps < 20000:
		s.ctrl.tick(0.1)
		steps += 1
	assert_ne(s.ctrl.outcome, BattleController.Outcome.ONGOING, "batalha terminou")

## Aceita resultado, fecha telas de nível e escolhe "Continuar".
func _accept_all(s: BattleScene) -> void:
	var result: ResultScreen = s.get_node("UI/ResultScreen") as ResultScreen
	var level_up: LevelUpScreen = s.get_node("UI/LevelUpScreen") as LevelUpScreen
	if s.ctrl.outcome == BattleController.Outcome.VICTORY:
		result.accept()
		var guard: int = 0
		while level_up.visible and guard < 10:
			level_up.leave()
			guard += 1
	assert_eq(result.action_labels(), PackedStringArray(["Continuar"]))
	result.accept()

func _win() -> BattleScene:
	var s: BattleScene = _touch(_weak())
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.VICTORY)
	_accept_all(s)
	return s

func test_setup_places_player_at_entry_and_camera_follows() -> void:
	var entry: Marker2D = map.get_node("Entry") as Marker2D
	assert_eq(_player().global_position, entry.global_position)
	var cam: MapCamera = map.get_node("MapCamera") as MapCamera
	assert_same(cam.follow, _player())
	assert_not_null(_enemy().movement, "inimigo configurado")
	assert_null(map.battle)

func test_touch_starts_battle_at_arena_positions() -> void:
	var s: BattleScene = _touch(_weak())
	assert_eq(s.mode, BattleScene.Mode.MAP)
	var ctrl: BattleController = s.ctrl
	var b: BattleState = ctrl.b
	var hero_pos: Array[Vector2] = _arena().hero_positions()
	for i: int in 3:
		assert_eq(b.heroes[i].position, hero_pos[i])
	var enemy_pos: Array[Vector2] = _arena().enemy_positions(2)
	assert_eq(b.enemies[0].position, enemy_pos[0])
	assert_eq(b.enemies[1].position, enemy_pos[1])
	assert_eq(b.enemies[0].id, &"x_0", "ids do modo MAP")
	assert_same(b.inventory, state.inventory, "inventário do estado de jogo")
	assert_false(_player().enabled)
	assert_false(_player().visible)
	assert_false(_enemy().visible)
	assert_true(_enemy().frozen)
	assert_false(_exit().armed)
	# O auto-start adiado da cena de batalha não pode substituir a batalha do mapa.
	await wait_physics_frames(3)
	assert_same(s.ctrl, ctrl, "auto-start standalone não venceu")
	assert_eq(s.ctrl.b.heroes[0].position, hero_pos[0])
	await wait_seconds(state.cfg.camera_slide_time + 0.2)
	var cam: MapCamera = map.get_node("MapCamera") as MapCamera
	assert_almost_eq(cam.global_position, _arena().center(), Vector2(1, 1))

func test_exit_label_is_utf8() -> void:
	assert_eq(_exit().label_text, "Saída")
	assert_eq(_exit().zone_id, &"exit")

func test_touch_without_encounter_is_ignored() -> void:
	_enemy().encounter = null
	_enemy().touched.emit(_enemy())
	assert_push_error("sem encontro")
	assert_null(map.battle)
	assert_true(_player().enabled)

func test_touch_twice_starts_one_battle() -> void:
	var s: BattleScene = _touch(_weak())
	_enemy().touched.emit(_enemy())
	assert_same(map.battle, s)
	var count: int = 0
	for child: Node in map.get_children():
		if child is BattleScene:
			count += 1
	assert_eq(count, 1)

func test_victory_removes_enemy_and_restores_control() -> void:
	var enemy: MapEnemy = _enemy()
	var s: BattleScene = _win()
	assert_null(map.battle)
	assert_true(s.is_queued_for_deletion(), "batalha liberada")
	await wait_physics_frames(2)
	assert_false(is_instance_valid(enemy), "inimigo removido")
	assert_true(_player().visible)
	assert_true(_player().enabled)
	assert_eq(_player().global_position, _arena().hero_positions()[0])
	assert_true(_exit().armed)

func test_player_can_move_after_victory() -> void:
	_win()
	await wait_physics_frames(2)
	# O ponto do líder não pode estar dentro de parede/obstáculo/inimigo (a física empurraria o jogador).
	assert_eq(_player().global_position, _arena().hero_positions()[0], "não foi empurrado por colisão")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = (_player().get_node("CollisionShape2D") as CollisionShape2D).shape
	query.transform = Transform2D(0.0, _arena().hero_positions()[0])
	query.collision_mask = 1 | 4
	query.exclude = [_player().get_rid()]
	assert_eq(map.get_world_2d().direct_space_state.intersect_shape(query).size(), 0, "ponto do líder livre")
	var moved: int = 0
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var start: Vector2 = _player().global_position
		_player().override_dir = dir
		await wait_physics_frames(20)
		_player().override_dir = Vector2.ZERO
		if _player().global_position.distance_to(start) > 10.0:
			moved += 1
	assert_gt(moved, 0, "não ficou preso em colisão")
	assert_eq(moved, 4, "ponto do líder em espaço aberto")

func test_hp_ap_persist_after_map_battle() -> void:
	var s: BattleScene = _touch(_weak())
	_run_to_end(s)
	var b: BattleState = s.ctrl.b
	_accept_all(s)
	for i: int in 3:
		assert_eq(state.heroes[i].hp, b.heroes[i].hp)
		assert_eq(state.heroes[i].ap, b.heroes[i].ap)

func test_defeat_emits_game_over() -> void:
	watch_signals(map)
	var s: BattleScene = _touch(_strong())
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.DEFEAT)
	assert_signal_not_emitted(map, "game_over")
	_accept_all(s)
	assert_signal_emit_count(map, "game_over", 1)

func test_exit_only_when_not_in_battle() -> void:
	watch_signals(map)
	_touch(_weak())
	_exit().entered.emit(&"exit")
	assert_signal_not_emitted(map, "exit_requested")
	_run_to_end(map.battle)
	_accept_all(map.battle)
	_exit().entered.emit(&"exit")
	assert_signal_emit_count(map, "exit_requested", 1)

func test_walking_into_exit_requests_exit() -> void:
	watch_signals(map)
	_player().override_dir = Vector2.LEFT
	await wait_physics_frames(60)
	assert_signal_emit_count(map, "exit_requested", 1)

func test_touch_ignored_during_battle_is_rearmed_after_victory() -> void:
	# Mapa próprio com um segundo inimigo, parado (MapMovement base não se move).
	var local: LocalMap = (load(SCENE) as PackedScene).instantiate() as LocalMap
	var second: MapEnemy = (load("res://world/map_enemy.tscn") as PackedScene).instantiate() as MapEnemy
	second.name = "Enemy2"
	second.position = Vector2(2300, 650)
	second.encounter = _weak()
	local.add_child(second)
	local.auto_battle = true
	local.dice_seed = 7
	add_child_autofree(local)
	second.movement = MapMovement.new()
	local.setup(state, &"Entry")
	var first: MapEnemy = local.get_node("Enemy") as MapEnemy
	var player: Player = local.get_node("Player") as Player
	first.encounter = _weak()
	first.touched.emit(first)
	var s: BattleScene = local.battle
	assert_not_null(s)
	s.set_process(false)
	# Toque do segundo inimigo durante a batalha: ignorado (e desarma o inimigo).
	second.global_position = player.global_position
	await wait_physics_frames(3)
	assert_same(local.battle, s, "toque ignorado durante a batalha")
	second.global_position = Vector2(2300, 650)
	await wait_physics_frames(3)
	_run_to_end(s)
	_accept_all(s)
	assert_null(local.battle)
	# Depois da vitória o segundo inimigo voltou a responder ao toque.
	second.global_position = player.global_position
	await wait_physics_frames(3)
	assert_not_null(local.battle, "segundo inimigo inicia batalha após a vitória")

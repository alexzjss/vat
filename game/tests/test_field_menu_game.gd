extends GutTest

## Menu de campo integrado ao Game: quando abre, congelamento do mapa, líder no mapa e formação na batalha.

const SCENE: String = "res://world/game.tscn"

var game: Game

func before_each() -> void:
	game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.skip_title = true
	add_child_autofree(game)

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	assert_false(game.busy, "transição terminou")

func _enter_area() -> LocalMap:
	(game.current as Overworld).location_entered.emit(&"area_teste")
	await _wait_idle()
	return game.current as LocalMap

func _player() -> Player:
	return game.current.get_node("Player") as Player

func _press_menu() -> void:
	var ev := InputEventAction.new()
	ev.action = &"open_menu"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame

func _weak_encounter() -> EncounterDef:
	var e := EncounterDef.new()
	e.id = &"fraco"
	var list: Array[EnemyDef] = []
	list.append(Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 0), 100))
	e.enemies = list
	return e

func test_menu_opens_on_overworld_and_local_map() -> void:
	await _wait_idle()
	assert_true(game.can_open_menu(), "pode abrir no mapa-múndi")
	assert_true(game.open_menu())
	assert_true(game.menu.is_open)
	assert_eq(game.current.process_mode, Node.PROCESS_MODE_DISABLED, "mapa congelado")
	game.menu.close()
	assert_eq(game.current.process_mode, Node.PROCESS_MODE_INHERIT, "mapa descongelado ao fechar")
	await _enter_area()
	assert_true(game.open_menu(), "pode abrir na área local")
	game.menu.close()

func test_open_menu_action_toggles_without_double_handling() -> void:
	await _wait_idle()
	await _press_menu()
	assert_true(game.menu.is_open, "open_menu abre")
	await _press_menu()
	assert_false(game.menu.is_open, "open_menu dentro do menu volta/fecha e não reabre")
	assert_eq(game.current.process_mode, Node.PROCESS_MODE_INHERIT)

func test_menu_blocked_during_battle_and_transition() -> void:
	await _wait_idle()
	(game.current as Overworld).location_entered.emit(&"area_teste")
	assert_true(game.busy)
	assert_false(game.can_open_menu(), "não abre durante a transição")
	assert_false(game.open_menu())
	await _wait_idle()
	var map: LocalMap = game.current as LocalMap
	map.auto_battle = true
	var enemy: MapEnemy = map.enemies()[0]
	enemy.encounter = _weak_encounter()
	enemy.touched.emit(enemy)
	assert_not_null(map.battle)
	assert_false(game.can_open_menu(), "não abre com batalha em andamento")
	await _press_menu()
	assert_false(game.menu.is_open)
	map.battle.set_process(false)
	map.battle.queue_free()
	map.battle = null
	map.locked = true
	assert_false(game.can_open_menu(), "não abre com o mapa travado (Game Over)")

func test_menu_does_not_open_twice() -> void:
	await _wait_idle()
	assert_true(game.open_menu())
	assert_false(game.can_open_menu(), "já aberto")
	assert_false(game.open_menu())
	game.menu.close()

func test_world_frozen_while_menu_open() -> void:
	await _wait_idle()
	var map: LocalMap = await _enter_area()
	var touches: Array[int] = [0]
	for e: MapEnemy in map.enemies():
		e.touched.connect(func(_x: MapEnemy) -> void: touches[0] += 1)
	var enemy: MapEnemy = map.enemies()[0]
	var player: Player = map.player
	player.override_dir = Vector2.RIGHT
	assert_true(game.open_menu())
	var p0: Vector2 = player.global_position
	var e0: Vector2 = enemy.global_position
	await wait_physics_frames(30)
	assert_eq(player.global_position, p0, "jogador parado")
	assert_eq(enemy.global_position, e0, "inimigo parado")
	assert_eq(touches[0], 0, "nenhum toque")
	assert_null(map.battle)
	player.override_dir = Vector2.ZERO
	game.menu.close()
	await wait_physics_frames(2)
	assert_eq(touches[0], 0, "nenhum toque ao fechar")

func test_leader_change_reflects_on_map() -> void:
	await _wait_idle()
	assert_eq(_player().leader_letter, "A", "líder inicial")
	assert_true(game.open_menu())
	game.state.swap(game.state.heroes[0], game.state.heroes[1])
	game.menu.close()
	assert_eq(_player().leader_letter, "B", "marcador mostra o novo líder")

func test_leader_initial_uses_last_word() -> void:
	assert_eq(Player.leader_initial("Teste D"), "D")
	assert_eq(Player.leader_initial("ana"), "A")
	assert_eq(Player.leader_initial(""), "")

func test_formation_change_reflects_in_next_battle() -> void:
	await _wait_idle()
	var d: HeroState = game.state.heroes[3]
	var e: HeroState = game.state.reserve[0]
	assert_true(game.open_menu())
	game.state.swap(d, e)
	game.menu.close()
	var map: LocalMap = await _enter_area()
	map.auto_battle = true
	var enemy: MapEnemy = map.enemies()[0]
	enemy.encounter = _weak_encounter()
	enemy.touched.emit(enemy)
	assert_not_null(map.battle)
	map.battle.set_process(false)
	var ids: Array[StringName] = []
	for h: HeroState in map.battle.hero_states:
		ids.append(h.def.id)
	assert_eq(ids, [&"teste_a", &"teste_b", &"teste_c", e.def.id] as Array[StringName], "E no lugar de D")

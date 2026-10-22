extends GutTest

## Jogo raiz: abre no mapa-múndi, entra/sai da área local com fade e trata o Game Over.

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

func _player() -> Player:
	return game.current.get_node("Player") as Player

func _marker(name: String) -> Marker2D:
	return game.current.get_node(name) as Marker2D

func _enter_area() -> LocalMap:
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	await _wait_idle()
	return game.current as LocalMap

func _map_enemies(map: LocalMap) -> int:
	# Só o inimigo comum "Enemy": o mapa de teste tem também os do M7 (patrulheiro, chefe etc.).
	return map.enemies().filter(func(e: MapEnemy) -> bool: return e.name == &"Enemy").size()

func _weak_encounter() -> EncounterDef:
	var e := EncounterDef.new()
	e.id = &"fraco"
	var list: Array[EnemyDef] = []
	list.append(Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 0), 100))
	e.enemies = list
	return e

func _strong_encounter() -> EncounterDef:
	var e := EncounterDef.new()
	e.id = &"forte"
	var list: Array[EnemyDef] = []
	for id: StringName in [&"x", &"y"]:
		list.append(Fixtures.enemy_def(id, Stats.make(80, 40, 60, 0), 100))
	e.enemies = list
	return e

## Toca o inimigo, roda a batalha até o fim com ticks manuais e aceita as telas.
func _fight(map: LocalMap, enc: EncounterDef) -> BattleController.Outcome:
	map.auto_battle = true
	map.dice_seed = 7
	var enemy: MapEnemy = map.enemies()[0]
	enemy.encounter = enc
	enemy.touched.emit(enemy)
	var s: BattleScene = map.battle
	assert_not_null(s, "batalha começou")
	s.set_process(false)
	var steps: int = 0
	while s.ctrl.outcome == BattleController.Outcome.ONGOING and steps < 20000:
		s.ctrl.tick(0.1)
		steps += 1
	var outcome: BattleController.Outcome = s.ctrl.outcome
	var result: ResultScreen = s.get_node("UI/ResultScreen") as ResultScreen
	var level_up: LevelUpScreen = s.get_node("UI/LevelUpScreen") as LevelUpScreen
	if outcome == BattleController.Outcome.VICTORY:
		result.accept()
		var guard: int = 0
		while level_up.visible and guard < 10:
			level_up.leave()
			guard += 1
	result.accept()
	return outcome

func test_starts_on_overworld_at_start() -> void:
	assert_not_null(game.state, "estado criado")
	assert_true(game.current is Overworld)
	assert_eq(_player().global_position, _marker("Start").global_position)
	assert_eq(game.state.save_map, &"overworld")
	assert_eq(game.state.save_spawn, &"Start")
	assert_eq(game.state.heroes.size(), 4, "quatro heróis ativos")
	assert_eq(game.state.reserve.size(), 1, "teste_e na reserva")
	assert_false(game.busy)

func test_starting_content_matches_m1() -> void:
	assert_eq(game.test_profile.party.size(), 5)
	assert_eq(game.test_profile.items.size(), 4)
	assert_eq(game.test_profile.item_counts, [3, 2, 1, 1] as Array[int])
	for i: int in game.test_profile.items.size():
		assert_eq(game.state.inventory.available(game.test_profile.items[i].id), game.test_profile.item_counts[i])

func test_fade_layer_above_battle_ui() -> void:
	var fade: Fade = game.get_node("Fade") as Fade
	assert_gt(fade.layer, 1, "acima do CanvasLayer UI da batalha")
	var rect: ColorRect = fade.get_node("Rect") as ColorRect
	assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_enter_location_loads_local_map_at_entry() -> void:
	var map: LocalMap = await _enter_area()
	assert_not_null(map, "current é LocalMap")
	assert_eq(_player().global_position, _marker("Entry").global_position)
	assert_same(map.state, game.state)
	var fade: Fade = game.get_node("Fade") as Fade
	assert_almost_eq((fade.get_node("Rect") as ColorRect).modulate.a, 0.0, 0.01, "fade terminou transparente")

func test_exit_returns_beside_location_not_inside() -> void:
	var map: LocalMap = await _enter_area()
	map.exit_requested.emit()
	await _wait_idle()
	assert_true(game.current is Overworld)
	assert_eq(_player().global_position, _marker("AreaTesteReturn").global_position)
	watch_signals(game.current)
	await wait_physics_frames(30)
	assert_signal_not_emitted(game.current, "location_entered")
	assert_true(game.current is Overworld, "não reentrou na área")

func test_reenter_respawns_enemy() -> void:
	var map: LocalMap = await _enter_area()
	assert_eq(_map_enemies(map), 1)
	var outcome: BattleController.Outcome = _fight(map, _weak_encounter())
	assert_eq(outcome, BattleController.Outcome.VICTORY)
	await wait_physics_frames(2)
	assert_eq(_map_enemies(map), 0, "inimigo derrotado")
	map.exit_requested.emit()
	await _wait_idle()
	var again: LocalMap = await _enter_area()
	assert_ne(again, map, "área instanciada de novo")
	assert_eq(_map_enemies(again), 1, "inimigo reapareceu")

func test_game_over_restores_save_and_returns_to_start() -> void:
	var hero: HeroState = game.state.heroes[0]
	var saved_hp: int = hero.hp
	var saved_inv: Inventory = game.state.inventory
	var map: LocalMap = await _enter_area()
	var outcome: BattleController.Outcome = _fight(map, _strong_encounter())
	assert_eq(outcome, BattleController.Outcome.DEFEAT)
	await _wait_idle()
	assert_same(game.state.heroes[0], hero, "mesmo HeroState")
	assert_eq(hero.hp, saved_hp, "HP do salvamento")
	assert_ne(game.state.inventory, saved_inv, "inventário é cópia nova")
	assert_not_null(game.game_over_screen, "tela de Game Over")
	game.game_over_screen.accept()
	assert_true(game.in_title, "Game Over volta ao título")
	assert_null(game.current)

func test_game_over_restores_changed_hp() -> void:
	var hero: HeroState = game.state.heroes[1]
	var saved_hp: int = hero.hp
	var map: LocalMap = await _enter_area()
	hero.hp = 1
	map.game_over.emit()
	await _wait_idle()
	assert_eq(hero.hp, saved_hp)
	assert_not_null(game.game_over_screen, "tela de Game Over")

var _added_maps: int = 0

func _on_child_added(node: Node) -> void:
	if node is LocalMap or node is Overworld:
		_added_maps += 1

func test_signals_ignored_while_busy() -> void:
	_added_maps = 0
	game.child_entered_tree.connect(_on_child_added)
	var world: Overworld = game.current as Overworld
	world.location_entered.emit(&"area_teste", &"Entry")
	assert_true(game.busy, "transição em andamento")
	world.location_entered.emit(&"area_teste", &"Entry")
	world.location_entered.emit(&"area_teste", &"Entry")
	await _wait_idle()
	var map: LocalMap = game.current as LocalMap
	assert_not_null(map)
	var maps: int = 0
	for child: Node in game.get_children():
		if child is LocalMap or child is Overworld:
			maps += 1
	assert_eq(maps, 1, "uma só cena de mapa")
	assert_eq(_added_maps, 1, "só uma transição para a área")
	map.exit_requested.emit()
	assert_true(game.busy)
	game.state.heroes[0].hp = 1
	map.game_over.emit()
	assert_eq(game.state.heroes[0].hp, 1, "game_over ignorado: salvamento não restaurado")
	map.exit_requested.emit()
	await _wait_idle()
	assert_true(game.current is Overworld)
	assert_eq(_player().global_position, _marker("AreaTesteReturn").global_position, "game_over ignorado")
	assert_eq(_added_maps, 2, "só uma transição de volta")
	# go_to direto durante uma transição também é ignorado.
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	assert_true(game.busy)
	game.go_to(&"overworld", &"Start")
	await _wait_idle()
	assert_true(game.current is LocalMap, "go_to durante busy ignorado")
	assert_eq(_added_maps, 3)

func test_unknown_location_is_ignored() -> void:
	(game.current as Overworld).location_entered.emit(&"inexistente", &"Entry")
	assert_push_error("desconhecido")
	assert_false(game.busy)
	assert_true(game.current is Overworld)

# --- Mapas congelados durante a transição -------------------------------------------

func _slow_fade() -> void:
	game.state.cfg.fade_time = 0.3

func _zone_center(zone: Zone) -> Vector2:
	var cs: CollisionShape2D = zone.get_node("CollisionShape2D") as CollisionShape2D
	return zone.global_position + cs.position

func test_outgoing_map_frozen_during_fade_out() -> void:
	_slow_fade()
	var world: Overworld = game.current as Overworld
	var player: Player = _player()
	var start: Vector2 = player.global_position
	watch_signals(world)
	world.location_entered.emit(&"area_teste", &"Entry")
	assert_true(game.busy)
	await get_tree().process_frame
	assert_eq(world.process_mode, Node.PROCESS_MODE_DISABLED, "mapa de saída congelado")
	# Jogador posto dentro da zona durante o fade-out: nada dispara, nada se move.
	player.override_dir = Vector2.RIGHT
	await wait_physics_frames(10)
	assert_true(game.busy, "ainda em transição")
	assert_eq(player.global_position, start, "jogador não se move no mapa que sai")
	await _wait_idle()
	assert_true(game.current is LocalMap)

func test_enemy_touch_during_fade_in_waits_for_transition() -> void:
	_slow_fade()
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	while game.current is Overworld:
		await get_tree().process_frame
	var map: LocalMap = game.current as LocalMap
	assert_true(game.busy, "fade-in em andamento")
	assert_eq(map.process_mode, Node.PROCESS_MODE_DISABLED, "mapa de entrada congelado")
	map.auto_battle = true
	map.dice_seed = 7
	var enemy: MapEnemy = map.enemies()[0]
	enemy.encounter = _weak_encounter()
	_player().global_position = enemy.global_position
	await wait_physics_frames(10)
	assert_true(game.busy)
	assert_null(map.battle, "nenhuma batalha durante a transição")
	await _wait_idle()
	assert_eq(map.process_mode, Node.PROCESS_MODE_INHERIT, "mapa liberado ao fim")
	await wait_physics_frames(5)
	assert_not_null(map.battle, "toque detectado depois da transição")

func test_zone_entered_during_fade_in_fires_after_transition() -> void:
	var map: LocalMap = await _enter_area()
	_slow_fade()
	map.exit_requested.emit()
	while game.current is LocalMap:
		await get_tree().process_frame
	var world: Overworld = game.current as Overworld
	assert_true(game.busy)
	watch_signals(world)
	_player().global_position = _zone_center(world.get_node("AreaTeste") as Zone)
	await wait_physics_frames(10)
	assert_true(game.busy)
	assert_signal_not_emitted(world, "location_entered", "zona não dispara durante o fade-in")
	await _wait_idle()
	await wait_physics_frames(5)
	assert_signal_emit_count(world, "location_entered", 1, "zona dispara depois (não se perde)")
	await _wait_idle()
	assert_true(game.current is LocalMap, "entrou na área")

func test_leaving_local_map_locks_it_immediately() -> void:
	var map: LocalMap = await _enter_area()
	_slow_fade()
	map.exit_requested.emit()
	assert_true(map.locked, "encontros e saída barrados já no mesmo quadro")
	await _wait_idle()

func test_walking_into_location_triggers_transition() -> void:
	# Caminho real: a zona dispara num callback de física (sem erros de desligar colisão).
	var world: Overworld = game.current as Overworld
	world.setup(game.state, &"AreaTesteReturn")
	_player().override_dir = Vector2.UP
	var guard: int = 0
	while game.current == world and guard < 240:
		await wait_physics_frames(1)
		guard += 1
	await _wait_idle()
	assert_true(game.current is LocalMap, "entrou andando")
	assert_eq(_player().global_position, _marker("Entry").global_position)

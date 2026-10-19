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
	(game.current as Overworld).location_entered.emit(&"area_teste")
	await _wait_idle()
	return game.current as LocalMap

func _map_enemies(map: LocalMap) -> int:
	return map.enemies().size()

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
	assert_eq(game.state.heroes.size(), 3, "três heróis de teste")
	assert_false(game.busy)

func test_starting_content_matches_m1() -> void:
	assert_eq(game.party.size(), 3)
	assert_eq(game.start_items.size(), 3)
	assert_eq(game.start_item_counts, [3, 2, 1] as Array[int])
	for i: int in game.start_items.size():
		assert_eq(game.state.inventory.available(game.start_items[i].id), game.start_item_counts[i])

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
	assert_true(game.current is Overworld)
	assert_eq(_player().global_position, _marker("Start").global_position)

func test_game_over_restores_changed_hp() -> void:
	var hero: HeroState = game.state.heroes[1]
	var saved_hp: int = hero.hp
	var map: LocalMap = await _enter_area()
	hero.hp = 1
	map.game_over.emit()
	await _wait_idle()
	assert_eq(hero.hp, saved_hp)
	assert_true(game.current is Overworld)
	assert_eq(_player().global_position, _marker("Start").global_position)

var _added_maps: int = 0

func _on_child_added(node: Node) -> void:
	if node is LocalMap or node is Overworld:
		_added_maps += 1

func test_signals_ignored_while_busy() -> void:
	_added_maps = 0
	game.child_entered_tree.connect(_on_child_added)
	var world: Overworld = game.current as Overworld
	world.location_entered.emit(&"area_teste")
	assert_true(game.busy, "transição em andamento")
	world.location_entered.emit(&"area_teste")
	world.location_entered.emit(&"area_teste")
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

func test_unknown_location_is_ignored() -> void:
	(game.current as Overworld).location_entered.emit(&"inexistente")
	assert_push_error("desconhecido")
	assert_false(game.busy)
	assert_true(game.current is Overworld)

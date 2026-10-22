extends GutTest

## Ponto de descanso: cura o roster, grava o spawn, reinicia atributos com o Cristal e libera o Salvar.
## Saves sempre num diretório temporário (nunca os slots reais).

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

var game: Game
var map: LocalMap

func before_each() -> void:
	game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.skip_title = true
	add_child_autofree(game)

func after_each() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1

func _enter_area() -> void:
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	await _wait_idle()
	map = game.current as LocalMap

## Leva o jogador para dentro do ponto de descanso.
func _step_into_rest() -> void:
	map.player.global_position = map.rest_point.global_position
	await get_tree().process_frame
	assert_true(map.rest_point.player_inside, "jogador dentro do ponto")

func _full_hp(h: HeroState) -> int:
	return StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), game.state.cfg)

func test_reset_allocation_returns_points_and_clamps() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: HeroState = HeroState.create(Fixtures.hero_def(&"a", Stats.make(1, 1, 3, 2)), cfg)
	var full: int = h.hp
	h.allocated = Stats.make(2, 1, 4, 0)
	h.pending_points = 3
	h.rest(cfg)
	assert_gt(h.hp, full, "alocação aumentou o HP máximo")
	h.reset_allocation(cfg)
	assert_eq(h.pending_points, 10)
	assert_eq(h.allocated_total(), 0)
	assert_eq(h.hp, full, "HP limitado ao novo máximo")

func test_request_outside_area_does_nothing() -> void:
	await _enter_area()
	assert_false(map.rest_point.request())
	assert_false(game.rest_menu.is_open)
	assert_eq(map.rest_spawn(), &"")

func test_rest_heals_whole_roster_and_saves_spawn() -> void:
	await _enter_area()
	game.state.heroes[0].hp = 1
	game.state.heroes[0].ap = 0
	var reserve: HeroState = game.state.reserve[0]
	reserve.hp = 1
	await _step_into_rest()
	assert_true(map.rest_point.request())
	assert_true(game.rest_menu.is_open)
	assert_false(game.can_open_menu(), "menu de campo não abre sobre o descanso")
	game.rest_menu.accept()
	assert_eq(game.state.heroes[0].hp, _full_hp(game.state.heroes[0]))
	assert_gt(game.state.heroes[0].ap, 0)
	assert_eq(reserve.hp, _full_hp(reserve), "reserva também descansa")
	assert_eq(game.state.save_map, &"area_teste")
	assert_eq(game.state.save_spawn, &"RestSpawn")
	assert_eq(game.rest_menu.stage, RestMenu.Stage.SLOTS)
	game.rest_menu.accept()
	assert_eq(game.store.summary(1)["status"], SaveStore.Status.OK)
	assert_eq(game.store.summary(1)["map"], "area_teste")
	game.rest_menu.cancel()
	assert_eq(game.rest_menu.stage, RestMenu.Stage.MAIN, "Esc nos slots volta ao menu")
	game.rest_menu.cancel()
	assert_false(game.rest_menu.is_open)
	assert_eq(map.process_mode, Node.PROCESS_MODE_INHERIT, "mapa descongelado")

func test_reset_attributes_spends_crystal() -> void:
	await _enter_area()
	var hero: HeroState = game.state.heroes[0]
	hero.allocated = Stats.make(2, 1, 0, 0)
	hero.pending_points = 0
	await _step_into_rest()
	map.rest_point.request()
	var menu: RestMenu = game.rest_menu
	assert_eq(game.state.inventory.available(GameState.RESET_ITEM_ID), 1)
	assert_true(menu.entry_enabled(RestMenu.RESET_INDEX))
	menu.move(1)
	menu.accept()
	assert_eq(menu.stage, RestMenu.Stage.PICK_HERO)
	assert_true(menu.entry_enabled(0))
	assert_false(menu.entry_enabled(1), "herói sem pontos distribuídos")
	menu.accept()
	assert_eq(hero.allocated_total(), 0)
	assert_eq(hero.pending_points, 3)
	assert_eq(game.state.inventory.available(GameState.RESET_ITEM_ID), 0, "gastou o cristal")
	assert_eq(menu.stage, RestMenu.Stage.MAIN)
	assert_false(menu.entry_enabled(RestMenu.RESET_INDEX), "sem cristal")

func test_reset_disabled_without_crystal() -> void:
	await _enter_area()
	assert_true(game.state.inventory.reserve(GameState.RESET_ITEM_ID))
	game.state.inventory.commit(GameState.RESET_ITEM_ID)
	await _step_into_rest()
	map.rest_point.request()
	game.rest_menu.move(1)
	game.rest_menu.accept()
	assert_eq(game.rest_menu.stage, RestMenu.Stage.MAIN)
	assert_ne(game.rest_menu.message(), "")

func test_save_command_enabled_only_inside_rest_point() -> void:
	await _enter_area()
	assert_false(game.can_save())
	await _step_into_rest()
	assert_true(game.can_save())
	assert_true(game.open_menu())
	assert_true(game.menu.command_enabled(FieldMenu.SAVE_INDEX))
	game.menu.close()
	map.player.global_position = map.default_arena.global_position
	assert_false(game.can_save(), "fora do ponto")

func test_continue_from_rest_save_spawns_at_rest_marker() -> void:
	await _enter_area()
	await _step_into_rest()
	assert_true(game.save_to_slot(3))
	var again: Game = (load(SCENE) as PackedScene).instantiate() as Game
	again.balance = game.balance
	again.save_dir = TMP
	again.settings_path = TMP.path_join("settings.cfg")
	add_child_autofree(again)
	assert_true(again.continue_from_slot(3))
	await get_tree().process_frame
	var local: LocalMap = again.current as LocalMap
	assert_not_null(local)
	assert_eq(local.player.global_position, (local.get_node("RestSpawn") as Marker2D).global_position)

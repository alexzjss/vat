extends GutTest

## Título, Game Over e comando Salvar. Sempre num diretório de save temporário (nunca os slots reais).

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

var game: Game

func after_each() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _make(skip: bool) -> Game:
	var g: Game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	g.balance = cfg
	g.world_seed = 7
	g.save_dir = TMP
	g.settings_path = TMP.path_join("settings.cfg")
	g.skip_title = skip
	add_child_autofree(g)
	return g

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1

func test_starts_on_title_without_flag() -> void:
	game = _make(false)
	assert_true(game.in_title)
	assert_not_null(game.title)
	assert_null(game.state)
	assert_null(game.current)
	assert_false(game.can_open_menu(), "menu não abre no título")

func test_skip_title_starts_game() -> void:
	game = _make(true)
	assert_false(game.in_title)
	assert_null(game.title)
	assert_not_null(game.state)
	assert_true(game.current is Overworld)

func test_new_game_creates_state() -> void:
	game = _make(false)
	game.title.accept()
	await _wait_idle()
	assert_false(game.in_title)
	assert_not_null(game.state)
	assert_true(game.current is Overworld)
	assert_same(game.state.settings, game.settings)
	await get_tree().process_frame
	assert_null(game.title)

func test_continue_disabled_without_saves() -> void:
	game = _make(false)
	assert_false(game.title.entry_enabled(TitleScreen.CONTINUE_INDEX))
	game.title.move(1)
	game.title.accept()
	assert_false(game.title.picking(), "Continuar desabilitado não abre a lista")

func test_continue_loads_slot() -> void:
	var first: Game = _make(true)
	first.state.heroes[0].level = 4
	first.state.play_time = 125.0
	assert_true(first.save_to_slot(2))
	first.queue_free()
	await get_tree().process_frame
	game = _make(false)
	assert_true(game.title.entry_enabled(TitleScreen.CONTINUE_INDEX))
	game.title.move(1)
	game.title.accept()
	assert_true(game.title.picking())
	var picker: SaveSlotPicker = game.title.picker
	assert_false(picker.slot_enabled(0), "slot vazio não carrega")
	assert_true(picker.slot_enabled(1))
	picker.move(1)
	game.title.accept()
	await _wait_idle()
	assert_false(game.in_title)
	assert_eq(game.state.heroes[0].level, 4)
	assert_almost_eq(game.state.play_time, 125.0, 5.0)
	assert_true(game.current is Overworld)

func test_picker_cancel_returns_to_entries() -> void:
	var first: Game = _make(true)
	assert_true(first.save_to_slot(1))
	first.queue_free()
	await get_tree().process_frame
	game = _make(false)
	game.title.move(1)
	game.title.accept()
	assert_true(game.title.picking())
	game.title.cancel()
	assert_false(game.title.picking())

func test_game_over_goes_back_to_title() -> void:
	game = _make(true)
	var map: LocalMap = await _enter_area()
	map.game_over.emit()
	assert_not_null(game.game_over_screen)
	game.game_over_screen.accept()
	assert_true(game.in_title)
	assert_null(game.game_over_screen)
	assert_null(game.current)
	assert_not_null(game.title)

func _enter_area() -> LocalMap:
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	await _wait_idle()
	return game.current as LocalMap

func test_save_enabled_on_overworld_and_disabled_in_area() -> void:
	game = _make(true)
	await _wait_idle()
	assert_true(game.can_save())
	assert_true(game.open_menu())
	assert_true(game.menu.command_enabled(FieldMenu.SAVE_INDEX))
	game.menu.close()
	var map: LocalMap = await _enter_area()
	assert_not_null(map)
	assert_false(game.can_save(), "fora do ponto de descanso")
	assert_true(game.open_menu())
	assert_false(game.menu.command_enabled(FieldMenu.SAVE_INDEX))
	game.menu.cursor = FieldMenu.SAVE_INDEX
	game.menu.accept()
	assert_eq(game.menu.page, &"root", "comando desabilitado não abre a página")
	assert_ne(game.menu.message(), "")
	assert_false(game.save_to_slot(1))
	game.menu.close()

func test_save_page_writes_slot_and_confirms_overwrite() -> void:
	game = _make(true)
	await _wait_idle()
	game.open_menu()
	game.menu.cursor = FieldMenu.SAVE_INDEX
	game.menu.accept()
	assert_eq(game.menu.page, &"save")
	var picker: SaveSlotPicker = game.menu.save_page.picker
	picker.accept()
	assert_eq(game.store.summary(1)["status"], SaveStore.Status.OK)
	assert_eq(picker.message(), "Salvo no slot 1.")
	picker.accept()
	assert_true(picker.confirming, "slot ocupado pede confirmação")
	assert_true(game.menu.save_page.cancel(), "Esc desfaz a confirmação")
	assert_false(picker.confirming)
	picker.accept()
	picker.accept()
	assert_false(picker.confirming)
	assert_eq(picker.message(), "Salvo no slot 1.")
	game.menu.close()

func test_play_time_counts_outside_title() -> void:
	game = _make(false)
	game._process(5.0)
	game.start_new_game()
	game._process(2.0)
	assert_almost_eq(game.state.play_time, 2.0, 0.001)

func test_overworld_save_restores_player_position() -> void:
	var first: Game = _make(true)
	var pos := Vector2(777.0, 555.0)
	(first.current as Overworld).player.global_position = pos
	assert_true(first.save_to_slot(1))
	assert_eq(first.state.save_pos, pos)
	first.queue_free()
	await get_tree().process_frame
	game = _make(true)
	assert_true(game.continue_from_slot(1))
	await _wait_idle()
	var world: Overworld = game.current as Overworld
	assert_not_null(world)
	assert_eq(world.player.global_position, pos)

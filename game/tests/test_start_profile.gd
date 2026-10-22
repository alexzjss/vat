extends GutTest

## Perfil de início (M12): os perfis de teste e da fatia, o Novo jogo com cada um e as demos no perfil de teste.

const SCENE: String = "res://world/game.tscn"
const FATIA_SCENE: String = "res://world/game_fatia.tscn"
const TEST_PROFILE: String = "res://data/test/start_teste.tres"
const FATIA_PROFILE: String = "res://data/fatia/start.tres"

var game: Game

func _make() -> Game:
	var g: Game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	g.balance = cfg
	g.world_seed = 7
	g.skip_title = true
	add_child_autofree(g)
	return g

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	assert_false(game.busy, "transição terminou")

func _ids(defs: Array[CharacterDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for d: CharacterDef in defs:
		out.append(d.id)
	return out

func test_test_profile_matches_old_game_scene() -> void:
	var p: StartProfile = load(TEST_PROFILE) as StartProfile
	assert_not_null(p)
	assert_eq(_ids(p.party), [&"teste_a", &"teste_b", &"teste_c", &"teste_d", &"teste_e"] as Array[StringName])
	assert_eq(p.items.size(), 4)
	assert_eq(p.item_counts, [3, 2, 1, 1] as Array[int])
	assert_eq(p.equipment.size(), 9)
	assert_eq(p.equipment_counts.size(), 9)
	assert_eq(p.money, 0)
	assert_eq(p.map, &"overworld")
	assert_eq(p.spawn, &"Start")

func test_fatia_profile_has_three_heroes_and_fifty_coins() -> void:
	var p: StartProfile = load(FATIA_PROFILE) as StartProfile
	assert_not_null(p)
	assert_eq(_ids(p.party), [&"teste_a_f", &"teste_b_f", &"teste_c_f"] as Array[StringName])
	assert_eq(p.money, 50)
	assert_eq(p.map, &"cidade", "começa na cidade")
	assert_gt(p.items.size(), 0, "algumas poções")
	assert_eq(p.items.size(), p.item_counts.size())
	assert_eq(p.items[0].id, &"pocao_f")
	assert_gt(p.item_counts[0], 0)

func test_game_scene_uses_test_profile_and_fatia_scene_the_fatia() -> void:
	game = _make()
	assert_eq(game.start_profile.resource_path, TEST_PROFILE)
	assert_eq(game.test_profile.resource_path, TEST_PROFILE)
	var f: Game = (load(FATIA_SCENE) as PackedScene).instantiate() as Game
	assert_eq(f.start_profile.resource_path, FATIA_PROFILE, "o Novo jogo do jogo real é a fatia")
	assert_eq(f.test_profile.resource_path, TEST_PROFILE)
	f.free()

func test_demo_flag_picks_test_profile() -> void:
	assert_true(Game.uses_test_profile(PackedStringArray(["--demo-m2"])))
	assert_true(Game.uses_test_profile(PackedStringArray(["--demo-field-menu"])))
	assert_false(Game.uses_test_profile(PackedStringArray()))
	assert_false(Game.uses_test_profile(PackedStringArray(["--other"])))

func test_demo_fatia_flag_keeps_the_fatia_profile_but_still_uses_demo_saves() -> void:
	var args := PackedStringArray(["--demo-fatia"])
	assert_false(Game.uses_test_profile(args), "a demo da fatia usa o perfil da fatia")
	assert_true(Game.is_demo(args), "e continua gravando em demo_saves")
	assert_true(Game.is_demo(PackedStringArray(["--demo-m2"])))
	assert_false(Game.is_demo(PackedStringArray(["--other"])))

func test_new_game_with_test_profile_ignores_start_profile() -> void:
	game = _make()
	game.start_profile = load(FATIA_PROFILE) as StartProfile
	game.use_test_profile = true
	game.start_new_game()
	await _wait_idle()
	assert_eq(game.state.heroes.size(), 4)
	assert_eq(game.state.reserve.size(), 1)
	assert_eq(game.state.money, 0)
	assert_eq(game.current_map, &"overworld")

func test_new_game_with_fatia_profile_applies_it() -> void:
	game = _make()
	# A cidade só chega na Task 4: aponta o perfil da fatia para um mapa que já existe.
	var p: StartProfile = (load(FATIA_PROFILE) as StartProfile).duplicate() as StartProfile
	p.map = &"area_teste"
	p.spawn = &"Entry"
	game.start_profile = p
	game.use_test_profile = false
	game.start_new_game()
	await _wait_idle()
	assert_eq(game.state.money, 50)
	assert_eq(game.state.heroes.size(), 3)
	assert_eq(game.state.reserve.size(), 0)
	assert_eq(game.state.inventory.available(&"pocao_f"), p.item_counts[0])
	assert_eq(game.current_map, &"area_teste")
	assert_eq(game.state.save_map, &"area_teste")
	assert_eq(game.state.save_spawn, &"Entry")
	assert_eq((game.current.get_node("Player") as Player).global_position, (game.current.get_node("Entry") as Marker2D).global_position)

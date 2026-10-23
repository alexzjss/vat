extends GutTest

## Flags de desenvolvimento do Game (M16): `--start-map`, `--spawn`, `--battle`, `--level`.

const FATIA_SCENE: String = "res://world/game_fatia.tscn"
const TMP: String = "user://test_saves/"

var game: Game

func after_each() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

## Game da fatia que abre com `args` como argumentos do usuário (os flags agem no _ready).
func _boot(args: Array[String]) -> void:
	game = (load(FATIA_SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = (load("res://data/test/balance.tres") as BalanceConfig).duplicate() as BalanceConfig
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.user_args = PackedStringArray(args)
	add_child_autofree(game)

func _player() -> Player:
	return game.current.get_node("Player") as Player

func _marker(name: String) -> Marker2D:
	return game.current.get_node(name) as Marker2D

func _assert_fell_back_to_title() -> void:
	assert_true(game.in_title, "volta ao título")
	assert_not_null(game.title)
	assert_null(game.state, "nenhum jogo começou")
	assert_null(game.current)

# --- argumentos ---

func test_parse_start_map_and_spawn() -> void:
	var d: Dictionary = Game.parse_dev_flags(PackedStringArray(["--start-map=dungeon_1", "--spawn=Escada"]))
	assert_eq(d["start_map"], &"dungeon_1")
	assert_eq(d["spawn"], &"Escada")
	assert_false(d.has("battle"))

func test_parse_battle_and_level() -> void:
	var d: Dictionary = Game.parse_dev_flags(PackedStringArray(["--battle=enc_f12", "--level=3"]))
	assert_eq(d["battle"], &"enc_f12")
	assert_eq(d["level"], "3")
	assert_false(d.has("start_map"))

func test_parse_ignores_other_flags_and_needs_a_map_or_a_battle() -> void:
	assert_true(Game.parse_dev_flags(PackedStringArray()).is_empty())
	assert_true(Game.parse_dev_flags(PackedStringArray(["--demo-fatia", "--seed=3"])).is_empty())
	assert_true(Game.parse_dev_flags(PackedStringArray(["--spawn=Entry", "--level=4"])).is_empty(), "sozinhos não fazem nada")
	assert_false(Game.parse_dev_flags(PackedStringArray(["--demo-fatia", "--battle=x"])).is_empty())

func test_dev_flags_do_not_change_the_demo_detection() -> void:
	var args := PackedStringArray(["--start-map=cidade", "--battle=enc_f1"])
	assert_false(Game.is_demo(args))
	assert_false(Game.uses_test_profile(args))
	assert_true(Game.is_demo(PackedStringArray(["--demo-fatia"])))
	assert_false(Game.uses_test_profile(PackedStringArray(["--demo-fatia"])))
	assert_true(Game.uses_test_profile(PackedStringArray(["--demo-m2"])))

func test_without_dev_flags_the_game_opens_the_title() -> void:
	_boot([])
	assert_true(game.in_title)
	assert_eq(game.save_dir, TMP, "sem flag, o diretório de saves não muda")

# --- --start-map ---

func test_start_map_goes_straight_to_the_map_entry() -> void:
	_boot(["--start-map=dungeon_1"])
	assert_false(game.in_title)
	assert_null(game.title)
	assert_eq(game.current_map, &"dungeon_1")
	assert_eq(_player().global_position, _marker("Entry").global_position)
	assert_eq(game.state.party_avg_level(), 1, "só --battle mexe no nível")
	assert_null((game.current as LocalMap).battle)
	var profile: StartProfile = load("res://data/fatia/start.tres") as StartProfile
	assert_eq(game.state.heroes[0].def.id, profile.party[0].id, "perfil da fatia")

func test_start_map_with_spawn() -> void:
	_boot(["--start-map=dungeon_1", "--spawn=Escada"])
	assert_eq(game.current_map, &"dungeon_1")
	assert_eq(_player().global_position, _marker("Escada").global_position)

func test_start_map_on_the_profile_map_uses_the_profile_spawn() -> void:
	_boot(["--start-map=cidade"])
	assert_eq(game.current_map, &"cidade")
	assert_eq(_player().global_position, _marker("Start").global_position)

func test_start_map_on_the_overworld_uses_start() -> void:
	_boot(["--start-map=overworld_fatia"])
	assert_eq(game.current_map, &"overworld_fatia")
	assert_true(game.current is Overworld)

func test_unknown_map_prints_an_error_and_falls_back_to_the_title() -> void:
	_boot(["--start-map=nao_existe"])
	assert_push_error("mapa desconhecido 'nao_existe'")
	_assert_fell_back_to_title()

func test_unknown_spawn_prints_an_error_and_falls_back_to_the_title() -> void:
	_boot(["--start-map=dungeon_1", "--spawn=Nada"])
	assert_push_error("marcador 'Nada' não existe em 'dungeon_1'")
	_assert_fell_back_to_title()

# --- --battle ---

func test_battle_starts_the_encounter_on_the_start_map_with_the_default_level() -> void:
	_boot(["--battle=enc_f12"])
	assert_eq(game.current_map, &"cidade", "o mapa inicial da fatia")
	var map: LocalMap = game.current as LocalMap
	assert_not_null(map.battle, "o encontro começou na hora")
	assert_eq(game.state.party_avg_level(), Game.DEV_BATTLE_LEVEL)
	assert_eq(Game.DEV_BATTLE_LEVEL, 5)
	for h: HeroState in game.state.roster():
		assert_eq(h.level, 5, String(h.def.id))
		assert_eq(h.hp, StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), game.state.cfg), "HP cheio")

func test_battle_applies_the_level_flag() -> void:
	_boot(["--battle=enc_f12", "--level=3"])
	assert_not_null((game.current as LocalMap).battle)
	for h: HeroState in game.state.roster():
		assert_eq(h.level, 3, String(h.def.id))
		assert_gt(h.learned.size(), 0, "técnicas do nível")

func test_battle_level_never_lowers_a_hero() -> void:
	_boot(["--start-map=cidade"])
	game.state.heroes[0].level = 9
	game.state.set_party_level(4)
	assert_eq(game.state.heroes[0].level, 9)
	assert_eq(game.state.heroes[1].level, 4)

func test_battle_on_another_map_uses_its_arena() -> void:
	_boot(["--battle=enc_f1", "--start-map=dungeon_1"])
	assert_eq(game.current_map, &"dungeon_1")
	assert_not_null((game.current as LocalMap).battle)

func test_battle_ends_back_on_the_map() -> void:
	_boot(["--battle=enc_f1"])
	var map: LocalMap = game.current as LocalMap
	assert_not_null(map.battle)
	var outcomes: Array[int] = []
	map.event_battle_finished.connect(func(o: int) -> void: outcomes.append(o))
	map._on_battle_finished(BattleController.Outcome.FLED)
	assert_null(map.battle)
	assert_eq(outcomes, [int(BattleController.Outcome.FLED)] as Array[int])
	assert_eq(game.current_map, &"cidade", "o jogo segue no mapa")
	assert_true(_player().visible)
	assert_false(game.in_title)

func test_unknown_encounter_prints_an_error_and_falls_back_to_the_title() -> void:
	_boot(["--battle=nao_existe"])
	assert_push_error("encontro desconhecido 'nao_existe'")
	_assert_fell_back_to_title()

func test_invalid_level_prints_an_error_and_falls_back_to_the_title() -> void:
	_boot(["--battle=enc_f1", "--level=abc"])
	assert_push_error("nível inválido 'abc'")
	_assert_fell_back_to_title()

func test_battle_on_the_overworld_is_refused() -> void:
	_boot(["--battle=enc_f1", "--start-map=overworld_fatia"])
	assert_push_error("não tem arena")
	_assert_fell_back_to_title()

# --- saves e demos ---

func test_dev_flags_use_the_demo_save_directory() -> void:
	_boot(["--start-map=cidade"])
	assert_eq(game.save_dir, Game.DEMO_SAVE_DIR)
	assert_eq(game.store.dir, Game.DEMO_SAVE_DIR)
	assert_ne(Game.DEMO_SAVE_DIR, "user://", "nunca os slots reais")

func test_a_failed_dev_start_also_keeps_the_demo_directory() -> void:
	_boot(["--start-map=nao_existe"])
	assert_push_error("mapa desconhecido")
	assert_eq(game.save_dir, Game.DEMO_SAVE_DIR)

func test_demo_flags_win_over_dev_flags() -> void:
	_boot(["--demo-nada", "--start-map=dungeon_1"])
	assert_true(game.use_test_profile)
	assert_eq(game.current_map, &"overworld", "a demo segue no perfil de teste")
	assert_eq(game.save_dir, Game.DEMO_SAVE_DIR)

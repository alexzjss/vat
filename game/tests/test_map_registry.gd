extends GutTest

## Registro de mapas em dados (M17): equivale ao antigo `Game.MAPS` / `Game.EXIT_SPAWNS`, acusa erros e alimenta o `Game`.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

## Lista fixa: o que o `Game.MAPS` tinha antes do registro (id -> caminho da cena).
const EXPECTED_SCENES: Dictionary = {
	&"overworld": "res://world/overworld.tscn",
	&"area_teste": "res://world/local_map.tscn",
	&"dungeon_teste": "res://world/dungeon_teste.tscn",
	&"cidade": "res://world/fatia/cidade.tscn",
	&"casa_1": "res://world/fatia/casa_1.tscn",
	&"casa_2": "res://world/fatia/casa_2.tscn",
	&"overworld_fatia": "res://world/fatia/overworld_fatia.tscn",
	&"estrada": "res://world/fatia/estrada.tscn",
	&"dungeon_1": "res://world/fatia/dungeon_1.tscn",
	&"dungeon_2": "res://world/fatia/dungeon_2.tscn",
}
## E o que o `Game.EXIT_SPAWNS` tinha.
const EXPECTED_EXITS: Dictionary = {&"area_teste": &"AreaTesteReturn", &"dungeon_teste": &"DungeonReturn"}

func _def(id: StringName, scene: PackedScene) -> MapDef:
	var d := MapDef.new()
	d.id = id
	d.scene = scene
	return d

func _registry(defs: Array[MapDef]) -> MapRegistry:
	var r := MapRegistry.new()
	r.maps = defs
	return r

func _game_with(reg: MapRegistry) -> Game:
	var game: Game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.skip_title = true
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.map_registry = reg
	return game

func after_each() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

# --- equivalência ---

func test_default_registry_matches_the_old_maps_constant() -> void:
	var reg: MapRegistry = Game.default_registry()
	var scenes: Dictionary[StringName, PackedScene] = reg.scenes()
	assert_eq(scenes.size(), EXPECTED_SCENES.size())
	for id: StringName in EXPECTED_SCENES:
		assert_true(scenes.has(id), "tem %s" % id)
		if scenes.has(id):
			assert_eq(scenes[id].resource_path, EXPECTED_SCENES[id], String(id))
			assert_eq(reg.scene_of(id), scenes[id])

func test_default_registry_matches_the_old_exit_spawns() -> void:
	assert_eq(Game.default_registry().exit_spawns(), EXPECTED_EXITS)

func test_default_registry_has_no_errors_and_ids_are_complete() -> void:
	var reg: MapRegistry = Game.default_registry()
	assert_eq(reg.errors(), [])
	var ids: Array[StringName] = reg.ids()
	assert_eq(ids.size(), EXPECTED_SCENES.size())
	for id: StringName in EXPECTED_SCENES:
		assert_true(ids.has(id))
		assert_not_null(reg.find(id))
	assert_null(reg.find(&"nao_existe"))

func test_find_returns_the_def() -> void:
	var d: MapDef = Game.default_registry().find(&"area_teste")
	assert_eq(d.id, &"area_teste")
	assert_eq(d.exit_spawn, &"AreaTesteReturn")
	assert_eq(d.kind, MapDef.Kind.TESTE)

# --- errors() ---

func test_errors_catch_duplicate_id() -> void:
	var scene := PackedScene.new()
	var reg: MapRegistry = _registry([_def(&"a", scene), _def(&"a", scene)])
	var errs: Array[String] = reg.errors()
	assert_eq(errs.size(), 1)
	assert_string_contains(errs[0], "repetido")

func test_errors_catch_null_scene() -> void:
	var reg: MapRegistry = _registry([_def(&"a", null)])
	var errs: Array[String] = reg.errors()
	assert_eq(errs.size(), 1)
	assert_string_contains(errs[0], "sem cena")

func test_errors_catch_empty_id_and_null_entry() -> void:
	var reg: MapRegistry = _registry([_def(&"", PackedScene.new()), null])
	assert_eq(reg.errors().size(), 2)

# --- Game ---

func test_game_builds_maps_from_injected_registry() -> void:
	var scene := PackedScene.new()
	var d := _def(&"so_este", scene)
	d.exit_spawn = &"Volta"
	var game: Game = _game_with(_registry([d]))
	game.skip_title = false
	add_child_autofree(game)
	assert_eq(game.maps.keys(), [&"so_este"])
	assert_eq(game.maps[&"so_este"], scene)
	assert_eq(game.exit_spawn_of(&"so_este"), &"Volta")
	assert_eq(game.exit_spawn_of(&"outro"), &"Start")

func test_game_maps_stay_extendable_before_ready() -> void:
	var game: Game = _game_with(Game.default_registry())
	var extra := PackedScene.new()
	game.maps[&"extra"] = extra
	add_child_autofree(game)
	assert_eq(game.maps[&"extra"], extra)
	assert_eq(game.maps.size(), EXPECTED_SCENES.size() + 1)

func test_game_falls_back_to_the_default_registry() -> void:
	var game: Game = _game_with(null)
	add_child_autofree(game)
	assert_not_null(game.map_registry)
	assert_eq(game.maps.size(), EXPECTED_SCENES.size())
	assert_eq(game.exit_spawn_of(&"dungeon_teste"), &"DungeonReturn")

func test_game_scenes_use_the_exported_registry() -> void:
	var game: Game = (load(SCENE) as PackedScene).instantiate() as Game
	assert_not_null(game.map_registry, "game.tscn atribui o registro")
	game.free()
	var fatia: Game = (load("res://world/game_fatia.tscn") as PackedScene).instantiate() as Game
	assert_not_null(fatia.map_registry, "game_fatia.tscn herda o registro")
	fatia.free()

# --- validador ---

func test_map_checks_report_registry_errors() -> void:
	var reg: MapRegistry = _registry([_def(&"a", null), _def(&"a", PackedScene.new())])
	var issues: Array[ValidationIssue] = MapChecks.registry([reg])
	assert_eq(issues.size(), 2)
	assert_true(issues[0].is_error())
	assert_eq(MapChecks.registry([Game.default_registry()]).size(), 0)

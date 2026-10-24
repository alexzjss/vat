extends GutTest

## Assistente de mapa novo (M17): validação do id e do tamanho, células do chão e da borda por tipo, marcadores livres, e o
## mapa montado em memória (sem o editor) que passa na varredura do TileGrid e nos validadores de conteúdo.

const Wizard: GDScript = preload("res://addons/vat_editor/logic/map_wizard.gd")
const Builder: GDScript = preload("res://addons/vat_editor/logic/map_builder.gd")
const TMP: String = "user://m17_wizard_test"

func after_each() -> void:
	_rm_dir(TMP)

func _rm_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	for d: String in DirAccess.get_directories_at(path):
		_rm_dir(path.path_join(d))
	DirAccess.remove_absolute(path)

func _params(id: String, kind: int, w: int = 60, h: int = 30) -> Dictionary:
	return {"id": id, "name": "", "kind": kind, "width": w, "height": h}

func _registry() -> MapRegistry:
	var r := MapRegistry.new()
	var d := MapDef.new()
	d.id = &"cidade"
	r.maps = [d] as Array[MapDef]
	return r

func _plan(id: String, kind: int, w: int = 60, h: int = 30) -> Dictionary:
	return Wizard.plan(_params(id, kind, w, h), _registry(), TMP.path_join("mapas"), TMP.path_join("maps"))

# --- validação ---------------------------------------------------------------------------------

func test_id_rules() -> void:
	var r: MapRegistry = _registry()
	assert_eq(Wizard.id_error("minha_vila2", r, TMP), "")
	assert_ne(Wizard.id_error("", r, TMP), "")
	for bad: String in ["Vila", "2vila", "_vila", "vi la", "vila-x", "vilã", "A"]:
		assert_ne(Wizard.id_error(bad, r, TMP), "", bad)

func test_id_already_in_registry_is_refused() -> void:
	assert_string_contains(Wizard.id_error("cidade", _registry(), TMP), "registro")

func test_id_with_existing_scene_is_refused() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var f: FileAccess = FileAccess.open(TMP.path_join("ja_existe.tscn"), FileAccess.WRITE)
	f.store_string("x")
	f.close()
	assert_string_contains(Wizard.id_error("ja_existe", _registry(), TMP), "cena")
	assert_eq(Wizard.id_error("outro", _registry(), TMP), "")

func test_size_limits() -> void:
	assert_eq(Wizard.size_error(Wizard.MIN_W, Wizard.MIN_H), "")
	assert_eq(Wizard.size_error(Wizard.MAX_W, Wizard.MAX_H), "")
	assert_ne(Wizard.size_error(Wizard.MIN_W - 1, Wizard.MIN_H), "")
	assert_ne(Wizard.size_error(Wizard.MIN_W, Wizard.MIN_H - 1), "")
	assert_ne(Wizard.size_error(Wizard.MAX_W + 1, Wizard.MAX_H), "")
	assert_ne(Wizard.size_error(Wizard.MAX_W, Wizard.MAX_H + 1), "")

func test_kind_and_base_are_validated() -> void:
	assert_ne(Wizard.kind_error(MapDef.Kind.TESTE), "")
	assert_ne(Wizard.kind_error(99), "")
	for k: int in Wizard.KINDS:
		assert_eq(Wizard.kind_error(k), "")
		assert_eq(Wizard.base_error(Wizard.default_base(k)), "")
	assert_ne(Wizard.base_error(Vector2i(3, 0)), "", "parede não é chão")

func test_plan_collects_every_error() -> void:
	var p: Dictionary = Wizard.plan({"id": "Ruim", "kind": 99, "width": 5, "height": 5}, _registry(), TMP)
	assert_false(p["ok"])
	assert_gte((p["errors"] as Array).size(), 3)

func test_names_from_id() -> void:
	assert_eq(Wizard.root_name("minha_vila"), "MinhaVila")
	assert_eq(Wizard.root_name("casa_1"), "Casa1")
	assert_eq(Wizard.default_display_name("minha_vila"), "Minha vila")
	assert_eq(_plan("minha_vila", MapDef.Kind.CIDADE)["name"], "Minha vila")
	var named: Dictionary = Wizard.plan({"id": "v", "name": " Vila Azul ", "kind": 0, "width": 50, "height": 30}, null, TMP)
	assert_eq(named["name"], "Vila Azul")

func test_paths() -> void:
	var p: Dictionary = Wizard.plan(_params("nova", MapDef.Kind.CIDADE), _registry())
	assert_eq(p["scene_path"], "res://world/mapas/nova.tscn")
	assert_eq(p["def_path"], "res://data/maps/nova.tres")
	assert_eq(p["template"], "res://addons/vat_editor/templates/maps/cidade.tscn")

# --- células -----------------------------------------------------------------------------------

func test_floor_is_full_and_border_is_closed_for_every_kind() -> void:
	for k: int in Wizard.KINDS:
		var p: Dictionary = _plan("mapa_%d" % k, k, 50, 28)
		assert_true(p["ok"], str(p["errors"]))
		var floor_cells: Dictionary = p["floor"]
		var walls: Dictionary = p["walls"]
		assert_eq(floor_cells.size(), 50 * 28, "chão cheio (%s)" % Wizard.kind_label(k))
		var ring: int = int(Wizard.kind_info(k)["ring"])
		for y: int in 28:
			for x: int in 50:
				var on_border: bool = x < ring or y < ring or x >= 50 - ring or y >= 28 - ring
				assert_eq(walls.has(Vector2i(x, y)), on_border, "borda %s em %d,%d" % [Wizard.kind_label(k), x, y])
		assert_eq(walls.size(), 50 * 28 - (50 - 2 * ring) * (28 - 2 * ring))

func test_wall_tiles_by_kind() -> void:
	assert_eq((_plan("a", MapDef.Kind.CIDADE)["walls"] as Dictionary)[Vector2i(0, 0)], Vector2i(3, 0))
	assert_eq((_plan("b", MapDef.Kind.INTERIOR)["walls"] as Dictionary)[Vector2i(0, 0)], Vector2i(6, 0))
	assert_eq((_plan("c", MapDef.Kind.MASMORRA)["walls"] as Dictionary)[Vector2i(0, 0)], Vector2i(6, 0))
	assert_eq((_plan("d", MapDef.Kind.MUNDO)["walls"] as Dictionary)[Vector2i(0, 0)], Vector2i(4, 0), "água")

func test_chosen_base_tile_fills_the_floor() -> void:
	var params: Dictionary = _params("tile_x", MapDef.Kind.CIDADE)
	params["base"] = Vector2i(1, 0)
	var p: Dictionary = Wizard.plan(params, _registry(), TMP)
	for c: Vector2i in p["floor"]:
		assert_eq((p["floor"] as Dictionary)[c], Vector2i(1, 0))

func test_spawns_are_free_cells_and_arena_is_centered() -> void:
	for k: int in Wizard.KINDS:
		for size: Vector2i in [Vector2i(Wizard.MIN_W, Wizard.MIN_H), Vector2i(75, 23), Vector2i(Wizard.MAX_W, Wizard.MAX_H)]:
			var p: Dictionary = _plan("s_%d" % k, k, size.x, size.y)
			assert_true(p["ok"], str(p["errors"]))
			for key: String in ["start_cell", "entry_cell"]:
				var c: Vector2i = p[key]
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						assert_false((p["walls"] as Dictionary).has(c + Vector2i(dx, dy)), "%s livre" % key)
			assert_eq(p["bounds"], Rect2(0, 0, size.x * 32, size.y * 32))
			assert_eq(p["has_arena"], k != MapDef.Kind.MUNDO)
			assert_eq(p["arena_pos"], Vector2(size.x * 16, size.y * 16))

func test_free_cell_near_skips_walls() -> void:
	var solid: Dictionary = {}
	for x: int in 10:
		solid[Vector2i(x, 5)] = true
	var c: Vector2i = Wizard.free_cell_near(Vector2i(5, 5), solid, 10, 10)
	assert_ne(c, Vector2i(-1, -1))
	assert_false(solid.has(c))
	assert_eq(Wizard.free_cell_near(Vector2i(0, 0), {Vector2i(0, 0): true}, 1, 1), Vector2i(-1, -1))

# --- o mapa montado em memória -------------------------------------------------------------------

func _build(plan: Dictionary) -> Node2D:
	var packed: PackedScene = Builder.build(plan)
	assert_not_null(packed)
	var root: Node2D = packed.instantiate() as Node2D
	add_child_autofree(root)
	return root

func _bundle_for(id: StringName, scene: Node, path: String) -> ContentBundle:
	var b := ContentBundle.new()
	b.maps[id] = ContentLoader.scan_map(id, path, scene)
	b.roteiro_refs.append_array(ContentLoader.roteiro_refs(id, path, scene))
	return b

func test_built_map_passes_tilegrid_bfs_and_validators_for_every_kind() -> void:
	for k: int in Wizard.KINDS:
		var p: Dictionary = _plan("novo_%d" % k, k, 60, 30)
		var root: Node2D = _build(p)
		var label: String = Wizard.kind_label(k)
		assert_eq(root.name, StringName(p["root_name"]))
		assert_eq(root.scene_file_path, "", "o mapa novo não herda do modelo")
		var grid: TileGrid = TileGrid.from_map(root)
		var start: Node2D = root.get_node(^"Start") as Node2D
		var entry: Node2D = root.get_node(^"Entry") as Node2D
		var player: Node2D = root.get_node(^"Player") as Node2D
		assert_eq(start.position, p["start"])
		assert_eq(player.position, start.position)
		assert_true(grid.area_free(start.position, 1), "%s: spawn livre" % label)
		assert_true(grid.box_free(start.position, Vector2(36, 36)))
		assert_true(grid.box_free(entry.position, Vector2(36, 36)), "%s: Entry livre" % label)
		# Borda fechada: nenhuma célula livre alcançada sai do mapa.
		var reached: Dictionary[Vector2i, bool] = grid.flood(TileGrid.cell_of(start.position), Rect2i(-3, -3, 66, 36))
		assert_true(reached.has(TileGrid.cell_of(entry.position)), "%s: Start alcança Entry" % label)
		for c: Vector2i in reached:
			assert_true(c.x >= 0 and c.y >= 0 and c.x < 60 and c.y < 30, "%s: vazou da borda em %s" % [label, c])
		assert_eq((root.get_node(^"Chão") as TileMapLayer).get_used_cells().size(), 60 * 30)
		assert_eq((root.get_node(^"Decoração") as TileMapLayer).get_used_cells().size(), 0)
		# Os limites e a câmera.
		var bounds: Rect2 = root.call(&"bounds_rect")
		assert_eq(bounds, Rect2(0, 0, 60 * 32, 30 * 32))
		var cam: Camera2D = root.get_node(^"MapCamera") as Camera2D
		assert_eq(cam.limit_right, 60 * 32)
		assert_eq(cam.limit_bottom, 30 * 32)
		# Arena, nos tipos locais: as posições de herói caem em células livres.
		if p["has_arena"]:
			assert_true(root is LocalMap)
			assert_not_null(root.get_node_or_null(^"Followers"))
			var arena: BattleArena = root.get_node(^"Arena") as BattleArena
			assert_not_null(arena)
			for hp: Vector2 in arena.hero_positions():
				assert_true(grid.area_free(hp, 0), "%s: HeroSpot %s" % [label, hp])
			assert_eq(arena.enemy_count(), 4)
		else:
			assert_true(root is Overworld)
			assert_null(root.get_node_or_null(^"Arena"))
		# Validadores de conteúdo: nenhum achado de erro.
		var issues: Array[ValidationIssue] = ContentChecks.run(_bundle_for(StringName(p["id"]), root, p["scene_path"]))
		assert_eq(ValidationIssue.errors_of(issues).size(), 0, "%s: %s" % [label, str(issues)])

func test_built_map_has_no_stale_nodes_from_the_template() -> void:
	var root: Node2D = _build(_plan("limpo", MapDef.Kind.INTERIOR))
	for child: Node in root.get_children():
		assert_false(child is ColorRect or child is StaticBody2D)

func test_default_bounds_unchanged_when_unset() -> void:
	var local: LocalMap = LocalMap.new()
	var world: Overworld = Overworld.new()
	assert_eq(local.bounds_rect(), LocalMap.MAP_RECT)
	assert_eq(world.bounds_rect(), Overworld.MAP_RECT)
	local.free()
	world.free()

func test_register_in_memory_registry() -> void:
	var reg := MapRegistry.new()
	var p: Dictionary = Wizard.plan(_params("em_memoria", MapDef.Kind.MASMORRA), reg, TMP)
	var packed: PackedScene = Builder.build(p)
	var def: MapDef = Builder.register(reg, p, packed)
	assert_eq(reg.ids(), [&"em_memoria"] as Array[StringName])
	assert_eq(def.kind, MapDef.Kind.MASMORRA)
	assert_eq(reg.scene_of(&"em_memoria"), packed)
	assert_eq(reg.errors().size(), 0)
	assert_ne(Wizard.id_error("em_memoria", reg, TMP), "", "o id registrado não serve de novo")

func test_write_saves_scene_def_and_registry_in_a_temp_dir() -> void:
	var reg := MapRegistry.new()
	var reg_path: String = TMP.path_join("registro.tres")
	var p: Dictionary = Wizard.plan(_params("gravado", MapDef.Kind.CIDADE), reg, TMP.path_join("mapas"), TMP.path_join("maps"))
	var packed: PackedScene = Builder.build(p)
	assert_eq(Builder.write(p, packed, reg, reg_path), "")
	assert_true(FileAccess.file_exists(TMP.path_join("mapas/gravado.tscn")))
	assert_true(FileAccess.file_exists(TMP.path_join("maps/gravado.tres")))
	assert_true(FileAccess.file_exists(reg_path))
	var loaded: MapRegistry = ResourceLoader.load(reg_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MapRegistry
	assert_not_null(loaded)
	assert_eq(loaded.ids(), [&"gravado"] as Array[StringName])
	var scene: PackedScene = ResourceLoader.load(TMP.path_join("mapas/gravado.tscn"), "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert_not_null(scene)
	var root: Node = scene.instantiate()
	assert_true(root is LocalMap)
	assert_eq(root.get("map_bounds"), p["bounds"])
	root.free()
	# Tirar do registro não apaga a cena.
	assert_eq(Builder.unregister(reg, &"gravado", reg_path), "")
	assert_eq(reg.ids().size(), 0)
	assert_true(FileAccess.file_exists(TMP.path_join("mapas/gravado.tscn")))
	assert_ne(Builder.unregister(reg, &"gravado", reg_path), "")

func test_write_refuses_an_existing_def_or_scene_and_leaves_it_alone() -> void:
	var reg := MapRegistry.new()
	var p: Dictionary = Wizard.plan(_params("ocupado", MapDef.Kind.CIDADE), reg, TMP.path_join("mapas"), TMP.path_join("maps"))
	DirAccess.make_dir_recursive_absolute(TMP.path_join("maps"))
	var f: FileAccess = FileAccess.open(TMP.path_join("maps/ocupado.tres"), FileAccess.WRITE)
	f.store_string("meu")
	f.close()
	assert_ne(Builder.write(p, Builder.build(p), reg, TMP.path_join("registro.tres")), "")
	assert_false(FileAccess.file_exists(TMP.path_join("mapas/ocupado.tscn")), "a cena nem chega a ser gravada")
	assert_eq(FileAccess.get_file_as_string(TMP.path_join("maps/ocupado.tres")), "meu")
	assert_eq(reg.maps.size(), 0)

func test_write_deletes_the_saved_scene_when_the_registry_cannot_be_saved() -> void:
	var reg := MapRegistry.new()
	var p: Dictionary = Wizard.plan(_params("falha", MapDef.Kind.CIDADE), reg, TMP.path_join("mapas"), TMP.path_join("maps"))
	# Um arquivo no lugar da pasta do registro: o ResourceSaver não consegue gravar lá dentro.
	DirAccess.make_dir_recursive_absolute(TMP)
	var blocker: FileAccess = FileAccess.open(TMP.path_join("bloqueio"), FileAccess.WRITE)
	blocker.store_string("x")
	blocker.close()
	var err: String = Builder.write(p, Builder.build(p), reg, TMP.path_join("bloqueio/registro.tres"))
	assert_ne(err, "")
	assert_engine_error_count(1, "o ResourceSaver registra a falha de gravar o registro")
	assert_false(FileAccess.file_exists(TMP.path_join("mapas/falha.tscn")), "a cena gravada é apagada")
	assert_false(FileAccess.file_exists(TMP.path_join("maps/falha.tres")), "e o MapDef também")
	assert_eq(reg.maps.size(), 0)

func test_real_registry_and_data_are_untouched_by_the_tests() -> void:
	assert_false(Game.default_registry().has(&"gravado"))
	assert_false(FileAccess.file_exists("res://world/mapas/gravado.tscn"))

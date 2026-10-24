extends GutTest

## Lógica pura da paleta de objetos (M17): a lista de prefabs por tipo de mapa, a grade, nomes e flags únicos e a posição
## onde o prefab entra (com e sem vista 2D). Também confere que os 16 prefabs existem e que o mapa da fatia é reconhecido.

const Palette: GDScript = preload("res://addons/vat_editor/logic/palette.gd")

func _ids(list: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in list:
		out.append(p["id"])
	return out

func _empty_names() -> Array[String]:
	return []

# --- prefabs por tipo de mapa ---

func test_overworld_offers_only_the_relevant_prefabs() -> void:
	var ids: Array[StringName] = _ids(Palette.prefabs_for(Palette.KIND_OVERWORLD))
	assert_eq(ids.size(), 4)
	for want: StringName in [&"zona", &"marcador_spawn", &"placa", &"gatilho_evento"]:
		assert_true(ids.has(want), "mundo tem %s" % want)

func test_local_map_offers_everything_but_zone() -> void:
	var ids: Array[StringName] = _ids(Palette.prefabs_for(Palette.KIND_LOCAL))
	assert_eq(ids.size(), 15)
	assert_false(ids.has(&"zona"))
	assert_true(ids.has(&"bau"))
	assert_true(ids.has(&"ligacao"))

func test_other_scenes_have_no_palette() -> void:
	assert_eq(Palette.prefabs_for(Palette.KIND_NONE).size(), 0)

func test_every_prefab_file_exists_and_has_a_name() -> void:
	assert_eq(Palette.PREFABS.size(), 16)
	for p: Dictionary in Palette.PREFABS:
		assert_true(ResourceLoader.exists(Palette.prefab_path(p["id"])), String(p["id"]))
		assert_ne(String(p["name"]), "")
		assert_false((p["icons"] as Array).is_empty())

func test_kind_of_chain() -> void:
	assert_eq(Palette.kind_of_chain(["LocalMap"] as Array[String]), Palette.KIND_LOCAL)
	assert_eq(Palette.kind_of_chain(["Overworld"] as Array[String]), Palette.KIND_OVERWORLD)
	assert_eq(Palette.kind_of_chain(["Node2D"] as Array[String]), Palette.KIND_NONE)

func test_kind_of_real_map_roots() -> void:
	var dungeon: Node = (load("res://world/fatia/dungeon_1.tscn") as PackedScene).instantiate()
	var world: Node = (load("res://world/overworld.tscn") as PackedScene).instantiate()
	assert_eq(Palette.kind_of_node(dungeon), Palette.KIND_LOCAL)
	assert_eq(Palette.kind_of_node(world), Palette.KIND_OVERWORLD)
	var plain := Node2D.new()
	assert_eq(Palette.kind_of_node(plain), Palette.KIND_NONE)
	plain.free()
	assert_eq(Palette.kind_of_node(null), Palette.KIND_NONE)
	dungeon.free()
	world.free()

# --- grade ---

func test_snap_rounds_to_the_nearest_grid_point() -> void:
	assert_eq(Palette.snap(Vector2(10, 20)), Vector2(0, 32))
	assert_eq(Palette.snap(Vector2(15.9, 16)), Vector2(0, 32))
	assert_eq(Palette.snap(Vector2(-17, -49)), Vector2(-32, -64))
	assert_eq(Palette.snap(Vector2(64, 96)), Vector2(64, 96))

func test_snap_custom_grid() -> void:
	assert_eq(Palette.snap(Vector2(7, 9), 8), Vector2(8, 8))

# --- posição ---

func test_placement_prefers_the_last_click() -> void:
	assert_eq(Palette.placement(Vector2(70, 10), Vector2(500, 500)), Vector2(64, 0))

func test_placement_falls_back_to_the_view_center() -> void:
	assert_eq(Palette.placement(null, Vector2(500, 300)), Vector2(512, 288))

func test_placement_without_viewport_uses_the_fallback_on_the_grid() -> void:
	assert_eq(Palette.placement(null, null), Vector2.ZERO)
	assert_eq(Palette.placement(null, null, Vector2(100, 40)), Vector2(96, 32))

func test_placement_ignores_non_finite_points() -> void:
	assert_eq(Palette.placement(Vector2.INF, Vector2(33, 33)), Vector2(32, 32))

# --- nomes únicos ---

func test_unique_name_keeps_a_free_name() -> void:
	assert_eq(Palette.unique_name("Bau", _empty_names()), "Bau")
	assert_eq(Palette.unique_name("Bau", ["Npc"] as Array[String]), "Bau")

func test_unique_name_numbers_from_two() -> void:
	assert_eq(Palette.unique_name("Bau", ["Bau"] as Array[String]), "Bau2")
	assert_eq(Palette.unique_name("Bau", ["Bau", "Bau2"] as Array[String]), "Bau3")

func test_unique_name_fills_gaps_and_ignores_a_numeric_suffix() -> void:
	assert_eq(Palette.unique_name("Bau", ["Bau", "Bau3"] as Array[String]), "Bau2")
	assert_eq(Palette.unique_name("Bau7", ["Bau"] as Array[String]), "Bau2")

func test_collect_names_walks_the_whole_tree() -> void:
	var root := Node2D.new()
	root.name = &"Mapa"
	var a := Node2D.new()
	a.name = &"A"
	root.add_child(a)
	var b := Node2D.new()
	b.name = &"B"
	a.add_child(b)
	var names: Array[String] = Palette.collect_names(root)
	assert_eq(names.size(), 3)
	assert_true(names.has("B"))
	root.free()

# --- flags únicas ---

func test_next_flag_starts_at_one_and_skips_taken() -> void:
	assert_eq(Palette.next_flag("bau", "dungeon_1", _empty_names()), "bau_dungeon_1_1")
	assert_eq(Palette.next_flag("bau", "dungeon_1", ["bau_dungeon_1_1", "bau_dungeon_1_2"] as Array[String]), "bau_dungeon_1_3")

func test_placeholders_are_recognised() -> void:
	for f: StringName in [&"bau_novo", &"porta_nova", &"portao_novo", &"obstaculo_novo"]:
		assert_true(Palette.is_placeholder(f), String(f))
	assert_false(Palette.is_placeholder(&"bau_pocao"))
	assert_false(Palette.is_placeholder(&""))

func test_flag_changes_replace_the_placeholders() -> void:
	var ch: Dictionary = Palette.flag_changes({&"opened_flag": &"bau_novo"}, "dungeon_1", _empty_names())
	assert_eq(ch, {&"opened_flag": &"bau_dungeon_1_1"})
	ch = Palette.flag_changes({&"open_flag": &"porta_nova"}, "casa_1", ["porta_casa_1_1"] as Array[String])
	assert_eq(ch, {&"open_flag": &"porta_casa_1_2"})
	ch = Palette.flag_changes({&"flag": &"obstaculo_novo"}, "estrada", _empty_names())
	assert_eq(ch, {&"flag": &"obstaculo_estrada_1"})
	ch = Palette.flag_changes({&"flag": &"portao_novo"}, "estrada", _empty_names())
	assert_eq(ch, {&"flag": &"portao_estrada_1"})

func test_flag_changes_leave_real_flags_alone() -> void:
	assert_eq(Palette.flag_changes({&"opened_flag": &"bau_pocao"}, "dungeon_1", _empty_names()), {})
	assert_eq(Palette.flag_changes({&"flag": &"portao_aberto"}, "dungeon_1", ["portao_aberto"] as Array[String]), {})

func test_flag_changes_fix_a_duplicated_chest_flag() -> void:
	var ch: Dictionary = Palette.flag_changes({&"opened_flag": &"bau_x"}, "m", ["bau_x"] as Array[String])
	assert_eq(ch, {&"opened_flag": &"bau_m_1"})

func test_flag_changes_never_repeat_inside_one_node() -> void:
	var ch: Dictionary = Palette.flag_changes({&"opened_flag": &"bau_novo", &"flag": &"bau_novo"}, "m", _empty_names())
	assert_ne(ch[&"opened_flag"], ch[&"flag"])

func test_map_id_uses_the_registry_then_the_root_name() -> void:
	var reg: MapRegistry = Game.default_registry()
	assert_eq(Palette.map_id_for("res://world/fatia/dungeon_1.tscn", reg, "Dungeon1"), "dungeon_1")
	assert_eq(Palette.map_id_for("res://world/mapas/x.tscn", reg, "MapaNovo"), "mapa_novo")
	assert_eq(Palette.map_id_for("", null, ""), "mapa")

# --- flags lidas dos nós ---

func _chest(flag: StringName) -> Node:
	var c: Node = (load(Palette.prefab_path(&"bau")) as PackedScene).instantiate()
	c.set(&"opened_flag", flag)
	return c

func test_flag_props_of_reads_the_chest_flag() -> void:
	var c: Node = _chest(&"bau_novo")
	assert_eq(Palette.flag_props_of(c), {&"opened_flag": &"bau_novo"})
	c.free()

func test_collect_flags_skips_the_excluded_nodes() -> void:
	var root := Node2D.new()
	var a: Node = _chest(&"bau_a")
	var b: Node = _chest(&"bau_b")
	root.add_child(a)
	root.add_child(b)
	var all: Array[String] = Palette.collect_flags(root)
	assert_true(all.has("bau_a") and all.has("bau_b"))
	var some: Array[String] = Palette.collect_flags(root, [a] as Array[Node])
	assert_eq(some, ["bau_b"] as Array[String])
	root.free()

func test_a_new_chest_gets_a_flag_not_used_by_the_scene() -> void:
	var root := Node2D.new()
	root.add_child(_chest(&"bau_dungeon_1_1"))
	var fresh: Node = _chest(&"bau_novo")
	var ch: Dictionary = Palette.flag_changes(Palette.flag_props_of(fresh), "dungeon_1", Palette.collect_flags(root))
	assert_eq(ch[&"opened_flag"], &"bau_dungeon_1_2")
	fresh.free()
	root.free()

# --- interruptor e portão com a mesma flag (M17) ---

## Coloca o prefab `id` em `root` como a paleta faz (flags do `flags_for_new`).
func _place(root: Node, id: StringName) -> Node:
	var node: Node = (load(Palette.prefab_path(id)) as PackedScene).instantiate()
	var changes: Dictionary = Palette.flags_for_new(root, node, id, "m")
	for k: Variant in changes:
		node.set(k, changes[k])
	root.add_child(node)
	return node

func test_switch_placed_after_a_gate_reuses_its_flag() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var gate: Node = _place(root, &"portao_flag")
	var sw: Node = _place(root, &"interruptor")
	assert_eq(gate.get(&"flag"), &"portao_m_1")
	assert_eq(sw.get(&"flag"), gate.get(&"flag"))

func test_gate_placed_after_a_switch_reuses_its_flag() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var sw: Node = _place(root, &"interruptor")
	var gate: Node = _place(root, &"portao_flag")
	assert_eq(gate.get(&"flag"), sw.get(&"flag"))

func test_a_second_pair_gets_a_new_shared_flag() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var g1: Node = _place(root, &"portao_flag")
	var s1: Node = _place(root, &"interruptor")
	var g2: Node = _place(root, &"portao_flag")
	assert_ne(g2.get(&"flag"), g1.get(&"flag"), "o primeiro portão já tem par")
	var s2: Node = _place(root, &"interruptor")
	assert_eq(s2.get(&"flag"), g2.get(&"flag"))
	assert_eq(s1.get(&"flag"), g1.get(&"flag"))
	assert_eq(g2.get(&"flag"), &"portao_m_2")

func test_two_switches_in_a_row_do_not_share_a_gate_flag_twice() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var s1: Node = _place(root, &"interruptor")
	var s2: Node = _place(root, &"interruptor")
	assert_ne(s1.get(&"flag"), s2.get(&"flag"))

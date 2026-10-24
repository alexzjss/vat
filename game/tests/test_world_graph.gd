extends GutTest

## Grafo do mundo (M17): nós e arestas lidos das cenas do registro sem instanciar, ligações quebradas, mapas inalcançáveis,
## layout automático determinístico e a gravação das posições.

const WorldGraph: GDScript = preload("res://addons/vat_editor/logic/world_graph.gd")
const Picks: GDScript = preload("res://addons/vat_editor/logic/inspector_picks.gd")
const Wizard: GDScript = preload("res://addons/vat_editor/logic/map_wizard.gd")
const Builder: GDScript = preload("res://addons/vat_editor/logic/map_builder.gd")
const TMP_CFG: String = "user://m17_world_layout_test.cfg"

## As arestas do jogo hoje, "origem>destino@ponto:nó", derivadas das cenas (fatia e mapas de teste).
const EXPECTED_EDGES: Array[String] = [
	"casa_1>cidade@Casa1Saida:Saida",
	"casa_2>cidade@Casa2Saida:Saida",
	"cidade>casa_1@Entry:Casa1Porta",
	"cidade>casa_2@Entry:Casa2Porta",
	"cidade>overworld_fatia@CidadeReturn:SaidaLink",
	"dungeon_1>dungeon_2@Entry:EscadaLink",
	"dungeon_1>overworld_fatia@DungeonReturn:SaidaLink",
	"dungeon_2>dungeon_1@Escada:VoltaLink",
	"estrada>overworld_fatia@EstradaLeste:LinkLeste",
	"estrada>overworld_fatia@EstradaOeste:LinkOeste",
	"overworld_fatia>cidade@Entry:Cidade",
	"overworld_fatia>dungeon_1@Entry:Dungeon",
	"overworld_fatia>estrada@Entry:Estrada",
	"overworld_fatia>estrada@EntryLeste:EstradaVolta",
	"area_teste>overworld@AreaTesteReturn:Exit",
	"dungeon_teste>overworld@DungeonReturn:Exit",
	"overworld>area_teste@Entry:AreaTeste",
	"overworld>dungeon_teste@Entry:Dungeon",
]

func after_each() -> void:
	if FileAccess.file_exists(TMP_CFG):
		DirAccess.remove_absolute(TMP_CFG)

func _keys(graph: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in graph["edges"]:
		out.append("%s>%s@%s:%s" % [e["from"], e["to"], e["spawn"], e["source"]])
	out.sort()
	return out

func _sorted(list: Array[String]) -> Array[String]:
	var out: Array[String] = list.duplicate()
	out.sort()
	return out

func _node(graph: Dictionary, id: String) -> Dictionary:
	for n: Dictionary in graph["nodes"]:
		if n["id"] == id:
			return n
	return {}

# --- cenas em memória ---

func _local(links: Array, markers: Array[String] = ["Entry"]) -> PackedScene:
	var root := LocalMap.new()
	root.name = "Mapa"
	for m: String in markers:
		var mk := Marker2D.new()
		mk.name = m
		root.add_child(mk)
		mk.owner = root
	for l: Array in links:
		var a := MapLink.new()
		a.name = l[0]
		a.target_map = StringName(l[1])
		a.target_spawn = StringName(l[2])
		root.add_child(a)
		a.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed

func _def(id: String, scene: PackedScene, kind: int = MapDef.Kind.CIDADE) -> MapDef:
	var d := MapDef.new()
	d.id = StringName(id)
	d.scene = scene
	d.kind = kind as MapDef.Kind
	return d

func _registry(defs: Array[MapDef]) -> MapRegistry:
	var r := MapRegistry.new()
	r.maps = defs
	return r

# --- o registro real ---

func test_real_registry_has_the_slice_and_test_edges() -> void:
	var graph: Dictionary = WorldGraph.build(Game.default_registry())
	assert_eq(_keys(graph), _sorted(EXPECTED_EDGES))

func test_real_registry_has_a_node_per_map_with_spawns_and_counts() -> void:
	var graph: Dictionary = WorldGraph.build(Game.default_registry())
	assert_eq((graph["nodes"] as Array).size(), Game.default_registry().ids().size())
	var cidade: Dictionary = _node(graph, "cidade")
	assert_eq(cidade["kind"], MapDef.Kind.CIDADE)
	assert_eq(cidade["scene"], "res://world/fatia/cidade.tscn")
	assert_true((cidade["spawns"] as Array).has("Casa1Saida"))
	assert_eq((cidade["counts"] as Dictionary)["links"], 3)
	assert_eq((_node(graph, "overworld_fatia")["counts"] as Dictionary)["zones"], 4)
	assert_true(bool((_node(graph, "area_teste")["counts"] as Dictionary)["exit"]))
	assert_false(bool((cidade["counts"] as Dictionary)["exit"]))

func test_real_registry_has_no_broken_edges() -> void:
	var graph: Dictionary = WorldGraph.build(Game.default_registry())
	for e: Dictionary in WorldGraph.broken_edges(graph):
		fail_test("aresta quebrada: %s" % [e])
	assert_eq(WorldGraph.broken_edges(graph).size(), 0)

func test_real_registry_has_no_unreachable_maps() -> void:
	var graph: Dictionary = WorldGraph.build(Game.default_registry())
	assert_eq(graph["start"], &"cidade")
	assert_eq(graph["unreachable"], [] as Array[String])
	assert_eq(_sorted(graph["test_ids"]), _sorted(["area_teste", "dungeon_teste", "overworld"] as Array[String]))

func test_exit_edge_uses_exit_spawn_or_start() -> void:
	var local: PackedScene = load("res://world/local_map.tscn")
	var ow: PackedScene = load("res://world/overworld.tscn")
	var b: MapDef = _def("b", local)
	b.exit_spawn = &"AreaTesteReturn"
	var graph: Dictionary = WorldGraph.build(_registry([_def("overworld", ow, MapDef.Kind.MUNDO), _def("a", local), b] as Array[MapDef]), &"overworld")
	var exits: Array[Dictionary] = []
	for e: Dictionary in graph["edges"]:
		if e["kind"] == WorldGraph.EDGE_EXIT:
			exits.append(e)
	assert_eq(exits.size(), 2)
	assert_eq(exits[0]["spawn"], "Start")
	assert_eq(exits[1]["spawn"], "AreaTesteReturn")
	assert_eq(exits[1]["to"], "overworld")

# --- ligações quebradas ---

func test_broken_target_is_flagged() -> void:
	var reg: MapRegistry = _registry([_def("a", _local([["L", "sumiu", "Entry"]])), _def("b", _local([]))] as Array[MapDef])
	var broken: Array[Dictionary] = WorldGraph.broken_edges(WorldGraph.build(reg, &"a"))
	assert_eq(broken.size(), 1)
	assert_eq(broken[0]["to"], "sumiu")
	assert_string_contains(broken[0]["message"], "não está no registro")

func test_empty_target_is_flagged() -> void:
	var graph: Dictionary = WorldGraph.build(_registry([_def("a", _local([["L", "", "Entry"]]))] as Array[MapDef]), &"a")
	var broken: Array[Dictionary] = WorldGraph.broken_edges(graph)
	assert_eq(broken.size(), 1)
	assert_eq(broken[0]["message"], "sem destino")

func test_broken_spawn_is_flagged() -> void:
	var reg: MapRegistry = _registry([_def("a", _local([["L", "b", "Nao"]])), _def("b", _local([]))] as Array[MapDef])
	var broken: Array[Dictionary] = WorldGraph.broken_edges(WorldGraph.build(reg, &"a"))
	assert_eq(broken.size(), 1)
	assert_string_contains(broken[0]["message"], "Nao")
	var ok: MapRegistry = _registry([_def("a", _local([["L", "b", "Entry"]])), _def("b", _local([]))] as Array[MapDef])
	assert_eq(WorldGraph.broken_edges(WorldGraph.build(ok, &"a")).size(), 0)

func test_map_without_scene_is_a_node_without_edges() -> void:
	var graph: Dictionary = WorldGraph.build(_registry([_def("a", null)] as Array[MapDef]), &"a")
	assert_eq((graph["nodes"] as Array).size(), 1)
	assert_eq((graph["edges"] as Array).size(), 0)

# --- inalcançáveis ---

func test_unreachable_excludes_start_tests_and_self_links() -> void:
	var reg: MapRegistry = _registry([
		_def("a", _local([["L", "b", "Entry"], ["Self", "a", "Entry"]])),
		_def("b", _local([])),
		_def("solto", _local([["L", "b", "Entry"]])),
		_def("auto", _local([["Self", "auto", "Entry"]])),
		_def("t", _local([]), MapDef.Kind.TESTE),
	] as Array[MapDef])
	var graph: Dictionary = WorldGraph.build(reg, &"a")
	assert_eq(graph["unreachable"], ["solto", "auto"] as Array[String])
	assert_eq(graph["test_ids"], ["t"] as Array[String])

func test_without_tests_drops_test_nodes_and_their_edges() -> void:
	var graph: Dictionary = WorldGraph.without_tests(WorldGraph.build(Game.default_registry()))
	assert_eq((graph["nodes"] as Array).size(), 7)
	assert_eq(_keys(graph).size(), 14)
	for e: Dictionary in graph["edges"]:
		assert_ne(e["to"], "overworld")

# --- layout ---

func test_layout_columns_follow_distance_from_start() -> void:
	var graph: Dictionary = WorldGraph.build(Game.default_registry())
	var pos: Dictionary = WorldGraph.auto_layout(graph)
	assert_eq((pos["cidade"] as Vector2).x, 0.0)
	assert_eq((pos["casa_1"] as Vector2).x, WorldGraph.COLUMN_STEP)
	assert_eq((pos["overworld_fatia"] as Vector2).x, WorldGraph.COLUMN_STEP)
	assert_eq((pos["estrada"] as Vector2).x, WorldGraph.COLUMN_STEP * 2.0)
	assert_eq((pos["dungeon_2"] as Vector2).x, WorldGraph.COLUMN_STEP * 3.0)
	# Os mapas fora do alcance do inicial ficam à direita, sem sobrepor ninguém.
	var seen: Dictionary = {}
	for id: Variant in pos.keys():
		assert_false(seen.has(pos[id]), "posição repetida: %s" % id)
		seen[pos[id]] = true
	assert_gt((pos["overworld"] as Vector2).x, (pos["dungeon_2"] as Vector2).x)

func test_layout_is_deterministic() -> void:
	var a: Dictionary = WorldGraph.auto_layout(WorldGraph.build(Game.default_registry()))
	var b: Dictionary = WorldGraph.auto_layout(WorldGraph.build(Game.default_registry()))
	assert_eq(a, b)
	assert_eq(a.keys(), b.keys())

func test_layout_handles_empty_registry() -> void:
	assert_eq(WorldGraph.auto_layout(WorldGraph.build(MapRegistry.new(), &"x")), {})

func test_merged_layout_prefers_saved_positions() -> void:
	var graph: Dictionary = WorldGraph.build(Game.default_registry())
	var merged: Dictionary = WorldGraph.merged_layout(graph, {"cidade": Vector2(5, 7), "sumiu": Vector2(1, 1)})
	assert_eq(merged["cidade"], Vector2(5, 7))
	assert_false(merged.has("sumiu"))
	assert_eq(merged["casa_1"], WorldGraph.auto_layout(graph)["casa_1"])

func test_layout_save_load_round_trip() -> void:
	var pos: Dictionary = {"cidade": Vector2(10.5, 20), "casa_1": Vector2(-30, 40)}
	assert_eq(WorldGraph.save_layout(TMP_CFG, pos), OK)
	assert_eq(WorldGraph.load_layout(TMP_CFG), pos)
	# Gravar outro mapa não apaga os que já estavam.
	assert_eq(WorldGraph.save_layout(TMP_CFG, {"casa_2": Vector2(1, 2)}), OK)
	var back: Dictionary = WorldGraph.load_layout(TMP_CFG)
	assert_eq(back.size(), 3)
	assert_eq(back["cidade"], Vector2(10.5, 20))

func test_load_layout_of_missing_file_is_empty() -> void:
	assert_eq(WorldGraph.load_layout("user://nao_existe_m17.cfg"), {})

# --- prefabs instanciados (M17) ---

## Um mapa do assistente com prefabs instanciados: uma `Ligacao` (para a cidade, ponto `Entry`) e um `Spawn` chamado `Volta`,
## este dentro de um nó intermediário (a árvore inteira conta, como no validador).
func _wizard_map_with_prefabs() -> PackedScene:
	var params: Dictionary = {"id": "vila_nova", "name": "", "kind": MapDef.Kind.CIDADE, "width": 40, "height": 30}
	var plan: Dictionary = Wizard.plan(params, MapRegistry.new(), "user://m17_gx/mapas", "user://m17_gx/maps")
	var base: PackedScene = Builder.build(plan)
	var root: Node = base.instantiate()
	var link: MapLink = (load("res://world/prefabs/ligacao.tscn") as PackedScene).instantiate() as MapLink
	link.name = "PortaCidade"
	link.target_map = &"cidade"
	link.target_spawn = &"Entry"
	root.add_child(link)
	link.owner = root
	var group := Node2D.new()
	group.name = "Grupo"
	root.add_child(group)
	group.owner = root
	var marker: Node = (load("res://world/prefabs/marcador_spawn.tscn") as PackedScene).instantiate()
	marker.name = "Volta"
	group.add_child(marker)
	marker.owner = root
	var packed := PackedScene.new()
	assert_eq(packed.pack(root), OK)
	root.free()
	return packed

func test_scan_scene_finds_instanced_link_prefab() -> void:
	var scan: Dictionary = WorldGraph.scan_scene(_wizard_map_with_prefabs())
	assert_eq(scan["root"], "local")
	var links: Array = scan["links"]
	assert_eq(links.size(), 1)
	assert_eq((links[0] as Dictionary)["node"], "PortaCidade")
	assert_eq((links[0] as Dictionary)["target"], "cidade")
	assert_eq((links[0] as Dictionary)["spawn"], "Entry")

func test_spawns_of_lists_instanced_marker_prefab() -> void:
	var spawns: Array[String] = Picks.spawns_of(_wizard_map_with_prefabs())
	assert_true(spawns.has("Start"))
	assert_true(spawns.has("Entry"))
	assert_true(spawns.has("Grupo/Volta"))

func test_graph_shows_edge_of_instanced_prefab_and_it_is_not_broken() -> void:
	var reg: MapRegistry = _registry([_def("cidade", _local([])), _def("vila_nova", _wizard_map_with_prefabs())] as Array[MapDef])
	var graph: Dictionary = WorldGraph.build(reg, &"cidade")
	assert_eq(_keys(graph), ["vila_nova>cidade@Entry:PortaCidade"] as Array[String])
	assert_eq(WorldGraph.broken_edges(graph).size(), 0)
	assert_eq((_node(graph, "vila_nova")["counts"] as Dictionary)["links"], 1)

func test_instanced_link_with_missing_target_is_flagged() -> void:
	var reg: MapRegistry = _registry([_def("vila_nova", _wizard_map_with_prefabs())] as Array[MapDef])
	assert_eq(WorldGraph.broken_edges(WorldGraph.build(reg, &"vila_nova")).size(), 1)

func test_inherited_scene_sees_parent_prefab_and_child_override() -> void:
	var scene: PackedScene = _wizard_map_with_prefabs()
	var child: Node = scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)
	(child.get_node(^"PortaCidade") as MapLink).target_spawn = &"Volta"
	var inherited := PackedScene.new()
	assert_eq(inherited.pack(child), OK)
	child.free()
	var scan: Dictionary = WorldGraph.scan_scene(inherited)
	assert_eq((scan["links"] as Array).size(), 1)
	assert_eq(((scan["links"] as Array)[0] as Dictionary)["spawn"], "Volta")

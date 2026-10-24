extends GutTest

## Prefabs de objetos de jogo (M17): cada um instancia, reusa o script de hoje, tem colisão e os campos esperados e, solto
## num mapa modelo, passa nos validadores de conteúdo (as ligações precisam de destino, que o usuário escolhe).

const Wizard: GDScript = preload("res://addons/vat_editor/logic/map_wizard.gd")
const Builder: GDScript = preload("res://addons/vat_editor/logic/map_builder.gd")
const DIR: String = "res://world/prefabs/"

## arquivo -> {script: caminho do script, shape: tem CollisionShape2D filho?, props: campos exportados que devem existir}
const PREFABS: Dictionary = {
	"npc.tscn": {"script": "res://world/npc.gd", "shape": true, "props": ["display_name", "roteiro", "event_id", "speaker"]},
	"placa.tscn": {"script": "res://world/sign.gd", "shape": true, "props": ["text", "roteiro", "event_id"]},
	"ligacao.tscn": {"script": "res://world/map_link.gd", "shape": true, "props": ["target_map", "target_spawn", "label_text"]},
	"bau.tscn": {"script": "res://world/chest.gd", "shape": true, "props": ["item", "equipment", "count", "opened_flag"]},
	"ponto_descanso.tscn": {"script": "res://world/rest_point.gd", "shape": true, "props": ["spawn_name", "label_text"]},
	"loja.tscn": {"script": "res://world/shop_keeper.gd", "shape": true, "props": ["shop", "greeting", "display_name"]},
	"pousada.tscn": {"script": "res://world/inn.gd", "shape": true, "props": ["spawn_name"]},
	"inimigo_mapa.tscn": {"script": "res://world/map_enemy.gd", "shape": true, "props": ["encounter", "region", "arena_path", "behavior"]},
	"obstaculo_elemental.tscn": {"script": "res://world/elemental_obstacle.gd", "shape": true, "props": ["element", "flag", "size"]},
	"portao_flag.tscn": {"script": "res://world/flag_gate.gd", "shape": false, "props": ["flag", "open_value", "size"]},
	"interruptor.tscn": {"script": "res://world/switch.gd", "shape": true, "props": ["flag", "on_text", "off_text"]},
	"gatilho_evento.tscn": {"script": "res://world/event_trigger.gd", "shape": true, "props": ["roteiro", "event_id", "once_flag", "size"]},
	"marcador_spawn.tscn": {"script": "", "shape": false, "props": []},
	"zona.tscn": {"script": "res://world/zone.gd", "shape": true, "props": ["zone_id", "label_text", "spawn"]},
	"armadilha.tscn": {"script": "res://world/trap.gd", "shape": true, "props": ["encounter", "once_flag", "size"]},
	"porta_chave.tscn": {"script": "res://world/door.gd", "shape": true, "props": ["key_item", "open_flag", "size"]},
}

func _inst(file: String) -> Node:
	var packed: PackedScene = load(DIR + file) as PackedScene
	assert_not_null(packed, file)
	return packed.instantiate()

func test_every_prefab_file_is_covered_by_this_test() -> void:
	var on_disk: Array[String] = []
	for f: String in DirAccess.get_files_at(DIR):
		if f.get_extension() == "tscn":
			on_disk.append(f)
	on_disk.sort()
	var expected: Array[String] = []
	for k: Variant in PREFABS.keys():
		expected.append(str(k))
	expected.sort()
	assert_eq(on_disk, expected)

func test_each_prefab_instantiates_with_script_collision_and_fields() -> void:
	for file: String in PREFABS:
		var spec: Dictionary = PREFABS[file]
		var node: Node = _inst(file)
		assert_not_null(node, file)
		if spec["script"] != "":
			assert_not_null(node.get_script(), "%s: script" % file)
			assert_eq((node.get_script() as Script).resource_path, spec["script"], "%s: reusa o script de hoje" % file)
		var has_shape: bool = false
		for c: Node in node.get_children():
			if c is CollisionShape2D:
				has_shape = (c as CollisionShape2D).shape != null
		if spec["shape"] and file != "inimigo_mapa.tscn":
			assert_true(has_shape, "%s: colisão" % file)
		for prop: String in spec["props"]:
			assert_true(prop in node, "%s: campo %s" % [file, prop])
		node.free()

func test_defaults_have_no_roteiro_and_event_id_is_empty() -> void:
	for file: String in PREFABS:
		var node: Node = _inst(file)
		if "roteiro" in node:
			assert_null(node.get("roteiro"), "%s: sem roteiro" % file)
			assert_eq(node.get("event_id"), &"", "%s: event_id vazio" % file)
		node.free()

func test_map_enemy_prefab_is_the_map_enemy_scene_with_the_arena_path() -> void:
	var e: MapEnemy = _inst("inimigo_mapa.tscn") as MapEnemy
	assert_not_null(e)
	assert_eq(e.arena_path, NodePath("../Arena"))
	assert_not_null(e.get_node_or_null(^"TouchArea"))
	assert_not_null(e.get_node_or_null(^"CollisionShape2D"))
	e.free()

func test_state_flag_prefabs_have_placeholder_flags() -> void:
	assert_eq(_flag("bau.tscn", "opened_flag"), &"bau_novo")
	assert_eq(_flag("porta_chave.tscn", "open_flag"), &"porta_nova")
	assert_eq(_flag("portao_flag.tscn", "flag"), &"portao_novo")
	assert_eq(_flag("interruptor.tscn", "flag"), &"portao_novo", "o interruptor vem ligado ao portão")
	assert_eq(_flag("obstaculo_elemental.tscn", "flag"), &"obstaculo_novo")

func _flag(file: String, prop: String) -> StringName:
	var n: Node = _inst(file)
	var v: StringName = n.get(prop)
	n.free()
	return v

# --- soltos num mapa modelo ----------------------------------------------------------------------

func _template_map(kind: int) -> Node2D:
	var p: Dictionary = Wizard.plan({"id": "modelo", "kind": kind, "width": 60, "height": 30}, null, "user://m17_prefab_none")
	var root: Node2D = (Builder.build(p) as PackedScene).instantiate() as Node2D
	add_child_autofree(root)
	return root

func _drop(root: Node, file: String, node_name: String, pos: Vector2) -> Node2D:
	var n: Node2D = _inst(file) as Node2D
	if file == "obstaculo_elemental.tscn":
		# O prefab vem sem elemento (o usuário escolhe); sem ele o obstáculo acusa erro ao entrar na árvore.
		(n as ElementalObstacle).element = load("res://data/elements/kagutsuchi.tres") as ElementDef
	n.name = StringName(node_name)
	n.position = pos
	root.add_child(n)
	n.owner = root
	return n

func _bundle(root: Node2D) -> ContentBundle:
	var b := ContentBundle.new()
	var path: String = "res://world/mapas/modelo.tscn"
	b.maps[&"modelo"] = ContentLoader.scan_map(&"modelo", path, root)
	b.roteiro_refs.append_array(ContentLoader.roteiro_refs(&"modelo", path, root))
	return b

func _txt(issues: Array[ValidationIssue]) -> String:
	var out: PackedStringArray = []
	for i: ValidationIssue in issues:
		out.append(i.to_text())
	return "; ".join(out)

func _errors(b: ContentBundle) -> Array[ValidationIssue]:
	return ValidationIssue.errors_of(ContentChecks.run(b))

## Um mapa de destino mínimo, com o marcador `Entry`.
func _with_target(b: ContentBundle) -> ContentBundle:
	var entry: Array[StringName] = [&"Entry"]
	b.maps[&"alvo"] = ContentBundle.map_info("res://alvo.tscn", entry, [] as Array[Dictionary])
	return b

func test_prefabs_dropped_in_a_local_map_pass_the_content_checks() -> void:
	var root: Node2D = _template_map(MapDef.Kind.CIDADE)
	var files: Array[String] = ["npc.tscn", "placa.tscn", "bau.tscn", "loja.tscn", "pousada.tscn", "obstaculo_elemental.tscn",
			"portao_flag.tscn", "interruptor.tscn", "gatilho_evento.tscn", "armadilha.tscn", "porta_chave.tscn", "inimigo_mapa.tscn"]
	var x: float = 320.0
	for f: String in files:
		_drop(root, f, f.get_basename().capitalize().replace(" ", ""), Vector2(x, 320))
		x += 64.0
	# O ponto de descanso e a pousada apontam para marcadores do mapa: o prefab de marcador os fornece.
	_drop(root, "ponto_descanso.tscn", "RestPoint", Vector2(320, 480))
	_drop(root, "marcador_spawn.tscn", "RestSpawn", Vector2(320, 540))
	_drop(root, "marcador_spawn.tscn", "InnSpawn", Vector2(900, 540))
	var errs: Array[ValidationIssue] = _errors(_bundle(root))
	assert_eq(errs.size(), 0, _txt(errs))

func test_unlinked_door_link_is_flagged_until_it_has_a_target() -> void:
	var root: Node2D = _template_map(MapDef.Kind.CIDADE)
	var link: MapLink = _drop(root, "ligacao.tscn", "Porta", Vector2(320, 320)) as MapLink
	var errs: Array[ValidationIssue] = _errors(_bundle(root))
	assert_eq(errs.size(), 1, "o destino ainda não foi escolhido")
	assert_string_contains(errs[0].message, "MapLink Porta")
	link.target_map = &"alvo"
	link.target_spawn = &"Entry"
	var errs2: Array[ValidationIssue] = _errors(_with_target(_bundle(root)))
	assert_eq(errs2.size(), 0, _txt(errs2))

func test_zone_prefab_in_a_world_map() -> void:
	var root: Node2D = _template_map(MapDef.Kind.MUNDO)
	var zone: Zone = _drop(root, "zona.tscn", "Vila", Vector2(320, 320)) as Zone
	assert_eq(_errors(_bundle(root)).size(), 1, "a zona ainda não tem destino")
	zone.zone_id = &"alvo"
	var errs2: Array[ValidationIssue] = _errors(_with_target(_bundle(root)))
	assert_eq(errs2.size(), 0, _txt(errs2))

func test_prefab_drops_on_free_ground() -> void:
	var root: Node2D = _template_map(MapDef.Kind.MASMORRA)
	var grid: TileGrid = TileGrid.from_map(root)
	var n: Node2D = _drop(root, "bau.tscn", "Bau", Vector2(400, 400))
	assert_false(grid.is_solid_at(n.position))

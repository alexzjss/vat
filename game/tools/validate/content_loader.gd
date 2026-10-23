class_name ContentLoader
extends RefCounted

## Junta o conteúdo do disco num [ContentBundle] (M16): `.tres` de `res://data` e `res://art`, os `.roteiro` e um
## resumo de cada mapa de [constant Game.MAPS]. Faz IO, por isso mora em tools/ e não em core/.

const RESOURCE_ROOTS: Array[String] = ["res://data", "res://art"]
const SKIP_DIRS: Array[String] = [".godot", "addons", ".git"]

static func load_all() -> ContentBundle:
	var b := ContentBundle.new()
	var seen: Dictionary = {}
	for root: String in RESOURCE_ROOTS:
		for path: String in _files(root, "tres"):
			var res: Resource = load(path)
			if res != null and not seen.has(res):
				seen[res] = true
				b.resources.append(res)
	for path: String in RoteiroTools.find_roteiros("res://"):
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		b.roteiros[path] = f.get_as_text() if f != null else ""
	for map_id: StringName in Game.MAPS:
		var packed: PackedScene = Game.MAPS[map_id]
		var scene: Node = packed.instantiate()
		b.maps[map_id] = scan_map(map_id, packed.resource_path, scene)
		for ev: EventScript in embedded_events(scene):
			if not seen.has(ev):
				seen[ev] = true
				b.resources.append(ev)
		scene.free()
	return b

## Marcadores e ligações de um mapa instanciado (não precisa estar na árvore).
static func scan_map(map_id: StringName, path: String, scene: Node) -> Dictionary:
	var markers: Array[StringName] = []
	for n: Node in scene.find_children("*", "Marker2D", true, false):
		markers.append(StringName(String(scene.get_path_to(n))))
	var refs: Array[Dictionary] = []
	for n: Node in scene.find_children("*", "Area2D", true, false):
		var link: MapLink = n as MapLink
		if link != null:
			refs.append(ContentBundle.map_ref("MapLink %s" % link.name, link.target_map, link.target_spawn))
		var zone: Zone = n as Zone
		if zone != null and scene is Overworld:
			refs.append(ContentBundle.map_ref("Zone %s" % zone.name, zone.zone_id, zone.spawn))
		var inn: Inn = n as Inn
		if inn != null:
			refs.append(ContentBundle.map_ref("pousada %s" % inn.name, map_id, inn.spawn_name))
		var rest: RestPoint = n as RestPoint
		if rest != null:
			refs.append(ContentBundle.map_ref("ponto de descanso %s" % rest.name, map_id, rest.spawn_name))
	var local: LocalMap = scene as LocalMap
	if local != null and local.get_node_or_null(^"Exit") != null:
		refs.append(ContentBundle.map_ref("saída", &"overworld", Game.EXIT_SPAWNS.get(map_id, &"Start")))
	return ContentBundle.map_info(path, markers, refs)

## EventScripts guardados nas propriedades dos nós do mapa (NPCs, placas, gatilhos).
static func embedded_events(scene: Node) -> Array[EventScript]:
	var out: Array[EventScript] = []
	var nodes: Array[Node] = [scene]
	nodes.append_array(scene.find_children("*", "", true, false))
	for n: Node in nodes:
		for prop: Dictionary in n.get_property_list():
			if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or int(prop["type"]) != TYPE_OBJECT:
				continue
			var ev: EventScript = n.get(prop["name"]) as EventScript
			if ev != null and not out.has(ev):
				out.append(ev)
	return out

static func _files(root: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var names: PackedStringArray = DirAccess.get_files_at(root)
	names.sort()
	for f: String in names:
		if f.get_extension() == ext:
			out.append(root.path_join(f))
	var dirs: PackedStringArray = DirAccess.get_directories_at(root)
	dirs.sort()
	for d: String in dirs:
		if not SKIP_DIRS.has(d):
			out.append_array(_files(root.path_join(d), ext))
	return out

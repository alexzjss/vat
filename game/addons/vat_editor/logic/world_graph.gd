@tool
extends RefCounted

## Lógica pura do grafo do mundo (M17): um nó por mapa do registro e uma aresta por ligação (`MapLink`, `Zone` do mapa-múndi
## e o `$Exit` dos mapas locais), lidas do `SceneState` de cada cena sem instanciar nada. Acusa ligação quebrada (mapa de
## destino ausente ou marcador inexistente), mapas inalcançáveis e dá um layout automático determinístico. A aba Mundo
## (`ui/world_graph_panel.gd`) só desenha.

const Picks: GDScript = preload("res://addons/vat_editor/logic/inspector_picks.gd")

const START_PROFILE_PATH: String = "res://data/fatia/start.tres"
const LAYOUT_PATH: String = "res://addons/vat_editor/mundo_layout.cfg"
const LAYOUT_SECTION: String = "posicoes"
## Para onde o `$Exit` de um mapa local leva (o mesmo que `Game._on_exit_requested`).
const EXIT_TARGET: StringName = &"overworld"

const EDGE_LINK: StringName = &"link"
const EDGE_ZONE: StringName = &"zone"
const EDGE_EXIT: StringName = &"exit"

const COLUMN_STEP: float = 290.0
const ROW_STEP: float = 135.0
const KIND_NAMES: Array[String] = ["Cidade", "Interior", "Masmorra", "Mundo", "Teste"]

# --- leitura de uma cena ------------------------------------------------------------------------------------

## O que uma cena declara, sem instanciá-la: `{root, links, zones, has_exit}`.
## `root` é "local", "overworld" ou "" (outra coisa); `links` e `zones` são listas de `{node, target, spawn}`.
static func scan_scene(scene: PackedScene) -> Dictionary:
	var out: Dictionary = {"root": "", "links": [], "zones": [], "has_exit": false}
	if scene == null:
		return out
	# Do mais base para o mais derivado: o derivado sobrescreve as propriedades do mesmo caminho.
	var states: Array[SceneState] = []
	var st: SceneState = scene.get_state()
	while st != null:
		states.push_front(st)
		st = st.get_base_scene_state()
	var nodes: Dictionary = {}
	var order: Array[String] = []
	for state: SceneState in states:
		for i: int in state.get_node_count():
			var path: String = String(state.get_node_path(i))
			if not nodes.has(path):
				nodes[path] = {}
				order.append(path)
			var props: Dictionary = nodes[path]
			for j: int in state.get_node_property_count(i):
				props[String(state.get_node_property_name(i, j))] = state.get_node_property_value(i, j)
	for path: String in order:
		var props: Dictionary = nodes[path]
		var chain: Array[String] = Picks.script_chain(props.get("script") as Script)
		if path == ".":
			if chain.has("LocalMap"):
				out["root"] = "local"
			elif chain.has("Overworld"):
				out["root"] = "overworld"
			continue
		# Só filhos diretos da raiz ("./Nome"), como o resto do editor.
		if path.count("/") != 1:
			continue
		var node_name: String = path.get_file()
		if chain.has("MapLink"):
			var l: Array = out["links"]
			l.append({"node": node_name, "target": String(props.get("target_map", &"")), "spawn": String(props.get("target_spawn", &"Entry"))})
		elif chain.has("Zone"):
			var z: Array = out["zones"]
			z.append({"node": node_name, "target": String(props.get("zone_id", &"")), "spawn": String(props.get("spawn", &"Entry"))})
		if node_name == "Exit":
			out["has_exit"] = true
	return out

# --- o grafo ------------------------------------------------------------------------------------------------

## O mapa inicial do `data/fatia/start.tres` (vazio se não carregar).
static func start_map_id() -> StringName:
	var profile: StartProfile = load(START_PROFILE_PATH) as StartProfile
	return profile.map if profile != null else &""

## O grafo do `registry`: `{nodes, edges, unreachable, start, test_ids}`.
## `nodes`: `{id, name, kind (MapDef.Kind), kind_label, scene, spawns, counts {links, zones, exit}, test}` na ordem do registro.
## `edges`: `{from, to, spawn, source, kind, label, broken, message}`; `source` é o nome do nó na cena de origem.
## `unreachable`: ids sem nenhuma ligação vinda de outro mapa, fora o inicial (`start`; vazio = o do start.tres) e os de teste.
static func build(registry: MapRegistry, start: StringName = &"") -> Dictionary:
	var nodes: Array[Dictionary] = []
	var edges: Array[Dictionary] = []
	var start_id: StringName = start if start != &"" else start_map_id()
	var unreachable: Array[String] = []
	var test_ids: Array[String] = []
	if registry == null:
		return {"nodes": nodes, "edges": edges, "unreachable": unreachable, "start": start_id, "test_ids": test_ids}
	var seen: Dictionary = {}
	for d: MapDef in registry.maps:
		if d == null or d.id == &"" or seen.has(d.id):
			continue
		seen[d.id] = true
		var scan: Dictionary = scan_scene(d.scene)
		var markers: Array[String] = Picks.spawns_of(d.scene)
		var exit_here: bool = scan["root"] == "local" and bool(scan["has_exit"])
		var zone_count: int = (scan["zones"] as Array).size() if scan["root"] == "overworld" else 0
		nodes.append({
			"id": String(d.id),
			"name": d.display_name if d.display_name != "" else String(d.id),
			"kind": int(d.kind),
			"kind_label": kind_label(int(d.kind)),
			"scene": d.scene.resource_path if d.scene != null else "",
			"spawns": markers,
			"counts": {"links": (scan["links"] as Array).size(), "zones": zone_count, "exit": exit_here},
			"test": d.kind == MapDef.Kind.TESTE,
		})
		for l: Dictionary in scan["links"]:
			edges.append(_edge(registry, d.id, EDGE_LINK, l["node"], l["target"], l["spawn"]))
		if scan["root"] == "overworld":
			for z: Dictionary in scan["zones"]:
				edges.append(_edge(registry, d.id, EDGE_ZONE, z["node"], z["target"], z["spawn"]))
		if exit_here:
			var back: String = String(d.exit_spawn) if d.exit_spawn != &"" else "Start"
			edges.append(_edge(registry, d.id, EDGE_EXIT, "Exit", String(EXIT_TARGET), back))
	var incoming: Dictionary = {}
	for e: Dictionary in edges:
		if e["to"] != e["from"]:
			incoming[e["to"]] = true
	for n: Dictionary in nodes:
		if bool(n["test"]):
			test_ids.append(n["id"])
		elif String(n["id"]) != String(start_id) and not incoming.has(n["id"]):
			unreachable.append(n["id"])
	return {"nodes": nodes, "edges": edges, "unreachable": unreachable, "start": start_id, "test_ids": test_ids}

static func _edge(registry: MapRegistry, from: StringName, kind: StringName, source: String, target: String, spawn: String) -> Dictionary:
	var message: String = Picks.map_problem(registry, target)
	if message == "":
		message = Picks.spawn_problem(registry, target, spawn)
	return {
		"from": String(from), "to": target, "spawn": spawn, "source": source, "kind": kind,
		"label": "%s %s -> %s" % [kind_text(kind), source, spawn if spawn != "" else "(sem ponto)"],
		"broken": message != "", "message": message,
	}

static func kind_label(kind: int) -> String:
	return KIND_NAMES[kind] if kind >= 0 and kind < KIND_NAMES.size() else "?"

static func kind_text(kind: StringName) -> String:
	match kind:
		EDGE_ZONE:
			return "zona"
		EDGE_EXIT:
			return "saída"
		_:
			return "ligação"

## As arestas quebradas.
static func broken_edges(graph: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in graph["edges"]:
		if bool(e["broken"]):
			out.append(e)
	return out

## As arestas que saem de `map_id` ou chegam nele.
static func edges_of(graph: Dictionary, map_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in graph["edges"]:
		if e["from"] == map_id or e["to"] == map_id:
			out.append(e)
	return out

## O grafo sem os mapas de teste (e sem as arestas que tocam neles).
static func without_tests(graph: Dictionary) -> Dictionary:
	var tests: Array = graph["test_ids"]
	var nodes: Array[Dictionary] = []
	for n: Dictionary in graph["nodes"]:
		if not tests.has(n["id"]):
			nodes.append(n)
	var edges: Array[Dictionary] = []
	for e: Dictionary in graph["edges"]:
		if not tests.has(e["from"]) and not tests.has(e["to"]):
			edges.append(e)
	var out: Dictionary = graph.duplicate()
	out["nodes"] = nodes
	out["edges"] = edges
	return out

# --- layout -------------------------------------------------------------------------------------------------

## Layout automático: colunas pela distância (seguindo as arestas) a partir do mapa inicial, linhas na ordem do registro.
## Mapas que o inicial não alcança formam novas colunas à direita, cada grupo a partir do seu primeiro mapa. Determinístico.
## Devolve id -> Vector2.
static func auto_layout(graph: Dictionary) -> Dictionary:
	var ids: Array[String] = []
	var adj: Dictionary = {}
	for n: Dictionary in graph["nodes"]:
		ids.append(n["id"])
		adj[n["id"]] = []
	for e: Dictionary in graph["edges"]:
		if adj.has(e["from"]) and adj.has(e["to"]) and not (adj[e["from"]] as Array).has(e["to"]):
			(adj[e["from"]] as Array).append(e["to"])
	var column: Dictionary = {}
	var base: int = 0
	var roots: Array[String] = []
	if ids.has(String(graph["start"])):
		roots.append(String(graph["start"]))
	roots.append_array(ids)
	for root: String in roots:
		if column.has(root):
			continue
		column[root] = base
		var queue: Array[String] = [root]
		var top: int = base
		while not queue.is_empty():
			var cur: String = queue.pop_front()
			for nxt: String in adj[cur]:
				if not column.has(nxt):
					column[nxt] = int(column[cur]) + 1
					top = maxi(top, int(column[nxt]))
					queue.append(nxt)
		base = top + 1
	var rows: Dictionary = {}
	var out: Dictionary = {}
	for id: String in ids:
		var c: int = column[id]
		var r: int = int(rows.get(c, 0))
		rows[c] = r + 1
		out[id] = Vector2(c * COLUMN_STEP, r * ROW_STEP)
	return out

## O layout a usar: as posições gravadas em `saved` (id -> Vector2) para os mapas que as têm, o automático para o resto.
static func merged_layout(graph: Dictionary, saved: Dictionary) -> Dictionary:
	var out: Dictionary = auto_layout(graph)
	for id: Variant in out.keys():
		if saved.get(id) is Vector2:
			out[id] = saved[id]
	return out

# --- persistência -------------------------------------------------------------------------------------------

## Grava as posições (id -> Vector2) em `path`, mantendo no arquivo os mapas que não estão em `positions`.
static func save_layout(path: String, positions: Dictionary) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(path)
	for id: Variant in positions.keys():
		if positions[id] is Vector2:
			cfg.set_value(LAYOUT_SECTION, String(id), positions[id])
	return cfg.save(path)

## As posições gravadas em `path` (id -> Vector2); vazio se o arquivo não existe.
static func load_layout(path: String) -> Dictionary:
	var out: Dictionary = {}
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return out
	if cfg.has_section(LAYOUT_SECTION):
		for key: String in cfg.get_section_keys(LAYOUT_SECTION):
			var v: Variant = cfg.get_value(LAYOUT_SECTION, key)
			if v is Vector2:
				out[key] = v
	return out

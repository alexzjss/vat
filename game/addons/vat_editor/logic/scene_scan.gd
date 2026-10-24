@tool
extends RefCounted

## Leitura pura de uma `PackedScene` sem instanciá-la (M17): cada nó da árvore inteira (como o `find_children` do validador),
## com o tipo e as propriedades efetivos. Resolve cenas herdadas (o derivado sobrescreve a base) e nós que são instâncias de
## prefabs (o tipo, o script e os valores padrão vêm da cena instanciada; as propriedades gravadas no mapa sobrescrevem),
## inclusive instâncias aninhadas. Usado pelo grafo do mundo e pelas listas de marcadores.

## Caminho de um nó relativo à raiz: "" é a raiz, "Nome" um filho direto, "Sub/Nome" um neto.
## Devolve `{nodes: Dictionary, order: Array[String]}`; cada nó é `{name, type, props}`.
static func collect(scene: PackedScene) -> Dictionary:
	var nodes: Dictionary = {}
	var order: Array[String] = []
	if scene != null:
		_fill(scene, "", nodes, order, 0)
	return {"nodes": nodes, "order": order}

static func _fill(scene: PackedScene, prefix: String, nodes: Dictionary, order: Array[String], depth: int) -> void:
	if depth > 16:
		return # ciclo de instâncias: não deveria existir
	# Do mais base para o mais derivado: o derivado sobrescreve as propriedades do mesmo caminho.
	var states: Array[SceneState] = []
	var st: SceneState = scene.get_state()
	while st != null:
		states.push_front(st)
		st = st.get_base_scene_state()
	for state: SceneState in states:
		for i: int in state.get_node_count():
			var rel: String = _relative(String(state.get_node_path(i)))
			var full: String = prefix if rel == "" else (rel if prefix == "" else prefix + "/" + rel)
			if not nodes.has(full):
				nodes[full] = {"name": full.get_file(), "type": "", "props": {}}
				order.append(full)
			var entry: Dictionary = nodes[full]
			var inst: PackedScene = state.get_node_instance(i)
			if inst != null:
				_fill(inst, full, nodes, order, depth + 1)
			var type: String = String(state.get_node_type(i))
			if type != "":
				entry["type"] = type
			var props: Dictionary = entry["props"]
			for j: int in state.get_node_property_count(i):
				props[String(state.get_node_property_name(i, j))] = state.get_node_property_value(i, j)

static func _relative(path: String) -> String:
	if path == "." or path == "":
		return ""
	return path.trim_prefix("./")

## O script efetivo de um nó coletado (nulo se não tem).
static func script_of(entry: Dictionary) -> Script:
	return (entry["props"] as Dictionary).get("script") as Script

## Se o tipo nativo do nó é `native` ou herda dele (ex.: "Marker2D").
static func is_type(entry: Dictionary, native: String) -> bool:
	var type: String = String(entry["type"])
	return type != "" and (type == native or ClassDB.is_parent_class(type, native))

## Os caminhos (relativos à raiz) de todos os nós de tipo nativo `native`, sem a raiz, na ordem de leitura.
static func paths_of_type(scene: PackedScene, native: String) -> Array[String]:
	var out: Array[String] = []
	var data: Dictionary = collect(scene)
	var nodes: Dictionary = data["nodes"]
	for path: String in data["order"]:
		if path != "" and is_type(nodes[path], native):
			out.append(path)
	return out

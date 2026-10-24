@tool
extends RefCounted

## Lógica pura da paleta de objetos (M17): quais prefabs cada tipo de mapa oferece, a grade de 32 px, nomes e flags
## únicos e a posição onde o prefab entra. Sem Node de editor e sem IO (o dock em `ui/object_palette.gd` só liga isto
## ao `EditorUndoRedoManager` e à vista 2D).

const GRID: int = 32
const KIND_LOCAL: StringName = &"local"
const KIND_OVERWORLD: StringName = &"overworld"
const KIND_NONE: StringName = &""
const PREFAB_DIR: String = "res://world/prefabs/"

## Os prefabs, na ordem dos botões. `icons` é a lista de ícones do tema do editor (o primeiro que existir vale).
const PREFABS: Array[Dictionary] = [
	{"id": &"npc", "name": "NPC", "icons": ["Skeleton2D", "Sprite2D", "Node2D"], "kinds": [&"local"]},
	{"id": &"placa", "name": "Placa", "icons": ["Label", "Node2D"], "kinds": [&"local", &"overworld"]},
	{"id": &"ligacao", "name": "Ligação", "icons": ["Link", "Area2D"], "kinds": [&"local"]},
	{"id": &"bau", "name": "Baú", "icons": ["Package", "Area2D"], "kinds": [&"local"]},
	{"id": &"ponto_descanso", "name": "Ponto de descanso", "icons": ["Heart", "Area2D"], "kinds": [&"local"]},
	{"id": &"loja", "name": "Loja", "icons": ["Shop", "Area2D"], "kinds": [&"local"]},
	{"id": &"pousada", "name": "Pousada", "icons": ["Groups", "Area2D"], "kinds": [&"local"]},
	{"id": &"inimigo_mapa", "name": "Inimigo do mapa", "icons": ["CharacterBody2D", "Area2D"], "kinds": [&"local"]},
	{"id": &"obstaculo_elemental", "name": "Obstáculo elemental", "icons": ["StaticBody2D", "Area2D"], "kinds": [&"local"]},
	{"id": &"portao_flag", "name": "Portão de flag", "icons": ["Lock", "StaticBody2D"], "kinds": [&"local"]},
	{"id": &"porta_chave", "name": "Porta com chave", "icons": ["Key", "Area2D"], "kinds": [&"local"]},
	{"id": &"interruptor", "name": "Interruptor", "icons": ["ToolButton", "Area2D"], "kinds": [&"local"]},
	{"id": &"gatilho_evento", "name": "Gatilho de evento", "icons": ["Signal", "Area2D"], "kinds": [&"local", &"overworld"]},
	{"id": &"armadilha", "name": "Armadilha", "icons": ["Warning", "Area2D"], "kinds": [&"local"]},
	{"id": &"marcador_spawn", "name": "Marcador de spawn", "icons": ["Marker2D", "Position2D"], "kinds": [&"local", &"overworld"]},
	{"id": &"zona", "name": "Zona", "icons": ["Area2D", "Node2D"], "kinds": [&"overworld"]},
]

## Valores provisórios de flag dos prefabs -> prefixo da flag gerada (`bau_novo` -> `bau_<mapa>_<n>`).
const PLACEHOLDERS: Dictionary = {
	&"bau_novo": "bau",
	&"porta_nova": "porta",
	&"portao_novo": "portao",
	&"obstaculo_novo": "obstaculo",
}
## Propriedades de flag que identificam o próprio objeto (duas iguais num mapa são um erro de cópia).
const OWN_ID_PROPS: Array[StringName] = [&"opened_flag"]

## O tipo de mapa de uma cena a partir da cadeia de scripts da raiz (nomes de `class_name`): local, overworld ou nenhum.
static func kind_of_chain(chain: Array[String]) -> StringName:
	if chain.has("Overworld"):
		return KIND_OVERWORLD
	if chain.has("LocalMap"):
		return KIND_LOCAL
	return KIND_NONE

## Os nomes de `class_name` do script e dos que ele estende (do mais específico ao mais geral).
static func script_chain(script: Script) -> Array[String]:
	var out: Array[String] = []
	var s: Script = script
	while s != null:
		var n: String = s.get_global_name()
		if n != "":
			out.append(n)
		s = s.get_base_script()
	return out

static func kind_of_node(root: Node) -> StringName:
	if root == null:
		return KIND_NONE
	return kind_of_chain(script_chain(root.get_script() as Script))

## Os prefabs que o tipo de mapa oferece, na ordem dos botões. Tipo sem paleta: lista vazia.
static func prefabs_for(kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if kind == KIND_NONE:
		return out
	for p: Dictionary in PREFABS:
		if (p["kinds"] as Array).has(kind):
			out.append(p)
	return out

static func prefab_path(id: StringName) -> String:
	return PREFAB_DIR + String(id) + ".tscn"

# --- grade e posição ----------------------------------------------------------------------------------------

## O ponto na grade mais próximo (arredonda para o múltiplo de `grid`).
static func snap(pos: Vector2, grid: int = GRID) -> Vector2:
	var g: float = float(maxi(grid, 1))
	return Vector2(roundf(pos.x / g) * g, roundf(pos.y / g) * g)

## Onde o prefab entra: o último clique (se houver), senão o centro da vista, senão `fallback`; sempre na grade.
## `last_click` e `view_center` são Vector2 ou null (sem clique ainda, ou sem vista 2D).
static func placement(last_click: Variant, view_center: Variant, fallback: Vector2 = Vector2.ZERO, grid: int = GRID) -> Vector2:
	if last_click is Vector2 and (last_click as Vector2).is_finite():
		return snap(last_click as Vector2, grid)
	if view_center is Vector2 and (view_center as Vector2).is_finite():
		return snap(view_center as Vector2, grid)
	return snap(fallback, grid)

# --- nomes únicos -------------------------------------------------------------------------------------------

## `base` se ainda não existe; senão `base2`, `base3`... (o primeiro livre). O sufixo numérico de `base` é ignorado.
static func unique_name(base: String, existing: Array[String]) -> String:
	var stem: String = base
	while stem.length() > 1 and stem[stem.length() - 1].is_valid_int():
		stem = stem.left(stem.length() - 1)
	if not existing.has(stem):
		return stem
	var n: int = 2
	while existing.has("%s%d" % [stem, n]):
		n += 1
	return "%s%d" % [stem, n]

## Os nomes de todos os nós abaixo de `root` (o próprio `root` incluído).
static func collect_names(root: Node) -> Array[String]:
	var out: Array[String] = []
	if root == null:
		return out
	out.append(String(root.name))
	for n: Node in root.find_children("*", "", true, false):
		out.append(String(n.name))
	return out

# --- flags únicas -------------------------------------------------------------------------------------------

static func is_placeholder(flag: Variant) -> bool:
	return (flag is StringName or flag is String) and PLACEHOLDERS.has(StringName(flag))

## O id do mapa para compor as flags: o do registro (pela cena) ou o nome da raiz em minúsculas.
static func map_id_for(scene_path: String, registry: MapRegistry, root_name: String) -> String:
	if registry != null and scene_path != "":
		for d: MapDef in registry.maps:
			if d != null and d.scene != null and d.scene.resource_path == scene_path and d.id != &"":
				return String(d.id)
	return root_name.to_snake_case() if root_name != "" else "mapa"

## A próxima flag livre `<prefixo>_<mapa>_<n>` (n a partir de 1) que não está em `existing`.
static func next_flag(prefix: String, map_id: String, existing: Array[String]) -> String:
	var n: int = 1
	while existing.has("%s_%s_%d" % [prefix, map_id, n]):
		n += 1
	return "%s_%s_%d" % [prefix, map_id, n]

## Para um nó (`props`: nome -> valor das propriedades de flag): as trocas {propriedade: flag nova}. Valores provisórios
## sempre trocam; as propriedades "de identidade" (`OWN_ID_PROPS`) também trocam quando a flag já existe em `taken`
## (as flags dos outros nós). As flags novas não repetem nem `taken` nem as já dadas neste nó.
static func flag_changes(props: Dictionary, map_id: String, taken: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	var used: Array[String] = taken.duplicate()
	for k: Variant in props:
		var v: String = String(props[k])
		var prefix: String = ""
		if is_placeholder(v):
			prefix = String(PLACEHOLDERS[StringName(v)])
		elif OWN_ID_PROPS.has(StringName(k)) and v != "" and taken.has(v):
			prefix = "bau"
		if prefix == "":
			continue
		var fresh: String = next_flag(prefix, map_id, used)
		used.append(fresh)
		out[k] = StringName(fresh)
	return out

## As propriedades de flag de um nó: as exportadas StringName cujo nome é `flag` ou termina em `_flag`.
static func flag_props_of(node: Node) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in node.get_property_list():
		var pname: String = p["name"]
		if int(p["type"]) != TYPE_STRING_NAME or (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if pname == "flag" or pname.ends_with("_flag"):
			out[StringName(pname)] = node.get(pname)
	return out

## Todas as flags em uso abaixo de `root` (ele incluído), sem contar os nós de `except`.
static func collect_flags(root: Node, except: Array[Node] = []) -> Array[String]:
	var out: Array[String] = []
	if root == null:
		return out
	var all: Array[Node] = root.find_children("*", "", true, false)
	all.append(root)
	for n: Node in all:
		if except.has(n):
			continue
		var props: Dictionary = flag_props_of(n)
		for k: Variant in props:
			var v: String = String(props[k])
			if v != "" and not out.has(v):
				out.append(v)
	return out

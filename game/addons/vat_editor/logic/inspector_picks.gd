@tool
extends RefCounted

## Lógica pura das escolhas em lista do Inspector (M17): que propriedade ganha que menu, de onde vêm as opções (os mapas
## do registro, os marcadores da cena de destino, os livros `.roteiro` e os eventos deles, os recursos de conteúdo) e como
## um valor inválido aparece. Sem Node de editor: `inspector/vat_inspector_plugin.gd` só desenha.

const SceneScan: GDScript = preload("res://addons/vat_editor/logic/scene_scan.gd")

const PICK_MAP: StringName = &"map"
const PICK_SPAWN: StringName = &"spawn"
const PICK_BOOK: StringName = &"book"
const PICK_EVENT: StringName = &"event"
const PICK_RESOURCE: StringName = &"resource"

const NONE_LABEL: String = "(nenhum)"
const INVALID_SUFFIX: String = " (inválido)"

## (script, propriedade) -> tipo de menu. `Script` é o nome de `class_name` na cadeia do objeto.
const MAP_PROPS: Dictionary = {
	"MapLink": {"target_map": "map", "target_spawn": "spawn"},
	"Zone": {"zone_id": "map", "spawn": "spawn"},
}
## Quem tem `roteiro` + `event_id` ganha os menus do livro e do evento.
const BOOK_PROP: StringName = &"roteiro"
const EVENT_PROP: StringName = &"event_id"
## Propriedades de recurso: classe -> propriedade -> tipo do recurso (nome de `class_name`).
const RESOURCE_PROPS: Dictionary = {
	"MapEnemy": {"encounter": "EncounterDef"},
	"ShopKeeper": {"shop": "ShopDef"},
	"Npc": {"speaker": "SpeakerDef"},
	"ElementalObstacle": {"element": "ElementDef"},
}
## A propriedade que diz o mapa de destino de uma de spawn: `target_spawn` lê `target_map`; `spawn` da Zona lê `zone_id`.
const SPAWN_MAP_PROP: Dictionary = {"target_spawn": "target_map", "spawn": "zone_id"}

## O menu de uma propriedade de um objeto cuja cadeia de scripts é `chain`: `{kind, resource_class}` ou {} se não tem.
static func pick_for(chain: Array[String], prop: StringName, has_roteiro_pair: bool) -> Dictionary:
	for cls: String in chain:
		if MAP_PROPS.has(cls) and (MAP_PROPS[cls] as Dictionary).has(String(prop)):
			return {"kind": StringName((MAP_PROPS[cls] as Dictionary)[String(prop)])}
		if RESOURCE_PROPS.has(cls) and (RESOURCE_PROPS[cls] as Dictionary).has(String(prop)):
			return {"kind": PICK_RESOURCE, "resource_class": (RESOURCE_PROPS[cls] as Dictionary)[String(prop)]}
	if has_roteiro_pair and prop == BOOK_PROP:
		return {"kind": PICK_BOOK}
	if has_roteiro_pair and prop == EVENT_PROP:
		return {"kind": PICK_EVENT}
	return {}

## Se o objeto tem as duas propriedades `roteiro` e `event_id` (a partir da lista de propriedades).
static func has_roteiro_pair(property_names: Array[String]) -> bool:
	return property_names.has(String(BOOK_PROP)) and property_names.has(String(EVENT_PROP))

# --- fontes de opções ---------------------------------------------------------------------------------------

## Os ids dos mapas do registro, na ordem dele.
static func map_ids(registry: MapRegistry) -> Array[String]:
	var out: Array[String] = []
	if registry == null:
		return out
	for id: StringName in registry.ids():
		out.append(String(id))
	return out

## Os marcadores (Marker2D, inclusive os de prefabs instanciados e os herdados da cena-base) de uma cena, pelo caminho
## relativo à raiz, como o validador os lista. Cena nula: vazio. Não instancia nada.
static func spawns_of(scene: PackedScene) -> Array[String]:
	return SceneScan.paths_of_type(scene, "Marker2D")

## Os marcadores do mapa `map_id` do registro (vazio se o mapa não existe).
static func spawns_for_map(registry: MapRegistry, map_id: StringName) -> Array[String]:
	if registry == null:
		return []
	return spawns_of(registry.scene_of(map_id))

## Os ids dos eventos de um livro, em ordem alfabética (livro nulo: vazio).
static func event_ids(book: RoteiroBook) -> Array[String]:
	var out: Array[String] = []
	if book == null:
		return out
	for k: Variant in book.events.keys():
		out.append(String(k))
	out.sort()
	return out

## Os caminhos dos livros `.roteiro` disponíveis, em ordem (entregues por quem varre o projeto), só os que existem.
static func book_paths(paths: Array[String]) -> Array[String]:
	var out: Array[String] = paths.duplicate()
	out.sort()
	return out

## Rótulo de um recurso no menu: "id - Nome" (ou o que existir; o nome do arquivo no fim).
static func resource_label(res: Resource) -> String:
	if res == null:
		return NONE_LABEL
	var id: String = str(res.get(&"id")) if res.get(&"id") != null else ""
	var shown: String = ""
	for prop: StringName in [&"display_name", &"name"]:
		var v: Variant = res.get(prop)
		if v != null and str(v) != "":
			shown = str(v)
			break
	if id == "":
		id = res.resource_path.get_file().get_basename()
	if id == "" and shown == "":
		return "(sem id)"
	return id if shown == "" or shown == id else "%s - %s" % [id, shown]

## Entre `resources`, os que são da classe `class_name_` (nome de `class_name`), como `{label, resource}` em ordem de rótulo.
static func resource_options(resources: Array, class_name_: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in resources:
		var res: Resource = r as Resource
		if res == null:
			continue
		if not script_chain(res.get_script() as Script).has(class_name_):
			continue
		out.append({"label": resource_label(res), "resource": res})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["label"]) < String(b["label"]))
	return out

static func script_chain(script: Script) -> Array[String]:
	var out: Array[String] = []
	var s: Script = script
	while s != null:
		var n: String = s.get_global_name()
		if n != "":
			out.append(n)
		s = s.get_base_script()
	return out

# --- valor atual e invalidez --------------------------------------------------------------------------------

## A lista de um menu de texto: `[""] + values`, e o valor atual se não estiver nela (primeiro depois do vazio) com a
## marca de inválido. Devolve `{values: Array[String], index: int, invalid: bool}`; `""` é "(nenhum)".
static func choices(values: Array[String], current: String) -> Dictionary:
	var list: Array[String] = [""]
	list.append_array(values)
	var invalid: bool = current != "" and not values.has(current)
	if invalid:
		list.insert(1, current)
	return {"values": list, "index": maxi(list.find(current), 0), "invalid": invalid}

## O texto de um item da lista de `choices`.
static func choice_label(value: String, invalid: bool, is_current: bool) -> String:
	if value == "":
		return NONE_LABEL
	return value + INVALID_SUFFIX if invalid and is_current else value

## Por que o mapa de destino é inválido, ou "" se está certo (vazio conta como pendente: "sem destino").
static func map_problem(registry: MapRegistry, map_id: String) -> String:
	if map_id == "":
		return "sem destino"
	if registry == null or not registry.has(StringName(map_id)):
		return "o mapa '%s' não está no registro" % map_id
	return ""

## Por que o marcador é inválido, ou "" se está certo. Sem mapa de destino, não há como conferir (vale "").
static func spawn_problem(registry: MapRegistry, map_id: String, spawn: String) -> String:
	if map_id == "" or registry == null or not registry.has(StringName(map_id)):
		return ""
	if spawn == "":
		return "sem ponto de entrada"
	if not spawns_for_map(registry, StringName(map_id)).has(spawn):
		return "o mapa '%s' não tem o marcador '%s'" % [map_id, spawn]
	return ""

## Por que o evento é inválido, ou "".
static func event_problem(book: RoteiroBook, event_id: String) -> String:
	if event_id == "":
		return ""
	if book == null:
		return "o evento '%s' precisa de um roteiro" % event_id
	if not book.events.has(StringName(event_id)):
		return "o roteiro não tem o evento '%s'" % event_id
	return ""

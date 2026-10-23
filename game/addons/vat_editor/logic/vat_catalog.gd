@tool
extends RefCounted

## Listagem do Banco (M16): acha os `.tres` das pastas de uma categoria e carrega os que são do tipo certo.
## Também diz se um id já está em uso (ContentIndex para os tipos que ele indexa; varredura para os demais).

const Categories: GDScript = preload("res://addons/vat_editor/logic/vat_categories.gd")

## Tipo do ContentIndex para cada categoria que ele indexa.
const INDEX_KINDS: Dictionary[StringName, StringName] = {
	&"heroes": &"hero", &"items": &"item", &"equipment": &"equip", &"encounters": &"encounter", &"abilities": &"ability",
}

## Todo `.tres` sob `folders` (recursivo, em ordem). Pasta inexistente é ignorada.
static func list_paths(folders: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for f: String in folders:
		_collect(f, out)
	out.sort()
	return out

static func _collect(dir: String, out: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.get_extension() == "tres":
			out.append(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		if sub != ".godot":
			_collect(dir.path_join(sub), out)

## Os recursos da categoria `key`, carregados das pastas dela.
static func load_category(key: StringName) -> Array[Resource]:
	var out: Array[Resource] = []
	var cat: Dictionary = Categories.get_category(key)
	if cat.is_empty():
		return out
	var folders: Array[String] = []
	folders.assign(cat["folders"])
	for path: String in list_paths(folders):
		var res: Resource = load(path)
		if res != null and Categories.matches(key, res):
			out.append(res)
	return out

## O recurso que já usa `id` na categoria `key` dentro de `resources` (todos os carregados), ou null.
static func find_by_id(key: StringName, id: StringName, resources: Array) -> Resource:
	if INDEX_KINDS.has(key):
		return ContentIndex.from_resources(resources).resolve(INDEX_KINDS[key], id)
	for v: Variant in resources:
		var r: Resource = v as Resource
		if r != null and Categories.matches(key, r) and r.get(&"id") == id:
			return r
	return null

@tool
extends RefCounted

## Criação de recursos novos do Banco (M16), pura: monta o recurso (a partir do modelo da categoria ou de um existente)
## com o id novo e diz onde salvar. Quem salva e atualiza o FileSystem é o painel.

const Categories: GDScript = preload("res://addons/vat_editor/logic/vat_categories.gd")
const Catalog: GDScript = preload("res://addons/vat_editor/logic/vat_catalog.gd")

## "" se o id é aceitável; senão a mensagem. Só `a-z`, `0-9` e `_`, começando por letra.
static func id_error(id: String) -> String:
	if id == "":
		return "Informe um id."
	var re := RegEx.new()
	re.compile("^[a-z][a-z0-9_]*$")
	if re.search(id) == null:
		return "O id deve usar só letras minúsculas, números e _, começando por letra."
	return ""

## "" se a pasta é aceitável; senão a mensagem.
static func folder_error(folder: String) -> String:
	if not folder.begins_with("res://") or folder.contains(".."):
		return "A pasta deve ficar dentro do projeto (res://...)."
	return ""

static func target_path(folder: String, id: String) -> String:
	return folder.trim_suffix("/").path_join(id + ".tres")

static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "resource": null, "path": ""}

## Monta o recurso novo. `source` é o recurso a duplicar (null = usar o modelo da categoria); `all` são os recursos já
## carregados, para recusar id repetido. Devolve `{ok, error, resource, path}`.
static func build(key: StringName, id: String, folder: String, source: Resource, all: Array) -> Dictionary:
	var cat: Dictionary = Categories.get_category(key)
	if cat.is_empty():
		return _fail("Categoria desconhecida: %s." % key)
	var err: String = id_error(id)
	if err == "":
		err = folder_error(folder)
	if err != "":
		return _fail(err)
	var clash: Resource = Catalog.find_by_id(key, StringName(id), all)
	if clash != null:
		return _fail("O id '%s' já existe em %s." % [id, clash.resource_path])
	var path: String = target_path(folder, id)
	if FileAccess.file_exists(path):
		return _fail("Já existe um arquivo em %s." % path)
	var base: Resource = source
	if base == null:
		base = load(cat["template"]) as Resource
		if base == null:
			return _fail("Modelo não encontrado: %s." % cat["template"])
	elif not Categories.matches(key, base):
		return _fail("O recurso escolhido não é da categoria %s." % cat["label"])
	# Cópia funda só dos sub-recursos embutidos (Stats...); definições externas (habilidades, arte) continuam referências.
	var res: Resource = base.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	res.set(&"id", StringName(id))
	return {"ok": true, "error": "", "resource": res, "path": path}

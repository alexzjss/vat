@tool
extends RefCounted

## Preferências dos formulários do Banco (M18): quais seções recolhíveis estão abertas, por tipo de formulário. Fica num
## `ConfigFile` (`vat_editor.cfg`, na pasta de configuração do editor; `user://vat_editor.cfg` quando a API do editor não existe,
## como nos testes). Puro: o caminho entra por parâmetro, e arquivo ausente ou ilegível devolve o padrão.

const SECTION: String = "form_sections"
const FILE_NAME: String = "vat_editor.cfg"
## Seções que começam recolhidas (`tipo -> títulos`). O resto começa aberto.
const DEFAULT_COLLAPSED: Dictionary = {
	&"heroes": ["Afinidades", "Arte"],
	&"enemies": ["Afinidades", "Arte"],
}

## O arquivo de preferências: a pasta de configuração do editor, ou `user://` fora dele.
static func default_path() -> String:
	if Engine.is_editor_hint() and Engine.has_singleton(&"EditorInterface"):
		var paths: Object = (Engine.get_singleton(&"EditorInterface") as Object).call(&"get_editor_paths")
		if paths != null:
			var dir: String = str(paths.call(&"get_config_dir"))
			if dir != "":
				return dir.path_join(FILE_NAME)
	return "user://" + FILE_NAME

## Aberta ou recolhida sem consultar o arquivo.
static func default_open(kind: StringName, title: String) -> bool:
	return not (DEFAULT_COLLAPSED.get(kind, []) as Array).has(title)

static func _key(kind: StringName, title: String) -> String:
	return "%s/%s" % [kind, title]

## O arquivo lido, ou null se não existe ou está ilegível. Antes de entregar ao `ConfigFile` (que reclama no log a cada erro)
## confere o formato por linha: etiqueta `[...]` fechada ou `chave = valor`.
static func _read(path: String) -> ConfigFile:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	for line: String in text.split("\n"):
		var t: String = line.strip_edges()
		if t == "" or t.begins_with(";"):
			continue
		if t.begins_with("["):
			if not t.ends_with("]"):
				return null
		elif not t.contains("="):
			return null
	var cfg := ConfigFile.new()
	return cfg if cfg.parse(text) == OK else null

## A seção `title` do formulário `kind` está aberta? Sem arquivo, sem a chave ou com valor que não é verdadeiro/falso: o padrão.
static func is_open(path: String, kind: StringName, title: String) -> bool:
	var cfg: ConfigFile = _read(path)
	if cfg == null or not cfg.has_section_key(SECTION, _key(kind, title)):
		return default_open(kind, title)
	var value: Variant = cfg.get_value(SECTION, _key(kind, title))
	return value if value is bool else default_open(kind, title)

## Grava o estado da seção, mantendo o resto do arquivo (outras chaves e seções do editor). Um arquivo ilegível é refeito.
static func set_open(path: String, kind: StringName, title: String, open: bool) -> Error:
	var cfg: ConfigFile = _read(path)
	if cfg == null:
		cfg = ConfigFile.new()
	cfg.set_value(SECTION, _key(kind, title), open)
	return cfg.save(path)

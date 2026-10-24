class_name RoteiroTools
extends RefCounted

## Ferramentas de roteiro fora do jogo (M16): varredura de `res://data`, lista de `.roteiro` e a checagem usada
## pelo importador, por `tools/roteiro/check.gd` e pelos testes. O jogo em execução não usa nada daqui.

const DATA_ROOT: String = "res://data"
const EXTENSION: String = "roteiro"
## Pastas que a busca de `.roteiro` não entra.
const SKIP_DIRS: Array[String] = [".godot", "addons", ".git"]

## Carrega todo `.tres` de `root` (recursivo) e indexa os de conteúdo por id.
static func scan_content(root: String = DATA_ROOT) -> ContentIndex:
	var all: Array = []
	for path: String in _files(root, "tres"):
		var res: Resource = load(path)
		if res != null:
			all.append(res)
	return ContentIndex.from_resources(all)

## Todos os `.roteiro` sob `root`, em ordem.
static func find_roteiros(root: String = "res://") -> Array[String]:
	var out: Array[String] = _files(root, EXTENSION)
	out.sort()
	return out

## Compila o texto de um `.roteiro` com o índice. Devolve `{events, errors, warnings}`.
static func compile_text(text: String, source_name: String, index: ContentIndex) -> Dictionary:
	return RoteiroCompiler.compile(text, source_name, index.resolver())

## Compila o arquivo `.roteiro` em `path`. Arquivo ilegível vira um erro.
static func compile_file(path: String, index: ContentIndex) -> Dictionary:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		var errs: Array[String] = ["%s:0: não foi possível abrir o arquivo" % path.get_file()]
		return {"events": {}, "errors": errs, "warnings": [] as Array[String]}
	return compile_text(f.get_as_text(), path.get_file(), index)

## Compila os arquivos e junta os resultados:
## `{errors: Array[String], warnings: Array[String], files: int, events: int}`.
static func check(paths: Array[String], index: ContentIndex) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var events: int = 0
	for path: String in paths:
		var r: Dictionary = compile_file(path, index)
		errors.append_array(r["errors"] as Array[String])
		warnings.append_array(r["warnings"] as Array[String])
		events += (r["events"] as Dictionary).size()
	return {"errors": errors, "warnings": warnings, "files": paths.size(), "events": events}

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

## Simula um evento (M17) a partir de um pedido em dados simples (o que o painel manda ao processo filho):
## `{text, source, event, setup}` -> `{ok, errors: Array[String], result: Dictionary}`. Compila `text` com o conteúdo de
## `res://data`; com erro de compilação não simula. `setup` é o do `EventSimulator.simulate` (sem `index`).
static func simulate_job(job: Dictionary) -> Dictionary:
	var index: ContentIndex = scan_content()
	var compiled: Dictionary = compile_text(str(job.get("text", "")), str(job.get("source", "roteiro")), index)
	var errors: Array[String] = []
	errors.assign(compiled["errors"])
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "result": {}}
	var script: EventScript = (compiled["events"] as Dictionary).get(StringName(str(job.get("event", "")))) as EventScript
	if script == null:
		errors.append("o evento '%s' não existe" % str(job.get("event", "")))
		return {"ok": false, "errors": errors, "result": {}}
	var setup: Dictionary = (job.get("setup", {}) as Dictionary).duplicate()
	setup["index"] = index
	return {"ok": true, "errors": errors, "result": EventSimulator.simulate(script, setup)}

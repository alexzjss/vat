class_name SpeakerRegistry
extends RefCounted

## Todos os [SpeakerDef] do projeto (M16), achados em `res://data` e `res://art` na primeira consulta e guardados.
## Um `.tres` de texto só é carregado se o cabeçalho diz `SpeakerDef`; num jogo exportado os recursos já vêm
## compilados (`.tres.remap`) e aí cada um é carregado e testado pelo tipo. A resolução em si é do [SpeakerResolver].

const ROOTS: Array[String] = ["res://data", "res://art"]
const SKIP_DIRS: Array[String] = [".godot", "addons", ".git"]

static var _cache: Array[SpeakerDef] = []
static var _scanned: bool = false

static func speakers() -> Array[SpeakerDef]:
	if not _scanned:
		_scanned = true
		for root: String in ROOTS:
			_scan(root)
	return _cache

## Esquece o resultado guardado (testes e recarga de conteúdo).
static func reset() -> void:
	_cache = []
	_scanned = false

static func _scan(dir: String) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for f: String in files:
		var path: String = dir.path_join(f)
		if path.ends_with(".remap"):
			path = path.trim_suffix(".remap")
		elif not f.ends_with(".tres"):
			continue
		if path.ends_with(".tres") and _is_speaker(path):
			var res: SpeakerDef = load(path) as SpeakerDef
			if res != null and not _cache.has(res):
				_cache.append(res)
	var dirs: PackedStringArray = DirAccess.get_directories_at(dir)
	dirs.sort()
	for d: String in dirs:
		if not SKIP_DIRS.has(d):
			_scan(dir.path_join(d))

static func _is_speaker(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		# Exportado: sem texto para olhar; carrega e vê pelo tipo.
		return load(path) is SpeakerDef
	return f.get_line().contains("script_class=\"SpeakerDef\"")

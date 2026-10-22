class_name BestiaryPage
extends LorePage

## Bestiario (M15): um inimigo por linha (nome, ou "???" se nunca visto) e, ao lado, o detalhe de
## BestiaryText.entry_lines (4 linhas se visto, 9 se revelado). Cabecalho "Vistos N/M".
## Fonte da lista: os inimigos de `ENEMY_DIR` (a fatia) mais qualquer inimigo ja no bestiario do estado
## (resolvido varrendo `res://data`). Nao existe registro global de inimigos; `set_defs` injeta a lista (testes).

const ENEMY_DIR: String = "res://data/fatia/enemies"
const DATA_ROOT: String = "res://data"

static var _slice_cache: Array[EnemyDef] = []
static var _slice_loaded: bool = false

var _defs: Array[EnemyDef] = []
var _injected: bool = false

## Substitui a fonte automatica por uma lista fixa (testes).
func set_defs(defs: Array[EnemyDef]) -> void:
	_defs = defs
	_injected = true

func enter() -> void:
	super.enter()
	if not _injected:
		_defs = defs_for(state)
	_refresh()

func detail_for(i: int) -> String:
	if i < 0 or i >= _defs.size() or state == null:
		return ""
	var d: EnemyDef = _defs[i]
	return "\n".join(BestiaryText.entry_lines(d, state.bestiary_entry(d.id), state.bestiary_revealed(d.id), state.cfg))

func _refresh() -> void:
	var rows: Array[String] = []
	var seen: int = 0
	for d: EnemyDef in _defs:
		var is_seen: bool = bool(state.bestiary_entry(d.id)["seen"])
		seen += 1 if is_seen else 0
		rows.append(d.display_name if is_seen else BestiaryText.UNKNOWN)
	_set_rows(rows, "Vistos %d/%d" % [seen, _defs.size()])

## Inimigos da fatia (ordenados por id) + os ids do bestiario que estao fora dela.
static func defs_for(s: GameState) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = slice_enemies().duplicate()
	var have: Dictionary = {}
	for d: EnemyDef in out:
		have[d.id] = true
	var missing: Array[StringName] = []
	for id: StringName in s.bestiary:
		if not have.has(id):
			missing.append(id)
	if not missing.is_empty():
		for d: EnemyDef in _scan(DATA_ROOT):
			if missing.has(d.id) and not have.has(d.id):
				have[d.id] = true
				out.append(d)
	return out

static func slice_enemies() -> Array[EnemyDef]:
	if not _slice_loaded:
		_slice_cache = _scan(ENEMY_DIR)
		_slice_loaded = true
	return _slice_cache

static func _scan(root: String) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	var files: PackedStringArray = DirAccess.get_files_at(root)
	files.sort()
	for f: String in files:
		var name: String = f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var d: EnemyDef = load(root.path_join(name)) as EnemyDef
			if d != null:
				out.append(d)
	var dirs: PackedStringArray = DirAccess.get_directories_at(root)
	dirs.sort()
	for sub: String in dirs:
		out.append_array(_scan(root.path_join(sub)))
	return out

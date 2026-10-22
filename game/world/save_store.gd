class_name SaveStore
extends RefCounted

## Save em disco: 3 slots JSON (`save_<n>.json`) num diretorio configuravel. Fora de `core/` (faz IO).
## Formato: {"version": 1, "summary": {...}, "state": GameState.to_dict()}.

const VERSION: int = 1
const SLOTS: int = 3
const DATA_ROOT: String = "res://data/"

enum Status { EMPTY, OK, CORRUPT }

var dir: String
var registry: DefRegistry
var cfg: BalanceConfig

func _init(p_dir: String, p_registry: DefRegistry, p_cfg: BalanceConfig) -> void:
	dir = p_dir
	registry = p_registry
	cfg = p_cfg

## Varre `root` (recursivo) atras de CharacterDef, ItemDef e EquipmentDef.
static func build_registry(root: String = DATA_ROOT) -> DefRegistry:
	var chars: Array[CharacterDef] = []
	var items: Array[ItemDef] = []
	var equips: Array[EquipmentDef] = []
	for path: String in _tres_files(root):
		var res: Resource = load(path)
		if res is CharacterDef:
			chars.append(res)
		elif res is ItemDef:
			items.append(res)
		elif res is EquipmentDef:
			equips.append(res)
	return DefRegistry.create(chars, items, equips)

static func _tres_files(root: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(root):
		var name: String = f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			out.append(root.path_join(name))
	for sub: String in DirAccess.get_directories_at(root):
		out.append_array(_tres_files(root.path_join(sub)))
	return out

func slot_path(slot: int) -> String:
	return dir.path_join("save_%d.json" % slot)

func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOTS

## Grava o estado no slot (1..3). False em slot invalido ou falha de escrita.
func write(slot: int, state: GameState) -> bool:
	if not is_valid_slot(slot):
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	var leader: HeroState = state.leader()
	var doc: Dictionary = {
		"version": VERSION,
		"summary": {
			"leader": leader.def.display_name, "level": leader.level,
			"play_time": state.play_time, "map": String(state.save_map),
		},
		"state": state.to_dict(),
	}
	f.store_string(JSON.stringify(doc))
	f.close()
	return true

## Estado carregado do slot; null se vazio, corrompido, de outra versao ou com id desconhecido.
func read(slot: int, dice: Dice) -> GameState:
	var doc: Dictionary = _parse(slot)
	if doc.is_empty():
		return null
	return GameState.from_dict(doc["state"], registry, cfg, dice)

## Muda só a flag `id` no estado já gravado no slot (posição, derrotados, moeda e grupo ficam como estavam). False se o slot
## estiver vazio/inválido (nada é gravado) ou se a escrita falhar.
func set_flag(slot: int, id: StringName, value: int) -> bool:
	var doc: Dictionary = _parse(slot)
	if doc.is_empty():
		return false
	var st: Dictionary = doc["state"]
	var fl: Dictionary = st.get("flags", {}) if st.get("flags") is Dictionary else {}
	fl[String(id)] = value
	st["flags"] = fl
	var f: FileAccess = FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(doc))
	f.close()
	return true

## Há um slot válido (JSON legível, versão certa) em `slot`?
func has_slot(slot: int) -> bool:
	return not _parse(slot).is_empty()

## {"status": Status, e quando OK: "leader", "level", "play_time", "map"}.
func summary(slot: int) -> Dictionary:
	if not is_valid_slot(slot) or not FileAccess.file_exists(slot_path(slot)):
		return {"status": Status.EMPTY}
	var doc: Dictionary = _parse(slot)
	if doc.is_empty() or GameState.from_dict(doc["state"], registry, cfg, null) == null:
		return {"status": Status.CORRUPT}
	var s: Dictionary = doc["summary"]
	return {
		"status": Status.OK, "leader": str(s.get("leader", "")), "level": int(s.get("level", 1)),
		"play_time": float(s.get("play_time", 0.0)), "map": str(s.get("map", "")),
	}

func has_any_valid() -> bool:
	for slot: int in range(1, SLOTS + 1):
		if summary(slot)["status"] == Status.OK:
			return true
	return false

## Documento validado (JSON, versao, chaves) ou {} se ausente/invalido.
func _parse(slot: int) -> Dictionary:
	if not is_valid_slot(slot) or not FileAccess.file_exists(slot_path(slot)):
		return {}
	var text: String = FileAccess.get_file_as_string(slot_path(slot))
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var doc: Dictionary = json.data
	var v: Variant = doc.get("version")
	if not (v is float or v is int) or int(v) != VERSION:
		return {}
	if not doc.get("state") is Dictionary or not doc.get("summary") is Dictionary:
		return {}
	return doc

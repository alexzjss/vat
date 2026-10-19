extends GutTest

## Save em disco. Sempre num diretorio temporario (nunca os slots reais), limpo no after_each.

const TMP: String = "user://test_saves/"

var _store: SaveStore
var _reg: DefRegistry
var _cfg: BalanceConfig

func before_each() -> void:
	_cfg = load("res://data/test/balance.tres")
	_reg = SaveStore.build_registry()
	_store = SaveStore.new(TMP, _reg, _cfg)

func after_each() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _game() -> GameState:
	var chars: Array[CharacterDef] = []
	for n: String in ["a", "b"]:
		chars.append(load("res://data/test/heroes/teste_%s.tres" % n))
	var items: Array[ItemDef] = [load("res://data/test/items/pocao.tres")]
	var equips: Array[EquipmentDef] = [load("res://data/test/equipment/lamina_aco.tres")]
	var g: GameState = GameState.new_game(_cfg, chars, items, [4] as Array[int], ScriptedDice.new(), &"local", &"rest", 4, equips, [1] as Array[int])
	g.heroes[0].level = 3
	g.heroes[0].hp = 5
	g.play_time = 75.0
	return g

func _write_raw(slot: int, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var f: FileAccess = FileAccess.open(_store.slot_path(slot), FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_registry_resolves_real_data() -> void:
	assert_not_null(_reg.character(&"teste_a"))
	assert_not_null(_reg.item(&"pocao"))
	assert_not_null(_reg.equipment(&"lamina_aco"))
	assert_null(_reg.character(&"ghost"))

func test_write_and_read_round_trip() -> void:
	var g: GameState = _game()
	assert_true(_store.write(2, g))
	var r: GameState = _store.read(2, ScriptedDice.new())
	assert_not_null(r)
	assert_eq(r.heroes[0].to_dict(), g.heroes[0].to_dict())
	assert_eq(r.inventory.available(&"pocao"), 4)
	assert_eq(r.bag.count(&"lamina_aco"), 1)
	assert_eq(r.play_time, 75.0)

func test_empty_slot_summary_and_read() -> void:
	assert_eq(_store.summary(1)["status"], SaveStore.Status.EMPTY)
	assert_null(_store.read(1, null))
	assert_false(_store.has_any_valid())

func test_summary_of_valid_slot() -> void:
	var g: GameState = _game()
	_store.write(3, g)
	var s: Dictionary = _store.summary(3)
	assert_eq(s["status"], SaveStore.Status.OK)
	assert_eq(s["leader"], g.leader().def.display_name)
	assert_eq(s["level"], 3)
	assert_eq(s["play_time"], 75.0)
	assert_eq(s["map"], "local")
	assert_true(_store.has_any_valid())

func test_invalid_json_is_corrupt() -> void:
	_write_raw(1, "{ isto nao e json")
	assert_eq(_store.summary(1)["status"], SaveStore.Status.CORRUPT)
	assert_null(_store.read(1, null))
	assert_false(_store.has_any_valid())

func test_other_version_is_corrupt() -> void:
	_store.write(1, _game())
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_store.slot_path(1)))
	d["version"] = 2
	_write_raw(1, JSON.stringify(d))
	assert_eq(_store.summary(1)["status"], SaveStore.Status.CORRUPT)
	assert_null(_store.read(1, null))

func test_unknown_id_in_file_is_corrupt() -> void:
	_store.write(1, _game())
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_store.slot_path(1)))
	d["state"]["heroes"][0]["id"] = "ghost"
	_write_raw(1, JSON.stringify(d))
	assert_eq(_store.summary(1)["status"], SaveStore.Status.CORRUPT)
	assert_null(_store.read(1, null))

func test_invalid_slot_numbers_are_rejected() -> void:
	assert_false(_store.write(0, _game()))
	assert_false(_store.write(4, _game()))
	assert_eq(_store.summary(4)["status"], SaveStore.Status.EMPTY)
	assert_null(_store.read(0, null))

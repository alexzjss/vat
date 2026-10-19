extends GutTest

## Ida e volta de GameState/HeroState/Inventory/EquipmentBag por dicionario (sem disco).

var _sword: EquipmentDef
var _vest: EquipmentDef
var _spare: EquipmentDef
var _potion: ItemDef
var _ether: ItemDef
var _reg: DefRegistry

func _eq(id: StringName, slot: StringName) -> EquipmentDef:
	var e := EquipmentDef.new()
	e.id = id
	e.display_name = String(id)
	e.slot = slot
	e.modifiers = Stats.make(1, 0, 0, 0)
	return e

func _def(id: StringName, start: Array[EquipmentDef] = []) -> CharacterDef:
	var d: CharacterDef = Fixtures.hero_def(id, Stats.make(1, 1, 5, 2))
	d.weapon_types = [&"blade"] as Array[StringName]
	d.starting_equipment = start
	return d

func _item(id: StringName) -> ItemDef:
	var it := ItemDef.new()
	it.id = id
	return it

func _chars() -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for id: StringName in [&"a", &"b", &"c", &"d", &"e"]:
		var start: Array[EquipmentDef] = []
		if id == &"a":
			start = [_sword, _vest] as Array[EquipmentDef]
		out.append(_def(id, start))
	return out

func before_each() -> void:
	_sword = _eq(&"sword", &"weapon")
	_sword.weapon_type = &"blade"
	_vest = _eq(&"vest", &"armor")
	_spare = _eq(&"spare", &"armor")
	_potion = _item(&"potion")
	_ether = _item(&"ether")
	_reg = DefRegistry.create(_chars(), [_potion, _ether] as Array[ItemDef], [_sword, _vest, _spare] as Array[EquipmentDef])

func _game() -> GameState:
	var g: GameState = GameState.new_game(Fixtures.cfg(), _chars(), [_potion, _ether] as Array[ItemDef], [3, 1] as Array[int], ScriptedDice.new(), &"overworld", &"start", 4, [_spare] as Array[EquipmentDef], [2] as Array[int])
	g.heroes[0].level = 4
	g.heroes[0].xp = 321
	g.heroes[0].pending_points = 2
	g.heroes[0].allocated = Stats.make(1, 2, 3, 4)
	g.heroes[0].hp = 7
	g.heroes[0].ap = 1
	g.heroes[1].hp = 0
	g.play_time = 123.5
	g.save_map = &"local"
	g.save_spawn = &"rest"
	return g

func _round_trip(g: GameState) -> GameState:
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	return GameState.from_dict(d, _reg, g.cfg, ScriptedDice.new())

func test_full_round_trip() -> void:
	var g: GameState = _game()
	var r: GameState = _round_trip(g)
	assert_not_null(r)
	assert_eq(r.heroes.size(), 4)
	assert_eq(r.reserve.size(), 1)
	assert_eq(r.reserve[0].def.id, &"e")
	for i: int in g.heroes.size():
		assert_eq(r.heroes[i].to_dict(), g.heroes[i].to_dict(), "heroi %d" % i)
	assert_eq(r.heroes[0].equipment[&"weapon"], _sword)
	assert_eq(r.heroes[0].equipment[&"armor"], _vest)
	assert_eq(r.heroes[0].allocated.aura, 4)
	assert_eq(r.heroes[0].level, 4)
	assert_eq(r.heroes[1].hp, 0)
	assert_eq(r.inventory.available(&"potion"), 3)
	assert_eq(r.bag.count(&"spare"), 2)
	assert_eq(r.play_time, 123.5)
	assert_eq([r.save_map, r.save_spawn], [&"local", &"rest"])

func test_reserved_items_are_not_saved() -> void:
	var g: GameState = _game()
	assert_true(g.inventory.reserve(&"potion"))
	assert_eq(g.inventory.available(&"potion"), 2)
	var r: GameState = _round_trip(g)
	assert_eq(r.inventory.available(&"potion"), 3, "reserva zerada, contagem intacta")

func test_loaded_state_has_save_point_and_settings_are_not_saved() -> void:
	var g: GameState = _game()
	g.settings.battle_speed = 5
	assert_false(g.to_dict().has("settings"))
	var r: GameState = _round_trip(g)
	assert_not_null(r.settings)
	assert_ne(r.settings.battle_speed, 5, "settings voltam ao padrao")
	r.heroes[0].hp = 1
	r.restore_save()
	assert_eq(r.heroes[0].hp, 7, "save em memoria = estado carregado")

func test_unknown_hero_id_returns_null() -> void:
	var d: Dictionary = _game().to_dict()
	d["heroes"][0]["id"] = "ghost"
	assert_null(GameState.from_dict(d, _reg, Fixtures.cfg(), null))

func test_unknown_item_and_equipment_ids_return_null() -> void:
	var d: Dictionary = _game().to_dict()
	d["inventory"]["counts"]["bomb"] = 1
	assert_null(GameState.from_dict(d, _reg, Fixtures.cfg(), null))
	var d2: Dictionary = _game().to_dict()
	d2["bag"]["counts"]["ghost"] = 1
	assert_null(GameState.from_dict(d2, _reg, Fixtures.cfg(), null))
	var d3: Dictionary = _game().to_dict()
	d3["heroes"][0]["equipment"]["armor"] = "ghost"
	assert_null(GameState.from_dict(d3, _reg, Fixtures.cfg(), null))

func test_malformed_dictionaries_return_null() -> void:
	assert_null(GameState.from_dict({}, _reg, Fixtures.cfg(), null))
	var d: Dictionary = _game().to_dict()
	d["heroes"] = []
	assert_null(GameState.from_dict(d, _reg, Fixtures.cfg(), null), "sem ativos")
	var d2: Dictionary = _game().to_dict()
	d2["heroes"][0].erase("hp")
	assert_null(GameState.from_dict(d2, _reg, Fixtures.cfg(), null))

func test_save_pos_round_trip_and_optional() -> void:
	var g: GameState = _game()
	assert_false(_round_trip(g).has_save_pos(), "sem posição por padrão")
	g.save(&"overworld", &"Start", Vector2(12.5, 40.0))
	var r: GameState = _round_trip(g)
	assert_true(r.has_save_pos())
	assert_eq(r.save_pos, Vector2(12.5, 40.0))

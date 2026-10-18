class_name GameState
extends RefCounted

var cfg: BalanceConfig
var heroes: Array[HeroState] = []
var inventory: Inventory
var dice: Dice
var save_map: StringName
var save_spawn: StringName
var _saved_heroes: Array[Dictionary] = []
var _saved_inventory: Inventory

static func new_game(cfg: BalanceConfig, defs: Array[CharacterDef], items: Array[ItemDef], counts: Array[int], dice: Dice, map: StringName, spawn: StringName) -> GameState:
	var g := GameState.new()
	g.cfg = cfg
	g.dice = dice
	g.inventory = Inventory.new()
	for d: CharacterDef in defs:
		g.heroes.append(HeroState.create(d, cfg))
	for i: int in items.size():
		g.inventory.add(items[i], counts[i])
	g.save(map, spawn)
	return g

## Grava o ponto de salvamento: valores dos heróis e cópia do inventário.
func save(map: StringName, spawn: StringName) -> void:
	save_map = map
	save_spawn = spawn
	_saved_heroes = []
	for h: HeroState in heroes:
		_saved_heroes.append(h.snapshot())
	_saved_inventory = inventory.copy()

## Volta ao salvamento: os mesmos objetos HeroState, só os valores mudam; inventário é cópia nova.
func restore_save() -> void:
	for i: int in heroes.size():
		heroes[i].restore(_saved_heroes[i])
	inventory = _saved_inventory.copy()

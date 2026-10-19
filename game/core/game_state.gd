class_name GameState
extends RefCounted

var cfg: BalanceConfig
const MAX_ACTIVE: int = 4

var heroes: Array[HeroState] = []
var reserve: Array[HeroState] = []
var inventory: Inventory
var bag: EquipmentBag
var dice: Dice
## Configurações do jogador (menu Config); fora do save. Quem hospeda carrega/persiste.
var settings: GameSettings
var save_map: StringName
var save_spawn: StringName
var _saved_heroes: Array[Dictionary] = []
var _saved_active_ids: Array[StringName] = []
var _saved_reserve_ids: Array[StringName] = []
var _saved_inventory: Inventory
var _saved_bag: EquipmentBag

static func new_game(cfg: BalanceConfig, defs: Array[CharacterDef], items: Array[ItemDef], counts: Array[int], dice: Dice, map: StringName, spawn: StringName, max_active: int = MAX_ACTIVE, bag_items: Array[EquipmentDef] = [], bag_counts: Array[int] = []) -> GameState:
	var g := GameState.new()
	g.cfg = cfg
	g.dice = dice
	g.settings = GameSettings.new(cfg)
	g.inventory = Inventory.new()
	g.bag = EquipmentBag.new()
	for i: int in defs.size():
		var h := HeroState.create(defs[i], cfg)
		if i < max_active:
			g.heroes.append(h)
		else:
			g.reserve.append(h)
	for i: int in items.size():
		g.inventory.add(items[i], counts[i])
	for i: int in bag_items.size():
		g.bag.add(bag_items[i], bag_counts[i])
	g.save(map, spawn)
	return g

## Roster inteiro: ativos na ordem, depois reserva.
func roster() -> Array[HeroState]:
	var out: Array[HeroState] = []
	out.append_array(heroes)
	out.append_array(reserve)
	return out

## Primeiro ativo em pé; se todos caídos, o primeiro ativo.
func leader() -> HeroState:
	for h: HeroState in heroes:
		if h.hp > 0:
			return h
	return heroes[0]

## Troca as posições de dois heróis do roster (qualquer combinação de ativo/reserva).
func swap(a: HeroState, b: HeroState) -> bool:
	var la: Array[HeroState] = _list_of(a)
	var lb: Array[HeroState] = _list_of(b)
	if la.is_empty() or lb.is_empty():
		return false
	var ia: int = la.find(a)
	var ib: int = lb.find(b)
	la[ia] = b
	lb[ib] = a
	return true

func to_reserve(h: HeroState) -> bool:
	if not heroes.has(h) or heroes.size() <= 1:
		return false
	heroes.erase(h)
	reserve.append(h)
	return true

func to_active(h: HeroState) -> bool:
	if not reserve.has(h) or heroes.size() >= MAX_ACTIVE:
		return false
	reserve.erase(h)
	heroes.append(h)
	return true

## Equipa `e` em `slot` vindo da mochila; o item antigo volta para ela. HP/AP atuais são limitados ao novo máximo.
func equip(h: HeroState, slot: StringName, e: EquipmentDef) -> bool:
	if e == null or not roster().has(h) or not EquipmentRules.can_equip(h.def, e, slot) or bag.count(e.id) == 0:
		return false
	var taken: EquipmentDef = bag.take(e.id)
	var old: EquipmentDef = h.equipment.get(slot)
	if old != null:
		bag.put(old)
	h.equipment[slot] = taken
	h.clamp_to_max(cfg)
	return true

## Devolve o item de `slot` à mochila; false se vazio ou herói fora do roster.
func unequip(h: HeroState, slot: StringName) -> bool:
	if not roster().has(h) or not h.equipment.has(slot):
		return false
	bag.put(h.equipment[slot])
	h.equipment.erase(slot)
	h.clamp_to_max(cfg)
	return true

func _list_of(h: HeroState) -> Array[HeroState]:
	if heroes.has(h):
		return heroes
	if reserve.has(h):
		return reserve
	return []

## Grava o ponto de salvamento: valores e formação dos heróis e cópia do inventário.
func save(map: StringName, spawn: StringName) -> void:
	save_map = map
	save_spawn = spawn
	_saved_heroes = []
	_saved_active_ids = []
	_saved_reserve_ids = []
	for h: HeroState in heroes:
		_saved_heroes.append(h.snapshot())
		_saved_active_ids.append(h.def.id)
	for h: HeroState in reserve:
		_saved_heroes.append(h.snapshot())
		_saved_reserve_ids.append(h.def.id)
	_saved_inventory = inventory.copy()
	_saved_bag = bag.copy()

## Volta ao salvamento: os mesmos objetos HeroState, só listas e valores mudam; inventário é cópia nova.
func restore_save() -> void:
	var by_id: Dictionary = {}
	var all: Array[HeroState] = roster()
	for h: HeroState in all:
		by_id[h.def.id] = h
	heroes = []
	reserve = []
	for id: StringName in _saved_active_ids:
		heroes.append(by_id[id] as HeroState)
	for id: StringName in _saved_reserve_ids:
		reserve.append(by_id[id] as HeroState)
	var saved: Array[HeroState] = roster()
	for i: int in saved.size():
		saved[i].restore(_saved_heroes[i])
	inventory = _saved_inventory.copy()
	bag = _saved_bag.copy()

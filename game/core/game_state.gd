class_name GameState
extends RefCounted

var cfg: BalanceConfig
const MAX_ACTIVE: int = 4
## Sem posição exata gravada no save.
const NO_POS: Vector2 = Vector2.INF
## Item-chave que reinicia os atributos de um herói (usado no ponto de descanso).
const RESET_ITEM_ID: StringName = &"cristal_reinicio"

var heroes: Array[HeroState] = []
var reserve: Array[HeroState] = []
var inventory: Inventory
var bag: EquipmentBag
var dice: Dice
## Configurações do jogador (menu Config); fora do save. Quem hospeda carrega/persiste.
var settings: GameSettings
## Segundos jogados (soma feita por quem hospeda o jogo).
var play_time: float = 0.0
var save_map: StringName
var save_spawn: StringName
## Posição exata do jogador no mapa-múndi ao salvar (NO_POS = usar só o marcador `save_spawn`).
var save_pos: Vector2 = NO_POS
## Ids de encontros únicos (chefes) já vencidos; o mapa não os instancia de novo.
var defeated: Array[StringName] = []
## Flags de evento (M10): bool = 0/1, ou contador. Vão no save.
var flags: Dictionary[StringName, int] = {}
## Moeda do grupo (M12). Vai no save como campo opcional; o nome exibido é BalanceConfig.currency_name.
var money: int = 0
var _saved_money: int = 0
var _saved_defeated: Array[StringName] = []
var _saved_flags: Dictionary[StringName, int] = {}
var _saved_heroes: Array[Dictionary] = []
var _saved_active_ids: Array[StringName] = []
var _saved_reserve_ids: Array[StringName] = []
var _saved_inventory: Inventory
var _saved_bag: EquipmentBag

static func new_game(cfg: BalanceConfig, defs: Array[CharacterDef], items: Array[ItemDef], counts: Array[int], dice: Dice, map: StringName, spawn: StringName, max_active: int = MAX_ACTIVE, bag_items: Array[EquipmentDef] = [], bag_counts: Array[int] = [], start_money: int = 0) -> GameState:
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
	g.money = maxi(0, start_money)
	g.save(map, spawn)
	return g

func add_money(n: int) -> void:
	if n > 0:
		money += n

## Gasta `n` de moeda; false, sem mudar nada, se não houver o bastante (ou n negativo).
func spend_money(n: int) -> bool:
	if n < 0 or money < n:
		return false
	money -= n
	return true

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

## Descanso: HP e AP cheios (e reanima) em todo o roster, inclusive a reserva.
func rest_all() -> void:
	for h: HeroState in roster():
		h.rest(cfg)

## Gasta 1 Cristal de Reinício e devolve a alocação de `h` aos pontos pendentes. False sem cristal ou sem nada a reiniciar.
func reset_attributes(h: HeroState) -> bool:
	if h.allocated_total() <= 0 or not inventory.reserve(RESET_ITEM_ID):
		return false
	inventory.commit(RESET_ITEM_ID)
	h.reset_allocation(cfg)
	return true

## Estado completo para o save em disco. `settings` fica de fora (valem para todos os slots).
func to_dict() -> Dictionary:
	var hs: Array = []
	for h: HeroState in heroes:
		hs.append(h.to_dict())
	var rs: Array = []
	for h: HeroState in reserve:
		rs.append(h.to_dict())
	var out: Dictionary = {
		"heroes": hs, "reserve": rs, "inventory": inventory.to_dict(), "bag": bag.to_dict(),
		"save_map": String(save_map), "save_spawn": String(save_spawn), "play_time": play_time,
	}
	if money > 0:
		out["money"] = money
	if has_save_pos():
		out["save_pos"] = [save_pos.x, save_pos.y]
	if not defeated.is_empty():
		var ids: Array = []
		for id: StringName in defeated:
			ids.append(String(id))
		out["defeated"] = ids
	if not flags.is_empty():
		var fl: Dictionary = {}
		for k: StringName in flags:
			fl[String(k)] = flags[k]
		out["flags"] = fl
	return out

## Reconstroi o estado e grava o ponto de salvamento em memoria. Null se o formato for invalido
## ou algum id for desconhecido (o slot e tratado como corrompido).
static func from_dict(d: Dictionary, registry: DefRegistry, p_cfg: BalanceConfig, p_dice: Dice) -> GameState:
	var g := GameState.new()
	g.cfg = p_cfg
	g.dice = p_dice
	g.settings = GameSettings.new(p_cfg)
	if not _load_heroes(d.get("heroes"), registry, g.heroes) or not _load_heroes(d.get("reserve"), registry, g.reserve):
		return null
	if g.heroes.is_empty() or g.heroes.size() > MAX_ACTIVE:
		return null
	var inv: Variant = d.get("inventory")
	var bg: Variant = d.get("bag")
	var pt: Variant = d.get("play_time")
	if not inv is Dictionary or not bg is Dictionary or not (pt is float or pt is int):
		return null
	g.inventory = Inventory.from_dict(inv, registry)
	g.bag = EquipmentBag.from_dict(bg, registry)
	if g.inventory == null or g.bag == null:
		return null
	g.play_time = float(pt)
	var pos: Vector2 = NO_POS
	var sp: Variant = d.get("save_pos")
	if sp is Array and (sp as Array).size() == 2:
		var a: Array = sp
		if (a[0] is float or a[0] is int) and (a[1] is float or a[1] is int):
			pos = Vector2(float(a[0]), float(a[1]))
	var dv: Variant = d.get("defeated")
	if dv is Array:
		for e: Variant in (dv as Array):
			if e is String and not (e as String).is_empty() and not g.is_defeated(StringName(e as String)):
				g.defeated.append(StringName(e as String))
	var fv: Variant = d.get("flags")
	if fv is Dictionary:
		for k: Variant in (fv as Dictionary):
			var val: Variant = (fv as Dictionary)[k]
			if k is String and not (k as String).is_empty() and (val is int or val is float):
				g.flags[StringName(k as String)] = int(val)
	var mv: Variant = d.get("money")
	if mv is int or mv is float:
		g.money = maxi(0, int(mv))
	g.save(StringName(str(d.get("save_map", ""))), StringName(str(d.get("save_spawn", ""))), pos)
	return g

static func _load_heroes(src: Variant, registry: DefRegistry, out: Array[HeroState]) -> bool:
	if not src is Array:
		return false
	for e: Variant in (src as Array):
		var h: HeroState = HeroState.from_dict(e, registry) if e is Dictionary else null
		if h == null:
			return false
		out.append(h)
	return true

func is_defeated(id: StringName) -> bool:
	return id != &"" and defeated.has(id)

func mark_defeated(id: StringName) -> void:
	if id != &"" and not defeated.has(id):
		defeated.append(id)

## Valor da flag (0 se nunca gravada).
func get_flag(id: StringName) -> int:
	return flags.get(id, 0)

func set_flag(id: StringName, value: int) -> void:
	if id != &"":
		flags[id] = value

func add_flag(id: StringName, delta: int) -> void:
	if id != &"":
		flags[id] = get_flag(id) + delta

func has_save_pos() -> bool:
	return save_pos != NO_POS

## Grava o ponto de salvamento: valores e formação dos heróis e cópia do inventário.
func save(map: StringName, spawn: StringName, pos: Vector2 = NO_POS) -> void:
	save_map = map
	save_spawn = spawn
	save_pos = pos
	_saved_heroes = []
	_saved_active_ids = []
	_saved_reserve_ids = []
	for h: HeroState in heroes:
		_saved_heroes.append(h.snapshot())
		_saved_active_ids.append(h.def.id)
	for h: HeroState in reserve:
		_saved_heroes.append(h.snapshot())
		_saved_reserve_ids.append(h.def.id)
	_saved_money = money
	_saved_defeated = defeated.duplicate()
	_saved_flags = flags.duplicate()
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
	money = _saved_money
	defeated = _saved_defeated.duplicate()
	flags = _saved_flags.duplicate()
	inventory = _saved_inventory.copy()
	bag = _saved_bag.copy()

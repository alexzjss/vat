class_name ShopRules
extends RefCounted

## Regras de compra e venda (M12), puras. `def` é um ItemDef ou um EquipmentDef.
## Comprar: preço > 0, moeda suficiente e pilha até BalanceConfig.max_stack. Vender rende
## floor(price x sell_ratio); item-chave e valor 0 não vendem, e só o que está na mochila/inventário
## (equipamento vestido fica de fora, porque não está na mochila).

static func price_of(def: Resource) -> int:
	if def is ItemDef:
		return (def as ItemDef).price
	if def is EquipmentDef:
		return (def as EquipmentDef).price
	return 0

static func sell_value(def: Resource, cfg: BalanceConfig) -> int:
	return floori(float(price_of(def)) * cfg.sell_ratio)

static func can_sell(def: Resource, cfg: BalanceConfig) -> bool:
	if def is ItemDef and (def as ItemDef).key_item:
		return false
	return (def is ItemDef or def is EquipmentDef) and sell_value(def, cfg) > 0

## Quantas unidades o grupo possui (inventário ou mochila).
static func owned(state: GameState, def: Resource) -> int:
	if def is ItemDef:
		return state.inventory.count((def as ItemDef).id)
	if def is EquipmentDef:
		return state.bag.count((def as EquipmentDef).id)
	return 0

## Máximo comprável agora: limitado pela moeda e pelo espaço na pilha. 0 se o preço não é positivo.
static func max_buy(state: GameState, def: Resource) -> int:
	var price: int = price_of(def)
	if price <= 0:
		return 0
	return maxi(0, mini(state.money / price, state.cfg.max_stack - owned(state, def)))

## Máximo vendável agora (itens reservados numa batalha não contam).
static func max_sell(state: GameState, def: Resource) -> int:
	if not can_sell(def, state.cfg):
		return 0
	if def is ItemDef:
		return state.inventory.available((def as ItemDef).id)
	return state.bag.count((def as EquipmentDef).id)

## Compra `n` unidades. False, sem mudar nada, se n for inválido ou passar de [method max_buy].
static func buy(state: GameState, def: Resource, n: int) -> bool:
	if n <= 0 or n > max_buy(state, def):
		return false
	if not state.spend_money(price_of(def) * n):
		return false
	if def is ItemDef:
		state.inventory.add(def as ItemDef, n)
	else:
		state.bag.add(def as EquipmentDef, n)
	return true

## Vende `n` unidades. False, sem mudar nada, se n for inválido ou passar de [method max_sell].
static func sell(state: GameState, def: Resource, n: int) -> bool:
	if n <= 0 or n > max_sell(state, def):
		return false
	if def is ItemDef:
		if not state.inventory.remove((def as ItemDef).id, n):
			return false
	else:
		for _i: int in n:
			state.bag.take((def as EquipmentDef).id)
	state.add_money(sell_value(def, state.cfg) * n)
	return true

## Itens/equipamentos da mochila que a loja compraria, na ordem em que a mochila os lista (itens, depois equipamentos).
static func sellable(state: GameState) -> Array[Resource]:
	var out: Array[Resource] = []
	for it: ItemDef in state.inventory.listing():
		if max_sell(state, it) > 0:
			out.append(it)
	for e: EquipmentDef in state.bag.listing():
		if max_sell(state, e) > 0:
			out.append(e)
	return out

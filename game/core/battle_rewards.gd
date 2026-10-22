class_name BattleRewards
extends RefCounted

## Recompensa de uma batalha (M12), pura: moeda e drops dos inimigos derrotados, sorteados pelo Dice.
## Fuga não dá nada. Partes que caem junto com o núcleo contam (estão com HP 0 ao fim da batalha).

var money: int = 0
var items: Array[ItemDef] = []
var item_counts: Array[int] = []
var equipment: Array[EquipmentDef] = []
var equipment_counts: Array[int] = []
## Nomes do que não coube (BalanceConfig.max_stack); preenchido por [method apply].
var overflow: PackedStringArray = PackedStringArray()

## Um sorteio por entrada de drop válida, na ordem dos inimigos e das entradas (determinístico com a semente).
static func roll(enemies: Array[Combatant], dice: Dice, fled: bool = false) -> BattleRewards:
	var r := BattleRewards.new()
	if fled:
		return r
	for e: Combatant in enemies:
		if e.enemy_def == null or not e.is_out():
			continue
		r.money += maxi(0, e.enemy_def.money)
		for d: DropEntry in e.enemy_def.drops:
			if d == null or d.count <= 0 or (d.item == null and d.equipment == null):
				continue
			if dice.roll() >= d.chance:
				continue
			if d.item != null:
				r.add_item(d.item, d.count)
			else:
				r.add_equipment(d.equipment, d.count)
	return r

func add_item(def: ItemDef, n: int) -> void:
	var i: int = items.find(def)
	if i >= 0:
		item_counts[i] += n
	else:
		items.append(def)
		item_counts.append(n)

func add_equipment(def: EquipmentDef, n: int) -> void:
	var i: int = equipment.find(def)
	if i >= 0:
		equipment_counts[i] += n
	else:
		equipment.append(def)
		equipment_counts.append(n)

func is_empty() -> bool:
	return money <= 0 and items.is_empty() and equipment.is_empty() and overflow.is_empty()

## Soma ao estado do jogo: moeda, itens no inventário e equipamentos na mochila. O que passa do limite da pilha se perde:
## as quantidades e as linhas passam a mostrar só o que entrou, e `overflow` guarda os nomes do que sobrou.
func apply(state: GameState) -> void:
	state.add_money(money)
	var kept_items: Array[ItemDef] = []
	var kept_item_counts: Array[int] = []
	for i: int in items.size():
		var got: int = state.grant_item(items[i], item_counts[i])
		if got > 0:
			kept_items.append(items[i])
			kept_item_counts.append(got)
		if got < item_counts[i]:
			overflow.append(items[i].display_name)
	items = kept_items
	item_counts = kept_item_counts
	var kept_eq: Array[EquipmentDef] = []
	var kept_eq_counts: Array[int] = []
	for i: int in equipment.size():
		var got: int = state.grant_equipment(equipment[i], equipment_counts[i])
		if got > 0:
			kept_eq.append(equipment[i])
			kept_eq_counts.append(got)
		if got < equipment_counts[i]:
			overflow.append(equipment[i].display_name)
	equipment = kept_eq
	equipment_counts = kept_eq_counts

## Linhas para a tela de resultado: "+N Moedas" e "Obteve X!" / "Obteve X x2!".
func lines(currency_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	if money > 0:
		out.append("+%d %s" % [money, currency_name])
	for i: int in items.size():
		out.append(_obtained(items[i].display_name, item_counts[i]))
	for i: int in equipment.size():
		out.append(_obtained(equipment[i].display_name, equipment_counts[i]))
	for n: String in overflow:
		out.append(EventRunner.CAPPED_TEXT % n)
	return out

static func _obtained(name: String, n: int) -> String:
	return "Obteve %s x%d!" % [name, n] if n > 1 else "Obteve %s!" % name

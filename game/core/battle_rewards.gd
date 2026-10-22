class_name BattleRewards
extends RefCounted

## Recompensa de uma batalha (M12), pura: moeda e drops dos inimigos derrotados, sorteados pelo Dice.
## Fuga não dá nada. Partes que caem junto com o núcleo contam (estão com HP 0 ao fim da batalha).

var money: int = 0
var items: Array[ItemDef] = []
var item_counts: Array[int] = []
var equipment: Array[EquipmentDef] = []
var equipment_counts: Array[int] = []

## Um sorteio por entrada de drop válida, na ordem dos inimigos e das entradas (determinístico com a semente).
static func roll(enemies: Array[Combatant], dice: Dice, fled: bool = false) -> BattleRewards:
	var r := BattleRewards.new()
	if fled:
		return r
	for e: Combatant in enemies:
		if e.enemy_def == null or not e.is_down():
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
	return money <= 0 and items.is_empty() and equipment.is_empty()

## Soma ao estado do jogo: moeda, itens no inventário e equipamentos na mochila.
func apply(state: GameState) -> void:
	state.add_money(money)
	for i: int in items.size():
		state.inventory.add(items[i], item_counts[i])
	for i: int in equipment.size():
		state.bag.add(equipment[i], equipment_counts[i])

## Linhas para a tela de resultado: "+N Moedas" e "Obteve X!" / "Obteve X x2!".
func lines(currency_name: String) -> PackedStringArray:
	var out := PackedStringArray()
	if money > 0:
		out.append("+%d %s" % [money, currency_name])
	for i: int in items.size():
		out.append(_obtained(items[i].display_name, item_counts[i]))
	for i: int in equipment.size():
		out.append(_obtained(equipment[i].display_name, equipment_counts[i]))
	return out

static func _obtained(name: String, n: int) -> String:
	return "Obteve %s x%d!" % [name, n] if n > 1 else "Obteve %s!" % name

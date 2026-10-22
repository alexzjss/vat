class_name Inventory
extends RefCounted

var _counts: Dictionary[StringName, int] = {}
var _reserved: Dictionary[StringName, int] = {}
var _defs: Dictionary[StringName, ItemDef] = {}

func add(item: ItemDef, n: int) -> void:
	if item == null or n <= 0:
		push_error("Inventory.add invalido")
		return
	if not _defs.has(item.id):
		_defs[item.id] = item
		_counts[item.id] = 0
		_reserved[item.id] = 0
	_counts[item.id] += n

func available(id: StringName) -> int:
	return _counts.get(id, 0) - _reserved.get(id, 0)

## Total possuído (reservas incluídas).
func count(id: StringName) -> int:
	return _counts.get(id, 0)

## Tira `n` unidades livres (loja); false, sem mudar nada, se não houver tantas.
func remove(id: StringName, n: int) -> bool:
	if n <= 0 or available(id) < n:
		return false
	_counts[id] -= n
	return true

func reserve(id: StringName) -> bool:
	if available(id) <= 0:
		return false
	_reserved[id] += 1
	return true

func release(id: StringName) -> void:
	if _reserved.get(id, 0) > 0:
		_reserved[id] -= 1

func commit(id: StringName) -> void:
	if _reserved.get(id, 0) > 0:
		_reserved[id] -= 1
		_counts[id] -= 1

## Devolve uma unidade já consumida (ação perdida por falta de alvo).
func refund(id: StringName) -> void:
	if _defs.has(id):
		_counts[id] += 1

func listing() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for id: StringName in _defs:
		if _counts[id] > 0:
			out.append(_defs[id])
	return out

## Contagens por id (reservas nao entram no save).
func to_dict() -> Dictionary:
	var counts: Dictionary = {}
	for id: StringName in _defs:
		counts[String(id)] = _counts[id]
	return {"counts": counts}

## Null se algum id for desconhecido ou o formato for invalido.
static func from_dict(d: Dictionary, registry: DefRegistry) -> Inventory:
	var counts: Variant = d.get("counts")
	if not counts is Dictionary:
		return null
	var inv := Inventory.new()
	for key: Variant in (counts as Dictionary):
		var it: ItemDef = registry.item(StringName(str(key)))
		var n: Variant = (counts as Dictionary)[key]
		if it == null or not (n is float or n is int) or int(n) < 0:
			return null
		inv._defs[it.id] = it
		inv._counts[it.id] = int(n)
		inv._reserved[it.id] = 0
	return inv

## Cópia independente: contagens e defs copiadas, reservas zeradas.
func copy() -> Inventory:
	var c := Inventory.new()
	for id: StringName in _defs:
		c._defs[id] = _defs[id]
		c._counts[id] = _counts[id]
		c._reserved[id] = 0
	return c

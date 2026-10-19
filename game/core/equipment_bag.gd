class_name EquipmentBag
extends RefCounted

var _counts: Dictionary[StringName, int] = {}
var _defs: Dictionary[StringName, EquipmentDef] = {}

func add(e: EquipmentDef, n: int = 1) -> void:
	if e == null or n <= 0:
		push_error("EquipmentBag.add invalido")
		return
	if not _defs.has(e.id):
		_defs[e.id] = e
		_counts[e.id] = 0
	_counts[e.id] += n

func count(id: StringName) -> int:
	return _counts.get(id, 0)

## Remove uma unidade; null se não houver.
func take(id: StringName) -> EquipmentDef:
	if count(id) <= 0:
		return null
	_counts[id] -= 1
	return _defs[id]

func put(e: EquipmentDef) -> void:
	add(e, 1)

func listing() -> Array[EquipmentDef]:
	var out: Array[EquipmentDef] = []
	for id: StringName in _defs:
		if _counts[id] > 0:
			out.append(_defs[id])
	return out

func to_dict() -> Dictionary:
	var counts: Dictionary = {}
	for id: StringName in _defs:
		counts[String(id)] = _counts[id]
	return {"counts": counts}

## Null se algum id for desconhecido ou o formato for invalido.
static func from_dict(d: Dictionary, registry: DefRegistry) -> EquipmentBag:
	var counts: Variant = d.get("counts")
	if not counts is Dictionary:
		return null
	var bag := EquipmentBag.new()
	for key: Variant in (counts as Dictionary):
		var e: EquipmentDef = registry.equipment(StringName(str(key)))
		var n: Variant = (counts as Dictionary)[key]
		if e == null or not (n is float or n is int) or int(n) < 0:
			return null
		bag._defs[e.id] = e
		bag._counts[e.id] = int(n)
	return bag

func copy() -> EquipmentBag:
	var b := EquipmentBag.new()
	b._counts = _counts.duplicate()
	b._defs = _defs.duplicate()
	return b

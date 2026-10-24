class_name ContentIndex
extends RefCounted

## Índice puro dos recursos de conteúdo por (tipo, id), para o compilador do roteiro (M16).
## Tipos: `item`, `equip`, `hero`, `encounter`, `ability`. Ids repetidos: vale o primeiro; os demais vão para `duplicates`.
## Sem IO: quem varre as pastas entrega os recursos já carregados (ver RoteiroTools.scan_content).

var _by_kind: Dictionary = {}
var duplicates: Array[String] = []

static func from_resources(resources: Array) -> ContentIndex:
	var ix := ContentIndex.new()
	for r: Variant in resources:
		var res: Resource = r as Resource
		if res != null:
			ix._add(res)
	return ix

## O tipo do roteiro para um recurso, ou "" se não for indexado.
static func kind_of(res: Resource) -> StringName:
	if res is ItemDef:
		return &"item"
	if res is EquipmentDef:
		return &"equip"
	if res is CharacterDef:
		return &"hero"
	if res is EncounterDef:
		return &"encounter"
	if res is AbilityDef:
		return &"ability"
	return &""

func _add(res: Resource) -> void:
	var kind: StringName = kind_of(res)
	if kind == &"":
		return
	var id: StringName = res.get(&"id")
	if id == &"":
		return
	var bucket: Dictionary = _by_kind.get(kind, {})
	if bucket.has(id):
		duplicates.append("%s '%s': %s repete %s" % [kind, id, res.resource_path, (bucket[id] as Resource).resource_path])
	else:
		bucket[id] = res
	_by_kind[kind] = bucket

func resolve(kind: StringName, id: StringName) -> Resource:
	var bucket: Dictionary = _by_kind.get(kind, {})
	return bucket.get(id) as Resource

## Os ids de um tipo, em ordem alfabética (para listas de escolha).
func ids(kind: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in (_by_kind.get(kind, {}) as Dictionary).keys():
		out.append(k as StringName)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out

func count(kind: StringName) -> int:
	return (_by_kind.get(kind, {}) as Dictionary).size()

## O resolver que o RoteiroCompiler.compile espera.
func resolver() -> Callable:
	return resolve

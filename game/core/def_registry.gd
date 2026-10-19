class_name DefRegistry
extends RefCounted

## Resolve id -> definicao (heroi, item, equipamento). Recebe as listas prontas: sem IO.
## Quem varre os arquivos (SaveStore) monta o registro.

var _characters: Dictionary[StringName, CharacterDef] = {}
var _items: Dictionary[StringName, ItemDef] = {}
var _equipment: Dictionary[StringName, EquipmentDef] = {}

static func create(characters: Array[CharacterDef], items: Array[ItemDef], equipment: Array[EquipmentDef]) -> DefRegistry:
	var r := DefRegistry.new()
	for d: CharacterDef in characters:
		r._characters[d.id] = d
	for d: ItemDef in items:
		r._items[d.id] = d
	for d: EquipmentDef in equipment:
		r._equipment[d.id] = d
	return r

## Null quando o id e desconhecido.
func character(id: StringName) -> CharacterDef:
	return _characters.get(id)

func item(id: StringName) -> ItemDef:
	return _items.get(id)

func equipment(id: StringName) -> EquipmentDef:
	return _equipment.get(id)

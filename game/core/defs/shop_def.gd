class_name ShopDef
extends Resource

## Loja (M12): o que vende. Estoque infinito; os preços vêm de ItemDef.price / EquipmentDef.price.
@export var id: StringName
@export var display_name: String = ""
@export var items: Array[ItemDef] = []
@export var equipment: Array[EquipmentDef] = []

class_name EquipmentDef
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var slot: StringName
@export var modifiers: Stats
## Só armas; vazio = qualquer um usa.
@export var weapon_type: StringName = &""
## Só armadura/capacete; vazio = todos usam.
@export var allowed_ids: Array[StringName] = []
@export var passives: Array[EquipmentPassive] = []
## Economia (M12): preço de compra; vender rende floor(price x sell_ratio). 0 = não vendável.
@export var price: int = 0

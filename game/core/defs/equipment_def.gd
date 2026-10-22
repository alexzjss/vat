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
## Elementos (M13). Arma: elemento do ataque basico sem elemento proprio.
@export var element: ElementDef
## Afinidade elemental somada a do heroi: 0.3 = sofre 30% menos, -0.5 = sofre 50% mais, 1.0 = imune, >1 absorve.
@export var element_resist: Dictionary[StringName, float] = {}

class_name ItemDef
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export var shape: AbilityDef.Shape = AbilityDef.Shape.SINGLE
@export var side: AbilityDef.Side = AbilityDef.Side.ALLIES
@export var effects: Array[EffectDef] = []
## Item-chave: não é usável em batalha nem no menu de itens (ex.: Cristal de Reinício, usado no ponto de descanso).
@export var key_item: bool = false

class_name DropEntry
extends Resource

## Um drop possível de um inimigo (M12): `item` ou `equipment` (um dos dois), com `chance` (0..1) de cair e `count` unidades.
@export var item: ItemDef
@export var equipment: EquipmentDef
@export var chance: float = 1.0
@export var count: int = 1

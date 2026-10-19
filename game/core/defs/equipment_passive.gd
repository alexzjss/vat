class_name EquipmentPassive
extends Resource

enum Kind { IMMUNE, RESIST, START_WITH }

@export var kind: Kind = Kind.IMMUNE
@export var status: StatusDef
## Só RESIST: fração 0..1 de chance de resistir.
@export_range(0.0, 1.0) var amount: float = 0.0

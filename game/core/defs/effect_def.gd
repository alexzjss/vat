class_name EffectDef
extends Resource

enum Kind { DAMAGE, HEAL, REVIVE, RESTORE_AP, APPLY_STATUS, REMOVE_STATUS, SCAN }
enum Scale { STRENGTH, AURA, FIXED }

@export var kind: Kind = Kind.DAMAGE
@export var scale: Scale = Scale.STRENGTH
@export var potency: float = 1.0
@export var status: StatusDef
## REMOVE_STATUS: lista de estados removidos (além de `status`). Com `status` nulo e lista vazia, remove todos os negativos.
@export var statuses: Array[StatusDef] = []
@export var chance: float = 1.0
@export var dodgeable: bool = false

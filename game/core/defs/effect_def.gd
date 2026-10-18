class_name EffectDef
extends Resource

enum Kind { DAMAGE, HEAL, REVIVE, RESTORE_AP, APPLY_STATUS, REMOVE_STATUS }
enum Scale { STRENGTH, AURA, FIXED }

@export var kind: Kind = Kind.DAMAGE
@export var scale: Scale = Scale.STRENGTH
@export var potency: float = 1.0
@export var status: StatusDef
@export var chance: float = 1.0
@export var dodgeable: bool = false

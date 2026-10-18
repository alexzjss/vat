class_name StatusDef
extends Resource

enum Kind { POISON, SLEEP, PARALYSIS, HASTE, SLOW, BARRIER, ATTR_MOD }

@export var id: StringName
@export var kind: Kind = Kind.POISON
## Turnos do afetado.
@export var duration: int = 1
## Veneno: dano por turno; Barreira: pontos; HASTE/SLOW: % de taxa; ATTR_MOD: soma no atributo.
@export var potency: int = 0
## Só ATTR_MOD.
@export var attr: StringName
@export var apply_contribution: int = 0
## Ids de status removidos ao aplicar este.
@export var cancels: Array[StringName] = []

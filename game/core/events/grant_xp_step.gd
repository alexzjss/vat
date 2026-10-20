class_name GrantXpStep
extends EventStep

## Quem recebe: ACTIVE = a formação ativa; ALL_RECRUITED = ativos e reserva; LIST = só os ids de `heroes`.
enum Rule { ACTIVE, ALL_RECRUITED, LIST }

@export var amount: int = 0
@export var rule: Rule = Rule.ACTIVE
## Heróis caídos (HP 0) também recebem? false = só quem está em pé.
@export var include_downed: bool = false
@export var heroes: Array[StringName] = []

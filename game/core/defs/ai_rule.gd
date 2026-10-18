class_name AiRule
extends Resource

enum Condition { ALWAYS, ALLY_HP_BELOW }
enum TargetPick { LOWEST_HP_ENEMY, RANDOM_ENEMY, LOWEST_HP_ALLY, SELF }

@export var condition: Condition = Condition.ALWAYS
## Fração do HP máx.
@export var threshold: float = 0.0
@export var ability: AbilityDef
@export var pick: TargetPick = TargetPick.LOWEST_HP_ENEMY

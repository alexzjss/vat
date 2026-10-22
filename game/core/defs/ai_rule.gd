class_name AiRule
extends Resource

## Novos valores sempre no fim (os .tres guardam o índice).
## CAN_REACT (M14): algum alvo vivo da habilidade da regra tem uma marca que reage com o elemento dela.
enum Condition { ALWAYS, ALLY_HP_BELOW, PART_DOWN, CAN_REACT }
## NEAREST/FARTHEST: pela distância ao ator; CLUSTER: o centro que pega mais alvos na área da habilidade (empate: o primeiro).
## REACTION_TARGET (M14): o alvo com marca reagente (empate: menor HP); em area, o centro que pega um alvo reagente.
enum TargetPick { LOWEST_HP_ENEMY, RANDOM_ENEMY, LOWEST_HP_ALLY, SELF, NEAREST, FARTHEST, CLUSTER, REACTION_TARGET }

@export var condition: Condition = Condition.ALWAYS
## Fração do HP máx.
@export var threshold: float = 0.0
@export var ability: AbilityDef
@export var pick: TargetPick = TargetPick.LOWEST_HP_ENEMY
## Chance da regra valer quando as condicoes batem (1 = sempre; < 1 sorteia no Dice). Da variedade a fases de chefe.
@export_range(0.0, 1.0) var chance: float = 1.0
## Ataque anunciado (M11): o ator gasta o turno "preparando" e a ação sai no próximo ATB cheio dele.
@export var telegraph: bool = false

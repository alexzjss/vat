class_name RecruitStep
extends EventStep

## Recruta `hero` (M12): entra nos ativos se houver vaga, senão na reserva. Já recrutado = ignorado.
## PARTY_AVG (padrão): chega no nível médio dos ativos, arredondado para baixo; FIXED: chega em `level`.
## Novos valores sempre no fim (os .tres guardam o índice).
enum LevelMode { PARTY_AVG, FIXED }

@export var hero: CharacterDef
@export var level_mode: LevelMode = LevelMode.PARTY_AVG
## Só com FIXED.
@export var level: int = 1

class_name BossPhase
extends Resource

## Fase de chefe (M11): quando o HP do chefe cai abaixo de `hp_below` (fração do HP máx.), as regras de IA
## passam a ser as desta fase e a batalha mostra `banner`. Fases em ordem decrescente de `hp_below`.

@export var hp_below: float = 0.5
@export var ai_rules: Array[AiRule] = []
@export var banner: String = ""

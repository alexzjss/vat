class_name EnemyDef
extends Resource

## Novos valores sempre no fim (os .tres guardam o índice).
enum Role { NORMAL, CORE, PART }

@export var id: StringName
@export var display_name: String = ""
@export var level: int = 1
@export var base: Stats
@export var xp_base: int = 100
## Economia (M12): moeda e drops por inimigo derrotado.
@export var money: int = 0
@export var drops: Array[DropEntry] = []
@export var abilities: Array[AbilityDef] = []
@export var ai_rules: Array[AiRule] = []
@export var immunities: Array[StringName] = []
## 0..1 = redução da chance.
@export var resistances: Dictionary[StringName, float] = {}
## Chefe (M11): fases por HP (substituem `ai_rules` ao cruzar o limiar), em ordem decrescente de `hp_below`.
@export var phases: Array[BossPhase] = []
## Contra-ataque: usado contra o herói que causou dano de HP, com `counter_chance` de chance.
@export var counter: AbilityDef
@export var counter_chance: float = 0.0
## true: só o ataque básico do herói provoca o contra-ataque.
@export var counter_only_basic: bool = false
## Partes múltiplas: CORE vence a batalha ao cair (as PART caem junto); PART com `shields_core` protege o CORE.
@export var role: Role = Role.NORMAL
@export var shields_core: bool = false
## Elementos nativos (M13), no maximo 2: so dao o bonus de mesmo elemento.
@export var elements: Array[ElementDef] = []
## Afinidade por id de elemento: 0.3 = sofre 30% menos, -0.5 = sofre 50% mais, 1.0 = imune, >1 absorve.
@export var element_resist: Dictionary[StringName, float] = {}

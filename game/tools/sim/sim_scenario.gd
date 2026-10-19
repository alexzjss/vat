class_name SimScenario
extends RefCounted

## Descricao de um cenario de simulacao: grupo, encontro, config e politica.
## Nao usa o nome `seed` (sombra do builtin): a semente da execucao i e base_seed + i.

var label: String = ""
var heroes: Array[CharacterDef] = []
var hero_level: int = 1
## &"even": pontos em rodizio pelos atributos; &"main": tudo no atributo de maior base do heroi.
var alloc_rule: StringName = &"even"
## false: remove o equipamento inicial antes do descanso.
var equipment: bool = true
var enemies: Array[EnemyDef] = []
var cfg: BalanceConfig = BalanceConfig.new()
## &"basic" ou &"smart".
var policy: StringName = &"basic"
var runs: int = 1
var base_seed: int = 1
var items: Array[ItemDef] = []
var item_counts: Array[int] = []

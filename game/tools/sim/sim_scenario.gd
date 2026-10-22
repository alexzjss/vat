class_name SimScenario
extends RefCounted

## Descricao de um cenario de simulacao: grupo, encontro, config e politica.
## Nao usa o nome `seed` (sombra do builtin): a semente da execucao i e base_seed + i.

const BASELINE_ALL_A: String = "tudo A (M5a)"
const BASELINE_CHOSEN: String = "padrao escolhido (balance.tres)"
const BASELINE_CODE: String = "padrao do codigo (BalanceConfig.new)"

var label: String = ""
var heroes: Array[CharacterDef] = []
var hero_level: int = 1
## &"even": pontos em rodizio pelos atributos; &"main": tudo no atributo de maior base do heroi.
var alloc_rule: StringName = &"even"
## false: remove o equipamento inicial antes do descanso.
var equipment: bool = true
var enemies: Array[EnemyDef] = []
var cfg: BalanceConfig = BalanceConfig.new()
## Qual baseline de config este cenario usa (ver config_all_a / config_chosen); aparece nos relatorios.
var baseline: String = BASELINE_CODE
## &"basic" ou &"smart".
var policy: StringName = &"basic"
var runs: int = 1
var base_seed: int = 1
var items: Array[ItemDef] = []
var item_counts: Array[int] = []
## M14: true = a batalha usa uma tabela de reacoes vazia (nada reage), para comparar com a tabela real.
var no_reactions: bool = false

## Baseline M5a: todos os modos na opcao A (reproduz a comparacao do M5a). Coeficientes ficam nos valores do codigo.
static func config_all_a() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.dr_mode = BalanceConfig.DrMode.A
	c.hp_mode = BalanceConfig.HpMode.A
	c.ap_mode = BalanceConfig.ApMode.A
	c.atb_mode = BalanceConfig.AtbMode.A
	c.dodge_mode = BalanceConfig.DodgeMode.A
	c.damage_mode = BalanceConfig.DamageMode.A
	c.variance_mode = BalanceConfig.VarianceMode.A
	c.xp_mode = BalanceConfig.XpMode.A
	c.max_level = 0
	c.revive_mode = BalanceConfig.ReviveMode.A
	c.poison_mode = BalanceConfig.PoisonMode.A
	c.duration_mode = BalanceConfig.DurationMode.A
	return c

## Baseline atual do jogo: as formulas escolhidas, lidas de res://data/test/balance.tres (copia).
static func config_chosen() -> BalanceConfig:
	return (load("res://data/test/balance.tres") as BalanceConfig).duplicate() as BalanceConfig

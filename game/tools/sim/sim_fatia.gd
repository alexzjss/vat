class_name SimFatia
extends RefCounted

## Cenarios e relatorio da fatia vertical (M12, Task 5): lutas comuns e chefe com o grupo e o nivel da fatia
## (herois de teste A-D, alocacao `main`, itens da fatia), mais a rota completa (RouteFatia).
## Nao altera nenhum dado: os numeros que se ajustam vivem em `data/fatia/*.tres`. Valores de teste, nao canonicos.

const HERO_IDS: Array[String] = ["teste_a_f", "teste_b_f", "teste_c_f", "teste_d_f"]
const POLICIES: Array[StringName] = [&"basic", &"smart"]
const BOSS_ENC: String = "chefe_fatia"
## Nivel do grupo no chefe nos cenarios fixos (alvo do plano: Nv ~5; sensibilidade em +-1).
const BOSS_LEVELS: Array[int] = [3, 4, 5, 6]
const BOSS_MAIN_LEVEL: int = 5 # valor de teste (M12: nivel do grupo no chefe da fatia)
## Kit de itens dos cenarios fixos (ids de data/fatia/items): comuns e chefe (valores de teste do simulador).
const KIT: Array[Array] = [["pocao_f", 3], ["eter_f", 2], ["reviver_f", 1]]
const BOSS_KIT: Array[Array] = [["pocao_f", 3], ["eter_f", 2], ["reviver_f", 1], ["remedio_f", 2]]
## Encontros comuns e o nivel do grupo em que aparecem na rota tipica (media do grupo ao chegar, arredondada para baixo):
## a 1a vez de cada encontro e, quando o mesmo encontro volta bem mais tarde, tambem esse nivel.
const COMMON_CASES: Array[Dictionary] = [
	{"enc": "enc_f1", "level": 1}, {"enc": "enc_f2", "level": 1}, {"enc": "enc_f12", "level": 2}, {"enc": "enc_f12", "level": 3},
	{"enc": "enc_f2", "level": 3}, {"enc": "enc_f3", "level": 4}, {"enc": "enc_f4", "level": 4}, {"enc": "enc_f34", "level": 5},
]
## Metas (plano M12, item 17): comuns = metas classicas; chefe = smart 15-20 s e vitoria >= 90%.
const BOSS_DUR_MIN: float = 15.0 # valor de teste (M12)
const BOSS_DUR_MAX: float = 20.0 # valor de teste (M12)
const BOSS_WIN_MIN: float = 0.90 # valor de teste (M12)
const ROUTE_LEVEL_MIN: float = 4.0 # valor de teste (M12: Nv na chegada ao chefe, perfil tipico)
const ROUTE_LEVEL_MAX: float = 6.0

static func make_scenario(enc: String, level: int, policy: StringName, runs: int, label: String) -> SimScenario:
	var s := SimScenario.new()
	s.label = label
	for id: String in HERO_IDS:
		s.heroes.append(load("res://data/fatia/heroes/%s.tres" % id) as CharacterDef)
	s.hero_level = level
	s.alloc_rule = &"main"
	s.equipment = true
	s.enemies = (load("res://data/fatia/encounters/%s.tres" % enc) as EncounterDef).enemies.duplicate()
	s.policy = policy
	s.runs = runs
	s.base_seed = 1
	s.cfg = SimScenario.config_chosen()
	s.baseline = SimScenario.BASELINE_CHOSEN
	var kit: Array[Array] = BOSS_KIT if enc == BOSS_ENC else KIT
	for pair: Array in kit:
		s.items.append(load("res://data/fatia/items/%s.tres" % str(pair[0])) as ItemDef)
		s.item_counts.append(int(pair[1]))
	return s

static func case_label(enc: String, level: int, policy: StringName) -> String:
	return "N%d %s %s" % [level, enc, str(policy)]

## Roda um encontro nos dois tipos de politica; devolve as metricas na ordem de POLICIES.
static func run_case(enc: String, level: int, runs: int) -> Array[SimMetrics]:
	var out: Array[SimMetrics] = []
	for p: StringName in POLICIES:
		out.append(SimRunner.run(make_scenario(enc, level, p, runs, case_label(enc, level, p))))
	return out

## Meta de luta comum (smart: vitoria >= 95% e 10-60 s, pois os encontros da fatia tem 1-2 inimigos; basic: vitoria >= 75%).
static func common_ok(policy: StringName, m: SimMetrics) -> bool:
	if policy == &"smart":
		return m.win_rate() >= 0.95 and m.mean_duration() >= 10.0 and m.mean_duration() <= 60.0
	return m.win_rate() >= 0.75

## Meta do chefe (so smart; basic e apenas relatado).
static func boss_ok(m: SimMetrics) -> bool:
	return m.win_rate() >= BOSS_WIN_MIN and m.mean_duration() >= BOSS_DUR_MIN and m.mean_duration() <= BOSS_DUR_MAX

## Cenario elemental (M13): dois copias de inimigo_f3 (neutras ou fracas aos 4 elementos dos herois A-D), nivel 3,
## nas duas politicas. A `smart` usa a fraqueza; a `basic` ignora elementos (so a arma, que aqui e neutra).
const ELEM_LEVEL: int = 3 # valor de teste (M13)
const ELEM_WEAK: float = -0.5 # valor de teste (M13: fraqueza = +50% de dano)
const ELEM_IDS: Array[StringName] = [&"kagutsuchi", &"susanoo", &"indra", &"amaterasu"]

static func elemental_enemy(weak: bool) -> EnemyDef:
	var e: EnemyDef = (load("res://data/fatia/enemies/inimigo_f3.tres") as EnemyDef).duplicate() as EnemyDef
	# Sem as regras de Sangue e sem natives: so a afinidade muda entre as duas versoes.
	e.elements = []
	e.element_resist = {}
	e.abilities = [load("res://data/test/abilities/golpe.tres") as AbilityDef]
	var rule: AiRule = AiRule.new()
	rule.ability = e.abilities[0]
	e.ai_rules = [rule]
	if weak:
		for id: StringName in ELEM_IDS:
			e.element_resist[id] = ELEM_WEAK
	return e

static func elemental_scenario(policy: StringName, weak: bool, runs: int) -> SimScenario:
	var s: SimScenario = make_scenario("enc_f12", ELEM_LEVEL, policy, runs, "elemental %s %s" % [str(policy), "fraco" if weak else "neutro"])
	s.enemies = [elemental_enemy(weak), elemental_enemy(weak)]
	return s

## Ordem: basic neutro, smart neutro, basic fraco, smart fraco.
static func run_elemental(runs: int) -> Array[SimMetrics]:
	var out: Array[SimMetrics] = []
	for weak: bool in [false, true]:
		for p: StringName in POLICIES:
			out.append(SimRunner.run(elemental_scenario(p, weak, runs)))
	return out

## Cenario de reacoes (M14): o grupo da fatia contra um encontro da fatia, em tres versoes:
## smart com reacoes, smart sem reacoes (tabela vazia) e basic (que ignora marcas; os inimigos reagem normalmente).
const REACTION_CASES: Array[Dictionary] = [{"enc": "enc_f34", "level": 5}, {"enc": "chefe_fatia", "level": 5}]
const REACTION_VARIANTS: Array[String] = ["smart com reacoes", "smart sem reacoes", "basic com reacoes"]

static func reaction_scenario(enc: String, level: int, variant: int, runs: int) -> SimScenario:
	var policy: StringName = &"basic" if variant == 2 else &"smart"
	var s: SimScenario = make_scenario(enc, level, policy, runs, "N%d %s %s" % [level, enc, REACTION_VARIANTS[variant]])
	s.no_reactions = variant == 1
	return s

## Ordem de REACTION_VARIANTS.
static func run_reactions(enc: String, level: int, runs: int) -> Array[SimMetrics]:
	var out: Array[SimMetrics] = []
	for v: int in REACTION_VARIANTS.size():
		out.append(SimRunner.run(reaction_scenario(enc, level, v, runs)))
	return out

## Linha rapida para depuracao (`-fatia -quick`): imprime comuns e chefe sem escrever relatorio.
static func quick(runs: int, route_runs: int) -> void:
	for c: Dictionary in COMMON_CASES:
		var ms: Array[SimMetrics] = run_case(str(c["enc"]), int(c["level"]), runs)
		for i: int in POLICIES.size():
			print("[fatia] N%d %-7s %-5s win %3.0f%% dur %5.1f s hp %3.0f%% %s" % [int(c["level"]), str(c["enc"]), str(POLICIES[i]), ms[i].win_rate() * 100.0,
				ms[i].mean_duration(), ms[i].mean_party_hp_pct() * 100.0, "ok" if common_ok(POLICIES[i], ms[i]) else "FORA"])
	var el: Array[SimMetrics] = run_elemental(runs)
	var el_names: Array[String] = ["basic neutro", "smart neutro", "basic fraco", "smart fraco"]
	for i: int in el.size():
		print("[elemental] N%d %-12s win %3.0f%% dur %5.1f s hp %3.0f%%" % [ELEM_LEVEL, el_names[i], el[i].win_rate() * 100.0, el[i].mean_duration(), el[i].mean_party_hp_pct() * 100.0])
	for rc: Dictionary in REACTION_CASES:
		var rs: Array[SimMetrics] = run_reactions(str(rc["enc"]), int(rc["level"]), runs)
		for i: int in rs.size():
			print("[reacoes] N%d %-11s %-18s win %3.0f%% dur %5.1f s hp %3.0f%%" % [int(rc["level"]), str(rc["enc"]), REACTION_VARIANTS[i], rs[i].win_rate() * 100.0, rs[i].mean_duration(), rs[i].mean_party_hp_pct() * 100.0])
	for lv: int in BOSS_LEVELS:
		var bs: Array[SimMetrics] = run_case(BOSS_ENC, lv, runs)
		for i: int in POLICIES.size():
			print("[fatia] N%d chefe   %-5s win %3.0f%% dur %5.1f s hp %3.0f%%" % [lv, str(POLICIES[i]), bs[i].win_rate() * 100.0, bs[i].mean_duration(), bs[i].mean_party_hp_pct() * 100.0])
	if route_runs > 0:
		for pr: RouteFatia.Profile in [RouteFatia.Profile.MINIMUM, RouteFatia.Profile.TYPICAL, RouteFatia.Profile.FULL]:
			var agg: RouteFatia.Aggregate = RouteFatia.run(pr, route_runs)
			print("[rota] %-8s no chefe %d/%d nivel %.2f (%.1f-%.1f) moeda %.0f lutas %.1f (%.0f s) voltas %.1f chefe %d/%d em %.1f s falhas %s" % [
				RouteFatia.profile_name(pr), agg.reached_boss, agg.runs, agg.mean(agg.avg_levels), agg.min_of(agg.avg_levels), agg.max_of(agg.avg_levels),
				agg.mean(agg.money_at_boss), agg.mean(agg.fights), agg.mean(agg.fight_seconds), agg.mean(agg.rests), agg.boss_wins, agg.reached_boss,
				agg.mean(agg.boss_seconds), str(agg.failures)])
			print("       ganhou %.0f gastou %.0f; lojas: %s" % [agg.mean(agg.money_earned), agg.mean(agg.money_spent), str(agg.shop_visits.slice(0, 2 if pr == RouteFatia.Profile.MINIMUM else 4))])

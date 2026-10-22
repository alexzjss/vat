class_name SimReport
extends RefCounted

## Relatorio comparativo das formulas F1-F12 (spec M5 §4/§5): varia UMA opcao por vez sobre o padrao (tudo A).
## Gera Markdown + CSV. Nao usa Node/cena; roda tambem dentro de testes GUT.

## Chefe de teste do M11 (so relatorio, sem meta): encontro `chefe_dungeon` com o grupo no nivel pensado para a dungeon.
const BOSS_ENC: String = "Chefe"
const BOSS_LEVEL: int = 6 # valor de teste (M11: nivel do grupo no cenario do chefe)
const BOSS_EXTRA_ITEMS: Array[int] = [2, 1] # valor de teste (M11: Remedio e Panaceia no cenario do chefe)

const HERO_IDS: Array[String] = ["teste_a", "teste_b", "teste_c", "teste_d"]
const LEVELS: Array[int] = [1, 5, 10]
const ENCOUNTERS: Array[String] = ["X+Y", "X+Y+Z"]
const POLICIES: Array[StringName] = [&"basic", &"smart"]

## prop: campo do BalanceConfig; opts: valor de cada opcao (A, B, C); desc: o que cada opcao faz.
const FORMULAS: Array[Dictionary] = [
	{"id": "F1", "name": "Retornos decrescentes", "prop": "dr_mode", "opts": [0, 1, 2],
		"desc": ["A: 1 limiar (ate 20 integral, acima x0,5)", "B: faixas estilo Souls (x1 / x0,5 / x0,25)", "C: suave limite*v/(v+k)"]},
	{"id": "F2", "name": "HP maximo", "prop": "hp_mode", "opts": [0, 1, 2],
		"desc": ["A: Vit*10 + Nv*5", "B: base + Vit*a + Nv*b + Vit*Nv*c", "C: (base + Vit*a)*(1 + Nv*b)"]},
	{"id": "F3", "name": "AP maximo", "prop": "ap_mode", "opts": [0, 1, 2],
		"desc": ["A: Aura*5", "B: Aura*a + Nv*b", "C: Aura*a*(1 + Nv*b)"]},
	{"id": "F4", "name": "Velocidade para ATB", "prop": "atb_mode", "opts": [0, 1, 2],
		"desc": ["A: linear", "B: relativo ao campo (media de Velocidade)", "C: tempo de turno T*r/(r+Vel)"]},
	{"id": "F5", "name": "Dano fisico/habilidade", "prop": "damage_mode", "opts": [0, 1, 2],
		"desc": ["A: subtrativo", "B: razao k/(k+defesa)", "C: subtrativo com defesa de equipamento"]},
	{"id": "F6", "name": "Variacao de dano", "prop": "variance_mode", "opts": [0, 1, 2],
		"desc": ["A: nenhuma", "B: +-6%", "C: +-12%"]},
	{"id": "F7", "name": "Esquiva", "prop": "dodge_mode", "opts": [0, 1, 2],
		"desc": ["A: Vel*k com teto", "B: relativa (Vel alvo - Vel atacante)", "C: so equipamento/estado"]},
	{"id": "F8", "name": "Curva de XP", "prop": "xp_mode", "opts": [0, 1, 2],
		"desc": ["A: coef 10 quadratico", "B: coef calibrado", "C: coef + termo linear"]},
	{"id": "F9", "name": "Nivel maximo (so afeta XP)", "prop": "max_level", "opts": [0, 50, 99],
		"desc": ["A: sem limite", "B: 50", "C: 99"]},
	{"id": "F10", "name": "Reviver", "prop": "revive_mode", "opts": [0, 1, 2],
		"desc": ["A: 25% do HP max", "B: 50%", "C: fixo + 10%"]},
	{"id": "F11", "name": "Veneno", "prop": "poison_mode", "opts": [0, 1, 2],
		"desc": ["A: dano fixo por turno", "B: % do HP max", "C: fixo + %"]},
	{"id": "F12", "name": "Duracoes de estado", "prop": "duration_mode", "opts": [0, 1],
		"desc": ["A: valores de teste por estado", "B: tabela unica por forca"]},
]

const METAS: String = """- Batalha comum: 30-60 s de duracao com a politica `smart` e vitoria >= 90%.
- Politica `basic`: vitoria entre 40% e 70% (pressao real sem ser impossivel).
- Chefes: metas proprias por cenario (chefe da fatia: 15-20 s com `smart` e vitoria >= 90%; ver `docs/balance/2026-10-20-relatorio-fatia.md`).
- Cenario "difícil" (opt-in, `-hard F`): nivel 1, X+Y+Z com atributos dos inimigos multiplicados por F; desligado por padrao desde o M5b.
- Fonte: spec M5 (`.claude/specs/2026-10-19-m5-formulas-design.md`, §4).
- Cada formula varia apenas ela mesma sobre o padrao (tudo A); a opcao A das tabelas e o padrao."""

const NOTES: String = """- A familia "difícil" (fator unico sobre os inimigos) foi desligada no M5b: o conteudo foi reajustado para as formulas escolhidas e os cenarios-meta ja exercem `basic` entre ~50% e 100% de vitoria; o fator antigo (x1,125) era uma aresta de faca calibrada para os atributos antigos.
- TTK (acoes) e a media so das execucoes em que o inimigo morreu (derrotas/tempos esgotados nao entram).
- Diferencas pequenas (alguns pontos de vitoria) em poucas execucoes sao ruido, nao efeito da formula."""

const F12_NOTE: String = "> Nota: a tabela B de duracoes so difere dos dados dos estados para barreira, aceleracao e paralisia, que as politicas `basic`/`smart` quase nao usam; na pratica F12 nao e exercitada por este simulador (resultados A e B praticamente iguais)."

const CSV_HEADER: String = "formula,option,level,encounter,policy,runs,wins,losses,timeouts,win_rate,dur_mean,dur_median,actions_per_hero,basic_dmg,ability_dmg,hp_pct,ap_spent,xp_per_win_hero,battles_to_level"

## Fator de vida/atributos dos inimigos do cenario "dificil" (escolhido por busca; ver README).
## 0 = familia desligada por padrao (M5b: o conteudo ja pressiona o `basic`; o fator 1,125 era calibrado para o conteudo antigo). Use -hard F para reativar.
const HARD_SCALE: float = 0.0
const HARD_RUNS_DEFAULT: int = 20

## Cenarios padrao + familia "dificil" (nivel 1, X+Y+Z, inimigos com atributos x hard_scale). hard_runs <= 0: usa as mesmas execucoes.
static func default_cases(hard_scale: float = HARD_SCALE, hard_runs: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lv: int in LEVELS:
		for enc: String in ENCOUNTERS:
			for p: StringName in POLICIES:
				out.append({"level": lv, "enc": enc, "policy": p})
	if hard_scale > 0.0:
		for p: StringName in POLICIES:
			var c: Dictionary = hard_case(hard_scale, p)
			if hard_runs > 0:
				c["runs"] = hard_runs
			out.append(c)
	return out

static func hard_case(hard_scale: float, policy: StringName) -> Dictionary:
	return {"level": 1, "enc": "X+Y+Z difícil ×%s" % String.num(hard_scale), "policy": policy, "hard": hard_scale}

## Copia o EnemyDef (e seus Stats) com os atributos multiplicados; nunca altera o .tres.
static func scaled_enemy(d: EnemyDef, factor: float) -> EnemyDef:
	var e: EnemyDef = d.duplicate() as EnemyDef
	var b: Stats = d.base.duplicate() as Stats
	b.strength = roundi(float(b.strength) * factor)
	b.speed = roundi(float(b.speed) * factor)
	b.vitality = roundi(float(b.vitality) * factor)
	b.aura = roundi(float(b.aura) * factor)
	e.base = b
	return e

static func formula_ids() -> Array[String]:
	var out: Array[String] = []
	for f: Dictionary in FORMULAS:
		out.append(f["id"])
	return out

static func _formula(id: String) -> Dictionary:
	for f: Dictionary in FORMULAS:
		if f["id"] == id:
			return f
	return {}

static func _level_label(c: Dictionary) -> String:
	return "%d difícil" % int(c["level"]) if c.has("hard") else str(int(c["level"]))

static func _case_label(c: Dictionary) -> String:
	return "N%d %s %s" % [int(c["level"]), str(c["enc"]), str(c["policy"])]

static func _enemies(enc: String) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	if enc == BOSS_ENC:
		return (load("res://data/test/encounters/chefe_dungeon.tres") as EncounterDef).enemies.duplicate()
	for letter: String in enc.split(" ")[0].split("+"):
		out.append(load("res://data/test/enemies/inimigo_%s.tres" % letter.to_lower()) as EnemyDef)
	return out

## chosen=false: baseline tudo A (comparacao M5a); chosen=true: padrao escolhido (balance.tres).
static func make_scenario(c: Dictionary, runs: int, prop: String, value: int, label: String, chosen: bool = false) -> SimScenario:
	var s := SimScenario.new()
	s.label = label
	for id: String in HERO_IDS:
		s.heroes.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	s.hero_level = int(c["level"])
	s.alloc_rule = &"main"
	s.equipment = true
	s.enemies = _enemies(str(c["enc"]))
	if c.has("hard"):
		for i: int in s.enemies.size():
			s.enemies[i] = scaled_enemy(s.enemies[i], float(c["hard"]))
	s.policy = c["policy"]
	s.runs = runs
	s.base_seed = 1
	var cfg: BalanceConfig = SimScenario.config_chosen() if chosen else SimScenario.config_all_a()
	s.baseline = SimScenario.BASELINE_CHOSEN if chosen else SimScenario.BASELINE_ALL_A
	if prop != "":
		cfg.set(prop, value)
	s.cfg = cfg
	var item_ids: Array[String] = ["pocao", "eter", "reviver"]
	var counts: Array[int] = [3, 2, 1]
	if str(c["enc"]) == BOSS_ENC:
		item_ids.append_array(["remedio", "panaceia"])
		counts.append_array(BOSS_EXTRA_ITEMS)
	for i: int in item_ids.size():
		s.items.append(load("res://data/test/items/%s.tres" % item_ids[i]) as ItemDef)
		s.item_counts.append(counts[i])
	return s

static func _run_cases(cases: Array[Dictionary], runs: int, prop: String, value: int, opt_label: String, chosen: bool = false) -> Array[SimMetrics]:
	var out: Array[SimMetrics] = []
	for c: Dictionary in cases:
		out.append(SimRunner.run(make_scenario(c, int(c.get("runs", runs)), prop, value, "%s - %s" % [opt_label, _case_label(c)], chosen)))
	return out

# ---- agregacao ----

static func _xp_per_win_hero(m: SimMetrics) -> float:
	if m.xp_total.is_empty():
		return 0.0
	var total: int = 0
	for v: int in m.xp_total.values():
		total += v
	return float(total) / float(m.xp_total.size() * maxi(1, m.wins))

## Media das batalhas ate o nivel entre os herois com XP; -1 se nenhum.
static func _btl_mean(m: SimMetrics) -> float:
	var total: float = 0.0
	var n: int = 0
	for v: int in m.battles_to_level.values():
		if v >= 0:
			total += float(v)
			n += 1
	return total / float(n) if n > 0 else -1.0

static func _avg(ms: Array[SimMetrics], fn: Callable) -> float:
	if ms.is_empty():
		return 0.0
	var t: float = 0.0
	for m: SimMetrics in ms:
		t += float(fn.call(m))
	return t / float(ms.size())

static func _fmt_btl(v: float) -> String:
	return "?" if v < 0.0 else "%.1f" % v

static func _btl_avg(ms: Array[SimMetrics]) -> float:
	var t: float = 0.0
	var n: int = 0
	for m: SimMetrics in ms:
		var v: float = _btl_mean(m)
		if v >= 0.0:
			t += v
			n += 1
	return t / float(n) if n > 0 else -1.0

static func _summary_row(label: String, policy: String, level: String, ms: Array[SimMetrics]) -> String:
	var runs: int = 0
	var wins: int = 0
	var timeouts: int = 0
	for m: SimMetrics in ms:
		runs += m.runs
		wins += m.wins
		timeouts += m.timeouts
	return "| %s | %s | %s | %.0f%% | %d | %.1f | %.1f | %.1f | %.1f | %.0f%% | %.0f | %s |" % [
		label, policy, level, 100.0 * float(wins) / float(maxi(1, runs)), timeouts,
		_avg(ms, func(m: SimMetrics) -> float: return m.mean_duration()),
		_avg(ms, func(m: SimMetrics) -> float: return m.median_duration()),
		_avg(ms, func(m: SimMetrics) -> float: return m.avg_basic_damage()),
		_avg(ms, func(m: SimMetrics) -> float: return m.avg_ability_damage()),
		100.0 * _avg(ms, func(m: SimMetrics) -> float: return m.mean_party_hp_pct()),
		_avg(ms, func(m: SimMetrics) -> float: return _xp_per_win_hero(m)),
		_fmt_btl(_btl_avg(ms))]

static func _summary_header() -> String:
	return "| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |\n|---|---|---|---|---|---|---|---|---|---|---|---|"

## Agrupa por (politica, nivel) somando os encontros.
static func _summary_rows(label: String, cases: Array[Dictionary], ms: Array[SimMetrics]) -> Array[String]:
	var order: Array[String] = []
	var groups: Dictionary[String, Array] = {}
	var policy_of: Dictionary[String, String] = {}
	var level_of: Dictionary[String, String] = {}
	for i: int in cases.size():
		var p: String = str(cases[i]["policy"])
		var lv: String = _level_label(cases[i])
		var key: String = "%s|%s" % [p, lv]
		if not groups.has(key):
			groups[key] = []
			order.append(key)
			policy_of[key] = p
			level_of[key] = lv
		groups[key].append(ms[i])
	var out: Array[String] = []
	for key: String in order:
		var arr: Array[SimMetrics] = []
		for m: SimMetrics in groups[key]:
			arr.append(m)
		out.append(_summary_row(label, policy_of[key], level_of[key], arr))
	return out

static func _csv_rows(formula: String, opt: String, cases: Array[Dictionary], ms: Array[SimMetrics]) -> Array[String]:
	var out: Array[String] = []
	for i: int in cases.size():
		var m: SimMetrics = ms[i]
		out.append("%s,%s,%d,%s,%s,%d,%d,%d,%d,%.4f,%.2f,%.2f,%.2f,%.2f,%.2f,%.4f,%.2f,%.2f,%.2f" % [
			formula, opt, int(cases[i]["level"]), str(cases[i]["enc"]), str(cases[i]["policy"]), m.runs, m.wins, m.losses,
			m.timeouts, m.win_rate(), m.mean_duration(), m.median_duration(), m.mean_actions_per_hero(),
			m.avg_basic_damage(), m.avg_ability_damage(), m.mean_party_hp_pct(), m.mean_ap_spent(),
			_xp_per_win_hero(m), _btl_mean(m)])
	return out

static func _detail_table(label_prefix: String, cases: Array[Dictionary], ms: Array[SimMetrics]) -> String:
	var lines: Array[String] = [SimMetrics.header()]
	for i: int in ms.size():
		ms[i].label = "%s - %s" % [label_prefix, _case_label(cases[i])]
		lines.append(ms[i].to_markdown_row())
	return "\n".join(lines)

## formulas: ids a incluir (ex. ["F1", "F6"]); cases: cenarios {level, enc, policy}; runs: batalhas por cenario.
## Devolve {"markdown": String, "csv": String}.
static func build(formulas: Array[String], cases: Array[Dictionary], runs: int, verbose: bool = false) -> Dictionary:
	var md: Array[String] = []
	var csv: Array[String] = [CSV_HEADER]
	md.append("# Relatorio comparativo de formulas (M5a)\n")
	md.append("Baseline: **%s** (todos os modos na opcao A, reproduz a comparacao do M5a; nao e o padrao atual do jogo).\n" % SimScenario.BASELINE_ALL_A)
	var hard_runs: int = 0
	for c: Dictionary in cases:
		if c.has("hard"):
			hard_runs = int(c.get("runs", runs))
	var runs_text: String = "%d execucoes por cenario normal" % runs
	if hard_runs > 0:
		runs_text += " e %d por cenario difícil" % hard_runs
	md.append("Gerado por `run_sim.ps1` (%s; grupo = herois de teste A-D com equipamento, alocacao `main`; itens: Pocao 3, Eter 2, Reviver 1; sementes 1..N, deterministico). Valores de teste, nao canonicos.\n" % runs_text)
	md.append("## Metas\n")
	md.append(METAS + "\n")
	md.append("## Observacoes\n")
	md.append(NOTES + "\n")
	# Padrao (tudo A): calculado uma vez e reaproveitado como opcao A de cada formula.
	if verbose:
		print("[sim] padrao (tudo A)")
	var base: Array[SimMetrics] = _run_cases(cases, runs, "", 0, "A")
	md.append("## Padrao (tudo A)\n")
	md.append(_detail_table("padrao", cases, base) + "\n")
	csv.append_array(_csv_rows("BASE", "A", cases, base))
	for fid: String in formulas:
		var f: Dictionary = _formula(fid)
		if f.is_empty():
			push_error("formula desconhecida: %s" % fid)
			continue
		var prop: String = f["prop"]
		var opts: Array = f["opts"]
		var descs: Array = f["desc"]
		md.append("## %s - %s\n" % [fid, f["name"]])
		for d: String in descs:
			md.append("- %s" % d)
		md.append("")
		if fid == "F12":
			md.append(F12_NOTE + "\n")
		var summary: Array[String] = [_summary_header()]
		var details: Array[String] = []
		for i: int in opts.size():
			var opt: String = char(65 + i)
			var label: String = "%s-%s" % [fid, opt]
			var ms: Array[SimMetrics] = base
			if i > 0:
				if verbose:
					print("[sim] %s" % label)
				ms = _run_cases(cases, runs, prop, int(opts[i]), label)
				csv.append_array(_csv_rows(fid, opt, cases, ms))
			else:
				csv.append_array(_csv_rows(fid, opt, cases, ms))
			summary.append_array(_summary_rows(label, cases, ms))
			details.append("**%s**\n\n%s\n" % [label, _detail_table(label, cases, ms)])
		md.append("\n".join(summary) + "\n")
		md.append("<details><summary>Detalhe por cenario</summary>\n")
		md.append("\n".join(details))
		md.append("</details>\n")
	return {"markdown": "\n".join(md), "csv": "\n".join(csv) + "\n"}

# ---- relatorio final (M5b): padrao escolhido nos cenarios-meta ----

## Cenarios-meta: grupo A-D com equipamento; X+Y nos niveis 1 e 5, X+Y+Z nos niveis 5 e 10; smart e basic.
static func target_cases() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pairs: Array = [[1, "X+Y"], [5, "X+Y"], [5, "X+Y+Z"], [10, "X+Y+Z"]]
	for pr: Array in pairs:
		for p: StringName in POLICIES:
			out.append({"level": int(pr[0]), "enc": str(pr[1]), "policy": p})
	return out

## Roda o padrao escolhido nos cenarios-meta.
static func run_targets(runs: int, verbose: bool = false) -> Array[SimMetrics]:
	var cases: Array[Dictionary] = target_cases()
	var out: Array[SimMetrics] = []
	for c: Dictionary in cases:
		if verbose:
			print("[sim] meta %s" % _case_label(c))
		out.append(SimRunner.run(make_scenario(c, runs, "", 0, "escolhido - %s" % _case_label(c), true)))
	return out

static func boss_cases() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: StringName in POLICIES:
		out.append({"level": BOSS_LEVEL, "enc": BOSS_ENC, "policy": p})
	return out

## Roda o chefe de teste (basic e smart) com o padrao escolhido.
static func run_boss(runs: int, verbose: bool = false) -> Array[SimMetrics]:
	var out: Array[SimMetrics] = []
	for c: Dictionary in boss_cases():
		if verbose:
			print("[sim] chefe %s" % _case_label(c))
		out.append(SimRunner.run(make_scenario(c, runs, "", 0, "escolhido - %s" % _case_label(c), true)))
	return out

## Secao "Chefe (M11)" do relatorio final: so mostra numeros (sem meta obrigatoria; chefe exige tatica).
static func boss_section(cases: Array[Dictionary], ms: Array[SimMetrics]) -> String:
	var lines: Array[String] = []
	lines.append("## Chefe (M11)
")
	lines.append("Cenario so de relatorio, sem meta obrigatoria (chefe exige tatica; `basic` pode perder). Encontro `chefe_dungeon` (Guardiao + 2 Bracos) com o grupo A-D no nivel %d, alocacao `main`, itens: Pocao 3, Eter 2, Reviver 1, Remedio %d, Panaceia %d. Referencia de duracao do plano de metas: 2-4 min.
" % [BOSS_LEVEL, BOSS_EXTRA_ITEMS[0], BOSS_EXTRA_ITEMS[1]])
	lines.append("| Politica | Vitorias | Derrotas | Tempos esg. | Dur media (s) | Dur mediana (s) | HP final | Estados apl/res |
|---|---|---|---|---|---|---|---|")
	for i: int in cases.size():
		var m: SimMetrics = ms[i]
		lines.append("| %s | %.0f%% | %d | %d | %.1f | %.1f | %.0f%% | %d/%d |" % [str(cases[i]["policy"]), m.win_rate() * 100.0, m.losses, m.timeouts,
			m.mean_duration(), m.median_duration(), m.mean_party_hp_pct() * 100.0, m.statuses_applied, m.statuses_resisted])
	lines.append("")
	return "
".join(lines)

## Meta atendida? smart: vitoria >= 95% e 20-60 s (X+Y puro pode ser mais curto: so piso de 10 s); basic: vitoria >= 75%.
static func meets_target(policy: StringName, enc: String, m: SimMetrics) -> bool:
	if policy == &"smart":
		var lo: float = 20.0 if enc == "X+Y+Z" else 10.0
		return m.mean_duration() >= lo and m.mean_duration() <= 60.0 and m.win_rate() >= 0.95
	return m.win_rate() >= 0.75

## Registro das mudancas do M5b (antes x depois). 
const CHANGES: Array[Dictionary] = [
	{"what": "Inimigo X: Forca/Vel/Vit", "before": "11 / 9 / 8", "after": "27 / 10 / 5", "why": "Forca 2,5x o original (teto), Vit >= 5; Vel 10 mantem a pressao do basic em N5 X+Y+Z"},
	{"what": "Inimigo Y: Forca/Vel/Vit", "before": "8 / 7 / 7", "after": "20 / 12 / 5", "why": "Forca 2,5x, Vit 5; Vel 12 (ameaca rapida e fragil)"},
	{"what": "Inimigo Z: Forca/Vel/Vit", "before": "13 / 2 / 12", "after": "32 / 7 / 12", "why": "Forca 2,5x, Vit mantida; Vel 7 (a Vel de Z e a alavanca fina: 8 derruba smart para 87%)"},
	{"what": "HP: hp_base", "before": "30 (codigo)", "after": "0", "why": "Com Vit >= 5 nos inimigos, a base 30 deixava as batalhas longas demais (smart 60-80 s)"},
	{"what": "HP: hp_vit_a", "before": "8 (codigo)", "after": "5", "why": "HP = Vit*5 + Nv*3 + Vit*Nv*0,2 (estilo FF: cresce com o nivel); dificuldade classica"},
	{"what": "HP: hp_lvl_b", "before": "4 (codigo)", "after": "3", "why": "Crescimento por nivel mantido (heroi HP 10 tem mais HP que HP 1 com a mesma Vit)"},
	{"what": "HP: hp_vit_lvl_c", "before": "0,4 (codigo)", "after": "0,2", "why": "Termo Vit x Nivel mais suave"},
	{"what": "RD: dr_band2_start", "before": "20 (codigo)", "after": "13", "why": "Faixa 2 mais cedo: retornos decrescentes a partir de 13"},
	{"what": "RD: dr_band2_factor", "before": "0,5 (codigo)", "after": "0,45", "why": "Faixa 2 um pouco mais dura"},
	{"what": "Dano: dmg_ratio_k", "before": "20,0 (codigo)", "after": "20,0", "why": "Sem mudanca (variar k 20-80 quase nao alterou os resultados)"},
	{"what": "Itens (Pocao 3 / Eter 2 / Reviver 1)", "before": "sem mudanca", "after": "sem mudanca", "why": "Nao foi preciso mexer"},
	{"what": "xp_base dos inimigos (100/100/150)", "before": "sem mudanca", "after": "sem mudanca", "why": "Nao foi preciso mexer"},
]

static func build_final(runs: int, verbose: bool = false) -> Dictionary:
	var cases: Array[Dictionary] = target_cases()
	var ms: Array[SimMetrics] = run_targets(runs, verbose)
	var md: Array[String] = []
	md.append("# Relatorio final de balanceamento (M5b)
")
	md.append("Baseline: **%s**. Gerado por `run_sim.ps1 -Final` (%d execucoes por cenario; grupo = herois de teste A-D com equipamento, alocacao `main`; itens: Pocao 3, Eter 2, Reviver 1; sementes 1..N). Valores de teste, nao canonicos.
" % [SimScenario.BASELINE_CHOSEN, runs])
	md.append("## Metas
")
	md.append("- `smart`: 20-60 s de duracao media (X+Y pode ser menor) e vitoria >= 95%.
- `basic`: vitoria >= 75%.
")
	md.append("## Cenarios-meta
")
	md.append("| Cenario | Politica | Vitorias | Dur media (s) | Dur mediana (s) | HP final | Meta |
|---|---|---|---|---|---|---|")
	var csv: Array[String] = [CSV_HEADER]
	for i: int in cases.size():
		var m: SimMetrics = ms[i]
		var pol: StringName = cases[i]["policy"]
		md.append("| N%d %s | %s | %.0f%% | %.1f | %.1f | %.0f%% | %s |" % [int(cases[i]["level"]), str(cases[i]["enc"]), str(pol),
			m.win_rate() * 100.0, m.mean_duration(), m.median_duration(), m.mean_party_hp_pct() * 100.0, "ok" if meets_target(pol, str(cases[i]["enc"]), m) else "FORA"])
	csv.append_array(_csv_rows("FINAL", "escolhido", cases, ms))
	md.append("
## Detalhe
")
	md.append(_detail_table("escolhido", cases, ms) + "
")
	md.append("## Antes x depois
")
	if CHANGES.is_empty():
		md.append("(sem mudancas registradas)
")
	else:
		md.append("| Valor | Antes | Depois | Motivo |
|---|---|---|---|")
		for ch: Dictionary in CHANGES:
			md.append("| %s | %s | %s | %s |" % [ch["what"], ch["before"], ch["after"], ch["why"]])
		md.append("")
	md.append(NOTES + "
")
	var boss_cs: Array[Dictionary] = boss_cases()
	var boss_ms: Array[SimMetrics] = run_boss(runs, verbose)
	md.append(boss_section(boss_cs, boss_ms))
	csv.append_array(_csv_rows("BOSS", "escolhido", boss_cs, boss_ms))
	return {"markdown": "
".join(md), "csv": "
".join(csv) + "
"}

static func write_files(result: Dictionary, md_path: String) -> bool:
	var dir: String = md_path.get_base_dir()
	if dir != "" and DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_error("nao foi possivel criar %s" % dir)
		return false
	var csv_path: String = md_path.get_basename() + ".csv"
	var fm := FileAccess.open(md_path, FileAccess.WRITE)
	var fc := FileAccess.open(csv_path, FileAccess.WRITE)
	if fm == null or fc == null:
		push_error("nao foi possivel escrever o relatorio")
		return false
	fm.store_string(str(result["markdown"]))
	fc.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF])) # BOM UTF-8: o Excel mostra os acentos
	fc.store_string(str(result["csv"]))
	return true

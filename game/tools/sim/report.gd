class_name SimReport
extends RefCounted

## Relatorio comparativo das formulas F1-F12 (spec M5 §4/§5): varia UMA opcao por vez sobre o padrao (tudo A).
## Gera Markdown + CSV. Nao usa Node/cena; roda tambem dentro de testes GUT.

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
- Chefe de teste: 2-4 min.
- Fonte: spec M5 (`docs/superpowers/specs/2026-10-19-m5-formulas-design.md`, §4).
- Cada formula varia apenas ela mesma sobre o padrao (tudo A); a opcao A das tabelas e o padrao."""

const CSV_HEADER: String = "formula,option,level,encounter,policy,runs,wins,losses,timeouts,win_rate,dur_mean,dur_median,actions_per_hero,basic_dmg,ability_dmg,hp_pct,ap_spent,xp_per_win_hero,battles_to_level"

static func default_cases() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lv: int in LEVELS:
		for enc: String in ENCOUNTERS:
			for p: StringName in POLICIES:
				out.append({"level": lv, "enc": enc, "policy": p})
	return out

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

static func _case_label(c: Dictionary) -> String:
	return "N%d %s %s" % [int(c["level"]), str(c["enc"]), str(c["policy"])]

static func _enemies(enc: String) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for letter: String in enc.split("+"):
		out.append(load("res://data/test/enemies/inimigo_%s.tres" % letter.to_lower()) as EnemyDef)
	return out

static func make_scenario(c: Dictionary, runs: int, prop: String, value: int, label: String) -> SimScenario:
	var s := SimScenario.new()
	s.label = label
	for id: String in HERO_IDS:
		s.heroes.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	s.hero_level = int(c["level"])
	s.alloc_rule = &"main"
	s.equipment = true
	s.enemies = _enemies(str(c["enc"]))
	s.policy = c["policy"]
	s.runs = runs
	s.base_seed = 1
	var cfg := BalanceConfig.new()
	if prop != "":
		cfg.set(prop, value)
	s.cfg = cfg
	var item_ids: Array[String] = ["pocao", "eter", "reviver"]
	var counts: Array[int] = [3, 2, 1]
	for i: int in item_ids.size():
		s.items.append(load("res://data/test/items/%s.tres" % item_ids[i]) as ItemDef)
		s.item_counts.append(counts[i])
	return s

static func _run_cases(cases: Array[Dictionary], runs: int, prop: String, value: int, opt_label: String) -> Array[SimMetrics]:
	var out: Array[SimMetrics] = []
	for c: Dictionary in cases:
		out.append(SimRunner.run(make_scenario(c, runs, prop, value, "%s - %s" % [opt_label, _case_label(c)])))
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
		var lv: String = str(cases[i]["level"])
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
	md.append("Gerado por `run_sim.ps1` (%d execucoes por cenario; grupo = herois de teste A-D com equipamento, alocacao `main`; itens: Pocao 3, Eter 2, Reviver 1; sementes 1..N, deterministico). Valores de teste, nao canonicos.\n" % runs)
	md.append("## Metas\n")
	md.append(METAS + "\n")
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
	fc.store_string(str(result["csv"]))
	return true

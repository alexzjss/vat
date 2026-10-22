class_name FatiaReport
extends RefCounted

## Relatorio de balanceamento da fatia vertical (M12, Task 5): rota, lutas comuns, chefe e o registro antes -> depois.
## Gera Markdown + CSV (gravados por SimReport.write_files). Valores de teste, nao canonicos.

## Registro das mudancas da Task 5 (so em data/fatia/*.tres; BalanceConfig, formulas e data/test nao mudam).
const CHANGES: Array[Dictionary] = [
	{"what": "Guardião (fatia): Vitalidade", "before": "28", "after": "3", "why": "Alvo do chefe: 15-20 s. HP = Vit*5 + Nv*3 + Vit*Nv*0,2: 191 -> 37 de HP; era a maior parte do tempo da luta"},
	{"what": "Braço (fatia) x2: Vitalidade", "before": "17", "after": "2", "why": "Os braços protegem o núcleo e têm de cair antes dele: 117 -> 24 de HP cada"},
	{"what": "Braço (fatia) x2: nível", "before": "5", "after": "4", "why": "O nível entra no HP (3 por nível); ajuste fino para ficar dentro de 15-20 s também no Nv 4"},
	{"what": "Inimigo F1: Vitalidade", "before": "5", "after": "7", "why": "A luta de 1 inimigo no Nv 1 durava 9,3 s; com Vit 7 fica em ~11 s (piso de 10 s das lutas pequenas)"},
	{"what": "Guardião e Braços: Força, Velocidade, Aura, fases, habilidades e IA", "before": "24 / 8 / 10 (Guardião), 16 / 8 / 2 (Braço)", "after": "sem mudança", "why": "Só o HP precisava mudar. Subir a Força (até 50/36) e a Velocidade (10 ou 12) não ajudou: a Força quase não mexe na duração e a Velocidade deixa a luta mais longa e mais perigosa (30-39 s, vitória do smart de 83% a 100%)"},
	{"what": "xp_base dos inimigos comuns e do chefe", "before": "100 / 100 / 150 / 100", "after": "sem mudança", "why": "A rota típica já chega ao chefe no Nv 5 (alvo 4-6)"},
	{"what": "Moeda, drops, preços da loja e recompensa da missão", "before": "valores do conteúdo", "after": "sem mudança", "why": "A 1ª visita à cidade compra 1 capacete (50) e a 2ª, 1 arma (80): 1-2 equipamentos (alvo)"},
]

## Metricas medidas ANTES do ajuste (2026-10-20, dados da Task 4 sem mudanca; 60 execucoes por cenario e 30 de rota).
## Chefe: nivel -> [vitorias smart (%), duracao smart (s), vitorias basic (%), duracao basic (s)].
const BEFORE_BOSS: Dictionary = {
	4: [72, 153.8, 0, 52.7], 5: [92, 165.6, 0, 60.1], 6: [88, 154.5, 0, 64.4],
}
const BEFORE_F1_SMART: float = 9.3
## Chefe pela rota minima, tipica e completa antes: [vitorias de 30, duracao media (s)].
const BEFORE_ROUTE_BOSS: Array[Array] = [[4, 124.5], [30, 130.2], [30, 124.0]]

static func _fmt(v: float, digits: int = 1) -> String:
	return String.num(v, digits)

static func _pct(v: float) -> String:
	return "%.0f%%" % (v * 100.0)

static func _route_table(aggs: Array[RouteFatia.Aggregate]) -> String:
	var lines: Array[String] = []
	lines.append("| Perfil | Execuções | Chegou ao chefe | Nível médio no chefe (mín-máx) | Moeda no chefe | Moeda ganha / gasta até lá | Lutas até o chefe | Tempo de luta até o chefe (s) | Voltas ao descanso | Chefe pela rota (vitórias, dur. média s) |")
	lines.append("|---|---|---|---|---|---|---|---|---|---|")
	for a: RouteFatia.Aggregate in aggs:
		lines.append("| %s | %d | %d | %s (%s-%s) | %s | %s / %s | %s | %s | %s | %d/%d, %s |" % [
			RouteFatia.profile_name(a.profile), a.runs, a.reached_boss, _fmt(a.mean(a.avg_levels), 2), _fmt(a.min_of(a.avg_levels), 2), _fmt(a.max_of(a.avg_levels), 2),
			_fmt(a.mean(a.money_at_boss), 0), _fmt(a.mean(a.money_earned), 0), _fmt(a.mean(a.money_spent), 0), _fmt(a.mean(a.fights), 1), _fmt(a.mean(a.fight_seconds), 0),
			_fmt(a.mean(a.rests), 1), a.boss_wins, a.reached_boss, _fmt(a.mean(a.boss_seconds), 1)])
	return "\n".join(lines)

static func _hero_levels_table(aggs: Array[RouteFatia.Aggregate]) -> String:
	var ids: Array[StringName] = [&"teste_a_f", &"teste_b_f", &"teste_c_f", &"teste_d_f"]
	var lines: Array[String] = ["| Perfil | Teste A | Teste B | Teste C | Teste D |", "|---|---|---|---|---|"]
	for a: RouteFatia.Aggregate in aggs:
		var cells: Array[String] = []
		for id: StringName in ids:
			var arr: Array = a.hero_levels.get(id, [])
			var t: float = 0.0
			for v: Variant in arr:
				t += float(v)
			cells.append(_fmt(t / float(maxi(1, arr.size())), 2))
		lines.append("| %s | %s |" % [RouteFatia.profile_name(a.profile), " | ".join(cells)])
	return "\n".join(lines)

static func _step_table(a: RouteFatia.Aggregate) -> String:
	var lines: Array[String] = ["| Etapa | Tag | Nível do grupo ao chegar | Vitórias | Dur. média (s) | XP médio por herói | Nível depois | Moeda depois |", "|---|---|---|---|---|---|---|---|"]
	for i: int in a.steps.size():
		var lg: Dictionary = a.step_log[i]
		var n: int = int(lg["n"])
		if n == 0:
			continue
		var st: RouteFatia.Step = a.steps[i]
		var fought: bool = st.kind == &"fight" or st.kind == &"boss"
		var fights: int = int(lg["wins"]) + int(lg["losses"])
		lines.append("| %s | %s | %s | %s | %s | %s | %s | %s |" % [
			st.label, str(st.tag) if fought else "-", _fmt(float(lg["pre"]) / float(n), 2),
			"%d/%d" % [int(lg["wins"]), fights] if fought else "-",
			_fmt(float(lg["secs"]) / float(maxi(1, fights)), 1) if fought else "-",
			_fmt(float(lg["xp"]) / float(maxi(1, fights)) / 4.0, 0) if fought else "-",
			_fmt(float(lg["lvl"]) / float(n), 2), _fmt(float(lg["money"]) / float(n), 0)])
	return "\n".join(lines)

static func _shop_section(typical: RouteFatia.Aggregate, full: RouteFatia.Aggregate) -> String:
	var shop: ShopDef = load(RouteFatia.SHOP) as ShopDef
	var cfg: BalanceConfig = SimScenario.config_chosen()
	var quest: Dictionary = RouteFatia.quest_reward()
	var per_fight: float = (typical.mean(typical.money_earned) - float(quest["money"])) / maxf(1.0, typical.mean(typical.fights))
	var lines: Array[String] = []
	lines.append("Preços da `loja_cidade` e quantas lutas típicas de moeda cada um custa (média da rota típica: %s %s por luta, sem contar a missão)." % [_fmt(per_fight, 1), cfg.currency_name])
	lines.append("")
	lines.append("| Item | Preço | Venda (x%s) | Lutas para pagar |" % _fmt(cfg.sell_ratio, 2))
	lines.append("|---|---|---|---|")
	for it: ItemDef in shop.items:
		lines.append("| %s | %d | %d | %s |" % [it.display_name, it.price, ShopRules.sell_value(it, cfg), _fmt(float(it.price) / maxf(0.1, per_fight), 1)])
	for e: EquipmentDef in shop.equipment:
		lines.append("| %s | %d | %d | %s |" % [e.display_name, e.price, ShopRules.sell_value(e, cfg), _fmt(float(e.price) / maxf(0.1, per_fight), 1)])
	lines.append("")
	lines.append("Compras da rota (política de compra do simulador: equipamento por prioridade se algum herói ativo ganha com ele, depois Poções até 6):")
	lines.append("")
	lines.append("| Perfil | Visita | Moeda ao chegar | Compra mais frequente | Moeda ao sair |")
	lines.append("|---|---|---|---|---|")
	for a: RouteFatia.Aggregate in [typical, full]:
		var per_run: int = a.shop_visits.size() / maxi(1, a.runs)
		for v: int in per_run:
			var before: float = 0.0
			var after: float = 0.0
			var counts: Dictionary = {}
			for r: int in a.runs:
				var rec: Dictionary = a.shop_visits[r * per_run + v]
				before += float(rec["money_before"])
				after += float(rec["money_after"])
				var key: String = ", ".join(rec["bought"])
				counts[key] = int(counts.get(key, 0)) + 1
			var best: String = ""
			var best_n: int = -1
			for k: String in counts:
				if int(counts[k]) > best_n:
					best = k
					best_n = int(counts[k])
			lines.append("| %s | %d | %s | %s | %s |" % [RouteFatia.profile_name(a.profile), v + 1, _fmt(before / float(a.runs), 0), best, _fmt(after / float(a.runs), 0)])
	lines.append("")
	lines.append("Recompensa da missão (lida do evento `morador_c`): %d %s, `%s` e %d de XP narrativa para cada herói ativo." % [int(quest["money"]), cfg.currency_name, str((quest["equipment"] as EquipmentDef).display_name), int(quest["xp"])])
	return "\n".join(lines)

static func build(runs: int, route_runs: int, verbose: bool = false) -> Dictionary:
	var md: Array[String] = []
	var csv: Array[String] = ["section,level,encounter,policy,runs,wins,win_rate,dur_mean,dur_median,hp_pct"]
	md.append("# Relatório de balanceamento da fatia vertical (M12)\n")
	md.append("Baseline: **%s**. Gerado por `run_sim.ps1 -Fatia` (%d execuções por cenário de luta e %d execuções de rota por perfil; grupo = heróis de teste A-D com equipamento inicial, alocação `main`; itens: Poção 3, Éter 2, Reviver 1 e, no chefe, Remédio 2; sementes 1..N). Valores de teste, não canônicos.\n" % [SimScenario.BASELINE_CHOSEN, runs, route_runs])
	md.append("## Metas\n")
	md.append("- Lutas comuns: `smart` com vitória >= 95% e duração média de 10-60 s (as lutas da fatia têm 1-2 inimigos, por isso o piso é 10 s; a meta clássica de 20 s vale para 3 inimigos); `basic` com vitória >= 75%.")
	md.append("- Chefe (decisão do usuário, plano M12): `smart` com duração média de **%s-%s s** e vitória >= %s; `basic` só é relatado. Leitura: segundos de jogo do simulador (a mesma unidade dos 20-60 s das lutas comuns), média sobre as execuções, grupo no Nv %d com equipamento inicial." % [_fmt(SimFatia.BOSS_DUR_MIN, 0), _fmt(SimFatia.BOSS_DUR_MAX, 0), _pct(SimFatia.BOSS_WIN_MIN), SimFatia.BOSS_MAIN_LEVEL])
	md.append("- Ritmo: a rota **típica** (obrigatório + errantes/patrulheiros + baús + missão entregue) chega ao chefe no **Nv %s-%s** (média dos 4 ativos)." % [_fmt(SimFatia.ROUTE_LEVEL_MIN, 0), _fmt(SimFatia.ROUTE_LEVEL_MAX, 0)])
	md.append("- Moeda: as duas visitas à cidade compram 1-2 equipamentos.\n")

	var aggs: Array[RouteFatia.Aggregate] = []
	for pr: RouteFatia.Profile in [RouteFatia.Profile.MINIMUM, RouteFatia.Profile.TYPICAL, RouteFatia.Profile.FULL]:
		if verbose:
			print("[sim] rota %s" % RouteFatia.profile_name(pr))
		aggs.append(RouteFatia.run(pr, route_runs))
	var typical: RouteFatia.Aggregate = aggs[1]
	md.append("## Rota e ritmo\n")
	md.append("A rota simulada (`tools/sim/route_fatia.gd`) percorre: cidade (recruta D, loja) -> estrada -> andar 1 (recruta E, baús) -> volta à cidade (missão, loja, pousada) -> andar 2 -> chefe, com o `GameState` real: XP por contribuição, moeda e drops sorteados, compras pelo `ShopRules`, cura de campo com itens e volta ao ponto de descanso quando o grupo fica fraco (coluna \"Voltas\"). Perfis: **mínimo** = só o obrigatório (perseguidores, armadilha de batalha, chefe; sem baús nem missão); **típico** = obrigatório + errantes e patrulheiros + baús + missão entregue; **completo** = tudo, inclusive os grupos (\"dupla\") dos três mapas. O recruta E vai para a reserva (o grupo ativo já tem 4) e não entra na média.\n")
	md.append(_route_table(aggs) + "\n")
	md.append("Nível médio por herói ao chegar ao chefe:\n")
	md.append(_hero_levels_table(aggs) + "\n")
	var lvl: float = typical.mean(typical.avg_levels)
	md.append("**Nível estimado no chefe (rota típica): %s** (alvo %s-%s): %s. Mínimo: %s; completo: %s.\n" % [_fmt(lvl, 2), _fmt(SimFatia.ROUTE_LEVEL_MIN, 0), _fmt(SimFatia.ROUTE_LEVEL_MAX, 0),
		"dentro da meta" if lvl >= SimFatia.ROUTE_LEVEL_MIN and lvl <= SimFatia.ROUTE_LEVEL_MAX else "FORA da meta", _fmt(aggs[0].mean(aggs[0].avg_levels), 2), _fmt(aggs[2].mean(aggs[2].avg_levels), 2)])
	md.append("**Moeda acumulada (rota típica):** %s ganhas até o chefe (lutas e missão), %s gastas (lojas e pousada), %s no bolso ao entrar na sala do chefe; mais a inicial.\n" % [
		_fmt(typical.mean(typical.money_earned), 0), _fmt(typical.mean(typical.money_spent), 0), _fmt(typical.mean(typical.money_at_boss), 0)])
	md.append("### Rota típica, etapa por etapa\n")
	md.append(_step_table(typical) + "\n")
	md.append("### Loja e moeda\n")
	md.append(_shop_section(typical, aggs[2]) + "\n")

	md.append("## Lutas comuns\n")
	md.append("Nível do grupo = o da rota típica ao encontrar cada encontro (média dos ativos, arredondada para baixo; encontros que voltam bem mais tarde aparecem de novo), grupo A-D no equipamento inicial.\n")
	md.append("| Cenário | Política | Vitórias | Dur média (s) | Dur mediana (s) | HP final | Meta |\n|---|---|---|---|---|---|---|")
	var detail: Array[String] = [SimMetrics.header()]
	var f1_smart: float = 0.0
	for c: Dictionary in SimFatia.COMMON_CASES:
		if verbose:
			print("[sim] comum %s N%d" % [str(c["enc"]), int(c["level"])])
		var ms: Array[SimMetrics] = SimFatia.run_case(str(c["enc"]), int(c["level"]), runs)
		for i: int in SimFatia.POLICIES.size():
			var m: SimMetrics = ms[i]
			var pol: StringName = SimFatia.POLICIES[i]
			md.append("| N%d %s | %s | %s | %s | %s | %s | %s |" % [int(c["level"]), str(c["enc"]), str(pol), _pct(m.win_rate()), _fmt(m.mean_duration()), _fmt(m.median_duration()),
				_pct(m.mean_party_hp_pct()), "ok" if SimFatia.common_ok(pol, m) else "FORA"])
			detail.append(m.to_markdown_row())
			csv.append("COMMON,%d,%s,%s,%d,%d,%.4f,%.2f,%.2f,%.4f" % [int(c["level"]), str(c["enc"]), str(pol), m.runs, m.wins, m.win_rate(), m.mean_duration(), m.median_duration(), m.mean_party_hp_pct()])
			if str(c["enc"]) == "enc_f1" and pol == &"smart":
				f1_smart = m.mean_duration()
	md.append("\n<details><summary>Detalhe por cenário</summary>\n\n" + "\n".join(detail) + "\n\n</details>\n")

	md.append("## Chefe\n")
	md.append("Encontro `chefe_fatia` (Guardião + 2 Braços), grupo A-D, alocação `main`, itens: Poção 3, Éter 2, Reviver 1, Remédio 2. Meta no Nv %d: `smart` %s-%s s e vitória >= %s; os outros níveis mostram a sensibilidade.\n" % [SimFatia.BOSS_MAIN_LEVEL, _fmt(SimFatia.BOSS_DUR_MIN, 0), _fmt(SimFatia.BOSS_DUR_MAX, 0), _pct(SimFatia.BOSS_WIN_MIN)])
	md.append("| Nível do grupo | Política | Vitórias | Derrotas | Dur média (s) | Dur mediana (s) | HP final | Meta |\n|---|---|---|---|---|---|---|---|")
	var boss: Dictionary = {}
	for lv: int in SimFatia.BOSS_LEVELS:
		if verbose:
			print("[sim] chefe N%d" % lv)
		var bms: Array[SimMetrics] = SimFatia.run_case(SimFatia.BOSS_ENC, lv, runs)
		boss[lv] = bms
		for i: int in SimFatia.POLICIES.size():
			var m: SimMetrics = bms[i]
			var pol: StringName = SimFatia.POLICIES[i]
			var goal: String = "-"
			if pol == &"smart":
				goal = ("ok" if SimFatia.boss_ok(m) else "FORA") + (" (alvo)" if lv == SimFatia.BOSS_MAIN_LEVEL else " (sensibilidade)")
			md.append("| N%d | %s | %s | %d | %s | %s | %s | %s |" % [lv, str(pol), _pct(m.win_rate()), m.losses, _fmt(m.mean_duration()), _fmt(m.median_duration()), _pct(m.mean_party_hp_pct()), goal])
			csv.append("BOSS,%d,%s,%s,%d,%d,%.4f,%.2f,%.2f,%.4f" % [lv, SimFatia.BOSS_ENC, str(pol), m.runs, m.wins, m.win_rate(), m.mean_duration(), m.median_duration(), m.mean_party_hp_pct()])
	md.append("")
	md.append("Chefe pela rota (grupo e kit reais de cada perfil): mínimo %d/%d em %s s; típico %d/%d em %s s; completo %d/%d em %s s.\n" % [
		aggs[0].boss_wins, aggs[0].reached_boss, _fmt(aggs[0].mean(aggs[0].boss_seconds)), typical.boss_wins, typical.reached_boss, _fmt(typical.mean(typical.boss_seconds)),
		aggs[2].boss_wins, aggs[2].reached_boss, _fmt(aggs[2].mean(aggs[2].boss_seconds))])

	md.append("## Antes -> depois\n")
	md.append("Só os `.tres` de `data/fatia/` mudaram.\n")
	md.append("| Valor | Antes | Depois | Motivo |\n|---|---|---|---|")
	for ch: Dictionary in CHANGES:
		md.append("| %s | %s | %s | %s |" % [ch["what"], ch["before"], ch["after"], ch["why"]])
	md.append("")
	md.append("Efeito medido (antes: dados da Task 4, 60 execuções por cenário e 30 de rota, mesmas sementes):\n")
	md.append("| Métrica | Antes | Depois |\n|---|---|---|")
	for lv: int in [4, 5, 6]:
		var bf: Array = BEFORE_BOSS[lv]
		var after_ms: Array[SimMetrics] = boss[lv]
		md.append("| Chefe N%d `smart` (vitórias, dur. s) | %d%%, %s | %s, %s |" % [lv, int(bf[0]), _fmt(float(bf[1])), _pct(after_ms[1].win_rate()), _fmt(after_ms[1].mean_duration())])
	var b5: Array[SimMetrics] = boss[SimFatia.BOSS_MAIN_LEVEL]
	var bf5: Array = BEFORE_BOSS[SimFatia.BOSS_MAIN_LEVEL]
	md.append("| Chefe N%d `basic` (vitórias, dur. s) | %d%%, %s | %s, %s |" % [SimFatia.BOSS_MAIN_LEVEL, int(bf5[2]), _fmt(float(bf5[3])), _pct(b5[0].win_rate()), _fmt(b5[0].mean_duration())])
	var names: Array[String] = ["mínimo", "típico", "completo"]
	for k: int in 3:
		var bb: Array = BEFORE_ROUTE_BOSS[k]
		md.append("| Chefe pela rota %s (vitórias de %d, dur. s) | %d, %s | %d, %s |" % [names[k], route_runs, int(bb[0]), _fmt(float(bb[1])), aggs[k].boss_wins, _fmt(aggs[k].mean(aggs[k].boss_seconds))])
	md.append("| Luta enc_f1 N1 `smart` (dur. s) | %s | %s |" % [_fmt(BEFORE_F1_SMART), _fmt(f1_smart)])
	md.append("")

	md.append("## Notas e limites\n")
	md.append("- **Leitura do alvo de 15-20 s.** O plano diz \"tempo médio de 15-20 s\" para o chefe `smart`; foi lido como segundos de jogo do simulador, a mesma unidade dos 20-60 s das lutas comuns. Efeito colateral: o chefe fica mais curto que as lutas comuns de 2 inimigos (25-38 s) e o HP total dele (Guardião ~37 + 2 Braços ~24 cada) é parecido com o de um inimigo comum. As fases e o contra-ataque continuam nos dados, mas passam rápido. Se a intenção era outra unidade ou uma luta com mais corpo, basta subir a Vitalidade do Guardião e dos Braços (cada ponto de Vit do Guardião soma ~2 s à luta no Nv 5; Vit 4 já leva o Nv 4 para ~20-21 s).")
	md.append("- O chefe quase não ameaça o `smart` (HP final do grupo ~85%) e o `basic` também vence, ao contrário do chefe do M11 (0%).")
	md.append("- **Tempo de jogo.** Só o combate é medido: ~%s s (%s min) de luta até o chefe na rota típica, mais ~%s s do chefe. Os ~15 min da fatia dependem de caminhada, diálogos, menus e da volta à cidade, que o simulador não mede; o combate sozinho não preenche esse tempo." % [_fmt(typical.mean(typical.fight_seconds), 0), _fmt(typical.mean(typical.fight_seconds) / 60.0), _fmt(typical.mean(typical.boss_seconds), 0)])
	md.append("- A volta à cidade para entregar a missão supõe que o andar 1 reaparece sem lutas (o jogador passa direto); lutas de reaparição somariam XP.")
	md.append("- Cura de campo e compras seguem regras simples do simulador (ver `route_fatia.gd`); um jogador real pode gastar a moeda de outro jeito. A moeda que sobra depois da 2ª visita não tem onde ser gasta antes do fim da demo.")
	md.append("- Convenções (TTK, ruído, colunas do detalhe): ver `docs/balance/2026-10-19-relatorio-final.md`.")
	for a: RouteFatia.Aggregate in aggs:
		csv.append("ROUTE,%s,%d,%.2f,%d,%.1f,%.1f" % [RouteFatia.profile_name(a.profile), a.reached_boss, a.mean(a.avg_levels), a.boss_wins, a.mean(a.money_at_boss), a.mean(a.boss_seconds)])
	return {"markdown": "\n".join(md) + "\n", "csv": "\n".join(csv) + "\n"}

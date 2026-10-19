extends GutTest

## Rede de seguranca do balanceamento: conteudo de teste + formulas escolhidas nos cenarios-meta (M5b).
## Poucas execucoes (ruido), por isso as margens sao mais largas que as metas
## (smart: 20-60 s e >= 95%; basic >= 75%).

const RUNS: int = 10

func test_content_meets_targets() -> void:
	var cases: Array[Dictionary] = SimReport.target_cases()
	var ms: Array[SimMetrics] = SimReport.run_targets(RUNS)
	assert_eq(ms.size(), cases.size())
	for i: int in cases.size():
		var m: SimMetrics = ms[i]
		var label: String = "N%d %s %s" % [int(cases[i]["level"]), str(cases[i]["enc"]), str(cases[i]["policy"])]
		if cases[i]["policy"] == &"smart":
			assert_gte(m.win_rate(), 0.85, "%s: vitoria smart" % label)
			assert_between(m.mean_duration(), 15.0, 70.0, "%s: duracao smart (s)" % label)
		else:
			assert_gte(m.win_rate(), 0.65, "%s: vitoria basic" % label)

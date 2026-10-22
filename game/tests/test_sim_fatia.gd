extends GutTest

## Simulador da fatia (M12, Task 5): a rota e os cenarios de luta/chefe com os dados de data/fatia.
## Poucas execucoes (rapido); as metas completas ficam no relatorio (`run_sim.ps1 -Fatia`).

func test_route_is_deterministic() -> void:
	var a: RouteFatia.Aggregate = RouteFatia.run(RouteFatia.Profile.TYPICAL, 2)
	var b: RouteFatia.Aggregate = RouteFatia.run(RouteFatia.Profile.TYPICAL, 2)
	assert_eq(a.avg_levels, b.avg_levels)
	assert_eq(a.money_at_boss, b.money_at_boss)
	assert_eq(a.boss_seconds, b.boss_seconds)

func test_route_profiles_reach_the_boss_in_order_of_level() -> void:
	var lv: Array[float] = []
	for pr: RouteFatia.Profile in [RouteFatia.Profile.MINIMUM, RouteFatia.Profile.TYPICAL, RouteFatia.Profile.FULL]:
		var a: RouteFatia.Aggregate = RouteFatia.run(pr, 2)
		assert_eq(a.reached_boss, a.runs, "chega ao chefe: %s" % RouteFatia.profile_name(pr))
		lv.append(a.mean(a.avg_levels))
	assert_lt(lv[0], lv[1], "o minimo chega mais fraco que o tipico")
	assert_lt(lv[1], lv[2], "o completo chega mais forte que o tipico")

func test_typical_route_arrives_at_the_boss_in_the_target_levels() -> void:
	var a: RouteFatia.Aggregate = RouteFatia.run(RouteFatia.Profile.TYPICAL, 3)
	assert_between(a.mean(a.avg_levels), SimFatia.ROUTE_LEVEL_MIN, SimFatia.ROUTE_LEVEL_MAX, "Nv 4-6 no chefe")

func test_typical_route_money_buys_one_or_two_pieces_of_equipment() -> void:
	var a: RouteFatia.Aggregate = RouteFatia.run(RouteFatia.Profile.TYPICAL, 2)
	var pieces: int = 0
	for rec: Dictionary in a.shop_visits.slice(0, 2):
		for item: String in rec["bought"]:
			if not item.begins_with("Poção"):
				pieces += 1
	assert_between(pieces, 1, 2, "1-2 equipamentos nas duas visitas")

func test_quest_reward_is_read_from_the_event() -> void:
	var r: Dictionary = RouteFatia.quest_reward()
	assert_gt(int(r["money"]), 0)
	assert_gt(int(r["xp"]), 0)
	assert_not_null(r["equipment"])

func test_boss_meets_the_slice_target_at_the_planned_level() -> void:
	var ms: Array[SimMetrics] = SimFatia.run_case(SimFatia.BOSS_ENC, SimFatia.BOSS_MAIN_LEVEL, 6)
	var smart: SimMetrics = ms[1]
	assert_true(SimFatia.boss_ok(smart), "smart: %.1f s, %.0f%%" % [smart.mean_duration(), smart.win_rate() * 100.0])

func test_common_fights_meet_the_classic_targets() -> void:
	for c: Dictionary in SimFatia.COMMON_CASES:
		var ms: Array[SimMetrics] = SimFatia.run_case(str(c["enc"]), int(c["level"]), 4)
		for i: int in SimFatia.POLICIES.size():
			assert_true(SimFatia.common_ok(SimFatia.POLICIES[i], ms[i]), "%s %s: %.1f s, %.0f%%" % [str(c["enc"]), str(SimFatia.POLICIES[i]), ms[i].mean_duration(), ms[i].win_rate() * 100.0])

func test_scenario_uses_fatia_data_and_the_kit() -> void:
	var s: SimScenario = SimFatia.make_scenario(SimFatia.BOSS_ENC, 5, &"smart", 1, "t")
	assert_eq(s.enemies.size(), 3)
	assert_eq(s.heroes.size(), 4)
	assert_eq(s.items.size(), SimFatia.BOSS_KIT.size())
	assert_eq(SimFatia.make_scenario("enc_f1", 1, &"basic", 1, "t").items.size(), SimFatia.KIT.size())

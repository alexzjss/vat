extends GutTest

func test_report_has_header_and_one_row_per_option() -> void:
	var cases: Array[Dictionary] = [{"level": 1, "enc": "X+Y", "policy": &"basic"}]
	var ids: Array[String] = ["F12"]
	var r: Dictionary = SimReport.build(ids, cases, 2)
	var md: String = r["markdown"]
	assert_true(md.contains(SimMetrics.header()))
	assert_true(md.contains("## Metas"))
	assert_true(md.contains("F12-A - N1 X+Y basic"))
	assert_true(md.contains("F12-B - N1 X+Y basic"))
	assert_false(md.contains("F12-C"))
	# Cada opcao: uma linha no detalhe, com 2 execucoes.
	var rows: int = 0
	for line: String in md.split("\n"):
		if line.begins_with("| F12-") and line.contains(" - N1 X+Y basic | 2 |"):
			rows += 1
	assert_eq(rows, 2)
	var csv_lines: PackedStringArray = (r["csv"] as String).strip_edges().split("\n")
	assert_eq(csv_lines.size(), 4)
	assert_true(csv_lines[2].begins_with("F12,A,1,X+Y,basic,2,"))

func test_report_is_deterministic() -> void:
	var cases: Array[Dictionary] = [{"level": 1, "enc": "X+Y", "policy": &"smart"}]
	var ids: Array[String] = ["F6"]
	assert_eq(SimReport.build(ids, cases, 2)["csv"], SimReport.build(ids, cases, 2)["csv"])

func test_hard_family_present_and_scaled() -> void:
	var cases: Array[Dictionary] = [SimReport.hard_case(1.5, &"basic")]
	var ids: Array[String] = ["F12"]
	var r: Dictionary = SimReport.build(ids, cases, 2)
	assert_true((r["markdown"] as String).contains("N1 X+Y+Z difícil ×1.5 basic"))
	assert_true((r["csv"] as String).contains("F12,B,1,X+Y+Z difícil ×1.5,basic,2,"))
	var d := load("res://data/test/enemies/inimigo_x.tres") as EnemyDef
	var e: EnemyDef = SimReport.scaled_enemy(d, 2.0)
	assert_eq(e.base.strength, d.base.strength * 2)
	assert_eq(d.base.strength, 27)
	assert_eq(e.base.strength, 54, "2 x 27")
	assert_eq(SimReport.default_cases().size(), 12, "familia dificil desligada por padrao")
	assert_eq(SimReport.default_cases(1.125, 5).size(), 14)

func test_config_all_a_is_m5a_baseline() -> void:
	var c: BalanceConfig = SimScenario.config_all_a()
	assert_eq(c.dr_mode, BalanceConfig.DrMode.A)
	assert_eq(c.hp_mode, BalanceConfig.HpMode.A)
	assert_eq(c.ap_mode, BalanceConfig.ApMode.A)
	assert_eq(c.damage_mode, BalanceConfig.DamageMode.A)
	assert_eq(c.variance_mode, BalanceConfig.VarianceMode.A)
	assert_eq(c.dodge_mode, BalanceConfig.DodgeMode.A)
	assert_eq(c.xp_mode, BalanceConfig.XpMode.A)
	assert_eq(c.max_level, 0)
	assert_eq(c.poison_mode, BalanceConfig.PoisonMode.A)
	assert_eq(c.revive_mode, BalanceConfig.ReviveMode.A)
	assert_eq(c.duration_mode, BalanceConfig.DurationMode.A)

func test_config_chosen_comes_from_balance_tres() -> void:
	var c: BalanceConfig = SimScenario.config_chosen()
	var tres := load("res://data/test/balance.tres") as BalanceConfig
	assert_eq(c.hp_mode, tres.hp_mode)
	assert_eq(c.damage_mode, BalanceConfig.DamageMode.B)
	assert_eq(c.xp_mode, BalanceConfig.XpMode.C)
	assert_ne(c, tres, "copia: tuning do simulador nao altera o recurso carregado")

func test_scenarios_declare_their_baseline() -> void:
	var c: Dictionary = {"level": 1, "enc": "X+Y", "policy": &"basic"}
	var a: SimScenario = SimReport.make_scenario(c, 1, "", 0, "a")
	var ch: SimScenario = SimReport.make_scenario(c, 1, "", 0, "c", true)
	assert_eq(a.baseline, SimScenario.BASELINE_ALL_A)
	assert_eq(a.cfg.hp_mode, BalanceConfig.HpMode.A)
	assert_eq(ch.baseline, SimScenario.BASELINE_CHOSEN)
	assert_eq(ch.cfg.hp_mode, BalanceConfig.HpMode.B)
	var md: String = SimReport.build(["F12"] as Array[String], [c] as Array[Dictionary], 1)["markdown"]
	assert_true(md.contains(SimScenario.BASELINE_ALL_A))

func test_target_cases_and_final_report() -> void:
	assert_eq(SimReport.target_cases().size(), 8)
	var r: Dictionary = SimReport.build_final(1)
	assert_true((r["markdown"] as String).contains(SimScenario.BASELINE_CHOSEN))
	assert_true((r["markdown"] as String).contains("## Antes x depois"))

# --- Chefe (M11): cenario so de relatorio e politica smart minima ---

func test_boss_cases_and_section_in_the_final_report() -> void:
	assert_eq(SimReport.boss_cases().size(), 2)
	var r: Dictionary = SimReport.build_final(1)
	assert_true((r["markdown"] as String).contains("## Chefe (M11)"))
	assert_true((r["csv"] as String).contains("BOSS,escolhido"))

func test_boss_scenario_ends_every_run() -> void:
	var ms: Array[SimMetrics] = SimReport.run_boss(1)
	assert_eq(ms.size(), 2)
	for m: SimMetrics in ms:
		assert_eq(m.timeouts, 0)
		assert_eq(m.wins + m.losses, 1)

func _boss_battle() -> BattleState:
	var cfg: BalanceConfig = Fixtures.cfg()
	var core_def: EnemyDef = Fixtures.enemy_def(&"core", Stats.make(5, 1, 10, 5))
	core_def.role = EnemyDef.Role.CORE
	var arm_def: EnemyDef = Fixtures.enemy_def(&"arm", Stats.make(5, 1, 10, 5))
	arm_def.role = EnemyDef.Role.PART
	arm_def.shields_core = true
	var core: Combatant = Combatant.from_enemy(core_def, &"core", Vector2.ZERO, cfg)
	var arm: Combatant = Combatant.from_enemy(arm_def, &"arm", Vector2.ZERO, cfg)
	core.hp = 1
	var hero: Combatant = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"h", Stats.make(10, 5, 10, 1)), cfg), Vector2.ZERO)
	return BattleState.create(cfg, ScriptedDice.new(), [hero], [core, arm])

func test_smart_does_not_attack_a_shielded_core_but_basic_does() -> void:
	var b: BattleState = _boss_battle()
	var smart: PendingAction = SimPolicy.decide(SelectionSession.new(b.heroes[0], b), b, &"smart")
	assert_eq(smart.center.id, &"arm", "smart ataca a parte que protege")
	var basic: PendingAction = SimPolicy.decide(SelectionSession.new(b.heroes[0], b), b, &"basic")
	assert_eq(basic.center.id, &"core", "basic segue o menor HP")
	b.enemies[1].hp = 0
	var open: PendingAction = SimPolicy.decide(SelectionSession.new(b.heroes[0], b), b, &"smart")
	assert_eq(open.center.id, &"core", "sem a parte de pe o nucleo e alvo normal")

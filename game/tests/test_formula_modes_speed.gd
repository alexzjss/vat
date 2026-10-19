extends GutTest
var cfg: BalanceConfig
func before_each() -> void:
	cfg = Fixtures.cfg()
func _c(id: StringName, spd: int) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1, spd, 1, 1)), id, Vector2.ZERO, cfg)
func test_speed_modes_default_to_a() -> void:
	assert_eq(cfg.atb_mode, BalanceConfig.AtbMode.A)
	assert_eq(cfg.dodge_mode, BalanceConfig.DodgeMode.A)
func test_atb_mode_a_unchanged() -> void:
	assert_almost_eq(StatCalculator.atb_rate(_c(&"a", 10), cfg), 0.4, 0.0001)
	assert_almost_eq(StatCalculator.atb_rate(_c(&"a", 10), cfg, 99.0), 0.4, 0.0001)
func test_atb_mode_b_relative_to_average() -> void:
	cfg.atb_mode = BalanceConfig.AtbMode.B
	assert_almost_eq(StatCalculator.atb_rate(_c(&"a", 10), cfg, 15.0), 0.1375, 0.0001)
	assert_almost_eq(StatCalculator.atb_rate(_c(&"b", 20), cfg, 15.0), 0.2625, 0.0001)
func test_atb_mode_b_single_combatant_is_base_rate() -> void:
	cfg.atb_mode = BalanceConfig.AtbMode.B
	assert_almost_eq(StatCalculator.atb_rate(_c(&"a", 10), cfg, 10.0), 0.2, 0.0001)
func test_atb_mode_b_zero_speed() -> void:
	cfg.atb_mode = BalanceConfig.AtbMode.B
	assert_almost_eq(StatCalculator.atb_rate(_c(&"a", 0), cfg, 0.0), 0.2, 0.0001)
func test_atb_mode_b_falls_back_to_a_without_average() -> void:
	cfg.atb_mode = BalanceConfig.AtbMode.B
	assert_almost_eq(StatCalculator.atb_rate(_c(&"a", 10), cfg), 0.4, 0.0001)
func test_atb_mode_c_saturating() -> void:
	cfg.atb_mode = BalanceConfig.AtbMode.C
	assert_almost_eq(StatCalculator.atb_rate(_c(&"a", 0), cfg), 0.25, 0.0001)
	assert_almost_eq(StatCalculator.atb_rate(_c(&"a", 5), cfg), 0.3125, 0.0001)
	assert_almost_eq(StatCalculator.atb_rate(_c(&"a", 20), cfg), 0.5, 0.0001)
func test_atb_haste_and_min_rate_apply_in_every_mode() -> void:
	cfg.atb_mode = BalanceConfig.AtbMode.C
	var c := _c(&"a", 0)
	c.statuses.append(ActiveStatus.create(Fixtures.status_def(StatusDef.Kind.HASTE, 2, 50), &"x", 1))
	assert_almost_eq(StatCalculator.atb_rate(c, cfg), 0.375, 0.0001)
	var d := _c(&"d", 0)
	d.statuses.append(ActiveStatus.create(Fixtures.status_def(StatusDef.Kind.SLOW, 2, 90), &"x", 1))
	assert_almost_eq(StatCalculator.atb_rate(d, cfg), 0.05, 0.0001)
func test_clock_mode_b_uses_living_average() -> void:
	cfg.atb_mode = BalanceConfig.AtbMode.B
	var a := _c(&"a", 10); var b := _c(&"b", 20); var dead := _c(&"z", 1000)
	dead.hp = 0
	var q := ReadyQueue.new(cfg, ScriptedDice.new())
	AtbClock.new(cfg).advance(1.0, [a, b, dead], q)
	assert_almost_eq(a.atb, 0.1375, 0.0001)
	assert_almost_eq(b.atb, 0.2625, 0.0001)
func test_clock_mode_b_all_zero_speed() -> void:
	cfg.atb_mode = BalanceConfig.AtbMode.B
	var a := _c(&"a", 0)
	var q := ReadyQueue.new(cfg, ScriptedDice.new())
	AtbClock.new(cfg).advance(1.0, [a], q)
	assert_almost_eq(a.atb, 0.2, 0.0001)
func test_dodge_mode_a_unchanged() -> void:
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 10), cfg), 0.05, 0.0001)
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 10), cfg, _c(&"x", 99)), 0.05, 0.0001)
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 100), cfg), 0.15, 0.0001)
func test_dodge_mode_b_speed_difference() -> void:
	cfg.dodge_mode = BalanceConfig.DodgeMode.B
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 30), cfg, _c(&"x", 10)), 0.075, 0.0001) # 30 -> 25 after diminishing returns, minus 10
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 60), cfg, _c(&"x", 0)), 0.15, 0.0001)
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 5), cfg, _c(&"x", 20)), 0.0, 0.0001)
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 0), cfg, _c(&"x", 0)), 0.0, 0.0001)
func test_dodge_mode_b_null_attacker_falls_back_to_a() -> void:
	cfg.dodge_mode = BalanceConfig.DodgeMode.B
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 10), cfg), 0.05, 0.0001)
func test_dodge_mode_c_is_zero() -> void:
	cfg.dodge_mode = BalanceConfig.DodgeMode.C
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 100), cfg, _c(&"x", 0)), 0.0, 0.0001)
	assert_almost_eq(StatCalculator.dodge_chance(_c(&"t", 100), cfg), 0.0, 0.0001)

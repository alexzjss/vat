extends GutTest
var cfg: BalanceConfig
func before_each() -> void:
	cfg = Fixtures.cfg()
func _c(stats: Stats, level := 1) -> Combatant:
	var h := HeroState.create(Fixtures.hero_def(&"a", stats), cfg)
	h.level = level
	return Combatant.from_hero(h, Vector2.ZERO)
func test_diminishing_returns_above_soft_cap() -> void:
	assert_eq(StatCalculator.diminishing(20, cfg), 20)
	assert_eq(StatCalculator.diminishing(30, cfg), 25)
	assert_eq(StatCalculator.diminishing(31, cfg), 25)
func test_equipment_does_not_bypass_diminishing() -> void:
	var c := _c(Stats.make(20, 0, 0, 0))
	c.equipment_mods = Stats.make(10, 0, 0, 0)
	assert_eq(StatCalculator.effective(c, &"strength", cfg), 25)
func test_derived_values() -> void:
	var c := _c(Stats.make(0, 10, 4, 6), 3)
	assert_eq(StatCalculator.hp_max(c, cfg), 55)
	assert_eq(StatCalculator.ap_max(c, cfg), 30)
	assert_almost_eq(StatCalculator.atb_rate(c, cfg), 0.4, 0.0001)
	assert_almost_eq(StatCalculator.dodge_chance(c, cfg), 0.05, 0.0001)
func test_dodge_is_capped() -> void:
	assert_almost_eq(StatCalculator.dodge_chance(_c(Stats.make(0, 99, 1, 0)), cfg), 0.15, 0.0001)
func test_effective_never_negative_and_atb_has_floor() -> void:
	var c := _c(Stats.make(0, 0, 1, 0))
	c.equipment_mods = Stats.make(-5, -50, 0, 0)
	assert_eq(StatCalculator.effective(c, &"strength", cfg), 0)
	cfg.atb_base_rate = 0.0
	assert_almost_eq(StatCalculator.atb_rate(c, cfg), cfg.atb_min_rate, 0.0001)

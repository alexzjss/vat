extends GutTest
var cfg: BalanceConfig
func before_each() -> void:
	cfg = Fixtures.cfg()
func _c(stats: Stats, level := 1) -> Combatant:
	var h := HeroState.create(Fixtures.hero_def(&"a", stats), cfg)
	h.level = level
	return Combatant.from_hero(h, Vector2.ZERO)
func test_default_modes_are_a() -> void:
	var fresh := BalanceConfig.new()
	assert_eq(fresh.dr_mode, BalanceConfig.DrMode.A)
	assert_eq(fresh.hp_mode, BalanceConfig.HpMode.A)
	assert_eq(fresh.ap_mode, BalanceConfig.ApMode.A)
	assert_eq(cfg.dr_mode, BalanceConfig.DrMode.A)
func test_dr_mode_a_unchanged() -> void:
	assert_eq(StatCalculator.diminishing(30, cfg), 25)
func test_dr_mode_b_bands() -> void:
	cfg.dr_mode = BalanceConfig.DrMode.B
	assert_eq(StatCalculator.diminishing(0, cfg), 0)
	assert_eq(StatCalculator.diminishing(10, cfg), 10)
	assert_eq(StatCalculator.diminishing(20, cfg), 20)
	assert_eq(StatCalculator.diminishing(30, cfg), 25)
	assert_eq(StatCalculator.diminishing(40, cfg), 30)
	assert_eq(StatCalculator.diminishing(50, cfg), 32)
	assert_eq(StatCalculator.diminishing(100, cfg), 45)
func test_dr_mode_c_smooth() -> void:
	cfg.dr_mode = BalanceConfig.DrMode.C
	assert_eq(StatCalculator.diminishing(0, cfg), 0)
	assert_eq(StatCalculator.diminishing(-3, cfg), -3)
	assert_eq(StatCalculator.diminishing(10, cfg), 15)
	assert_eq(StatCalculator.diminishing(30, cfg), 30)
	assert_eq(StatCalculator.diminishing(90, cfg), 45)
	assert_eq(StatCalculator.diminishing(1000, cfg), 58)
func test_hp_modes() -> void:
	var c := _c(Stats.make(0, 10, 4, 6), 3)
	assert_eq(StatCalculator.hp_max(c, cfg), 55)
	cfg.hp_mode = BalanceConfig.HpMode.B
	assert_eq(StatCalculator.hp_max(c, cfg), 78)
	cfg.hp_mode = BalanceConfig.HpMode.C
	assert_eq(StatCalculator.hp_max(c, cfg), 76)
func test_hp_modes_zero_vitality() -> void:
	var c := _c(Stats.make(0, 0, 0, 0), 1)
	cfg.hp_mode = BalanceConfig.HpMode.B
	assert_eq(StatCalculator.hp_max(c, cfg), 34)
	cfg.hp_mode = BalanceConfig.HpMode.C
	assert_eq(StatCalculator.hp_max(c, cfg), 32)
func test_ap_modes() -> void:
	var c := _c(Stats.make(0, 10, 4, 6), 3)
	assert_eq(StatCalculator.ap_max(c, cfg), 30)
	cfg.ap_mode = BalanceConfig.ApMode.B
	assert_eq(StatCalculator.ap_max(c, cfg), 27)
	cfg.ap_mode = BalanceConfig.ApMode.C
	assert_eq(StatCalculator.ap_max(c, cfg), 27)
func test_ap_modes_zero_aura() -> void:
	var c := _c(Stats.make(0, 0, 0, 0), 3)
	cfg.ap_mode = BalanceConfig.ApMode.B
	assert_eq(StatCalculator.ap_max(c, cfg), 3)
	cfg.ap_mode = BalanceConfig.ApMode.C
	assert_eq(StatCalculator.ap_max(c, cfg), 0)
func test_effective_uses_dr_mode() -> void:
	cfg.dr_mode = BalanceConfig.DrMode.B
	var c := _c(Stats.make(50, 0, 0, 0))
	assert_eq(StatCalculator.effective(c, &"strength", cfg), 32)

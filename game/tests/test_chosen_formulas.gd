extends GutTest

func _assert_chosen(c: BalanceConfig) -> void:
	assert_eq(c.dr_mode, BalanceConfig.DrMode.B)
	assert_eq(c.hp_mode, BalanceConfig.HpMode.B)
	assert_eq(c.ap_mode, BalanceConfig.ApMode.B)
	assert_eq(c.atb_mode, BalanceConfig.AtbMode.A)
	assert_eq(c.damage_mode, BalanceConfig.DamageMode.B)
	assert_eq(c.variance_mode, BalanceConfig.VarianceMode.B)
	assert_eq(c.dodge_mode, BalanceConfig.DodgeMode.B)
	assert_eq(c.xp_mode, BalanceConfig.XpMode.C)
	assert_eq(c.max_level, 99)
	assert_eq(c.revive_mode, BalanceConfig.ReviveMode.A)
	assert_eq(c.poison_mode, BalanceConfig.PoisonMode.B)
	assert_eq(c.duration_mode, BalanceConfig.DurationMode.A)

func test_game_uses_chosen_modes() -> void:
	_assert_chosen(load("res://data/test/balance.tres") as BalanceConfig)

func test_balance_config_defaults_are_chosen() -> void:
	_assert_chosen(BalanceConfig.new())

func test_fixtures_pin_mode_a() -> void:
	var c := Fixtures.cfg()
	assert_eq(c.dr_mode, BalanceConfig.DrMode.A)
	assert_eq(c.hp_mode, BalanceConfig.HpMode.A)
	assert_eq(c.ap_mode, BalanceConfig.ApMode.A)
	assert_eq(c.atb_mode, BalanceConfig.AtbMode.A)
	assert_eq(c.damage_mode, BalanceConfig.DamageMode.A)
	assert_eq(c.variance_mode, BalanceConfig.VarianceMode.A)
	assert_eq(c.dodge_mode, BalanceConfig.DodgeMode.A)
	assert_eq(c.xp_mode, BalanceConfig.XpMode.A)
	assert_eq(c.max_level, 0)
	assert_eq(c.revive_mode, BalanceConfig.ReviveMode.A)
	assert_eq(c.poison_mode, BalanceConfig.PoisonMode.A)
	assert_eq(c.duration_mode, BalanceConfig.DurationMode.A)

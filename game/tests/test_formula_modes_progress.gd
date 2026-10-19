extends GutTest
var cfg: BalanceConfig
var ledger: ContributionLedger
var hero: Combatant
var foe: Combatant
func before_each() -> void:
	cfg = Fixtures.cfg()
	ledger = ContributionLedger.new()
	hero = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(5, 5, 5, 5)), cfg), Vector2.ZERO)
	foe = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(5, 5, 5, 5)), &"x", Vector2.ZERO, cfg)
func _sys(rolls: Array[float] = []) -> StatusSystem:
	return StatusSystem.new(cfg, ledger, ScriptedDice.new(rolls))
func _hs() -> HeroState:
	return HeroState.create(Fixtures.hero_def(&"a", Stats.make(5, 5, 5, 5)), cfg)

func test_defaults_are_mode_a() -> void:
	var c := BalanceConfig.new()
	assert_eq(c.xp_mode, BalanceConfig.XpMode.A)
	assert_eq(c.revive_mode, BalanceConfig.ReviveMode.A)
	assert_eq(c.poison_mode, BalanceConfig.PoisonMode.A)
	assert_eq(c.duration_mode, BalanceConfig.DurationMode.A)
	assert_eq(c.max_level, 0)

# XP
func test_xp_mode_a() -> void:
	assert_eq(XpCalculator.xp_for_level(5, cfg), cfg.xp_coef * 16)
func test_xp_mode_b() -> void:
	cfg.xp_mode = BalanceConfig.XpMode.B
	assert_eq(XpCalculator.xp_for_level(5, cfg), 25 * 16)
func test_xp_mode_c() -> void:
	cfg.xp_mode = BalanceConfig.XpMode.C
	assert_eq(XpCalculator.xp_for_level(5, cfg), 15 * 16 + 30 * 4)
func test_xp_level_one_is_zero_all_modes() -> void:
	for m: int in [BalanceConfig.XpMode.A, BalanceConfig.XpMode.B, BalanceConfig.XpMode.C]:
		cfg.xp_mode = m as BalanceConfig.XpMode
		assert_eq(XpCalculator.xp_for_level(1, cfg), 0)
func test_max_level_caps_and_discards_excess() -> void:
	cfg.max_level = 3
	var h: HeroState = _hs()
	var gained: int = XpCalculator.grant(h, 100000, cfg)
	assert_eq(h.level, 3)
	assert_eq(gained, 2)
	assert_eq(h.xp, XpCalculator.xp_for_level(3, cfg))
	assert_eq(h.pending_points, 2) # levels 2 and 3, 1 point each
func test_max_level_already_reached_gains_nothing() -> void:
	cfg.max_level = 3
	var h: HeroState = _hs()
	XpCalculator.grant(h, 100000, cfg)
	assert_eq(XpCalculator.grant(h, 500, cfg), 0)
	assert_eq(h.level, 3)
	assert_eq(h.xp, XpCalculator.xp_for_level(3, cfg))
func test_max_level_below_cap_keeps_xp() -> void:
	cfg.max_level = 10
	var h: HeroState = _hs()
	XpCalculator.grant(h, 45, cfg)
	assert_eq(h.xp, 45)
func test_max_level_zero_is_uncapped() -> void:
	var h: HeroState = _hs()
	XpCalculator.grant(h, 10 * 98 * 98, cfg)
	assert_eq(h.level, 99)

# Revive
func _rev() -> EffectDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.REVIVE
	e.potency = 0.25
	return e
func _revive(hp_max: int) -> int:
	return EffectMath.revive_hp(_rev(), hp_max, cfg)
func test_revive_mode_a() -> void:
	assert_eq(_revive(100), 25)
	assert_eq(_revive(1), 1)
func test_revive_mode_b() -> void:
	cfg.revive_mode = BalanceConfig.ReviveMode.B
	assert_eq(_revive(100), 50)
	assert_eq(_revive(1), 1)
func test_revive_mode_c() -> void:
	cfg.revive_mode = BalanceConfig.ReviveMode.C
	assert_eq(_revive(100), 20)
	assert_eq(_revive(0), 10)
func test_revive_two_arg_call_is_mode_a() -> void:
	assert_eq(EffectMath.revive_hp(_rev(), 100), 25)

# Poison
func _poison_dmg(hp: int, potency: int = 3) -> int:
	var p := Fixtures.status_def(StatusDef.Kind.POISON, 4, potency)
	p.id = &"poison"
	var sys := _sys([0.0])
	sys.apply(foe, p, hero, 1.0, [foe])
	foe.hp = hp
	return sys.on_atb_full(foe, [foe]).poison_damage
func test_poison_mode_a() -> void:
	assert_eq(_poison_dmg(100), 3)
func test_poison_mode_b() -> void:
	cfg.poison_mode = BalanceConfig.PoisonMode.B
	var hpm: int = StatCalculator.hp_max(foe, cfg)
	assert_eq(_poison_dmg(hpm), maxi(1, floori(hpm * 0.06)))
func test_poison_mode_c() -> void:
	cfg.poison_mode = BalanceConfig.PoisonMode.C
	var hpm: int = StatCalculator.hp_max(foe, cfg)
	assert_eq(_poison_dmg(hpm), 3 + floori(hpm * 0.06))
func test_poison_caps_to_current_hp_all_modes() -> void:
	for m: int in [BalanceConfig.PoisonMode.A, BalanceConfig.PoisonMode.B, BalanceConfig.PoisonMode.C]:
		cfg.poison_mode = m as BalanceConfig.PoisonMode
		before_each()
		cfg.poison_mode = m as BalanceConfig.PoisonMode
		assert_eq(_poison_dmg(1), 1)
		assert_eq(foe.hp, 0)
func test_poison_mode_b_minimum_one() -> void:
	cfg.poison_mode = BalanceConfig.PoisonMode.B
	cfg.poison_pct = 0.0
	assert_eq(_poison_dmg(50), 1)

# Durations
func test_duration_mode_a_uses_data() -> void:
	var s := Fixtures.status_def(StatusDef.Kind.SLEEP, 7)
	s.id = &"sleep"
	_sys([0.0]).apply(foe, s, hero, 1.0, [foe])
	assert_eq(foe.statuses[0].remaining, 7)
func test_duration_mode_b_uses_table() -> void:
	cfg.duration_mode = BalanceConfig.DurationMode.B
	var s := Fixtures.status_def(StatusDef.Kind.SLEEP, 7)
	s.id = &"sleep"
	_sys([0.0]).apply(foe, s, hero, 1.0, [foe])
	assert_eq(foe.statuses[0].remaining, 2)
func test_duration_mode_b_missing_id_uses_data() -> void:
	cfg.duration_mode = BalanceConfig.DurationMode.B
	var s := Fixtures.status_def(StatusDef.Kind.SLEEP, 7)
	s.id = &"unknown"
	_sys([0.0]).apply(foe, s, hero, 1.0, [foe])
	assert_eq(foe.statuses[0].remaining, 7)
func test_duration_mode_b_renew_and_forced() -> void:
	cfg.duration_mode = BalanceConfig.DurationMode.B
	var p := Fixtures.status_def(StatusDef.Kind.POISON, 9, 3)
	p.id = &"poison"
	var sys := _sys([0.0, 0.0])
	sys.apply(foe, p, hero, 1.0, [foe])
	foe.statuses[0].remaining = 1
	sys.apply(foe, p, hero, 1.0, [foe])
	assert_eq(foe.statuses[0].remaining, 4)
	sys.apply_forced(hero, p)
	assert_eq(hero.statuses[0].remaining, 4)

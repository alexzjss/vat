extends GutTest
var cfg: BalanceConfig
var e: EffectDef
func before_each() -> void:
	cfg = Fixtures.cfg()
	e = Fixtures.hit(3.0).effects[0]
func _dmg(roll: float = 0.5, str_eff: int = 10, vit: int = 4, equip: int = 0) -> int:
	return EffectMath.damage(e, str_eff, vit, equip, cfg, ScriptedDice.new([roll]))
func test_modes_default_to_a() -> void:
	assert_eq(BalanceConfig.new().damage_mode, BalanceConfig.DamageMode.A)
	assert_eq(BalanceConfig.new().variance_mode, BalanceConfig.VarianceMode.A)
func test_damage_mode_a_unchanged() -> void:
	assert_eq(_dmg(), 28) # 30 - floor(2.0)
func test_damage_mode_b_ratio() -> void:
	cfg.damage_mode = BalanceConfig.DamageMode.B
	assert_eq(_dmg(), 27) # floor(30*20/22)
func test_damage_mode_c_equipment() -> void:
	cfg.damage_mode = BalanceConfig.DamageMode.C
	assert_eq(_dmg(0.5, 10, 4, 6), 22) # 30 - floor(2 + 6)
	assert_eq(_dmg(0.5, 10, 4, 0), 28)
func test_damage_zero_defense_all_modes() -> void:
	assert_eq(_dmg(0.5, 10, 0), 30)
	cfg.damage_mode = BalanceConfig.DamageMode.B
	assert_eq(_dmg(0.5, 10, 0), 30)
	cfg.damage_mode = BalanceConfig.DamageMode.C
	assert_eq(_dmg(0.5, 10, 0, 0), 30)
func test_damage_minimum_one_all_modes() -> void:
	for m: int in [BalanceConfig.DamageMode.A, BalanceConfig.DamageMode.B, BalanceConfig.DamageMode.C]:
		cfg.damage_mode = m as BalanceConfig.DamageMode
		assert_eq(_dmg(0.5, 0, 50, 50), 1)
func test_fixed_scale_ignores_attribute() -> void:
	e.scale = EffectDef.Scale.FIXED
	e.potency = 12.0
	assert_eq(_dmg(0.5, 99, 0), 12)
func test_variance_b_bounds() -> void:
	cfg.variance_mode = BalanceConfig.VarianceMode.B
	assert_eq(_dmg(1.0), 29) # floor(28*1.06)
	assert_eq(_dmg(0.0), 26) # floor(28*0.94)
	assert_eq(_dmg(0.5), 28)
func test_variance_c_bounds() -> void:
	cfg.variance_mode = BalanceConfig.VarianceMode.C
	assert_eq(_dmg(1.0), 31) # floor(28*1.12)
	assert_eq(_dmg(0.0), 24) # floor(28*0.88)
func test_variance_applies_before_minimum() -> void:
	cfg.variance_mode = BalanceConfig.VarianceMode.C
	assert_eq(_dmg(0.0, 0, 50), 1)
func test_variance_mode_a_consumes_no_roll() -> void:
	var d := ScriptedDice.new([0.25, 0.75])
	EffectMath.damage(e, 10, 4, 0, cfg, d)
	assert_eq(d.roll(), 0.25)
func test_variance_modes_b_c_consume_one_roll() -> void:
	cfg.variance_mode = BalanceConfig.VarianceMode.B
	var d := ScriptedDice.new([0.25, 0.75])
	EffectMath.damage(e, 10, 4, 0, cfg, d)
	assert_eq(d.roll(), 0.75)
func test_variance_deterministic_with_seed() -> void:
	cfg.variance_mode = BalanceConfig.VarianceMode.C
	var a: Array[int] = []
	var b: Array[int] = []
	var d1 := Dice.new(7)
	var d2 := Dice.new(7)
	for i in 5:
		a.append(EffectMath.damage(e, 10, 4, 0, cfg, d1))
		b.append(EffectMath.damage(e, 10, 4, 0, cfg, d2))
	assert_eq(a, b)
func test_executor_uses_target_equipment_and_variance() -> void:
	cfg.damage_mode = BalanceConfig.DamageMode.C
	cfg.variance_mode = BalanceConfig.VarianceMode.B
	var h := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10,0,2,4)), cfg), Vector2(0,0))
	var x := Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1,0,4,1)), &"x", Vector2(100,0), cfg)
	x.equipment_mods = Stats.make(0, 0, 6, 0)
	var b := BattleState.create(cfg, ScriptedDice.new([1.0]), [h], [x])
	var a := PendingAction.new(); a.actor = h; a.ability = Fixtures.hit(3.0); a.center = x; a.center_pos = x.position
	var hp0 := x.hp
	ActionExecutor.apply(a, b)
	# vit efetiva 4+6=10 -> defesa 5 + equip 6 = 11; 30-11=19; floor(19*1.06)=20
	assert_eq(x.hp, hp0 - 20)

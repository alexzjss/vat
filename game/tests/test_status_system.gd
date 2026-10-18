extends GutTest
var cfg: BalanceConfig; var ledger: ContributionLedger
var hero: Combatant; var foe: Combatant
func _sys(rolls: Array[float] = []) -> StatusSystem:
	return StatusSystem.new(cfg, ledger, ScriptedDice.new(rolls))
func before_each() -> void:
	cfg = Fixtures.cfg(); ledger = ContributionLedger.new()
	hero = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(5,5,5,5)), cfg), Vector2.ZERO)
	foe = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(5,5,5,5)), &"x", Vector2.ZERO, cfg)
func test_immunity_blocks_and_gives_no_contribution() -> void:
	foe.enemy_def.immunities = [&"sleep"]
	var s := Fixtures.status_def(StatusDef.Kind.SLEEP, 2); s.id = &"sleep"; s.apply_contribution = 10
	assert_eq(_sys().apply(foe, s, hero, 1.0, [foe]), StatusSystem.ApplyResult.IMMUNE)
	assert_eq(ledger.total_against(&"x"), 0.0)
func test_partial_resistance_reduces_chance() -> void:
	foe.enemy_def.resistances = {&"sleep": 0.5}
	var s := Fixtures.status_def(StatusDef.Kind.SLEEP, 2); s.id = &"sleep"
	assert_eq(_sys([0.6]).apply(foe, s, hero, 1.0, [foe]), StatusSystem.ApplyResult.RESISTED)
	assert_eq(_sys([0.4]).apply(foe, s, hero, 1.0, [foe]), StatusSystem.ApplyResult.APPLIED)
func test_reapply_renews_without_stacking_and_credits_added_fraction() -> void:
	var p := Fixtures.status_def(StatusDef.Kind.POISON, 4, 3); p.id = &"poison"; p.apply_contribution = 20
	var sys := _sys([0.0, 0.0])
	sys.apply(foe, p, hero, 1.0, [foe])
	foe.statuses[0].remaining = 1
	assert_eq(sys.apply(foe, p, hero, 1.0, [foe]), StatusSystem.ApplyResult.RENEWED)
	assert_eq(foe.statuses.size(), 1)
	assert_eq(foe.statuses[0].remaining, 4)
	assert_eq(ledger.get_points(&"a", &"x"), 20.0 + 15.0)
func test_sleep_loses_turns_then_expires_without_banked_action() -> void:
	var s := Fixtures.status_def(StatusDef.Kind.SLEEP, 2); s.id = &"sleep"
	var sys := _sys([0.0]); sys.apply(foe, s, hero, 1.0, [foe])
	assert_true(sys.on_atb_full(foe, [foe]).lost_turn)
	assert_true(sys.on_atb_full(foe, [foe]).lost_turn)
	assert_false(sys.on_atb_full(foe, [foe]).lost_turn)
	assert_eq(ledger.get_points(&"a", &"x"), 2.0 * cfg.control_value_per_turn)
func test_sleep_ends_on_hp_damage_paralysis_does_not() -> void:
	var sl := Fixtures.status_def(StatusDef.Kind.SLEEP, 3); sl.id = &"sleep"
	var pa := Fixtures.status_def(StatusDef.Kind.PARALYSIS, 3); pa.id = &"para"
	var sys := _sys([0.0, 0.0])
	sys.apply(foe, sl, hero, 1.0, [foe]); sys.apply(foe, pa, hero, 1.0, [foe])
	sys.on_hp_damage(foe)
	assert_eq(foe.statuses.map(func(a: ActiveStatus) -> StringName: return a.def.id), [&"para"])
func test_poison_ticks_on_each_atb_full_and_credits_source() -> void:
	var p := Fixtures.status_def(StatusDef.Kind.POISON, 3, 4); p.id = &"poison"
	var sys := _sys([0.0]); sys.apply(foe, p, hero, 1.0, [foe])
	var hp0 := foe.hp
	assert_eq(sys.on_atb_full(foe, [foe]).poison_damage, 4)
	sys.on_atb_full(foe, [foe])
	assert_eq(foe.hp, hp0 - 8)
	assert_eq(ledger.get_points(&"a", &"x"), 8.0)
func test_haste_cancels_slow() -> void:
	var slow := Fixtures.status_def(StatusDef.Kind.SLOW, 3, 50); slow.id = &"slow"
	var haste := Fixtures.status_def(StatusDef.Kind.HASTE, 3, 50); haste.id = &"haste"; haste.cancels = [&"slow"]
	var sys := _sys([0.0, 0.0])
	sys.apply(hero, slow, foe, 1.0, [foe]); sys.apply(hero, haste, foe, 1.0, [foe])
	assert_eq(hero.statuses.size(), 1)
	assert_eq(hero.statuses[0].def.id, &"haste")
func test_barrier_absorbs_and_credits_protection() -> void:
	var b := Fixtures.status_def(StatusDef.Kind.BARRIER, 5, 10); b.id = &"barrier"
	var sys := _sys([0.0]); sys.apply(hero, b, hero, 1.0, [foe])
	assert_eq(sys.absorb_with_barrier(hero, 14, foe), 4)
	assert_eq(hero.statuses.size(), 0)
	assert_eq(ledger.get_points(&"a", &"x"), 10.0 + b.apply_contribution)

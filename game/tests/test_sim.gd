extends GutTest

func _eth() -> ItemDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.RESTORE_AP
	e.scale = EffectDef.Scale.FIXED
	e.potency = 5.0
	var it := ItemDef.new()
	it.id = &"ether"
	it.effects = [e]
	return it

func _scenario(policy: StringName) -> SimScenario:
	var s := SimScenario.new()
	s.label = "t_%s" % policy
	s.cfg = Fixtures.cfg()
	s.heroes = [Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1)), Fixtures.hero_def(&"b", Stats.make(8, 5, 5, 3))]
	s.enemies = [Fixtures.enemy_def(&"x", Stats.make(6, 3, 2, 1)), Fixtures.enemy_def(&"y", Stats.make(6, 3, 2, 1))]
	s.hero_level = 3
	s.runs = 3
	s.base_seed = 7
	s.policy = policy
	return s

func _foe(id: StringName, pos: Vector2, cfg: BalanceConfig) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(6, 3, 2, 1)), StringName("%s_0" % id), pos, cfg)

func test_runs_finish_for_both_policies() -> void:
	for p: StringName in [&"basic", &"smart"]:
		var m: SimMetrics = SimRunner.run(_scenario(p))
		assert_eq(m.runs, 3)
		assert_eq(m.wins + m.losses + m.timeouts, 3)
		assert_eq(m.timeouts, 0)
		assert_gt(m.mean_duration(), 0.0)
		assert_gt(m.basic_actions, 0)
		assert_true(m.hero_actions.has(&"a"))

func test_deterministic_same_seed() -> void:
	var a: SimMetrics = SimRunner.run(_scenario(&"basic"))
	var b: SimMetrics = SimRunner.run(_scenario(&"basic"))
	assert_eq(a.to_markdown_row(), b.to_markdown_row())
	assert_eq(a.durations, b.durations)
	assert_eq(a.basic_damage, b.basic_damage)

func test_hero_setup_allocates_points() -> void:
	var s := _scenario(&"basic")
	s.hero_level = 5
	s.alloc_rule = &"main"
	var h: HeroState = SimRunner.make_hero(s.heroes[0], s)
	assert_eq(h.level, 5)
	assert_eq(h.pending_points, 0)
	assert_eq(h.allocated.strength, 6)
	s.alloc_rule = &"even"
	var h2: HeroState = SimRunner.make_hero(s.heroes[0], s)
	assert_eq(h2.allocated.strength + h2.allocated.speed + h2.allocated.vitality + h2.allocated.aura, 6)
	assert_eq(h2.allocated.strength, 2)

func test_smart_policy_always_submits() -> void:
	var cfg := Fixtures.cfg()
	var d := Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1))
	var costly := Fixtures.hit(2.0, AbilityDef.Shape.CIRCLE_TARGET)
	costly.ap_cost = 50
	costly.radius = 200.0
	d.abilities = [costly]
	var hs := HeroState.create(d, cfg)
	hs.ap = 0
	var hero := Combatant.from_hero(hs, Vector2(300, 135))
	var foe: Combatant = _foe(&"x", Vector2(900, 200), cfg)
	var b := BattleState.create(cfg, Dice.new(1), [hero] as Array[Combatant], [foe] as Array[Combatant])
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(hero, b), b, &"smart")
	assert_not_null(a)
	assert_eq(a.ability, hero.basic_attack)
	assert_eq(a.center, foe)

func test_smart_uses_area_when_two_enemies_hit() -> void:
	var cfg := Fixtures.cfg()
	var d := Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 3))
	var area := Fixtures.hit(1.0, AbilityDef.Shape.CIRCLE_TARGET)
	area.id = &"area"
	area.ap_cost = 2
	area.radius = 300.0
	d.abilities = [area]
	var hs := HeroState.create(d, cfg)
	var hero := Combatant.from_hero(hs, Vector2(300, 135))
	var foes: Array[Combatant] = [_foe(&"x", Vector2(900, 200), cfg), _foe(&"y", Vector2(900, 360), cfg)]
	var b := BattleState.create(cfg, Dice.new(1), [hero] as Array[Combatant], foes)
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(hero, b), b, &"smart")
	assert_eq(a.ability, area)
	assert_eq(hero.ap, hs.ap - 2)

func test_smart_uses_ether_without_ap() -> void:
	var cfg := Fixtures.cfg()
	var d := Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1))
	var costly := Fixtures.hit(2.0)
	costly.ap_cost = 3
	d.abilities = [costly]
	var hs := HeroState.create(d, cfg)
	hs.ap = 0
	var hero := Combatant.from_hero(hs, Vector2(300, 135))
	var foe: Combatant = _foe(&"x", Vector2(900, 200), cfg)
	var b := BattleState.create(cfg, Dice.new(1), [hero] as Array[Combatant], [foe] as Array[Combatant])
	var eth: ItemDef = _eth()
	b.inventory.add(eth, 1)
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(hero, b), b, &"smart")
	assert_eq(a.item, eth)
	assert_eq(a.center, hero)

func test_timeout_is_reported() -> void:
	var s := _scenario(&"basic")
	s.runs = 2
	s.cfg.sim_max_seconds = 3.0
	s.enemies = [Fixtures.enemy_def(&"tank", Stats.make(6, 3, 5000, 1))]
	var m: SimMetrics = SimRunner.run(s)
	assert_eq(m.timeouts, 2)
	assert_eq(m.wins, 0)
	assert_eq(m.losses, 0)

func test_markdown_row_and_header() -> void:
	var m: SimMetrics = SimRunner.run(_scenario(&"basic"))
	assert_eq(SimMetrics.header().split("\n").size(), 2)
	assert_true(m.to_markdown_row().begins_with("| t_basic |"))

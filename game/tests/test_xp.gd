extends GutTest
func _e(id: StringName, xp: int) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1,1,1,1), xp), id, Vector2.ZERO, Fixtures.cfg())
func _h(id: StringName) -> Combatant:
	return Combatant.from_hero(HeroState.create(Fixtures.hero_def(id, Stats.make(1,1,1,1)), Fixtures.cfg()), Vector2.ZERO)
func test_per_enemy_floor_and_sum_le_base() -> void:
	var l := ContributionLedger.new()
	l.add(&"a", &"x", 1); l.add(&"b", &"x", 1); l.add(&"c", &"x", 1)
	var xp := XpCalculator.combat_xp(l, [_e(&"x", 100)], [_h(&"a"), _h(&"b"), _h(&"c")], false)
	assert_eq(xp, {&"a": 33, &"b": 33, &"c": 33})
func test_computed_per_enemy_not_on_total() -> void:
	var l := ContributionLedger.new()
	l.add(&"a", &"x", 1); l.add(&"b", &"x", 2); l.add(&"a", &"y", 1)
	var xp := XpCalculator.combat_xp(l, [_e(&"x", 10), _e(&"y", 10)], [_h(&"a"), _h(&"b")], false)
	assert_eq(xp, {&"a": 3 + 10, &"b": 6})
func test_zero_contribution_and_flee() -> void:
	var l := ContributionLedger.new()
	assert_eq(XpCalculator.combat_xp(l, [_e(&"x", 100)], [_h(&"a")], false), {&"a": 0})
	l.add(&"a", &"x", 5)
	assert_eq(XpCalculator.combat_xp(l, [_e(&"x", 100)], [_h(&"a")], true), {&"a": 0})
func test_multi_level_accumulates_points_with_bonus_at_5() -> void:
	var cfg := Fixtures.cfg()
	var h := HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,1,1)), cfg)
	h.level = 3; h.xp = XpCalculator.xp_for_level(3, cfg)
	assert_eq(XpCalculator.grant(h, XpCalculator.xp_for_level(6, cfg) - h.xp, cfg), 3)
	assert_eq(h.level, 6)
	assert_eq(h.pending_points, 1 + 3 + 1)
	assert_false(XpCalculator.allocate(h, &"strength", 6))
	assert_true(XpCalculator.allocate(h, &"strength", 5))
	assert_eq(h.allocated.strength, 5)
func test_allocate_rejects_unknown_attr_and_non_positive() -> void:
	var h := HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,1,1)), Fixtures.cfg())
	h.pending_points = 3
	assert_false(XpCalculator.allocate(h, &"luck", 1))
	assert_false(XpCalculator.allocate(h, &"strength", 0))
	assert_false(XpCalculator.allocate(h, &"strength", -1))
	assert_eq(h.pending_points, 3)
	assert_eq(h.allocated.strength, 0)
func test_downed_hero_receives_xp() -> void:
	var l := ContributionLedger.new()
	l.add(&"a", &"x", 1)
	var a := _h(&"a")
	a.hp = 0
	assert_true(a.is_down())
	assert_eq(XpCalculator.combat_xp(l, [_e(&"x", 50)], [a], false), {&"a": 50})
func test_actor_not_in_heroes_ignored() -> void:
	var l := ContributionLedger.new()
	l.add(&"a", &"x", 1); l.add(&"support", &"x", 1)
	assert_eq(XpCalculator.combat_xp(l, [_e(&"x", 100)], [_h(&"a")], false), {&"a": 50})
func test_grant_no_level_when_insufficient() -> void:
	var cfg := Fixtures.cfg()
	var h := HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,1,1)), cfg)
	assert_eq(XpCalculator.grant(h, 5, cfg), 0)
	assert_eq(h.level, 1)
	assert_eq(h.xp, 5)
	assert_eq(h.pending_points, 0)

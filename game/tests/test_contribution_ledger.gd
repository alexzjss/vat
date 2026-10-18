extends GutTest
func _enemy(id: StringName) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1,1,1,1)), id, Vector2.ZERO, Fixtures.cfg())
func test_add_and_totals() -> void:
	var l := ContributionLedger.new()
	l.add(&"a", &"x", 30); l.add(&"b", &"x", 10); l.add(&"a", &"x", 0)
	assert_eq(l.get_points(&"a", &"x"), 30.0)
	assert_eq(l.total_against(&"x"), 40.0)
func test_ally_benefit_proportional_to_damage_taken() -> void:
	var l := ContributionLedger.new()
	var x := _enemy(&"x"); var y := _enemy(&"y")
	var ally := _enemy(&"ally")
	ally.damage_taken_from = {&"x": 30, &"y": 10}
	l.add_ally_benefit(&"healer", ally, 20, [x, y])
	assert_eq(l.get_points(&"healer", &"x"), 15.0)
	assert_eq(l.get_points(&"healer", &"y"), 5.0)
func test_ally_benefit_split_evenly_without_damage_taken() -> void:
	var l := ContributionLedger.new()
	var ally := _enemy(&"ally")
	l.add_ally_benefit(&"healer", ally, 20, [_enemy(&"x"), _enemy(&"y")])
	assert_eq(l.get_points(&"healer", &"x"), 10.0)
	assert_eq(l.get_points(&"healer", &"y"), 10.0)

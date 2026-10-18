extends GutTest
func test_stats_plus_and_get_attr() -> void:
	var s := Stats.make(1, 2, 3, 4).plus(Stats.make(10, 0, 0, -1))
	assert_eq(s.get_attr(&"strength"), 11)
	assert_eq(s.get_attr(&"aura"), 3)
func test_scripted_dice_sequence() -> void:
	var d := ScriptedDice.new([0.1, 0.7])
	assert_eq(d.roll(), 0.1)
	assert_eq(d.roll(), 0.7)
	assert_eq(d.roll(), 0.99)

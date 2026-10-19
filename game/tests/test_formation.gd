extends GutTest
var g: GameState
func before_each() -> void:
	var defs: Array[CharacterDef] = []
	for id: StringName in [&"a", &"b", &"c", &"d", &"e"]:
		defs.append(Fixtures.hero_def(id, Stats.make(1, 1, 3, 2)))
	g = GameState.new_game(Fixtures.cfg(), defs, [], [], ScriptedDice.new(), &"overworld", &"Start")
func _ids(arr: Array[HeroState]) -> Array: return arr.map(func(h: HeroState) -> StringName: return h.def.id)
func test_first_four_active_rest_reserve() -> void:
	assert_eq(_ids(g.heroes), [&"a", &"b", &"c", &"d"])
	assert_eq(_ids(g.reserve), [&"e"])
	assert_eq(_ids(g.roster()), [&"a", &"b", &"c", &"d", &"e"])
func test_max_active_param() -> void:
	var defs: Array[CharacterDef] = []
	for id: StringName in [&"a", &"b", &"c"]:
		defs.append(Fixtures.hero_def(id, Stats.make(1, 1, 3, 2)))
	var g2 := GameState.new_game(Fixtures.cfg(), defs, [], [], ScriptedDice.new(), &"m", &"S", 2)
	assert_eq(_ids(g2.heroes), [&"a", &"b"])
	assert_eq(_ids(g2.reserve), [&"c"])
func test_swap_active_with_reserve_keeps_slot() -> void:
	assert_true(g.swap(g.heroes[1], g.reserve[0]))
	assert_eq(_ids(g.heroes), [&"a", &"e", &"c", &"d"])
	assert_eq(_ids(g.reserve), [&"b"])
func test_swap_active_active_and_reserve_reserve() -> void:
	assert_true(g.swap(g.heroes[0], g.heroes[2]))
	assert_eq(_ids(g.heroes), [&"c", &"b", &"a", &"d"])
	g.to_reserve(g.heroes[3])
	assert_true(g.swap(g.reserve[0], g.reserve[1]))
	assert_eq(_ids(g.reserve), [&"d", &"e"])
func test_swap_rejects_foreign() -> void:
	var other := HeroState.create(Fixtures.hero_def(&"z", Stats.make(1, 1, 3, 2)), g.cfg)
	assert_false(g.swap(g.heroes[0], other))
	assert_false(g.swap(other, g.heroes[0]))
	assert_eq(_ids(g.heroes), [&"a", &"b", &"c", &"d"])
func test_to_reserve_rejects_non_active() -> void:
	assert_false(g.to_reserve(g.reserve[0]))
func test_to_active_rejects_non_reserve() -> void:
	assert_false(g.to_active(g.heroes[0]))
func test_to_active_appends_at_end() -> void:
	g.to_reserve(g.heroes[0])
	assert_true(g.to_active(g.reserve[1]))
	assert_eq(_ids(g.heroes), [&"b", &"c", &"d", &"a"])
	assert_eq(_ids(g.reserve), [&"e"])
func test_cannot_empty_party_or_overfill() -> void:
	for i: int in 3:
		assert_true(g.to_reserve(g.heroes[0]))
	assert_false(g.to_reserve(g.heroes[0]))
	assert_eq(g.heroes.size(), 1)
	while g.heroes.size() < GameState.MAX_ACTIVE:
		assert_true(g.to_active(g.reserve[0]))
	assert_false(g.to_active(g.reserve[0]))
func test_leader_is_first_standing_active() -> void:
	g.heroes[0].hp = 0
	assert_eq(g.leader(), g.heroes[1])
	for h: HeroState in g.heroes:
		h.hp = 0
	assert_eq(g.leader(), g.heroes[0])
func test_restore_save_restores_formation() -> void:
	var b := g.heroes[1]
	g.swap(b, g.reserve[0])
	g.restore_save()
	assert_eq(_ids(g.heroes), [&"a", &"b", &"c", &"d"])
	assert_eq(_ids(g.reserve), [&"e"])
	assert_eq(g.heroes[1], b)
func test_restore_save_restores_after_to_reserve_and_values() -> void:
	var a := g.heroes[0]
	var hp0 := a.hp
	g.to_reserve(a)
	a.hp = 0
	g.restore_save()
	assert_eq(_ids(g.heroes), [&"a", &"b", &"c", &"d"])
	assert_eq(a.hp, hp0)
	assert_eq(_ids(g.reserve), [&"e"])
func test_save_snapshots_new_formation() -> void:
	g.swap(g.heroes[1], g.reserve[0])
	g.save(&"m", &"S")
	g.swap(g.heroes[0], g.heroes[3])
	g.restore_save()
	assert_eq(_ids(g.heroes), [&"a", &"e", &"c", &"d"])
	assert_eq(_ids(g.reserve), [&"b"])
func test_reserve_gets_no_combat_xp_path() -> void:
	var l := ContributionLedger.new()
	var e := Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1,1,1,1), 100), &"x", Vector2.ZERO, g.cfg)
	l.add(&"e", &"x", 10)
	var cs: Array[Combatant] = []
	for h: HeroState in g.heroes:
		cs.append(Combatant.from_hero(h, Vector2.ZERO))
	assert_false(XpCalculator.combat_xp(l, [e], cs, false).has(&"e"))

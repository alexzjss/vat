extends GutTest

func _gs() -> GameState:
	var cfg: BalanceConfig = Fixtures.cfg()
	var potion := ItemDef.new()
	potion.id = &"potion"
	var defs: Array[CharacterDef] = [Fixtures.hero_def(&"a", Stats.make(1, 1, 3, 2))]
	var items: Array[ItemDef] = [potion]
	var counts: Array[int] = [3]
	return GameState.new_game(cfg, defs, items, counts, ScriptedDice.new(), &"overworld", &"start")

func test_new_game_full_party_and_save_point() -> void:
	var g: GameState = _gs()
	assert_eq(g.heroes.size(), 1)
	assert_eq(g.heroes[0].hp, StatCalculator.hp_max(Combatant.from_hero(g.heroes[0], Vector2.ZERO), g.cfg))
	assert_eq(g.inventory.available(&"potion"), 3)
	assert_eq([g.save_map, g.save_spawn], [&"overworld", &"start"])

func test_restore_is_deep_and_independent() -> void:
	var g: GameState = _gs()
	var h: HeroState = g.heroes[0]
	var hp0: int = h.hp
	h.hp = 1
	h.xp = 500
	h.level = 4
	h.pending_points = 2
	h.allocated.strength = 3
	g.inventory.reserve(&"potion")
	g.inventory.commit(&"potion")
	g.restore_save()
	assert_eq(g.heroes[0], h)
	assert_eq([h.hp, h.xp, h.level, h.pending_points, h.allocated.strength], [hp0, 0, 1, 0, 0])
	assert_eq(g.inventory.available(&"potion"), 3)
	h.allocated.strength = 9
	g.inventory.reserve(&"potion")
	g.inventory.commit(&"potion")
	g.restore_save()
	assert_eq(h.allocated.strength, 0)
	assert_eq(g.inventory.available(&"potion"), 3)

func test_save_overwrites_save_point() -> void:
	var g: GameState = _gs()
	g.heroes[0].xp = 40
	g.save(&"cave", &"door")
	g.heroes[0].xp = 0
	g.restore_save()
	assert_eq(g.heroes[0].xp, 40)
	assert_eq([g.save_map, g.save_spawn], [&"cave", &"door"])

func test_inventory_copy_is_independent_and_clears_reservations() -> void:
	var g: GameState = _gs()
	g.inventory.reserve(&"potion")
	var c: Inventory = g.inventory.copy()
	assert_eq(c.available(&"potion"), 3)
	c.reserve(&"potion")
	c.commit(&"potion")
	assert_eq(c.available(&"potion"), 2)
	assert_eq(g.inventory.available(&"potion"), 2)

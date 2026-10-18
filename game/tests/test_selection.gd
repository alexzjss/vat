extends GutTest
var b: BattleState
var h: Combatant
var x: Combatant

func before_each() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,1,2)), cfg), Vector2.ZERO)
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1,1,1,1)), &"x", Vector2(50,0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	b.inventory = Inventory.new()

func test_cannot_select_without_ap() -> void:
	var ab: AbilityDef = Fixtures.hit(1.0)
	ab.ap_cost = h.ap + 1
	var s := SelectionSession.new(h, b)
	assert_false(s.choose_ability(ab))
	assert_eq(s.step, SelectionSession.Step.COMMAND)

func test_cancel_refunds_ap_fully() -> void:
	var ab: AbilityDef = Fixtures.hit(1.0)
	ab.ap_cost = 4
	var ap0: int = h.ap
	var s := SelectionSession.new(h, b)
	assert_true(s.choose_ability(ab))
	assert_eq(h.ap, ap0 - 4)
	s.back()
	assert_eq(h.ap, ap0)
	assert_eq(s.step, SelectionSession.Step.COMMAND)

func test_confirm_keeps_cost_and_builds_action() -> void:
	var ab: AbilityDef = Fixtures.hit(1.0)
	ab.ap_cost = 4
	var s := SelectionSession.new(h, b)
	s.choose_ability(ab)
	s.set_center(x)
	var a: PendingAction = s.confirm()
	assert_eq(a.center, x)
	assert_eq(a.center_pos, x.position)
	assert_eq(h.ap, StatCalculator.ap_max(h, b.cfg) - 4)
	assert_eq(s.step, SelectionSession.Step.DONE)

func test_cannot_select_item_out_of_stock() -> void:
	var it := ItemDef.new()
	it.id = &"potion"
	b.inventory.add(it, 1)
	var s := SelectionSession.new(h, b)
	assert_true(s.choose_item(it))
	assert_false(SelectionSession.new(h, b).choose_item(it))
	s.back()
	assert_eq(b.inventory.available(&"potion"), 1)

func test_item_confirm_commits() -> void:
	var it := ItemDef.new()
	it.id = &"potion"
	it.side = AbilityDef.Side.ENEMIES
	b.inventory.add(it, 2)
	var s := SelectionSession.new(h, b)
	s.choose_item(it)
	s.set_center(x)
	var a: PendingAction = s.confirm()
	assert_eq(a.item, it)
	assert_eq(b.inventory.available(&"potion"), 1)
	assert_eq(b.inventory.listing().size(), 1)

func test_back_in_command_does_nothing_and_invalid_center_rejected() -> void:
	var s := SelectionSession.new(h, b)
	s.back()
	assert_eq(s.step, SelectionSession.Step.COMMAND)
	s.choose_ability(h.basic_attack)
	s.set_center(h)
	assert_eq(s.step, SelectionSession.Step.TARGET)
	assert_null(s.center)
	assert_push_error_count(1)

func test_confirm_before_confirm_step_returns_null() -> void:
	var s := SelectionSession.new(h, b)
	assert_null(s.confirm())
	assert_push_error_count(1)

func test_inventory_add_guards() -> void:
	b.inventory.add(null, 1)
	var it := ItemDef.new()
	it.id = &"p"
	b.inventory.add(it, 0)
	assert_push_error_count(2)
	assert_eq(b.inventory.listing().size(), 0)

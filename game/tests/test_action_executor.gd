extends GutTest
var b: BattleState; var h: Combatant; var x: Combatant; var y: Combatant
func before_each() -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10,0,2,4)), cfg), Vector2(0,0))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1,0,2,1)), &"x", Vector2(100,0), cfg)
	y = Combatant.from_enemy(Fixtures.enemy_def(&"y", Stats.make(1,0,4,1)), &"y", Vector2(120,0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x, y])
func _act(ab: AbilityDef, center: Combatant) -> PendingAction:
	var a := PendingAction.new(); a.actor = h; a.ability = ab; a.center = center; a.center_pos = center.position
	return a
func test_area_overkill_counts_only_remaining_hp() -> void:
	var ab := Fixtures.hit(3.0, AbilityDef.Shape.CIRCLE_TARGET); ab.radius = 50
	x.hp = 5
	var r := ActionExecutor.apply(_act(ab, x), b)
	assert_eq(r.downed, [x])
	assert_eq(b.ledger.get_points(&"a", &"x"), 5.0)
	assert_eq(b.ledger.get_points(&"a", &"y"), 28.0)
func test_fizzle_when_no_valid_target() -> void:
	x.hp = 0; y.hp = 0
	var r := ActionExecutor.apply(_act(Fixtures.hit(1.0), x), b)
	assert_true(r.fizzled)
func test_redirects_when_center_down() -> void:
	var a := _act(Fixtures.hit(1.0), x); x.hp = 0
	assert_eq(ActionExecutor.apply(a, b).targets, [y])
func test_downed_actor_still_completes() -> void:
	h.hp = 0
	ActionExecutor.apply(_act(Fixtures.hit(1.0), x), b)
	assert_lt(x.hp, StatCalculator.hp_max(x, b.cfg))
func test_heal_clamped_and_credits_only_restored() -> void:
	var heal := AbilityDef.new(); heal.shape = AbilityDef.Shape.SINGLE; heal.side = AbilityDef.Side.ALLIES
	var e := EffectDef.new(); e.kind = EffectDef.Kind.HEAL; e.scale = EffectDef.Scale.FIXED; e.potency = 50
	heal.effects = [e]
	h.hp = StatCalculator.hp_max(h, b.cfg) - 7
	h.damage_taken_from = {&"x": 7}
	var a := _act(heal, h)
	ActionExecutor.apply(a, b)
	assert_eq(h.hp, StatCalculator.hp_max(h, b.cfg))
	assert_eq(b.ledger.get_points(&"a", &"x"), 7.0)
func test_damage_minimum_is_one() -> void:
	var ab := Fixtures.hit(0.0)
	var hp0 := x.hp
	ActionExecutor.apply(_act(ab, x), b)
	assert_eq(x.hp, hp0 - 1)

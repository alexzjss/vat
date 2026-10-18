extends GutTest
var b: BattleState; var h: Combatant; var e1: Combatant; var e2: Combatant; var e3: Combatant
func _e(id: StringName, pos: Vector2) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1,1,1,1)), id, pos, Fixtures.cfg())
func before_each() -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,1,1)), cfg), Vector2(0, 0))
	e1 = _e(&"x", Vector2(100, 0)); e2 = _e(&"y", Vector2(130, 0)); e3 = _e(&"z", Vector2(100, 200))
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [e1, e2, e3])
func _ids(arr: Array[Combatant]) -> Array: return arr.map(func(c: Combatant) -> StringName: return c.id)
func test_circle_includes_by_distance() -> void:
	var got := Targeting.area(AbilityDef.Shape.CIRCLE_TARGET, AbilityDef.Side.ENEMIES, [], 40.0, 0.0, h, e1, b)
	assert_eq(_ids(got), [&"x", &"y"])
func test_line_hits_only_along_segment() -> void:
	var got := Targeting.area(AbilityDef.Shape.LINE, AbilityDef.Side.ENEMIES, [], 0.0, 20.0, h, e2, b)
	assert_eq(_ids(got), [&"x", &"y"])
func test_downed_not_targetable_except_revive() -> void:
	e1.hp = 0
	var heal: Array[EffectDef] = []
	assert_false(Targeting.candidates(AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES, heal, h, b).has(e1))
	var rev := EffectDef.new(); rev.kind = EffectDef.Kind.REVIVE
	h.hp = 0
	var hero2 := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"b", Stats.make(1,1,1,1)), b.cfg), Vector2.ZERO)
	b.heroes.append(hero2)
	assert_eq(Targeting.candidates(AbilityDef.Shape.SINGLE, AbilityDef.Side.ALLIES, [rev], hero2, b), [h])
func test_redirect_to_nearest_or_null() -> void:
	e1.hp = 0
	assert_eq(Targeting.redirect(AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES, [], h, e1, e1.position, b), e2)
	e2.hp = 0; e3.hp = 0
	assert_null(Targeting.redirect(AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES, [], h, e1, e1.position, b))

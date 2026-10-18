extends GutTest
func test_heals_ally_below_threshold_else_attacks_lowest_hp() -> void:
	var cfg := Fixtures.cfg()
	var h1 := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,5,1)), cfg), Vector2.ZERO)
	var h2 := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"b", Stats.make(1,1,5,1)), cfg), Vector2.ZERO)
	h2.hp = 3
	var d := Fixtures.enemy_def(&"x", Stats.make(1,1,5,5))
	var heal := AbilityDef.new(); heal.side = AbilityDef.Side.ALLIES
	var r1 := AiRule.new(); r1.condition = AiRule.Condition.ALLY_HP_BELOW; r1.threshold = 0.5; r1.ability = heal; r1.pick = AiRule.TargetPick.LOWEST_HP_ALLY
	var r2 := AiRule.new(); r2.ability = Fixtures.hit(1.0); r2.pick = AiRule.TargetPick.LOWEST_HP_ENEMY
	d.ai_rules = [r1, r2]
	var x := Combatant.from_enemy(d, &"x", Vector2.ZERO, cfg)
	var b := BattleState.create(cfg, ScriptedDice.new(), [h1, h2], [x])
	assert_eq(EnemyAI.decide(x, b).center, h2)
	x.hp = 1
	assert_eq(EnemyAI.decide(x, b).ability, heal)

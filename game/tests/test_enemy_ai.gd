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

func _hero(id: StringName, hp: int) -> Combatant:
	var h := Combatant.from_hero(HeroState.create(Fixtures.hero_def(id, Stats.make(1,1,5,1)), Fixtures.cfg()), Vector2.ZERO)
	h.hp = hp
	return h

func _rule(ability: AbilityDef, pick: AiRule.TargetPick, cost: int = 0) -> AiRule:
	ability.ap_cost = cost
	var r := AiRule.new()
	r.ability = ability
	r.pick = pick
	return r

func _setup(rules: Array[AiRule], heroes: Array[Combatant], dice: Dice = null) -> Array:
	var cfg := Fixtures.cfg()
	var d := Fixtures.enemy_def(&"x", Stats.make(1,1,5,5))
	d.ai_rules = rules
	var x := Combatant.from_enemy(d, &"x", Vector2.ZERO, cfg)
	var b := BattleState.create(cfg, dice if dice != null else ScriptedDice.new(), heroes, [x])
	return [x, b]

func test_ap_deducted_on_rule() -> void:
	var h := _hero(&"a", 20)
	var s := _setup([_rule(Fixtures.hit(1.0), AiRule.TargetPick.LOWEST_HP_ENEMY, 3)], [h])
	var x: Combatant = s[0]
	var before: int = x.ap
	assert_gt(before, 2)
	var pa := EnemyAI.decide(x, s[1])
	assert_eq(pa.center, h)
	assert_eq(x.ap, before - 3)

func test_skips_rule_when_ap_insufficient() -> void:
	var h := _hero(&"a", 20)
	var s := _setup([_rule(Fixtures.hit(2.0), AiRule.TargetPick.LOWEST_HP_ENEMY, 99)], [h])
	var x: Combatant = s[0]
	var before: int = x.ap
	var pa := EnemyAI.decide(x, s[1])
	assert_eq(pa.ability, x.basic_attack)
	assert_eq(x.ap, before)

func test_self_pick() -> void:
	var buff := Fixtures.hit(1.0, AbilityDef.Shape.CIRCLE_SELF)
	var s := _setup([_rule(buff, AiRule.TargetPick.SELF)], [_hero(&"a", 20)])
	var pa := EnemyAI.decide(s[0], s[1])
	assert_eq(pa.ability, buff)
	assert_eq(pa.center, s[0])

func test_self_pick_actor_not_candidate_falls_through() -> void:
	var atk := Fixtures.hit(1.0)
	var h := _hero(&"a", 20)
	var s := _setup([_rule(atk, AiRule.TargetPick.SELF)], [h])
	var x: Combatant = s[0]
	var pa := EnemyAI.decide(x, s[1])
	assert_eq(pa.ability, x.basic_attack)
	assert_ne(pa.ability, atk)
	assert_eq(pa.center, h)

func test_random_enemy_uses_dice() -> void:
	var h1 := _hero(&"a", 20)
	var h2 := _hero(&"b", 20)
	var dice := ScriptedDice.new([0.9] as Array[float])
	var s := _setup([_rule(Fixtures.hit(1.0), AiRule.TargetPick.RANDOM_ENEMY)], [h1, h2], dice)
	assert_eq(EnemyAI.decide(s[0], s[1]).center, h2)

func test_lowest_hp_tie_first_wins() -> void:
	var h1 := _hero(&"a", 7)
	var h2 := _hero(&"b", 7)
	var s := _setup([_rule(Fixtures.hit(1.0), AiRule.TargetPick.LOWEST_HP_ENEMY)], [h1, h2])
	assert_eq(EnemyAI.decide(s[0], s[1]).center, h1)

func test_fallback_basic_attack_on_lowest_hp_living() -> void:
	var h1 := _hero(&"a", 0)
	var h2 := _hero(&"b", 9)
	var h3 := _hero(&"c", 5)
	var s := _setup([], [h1, h2, h3])
	var x: Combatant = s[0]
	var pa := EnemyAI.decide(x, s[1])
	assert_eq(pa.ability, x.basic_attack)
	assert_eq(pa.center, h3)
	assert_eq(pa.actor, x)

func test_null_basic_attack_returns_null() -> void:
	var s := _setup([], [_hero(&"a", 20)])
	var x: Combatant = s[0]
	x.basic_attack = null
	assert_null(EnemyAI.decide(x, s[1]))
	assert_push_error("sem ataque")

func test_all_foes_down_returns_null() -> void:
	var s := _setup([], [_hero(&"a", 0)])
	assert_null(EnemyAI.decide(s[0], s[1]))

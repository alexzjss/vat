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

## Curandeiro com regra ALLY_HP_BELOW 0.5 e aliados X (Vit 8 -> 85) e Y (Vit 7 -> 75).
func _healer_setup(x_hp: int, y_hp: int) -> Array:
	var cfg := Fixtures.cfg()
	var heal := AbilityDef.new(); heal.side = AbilityDef.Side.ALLIES
	var e := EffectDef.new(); e.kind = EffectDef.Kind.HEAL; e.scale = EffectDef.Scale.FIXED; e.potency = 10
	heal.effects = [e]
	var r := AiRule.new(); r.condition = AiRule.Condition.ALLY_HP_BELOW; r.threshold = 0.5; r.ability = heal; r.pick = AiRule.TargetPick.LOWEST_HP_ALLY
	var hd := Fixtures.enemy_def(&"healer", Stats.make(1,1,5,5))
	hd.ai_rules = [r]
	var healer := Combatant.from_enemy(hd, &"healer", Vector2.ZERO, cfg)
	var ex := Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1,1,8,1)), &"x", Vector2.ZERO, cfg)
	var ey := Combatant.from_enemy(Fixtures.enemy_def(&"y", Stats.make(1,1,7,1)), &"y", Vector2.ZERO, cfg)
	assert_eq(StatCalculator.hp_max(ex, cfg), 85)
	assert_eq(StatCalculator.hp_max(ey, cfg), 75)
	ex.hp = x_hp
	ey.hp = y_hp
	var b := BattleState.create(cfg, ScriptedDice.new(), [_hero(&"a", 20)], [healer, ex, ey])
	return [healer, b, ex, ey, heal]

func test_ally_hp_below_heals_ally_below_threshold_not_lowest_absolute() -> void:
	# X 42/85 = 0.494 (abaixo de 0.5); Y 40/75 = 0.533 (acima): cura X mesmo com Y tendo menos HP.
	var s := _healer_setup(42, 40)
	var pa := EnemyAI.decide(s[0], s[1])
	assert_eq(pa.ability, s[4])
	assert_eq(pa.center, s[2])

func test_ally_hp_below_picks_lowest_ratio_among_below() -> void:
	# X 30/85 = 0.353; Y 28/75 = 0.373: ambos abaixo; menor fração é X.
	var s := _healer_setup(30, 28)
	assert_eq(EnemyAI.decide(s[0], s[1]).center, s[2])

# --- IA de combo (M14, Task 4) ---------------------------------------------------------------

func _el(id: StringName, reacts: bool = true) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	e.reacts = reacts
	return e

func _table(a: ElementDef, b: ElementDef) -> ReactionTable:
	var d := ReactionDef.new()
	d.id = &"r"
	d.a = a
	d.b = b
	var t := ReactionTable.new()
	t.reactions = [d] as Array[ReactionDef]
	return t

func _elemental(el: ElementDef, shape: AbilityDef.Shape = AbilityDef.Shape.SINGLE) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(1.0, shape)
	a.element = el
	a.radius = 200.0
	return a

func _combo_rule(ab: AbilityDef, pick: AiRule.TargetPick = AiRule.TargetPick.REACTION_TARGET) -> AiRule:
	var r := _rule(ab, pick)
	r.condition = AiRule.Condition.CAN_REACT
	return r

## Inimigo com `rules` contra `heroes`, com a tabela fogo + agua.
func _combo_setup(rules: Array[AiRule], heroes: Array[Combatant], table: ReactionTable) -> Array:
	var s := _setup(rules, heroes)
	(s[1] as BattleState).reactions = table
	return s

func test_new_enum_values_are_appended() -> void:
	assert_eq(AiRule.Condition.CAN_REACT, 3)
	assert_eq(AiRule.TargetPick.REACTION_TARGET, 7)

func test_can_react_picks_the_marked_hero_over_lower_hp() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var h1 := _hero(&"a", 5)
	var h2 := _hero(&"b", 20)
	MarkRules.set_mark(h2, fire, 3)
	var fallback := Fixtures.hit(1.0)
	var s := _combo_setup([_combo_rule(_elemental(water)), _rule(fallback, AiRule.TargetPick.LOWEST_HP_ENEMY)], [h1, h2], _table(fire, water))
	var pa := EnemyAI.decide(s[0], s[1])
	assert_eq(pa.center, h2)
	assert_eq(pa.ability.element, water)

func test_reaction_target_ties_go_to_the_lowest_hp() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var h1 := _hero(&"a", 15)
	var h2 := _hero(&"b", 9)
	var h3 := _hero(&"c", 4)
	MarkRules.set_mark(h1, fire, 3)
	MarkRules.set_mark(h2, fire, 3)
	var s := _combo_setup([_combo_rule(_elemental(water))], [h1, h2, h3], _table(fire, water))
	assert_eq(EnemyAI.decide(s[0], s[1]).center, h2)

func test_can_react_is_false_without_a_mark_and_the_next_rule_runs() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var h1 := _hero(&"a", 20)
	var fallback := Fixtures.hit(1.0)
	var s := _combo_setup([_combo_rule(_elemental(water)), _rule(fallback, AiRule.TargetPick.LOWEST_HP_ENEMY)], [h1], _table(fire, water))
	assert_eq(EnemyAI.decide(s[0], s[1]).ability, fallback)

func test_can_react_is_false_when_the_pair_does_not_react() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var earth := _el(&"earth")
	var h1 := _hero(&"a", 20)
	MarkRules.set_mark(h1, earth, 3)
	var fallback := Fixtures.hit(1.0)
	var s := _combo_setup([_combo_rule(_elemental(water)), _rule(fallback, AiRule.TargetPick.LOWEST_HP_ENEMY)], [h1], _table(fire, water))
	assert_eq(EnemyAI.decide(s[0], s[1]).ability, fallback)

func test_can_react_is_false_for_the_same_element_and_for_a_neutral_ability() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var h1 := _hero(&"a", 20)
	MarkRules.set_mark(h1, fire, 3)
	var fallback := Fixtures.hit(1.0)
	var same := _combo_setup([_combo_rule(_elemental(fire)), _rule(fallback, AiRule.TargetPick.LOWEST_HP_ENEMY)], [h1], _table(fire, water))
	assert_eq(EnemyAI.decide(same[0], same[1]).ability, fallback)
	var neutral := _combo_setup([_combo_rule(Fixtures.hit(1.0)), _rule(fallback, AiRule.TargetPick.LOWEST_HP_ENEMY)], [h1], _table(fire, water))
	assert_eq(EnemyAI.decide(neutral[0], neutral[1]).ability, fallback)

func test_can_react_is_false_with_an_empty_table() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var h1 := _hero(&"a", 20)
	MarkRules.set_mark(h1, fire, 3)
	var fallback := Fixtures.hit(1.0)
	var s := _combo_setup([_combo_rule(_elemental(water)), _rule(fallback, AiRule.TargetPick.LOWEST_HP_ENEMY)], [h1], ReactionTable.new())
	assert_eq(EnemyAI.decide(s[0], s[1]).ability, fallback)

func test_can_react_ignores_a_hero_that_absorbs_or_is_immune() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var h1 := _hero(&"a", 20)
	MarkRules.set_mark(h1, fire, 3)
	h1.element_resist[&"water"] = 1.0
	var fallback := Fixtures.hit(1.0)
	var s := _combo_setup([_combo_rule(_elemental(water)), _rule(fallback, AiRule.TargetPick.LOWEST_HP_ENEMY)], [h1], _table(fire, water))
	assert_eq(EnemyAI.decide(s[0], s[1]).ability, fallback)

func test_reaction_target_without_can_react_skips_when_nobody_reacts() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var h1 := _hero(&"a", 20)
	var fallback := Fixtures.hit(1.0)
	var rule := _rule(_elemental(water), AiRule.TargetPick.REACTION_TARGET)
	var s := _combo_setup([rule, _rule(fallback, AiRule.TargetPick.LOWEST_HP_ENEMY)], [h1], _table(fire, water))
	assert_eq(EnemyAI.decide(s[0], s[1]).ability, fallback)

func test_area_combo_is_centered_on_the_reacting_hero() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var h1 := _hero(&"a", 20)
	var h2 := _hero(&"b", 20)
	h2.position = Vector2(50, 0)
	MarkRules.set_mark(h1, fire, 3)
	var s := _combo_setup([_combo_rule(_elemental(water, AbilityDef.Shape.CIRCLE_TARGET))], [h1, h2], _table(fire, water))
	assert_eq(EnemyAI.decide(s[0], s[1]).center, h1)

func test_combo_rule_with_full_chance_consumes_no_dice() -> void:
	var fire := _el(&"fire")
	var water := _el(&"water")
	var h1 := _hero(&"a", 20)
	MarkRules.set_mark(h1, fire, 3)
	var dice := ScriptedDice.new([0.5] as Array[float])
	var s := _setup([_combo_rule(_elemental(water))], [h1], dice)
	(s[1] as BattleState).reactions = _table(fire, water)
	assert_eq(EnemyAI.decide(s[0], s[1]).center, h1)
	assert_eq(dice.roll(), 0.5, "o primeiro sorteio continua intacto")

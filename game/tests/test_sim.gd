extends GutTest

func _eth() -> ItemDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.RESTORE_AP
	e.scale = EffectDef.Scale.FIXED
	e.potency = 5.0
	var it := ItemDef.new()
	it.id = &"ether"
	it.effects = [e]
	return it

func _scenario(policy: StringName) -> SimScenario:
	var s := SimScenario.new()
	s.label = "t_%s" % policy
	s.cfg = Fixtures.cfg()
	s.heroes = [Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1)), Fixtures.hero_def(&"b", Stats.make(8, 5, 5, 3))]
	s.enemies = [Fixtures.enemy_def(&"x", Stats.make(6, 3, 2, 1)), Fixtures.enemy_def(&"y", Stats.make(6, 3, 2, 1))]
	s.hero_level = 3
	s.runs = 3
	s.base_seed = 7
	s.policy = policy
	return s

func _foe(id: StringName, pos: Vector2, cfg: BalanceConfig) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(6, 3, 2, 1)), StringName("%s_0" % id), pos, cfg)

func test_runs_finish_for_both_policies() -> void:
	for p: StringName in [&"basic", &"smart"]:
		var m: SimMetrics = SimRunner.run(_scenario(p))
		assert_eq(m.runs, 3)
		assert_eq(m.wins + m.losses + m.timeouts, 3)
		assert_eq(m.timeouts, 0)
		assert_gt(m.mean_duration(), 0.0)
		assert_gt(m.basic_actions, 0)
		assert_true(m.hero_actions.has(&"a"))

func test_deterministic_same_seed() -> void:
	var a: SimMetrics = SimRunner.run(_scenario(&"basic"))
	var b: SimMetrics = SimRunner.run(_scenario(&"basic"))
	assert_eq(a.to_markdown_row(), b.to_markdown_row())
	assert_eq(a.durations, b.durations)
	assert_eq(a.basic_damage, b.basic_damage)

func test_hero_setup_allocates_points() -> void:
	var s := _scenario(&"basic")
	s.hero_level = 5
	s.alloc_rule = &"main"
	var h: HeroState = SimRunner.make_hero(s.heroes[0], s)
	assert_eq(h.level, 5)
	assert_eq(h.pending_points, 0)
	assert_eq(h.allocated.strength, 6)
	s.alloc_rule = &"even"
	var h2: HeroState = SimRunner.make_hero(s.heroes[0], s)
	assert_eq(h2.allocated.strength + h2.allocated.speed + h2.allocated.vitality + h2.allocated.aura, 6)
	assert_eq(h2.allocated.strength, 2)

func test_smart_policy_always_submits() -> void:
	var cfg := Fixtures.cfg()
	var d := Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1))
	var costly := Fixtures.hit(2.0, AbilityDef.Shape.CIRCLE_TARGET)
	costly.ap_cost = 50
	costly.radius = 200.0
	Fixtures.set_abilities(d, [costly])
	var hs := HeroState.create(d, cfg)
	hs.ap = 0
	var hero := Combatant.from_hero(hs, Vector2(300, 135))
	var foe: Combatant = _foe(&"x", Vector2(900, 200), cfg)
	var b := BattleState.create(cfg, Dice.new(1), [hero] as Array[Combatant], [foe] as Array[Combatant])
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(hero, b), b, &"smart")
	assert_not_null(a)
	assert_eq(a.ability, hero.basic_attack)
	assert_eq(a.center, foe)

func test_smart_uses_area_when_two_enemies_hit() -> void:
	var cfg := Fixtures.cfg()
	var d := Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 3))
	var area := Fixtures.hit(1.0, AbilityDef.Shape.CIRCLE_TARGET)
	area.id = &"area"
	area.ap_cost = 2
	area.radius = 300.0
	Fixtures.set_abilities(d, [area])
	var hs := HeroState.create(d, cfg)
	var hero := Combatant.from_hero(hs, Vector2(300, 135))
	var foes: Array[Combatant] = [_foe(&"x", Vector2(900, 200), cfg), _foe(&"y", Vector2(900, 360), cfg)]
	var b := BattleState.create(cfg, Dice.new(1), [hero] as Array[Combatant], foes)
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(hero, b), b, &"smart")
	assert_eq(a.ability, area)
	assert_eq(hero.ap, hs.ap - 2)

func test_smart_uses_ether_without_ap() -> void:
	var cfg := Fixtures.cfg()
	var d := Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1))
	var costly := Fixtures.hit(2.0)
	costly.ap_cost = 3
	Fixtures.set_abilities(d, [costly])
	var hs := HeroState.create(d, cfg)
	hs.ap = 0
	var hero := Combatant.from_hero(hs, Vector2(300, 135))
	var foe: Combatant = _foe(&"x", Vector2(900, 200), cfg)
	var b := BattleState.create(cfg, Dice.new(1), [hero] as Array[Combatant], [foe] as Array[Combatant])
	var eth: ItemDef = _eth()
	b.inventory.add(eth, 1)
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(hero, b), b, &"smart")
	assert_eq(a.item, eth)
	assert_eq(a.center, hero)

func test_timeout_is_reported() -> void:
	var s := _scenario(&"basic")
	s.runs = 2
	s.cfg.sim_max_seconds = 3.0
	s.enemies = [Fixtures.enemy_def(&"tank", Stats.make(6, 3, 5000, 1))]
	var m: SimMetrics = SimRunner.run(s)
	assert_eq(m.timeouts, 2)
	assert_eq(m.wins, 0)
	assert_eq(m.losses, 0)

func test_markdown_row_and_header() -> void:
	var m: SimMetrics = SimRunner.run(_scenario(&"basic"))
	assert_eq(SimMetrics.header().split("\n").size(), 2)
	assert_true(m.to_markdown_row().begins_with("| t_basic |"))

# ---------- policy ordering / fallback ----------

func _ability(id: StringName, cost: int, shape: AbilityDef.Shape, side: AbilityDef.Side, effects: Array[EffectDef], radius: float = 0.0) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = id
	a.ap_cost = cost
	a.shape = shape
	a.side = side
	a.radius = radius
	a.effects = effects
	return a

func _effect(kind: EffectDef.Kind, st: StatusDef = null) -> EffectDef:
	var e := EffectDef.new()
	e.kind = kind
	e.scale = EffectDef.Scale.AURA
	e.potency = 1.0
	e.status = st
	return e

func _effects(e: EffectDef) -> Array[EffectDef]:
	return [e] as Array[EffectDef]

func _revive_item() -> ItemDef:
	var it := ItemDef.new()
	it.id = &"phoenix"
	it.effects = _effects(_effect(EffectDef.Kind.REVIVE))
	return it

## Heroi a com `abilities` e AP 10; aliado b; n_foes inimigos nas posicoes padrao (e1 tem mais HP que e0).
func _world(abilities: Array[AbilityDef], n_foes: int, ally_hp_pct: float = 1.0, ally_down: bool = false) -> BattleState:
	var cfg := Fixtures.cfg()
	var d := Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 3))
	Fixtures.set_abilities(d, abilities)
	var hero := Combatant.from_hero(HeroState.create(d, cfg), Vector2(300, 135))
	hero.ap = 10
	var heroes: Array[Combatant] = [hero]
	var ally := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"b", Stats.make(10, 5, 5, 1)), cfg), Vector2(300, 285))
	ally.hp = 0 if ally_down else int(float(ally.hp) * ally_hp_pct)
	heroes.append(ally)
	var foes: Array[Combatant] = []
	for i: int in n_foes:
		foes.append(Combatant.from_enemy(Fixtures.enemy_def(StringName("e%d" % i), Stats.make(6, 3, 2 + i, 1)), StringName("e%d_%d" % [i, i]), Vector2(900, 200 + 160 * i), cfg))
	return BattleState.create(cfg, Dice.new(1), heroes, foes)

func _decide(b: BattleState) -> PendingAction:
	return SimPolicy.decide(SelectionSession.new(b.heroes[0], b), b, &"smart")

func test_smart_failed_step_falls_back_and_refunds_ap() -> void:
	var area: AbilityDef = _ability(&"area", 3, AbilityDef.Shape.CIRCLE_TARGET, AbilityDef.Side.ENEMIES, _effects(_effect(EffectDef.Kind.DAMAGE)), 300.0)
	var b: BattleState = _world([area] as Array[AbilityDef], 1)
	var hero: Combatant = b.heroes[0]
	var a: PendingAction = _decide(b)
	assert_eq(a.ability, hero.basic_attack)
	assert_eq(hero.ap, 10)

func test_smart_revive_has_priority_over_heal() -> void:
	var heal: AbilityDef = _ability(&"cura", 2, AbilityDef.Shape.SINGLE, AbilityDef.Side.ALLIES, _effects(_effect(EffectDef.Kind.HEAL)))
	var b: BattleState = _world([heal] as Array[AbilityDef], 1, 1.0, true)
	var third := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"c", Stats.make(10, 5, 5, 1)), b.cfg), Vector2(300, 435))
	third.hp = 1
	b.heroes.append(third)
	var item: ItemDef = _revive_item()
	b.inventory.add(item, 1)
	var a: PendingAction = _decide(b)
	assert_eq(a.item, item)
	assert_eq(a.center, b.heroes[1])
	# sem o item: cura no aliado fraco vivo
	var b2: BattleState = _world([heal] as Array[AbilityDef], 1, 1.0, true)
	b2.heroes.append(third)
	var a2: PendingAction = _decide(b2)
	assert_eq(a2.ability, heal)
	assert_eq(a2.center, third)

func test_smart_heal_threshold_40_percent() -> void:
	var heal: AbilityDef = _ability(&"cura", 2, AbilityDef.Shape.SINGLE, AbilityDef.Side.ALLIES, _effects(_effect(EffectDef.Kind.HEAL)))
	var low: PendingAction = _decide(_world([heal] as Array[AbilityDef], 1, 0.3))
	assert_eq(low.ability, heal)
	assert_eq(low.center.id, &"b")
	var ok: PendingAction = _decide(_world([heal] as Array[AbilityDef], 1, 0.6))
	assert_ne(ok.ability, heal)

func test_smart_status_targets_highest_hp_unaffected() -> void:
	var poison: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 3, 2)
	var ab: AbilityDef = _ability(&"veneno", 1, AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES, _effects(_effect(EffectDef.Kind.APPLY_STATUS, poison)))
	var b: BattleState = _world([ab] as Array[AbilityDef], 2)
	var a: PendingAction = _decide(b)
	assert_eq(a.ability, ab)
	assert_eq(a.center, b.enemies[1])
	b.statuses.apply_forced(b.enemies[1], poison)
	var a2: PendingAction = _decide(b)
	assert_eq(a2.ability, ab)
	assert_eq(a2.center, b.enemies[0])
	b.statuses.apply_forced(b.enemies[0], poison)
	var a3: PendingAction = _decide(b)
	assert_eq(a3.ability, b.heroes[0].basic_attack)

func test_smart_priority_heal_then_area_then_status() -> void:
	var heal: AbilityDef = _ability(&"cura", 2, AbilityDef.Shape.SINGLE, AbilityDef.Side.ALLIES, _effects(_effect(EffectDef.Kind.HEAL)))
	var area: AbilityDef = _ability(&"area", 2, AbilityDef.Shape.CIRCLE_TARGET, AbilityDef.Side.ENEMIES, _effects(_effect(EffectDef.Kind.DAMAGE)), 300.0)
	var poison: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 3, 2)
	var st: AbilityDef = _ability(&"veneno", 1, AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES, _effects(_effect(EffectDef.Kind.APPLY_STATUS, poison)))
	var abs: Array[AbilityDef] = [st, area, heal]
	assert_eq(_decide(_world(abs, 2, 0.2)).ability, heal)
	assert_eq(_decide(_world(abs, 2, 1.0)).ability, area)
	assert_eq(_decide(_world(abs, 1, 1.0)).ability, st)

func test_smart_ether_before_area_when_out_of_ap() -> void:
	var area: AbilityDef = _ability(&"area", 4, AbilityDef.Shape.CIRCLE_TARGET, AbilityDef.Side.ENEMIES, _effects(_effect(EffectDef.Kind.DAMAGE)), 300.0)
	var b: BattleState = _world([area] as Array[AbilityDef], 2)
	b.heroes[0].ap = 1
	var eth: ItemDef = _eth()
	b.inventory.add(eth, 1)
	assert_eq(_decide(b).item, eth)

# ---------- seed ruling ----------

func _random_scenario(seed_value: int, runs: int) -> SimScenario:
	var s := SimScenario.new()
	s.cfg = Fixtures.cfg()
	s.cfg.variance_mode = BalanceConfig.VarianceMode.B
	s.cfg.variance_b = 0.9
	s.cfg.sim_max_seconds = 8.0
	s.heroes = [Fixtures.hero_def(&"a", Stats.make(200, 5, 5, 1))]
	s.enemies = [Fixtures.enemy_def(&"tank", Stats.make(6, 3, 60, 1))]
	s.runs = runs
	s.base_seed = seed_value
	return s

func test_different_seeds_diverge() -> void:
	var a: SimMetrics = SimRunner.run(_random_scenario(100, 4))
	var b: SimMetrics = SimRunner.run(_random_scenario(200, 4))
	assert_ne(a.run_hero_damage, b.run_hero_damage)
	assert_gt(a.run_hero_damage[0], 0)

func test_run_i_uses_base_seed_plus_i() -> void:
	var two: SimMetrics = SimRunner.run(_random_scenario(10, 2))
	var one: SimMetrics = SimRunner.run(_random_scenario(11, 1))
	assert_eq(one.run_hero_damage[0], two.run_hero_damage[1])
	assert_ne(two.run_hero_damage[0], two.run_hero_damage[1])

# ---------- metric math ----------

func test_median_odd_and_even() -> void:
	var m := SimMetrics.new()
	m.durations = [5.0, 1.0, 3.0] as Array[float]
	assert_eq(m.median_duration(), 3.0)
	assert_eq(m.mean_duration(), 3.0)
	m.durations = [4.0, 1.0, 3.0, 10.0] as Array[float]
	assert_eq(m.median_duration(), 3.5)
	assert_eq(m.mean_duration(), 4.5)
	m.durations = [] as Array[float]
	assert_eq(m.median_duration(), 0.0)

func test_damage_split_ap_hp_and_statuses() -> void:
	var m := SimMetrics.new()
	m.runs = 2
	m.basic_actions = 4
	m.basic_damage = 30
	m.ability_actions = 3
	m.ability_damage = 45
	m.ap_spent = 9
	m.party_hp_pct = [0.5, 1.0] as Array[float]
	m.hero_actions = {&"a": 6, &"b": 2}
	m.ttk_actions = {&"x": [2, 4]}
	assert_eq(m.avg_basic_damage(), 7.5)
	assert_eq(m.avg_ability_damage(), 15.0)
	assert_eq(m.mean_ap_spent(), 4.5)
	assert_eq(m.mean_party_hp_pct(), 0.75)
	assert_eq(m.mean_actions_per_hero(), 2.0)
	assert_eq(m.mean_ttk_actions(&"x"), 3.0)
	assert_eq(SimMetrics.new().avg_basic_damage(), 0.0)

func test_battles_to_level_estimate_and_unknown() -> void:
	var s := _scenario(&"basic")
	s.hero_level = 1
	var m := SimMetrics.new()
	m.wins = 2
	m.xp_total = {&"a": 8, &"b": 0}
	SimRunner._finish_xp(s, m)
	# nivel 1 -> 2 custa 10 XP; 4 por vitoria => 3 batalhas; sem XP => -1
	assert_eq(m.battles_to_level[&"a"], 3)
	assert_eq(m.battles_to_level[&"b"], -1)

func test_exact_numbers_small_scenario() -> void:
	var s := SimScenario.new()
	s.cfg = Fixtures.cfg()
	s.heroes = [Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1))]
	s.enemies = [Fixtures.enemy_def(&"x", Stats.make(6, 3, 2, 1), 100)]
	s.runs = 1
	var m: SimMetrics = SimRunner.run(s)
	assert_eq(m.wins, 1)
	# inimigo vit 2: HP 25; golpe 10 - floor(2*0.5) = 9 => 9 + 9 + 7 (limitado ao HP)
	assert_eq(m.basic_actions, 3)
	assert_eq(m.basic_damage, 25)
	assert_eq(m.ability_actions, 0)
	assert_eq(m.ap_spent, 0)
	assert_eq(m.hero_actions[&"a"], 3)
	assert_eq(m.ttk_actions[&"x"], [3])
	assert_eq(m.xp_total[&"a"], 100)
	assert_eq(m.battles_to_level[&"a"], 1)
	assert_eq(m.statuses_applied, 0)
	assert_eq(m.run_hero_damage, [25] as Array[int])

func test_statuses_applied_and_resisted_counts() -> void:
	var sleep: StatusDef = Fixtures.status_def(StatusDef.Kind.SLEEP, 1)
	var eff: EffectDef = _effect(EffectDef.Kind.APPLY_STATUS, sleep)
	eff.chance = 1.0
	var ab: AbilityDef = _ability(&"sono", 1, AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES, _effects(eff))
	var s := SimScenario.new()
	s.cfg = Fixtures.cfg()
	s.cfg.sim_max_seconds = 40.0
	var hd: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1))
	Fixtures.set_abilities(hd, [ab])
	s.heroes = [hd]
	var foe: EnemyDef = Fixtures.enemy_def(&"tank", Stats.make(1, 1, 500, 1))
	foe.resistances = {&"sleep": 0.5} as Dictionary[StringName, float]
	s.enemies = [foe]
	s.policy = &"smart"
	s.runs = 3
	s.base_seed = 5
	var m: SimMetrics = SimRunner.run(s)
	assert_gt(m.statuses_applied, 0)
	assert_gt(m.statuses_resisted, 0)
	var m2: SimMetrics = SimRunner.run(s)
	assert_eq(m2.statuses_applied, m.statuses_applied)
	assert_eq(m2.statuses_resisted, m.statuses_resisted)

# --- smart e reacoes (M14, Task 4) -----------------------------------------------------------

func _reaction_setup(basic_policy: bool = false) -> Array:
	var cfg := Fixtures.cfg()
	var fire := ElementDef.new()
	fire.id = &"fire"
	var water := ElementDef.new()
	water.id = &"water"
	var d := Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 3))
	var wave := Fixtures.hit(1.0)
	wave.id = &"wave"
	wave.ap_cost = 2
	wave.element = water
	Fixtures.set_abilities(d, [wave])
	var hero := Combatant.from_hero(HeroState.create(d, cfg), Vector2(300, 135))
	var weak: Combatant = _foe(&"x", Vector2(900, 200), cfg)
	weak.element_resist[&"water"] = -0.5
	var marked: Combatant = _foe(&"y", Vector2(900, 360), cfg)
	MarkRules.set_mark(marked, fire, 3)
	var b := BattleState.create(cfg, Dice.new(1), [hero] as Array[Combatant], [weak, marked] as Array[Combatant])
	var rd := ReactionDef.new()
	rd.id = &"steam"
	rd.a = fire
	rd.b = water
	var t := ReactionTable.new()
	t.reactions = [rd] as Array[ReactionDef]
	b.reactions = t
	return [b, hero, weak, marked, wave]

func test_smart_prefers_reaction_over_weakness() -> void:
	var s := _reaction_setup()
	var b: BattleState = s[0]
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(s[1], b), b, &"smart")
	assert_eq(a.ability, s[4])
	assert_eq(a.center, s[3])

func test_smart_falls_back_to_weakness_without_a_reaction() -> void:
	var s := _reaction_setup()
	var b: BattleState = s[0]
	b.reactions = ReactionTable.new()
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(s[1], b), b, &"smart")
	assert_eq(a.ability, s[4])
	assert_eq(a.center, s[2])

func test_smart_never_reacts_into_immunity() -> void:
	var s := _reaction_setup()
	var b: BattleState = s[0]
	(s[3] as Combatant).element_resist[&"water"] = 1.0
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(s[1], b), b, &"smart")
	assert_eq(a.center, s[2])

func test_basic_ignores_marks() -> void:
	var s := _reaction_setup()
	var b: BattleState = s[0]
	(s[2] as Combatant).hp = 1
	var a: PendingAction = SimPolicy.decide(SelectionSession.new(s[1], b), b, &"basic")
	assert_eq(a.ability, (s[1] as Combatant).basic_attack)
	assert_eq(a.center, s[2])

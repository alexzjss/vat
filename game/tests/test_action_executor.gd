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

func _ally_ability(effects: Array[EffectDef]) -> AbilityDef:
	var ab := AbilityDef.new(); ab.shape = AbilityDef.Shape.SINGLE; ab.side = AbilityDef.Side.ALLIES
	ab.effects = effects
	return ab

func _effect(kind: EffectDef.Kind, potency: float) -> EffectDef:
	var e := EffectDef.new(); e.kind = kind; e.scale = EffectDef.Scale.FIXED; e.potency = potency
	return e

## Segundo herói caído (Vitalidade 5 -> hp_max 55), com dano recebido de x.
func _fallen_ally() -> Combatant:
	var h2 := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"b", Stats.make(1,0,5,2)), b.cfg), Vector2(10,0))
	h2.hp = 0
	h2.atb = 0.7
	h2.damage_taken_from = {&"x": 30}
	b.heroes.append(h2)
	return h2

func test_revive_sets_floor_hp_resets_atb_and_credits_ally_benefit() -> void:
	var h2 := _fallen_ally()
	var r := ActionExecutor.apply(_act(_ally_ability([_effect(EffectDef.Kind.REVIVE, 0.25)]), h2), b)
	# floor(55 * 0.25) = 13
	assert_eq(h2.hp, 13)
	assert_eq(h2.atb, 0.0)
	assert_eq(r.hits.size(), 1)
	assert_eq(r.hits[0]["amount"], 13)
	assert_eq(b.ledger.get_points(&"a", &"x"), 13.0, "benefício creditado ao inimigo que causou o dano")

func test_revive_minimum_one_hp() -> void:
	var h2 := _fallen_ally()
	ActionExecutor.apply(_act(_ally_ability([_effect(EffectDef.Kind.REVIVE, 0.001)]), h2), b)
	assert_eq(h2.hp, 1)

func test_revive_ignores_standing_target() -> void:
	var hp0: int = h.hp
	var r := ActionExecutor.apply(_act(_ally_ability([_effect(EffectDef.Kind.REVIVE, 0.25)]), h), b)
	assert_eq(h.hp, hp0)
	assert_true(r.hits.is_empty())

func test_restore_ap_skips_downed_target() -> void:
	var h2 := _fallen_ally()
	h2.ap = 2
	# RESTORE_AP antes de REVIVE: o alvo ainda está caído quando o efeito de AP é avaliado.
	var r := ActionExecutor.apply(_act(_ally_ability([_effect(EffectDef.Kind.RESTORE_AP, 5.0), _effect(EffectDef.Kind.REVIVE, 0.25)]), h2), b)
	assert_eq(h2.ap, 2, "caído não recebe AP")
	for hit: Dictionary in r.hits:
		assert_ne(hit["kind"], EffectDef.Kind.RESTORE_AP)
	assert_eq(h2.hp, 13, "revive ainda aplica")

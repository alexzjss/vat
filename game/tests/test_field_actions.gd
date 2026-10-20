extends GutTest

## Itens e tecnicas fora de combate: formulas compartilhadas com o ActionExecutor.

func _effect(kind: EffectDef.Kind, scale: EffectDef.Scale, potency: float) -> EffectDef:
	var e := EffectDef.new()
	e.kind = kind
	e.scale = scale
	e.potency = potency
	return e

func _item(id: StringName, effects: Array[EffectDef]) -> ItemDef:
	var it := ItemDef.new()
	it.id = id
	it.effects = effects
	return it

func _tech(effects: Array[EffectDef], cost: int, shape: AbilityDef.Shape = AbilityDef.Shape.SINGLE, side: AbilityDef.Side = AbilityDef.Side.ALLIES) -> AbilityDef:
	var ab := AbilityDef.new()
	ab.id = &"tech"
	ab.ap_cost = cost
	ab.shape = shape
	ab.side = side
	ab.effects = effects
	return ab

func _state(n: int, active: int = 4) -> GameState:
	var defs: Array[CharacterDef] = []
	for i: int in n:
		defs.append(Fixtures.hero_def(StringName("h%d" % i), Stats.make(1, 1, 5, 6)))
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	return GameState.new_game(Fixtures.cfg(), defs, items, counts, ScriptedDice.new(), &"m", &"s", active)

func _hp_max(h: HeroState, cfg: BalanceConfig) -> int:
	return StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), cfg)

func test_battle_and_field_heal_use_same_math() -> void:
	var e := _effect(EffectDef.Kind.HEAL, EffectDef.Scale.AURA, 2.0)
	var cfg: BalanceConfig = Fixtures.cfg()
	var actor := HeroState.create(Fixtures.hero_def(&"a", Stats.make(1, 1, 5, 6)), cfg)
	var ally := HeroState.create(Fixtures.hero_def(&"b", Stats.make(1, 1, 5, 6)), cfg)
	var ac: Combatant = Combatant.from_hero(actor, Vector2.ZERO)
	var bc: Combatant = Combatant.from_hero(ally, Vector2(10, 0))
	var en: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 0, 2, 1)), &"x", Vector2(100, 0), cfg)
	var bs: BattleState = BattleState.create(cfg, ScriptedDice.new(), [ac, bc], [en])
	bc.hp = 1
	var ab := _tech([e], 0)
	var pa := PendingAction.new()
	pa.actor = ac
	pa.ability = ab
	pa.center = bc
	pa.center_pos = bc.position
	ActionExecutor.apply(pa, bs)
	var battle_gain: int = bc.hp - 1
	var s := _state(2)
	var user: HeroState = s.heroes[0]
	var tgt: HeroState = s.heroes[1]
	tgt.hp = 1
	assert_true(FieldActions.use_technique(s, user, ab, tgt))
	assert_eq(tgt.hp - 1, battle_gain)
	assert_eq(battle_gain, 12)

func test_effect_math_formulas() -> void:
	var fixed := _effect(EffectDef.Kind.HEAL, EffectDef.Scale.FIXED, 30.7)
	assert_eq(EffectMath.heal_amount(fixed, 99), 30)
	var aura := _effect(EffectDef.Kind.HEAL, EffectDef.Scale.AURA, 2.5)
	assert_eq(EffectMath.heal_amount(aura, 3), 7)
	var rev := _effect(EffectDef.Kind.REVIVE, EffectDef.Scale.FIXED, 0.25)
	assert_eq(EffectMath.revive_hp(rev, 55), 13)
	assert_eq(EffectMath.revive_hp(rev, 2), 1)
	var ap := _effect(EffectDef.Kind.RESTORE_AP, EffectDef.Scale.FIXED, 15.9)
	assert_eq(EffectMath.restore_ap_amount(ap), 15)

func test_item_heals_and_is_consumed() -> void:
	var s := _state(1)
	var pocao: ItemDef = _item(&"pocao", [_effect(EffectDef.Kind.HEAL, EffectDef.Scale.FIXED, 30.0)])
	s.inventory.add(pocao, 2)
	var h: HeroState = s.heroes[0]
	h.hp = 10
	assert_true(FieldActions.use_item(s, pocao, h))
	assert_eq(h.hp, 40)
	assert_eq(s.inventory.available(&"pocao"), 1)
	h.hp = _hp_max(h, s.cfg) - 5
	assert_true(FieldActions.use_item(s, pocao, h))
	assert_eq(h.hp, _hp_max(h, s.cfg))
	assert_eq(s.inventory.available(&"pocao"), 0)
	h.hp = 1
	assert_false(FieldActions.use_item(s, pocao, h))
	assert_eq(h.hp, 1)

func test_item_restores_ap_clamped() -> void:
	var s := _state(1)
	var eter: ItemDef = _item(&"eter", [_effect(EffectDef.Kind.RESTORE_AP, EffectDef.Scale.FIXED, 15.0)])
	s.inventory.add(eter, 1)
	var h: HeroState = s.heroes[0]
	h.ap = 0
	assert_true(FieldActions.use_item(s, eter, h))
	assert_eq(h.ap, 15)
	assert_eq(s.inventory.available(&"eter"), 0)

func test_no_effect_does_not_consume() -> void:
	var s := _state(1)
	var pocao: ItemDef = _item(&"pocao", [_effect(EffectDef.Kind.HEAL, EffectDef.Scale.FIXED, 30.0)])
	var reviver: ItemDef = _item(&"reviver", [_effect(EffectDef.Kind.REVIVE, EffectDef.Scale.FIXED, 0.25)])
	var eter: ItemDef = _item(&"eter", [_effect(EffectDef.Kind.RESTORE_AP, EffectDef.Scale.FIXED, 15.0)])
	s.inventory.add(pocao, 1)
	s.inventory.add(reviver, 1)
	s.inventory.add(eter, 1)
	var h: HeroState = s.heroes[0]
	assert_false(FieldActions.use_item(s, pocao, h))
	assert_false(FieldActions.use_item(s, reviver, h))
	assert_false(FieldActions.use_item(s, eter, h))
	h.hp = 0
	assert_false(FieldActions.use_item(s, pocao, h))
	assert_false(FieldActions.use_item(s, eter, h))
	assert_eq([s.inventory.available(&"pocao"), s.inventory.available(&"reviver"), s.inventory.available(&"eter")], [1, 1, 1])
	assert_eq(h.hp, 0)

func test_item_with_zero_stock_or_unusable_effects_fails() -> void:
	var s := _state(1)
	var pocao: ItemDef = _item(&"pocao", [_effect(EffectDef.Kind.HEAL, EffectDef.Scale.FIXED, 30.0)])
	var h: HeroState = s.heroes[0]
	h.hp = 5
	assert_false(FieldActions.use_item(s, pocao, h))
	assert_eq(h.hp, 5)
	var bad: ItemDef = _item(&"bad", [_effect(EffectDef.Kind.DAMAGE, EffectDef.Scale.FIXED, 5.0)])
	s.inventory.add(bad, 1)
	assert_false(FieldActions.use_item(s, bad, h))
	assert_eq(s.inventory.available(&"bad"), 1)
	var empty: ItemDef = _item(&"empty", [])
	s.inventory.add(empty, 1)
	assert_false(FieldActions.use_item(s, empty, h))
	assert_eq(s.inventory.available(&"empty"), 1)

func test_revive_item_on_downed() -> void:
	var s := _state(1)
	var reviver: ItemDef = _item(&"reviver", [_effect(EffectDef.Kind.REVIVE, EffectDef.Scale.FIXED, 0.25)])
	s.inventory.add(reviver, 1)
	var h: HeroState = s.heroes[0]
	var hpm: int = _hp_max(h, s.cfg)
	h.hp = 0
	assert_true(FieldActions.use_item(s, reviver, h))
	assert_eq(h.hp, maxi(1, int(floor(hpm * 0.25))))
	assert_eq(s.inventory.available(&"reviver"), 0)

func test_technique_costs_ap_and_heals() -> void:
	var s := _state(2)
	var user: HeroState = s.heroes[0]
	var tgt: HeroState = s.heroes[1]
	var ab := _tech([_effect(EffectDef.Kind.HEAL, EffectDef.Scale.AURA, 3.0)], 4)
	tgt.hp = 1
	var ap0: int = user.ap
	assert_true(FieldActions.can_use_technique(user, ab, tgt, s.cfg))
	assert_true(FieldActions.use_technique(s, user, ab, tgt))
	assert_eq(user.ap, ap0 - 4)
	assert_eq(tgt.hp, 1 + 18)

func test_technique_disabled_without_ap_or_when_user_down() -> void:
	var s := _state(2)
	var user: HeroState = s.heroes[0]
	var tgt: HeroState = s.heroes[1]
	var ab := _tech([_effect(EffectDef.Kind.HEAL, EffectDef.Scale.AURA, 3.0)], 4)
	tgt.hp = 1
	user.ap = 3
	assert_false(FieldActions.can_use_technique(user, ab, tgt, s.cfg))
	assert_false(FieldActions.use_technique(s, user, ab, tgt))
	assert_eq([user.ap, tgt.hp], [3, 1])
	user.ap = 10
	user.hp = 0
	assert_false(FieldActions.can_use_technique(user, ab, tgt, s.cfg))
	assert_false(FieldActions.use_technique(s, user, ab, tgt))
	user.hp = 5
	tgt.hp = _hp_max(tgt, s.cfg)
	assert_false(FieldActions.can_use_technique(user, ab, tgt, s.cfg))
	assert_false(FieldActions.use_technique(s, user, ab, tgt))
	assert_eq(user.ap, 10)

func test_field_techniques_lists_only_ally_restoratives() -> void:
	var s := _state(1)
	var user: HeroState = s.heroes[0]
	var cura := _tech([_effect(EffectDef.Kind.HEAL, EffectDef.Scale.AURA, 3.0)], 4)
	var golpe := _tech([_effect(EffectDef.Kind.DAMAGE, EffectDef.Scale.STRENGTH, 1.0)], 0, AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES)
	var sono := _tech([_effect(EffectDef.Kind.APPLY_STATUS, EffectDef.Scale.FIXED, 0.0)], 2, AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES)
	var cura_inimiga := _tech([_effect(EffectDef.Kind.HEAL, EffectDef.Scale.AURA, 3.0)], 2, AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES)
	var mixed := _tech([_effect(EffectDef.Kind.HEAL, EffectDef.Scale.AURA, 1.0), _effect(EffectDef.Kind.APPLY_STATUS, EffectDef.Scale.FIXED, 0.0)], 2)
	Fixtures.give_abilities(user, [cura, golpe, sono, cura_inimiga, mixed])
	assert_eq(FieldActions.field_techniques(user), [cura])

func test_is_field_usable() -> void:
	var none: Array[EffectDef] = []
	assert_false(FieldActions.is_field_usable(none))
	assert_true(FieldActions.is_field_usable([_effect(EffectDef.Kind.REVIVE, EffectDef.Scale.FIXED, 0.5)]))
	assert_false(FieldActions.is_field_usable([_effect(EffectDef.Kind.REMOVE_STATUS, EffectDef.Scale.FIXED, 0.0)]))

func test_would_affect_by_kind() -> void:
	var s := _state(1)
	var h: HeroState = s.heroes[0]
	var heal: Array[EffectDef] = [_effect(EffectDef.Kind.HEAL, EffectDef.Scale.FIXED, 5.0)]
	var rev: Array[EffectDef] = [_effect(EffectDef.Kind.REVIVE, EffectDef.Scale.FIXED, 0.5)]
	var ap: Array[EffectDef] = [_effect(EffectDef.Kind.RESTORE_AP, EffectDef.Scale.FIXED, 5.0)]
	assert_false(FieldActions.would_affect(heal, h, s.cfg))
	assert_false(FieldActions.would_affect(rev, h, s.cfg))
	assert_false(FieldActions.would_affect(ap, h, s.cfg))
	h.hp = 3
	h.ap = 0
	assert_true(FieldActions.would_affect(heal, h, s.cfg))
	assert_true(FieldActions.would_affect(ap, h, s.cfg))
	h.hp = 0
	assert_true(FieldActions.would_affect(rev, h, s.cfg))
	assert_false(FieldActions.would_affect(heal, h, s.cfg))
	assert_false(FieldActions.would_affect(ap, h, s.cfg))

func test_group_technique_affects_all_actives_only() -> void:
	var s := _state(3, 2)
	var user: HeroState = s.heroes[0]
	var other: HeroState = s.heroes[1]
	var rest: HeroState = s.reserve[0]
	var ab := _tech([_effect(EffectDef.Kind.HEAL, EffectDef.Scale.FIXED, 10.0)], 4, AbilityDef.Shape.GROUP)
	user.hp = 1
	other.hp = 1
	rest.hp = 1
	var ap0: int = user.ap
	assert_true(FieldActions.can_use_technique(user, ab, user, s.cfg, s))
	assert_true(FieldActions.use_technique(s, user, ab, user))
	assert_eq([user.hp, other.hp, rest.hp], [11, 11, 1])
	assert_eq(user.ap, ap0 - 4)

func test_group_technique_requires_someone_affected() -> void:
	var s := _state(2)
	var user: HeroState = s.heroes[0]
	var ab := _tech([_effect(EffectDef.Kind.HEAL, EffectDef.Scale.FIXED, 10.0)], 4, AbilityDef.Shape.ALL)
	assert_false(FieldActions.can_use_technique(user, ab, user, s.cfg, s))
	assert_false(FieldActions.use_technique(s, user, ab, user))
	s.heroes[1].hp = 2
	assert_true(FieldActions.can_use_technique(user, ab, user, s.cfg, s))

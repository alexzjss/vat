extends GutTest
## M13 Task 2: Shukketsu (Sangue) e Sangramento. Defs em memoria; os dados de teste continuam neutros.

var b: BattleState
var h: Combatant
var x: Combatant
var blood: ElementDef

func before_each() -> void:
	blood = ElementDef.new()
	blood.id = &"blood"
	blood.rule = ElementDef.Rule.BLOOD
	var cfg := Fixtures.cfg()
	# Heroi: Forca 40, hp 25. Inimigo: Vit 12 -> hp 125, defesa 6 -> golpe de 24 (Forca 40 cai para 30 pelo teto de DR).
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(40, 0, 2, 4)), cfg), Vector2(0, 0))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 0, 12, 1)), &"x", Vector2(100, 0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x])

func _ability(element: ElementDef) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(1.0)
	a.element = element
	return a

func _hit(actor: Combatant, target: Combatant) -> Dictionary:
	var a := PendingAction.new()
	a.actor = actor
	a.ability = _ability(blood)
	a.center = target
	a.center_pos = target.position
	return ActionExecutor.apply(a, b).hits[0]

func _bleed(potency: int, duration: int = 4) -> StatusDef:
	var s: StatusDef = Fixtures.status_def(StatusDef.Kind.BLEED, duration, potency)
	s.id = &"bleed"
	s.negative = true
	return s

# --- roubo de vida -----------------------------------------------------------

func test_blood_at_full_hp_is_plain_damage_without_lifesteal() -> void:
	var hit: Dictionary = _hit(h, x)
	assert_eq(hit["amount"], 24)
	assert_eq(hit["lifesteal"], 0, "HP cheio: nada a curar")
	assert_eq(h.hp, 25)

func test_lifesteal_heals_attacker_by_fraction_of_effective_damage() -> void:
	h.hp = 10
	var hit: Dictionary = _hit(h, x)
	assert_eq(hit["amount"], 31, "24 x (1 + 0.5 x 0.6) = 31 (floor)")
	assert_eq(hit["lifesteal"], 7, "floor(31 x 0.25)")
	assert_eq(h.hp, 17)

func test_lifesteal_caps_at_max_hp() -> void:
	h.hp = 24
	var hit: Dictionary = _hit(h, x)
	assert_eq(hit["lifesteal"], 1)
	assert_eq(h.hp, 25)

func test_lifesteal_uses_effective_damage_capped_by_target_hp() -> void:
	h.hp = 1
	x.hp = 8
	var hit: Dictionary = _hit(h, x)
	assert_eq(hit["amount"], 8)
	assert_eq(hit["lifesteal"], 2, "floor(8 x 0.25)")
	assert_eq(h.hp, 3)

func test_no_lifesteal_when_target_absorbs() -> void:
	h.hp = 10
	x.enemy_def.element_resist = {&"blood": 1.5}
	var hit: Dictionary = _hit(h, x)
	assert_eq(hit["affinity"], ElementMath.Affinity.ABSORB)
	assert_eq(hit["lifesteal"], 0)
	assert_eq(h.hp, 10)

func test_no_lifesteal_when_immune() -> void:
	h.hp = 10
	x.enemy_def.element_resist = {&"blood": 1.0}
	var hit: Dictionary = _hit(h, x)
	assert_eq(hit["amount"], 0)
	assert_eq(hit["lifesteal"], 0)
	assert_eq(h.hp, 10)

func test_lifesteal_gives_no_contribution_credit() -> void:
	h.hp = 10
	var hit: Dictionary = _hit(h, x)
	assert_gt(hit["lifesteal"], 0)
	assert_eq(b.ledger.get_points(h.id, x.id), float(hit["amount"]), "so o credito do dano, nenhum da cura")
	assert_eq(b.ledger.entries().size(), 1)

func test_enemy_blood_user_lifesteals_too() -> void:
	x.base = Stats.make(40, 0, 12, 1)
	x.hp = 40
	var a := PendingAction.new()
	a.actor = x
	a.ability = _ability(blood)
	a.center = h
	a.center_pos = h.position
	var hit: Dictionary = ActionExecutor.apply(a, b).hits[0]
	assert_gt(hit["lifesteal"], 0)
	assert_eq(x.hp, mini(125, 40 + int(hit["lifesteal"])))

# --- HP baixo ----------------------------------------------------------------

func test_low_hp_bonus_extremes() -> void:
	h.hp = 25
	assert_eq(ElementMath.blood_multiplier(h, b.cfg), 1.0)
	h.hp = 1
	assert_almost_eq(ElementMath.blood_multiplier(h, b.cfg), 1.48, 0.0001)
	assert_eq(_hit(h, x)["amount"], 35, "24 x 1.48 = 35 (floor)")

func test_low_hp_bonus_applies_after_same_element_and_before_affinity() -> void:
	h.elements = [blood]
	h.hp = 1
	x.enemy_def.element_resist = {&"blood": 0.5}
	# 24 -> nativo x1.2 = 28 -> sangue x1.48 = 41 -> afinidade x0.5 = 20
	var hit: Dictionary = _hit(h, x)
	assert_eq(hit["amount"], 20)
	assert_eq(hit["affinity"], ElementMath.Affinity.RESIST)

func test_blood_rule_does_not_apply_to_other_elements() -> void:
	var fire := ElementDef.new()
	fire.id = &"fire"
	h.hp = 1
	var a := PendingAction.new()
	a.actor = h
	a.ability = _ability(fire)
	a.center = x
	a.center_pos = x.position
	var hit: Dictionary = ActionExecutor.apply(a, b).hits[0]
	assert_eq(hit["amount"], 24)
	assert_eq(hit["lifesteal"], 0)

func test_blood_consumes_no_dice() -> void:
	var dice := ScriptedDice.new([0.1, 0.2])
	b = BattleState.create(b.cfg, dice, [h], [x])
	h.hp = 5
	_hit(h, x)
	assert_eq(dice._i, 0)

# --- Sangramento -------------------------------------------------------------

func test_bleed_def_loads() -> void:
	var s: StatusDef = load("res://data/test/statuses/bleed.tres") as StatusDef
	assert_not_null(s)
	assert_eq(s.kind, StatusDef.Kind.BLEED)
	assert_true(s.negative)
	assert_eq(StatusDef.Kind.REGEN, 11, "enum so cresce no fim")
	assert_eq(StatusDef.Kind.BLEED, 12)

func test_bleed_costs_percent_of_max_hp_on_action() -> void:
	b.statuses.apply_forced(h, _bleed(20))
	assert_eq(b.statuses.on_action(h), 5, "20% de 25")
	assert_eq(h.hp, 20)

func test_bleed_never_downs() -> void:
	b.statuses.apply_forced(h, _bleed(50))
	h.hp = 3
	assert_eq(b.statuses.on_action(h), 2)
	assert_eq(h.hp, 1)
	assert_eq(b.statuses.on_action(h), 0)
	assert_eq(h.hp, 1)

func test_bleed_renews_without_stacking() -> void:
	var s: StatusDef = _bleed(20)
	b.statuses.apply_forced(h, s)
	assert_eq(b.statuses.apply_forced(h, s), StatusSystem.ApplyResult.RENEWED)
	assert_eq(h.statuses.size(), 1)
	assert_eq(b.statuses.on_action(h), 5)

func test_bleed_respects_immunity_and_resistance() -> void:
	var s: StatusDef = _bleed(20)
	h.immunities = [&"bleed"]
	assert_eq(b.statuses.apply(h, s, x, 1.0, [x]), StatusSystem.ApplyResult.IMMUNE)
	assert_true(h.statuses.is_empty())
	h.immunities = []
	h.resistances = {&"bleed": 1.0}
	assert_eq(b.statuses.apply(h, s, x, 1.0, [x]), StatusSystem.ApplyResult.RESISTED)
	assert_true(h.statuses.is_empty())

func test_bleed_on_enemy_credits_the_source() -> void:
	b.statuses.apply(x, _bleed(10), h, 1.0, [x])
	assert_eq(b.statuses.on_action(x), 12, "10% de 125 = 12 (floor)")
	assert_gt(b.ledger.get_points(h.id, x.id), 0.0)

func test_bleed_only_when_the_afflicted_acts() -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 1)), cfg), Vector2.ZERO)
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(10, 1, 5, 5)), &"x", Vector2.ZERO, cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	var ctrl := BattleController.new(b)
	b.statuses.apply_forced(h, _bleed(10))
	var seen: Array[int] = []
	ctrl.bleed_tick.connect(func(c: Combatant, amount: int) -> void:
		if c == h:
			seen.append(amount))
	# Ninguem agiu ainda (heroi com ATB 0.4/s): nada de dano por tempo.
	for i: int in 20:
		ctrl.tick(0.05)
	assert_eq(seen.size(), 0)
	assert_eq(h.hp, 55)
	# O heroi age: o Sangramento cobra no impacto, uma vez.
	while ctrl.session == null:
		ctrl.tick(0.05)
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(s.actor.basic_attack))
	s.set_center(x)
	ctrl.submit(s.confirm())
	for i: int in 12:
		ctrl.tick(0.05)
	assert_eq(seen, [5] as Array[int], "10% de 55 = 5")
	assert_eq(h.hp, 50)

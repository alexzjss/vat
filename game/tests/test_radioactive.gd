extends GutTest
## M13 Task 3: elemento Radioativo e contaminacao. Defs em memoria; os dados de teste continuam neutros.

var b: BattleState
var h: Combatant
var x: Combatant
var rad: ElementDef

func before_each() -> void:
	rad = ElementDef.new()
	rad.id = &"rad"
	rad.rule = ElementDef.Rule.RADIOACTIVE
	rad.reacts = false
	_build(Stats.make(40, 0, 30, 1))

## Heroi: Forca 40 (30 pelo teto de DR), hp 25. Inimigo (Vit 30 -> DR 25): hp 255, defesa 12, golpe de 18.
func _build(enemy_stats: Stats) -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(40, 0, 2, 4)), cfg), Vector2(0, 0))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", enemy_stats), &"x", Vector2(100, 0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x])

func _ability() -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(1.0)
	a.element = rad
	return a

func _hit(actor: Combatant = null, target: Combatant = null) -> Dictionary:
	var a := PendingAction.new()
	a.actor = actor if actor != null else h
	a.ability = _ability()
	a.center = target if target != null else x
	a.center_pos = a.center.position
	return ActionExecutor.apply(a, b).hits[0]

# --- ignora afinidade --------------------------------------------------------

func test_ignores_affinity_even_immune_and_absorb() -> void:
	var plain: int = int(_hit()["amount"])
	for r: float in [-0.5, 0.5, 1.0, 1.5]:
		_build(Stats.make(40, 0, 30, 1))
		x.enemy_def.element_resist = {&"rad": r}
		var hit: Dictionary = _hit()
		assert_eq(hit["affinity"], ElementMath.Affinity.NEUTRAL, "resist %s" % r)
		assert_eq(hit["kind"], EffectDef.Kind.DAMAGE)
		assert_eq(hit["amount"], plain, "resist %s" % r)

func test_same_element_bonus_still_applies() -> void:
	var plain: int = int(_hit()["amount"])
	_build(Stats.make(40, 0, 30, 1))
	h.elements = [rad]
	var hit: Dictionary = _hit()
	assert_eq(hit["amount"], floori(float(plain) * 1.2))

# --- contaminacao ------------------------------------------------------------

func test_accumulates_one_per_damaging_hit() -> void:
	var first: Dictionary = _hit()
	assert_eq(first["contamination"], 1)
	assert_eq(x.contamination, 1)
	assert_eq(first["burst"], 0)
	assert_eq(_hit()["contamination"], 2)
	assert_eq(x.contamination, 2)

func test_hit_that_deals_no_damage_does_not_contaminate() -> void:
	b.statuses.apply_forced(x, Fixtures.status_def(StatusDef.Kind.BARRIER, 5, 9999))
	var hit: Dictionary = _hit()
	assert_eq(hit["amount"], 0)
	assert_eq(x.contamination, 0)

func test_bursts_at_threshold_with_credit_and_reset() -> void:
	_hit()
	_hit()
	var hp_before: int = x.hp
	var third: Dictionary = _hit()
	var burst: int = 38
	assert_eq(third["burst"], burst, "15% de 255 (sem corrosao) = 38, floor")
	assert_eq(x.hp, hp_before - int(third["amount"]) - burst)
	assert_eq(x.contamination, 0)
	assert_eq(third["contamination"], 0)
	var credited: float = b.ledger.get_points(h.id, x.id)
	assert_eq(credited, float(255 - x.hp), "o credito vai para quem deu o golpe, estouro incluido")

func test_burst_can_down_the_target_and_credits_the_hitter() -> void:
	x.contamination = 2
	x.hp = 40
	var hit: Dictionary = _hit()
	assert_true(x.is_down())
	assert_eq(x.hp, 0)
	assert_eq(hit["amount"] + hit["burst"], 40)
	assert_eq(b.ledger.get_points(h.id, x.id), 40.0)
	assert_eq(x.contamination, 0, "caiu: zera")

func test_burst_on_a_hero_records_damage_taken_and_fills_limit() -> void:
	x.base = Stats.make(40, 0, 30, 1)
	h.base = Stats.make(40, 0, 30, 1)
	h.hp = 255
	h.contamination = 2
	var hit: Dictionary = _hit(x, h)
	assert_gt(hit["burst"], 0)
	assert_eq(int(h.damage_taken_from.get(x.id, 0)), int(hit["amount"]) + int(hit["burst"]))
	assert_gt(h.limit, 0.0)

func test_decays_one_per_two_actions_of_the_target() -> void:
	var ctrl := BattleController.new(b)
	x.contamination = 2
	ctrl._on_action_fired(x)
	assert_eq(x.contamination, 2)
	ctrl._on_action_fired(x)
	assert_eq(x.contamination, 1)
	ctrl._on_action_fired(x)
	assert_eq(x.contamination, 1)
	ctrl._on_action_fired(x)
	assert_eq(x.contamination, 0)
	ctrl._on_action_fired(x)
	assert_eq(x.contamination, 0)
	assert_eq(x.contam_actions, 0, "sem contaminacao nao conta acoes")

func test_other_combatants_actions_do_not_decay() -> void:
	var ctrl := BattleController.new(b)
	x.contamination = 2
	for i: int in 4:
		ctrl._on_action_fired(h)
	assert_eq(x.contamination, 2)

func test_decay_runs_through_the_real_battle_loop() -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 1)), cfg), Vector2.ZERO)
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(10, 1, 50, 5)), &"x", Vector2.ZERO, cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	var ctrl := BattleController.new(b)
	h.contamination = 2
	for n: int in 2:
		while ctrl.session == null:
			ctrl.tick(0.05)
		var s: SelectionSession = ctrl.session
		assert_true(s.choose_ability(s.actor.basic_attack))
		s.set_center(x)
		ctrl.submit(s.confirm())
		for i: int in 14:
			ctrl.tick(0.05)
	assert_eq(h.contamination, 1, "duas acoes do proprio contaminado: perde 1")

# --- corrosao ----------------------------------------------------------------

func test_corrodes_vitality_per_stack() -> void:
	var base: int = StatCalculator.effective(x, &"vitality", b.cfg)
	assert_eq(base, 25)
	x.contamination = 1
	assert_eq(StatCalculator.effective(x, &"vitality", b.cfg), 22, "25 x 0.9 = 22 (floor)")
	x.contamination = 2
	assert_eq(StatCalculator.effective(x, &"vitality", b.cfg), 20)
	x.contamination = 3
	assert_eq(StatCalculator.effective(x, &"vitality", b.cfg), 17)
	x.contamination = 0
	assert_eq(StatCalculator.effective(x, &"vitality", b.cfg), 25)

func test_corrosion_leaves_other_attributes_alone() -> void:
	var str0: int = StatCalculator.effective(x, &"strength", b.cfg)
	x.contamination = 3
	assert_eq(StatCalculator.effective(x, &"strength", b.cfg), str0)

func test_corrosion_never_zeroes_vitality() -> void:
	b.cfg.rad_corrode_per_stack = 0.6
	x.contamination = 3
	assert_eq(StatCalculator.effective(x, &"vitality", b.cfg), 1)

func test_corrosion_lowers_defense_so_later_hits_hurt_more() -> void:
	var first: int = int(_hit()["amount"])
	var second: int = int(_hit()["amount"])
	assert_gt(second, first)

# --- fere o usuario ----------------------------------------------------------

func test_self_harm_is_a_fraction_of_effective_damage() -> void:
	var hit: Dictionary = _hit()
	assert_eq(hit["self_damage"], floori(float(hit["amount"]) * 0.1))
	assert_eq(h.hp, 25 - int(hit["self_damage"]))
	assert_gt(hit["self_damage"], 0)

func test_self_harm_never_downs_and_never_fills_limit() -> void:
	b.cfg.rad_self_pct = 5.0
	h.hp = 4
	var hit: Dictionary = _hit()
	assert_eq(h.hp, 1)
	assert_eq(hit["self_damage"], 3)
	assert_eq(h.limit, 0.0)
	var again: Dictionary = _hit()
	assert_eq(again["self_damage"], 0)
	assert_eq(h.hp, 1)

func test_self_harm_skips_when_no_effective_damage() -> void:
	b.statuses.apply_forced(x, Fixtures.status_def(StatusDef.Kind.BARRIER, 5, 9999))
	var hit: Dictionary = _hit()
	assert_eq(hit["self_damage"], 0)
	assert_eq(h.hp, 25)

func test_radioactive_consumes_no_dice() -> void:
	var dice := ScriptedDice.new([0.1, 0.2])
	b = BattleState.create(b.cfg, dice, [h], [x])
	for i: int in 3:
		_hit()
	assert_eq(dice._i, 0)

# --- zera ao cair e no fim da batalha ----------------------------------------

func test_resets_when_the_target_goes_down() -> void:
	x.contamination = 1
	x.contam_actions = 1
	x.hp = 1
	_hit()
	assert_true(x.is_down())
	assert_eq(x.contamination, 0)
	assert_eq(x.contam_actions, 0)

func test_resets_when_downed_by_poison() -> void:
	var ctrl := BattleController.new(b)
	assert_not_null(ctrl)
	x.contamination = 2
	b.statuses.clear_all(x)
	assert_eq(x.contamination, 0)

func test_resets_at_the_end_of_the_battle() -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 1)), cfg), Vector2.ZERO)
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(10, 1, 5, 5)), &"x", Vector2.ZERO, cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	var ctrl := BattleController.new(b)
	h.contamination = 2
	x.hp = 1
	while ctrl.session == null:
		ctrl.tick(0.05)
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(s.actor.basic_attack))
	s.set_center(x)
	ctrl.submit(s.confirm())
	for i: int in 40:
		ctrl.tick(0.05)
	assert_eq(ctrl.outcome, BattleController.Outcome.VICTORY)
	assert_eq(h.contamination, 0)
	assert_eq(h.contam_actions, 0)

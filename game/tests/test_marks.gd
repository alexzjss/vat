extends GutTest
## M14 Task 1: marcas elementais. Defs em memoria; os dados de teste continuam neutros.

var b: BattleState
var h: Combatant
var x: Combatant
var y: Combatant
var fire: ElementDef
var water: ElementDef
var rad: ElementDef

func _el(id: StringName, reacts: bool = true, rule: ElementDef.Rule = ElementDef.Rule.NORMAL) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	e.reacts = reacts
	e.rule = rule
	return e

func before_each() -> void:
	fire = _el(&"fire")
	water = _el(&"water")
	rad = _el(&"rad", false, ElementDef.Rule.RADIOACTIVE)
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(40, 0, 2, 4)), cfg), Vector2(0, 0))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 0, 12, 1)), &"x", Vector2(100, 0), cfg)
	y = Combatant.from_enemy(Fixtures.enemy_def(&"y", Stats.make(1, 0, 12, 1)), &"y", Vector2(150, 0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x, y])

func _ability(element: ElementDef, shape: AbilityDef.Shape = AbilityDef.Shape.SINGLE) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(1.0, shape)
	a.element = element
	a.radius = 200.0
	return a

func _fire(actor: Combatant, target: Combatant, ability: AbilityDef) -> ActionResult:
	var a := PendingAction.new()
	a.actor = actor
	a.ability = ability
	a.center = target
	a.center_pos = target.position
	return ActionExecutor.apply(a, b)

func _barrier(target: Combatant, points: int) -> void:
	var s: StatusDef = Fixtures.status_def(StatusDef.Kind.BARRIER, 3, points)
	b.statuses.apply_forced(target, s)

# --- quem marca ---------------------------------------------------------------

func test_reacting_element_marks_target() -> void:
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_eq(x.mark, fire)
	assert_eq(x.mark_turns, 3)
	assert_eq(r.hits[0]["mark"], &"fire")

func test_neutral_hit_does_not_mark() -> void:
	var r: ActionResult = _fire(h, x, _ability(null))
	assert_null(x.mark)
	assert_eq(r.hits[0]["mark"], &"")

func test_radioactive_does_not_mark() -> void:
	_fire(h, x, _ability(rad))
	assert_null(x.mark)

func test_immune_does_not_mark() -> void:
	x.enemy_def.element_resist = {&"fire": 1.0}
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_eq(r.hits[0]["affinity"], ElementMath.Affinity.IMMUNE)
	assert_null(x.mark)

func test_absorb_does_not_mark() -> void:
	x.enemy_def.element_resist = {&"fire": 1.5}
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_eq(r.hits[0]["affinity"], ElementMath.Affinity.ABSORB)
	assert_null(x.mark)

func test_dodge_does_not_mark() -> void:
	b.dice = ScriptedDice.new([0.0] as Array[float])
	x.base.speed = 20
	var ab: AbilityDef = _ability(fire)
	ab.effects[0].dodgeable = true
	var r: ActionResult = _fire(h, x, ab)
	assert_true(r.hits[0]["dodged"])
	assert_null(x.mark)

func test_blind_miss_does_not_mark() -> void:
	b.dice = ScriptedDice.new([0.0] as Array[float])
	b.statuses.apply_forced(h, Fixtures.status_def(StatusDef.Kind.BLIND, 3))
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_true(r.hits[0]["missed"])
	assert_null(x.mark)

func test_barrier_absorbing_everything_still_marks() -> void:
	_barrier(x, 999)
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_eq(r.hits[0]["amount"], 0)
	assert_eq(x.mark, fire)

func test_weak_and_resisted_hits_mark() -> void:
	x.enemy_def.element_resist = {&"fire": -0.5, &"water": 0.5}
	_fire(h, x, _ability(fire))
	assert_eq(x.mark, fire)
	x.mark = null
	_fire(h, x, _ability(water))
	assert_eq(x.mark, water)

func test_killing_blow_leaves_no_mark() -> void:
	x.hp = 1
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_true(x.is_down())
	assert_null(x.mark)
	assert_eq(x.mark_turns, 0)
	assert_eq(r.hits[0]["mark"], &"")

# --- troca e renovacao --------------------------------------------------------

func test_same_element_renews_turns() -> void:
	_fire(h, x, _ability(fire))
	x.mark_turns = 1
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_eq(x.mark, fire)
	assert_eq(x.mark_turns, 3)
	assert_eq(r.hits[0]["mark"], &"fire")

func test_different_element_replaces_mark_when_table_is_empty() -> void:
	_fire(h, x, _ability(fire))
	_fire(h, x, _ability(water))
	assert_eq(x.mark, water)
	assert_eq(x.mark_turns, 3)

func test_neutral_hit_keeps_existing_mark_and_turns() -> void:
	_fire(h, x, _ability(fire))
	x.mark_turns = 2
	var r: ActionResult = _fire(h, x, _ability(null))
	assert_eq(x.mark, fire)
	assert_eq(x.mark_turns, 2)
	assert_eq(r.hits[0]["mark"], &"fire", "o hit mostra a marca que o alvo carrega")

func test_blocked_hit_keeps_existing_mark() -> void:
	_fire(h, x, _ability(fire))
	x.enemy_def.element_resist = {&"water": 1.0}
	_fire(h, x, _ability(water))
	assert_eq(x.mark, fire)

# --- contagem de turnos -------------------------------------------------------

func test_mark_counts_down_on_atb_full_and_expires() -> void:
	_fire(h, x, _ability(fire))
	var none: Array[Combatant] = []
	b.statuses.on_atb_full(x, none)
	assert_eq(x.mark_turns, 2)
	b.statuses.on_atb_full(x, none)
	assert_eq(x.mark_turns, 1)
	var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(x, none)
	assert_null(x.mark)
	assert_eq(x.mark_turns, 0)
	assert_true(out.mark_expired)

func test_unmarked_combatant_is_unaffected_by_countdown() -> void:
	var none: Array[Combatant] = []
	var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(x, none)
	assert_false(out.mark_expired)
	assert_eq(x.mark_turns, 0)

# --- uma vez por habilidade por alvo -----------------------------------------

func test_multi_damage_ability_marks_once_per_target() -> void:
	var ab: AbilityDef = _ability(fire)
	ab.effects.append(Fixtures.hit(1.0).effects[0])
	var r: ActionResult = _fire(h, x, ab)
	assert_eq(r.hits.size(), 2)
	assert_eq(x.mark, fire)
	assert_eq(r.hits[0]["mark"], &"fire")
	assert_eq(r.hits[1]["mark"], &"fire", "o segundo golpe mostra a marca que ja esta la")

func test_second_effect_marks_when_first_missed() -> void:
	b.dice = ScriptedDice.new([0.0] as Array[float])
	x.base.speed = 20
	var ab: AbilityDef = _ability(fire)
	ab.effects[0].dodgeable = true
	ab.effects.append(Fixtures.hit(1.0).effects[0])
	var r: ActionResult = _fire(h, x, ab)
	assert_true(r.hits[0]["dodged"])
	assert_eq(x.mark, fire)
	assert_eq(r.hits[1]["mark"], &"fire")

func test_second_effect_does_not_renew_after_first() -> void:
	_fire(h, x, _ability(fire))
	x.mark_turns = 1
	var ab: AbilityDef = _ability(fire)
	ab.effects.append(Fixtures.hit(1.0).effects[0])
	_fire(h, x, ab)
	assert_eq(x.mark_turns, 3)

# --- area ---------------------------------------------------------------------

func test_area_marks_each_target_separately() -> void:
	y.enemy_def.element_resist = {&"fire": 1.0}
	var r: ActionResult = _fire(h, x, _ability(fire, AbilityDef.Shape.ALL))
	assert_eq(r.hits.size(), 2)
	assert_eq(x.mark, fire)
	assert_null(y.mark, "imune nao marca")

func test_area_marks_all_hit_targets() -> void:
	_fire(h, x, _ability(water, AbilityDef.Shape.ALL))
	assert_eq(x.mark, water)
	assert_eq(y.mark, water)

# --- some --------------------------------------------------------------------

func test_clear_all_clears_mark() -> void:
	_fire(h, x, _ability(fire))
	b.statuses.clear_all(x)
	assert_null(x.mark)
	assert_eq(x.mark_turns, 0)

func test_marks_clear_when_battle_ends_in_victory() -> void:
	var ctrl := BattleController.new(b)
	_fire(h, y, _ability(fire))
	_fire(x, h, _ability(water))
	assert_not_null(h.mark)
	x.hp = 0
	y.hp = 0
	ctrl.tick(0.1)
	assert_eq(ctrl.outcome, BattleController.Outcome.VICTORY)
	for c: Combatant in b.all():
		assert_null(c.mark)
		assert_eq(c.mark_turns, 0)

func test_marks_clear_when_battle_ends_in_flight() -> void:
	var ctrl := BattleController.new(b)
	ctrl.can_flee = true
	_fire(h, x, _ability(fire))
	ctrl.flee_gauge = 1.0
	ctrl.update_flee(0.1, true)
	assert_eq(ctrl.outcome, BattleController.Outcome.FLED)
	assert_null(x.mark)

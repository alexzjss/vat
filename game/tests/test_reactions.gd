extends GutTest
## M14 Task 2: motor de reacoes. Tabela pequena em memoria; os dados de teste continuam neutros.
## Heroi: Forca 40 contra Vit 12 = 24 de dano, HP maximo 25. Inimigo: HP 125.

var b: BattleState
var h: Combatant
var h2: Combatant
var x: Combatant
var y: Combatant
var z: Combatant
var fire: ElementDef
var water: ElementDef
var earth: ElementDef
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
	earth = _el(&"earth")
	rad = _el(&"rad", false, ElementDef.Rule.RADIOACTIVE)
	_build([] as Array[float])

func _build(dice_values: Array[float]) -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(40, 0, 2, 4)), cfg), Vector2(0, 0))
	h2 = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"b", Stats.make(40, 0, 2, 4)), cfg), Vector2(0, 50))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 0, 12, 1)), &"x", Vector2(100, 0), cfg)
	y = Combatant.from_enemy(Fixtures.enemy_def(&"y", Stats.make(1, 0, 12, 1)), &"y", Vector2(150, 0), cfg)
	z = Combatant.from_enemy(Fixtures.enemy_def(&"z", Stats.make(1, 0, 12, 1)), &"z", Vector2(900, 0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(dice_values), [h, h2], [x, y, z])

## Reacao fogo + agua; `fields` sobrescreve propriedades (bonus_pct, keep, ...).
func _def(fields: Dictionary = {}) -> ReactionDef:
	var d := ReactionDef.new()
	d.id = &"steam"
	d.a = fire
	d.b = water
	for k: String in fields:
		d.set(k, fields[k])
	var t := ReactionTable.new()
	t.reactions = [d] as Array[ReactionDef]
	b.reactions = t
	return d

func _ability(element: ElementDef, shape: AbilityDef.Shape = AbilityDef.Shape.SINGLE) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(1.0, shape)
	a.element = element
	a.radius = 200.0
	return a

func _fire(actor: Combatant, target: Combatant, ability: AbilityDef, counter: bool = false) -> ActionResult:
	var a := PendingAction.new()
	a.actor = actor
	a.ability = ability
	a.center = target
	a.center_pos = target.position
	a.is_counter = counter
	return ActionExecutor.apply(a, b)

## Marca `t` com fogo e acerta agua nele: o par da reacao de teste.
func _combo(t: Combatant = x, shape: AbilityDef.Shape = AbilityDef.Shape.SINGLE) -> ActionResult:
	MarkRules.set_mark(t, fire, 3)
	return _fire(h, t, _ability(water, shape))

func _status(kind: StatusDef.Kind, id: StringName, contribution: int = 0, potency: int = 0) -> StatusDef:
	var s: StatusDef = Fixtures.status_def(kind, 3, potency)
	s.id = id
	s.apply_contribution = contribution
	return s

func _list(items: Array) -> Array[StatusDef]:
	var out: Array[StatusDef] = []
	for i: StatusDef in items:
		out.append(i)
	return out

func _has_status(c: Combatant, id: StringName) -> bool:
	for s: ActiveStatus in c.statuses:
		if s.def.id == id:
			return true
	return false

# --- quando reage --------------------------------------------------------------

func test_plain_hit_has_empty_reaction_fields() -> void:
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_eq(r.hits[0]["reaction"], &"")
	assert_eq(r.hits[0]["reaction_effects"], {})

func test_empty_table_never_reacts() -> void:
	var r: ActionResult = _combo()
	assert_eq(r.hits[0]["reaction"], &"")
	assert_eq(x.mark, water, "sem reacao a marca so troca")

func test_different_elements_react_and_consume_both_marks() -> void:
	_def()
	var r: ActionResult = _combo()
	assert_eq(r.hits[0]["reaction"], &"steam")
	assert_null(x.mark)
	assert_eq(x.mark_turns, 0)
	assert_eq(r.hits[0]["mark"], &"")

func test_pair_is_unordered() -> void:
	_def()
	MarkRules.set_mark(x, water, 3)
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_eq(r.hits[0]["reaction"], &"steam")

func test_same_element_renews_without_reacting() -> void:
	_def({"bonus_pct": 1.0})
	MarkRules.set_mark(x, fire, 1)
	var r: ActionResult = _fire(h, x, _ability(fire))
	assert_eq(r.hits[0]["reaction"], &"")
	assert_eq(x.mark_turns, 3)
	assert_eq(x.hp, 125 - 24)

func test_pair_missing_from_table_replaces_mark() -> void:
	_def()
	MarkRules.set_mark(x, earth, 3)
	var r: ActionResult = _fire(h, x, _ability(water))
	assert_eq(r.hits[0]["reaction"], &"")
	assert_eq(x.mark, water)

func test_no_reaction_without_prior_mark() -> void:
	_def({"bonus_pct": 1.0})
	var r: ActionResult = _fire(h, x, _ability(water))
	assert_eq(r.hits[0]["reaction"], &"")
	assert_eq(x.mark, water)

func test_no_reaction_when_target_goes_down_with_the_hit() -> void:
	_def({"bonus_pct": 1.0})
	x.hp = 20
	var r: ActionResult = _combo()
	assert_true(x.is_down())
	assert_eq(r.hits[0]["reaction"], &"")
	assert_null(x.mark)

func test_no_reaction_when_new_hit_is_absorbed() -> void:
	_def({"bonus_pct": 1.0})
	x.enemy_def.element_resist = {&"water": 1.5}
	var r: ActionResult = _combo()
	assert_eq(r.hits[0]["reaction"], &"")
	assert_eq(x.mark, fire, "a marca antiga fica")

func test_no_reaction_when_new_hit_is_immune() -> void:
	_def({"bonus_pct": 1.0})
	x.enemy_def.element_resist = {&"water": 1.0}
	var r: ActionResult = _combo()
	assert_eq(r.hits[0]["reaction"], &"")
	assert_eq(x.mark, fire)
	assert_eq(x.hp, 125)

func test_radioactive_never_reacts() -> void:
	var d: ReactionDef = _def({"bonus_pct": 1.0})
	d.b = rad
	var r: ActionResult = _fire(h, x, _ability(rad))
	assert_eq(r.hits[0]["reaction"], &"")

func test_reaction_fires_on_barrier_absorbed_hit() -> void:
	_def({"bonus_pct": 0.5})
	b.statuses.apply_forced(x, _status(StatusDef.Kind.BARRIER, &"barrier", 0, 999))
	var r: ActionResult = _combo()
	assert_eq(r.hits[0]["amount"], 0)
	assert_eq(r.hits[0]["reaction"], &"steam")

# --- bonus_pct -----------------------------------------------------------------

func test_bonus_pct_deals_extra_damage_floor_of_final_damage() -> void:
	_def({"bonus_pct": 0.5})
	var r: ActionResult = _combo()
	assert_eq(r.hits[0]["amount"], 24, "o golpe em si nao muda")
	assert_eq(r.hits[0]["reaction_effects"]["extra_damage"], 12)
	assert_eq(x.hp, 125 - 24 - 12)

func test_extra_damage_does_not_pass_affinity_again() -> void:
	_def({"bonus_pct": 0.5})
	x.enemy_def.element_resist = {&"water": -0.5}
	var r: ActionResult = _combo()
	assert_eq(r.hits[0]["amount"], 36, "24 x 1.5")
	assert_eq(r.hits[0]["reaction_effects"]["extra_damage"], 18, "floor(36 x 0.5), sem nova afinidade")

func test_extra_damage_does_not_mark_or_react_again() -> void:
	_def({"bonus_pct": 0.5, "keep": null})
	var r: ActionResult = _combo()
	assert_eq(r.hits.size(), 1, "o dano extra nao e um hit")
	assert_null(x.mark)

func test_barrier_takes_what_is_left_of_the_extra_damage() -> void:
	_def({"bonus_pct": 0.5})
	b.statuses.apply_forced(x, _status(StatusDef.Kind.BARRIER, &"barrier", 0, 30))
	var r: ActionResult = _combo()
	assert_eq(r.hits[0]["amount"], 0, "a barreira de 30 absorveu os 24")
	assert_eq(r.hits[0]["reaction_effects"]["extra_damage"], 6, "12 de extra: 6 na barreira, 6 no HP")
	assert_eq(x.hp, 125 - 6)

func test_extra_damage_can_down_the_target() -> void:
	_def({"bonus_pct": 0.5})
	x.hp = 30
	var r: ActionResult = _combo()
	assert_true(x.is_down())
	assert_true(r.downed.has(x))
	assert_eq(r.hits[0]["reaction"], &"steam")
	assert_eq(r.hits[0]["reaction_effects"]["extra_damage"], 6, "so o HP que restava")
	assert_null(x.mark)

func test_extra_damage_kill_skips_target_effects() -> void:
	_build([0.0] as Array[float])
	x.hp = 30
	_def({"bonus_pct": 1.0, "target_statuses": _list([_status(StatusDef.Kind.SLOW, &"slow")]), "status_chance": 1.0})
	_combo()
	assert_true(x.is_down())
	assert_false(_has_status(x, &"slow"))

func test_extra_damage_counts_as_contribution() -> void:
	_def({"bonus_pct": 0.5})
	_combo()
	assert_eq(b.ledger.get_points(&"a", &"x"), 36.0, "24 do golpe + 12 do extra")

# --- keep ----------------------------------------------------------------------

func test_keep_old_element_leaves_that_mark() -> void:
	_def({"keep": fire})
	_combo()
	assert_eq(x.mark, fire)
	assert_eq(x.mark_turns, 3)

func test_keep_new_element_leaves_that_mark() -> void:
	_def({"keep": water})
	var r: ActionResult = _combo()
	assert_eq(x.mark, water)
	assert_eq(r.hits[0]["mark"], &"water")

# --- area ----------------------------------------------------------------------

func test_area_hits_other_allies_in_radius_neutral_without_marks() -> void:
	_def({"area_pct": 0.5, "area_radius": 200.0})
	var r: ActionResult = _combo()
	assert_eq(y.hp, 125 - 12)
	assert_eq(z.hp, 125, "fora do raio")
	assert_eq(x.hp, 125 - 24, "o alvo nao leva a area")
	assert_null(y.mark, "a area nao marca")
	var area: Array = r.hits[0]["reaction_effects"]["area"]
	assert_eq(area.size(), 1)
	assert_eq(area[0]["target_id"], &"y")
	assert_eq(area[0]["amount"], 12)

## Chefe de teste: `x` (alvo do golpe) e o nucleo; `y` (no raio) e uma parte que protege o nucleo.
func _boss_x_core_y_arm() -> void:
	x.enemy_def.role = EnemyDef.Role.CORE
	y.enemy_def.role = EnemyDef.Role.PART
	y.enemy_def.shields_core = true

## Chefe de teste: `x` (alvo do golpe) e uma parte protetora e `y` (no raio) e o nucleo.
func _boss_x_arm_y_core() -> void:
	x.enemy_def.role = EnemyDef.Role.PART
	x.enemy_def.shields_core = true
	y.enemy_def.role = EnemyDef.Role.CORE

func test_area_damage_respects_the_shielded_core() -> void:
	_def({"area_pct": 0.5, "area_radius": 200.0})
	_boss_x_arm_y_core()
	assert_true(b.core_shielded(y))
	var r: ActionResult = _combo()
	# golpe 24 no Braco; area = 12, reduzida pelo escudo do nucleo (x0,25 = 3).
	assert_eq(y.hp, 125 - maxi(1, floori(12.0 * b.cfg.core_shield_mult)))
	assert_eq(r.hits[0]["reaction_effects"]["area"][0]["amount"], 125 - y.hp)

func test_area_damage_to_shielded_core_has_a_minimum_of_one() -> void:
	_def({"area_pct": 0.1, "area_radius": 200.0})
	_boss_x_arm_y_core()
	_combo()
	assert_eq(y.hp, 125 - 1, "area 2 x 0,25 = 0: o escudo nunca zera o dano")

func test_area_damage_is_full_when_the_core_is_unshielded() -> void:
	_def({"area_pct": 0.5, "area_radius": 200.0})
	_boss_x_arm_y_core()
	x.enemy_def.shields_core = false
	assert_false(b.core_shielded(y))
	_combo()
	assert_eq(y.hp, 125 - 12)

func test_extra_damage_is_already_shielded_through_the_final_hit() -> void:
	# O dano extra usa o dano final do golpe (depois do escudo do nucleo): nao precisa de escudo a parte.
	_def({"bonus_pct": 0.5})
	_boss_x_core_y_arm()
	var r: ActionResult = _combo()
	var hit_dmg: int = maxi(1, floori(24.0 * b.cfg.core_shield_mult))
	assert_eq(r.hits[0]["amount"], hit_dmg)
	assert_eq(r.hits[0]["reaction_effects"]["extra_damage"], floori(float(hit_dmg) * 0.5))

func test_area_kill_of_the_last_part_unshields_the_core() -> void:
	_def({"area_pct": 0.5, "area_radius": 200.0})
	_boss_x_core_y_arm()
	y.hp = 1
	var r: ActionResult = _combo()
	assert_true(y.is_down())
	assert_true(r.downed.has(y))
	assert_false(b.core_shielded(x), "sem a parte de pe, o nucleo volta a levar dano cheio")

func test_area_kill_of_the_core_collapses_the_remaining_parts() -> void:
	_def({"area_pct": 0.5, "area_radius": 200.0})
	_boss_x_arm_y_core()
	z.enemy_def.role = EnemyDef.Role.PART
	z.enemy_def.shields_core = true
	z.position = Vector2(120, 0)
	y.hp = 1
	var r: ActionResult = _combo()
	assert_true(y.is_down(), "a area de 3 derruba o nucleo de 1 HP mesmo com o escudo")
	assert_true(b.enemies_defeated())
	assert_true(x.is_down() and z.is_down(), "as partes caem junto com o nucleo")
	assert_true(r.downed.has(x) and r.downed.has(z) and r.downed.has(y))

func test_area_has_no_chain_reaction() -> void:
	_def({"area_pct": 0.5, "area_radius": 200.0, "bonus_pct": 1.0})
	MarkRules.set_mark(y, fire, 3)
	_combo()
	assert_eq(y.mark, fire, "a marca de quem tomou a area nao muda nem reage")
	assert_eq(y.hp, 125 - 12, "so a area, sem extra")

func test_area_is_neutral_even_against_weakness() -> void:
	_def({"area_pct": 0.5, "area_radius": 200.0})
	y.enemy_def.element_resist = {&"water": -0.5}
	_combo()
	assert_eq(y.hp, 125 - 12)

func test_area_damage_counts_as_contribution_and_can_down() -> void:
	_def({"area_pct": 0.5, "area_radius": 200.0})
	y.hp = 5
	var r: ActionResult = _combo()
	assert_true(y.is_down())
	assert_true(r.downed.has(y))
	assert_eq(b.ledger.get_points(&"a", &"y"), 5.0)

func test_area_statuses_use_status_chance() -> void:
	_build([0.0, 0.99] as Array[float])
	_def({"area_radius": 500.0, "area_statuses": _list([_status(StatusDef.Kind.SLOW, &"slow")]), "status_chance": 0.5})
	_combo()
	assert_true(_has_status(y, &"slow"), "primeiro sorteio 0.0 < 0.5")
	assert_false(_has_status(z, &"slow"), "segundo sorteio 0.99 resiste")

# --- estados -------------------------------------------------------------------

func test_target_status_applies_on_chance() -> void:
	_build([0.0] as Array[float])
	_def({"target_statuses": _list([_status(StatusDef.Kind.SLOW, &"slow")]), "status_chance": 0.5})
	var r: ActionResult = _combo()
	assert_true(_has_status(x, &"slow"))
	var sts: Array = r.hits[0]["reaction_effects"]["statuses"]
	assert_eq(sts.size(), 1)
	assert_eq(sts[0]["target_id"], &"x")
	assert_eq(sts[0]["status_id"], &"slow")
	assert_eq(sts[0]["result"], StatusSystem.ApplyResult.APPLIED)

func test_target_status_can_be_resisted_by_chance() -> void:
	_build([0.99] as Array[float])
	_def({"target_statuses": _list([_status(StatusDef.Kind.SLOW, &"slow")]), "status_chance": 0.5})
	var r: ActionResult = _combo()
	assert_false(_has_status(x, &"slow"))
	assert_eq(r.hits[0]["reaction_effects"]["statuses"][0]["result"], StatusSystem.ApplyResult.RESISTED)

func test_target_status_respects_immunity() -> void:
	_build([0.0] as Array[float])
	x.enemy_def.immunities = [&"slow"] as Array[StringName]
	_def({"target_statuses": _list([_status(StatusDef.Kind.SLOW, &"slow")]), "status_chance": 1.0})
	var r: ActionResult = _combo()
	assert_eq(r.hits[0]["reaction_effects"]["statuses"][0]["result"], StatusSystem.ApplyResult.IMMUNE)

func test_reaction_status_gives_todays_status_credit() -> void:
	_build([0.0] as Array[float])
	_def({"target_statuses": _list([_status(StatusDef.Kind.SLOW, &"slow", 10)]), "status_chance": 1.0})
	_combo()
	assert_eq(b.ledger.get_points(&"a", &"x"), 34.0, "24 de dano + 10 do estado, sem bonus de reacao")

func test_attacker_statuses_apply_without_roll() -> void:
	_def({"attacker_statuses": _list([_status(StatusDef.Kind.HASTE, &"haste")])})
	var r: ActionResult = _combo()
	assert_true(_has_status(h, &"haste"))
	assert_eq(r.hits[0]["reaction_effects"]["statuses"][0]["target_id"], &"a")

func test_remove_target_statuses() -> void:
	var slow: StatusDef = _status(StatusDef.Kind.SLOW, &"slow")
	_def({"remove_target_statuses": _list([slow])})
	b.statuses.apply_forced(x, slow)
	var r: ActionResult = _combo()
	assert_false(_has_status(x, &"slow"))
	assert_eq(r.hits[0]["reaction_effects"]["removed"], 1)

func test_remove_runs_after_target_statuses() -> void:
	_build([0.0] as Array[float])
	var slow: StatusDef = _status(StatusDef.Kind.SLOW, &"slow")
	_def({"target_statuses": _list([slow]), "status_chance": 1.0, "remove_target_statuses": _list([slow])})
	_combo()
	assert_false(_has_status(x, &"slow"))

# --- ATB -----------------------------------------------------------------------

func test_target_atb_is_a_fraction_of_the_bar() -> void:
	_def({"target_atb": -0.25})
	x.atb = 0.8
	var r: ActionResult = _combo()
	assert_almost_eq(x.atb, 0.55, 0.0001)
	assert_almost_eq(float(r.hits[0]["reaction_effects"]["atb"]["target"]), -0.25, 0.0001)

func test_target_atb_clamps_to_bar() -> void:
	_def({"target_atb": -0.25})
	x.atb = 0.1
	_combo()
	assert_eq(x.atb, 0.0)
	_def({"target_atb": 0.9})
	x.atb = 0.5
	_combo()
	assert_eq(x.atb, 1.0)

func test_target_delay_removes_a_ready_target_from_the_queue() -> void:
	_def({"target_atb": -0.25})
	x.atb = 1.0
	b.queue.push(x, 0)
	_combo()
	assert_almost_eq(x.atb, 0.75, 0.0001)
	assert_false(b.queue.has(x))

func test_target_gaining_a_full_bar_enters_the_queue() -> void:
	_def({"target_atb": 0.5})
	x.atb = 0.7
	_combo()
	assert_eq(x.atb, 1.0)
	assert_true(b.queue.has(x))

func test_attacker_atb_is_deferred_until_the_action_ends() -> void:
	_def({"attacker_atb": 0.3})
	h.atb = 1.0
	var r: ActionResult = _combo()
	assert_eq(h.atb_bonus, 0.3, "a barra do ator ainda vai ser zerada no fim da acao")
	assert_eq(h.atb, 1.0)
	assert_almost_eq(float(r.hits[0]["reaction_effects"]["atb"]["attacker"]), 0.3, 0.0001)

func test_attacker_atb_applies_directly_on_counter() -> void:
	_def({"attacker_atb": 0.3})
	h.atb = 0.2
	MarkRules.set_mark(x, fire, 3)
	_fire(h, x, _ability(water), true)
	assert_almost_eq(h.atb, 0.5, 0.0001)
	assert_eq(h.atb_bonus, 0.0)

func test_controller_keeps_attacker_atb_bonus_after_the_action() -> void:
	_def({"attacker_atb": 0.3})
	var ctrl := BattleController.new(b)
	var done: Array[bool] = [false]
	ctrl.action_finished.connect(func(_a: PendingAction) -> void: done[0] = true)
	h.basic_attack.element = water
	MarkRules.set_mark(x, fire, 3)
	h.atb = 0.999
	ctrl.tick(0.05)
	var s: SelectionSession = ctrl.session
	assert_not_null(s)
	s.choose_ability(s.actor.basic_attack)
	s.set_center(x)
	ctrl.submit(s.confirm())
	var guard: int = 0
	while not done[0] and guard < 400:
		ctrl.tick(0.05)
		guard += 1
	assert_true(done[0])
	assert_almost_eq(h.atb, 0.3, 0.06)
	assert_eq(h.atb_bonus, 0.0)

# --- cura ----------------------------------------------------------------------

func test_heal_attacker_pct_uses_restore_cap() -> void:
	_def({"heal_attacker_pct": 0.5})
	h.hp = 10
	var r: ActionResult = _combo()
	assert_eq(h.hp, 22, "10 + floor(24 x 0.5)")
	assert_eq(r.hits[0]["reaction_effects"]["heal_attacker"], 12)
	h.hp = 20
	_combo()
	assert_eq(h.hp, 25, "nao passa do HP maximo")

func test_heal_allies_pct_heals_the_attackers_group() -> void:
	_def({"heal_allies_pct": 0.25})
	h.hp = 10
	h2.hp = 20
	var r: ActionResult = _combo()
	assert_eq(h.hp, 16)
	assert_eq(h2.hp, 25, "20 + 6 passa do maximo: so 5")
	var heals: Array = r.hits[0]["reaction_effects"]["heal_allies"]
	assert_eq(heals.size(), 2)

func test_reaction_heals_give_no_contribution() -> void:
	_def({"heal_allies_pct": 0.5, "heal_attacker_pct": 0.5})
	h.hp = 10
	h2.hp = 10
	_combo()
	assert_eq(b.ledger.get_points(&"a", &"x"), 24.0, "so o dano do golpe")

## M14 Task 6: na Transfusao (Luz + Sangue) os dois numeros verdes no atacante sao a cura da reacao (heal_attacker_pct)
## e o roubo de vida do Sangue (lifesteal do golpe); com heal_allies_pct = 0 ninguem mais (nem o atacante) entra em heal_allies.
func test_transfusion_shows_reaction_heal_and_blood_lifesteal_separately() -> void:
	var blood: ElementDef = _el(&"blood", true, ElementDef.Rule.BLOOD)
	_def({"a": blood, "b": water, "heal_attacker_pct": 0.5})
	h.hp = 1
	h2.hp = 10
	MarkRules.set_mark(x, water, 3)
	var r: ActionResult = _fire(h, x, _ability(blood))
	var hit: Dictionary = r.hits[0]
	var fx: Dictionary = hit["reaction_effects"]
	assert_eq(hit["lifesteal"], floori(float(hit["amount"]) * b.cfg.blood_lifesteal), "Sangue: fracao do dano")
	assert_gt(int(fx["heal_attacker"]), 0, "reacao: heal_attacker_pct")
	assert_eq((fx["heal_allies"] as Array).size(), 0, "heal_allies_pct 0: ninguem, nem o atacante")
	assert_eq(h2.hp, 10)

func test_heal_skips_downed_allies() -> void:
	_def({"heal_allies_pct": 0.5})
	h2.hp = 0
	_combo()
	assert_eq(h2.hp, 0)

# --- varios efeitos e area do golpe -------------------------------------------------

func test_multi_damage_ability_reacts_once() -> void:
	_def({"bonus_pct": 0.5})
	MarkRules.set_mark(x, fire, 3)
	var ab: AbilityDef = _ability(water)
	ab.effects.append(Fixtures.hit(1.0).effects[0])
	var r: ActionResult = _fire(h, x, ab)
	assert_eq(r.hits[0]["reaction"], &"steam")
	assert_eq(r.hits[1]["reaction"], &"")
	assert_eq(x.hp, 125 - 24 - 12 - 24, "um extra so, dois golpes")

func test_area_ability_reacts_only_on_marked_targets() -> void:
	_def({"bonus_pct": 0.5})
	MarkRules.set_mark(x, fire, 3)
	var r: ActionResult = _fire(h, x, _ability(water, AbilityDef.Shape.ALL))
	assert_eq(r.hits[0]["reaction"], &"steam")
	assert_eq(r.hits[1]["reaction"], &"")
	assert_eq(y.mark, water, "quem nao tinha marca so e marcado")
	assert_null(x.mark)

# --- simetria ------------------------------------------------------------------

func test_enemies_trigger_reactions_on_heroes() -> void:
	_def({"bonus_pct": 0.5})
	x.base.strength = 10
	MarkRules.set_mark(h, fire, 3)
	var ab: AbilityDef = _ability(water)
	ab.side = AbilityDef.Side.ENEMIES
	var a := PendingAction.new()
	a.actor = x
	a.ability = ab
	a.center = h
	a.center_pos = h.position
	var r: ActionResult = ActionExecutor.apply(a, b)
	assert_eq(r.hits[0]["reaction"], &"steam")
	assert_null(h.mark)
	assert_true(h.hp < 25)
	assert_eq(h.damage_taken_from[&"x"], 25 - h.hp, "o dano extra tambem conta para quem atacou")

# --- ordem ---------------------------------------------------------------------

func test_all_steps_together() -> void:
	_build([0.0, 0.0] as Array[float])
	var slow: StatusDef = _status(StatusDef.Kind.SLOW, &"slow")
	var haste: StatusDef = _status(StatusDef.Kind.HASTE, &"haste")
	_def({"bonus_pct": 0.5, "target_statuses": _list([slow]), "status_chance": 1.0, "area_pct": 0.5, "area_radius": 200.0,
		"target_atb": -0.25, "attacker_atb": 0.2, "attacker_statuses": _list([haste]), "heal_attacker_pct": 0.5, "keep": fire})
	h.hp = 10
	x.atb = 0.6
	var r: ActionResult = _combo()
	var fx: Dictionary = r.hits[0]["reaction_effects"]
	assert_eq(fx["extra_damage"], 12)
	assert_eq(y.hp, 125 - 12)
	assert_true(_has_status(x, &"slow"))
	assert_almost_eq(x.atb, 0.35, 0.0001)
	assert_true(_has_status(h, &"haste"))
	assert_eq(h.hp, 22)
	assert_eq(x.mark, fire)

# --- validador -----------------------------------------------------------------

func _table(defs: Array) -> ReactionTable:
	var t := ReactionTable.new()
	var out: Array[ReactionDef] = []
	for d: ReactionDef in defs:
		out.append(d)
	t.reactions = out
	return t

func _pair(id: StringName, p: ElementDef, q: ElementDef, keep: ElementDef = null) -> ReactionDef:
	var d := ReactionDef.new()
	d.id = id
	d.a = p
	d.b = q
	d.keep = keep
	return d

func _els(items: Array) -> Array[ElementDef]:
	var out: Array[ElementDef] = []
	for e: ElementDef in items:
		out.append(e)
	return out

func test_validator_accepts_a_complete_table() -> void:
	var t: ReactionTable = _table([_pair(&"1", fire, water), _pair(&"2", fire, earth, fire), _pair(&"3", water, earth, earth)])
	assert_eq(ReactionRules.errors(t, _els([fire, water, earth, rad])), [] as Array[String])

func test_validator_flags_duplicate_pairs_in_either_order() -> void:
	var t: ReactionTable = _table([_pair(&"1", fire, water), _pair(&"2", water, fire)])
	var errs: Array[String] = ReactionRules.errors(t, _els([fire, water]))
	assert_eq(errs.size(), 1)
	assert_true(errs[0].contains("repetido"))

func test_validator_flags_missing_pairs() -> void:
	var t: ReactionTable = _table([_pair(&"1", fire, water)])
	var errs: Array[String] = ReactionRules.errors(t, _els([fire, water, earth]))
	assert_eq(errs.size(), 2, "faltam fogo+terra e agua+terra")
	assert_true(errs[0].contains("faltando"))

func test_validator_ignores_non_reacting_elements_when_checking_missing() -> void:
	var t: ReactionTable = _table([_pair(&"1", fire, water)])
	assert_eq(ReactionRules.errors(t, _els([fire, water, rad])).size(), 0)

func test_validator_flags_keep_outside_the_pair() -> void:
	var t: ReactionTable = _table([_pair(&"1", fire, water, earth)])
	var errs: Array[String] = ReactionRules.errors(t, _els([fire, water]))
	assert_eq(errs.size(), 1)
	assert_true(errs[0].contains("keep"))

func test_validator_flags_non_reacting_element_in_a_pair() -> void:
	var t: ReactionTable = _table([_pair(&"1", fire, rad)])
	var errs: Array[String] = ReactionRules.errors(t, _els([fire]))
	assert_eq(errs.size(), 1)
	assert_true(errs[0].contains("nao reage"))

func test_validator_flags_null_elements_and_same_element_pair() -> void:
	var t: ReactionTable = _table([_pair(&"1", fire, null), _pair(&"2", water, water)])
	assert_eq(ReactionRules.errors(t, _els([])).size(), 2)

func test_find_returns_null_for_unknown_pair_and_empty_table() -> void:
	var t: ReactionTable = _table([_pair(&"1", fire, water)])
	assert_null(ReactionRules.find(t, fire, earth))
	assert_null(ReactionRules.find(ReactionTable.new(), fire, water))
	assert_null(ReactionRules.find(null, fire, water))
	assert_eq(ReactionRules.find(t, water, fire).id, &"1")

# --- tabela da batalha -----------------------------------------------------------

func test_battle_state_always_has_a_table() -> void:
	assert_not_null(BattleState.create(Fixtures.cfg(), ScriptedDice.new(), [h], [x]).reactions)

func test_battle_state_table_is_injectable() -> void:
	var t: ReactionTable = _table([_pair(&"1", fire, water)])
	b.reactions = t
	assert_eq(b.reactions, t)

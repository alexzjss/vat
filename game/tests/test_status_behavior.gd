extends GutTest
## M15 Task 2: Provocar, Berserk e Reflexo. Defs em memoria; numeros de teste.

var cfg: BalanceConfig
var b: BattleState
var h: Combatant
var h2: Combatant
var x: Combatant
var x2: Combatant

func before_each() -> void:
	cfg = Fixtures.cfg()
	cfg.berserk_str_pct = 0.5
	h = _hero(&"a", Vector2.ZERO)
	h2 = _hero(&"b", Vector2(0, 300))
	x = _foe(&"x", Vector2(100, 0))
	x2 = _foe(&"x2", Vector2(110, 0))
	b = BattleState.create(cfg, ScriptedDice.new(), [h, h2], [x, x2])

func _hero(id: StringName, pos: Vector2) -> Combatant:
	return Combatant.from_hero(HeroState.create(Fixtures.hero_def(id, Stats.make(10, 5, 5, 4)), cfg), pos)

func _foe(id: StringName, pos: Vector2) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(10, 5, 5, 4)), id, pos, cfg)

func _st(kind: StatusDef.Kind, duration: int = 3, negative: bool = false) -> StatusDef:
	var s: StatusDef = Fixtures.status_def(kind, duration)
	s.negative = negative
	return s

func _give(c: Combatant, kind: StatusDef.Kind, duration: int = 3) -> void:
	b.statuses.apply_forced(c, _st(kind, duration, kind == StatusDef.Kind.BERSERK))

func _el(id: StringName, reacts: bool = true) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	e.reacts = reacts
	return e

func _ability(potency: float, element: ElementDef, shape: AbilityDef.Shape = AbilityDef.Shape.SINGLE, radius: float = 0.0) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(potency, shape)
	a.id = &"tech"
	a.ap_cost = 1
	a.element = element
	a.radius = radius
	return a

func _heal_ability(element: ElementDef, side: AbilityDef.Side) -> AbilityDef:
	var heal := EffectDef.new()
	heal.kind = EffectDef.Kind.HEAL
	heal.scale = EffectDef.Scale.FIXED
	heal.potency = 10.0
	var ab: AbilityDef = _ability(0.0, element)
	ab.side = side
	ab.effects = [heal]
	return ab

func _act(actor: Combatant, ab: AbilityDef, center: Combatant) -> PendingAction:
	var a := PendingAction.new()
	a.actor = actor
	a.ability = ab
	a.center = center
	a.center_pos = center.position
	return a

func _cast(actor: Combatant, ab: AbilityDef, center: Combatant) -> ActionResult:
	return ActionExecutor.apply(_act(actor, ab, center), b)

func _rule(ab: AbilityDef, pick: AiRule.TargetPick) -> AiRule:
	var r := AiRule.new()
	r.ability = ab
	r.pick = pick
	return r

func _run_until(ctrl: BattleController, pred: Callable, max_seconds: float = 30.0) -> bool:
	for i: int in int(max_seconds / 0.05):
		ctrl.tick(0.05)
		if pred.call():
			return true
	return false

func _first_action(ctrl: BattleController) -> Array[PendingAction]:
	var seen: Array[PendingAction] = []
	ctrl.action_started.connect(func(a: PendingAction) -> void: seen.append(a))
	_run_until(ctrl, func() -> bool: return not seen.is_empty())
	return seen

# --- dados e HUD -------------------------------------------------------------

func test_data_files_have_the_new_kinds() -> void:
	var want: Dictionary = {&"taunt": StatusDef.Kind.TAUNT, &"berserk": StatusDef.Kind.BERSERK, &"reflect": StatusDef.Kind.REFLECT}
	for id: StringName in want:
		var d: StatusDef = load("res://data/test/statuses/%s.tres" % id) as StatusDef
		assert_not_null(d, str(id))
		if d != null:
			assert_eq(d.id, id)
			assert_eq(d.kind, want[id])
			assert_false(StatusSystem.is_timed(d.kind), "duracao em turnos")
	assert_eq(StatusDef.Kind.DOOM, 17, "enum antigo intacto")

func test_hud_labels() -> void:
	assert_eq(CombatantView.def_label(_st(StatusDef.Kind.TAUNT)), "PROV")
	assert_eq(CombatantView.def_label(_st(StatusDef.Kind.BERSERK)), "BERS")
	assert_eq(CombatantView.def_label(_st(StatusDef.Kind.REFLECT)), "REFL")

func test_balance_config_has_berserk_pct() -> void:
	assert_eq(BalanceConfig.new().berserk_str_pct, 0.5)

# --- Provocar ----------------------------------------------------------------

func test_taunt_forces_enemy_basic_attack_target() -> void:
	h2.hp = 1
	_give(h, StatusDef.Kind.TAUNT)
	assert_eq(EnemyAI.decide(x, b).center, h, "sem Provocar iria no de menor HP")

func test_without_taunt_enemy_picks_lowest_hp() -> void:
	h2.hp = 1
	assert_eq(EnemyAI.decide(x, b).center, h2)

func test_taunt_forces_enemy_rule_picks() -> void:
	var tech: AbilityDef = _ability(1.0, null)
	for pick: AiRule.TargetPick in [AiRule.TargetPick.RANDOM_ENEMY, AiRule.TargetPick.LOWEST_HP_ENEMY, AiRule.TargetPick.FARTHEST, AiRule.TargetPick.NEAREST]:
		x.enemy_def.ai_rules = [_rule(tech, pick)]
		x.ap = 5
		h2.hp = 1
		h.statuses.clear()
		_give(h, StatusDef.Kind.TAUNT)
		var pa: PendingAction = EnemyAI.decide(x, b)
		assert_eq(pa.ability, tech)
		assert_eq(pa.center, h, "pick %d" % pick)

func test_taunt_centers_enemy_area_on_the_taunter() -> void:
	var blast: AbilityDef = _ability(1.0, null, AbilityDef.Shape.CIRCLE_TARGET, 50.0)
	x.enemy_def.ai_rules = [_rule(blast, AiRule.TargetPick.CLUSTER)]
	var h3: Combatant = _hero(&"c", Vector2(10, 300))
	b = BattleState.create(cfg, ScriptedDice.new(), [h, h2, h3], [x, x2])
	assert_eq(EnemyAI.decide(x, b).center, h2, "sem Provocar: o aglomerado")
	x.ap = 5
	_give(h, StatusDef.Kind.TAUNT)
	assert_eq(EnemyAI.decide(x, b).center, h, "com Provocar: o provocador")

func test_taunt_ignored_when_taunter_is_down_or_petrified() -> void:
	h2.hp = 1
	_give(h, StatusDef.Kind.TAUNT)
	h.hp = 0
	assert_eq(EnemyAI.decide(x, b).center, h2, "caido")
	h.hp = 10
	var pet: StatusDef = _st(StatusDef.Kind.PETRIFY, 1)
	pet.seconds = 0.0
	b.statuses.apply_forced(h, pet)
	assert_true(h.is_petrified())
	assert_eq(EnemyAI.decide(x, b).center, h2, "petrificado")

func test_taunt_with_two_taunters_uses_the_longest_remaining() -> void:
	h2.hp = 1
	_give(h, StatusDef.Kind.TAUNT, 2)
	_give(h2, StatusDef.Kind.TAUNT, 5)
	assert_eq(EnemyAI.decide(x, b).center, h2)
	h2.statuses[0].remaining = 2
	assert_eq(EnemyAI.decide(x, b).center, h, "empate: o primeiro")
	h.statuses[0].remaining = 1
	assert_eq(EnemyAI.decide(x, b).center, h2)

func test_taunt_on_an_enemy_does_not_force_the_players_choice() -> void:
	_give(x, StatusDef.Kind.TAUNT)
	var s := SelectionSession.new(h, b)
	assert_true(s.choose_ability(h.basic_attack))
	var cands: Array[Combatant] = s.target_candidates()
	assert_true(cands.has(x) and cands.has(x2), "o jogador ve todos os alvos")
	s.set_center(x2)
	assert_eq(s.confirm().center, x2, "e escolhe o que quiser")

func test_taunter_helper_only_counts_the_opposing_side() -> void:
	_give(h2, StatusDef.Kind.TAUNT)
	assert_null(Targeting.taunter([h2] as Array[Combatant], h), "aliado nao forca")
	assert_eq(Targeting.taunter([h2] as Array[Combatant], x), h2)

func test_taunt_forces_sim_policies() -> void:
	x2.hp = 1
	_give(x, StatusDef.Kind.TAUNT)
	for policy: StringName in [&"basic", &"smart"]:
		var pa: PendingAction = SimPolicy.decide(SelectionSession.new(h, b), b, policy)
		assert_eq(pa.center, x, str(policy))

func test_taunt_forces_sim_smart_area_on_the_taunter() -> void:
	var blast: AbilityDef = _ability(1.0, null, AbilityDef.Shape.CIRCLE_TARGET, 50.0)
	Fixtures.give_abilities(h.hero_state, [blast])
	h.abilities = h.hero_state.abilities()
	h.ap = 5
	x2.position = Vector2(100, 10)
	_give(x, StatusDef.Kind.TAUNT)
	var pa: PendingAction = SimPolicy.decide(SelectionSession.new(h, b), b, &"smart")
	assert_eq(pa.center, x)

func test_confusion_ignores_taunt_and_keeps_random_pick() -> void:
	b = BattleState.create(cfg, ScriptedDice.new([0.0, 0.0]), [h, h2], [x, x2])
	_give(x, StatusDef.Kind.TAUNT)
	var pa: PendingAction = EnemyAI.confused_action(h, b)
	assert_true(pa.confused)
	assert_eq(pa.center, h2, "o sorteio 0.0 pega o primeiro candidato (o aliado), sem forcar o provocador")

func test_confused_enemy_ignores_a_hero_taunter() -> void:
	b = BattleState.create(cfg, ScriptedDice.new([0.0]), [h, h2], [x, x2])
	_give(h2, StatusDef.Kind.TAUNT)
	assert_eq(EnemyAI.confused_action(x, b).center, h, "primeiro candidato do sorteio, nao o provocador h2")

func test_taunt_lasts_in_turns_and_expires() -> void:
	_give(h, StatusDef.Kind.TAUNT, 2)
	b.statuses.on_atb_full(h, [x])
	assert_true(h.has_kind(StatusDef.Kind.TAUNT))
	b.statuses.on_atb_full(h, [x])
	assert_false(h.has_kind(StatusDef.Kind.TAUNT))

# --- Berserk -----------------------------------------------------------------

func test_berserk_raises_strength_by_config_pct() -> void:
	var base: int = StatCalculator.effective(h, &"strength", cfg)
	_give(h, StatusDef.Kind.BERSERK)
	assert_eq(StatCalculator.effective(h, &"strength", cfg), floori(base * 1.5))
	assert_eq(StatCalculator.effective(h, &"speed", cfg), 5, "so a Forca")
	cfg.berserk_str_pct = 1.0
	assert_eq(StatCalculator.effective(h, &"strength", cfg), base * 2)

func test_berserk_raises_basic_attack_damage() -> void:
	var hp0: int = x.hp
	_cast(h, h.basic_attack, x)
	var normal: int = hp0 - x.hp
	x.hp = hp0
	_give(h, StatusDef.Kind.BERSERK)
	_cast(h, h.basic_attack, x)
	assert_gt(hp0 - x.hp, normal)

func test_berserk_action_is_basic_attack_on_random_living_enemy() -> void:
	var tech: AbilityDef = _ability(3.0, null)
	Fixtures.give_abilities(h.hero_state, [tech])
	h.abilities = h.hero_state.abilities()
	b = BattleState.create(cfg, ScriptedDice.new([0.0, 0.99, 0.0]), [h, h2], [x, x2])
	_give(h, StatusDef.Kind.BERSERK)
	var first: PendingAction = EnemyAI.berserk_action(h, b)
	assert_eq(first.ability, h.basic_attack, "sem habilidades")
	assert_eq(first.center, x)
	assert_eq(EnemyAI.berserk_action(h, b).center, x2)
	x2.hp = 0
	assert_eq(EnemyAI.berserk_action(h, b).center, x, "caidos nao entram")
	x.hp = 0
	assert_null(EnemyAI.berserk_action(h, b), "sem alvo")

func test_berserk_respects_taunt() -> void:
	b = BattleState.create(cfg, ScriptedDice.new([0.0]), [h, h2], [x, x2])
	_give(x2, StatusDef.Kind.TAUNT)
	_give(h, StatusDef.Kind.BERSERK)
	assert_eq(EnemyAI.berserk_action(h, b).center, x2)

func test_berserk_hero_acts_alone_without_menu() -> void:
	h.atb = 1.0
	var ctrl := BattleController.new(b)
	_give(h, StatusDef.Kind.BERSERK)
	watch_signals(ctrl)
	var seen: Array[PendingAction] = _first_action(ctrl)
	assert_false(seen.is_empty())
	assert_signal_not_emitted(ctrl, "hero_turn", "sem menu")
	assert_null(ctrl.session)
	assert_eq(seen[0].actor, h)
	assert_eq(seen[0].ability, h.basic_attack)
	assert_true(b.enemies.has(seen[0].center))
	assert_signal_emitted(ctrl, "confused_act")

func test_berserk_hero_does_not_use_techniques_even_with_ap() -> void:
	var tech: AbilityDef = _ability(5.0, null)
	Fixtures.give_abilities(h.hero_state, [tech])
	h.abilities = h.hero_state.abilities()
	h.ap = 9
	h.atb = 1.0
	var ctrl := BattleController.new(b)
	_give(h, StatusDef.Kind.BERSERK)
	var seen: Array[PendingAction] = _first_action(ctrl)
	assert_eq(seen[0].ability, h.basic_attack)
	assert_eq(h.ap, 9, "nenhum AP gasto")

func test_berserk_in_active_mode_drops_the_open_menu() -> void:
	h.atb = 1.0
	var ctrl := BattleController.new(b)
	ctrl.active_mode = true
	ctrl.tick(0.05)
	assert_not_null(ctrl.session, "menu aberto")
	_give(h, StatusDef.Kind.BERSERK)
	var seen: Array[PendingAction] = []
	ctrl.action_started.connect(func(a: PendingAction) -> void: seen.append(a))
	_run_until(ctrl, func() -> bool: return not seen.is_empty() and seen[0].actor == h)
	assert_false(seen.is_empty())
	assert_eq(seen[0].ability, h.basic_attack)

func test_berserk_enemy_replaces_ai_rules_with_basic_attack() -> void:
	var heavy: AbilityDef = _ability(5.0, null)
	heavy.id = &"heavy"
	x.enemy_def.abilities = [Fixtures.hit(1.0), heavy] as Array[AbilityDef]
	x.abilities = x.enemy_def.abilities.duplicate()
	x.basic_attack = x.abilities[0]
	x.enemy_def.ai_rules = [_rule(heavy, AiRule.TargetPick.LOWEST_HP_ENEMY)]
	x.atb = 1.0
	var ctrl := BattleController.new(b)
	_give(x, StatusDef.Kind.BERSERK)
	var seen: Array[PendingAction] = _first_action(ctrl)
	assert_eq(seen[0].actor, x)
	assert_eq(seen[0].ability, x.basic_attack, "a regra pesada e ignorada")
	assert_true(b.heroes.has(seen[0].center))

func test_berserk_enemy_respects_taunt() -> void:
	x.atb = 1.0
	_give(h2, StatusDef.Kind.TAUNT)
	var ctrl := BattleController.new(b)
	_give(x, StatusDef.Kind.BERSERK)
	var seen: Array[PendingAction] = _first_action(ctrl)
	assert_eq(seen[0].actor, x)
	assert_eq(seen[0].center, h2)

func test_berserk_is_negative_and_removed_by_panacea() -> void:
	_give(h, StatusDef.Kind.BERSERK)
	assert_eq(b.statuses.remove_negative(h), 1)

# --- Reflexo -----------------------------------------------------------------

func test_reflect_single_bounces_all_effects_to_the_caster() -> void:
	var fire: ElementDef = _el(&"fire")
	_give(x, StatusDef.Kind.REFLECT)
	var hp_x: int = x.hp
	var hp_h: int = h.hp
	var r: ActionResult = _cast(h, _ability(2.0, fire), x)
	assert_eq(x.hp, hp_x, "o refletido nao sofre")
	assert_lt(h.hp, hp_h, "o lancador sofre")
	assert_eq(r.hits.size(), 1)
	assert_eq(r.hits[0]["target_id"], &"a")
	assert_eq(r.hits[0]["reflected_from"], &"x")
	assert_eq(r.hits[0]["amount"], hp_h - h.hp)

func test_reflect_bounces_statuses_too() -> void:
	var fire: ElementDef = _el(&"fire")
	var ab: AbilityDef = _ability(0.0, fire)
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.APPLY_STATUS
	e.status = _st(StatusDef.Kind.SLOW, 3, true)
	e.chance = 1.0
	ab.effects = [e]
	_give(x, StatusDef.Kind.REFLECT)
	var r: ActionResult = _cast(h, ab, x)
	assert_true(h.has_kind(StatusDef.Kind.SLOW))
	assert_false(x.has_kind(StatusDef.Kind.SLOW))
	assert_eq(r.hits[0]["reflected_from"], &"x")

func test_reflect_in_area_each_reflector_bounces_its_share() -> void:
	var fire: ElementDef = _el(&"fire")
	var blast: AbilityDef = _ability(2.0, fire, AbilityDef.Shape.CIRCLE_TARGET, 50.0)
	# Um refletindo: so a parte dele volta.
	_give(x, StatusDef.Kind.REFLECT)
	var hp_h: int = h.hp
	var hp_x2: int = x2.hp
	var r: ActionResult = _cast(h, blast, x)
	var one_share: int = hp_h - h.hp
	assert_gt(one_share, 0)
	assert_lt(x2.hp, hp_x2, "o outro leva normal")
	assert_eq(x.hp, StatCalculator.hp_max(x, cfg))
	assert_eq(r.hits.size(), 2)
	# Dois refletindo: duas partes voltam.
	h.hp = hp_h
	x2.hp = hp_x2
	_give(x2, StatusDef.Kind.REFLECT)
	var r2: ActionResult = _cast(h, blast, x)
	assert_eq(hp_h - h.hp, one_share * 2)
	assert_eq(x2.hp, hp_x2)
	var from: Array[StringName] = []
	for hit: Dictionary in r2.hits:
		from.append(hit["reflected_from"])
	assert_eq(from, [&"x", &"x2"] as Array[StringName])

func test_reflect_never_reflects_again_even_if_caster_reflects() -> void:
	var fire: ElementDef = _el(&"fire")
	_give(x, StatusDef.Kind.REFLECT)
	_give(h, StatusDef.Kind.REFLECT)
	var hp_h: int = h.hp
	var r: ActionResult = _cast(h, _ability(2.0, fire), x)
	assert_lt(h.hp, hp_h, "o golpe devolvido atinge o lancador, uma vez")
	assert_eq(r.hits.size(), 1)
	assert_eq(x.hp, StatCalculator.hp_max(x, cfg))
	assert_eq(r.hits[0]["target_id"], &"a")

func test_reflector_gets_no_mark_and_no_reaction() -> void:
	var fire: ElementDef = _el(&"fire")
	var ice: ElementDef = _el(&"ice")
	_give(x, StatusDef.Kind.REFLECT)
	var r: ActionResult = _cast(h, _ability(1.0, fire), x)
	assert_null(x.mark, "sem marca")
	assert_eq(r.hits[0]["reaction"], &"")
	# O alvo que nao reflete e marcado normalmente (o teste vale).
	_cast(h, _ability(1.0, fire), x2)
	assert_eq(x2.mark, fire)
	# Marca previa no refletido nao reage com o golpe refletido.
	MarkRules.set_mark(x, ice, 3)
	var react := ReactionDef.new()
	react.id = &"steam"
	react.a = ice
	react.b = fire
	react.bonus_pct = 0.5
	var table := ReactionTable.new()
	table.reactions = [react] as Array[ReactionDef]
	b.reactions = table
	var hp_x: int = x.hp
	var r2: ActionResult = _cast(h, _ability(1.0, fire), x)
	assert_eq(r2.hits[0]["reaction"], &"")
	assert_eq(x.hp, hp_x)
	assert_eq(x.mark, ice, "a marca antiga fica intacta")

func test_basic_attack_with_weapon_element_does_not_reflect() -> void:
	h.weapon_element = _el(&"fire")
	_give(x, StatusDef.Kind.REFLECT)
	var hp_h: int = h.hp
	var r: ActionResult = _cast(h, h.basic_attack, x)
	assert_lt(x.hp, StatCalculator.hp_max(x, cfg), "o ataque basico acerta o refletido")
	assert_eq(h.hp, hp_h)
	assert_eq(r.hits[0]["reflected_from"], &"")

func test_enemy_basic_attack_with_def_element_does_not_reflect() -> void:
	x.basic_attack.element = _el(&"fire")
	_give(h, StatusDef.Kind.REFLECT)
	_cast(x, x.basic_attack, h)
	assert_lt(h.hp, StatCalculator.hp_max(h, cfg))
	assert_eq(x.hp, StatCalculator.hp_max(x, cfg))

func test_non_elemental_ability_does_not_reflect() -> void:
	_give(x, StatusDef.Kind.REFLECT)
	var hp_h: int = h.hp
	_cast(h, _ability(2.0, null), x)
	assert_lt(x.hp, StatCalculator.hp_max(x, cfg))
	assert_eq(h.hp, hp_h)

func test_reflect_does_not_bounce_an_elemental_heal_on_an_ally() -> void:
	# Regra: o Reflexo so devolve golpes de um oponente. Cura elemental num aliado que reflete passa direto.
	_give(h2, StatusDef.Kind.REFLECT)
	h2.hp = 5
	h.hp = 5
	var r: ActionResult = _cast(h, _heal_ability(_el(&"holy"), AbilityDef.Side.ALLIES), h2)
	assert_gt(h2.hp, 5, "o aliado curou")
	assert_eq(h.hp, 5, "o curandeiro nao recebeu a cura")
	assert_eq(r.hits[0]["reflected_from"], &"")

func test_reflect_bounces_a_heal_aimed_at_an_opponent() -> void:
	# Mesma regra vista pelo outro lado: o efeito mira um oponente refletindo, entao volta (a cura vai para o lancador).
	_give(x, StatusDef.Kind.REFLECT)
	x.hp = 5
	h.hp = 5
	_cast(h, _heal_ability(_el(&"holy"), AbilityDef.Side.ENEMIES), x)
	assert_eq(x.hp, 5)
	assert_gt(h.hp, 5)

func test_reflect_on_self_target_does_not_bounce() -> void:
	var ab: AbilityDef = _heal_ability(_el(&"holy"), AbilityDef.Side.ALLIES)
	ab.shape = AbilityDef.Shape.CIRCLE_SELF
	_give(h, StatusDef.Kind.REFLECT)
	h.hp = 5
	var r: ActionResult = _cast(h, ab, h)
	assert_gt(h.hp, 5)
	assert_eq(r.hits[0]["reflected_from"], &"")

func test_reflect_lasts_in_turns_and_expires() -> void:
	_give(x, StatusDef.Kind.REFLECT, 2)
	b.statuses.on_atb_full(x, [x])
	assert_true(x.is_reflecting())
	var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(x, [x])
	assert_false(x.is_reflecting())
	assert_true(out.expired.has(&"reflect"))

func test_reflect_bounce_that_downs_the_caster_ends_cleanly() -> void:
	var fire: ElementDef = _el(&"fire")
	_give(x, StatusDef.Kind.REFLECT)
	h.hp = 1
	var r: ActionResult = _cast(h, _ability(5.0, fire), x)
	assert_true(h.is_down())
	assert_true(r.downed.has(h))
	assert_eq(x.hp, StatCalculator.hp_max(x, cfg))

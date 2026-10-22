extends GutTest
## M15 Task 1: Queimadura, Congelado, Molhado, Petrificacao e Contagem (Doom). Defs em memoria; numeros de teste.

var cfg: BalanceConfig
var b: BattleState
var h: Combatant
var x: Combatant

func before_each() -> void:
	cfg = Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 4)), cfg), Vector2.ZERO)
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(10, 5, 5, 4)), &"x", Vector2(100, 0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x])

func _st(kind: StatusDef.Kind, duration: int = 3, potency: int = 0, seconds: float = 0.0) -> StatusDef:
	var s: StatusDef = Fixtures.status_def(kind, duration, potency)
	s.seconds = seconds
	s.negative = true
	return s

func _el(id: StringName) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	return e

func _ability(potency: float, scale: EffectDef.Scale = EffectDef.Scale.STRENGTH, element: ElementDef = null) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(potency)
	a.effects[0].scale = scale
	a.element = element
	return a

func _act(actor: Combatant, ab: AbilityDef, center: Combatant) -> PendingAction:
	var a := PendingAction.new()
	a.actor = actor
	a.ability = ab
	a.center = center
	a.center_pos = center.position
	return a

func _cast(actor: Combatant, ab: AbilityDef, target: Combatant) -> ActionResult:
	return ActionExecutor.apply(_act(actor, ab, target), b)

## Habilidade que aplica `s` (100%) ou remove (`remove`) no alvo.
func _status_ability(s: StatusDef, remove: bool = false, side: AbilityDef.Side = AbilityDef.Side.ENEMIES) -> AbilityDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.REMOVE_STATUS if remove else EffectDef.Kind.APPLY_STATUS
	e.status = s
	e.chance = 1.0
	var a := AbilityDef.new()
	a.id = &"st"
	a.shape = AbilityDef.Shape.SINGLE
	a.side = side
	a.cast_time = 1.0
	a.impact_time = 0.5
	a.effects = [e]
	return a

func _apply(target: Combatant, s: StatusDef, source: Combatant = null) -> StatusSystem.ApplyResult:
	return b.statuses.apply(target, s, source if source != null else h, 1.0, [x])

func _controller() -> BattleController:
	return BattleController.new(b)

func _run(ctrl: BattleController, seconds: float, step: float = 0.05) -> void:
	for i: int in int(round(seconds / step)):
		ctrl.tick(step)

# --- dados -----------------------------------------------------------------

func test_data_files_have_the_new_kinds() -> void:
	var want: Dictionary = {&"burn": StatusDef.Kind.BURN, &"freeze": StatusDef.Kind.FREEZE, &"wet": StatusDef.Kind.WET, &"petrify": StatusDef.Kind.PETRIFY, &"doom": StatusDef.Kind.DOOM}
	for id: StringName in want:
		var d: StatusDef = load("res://data/test/statuses/%s.tres" % id) as StatusDef
		assert_not_null(d, str(id))
		if d != null:
			assert_eq(d.id, id)
			assert_eq(d.kind, want[id])
	assert_eq(StatusDef.Kind.BLEED, 12, "enum antigo intacto")
	var burn: StatusDef = load("res://data/test/statuses/burn.tres") as StatusDef
	var wet: StatusDef = load("res://data/test/statuses/wet.tres") as StatusDef
	assert_true(burn.cancels.has(&"wet"))
	assert_true(wet.cancels.has(&"burn"))

func test_hud_labels() -> void:
	assert_eq(CombatantView.def_label(_st(StatusDef.Kind.BURN)), "QUEI")
	assert_eq(CombatantView.def_label(_st(StatusDef.Kind.FREEZE)), "GELO")
	assert_eq(CombatantView.def_label(_st(StatusDef.Kind.WET)), "MOLH")
	assert_eq(CombatantView.def_label(_st(StatusDef.Kind.PETRIFY)), "PEDRA")
	_apply(x, _st(StatusDef.Kind.PETRIFY, 1, 0, 8.0))
	assert_eq(CombatantView.status_label(x.statuses[0]), "PEDRA 8", "contagem antes de petrificar")
	x.statuses[0].time_left = 0.0
	assert_eq(CombatantView.status_label(x.statuses[0]), "PEDRA")
	_apply(h, _st(StatusDef.Kind.DOOM, 1, 0, 14.2))
	assert_eq(CombatantView.status_label(h.statuses[0]), "DOOM 15")

# --- Queimadura ------------------------------------------------------------

func test_burn_deals_percent_of_max_hp_each_atb_full_and_credits_source() -> void:
	var hp_max: int = StatCalculator.hp_max(x, cfg)
	_apply(x, _st(StatusDef.Kind.BURN, 3, 10))
	var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(x, [x])
	assert_eq(out.burn_damage, floori(hp_max * 0.10))
	assert_eq(x.hp, hp_max - out.burn_damage)
	assert_eq(b.ledger.get_points(&"a", &"x"), float(out.burn_damage))

func test_burn_can_down() -> void:
	_apply(x, _st(StatusDef.Kind.BURN, 3, 10))
	x.hp = 2
	var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(x, [x])
	assert_eq(out.burn_damage, 2)
	assert_true(x.is_down())

func test_burn_expires_by_turns() -> void:
	_apply(x, _st(StatusDef.Kind.BURN, 2, 5))
	b.statuses.on_atb_full(x, [x])
	var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(x, [x])
	assert_eq(out.expired, [&"burn"])
	assert_false(x.has_kind(StatusDef.Kind.BURN))

func test_burn_lowers_strength_by_config_pct() -> void:
	var before: int = StatCalculator.effective(h, &"strength", cfg)
	_apply(h, _st(StatusDef.Kind.BURN, 3, 5), x)
	var after: int = StatCalculator.effective(h, &"strength", cfg)
	assert_eq(after, floori(before * (1.0 - cfg.burn_str_pct)))
	assert_eq(StatCalculator.effective(h, &"vitality", cfg), 5, "so a Forca cai")
	b.statuses.remove_kind(h, StatusDef.Kind.BURN)
	assert_eq(StatCalculator.effective(h, &"strength", cfg), before)

# --- Molhado x Queimadura --------------------------------------------------

func test_wet_blocks_burn_and_dries() -> void:
	_apply(x, _st(StatusDef.Kind.WET))
	assert_eq(_apply(x, _st(StatusDef.Kind.BURN, 3, 5)), StatusSystem.ApplyResult.IMMUNE)
	assert_false(x.has_kind(StatusDef.Kind.BURN))
	assert_false(x.has_kind(StatusDef.Kind.WET), "o fogo secou o Molhado")

func test_wet_removes_burn() -> void:
	var wet: StatusDef = _st(StatusDef.Kind.WET)
	wet.id = &"wet"
	wet.cancels = [&"burn"]
	var burn: StatusDef = _st(StatusDef.Kind.BURN, 3, 5)
	burn.id = &"burn"
	assert_eq(_apply(x, burn), StatusSystem.ApplyResult.APPLIED)
	assert_eq(_apply(x, wet), StatusSystem.ApplyResult.APPLIED)
	assert_true(x.has_kind(StatusDef.Kind.WET))
	assert_false(x.has_kind(StatusDef.Kind.BURN))

func test_wet_has_no_damage() -> void:
	_apply(x, _st(StatusDef.Kind.WET))
	var hp: int = x.hp
	b.statuses.on_atb_full(x, [x])
	assert_eq(x.hp, hp)

func test_wet_adds_indra_weakness_in_the_sum() -> void:
	var indra: ElementDef = _el(&"indra")
	x.enemy_def.element_resist = {&"indra": 0.5}
	assert_eq(ElementMath.total_resist(indra, x, cfg), 0.5)
	_apply(x, _st(StatusDef.Kind.WET))
	assert_almost_eq(ElementMath.total_resist(indra, x, cfg), 0.5 - cfg.wet_indra_bonus, 0.0001)
	assert_eq(ElementMath.total_resist(_el(&"atlas"), x, cfg), 0.0, "so Indra")

func test_wet_raises_indra_damage() -> void:
	var indra: ElementDef = _el(&"indra")
	var ab: AbilityDef = _ability(3.0, EffectDef.Scale.STRENGTH, indra)
	var hp0: int = x.hp
	_cast(h, ab, x)
	var dry: int = hp0 - x.hp
	x.hp = hp0
	_apply(x, _st(StatusDef.Kind.WET))
	_cast(h, ab, x)
	var wet: int = hp0 - x.hp
	assert_eq(wet, floori(dry * (1.0 + cfg.wet_indra_bonus)))
	assert_true(x.has_kind(StatusDef.Kind.WET), "Indra nao seca")

# --- Congelado -------------------------------------------------------------

func test_freeze_stops_atb_and_expires_in_seconds() -> void:
	_apply(x, _st(StatusDef.Kind.FREEZE, 1, 0, 2.0))
	assert_true(x.is_stopped())
	var clock := AtbClock.new(cfg)
	clock.advance(1.0, b.all(), b.queue)
	assert_eq(x.atb, 0.0, "o ATB nao enche")
	assert_true(b.statuses.tick_time(b.all(), 1.0).is_empty())
	var freed: Array[Combatant] = b.statuses.tick_time(b.all(), 1.5)
	assert_eq(freed, [x])
	assert_false(x.has_kind(StatusDef.Kind.FREEZE))

func test_freeze_shatter_on_first_strength_hit_fires_once() -> void:
	var ab: AbilityDef = _ability(3.0)
	var hp0: int = x.hp
	_cast(h, ab, x)
	var plain: int = hp0 - x.hp
	x.hp = hp0
	_apply(x, _st(StatusDef.Kind.FREEZE, 1, 0, 5.0))
	_cast(h, ab, x)
	assert_eq(hp0 - x.hp, floori(plain * (1.0 + cfg.freeze_shatter_bonus)), "bonus no golpe que quebra")
	assert_false(x.has_kind(StatusDef.Kind.FREEZE))
	x.hp = hp0
	_cast(h, ab, x)
	assert_eq(hp0 - x.hp, plain, "o bonus sai uma vez")

func test_freeze_survives_aura_damage_and_dot() -> void:
	_apply(x, _st(StatusDef.Kind.FREEZE, 1, 0, 5.0))
	var hp0: int = x.hp
	_cast(h, _ability(3.0, EffectDef.Scale.AURA), x)
	assert_lt(x.hp, hp0, "a Aura machuca")
	assert_true(x.has_kind(StatusDef.Kind.FREEZE), "mas nao quebra o gelo")
	_apply(x, _st(StatusDef.Kind.BURN, 3, 5))
	b.statuses.on_atb_full(x, [x])
	assert_true(x.has_kind(StatusDef.Kind.FREEZE), "dano de estado nao quebra")

func test_kagutsuchi_melts_freeze_without_bonus_and_dries_wet() -> void:
	var fire: ElementDef = _el(&"kagutsuchi")
	var ab: AbilityDef = _ability(3.0, EffectDef.Scale.STRENGTH, fire)
	var hp0: int = x.hp
	_cast(h, ab, x)
	var plain: int = hp0 - x.hp
	x.hp = hp0
	_apply(x, _st(StatusDef.Kind.FREEZE, 1, 0, 5.0))
	_cast(h, ab, x)
	assert_eq(hp0 - x.hp, plain, "sem bonus")
	assert_false(x.has_kind(StatusDef.Kind.FREEZE))
	_apply(x, _st(StatusDef.Kind.WET))
	_cast(h, ab, x)
	assert_false(x.has_kind(StatusDef.Kind.WET), "Kagutsuchi seca")

func test_fire_aura_hit_also_melts() -> void:
	_apply(x, _st(StatusDef.Kind.FREEZE, 1, 0, 5.0))
	_cast(h, _ability(3.0, EffectDef.Scale.AURA, _el(&"kagutsuchi")), x)
	assert_false(x.has_kind(StatusDef.Kind.FREEZE))

# --- Petrificacao ----------------------------------------------------------

func test_petrify_counts_down_then_petrifies() -> void:
	_apply(x, _st(StatusDef.Kind.PETRIFY, 1, 0, 8.0))
	assert_false(x.is_petrified())
	assert_false(x.is_stopped(), "ainda age durante a contagem")
	var res: Dictionary = b.statuses.tick_countdowns(b.all(), 7.0)
	assert_true((res["petrified"] as Array).is_empty())
	res = b.statuses.tick_countdowns(b.all(), 1.0)
	assert_eq(res["petrified"], [x])
	assert_true(x.is_petrified())
	assert_true(x.is_stopped())
	assert_true(x.is_out())
	assert_false(x.is_down())
	assert_eq(x.hp, StatCalculator.hp_max(x, cfg), "o HP continua")

func test_petrified_takes_no_damage_or_statuses_and_shows_stone() -> void:
	_apply(x, _st(StatusDef.Kind.PETRIFY, 1, 0, 1.0))
	b.statuses.tick_countdowns(b.all(), 2.0)
	var hp0: int = x.hp
	var r: ActionResult = ActionExecutor.apply(_act(h, _ability(3.0), x), b)
	assert_eq(x.hp, hp0)
	assert_true(r.fizzled, "petrificado nao e alvo")
	r = _cast_direct_damage(h, x)
	assert_eq(x.hp, hp0)
	assert_true(r.hits[0].get("petrified", false), "popup Pedra")
	assert_eq(_apply(x, _st(StatusDef.Kind.BURN, 3, 5)), StatusSystem.ApplyResult.IMMUNE)
	assert_false(x.has_kind(StatusDef.Kind.BURN))

## Forca o efeito direto (como uma acao que ja tinha o alvo antes da pedra).
func _cast_direct_damage(actor: Combatant, target: Combatant) -> ActionResult:
	var r := ActionResult.new()
	var ab: AbilityDef = _ability(3.0)
	ActionExecutor._apply_effect(ab.effects[0], actor, target, b, r, actor.id, ab)
	return r

func test_petrified_atb_does_not_fill_and_is_not_queued() -> void:
	_apply(h, _st(StatusDef.Kind.PETRIFY, 1, 0, 1.0))
	var ctrl := _controller()
	_run(ctrl, 3.0)
	assert_true(h.is_petrified())
	assert_eq(h.atb, 0.0)
	assert_false(b.queue.has(h))

func test_petrify_signal_and_queue_cleanup() -> void:
	h.atb = 1.0
	b.queue.push(h, 0)
	_apply(h, _st(StatusDef.Kind.PETRIFY, 1, 0, 0.04))
	var ctrl := _controller()
	watch_signals(ctrl)
	ctrl.tick(0.05)
	assert_signal_emitted(ctrl, "petrified")
	assert_false(b.queue.has(h))
	assert_eq(h.atb, 0.0)

func test_petrify_is_cured_only_by_remove_status_and_can_be_targeted_for_it() -> void:
	var pet: StatusDef = _st(StatusDef.Kind.PETRIFY, 1, 0, 1.0)
	pet.id = &"petrify"
	var h2: Combatant = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"c", Stats.make(10, 5, 5, 4)), cfg), Vector2.ZERO)
	b.heroes.append(h2)
	_apply(h2, pet, x)
	b.statuses.tick_countdowns(b.all(), 2.0)
	assert_true(h2.is_petrified())
	var cure: AbilityDef = _status_ability(pet, true, AbilityDef.Side.ALLIES)
	var heal: AbilityDef = _status_ability(_st(StatusDef.Kind.BURN), true, AbilityDef.Side.ALLIES)
	assert_true(Targeting.candidates(cure.shape, cure.side, cure.effects, h, b).has(h2))
	assert_false(Targeting.candidates(heal.shape, heal.side, heal.effects, h, b).has(h2), "outra cura nao alcanca")
	_cast(h, cure, h2)
	assert_false(h2.is_petrified())
	assert_eq(h2.hp, StatCalculator.hp_max(h2, cfg))

func test_cured_petrified_with_full_atb_returns_to_queue() -> void:
	var pet: StatusDef = _st(StatusDef.Kind.PETRIFY, 1, 0, 0.1)
	pet.id = &"petrify"
	_apply(h, pet, x)
	b.statuses.tick_countdowns(b.all(), 1.0)
	h.atb = 1.0
	b.statuses.remove(h, &"petrify")
	var ctrl := _controller()
	ctrl.tick(0.05)
	assert_not_null(ctrl.session, "o heroi curado volta a agir")

# --- Fim da batalha com petrificados ---------------------------------------

func _petrify_now(c: Combatant) -> void:
	_apply(c, _st(StatusDef.Kind.PETRIFY, 1, 0, 1.0), h)
	b.statuses.tick_countdowns(b.all(), 2.0)

func test_victory_when_every_enemy_is_down_or_petrified() -> void:
	var y: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"y", Stats.make(10, 5, 5, 4)), &"y", Vector2(120, 0), cfg)
	b.enemies.append(y)
	var ctrl := _controller()
	_petrify_now(x)
	ctrl.tick(0.05)
	assert_eq(ctrl.outcome, BattleController.Outcome.ONGOING, "ainda resta um")
	y.hp = 0
	ctrl.tick(0.05)
	assert_eq(ctrl.outcome, BattleController.Outcome.VICTORY)

func test_victory_when_all_enemies_petrified() -> void:
	_petrify_now(x)
	var ctrl := _controller()
	ctrl.tick(0.05)
	assert_eq(ctrl.outcome, BattleController.Outcome.VICTORY)

func test_defeat_when_every_hero_is_down_or_petrified() -> void:
	var h2: Combatant = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"c", Stats.make(10, 5, 5, 4)), cfg), Vector2.ZERO)
	b.heroes.append(h2)
	var ctrl := _controller()
	_petrify_now(h)
	ctrl.tick(0.05)
	assert_eq(ctrl.outcome, BattleController.Outcome.ONGOING)
	h2.hp = 0
	ctrl.tick(0.05)
	assert_eq(ctrl.outcome, BattleController.Outcome.DEFEAT)

func test_petrified_hero_keeps_hp_for_the_end_of_battle() -> void:
	h.hp = 17
	_petrify_now(h)
	var ctrl := _controller()
	ctrl.tick(0.05)
	assert_eq(ctrl.outcome, BattleController.Outcome.DEFEAT)
	assert_eq(h.hp, 17)
	assert_false(h.is_down())

func test_petrified_enemy_gives_xp_and_drops_as_defeated() -> void:
	b.ledger.add(&"a", &"x", 10.0)
	_petrify_now(x)
	var xp: Dictionary[StringName, int] = XpCalculator.combat_xp(b.ledger, b.enemies, b.heroes, false)
	assert_eq(xp[&"a"], x.enemy_def.xp_base)
	x.enemy_def.money = 7
	assert_eq(BattleRewards.roll(b.enemies, b.dice).money, 7)

func test_petrified_enemy_is_not_a_target_for_ai() -> void:
	var y: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"y", Stats.make(10, 5, 5, 4)), &"y", Vector2(120, 0), cfg)
	b.enemies.append(y)
	_petrify_now(h)
	assert_null(EnemyAI.decide(y, b), "sem herois de pe, sem alvo")

# --- Contagem (Doom) -------------------------------------------------------

func test_doom_downs_at_zero_with_credit_to_the_applier() -> void:
	var doom: StatusDef = _st(StatusDef.Kind.DOOM, 1, 0, 15.0)
	doom.id = &"doom"
	_apply(x, doom, h)
	var hp0: int = x.hp
	var res: Dictionary = b.statuses.tick_countdowns(b.all(), 14.0)
	assert_true((res["doomed"] as Array).is_empty())
	assert_eq(x.hp, hp0)
	res = b.statuses.tick_countdowns(b.all(), 1.0)
	assert_eq(res["doomed"], [x])
	assert_true(x.is_down())
	assert_eq(b.ledger.get_points(&"a", &"x"), float(hp0))

func test_doom_through_controller_clears_and_signals() -> void:
	var doom: StatusDef = _st(StatusDef.Kind.DOOM, 1, 0, 1.0)
	doom.id = &"doom"
	_apply(h, doom, x)
	var ctrl := _controller()
	watch_signals(ctrl)
	_run(ctrl, 2.0)
	assert_signal_emitted(ctrl, "doom_fired")
	assert_true(h.is_down())
	assert_eq(h.statuses.size(), 0)
	assert_eq(ctrl.outcome, BattleController.Outcome.DEFEAT)

func test_doom_is_removable_and_immunity_blocks() -> void:
	var doom: StatusDef = _st(StatusDef.Kind.DOOM, 1, 0, 15.0)
	doom.id = &"doom"
	_apply(x, doom, h)
	_cast(h, _status_ability(doom, true), x)
	assert_false(x.has_kind(StatusDef.Kind.DOOM))
	x.enemy_def.immunities = [&"doom"]
	assert_eq(_apply(x, doom, h), StatusSystem.ApplyResult.IMMUNE)

func test_doom_reapply_renews_the_countdown() -> void:
	var doom: StatusDef = _st(StatusDef.Kind.DOOM, 1, 0, 15.0)
	doom.id = &"doom"
	_apply(x, doom, h)
	b.statuses.tick_countdowns(b.all(), 10.0)
	assert_eq(_apply(x, doom, h), StatusSystem.ApplyResult.RENEWED)
	assert_eq(x.statuses[0].time_left, 15.0)

func test_petrified_unit_countdown_is_frozen() -> void:
	var doom: StatusDef = _st(StatusDef.Kind.DOOM, 1, 0, 5.0)
	doom.id = &"doom"
	_apply(x, doom, h)
	_petrify_now(x)
	b.statuses.tick_countdowns(b.all(), 30.0)
	assert_false(x.is_down(), "a pedra segura a Contagem")

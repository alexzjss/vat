extends GutTest

## Catálogo de estados completo (M11, núcleo): Pare, Confusão, buffs/debuffs, Silêncio, Cegueira,
## Regeneração e REMOVE_STATUS por lista / todos os negativos.

var cfg: BalanceConfig
var _log: Array[String] = []
var _cancelled: int = 0
var _resets: int = 0

func before_each() -> void:
	cfg = Fixtures.cfg()
	_log = []
	_cancelled = 0
	_resets = 0

func _st(kind: StatusDef.Kind, duration: int = 3, potency: int = 0, id: StringName = &"") -> StatusDef:
	var s: StatusDef = Fixtures.status_def(kind, duration, potency)
	if id != &"":
		s.id = id
	return s

func _stop(seconds: float) -> StatusDef:
	var s: StatusDef = _st(StatusDef.Kind.STOP, 1, 0, &"stop")
	s.seconds = seconds
	s.negative = true
	return s

func _mod(id: StringName, attr: StringName, potency: int) -> StatusDef:
	var s: StatusDef = _st(StatusDef.Kind.ATTR_MOD, 3, potency, id)
	s.attr = attr
	return s

func _hero(id: StringName, spd: int, techs: Array[AbilityDef] = []) -> Combatant:
	var d: CharacterDef = Fixtures.hero_def(id, Stats.make(10, spd, 5, 1))
	if not techs.is_empty():
		Fixtures.set_abilities(d, techs)
	return Combatant.from_hero(HeroState.create(d, cfg), Vector2.ZERO)

func _foe(id: StringName, spd: int) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(10, spd, 5, 5)), id, Vector2.ZERO, cfg)

func _ctrl(heroes: Array[Combatant], enemies: Array[Combatant], active: bool = true, dice: Dice = null) -> BattleController:
	var b: BattleState = BattleState.create(cfg, dice if dice != null else ScriptedDice.new(), heroes, enemies)
	var c := BattleController.new(b)
	c.active_mode = active
	c.hero_turn.connect(func(s: SelectionSession) -> void: _log.append("turn:%s" % s.actor.id))
	c.action_started.connect(func(a: PendingAction) -> void: _log.append("started:%s>%s" % [a.actor.id, a.center.id]))
	c.session_cancelled.connect(func(_s: SelectionSession) -> void: _cancelled += 1)
	c.session_reset.connect(func(_s: SelectionSession) -> void: _resets += 1)
	return c

func _until(ctrl: BattleController, cond: Callable, max_ticks: int = 800) -> bool:
	for i: int in max_ticks:
		if cond.call():
			return true
		ctrl.tick(0.05)
	return cond.call()

func _attack(ctrl: BattleController, target: Combatant) -> PendingAction:
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(s.actor.basic_attack))
	s.set_center(target)
	var a: PendingAction = s.confirm()
	ctrl.submit(a)
	return a

# --- Pare ---

func test_stop_freezes_atb_and_dodge_is_zero() -> void:
	var x: Combatant = _foe(&"x", 30)
	var h: Combatant = _hero(&"a", 30)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	b.statuses.apply_forced(x, _stop(5.0))
	var clock := AtbClock.new(cfg)
	for i: int in 20:
		clock.advance(0.1, [x, h], b.queue)
	assert_eq(x.atb, 0.0)
	assert_gt(h.atb, 0.0)
	cfg.dodge_per_speed = 0.01
	assert_gt(StatCalculator.dodge_chance(h, cfg), 0.0)
	b.statuses.apply_forced(h, _stop(5.0))
	assert_eq(StatCalculator.dodge_chance(h, cfg), 0.0)

func test_stop_counts_seconds_not_turns_and_other_statuses_do_not_tick() -> void:
	var x: Combatant = _foe(&"x", 10)
	var h: Combatant = _hero(&"a", 10)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	b.statuses.apply_forced(x, _st(StatusDef.Kind.POISON, 3, 4, &"poison"))
	b.statuses.apply_forced(x, _stop(1.0))
	var all: Array[Combatant] = [h, x]
	assert_eq(b.statuses.tick_time(all, 0.4), [] as Array[Combatant])
	assert_true(x.is_stopped())
	assert_eq(b.statuses.tick_time(all, 0.4), [] as Array[Combatant])
	assert_true(x.is_stopped())
	assert_eq(b.statuses.tick_time(all, 0.4), [x] as Array[Combatant])
	assert_false(x.is_stopped())
	assert_eq(x.statuses.size(), 1, "o veneno continua, intocado")
	assert_eq(x.statuses[0].remaining, 3)

func test_stop_scales_with_battle_speed() -> void:
	var x: Combatant = _foe(&"x", 1)
	var h: Combatant = _hero(&"a", 1)
	var ctrl: BattleController = _ctrl([h], [x])
	ctrl.speed_mult = 2.0
	ctrl.b.statuses.apply_forced(x, _stop(1.0))
	for i: int in 9:
		ctrl.tick(0.05)
	assert_true(x.is_stopped(), "0,9 s de batalha")
	for i: int in 3:
		ctrl.tick(0.05)
	assert_false(x.is_stopped(), "1,2 s de batalha")

func test_stopped_hero_leaves_queue_keeps_full_atb_and_returns() -> void:
	var a: Combatant = _hero(&"a", 40)
	var bh: Combatant = _hero(&"b", 20)
	var x: Combatant = _foe(&"x", 1)
	var ctrl: BattleController = _ctrl([a, bh], [x])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null and ctrl.session.actor == a))
	assert_true(_until(ctrl, func() -> bool: return ctrl.b.queue.has(bh)))
	ctrl.b.statuses.apply_forced(bh, _stop(2.0))
	ctrl.tick(0.05)
	assert_false(ctrl.b.queue.has(bh), "sai da fila")
	assert_eq(bh.atb, 1.0, "mantém o ATB cheio")
	_attack(ctrl, x)
	var before: int = _log.size()
	for i: int in 20:
		ctrl.tick(0.05)
	assert_false(_log.slice(before).has("turn:b"), "parado não age")
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null and ctrl.session.actor == bh), "volta à fila e age depois do Pare")
	assert_false(bh.is_stopped())

func test_stopped_head_of_queue_does_not_jam_the_others() -> void:
	var a: Combatant = _hero(&"a", 40)
	var bh: Combatant = _hero(&"b", 30)
	var x: Combatant = _foe(&"x", 1)
	var ctrl: BattleController = _ctrl([a, bh], [x])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	var first: Combatant = ctrl.session.actor
	var other: Combatant = bh if first == a else a
	assert_true(_until(ctrl, func() -> bool: return ctrl.b.queue.has(other)))
	ctrl.b.statuses.apply_forced(other, _stop(30.0))
	_attack(ctrl, x)
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null and ctrl.session.actor == first), "o primeiro herói age de novo apesar do parado")
	assert_eq(ctrl.session.actor, first)

func test_stop_cancels_open_session_and_hero_returns() -> void:
	var a: Combatant = _hero(&"a", 40)
	var x: Combatant = _foe(&"x", 1)
	var ctrl: BattleController = _ctrl([a], [x])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(a.basic_attack))
	ctrl.b.statuses.apply_forced(a, _stop(1.0))
	ctrl.tick(0.05)
	assert_null(ctrl.session)
	assert_eq(_cancelled, 1)
	assert_eq(a.atb, 1.0)
	assert_false(ctrl.b.queue.has(a))
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null), "volta depois do Pare")
	assert_eq(ctrl.session.actor, a)

func test_stop_refunds_queued_action_in_active_mode() -> void:
	var tech: AbilityDef = Fixtures.hit(1.0)
	tech.id = &"tech"
	tech.ap_cost = 2
	var a: Combatant = _hero(&"a", 40, [tech])
	var x: Combatant = _foe(&"x", 12)
	var ctrl: BattleController = _ctrl([a], [x])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing != null), "o inimigo age com o menu aberto")
	var ap0: int = a.ap
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(a.abilities[0]))
	s.set_center(x)
	ctrl.submit(s.confirm())
	assert_eq(a.ap, ap0 - 2)
	assert_not_null(ctrl._queued)
	ctrl.b.statuses.apply_forced(a, _stop(1.0))
	ctrl.tick(0.01)
	assert_null(ctrl._queued)
	assert_eq(a.ap, ap0, "AP devolvido")
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null), "volta à fila depois do Pare")

func test_stop_does_not_end_with_damage() -> void:
	var x: Combatant = _foe(&"x", 1)
	var h: Combatant = _hero(&"a", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	b.statuses.apply_forced(x, _stop(5.0))
	b.statuses.on_hp_damage(x)
	assert_true(x.is_stopped())

func test_stop_is_negative_and_renews_time() -> void:
	var x: Combatant = _foe(&"x", 1)
	var h: Combatant = _hero(&"a", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new([0.0, 0.0]), [h], [x])
	var st: StatusDef = _stop(2.0)
	b.statuses.apply(x, st, h, 1.0, [x])
	b.statuses.tick_time([x], 1.5)
	assert_eq(b.statuses.apply(x, st, h, 1.0, [x]), StatusSystem.ApplyResult.RENEWED)
	assert_eq(x.statuses[0].time_left, 2.0)

# --- Confusão ---

func test_confusion_picks_random_target_among_living_except_self() -> void:
	var a: Combatant = _hero(&"a", 10)
	var a2: Combatant = _hero(&"b", 10)
	var x: Combatant = _foe(&"x", 10)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new([0.0, 0.99, 0.5]), [a, a2], [x])
	var first: PendingAction = EnemyAI.confused_action(a, b)
	assert_eq(first.center, a2)
	assert_true(first.confused)
	assert_eq(first.side(), AbilityDef.Side.BOTH)
	assert_eq(EnemyAI.confused_action(a, b).center, x)
	x.hp = 0
	var third: PendingAction = EnemyAI.confused_action(a, b)
	assert_eq(third.center, a2, "caídos não entram")

func test_confused_hero_acts_alone_without_menu() -> void:
	var a: Combatant = _hero(&"a", 40)
	var x: Combatant = _foe(&"x", 1)
	var ctrl: BattleController = _ctrl([a], [x])
	var seen: Array[Combatant] = []
	ctrl.confused_act.connect(func(c: Combatant) -> void: seen.append(c))
	ctrl.b.statuses.apply_forced(a, _st(StatusDef.Kind.CONFUSION, 5, 0, &"confusion"))
	assert_true(_until(ctrl, func() -> bool: return _log.has("started:a>x")))
	assert_false(_log.has("turn:a"), "sem menu")
	assert_null(ctrl.session)
	assert_eq(seen, [a] as Array[Combatant])

func test_confused_attack_can_hit_an_ally() -> void:
	var a: Combatant = _hero(&"a", 10)
	var a2: Combatant = _hero(&"b", 10)
	var x: Combatant = _foe(&"x", 10)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new([0.0]), [a, a2], [x])
	var act: PendingAction = EnemyAI.confused_action(a, b)
	var hp0: int = a2.hp
	ActionExecutor.apply(act, b)
	assert_lt(a2.hp, hp0)
	assert_eq(x.hp, StatCalculator.hp_max(x, cfg))

func test_confusion_ends_with_hp_damage() -> void:
	var x: Combatant = _foe(&"x", 1)
	var h: Combatant = _hero(&"a", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	b.statuses.apply_forced(x, _st(StatusDef.Kind.CONFUSION, 5, 0, &"confusion"))
	b.statuses.apply_forced(x, _st(StatusDef.Kind.PARALYSIS, 5, 0, &"paralysis"))
	b.statuses.on_hp_damage(x)
	assert_false(x.is_confused())
	assert_eq(x.statuses.size(), 1)

# --- Buffs e debuffs ---

func test_attr_mods_sum_and_floor_is_one() -> void:
	var h: Combatant = _hero(&"a", 10)
	var x: Combatant = _foe(&"x", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	assert_eq(StatCalculator.effective(h, &"strength", cfg), 10)
	b.statuses.apply_forced(h, _mod(&"str_up", &"strength", 4))
	b.statuses.apply_forced(h, _mod(&"str_down", &"strength", -2))
	assert_eq(StatCalculator.effective(h, &"strength", cfg), 12)
	b.statuses.apply_forced(h, _mod(&"str_down2", &"strength", -40))
	assert_eq(StatCalculator.effective(h, &"strength", cfg), 1, "mínimo 1 com buff/debuff")

func test_attr_without_status_keeps_zero() -> void:
	var d: CharacterDef = Fixtures.hero_def(&"z", Stats.make(0, 5, 5, 0))
	var h: Combatant = Combatant.from_hero(HeroState.create(d, cfg), Vector2.ZERO)
	assert_eq(StatCalculator.effective(h, &"strength", cfg), 0)

func test_vitality_debuff_lowers_max_hp() -> void:
	var h: Combatant = _hero(&"a", 10)
	var hp0: int = StatCalculator.hp_max(h, cfg)
	h.statuses.append(ActiveStatus.create(_mod(&"vit_down", &"vitality", -2), &"x", 1))
	assert_eq(StatCalculator.hp_max(h, cfg), hp0 - 20)

func test_speed_status_reorders_ready_queue() -> void:
	var a: Combatant = _hero(&"a", 9)
	var bh: Combatant = _hero(&"b", 5)
	var q := ReadyQueue.new(cfg, ScriptedDice.new())
	q.push(a, 1)
	q.push(bh, 1)
	assert_eq(q.peek(), a)
	a.statuses.append(ActiveStatus.create(_mod(&"spd_down", &"speed", -8), &"x", 1))
	assert_eq(q.peek(), bh, "Velocidade menor muda a ordem")
	bh.statuses.append(ActiveStatus.create(_mod(&"spd_down", &"speed", -3), &"x", 2))
	bh.statuses.append(ActiveStatus.create(_mod(&"spd_up", &"speed", 12), &"x", 3))
	assert_eq(q.peek(), bh)
	assert_eq(q.ordered(), [bh, a] as Array[Combatant])

# --- Silêncio ---

func test_silence_blocks_techniques_but_not_basic_item_or_limit() -> void:
	var tech: AbilityDef = Fixtures.hit(1.0)
	tech.id = &"tech"
	tech.ap_cost = 1
	var a: Combatant = _hero(&"a", 10, [tech])
	var x: Combatant = _foe(&"x", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [a], [x])
	var s := SelectionSession.new(a, b)
	assert_true(s.can_use(a.abilities[0]))
	assert_true(s.techniques_available())
	b.statuses.apply_forced(a, _st(StatusDef.Kind.SILENCE, 3, 0, &"silence"))
	assert_false(s.can_use(a.abilities[0]))
	assert_false(s.techniques_available())
	assert_false(s.choose_ability(a.abilities[0]))
	assert_eq(a.ap, StatCalculator.ap_max(a, cfg), "nada gasto")
	assert_true(s.choose_ability(a.basic_attack), "ataque básico liberado")
	s.back()
	a.limit = 1.0
	a.limit_ability = Fixtures.hit(2.0)
	assert_true(s.choose_limit(), "Limite liberado")

func test_silenced_enemy_ai_falls_back_to_basic() -> void:
	var tech: AbilityDef = Fixtures.hit(2.0)
	tech.id = &"tech"
	tech.ap_cost = 1
	var d: EnemyDef = Fixtures.enemy_def(&"x", Stats.make(10, 5, 5, 5))
	d.abilities = [d.abilities[0], tech]
	var rule := AiRule.new()
	rule.ability = tech
	d.ai_rules = [rule]
	var x: Combatant = Combatant.from_enemy(d, &"x", Vector2.ZERO, cfg)
	var h: Combatant = _hero(&"a", 10)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	assert_eq(EnemyAI.decide(x, b).ability, tech)
	x.ap = StatCalculator.ap_max(x, cfg)
	b.statuses.apply_forced(x, _st(StatusDef.Kind.SILENCE, 3, 0, &"silence"))
	var ap0: int = x.ap
	assert_eq(EnemyAI.decide(x, b).ability, x.basic_attack)
	assert_eq(x.ap, ap0, "não gasta AP")

func test_silence_midway_undoes_technique_choice_and_resets_menu() -> void:
	var tech: AbilityDef = Fixtures.hit(1.0)
	tech.id = &"tech"
	tech.ap_cost = 2
	var a: Combatant = _hero(&"a", 40, [tech])
	var x: Combatant = _foe(&"x", 1)
	var ctrl: BattleController = _ctrl([a], [x])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	var s: SelectionSession = ctrl.session
	var ap0: int = a.ap
	assert_true(s.choose_ability(a.abilities[0]))
	assert_eq(a.ap, ap0 - 2)
	ctrl.b.statuses.apply_forced(a, _st(StatusDef.Kind.SILENCE, 3, 0, &"silence"))
	ctrl.tick(0.05)
	assert_eq(_resets, 1)
	assert_eq(ctrl.session, s, "a sessão continua do mesmo herói")
	assert_eq(s.step, SelectionSession.Step.COMMAND)
	assert_eq(a.ap, ap0, "AP devolvido")
	ctrl.tick(0.05)
	assert_eq(_resets, 1, "avisa uma vez só")

func test_silence_refunds_queued_technique_and_hero_returns_to_queue() -> void:
	var tech: AbilityDef = Fixtures.hit(1.0)
	tech.id = &"tech"
	tech.ap_cost = 2
	var a: Combatant = _hero(&"a", 40, [tech])
	var x: Combatant = _foe(&"x", 12)
	var ctrl: BattleController = _ctrl([a], [x])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing != null))
	var ap0: int = a.ap
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(a.abilities[0]))
	s.set_center(x)
	ctrl.submit(s.confirm())
	ctrl.b.statuses.apply_forced(a, _st(StatusDef.Kind.SILENCE, 5, 0, &"silence"))
	ctrl.tick(0.01)
	assert_null(ctrl._queued)
	assert_eq(a.ap, ap0)
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null), "escolhe de novo")
	assert_eq(ctrl.session.actor, a)

# --- Cegueira ---

func _blind_setup(rolls: Array[float]) -> Array:
	var h: Combatant = _hero(&"a", 10)
	var x: Combatant = _foe(&"x", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(rolls), [h], [x])
	b.statuses.apply_forced(h, _st(StatusDef.Kind.BLIND, 3, 0, &"blind"))
	return [b, h, x]

func _act(h: Combatant, ab: AbilityDef, x: Combatant) -> PendingAction:
	var a := PendingAction.new()
	a.actor = h
	a.ability = ab
	a.center = x
	a.center_pos = x.position
	return a

func test_blind_misses_strength_damage_below_chance() -> void:
	var s: Array = _blind_setup([0.1])
	var r: ActionResult = ActionExecutor.apply(_act(s[1], Fixtures.hit(1.0), s[2]), s[0])
	assert_true(r.hits[0]["missed"])
	assert_eq(r.hits[0]["amount"], 0)
	assert_eq((s[2] as Combatant).hp, StatCalculator.hp_max(s[2], cfg))

func test_blind_hits_when_roll_is_high() -> void:
	var s: Array = _blind_setup([0.9])
	var r: ActionResult = ActionExecutor.apply(_act(s[1], Fixtures.hit(1.0), s[2]), s[0])
	assert_false(r.hits[0]["missed"])
	assert_lt((s[2] as Combatant).hp, StatCalculator.hp_max(s[2], cfg))

func test_blind_does_not_affect_aura_damage() -> void:
	var s: Array = _blind_setup([0.1])
	var ab: AbilityDef = Fixtures.hit(1.0)
	ab.effects[0].scale = EffectDef.Scale.AURA
	var r: ActionResult = ActionExecutor.apply(_act(s[1], ab, s[2]), s[0])
	assert_false(r.hits[0]["missed"])
	assert_lt((s[2] as Combatant).hp, StatCalculator.hp_max(s[2], cfg))

func test_not_blind_does_not_consume_dice() -> void:
	var h: Combatant = _hero(&"a", 10)
	var x: Combatant = _foe(&"x", 1)
	var dice := ScriptedDice.new([0.1])
	var b: BattleState = BattleState.create(cfg, dice, [h], [x])
	var r: ActionResult = ActionExecutor.apply(_act(h, Fixtures.hit(1.0), x), b)
	assert_false(r.hits[0]["missed"])
	assert_eq(dice.roll(), 0.1, "o sorteio não foi gasto")

# --- Regeneração ---

func test_regen_heals_after_poison_min_one_and_does_not_revive() -> void:
	var h: Combatant = _hero(&"a", 10)
	var x: Combatant = _foe(&"x", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	var hpm: int = StatCalculator.hp_max(h, cfg)
	h.hp = 20
	b.statuses.apply_forced(h, _st(StatusDef.Kind.POISON, 5, 4, &"poison"))
	b.statuses.apply_forced(h, _st(StatusDef.Kind.REGEN, 5, 0, &"regen"))
	var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(h, [x])
	assert_eq(out.poison_damage, 4)
	assert_eq(out.regen_heal, maxi(1, floori(hpm * cfg.regen_pct)))
	assert_eq(h.hp, 20 - 4 + out.regen_heal)
	b.statuses.remove(h, &"poison")
	h.hp = hpm
	assert_eq(b.statuses.on_atb_full(h, [x]).regen_heal, 0, "no máximo não cura")
	h.hp = 1
	b.statuses.clear_all(h)
	b.statuses.apply_forced(h, _st(StatusDef.Kind.POISON, 5, 9, &"poison"))
	b.statuses.apply_forced(h, _st(StatusDef.Kind.REGEN, 5, 0, &"regen"))
	var dead: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(h, [x])
	assert_true(h.is_down(), "o veneno mata antes")
	assert_eq(dead.regen_heal, 0, "não revive")
	assert_eq(h.hp, 0)

func test_regen_minimum_is_one() -> void:
	var h: Combatant = _hero(&"a", 10)
	var x: Combatant = _foe(&"x", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	cfg.regen_pct = 0.0001
	h.hp = 10
	b.statuses.apply_forced(h, _st(StatusDef.Kind.REGEN, 5, 0, &"regen"))
	assert_eq(b.statuses.on_atb_full(h, [x]).regen_heal, 1)

func test_regen_credits_ledger_as_ally_benefit() -> void:
	var healer: Combatant = _hero(&"a", 10)
	var h: Combatant = _hero(&"b", 10)
	var x: Combatant = _foe(&"x", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new([0.0]), [healer, h], [x])
	h.hp = 10
	var st: StatusDef = _st(StatusDef.Kind.REGEN, 5, 0, &"regen")
	assert_eq(b.statuses.apply(h, st, healer, 1.0, [x]), StatusSystem.ApplyResult.APPLIED)
	var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(h, [x])
	assert_eq(b.ledger.get_points(&"a", &"x"), float(out.regen_heal))

# --- REMOVE_STATUS ---

func _remove(statuses: Array[StatusDef], single: StatusDef = null) -> PendingAction:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.REMOVE_STATUS
	e.scale = EffectDef.Scale.FIXED
	e.status = single
	e.statuses = statuses
	var it := ItemDef.new()
	it.id = &"rem"
	it.effects = [e]
	var a := PendingAction.new()
	a.item = it
	return a

func test_remove_status_by_list_only_removes_listed() -> void:
	var h: Combatant = _hero(&"a", 10)
	var x: Combatant = _foe(&"x", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	var conf: StatusDef = _st(StatusDef.Kind.CONFUSION, 3, 0, &"confusion")
	var sil: StatusDef = _st(StatusDef.Kind.SILENCE, 3, 0, &"silence")
	var poi: StatusDef = _st(StatusDef.Kind.POISON, 3, 1, &"poison")
	for s: StatusDef in [conf, sil, poi]:
		b.statuses.apply_forced(h, s)
	var act: PendingAction = _remove([conf, sil])
	act.actor = h
	act.center = h
	act.center_pos = h.position
	var r: ActionResult = ActionExecutor.apply(act, b)
	assert_eq(r.hits[0]["amount"], 2)
	assert_eq(h.statuses.size(), 1)
	assert_eq(h.statuses[0].def.id, &"poison")

func test_remove_status_empty_removes_all_negatives_only() -> void:
	var h: Combatant = _hero(&"a", 10)
	var x: Combatant = _foe(&"x", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	var poi: StatusDef = _st(StatusDef.Kind.POISON, 3, 1, &"poison")
	poi.negative = true
	var regen: StatusDef = _st(StatusDef.Kind.REGEN, 3, 0, &"regen")
	b.statuses.apply_forced(h, poi)
	b.statuses.apply_forced(h, _stop(3.0))
	b.statuses.apply_forced(h, regen)
	var act: PendingAction = _remove([] as Array[StatusDef])
	act.actor = h
	act.center = h
	act.center_pos = h.position
	var r: ActionResult = ActionExecutor.apply(act, b)
	assert_eq(r.hits[0]["amount"], 2)
	assert_eq(h.statuses.size(), 1)
	assert_eq(h.statuses[0].def.id, &"regen")

func test_remove_status_single_still_works() -> void:
	var h: Combatant = _hero(&"a", 10)
	var x: Combatant = _foe(&"x", 1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	var sil: StatusDef = _st(StatusDef.Kind.SILENCE, 3, 0, &"silence")
	b.statuses.apply_forced(h, sil)
	b.statuses.apply_forced(h, _st(StatusDef.Kind.BLIND, 3, 0, &"blind"))
	var act: PendingAction = _remove([] as Array[StatusDef], sil)
	act.actor = h
	act.center = h
	act.center_pos = h.position
	ActionExecutor.apply(act, b)
	assert_eq(h.statuses.size(), 1)
	assert_eq(h.statuses[0].def.id, &"blind")

# --- Dados de teste ---

func _load_status(id: String) -> StatusDef:
	return load("res://data/test/statuses/%s.tres" % id) as StatusDef

func test_catalog_data_loads() -> void:
	for id: String in ["stop", "confusion", "silence", "blind", "regen", "str_down", "vit_up", "vit_down", "spd_up", "spd_down"]:
		var s: StatusDef = _load_status(id)
		assert_not_null(s, id)
		assert_eq(s.id, StringName(id))
	assert_eq(_load_status("stop").kind, StatusDef.Kind.STOP)
	assert_gt(_load_status("stop").seconds, 0.0)
	assert_lt(_load_status("str_down").potency, 0)
	assert_eq(_load_status("spd_down").attr, &"speed")
	for id: String in ["stop", "confusion", "silence", "blind", "poison", "sleep", "paralysis", "slow", "str_down", "vit_down", "spd_down"]:
		assert_true(_load_status(id).negative, "%s é negativo" % id)
	for id: String in ["regen", "haste", "barrier", "str_up", "vit_up", "spd_up"]:
		assert_false(_load_status(id).negative, "%s não é negativo" % id)

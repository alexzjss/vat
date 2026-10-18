extends GutTest

const HERO_IDS: Array[StringName] = [&"a", &"b", &"c"]
const ENEMY_IDS: Array[StringName] = [&"x", &"y", &"z"]

var _log: Array[String] = []

func before_each() -> void:
	_log = []

## Heróis Stats(10, spd, 5, 1): hp 55, dano 10 - floor(5*0.5) = 8.
## Inimigos Stats(10, spd, 5, 5) com Fixtures.hit(1.0) como basic_attack e IA vazia.
func _battle(hero_speeds: Array[int], enemy_speeds: Array[int]) -> BattleController:
	var cfg := Fixtures.cfg()
	var heroes: Array[Combatant] = []
	for i: int in hero_speeds.size():
		var hs := HeroState.create(Fixtures.hero_def(HERO_IDS[i], Stats.make(10, hero_speeds[i], 5, 1)), cfg)
		heroes.append(Combatant.from_hero(hs, Vector2.ZERO))
	var enemies: Array[Combatant] = []
	for i: int in enemy_speeds.size():
		var d := Fixtures.enemy_def(ENEMY_IDS[i], Stats.make(10, enemy_speeds[i], 5, 5))
		enemies.append(Combatant.from_enemy(d, ENEMY_IDS[i], Vector2.ZERO, cfg))
	var b := BattleState.create(cfg, ScriptedDice.new(), heroes, enemies)
	var ctrl := BattleController.new(b)
	ctrl.hero_turn.connect(func(s: SelectionSession) -> void: _log.append("turn:%s" % s.actor.id))
	ctrl.action_started.connect(func(a: PendingAction) -> void: _log.append("started:%s" % a.actor.id))
	ctrl.action_impact.connect(func(a: PendingAction, _r: ActionResult) -> void: _log.append("impact:%s" % a.actor.id))
	ctrl.action_finished.connect(func(a: PendingAction) -> void: _log.append("finished:%s" % a.actor.id))
	ctrl.turn_lost.connect(func(c: Combatant) -> void: _log.append("lost:%s" % c.id))
	ctrl.battle_ended.connect(func(o: BattleController.Outcome) -> void: _log.append("ended:%s" % BattleController.Outcome.keys()[o]))
	watch_signals(ctrl)
	return ctrl

func _run(ctrl: BattleController, seconds: float, step: float = 0.05) -> void:
	var n: int = int(round(seconds / step))
	for i: int in n:
		ctrl.tick(step)

## Escolhe o ataque básico do herói da sessão contra `target` e submete.
func _attack(ctrl: BattleController, target: Combatant) -> PendingAction:
	var s: SelectionSession = ctrl.session
	assert_not_null(s)
	assert_true(s.choose_ability(s.actor.basic_attack))
	s.set_center(target)
	var a: PendingAction = s.confirm()
	ctrl.submit(a)
	return a

func _count(prefix: String) -> int:
	var n: int = 0
	for e: String in _log:
		if e == prefix:
			n += 1
	return n

func test_menu_pauses_time() -> void:
	var ctrl := _battle([10], [10])
	var b: BattleState = ctrl.b
	var h: Combatant = b.heroes[0]
	var x: Combatant = b.enemies[0]
	h.atb = 0.999
	ctrl.tick(0.05)
	assert_signal_emit_count(ctrl, "hero_turn", 1)
	assert_true(ctrl.is_paused())
	assert_eq(ctrl.session.actor, h)
	var x_atb: float = x.atb
	var tick_before: int = b.tick
	_run(ctrl, 5.0)
	assert_eq(x.atb, x_atb)
	assert_eq(h.atb, 1.0)
	assert_eq(b.tick, tick_before)
	assert_signal_emit_count(ctrl, "hero_turn", 1)
	assert_signal_emit_count(ctrl, "action_started", 0)

func test_ready_during_menu_highest_speed_acts_next() -> void:
	var ctrl := _battle([5, 15], [0])
	var b: BattleState = ctrl.b
	var slow: Combatant = b.heroes[0]
	var fast: Combatant = b.heroes[1]
	slow.atb = 0.999
	fast.atb = 0.999
	ctrl.tick(0.05)
	assert_eq(ctrl.session.actor, fast)
	assert_true(b.queue.has(slow))
	_attack(ctrl, b.enemies[0])
	assert_false(ctrl.is_paused())
	_run(ctrl, 1.1)
	assert_eq(_log, ["turn:b", "started:b", "impact:b", "finished:b", "turn:a"])
	assert_eq(ctrl.session.actor, slow)

func test_ready_during_animation_waits_in_queue() -> void:
	var ctrl := _battle([10], [0])
	var b: BattleState = ctrl.b
	var h: Combatant = b.heroes[0]
	var x: Combatant = b.enemies[0]
	x.basic_attack.cast_time = 3.0
	x.basic_attack.impact_time = 1.5
	x.atb = 0.999
	ctrl.tick(0.05)
	assert_eq(ctrl.executing.actor, x)
	# herói speed 10: taxa 0.4/s, enche em 2.5 s (no meio do cast de 3.0 s)
	_run(ctrl, 2.7)
	assert_eq(h.atb, 1.0)
	assert_true(b.queue.has(h))
	assert_null(ctrl.session)
	assert_signal_emit_count(ctrl, "hero_turn", 0)
	assert_signal_emit_count(ctrl, "action_finished", 0)
	_run(ctrl, 0.5)
	assert_eq(_log, ["started:x", "impact:x", "finished:x", "turn:a"])
	assert_eq(ctrl.session.actor, h)
	assert_false(b.queue.has(h))

func test_effects_resolve_before_next_action() -> void:
	var ctrl := _battle([0], [0, 0])
	var b: BattleState = ctrl.b
	b.enemies[0].atb = 0.999
	b.enemies[1].atb = 0.999
	ctrl.tick(0.05)
	_run(ctrl, 2.5)
	assert_eq(_log.size(), 6)
	var first: String = _log[0].trim_prefix("started:")
	var second: String = _log[3].trim_prefix("started:")
	assert_ne(first, second)
	assert_eq(_log, [
		"started:" + first, "impact:" + first, "finished:" + first,
		"started:" + second, "impact:" + second, "finished:" + second,
	])

func test_downed_actor_action_completes() -> void:
	var ctrl := _battle([0, 0], [0])
	var b: BattleState = ctrl.b
	var h: Combatant = b.heroes[0]
	var x: Combatant = b.enemies[0]
	var x_hp: int = x.hp
	h.atb = 0.999
	ctrl.tick(0.05)
	_attack(ctrl, x)
	_run(ctrl, 0.2)
	assert_eq(x.hp, x_hp, "ainda antes do impacto (0.5 s)")
	h.hp = 0
	_run(ctrl, 1.0)
	assert_eq(x.hp, x_hp - 8)
	assert_signal_emit_count(ctrl, "action_impact", 1)
	assert_signal_emit_count(ctrl, "action_finished", 1)
	assert_eq(h.atb, 0.0)
	assert_null(ctrl.executing)

func test_downed_hero_in_queue_never_gets_menu() -> void:
	var ctrl := _battle([0, 0], [20])
	var b: BattleState = ctrl.b
	var a: Combatant = b.heroes[0]
	var x: Combatant = b.enemies[0]
	a.hp = 1
	a.atb = 0.999
	x.atb = 0.999
	ctrl.tick(0.05)
	assert_eq(ctrl.executing.actor, x, "inimigo (speed 20) sai antes do herói (speed 0)")
	assert_true(b.queue.has(a))
	_run(ctrl, 1.5)
	assert_true(a.is_down())
	assert_false(b.queue.has(a))
	assert_eq(_count("turn:a"), 0)
	assert_signal_emit_count(ctrl, "hero_turn", 0)
	assert_eq(ctrl.outcome, BattleController.Outcome.ONGOING)

func test_battle_ends_once_with_ready_queue_nonempty() -> void:
	var ctrl := _battle([20, 0], [0])
	var b: BattleState = ctrl.b
	var fast: Combatant = b.heroes[0]
	var other: Combatant = b.heroes[1]
	var x: Combatant = b.enemies[0]
	x.hp = 1
	fast.atb = 0.999
	other.atb = 0.999
	ctrl.tick(0.05)
	assert_eq(ctrl.session.actor, fast)
	_attack(ctrl, x)
	_run(ctrl, 3.0)
	assert_true(x.is_down())
	assert_true(b.queue.has(other))
	assert_signal_emit_count(ctrl, "battle_ended", 1)
	assert_signal_emitted_with_parameters(ctrl, "battle_ended", [BattleController.Outcome.VICTORY])
	assert_eq(ctrl.outcome, BattleController.Outcome.VICTORY)
	assert_signal_emit_count(ctrl, "hero_turn", 1)
	assert_null(ctrl.session)
	assert_eq(_log.back(), "ended:VICTORY")

func test_battle_ends_with_defeat() -> void:
	var ctrl := _battle([0], [0])
	var b: BattleState = ctrl.b
	var h: Combatant = b.heroes[0]
	h.hp = 1
	b.enemies[0].atb = 0.999
	ctrl.tick(0.05)
	_run(ctrl, 3.0)
	assert_true(h.is_down())
	assert_signal_emit_count(ctrl, "battle_ended", 1)
	assert_signal_emitted_with_parameters(ctrl, "battle_ended", [BattleController.Outcome.DEFEAT])
	assert_eq(ctrl.outcome, BattleController.Outcome.DEFEAT)
	assert_signal_emit_count(ctrl, "hero_turn", 0)
	var t: int = b.tick
	_run(ctrl, 1.0)
	assert_eq(b.tick, t, "batalha encerrada não avança")

func test_sleeping_enemy_loses_turn_and_atb_resets() -> void:
	var ctrl := _battle([0], [20])
	var b: BattleState = ctrl.b
	var x: Combatant = b.enemies[0]
	var sleep := Fixtures.status_def(StatusDef.Kind.SLEEP, 1)
	assert_eq(b.statuses.apply(x, sleep, b.heroes[0], 1.0, b.living(b.enemies)), StatusSystem.ApplyResult.APPLIED)
	x.atb = 0.999
	ctrl.tick(0.05)
	assert_signal_emit_count(ctrl, "status_tick", 1)
	assert_signal_emit_count(ctrl, "turn_lost", 1)
	assert_signal_emitted_with_parameters(ctrl, "turn_lost", [x])
	assert_eq(x.atb, 0.0)
	assert_false(b.queue.has(x))
	assert_null(ctrl.executing)
	assert_true(x.statuses.is_empty(), "SLEEP 1 expira")
	# speed 20: taxa 0.6/s, enche de novo em ~1.67 s
	_run(ctrl, 1.8)
	assert_signal_emit_count(ctrl, "turn_lost", 1)
	assert_eq(ctrl.executing.actor, x)
	assert_eq(_log, ["lost:x", "started:x"])

func test_poison_downing_on_atb_full_removes_from_play() -> void:
	var ctrl := _battle([0, 0], [0])
	var b: BattleState = ctrl.b
	var a: Combatant = b.heroes[0]
	var poison := Fixtures.status_def(StatusDef.Kind.POISON, 3, 5)
	b.statuses.apply(a, poison, b.enemies[0], 1.0, b.living(b.enemies))
	a.hp = 3
	a.atb = 0.999
	ctrl.tick(0.05)
	assert_true(a.is_down())
	assert_signal_emit_count(ctrl, "status_tick", 1)
	var params: Array = get_signal_parameters(ctrl, "status_tick")
	var outcome: StatusSystem.AtbFullOutcome = params[1]
	assert_eq(outcome.poison_damage, 3)
	assert_eq(a.atb, 0.0)
	assert_true(a.statuses.is_empty())
	assert_false(b.queue.has(a))
	assert_signal_emit_count(ctrl, "turn_lost", 0)
	assert_signal_emit_count(ctrl, "hero_turn", 0)
	assert_eq(ctrl.outcome, BattleController.Outcome.ONGOING)

func test_enemy_null_decision_resets_atb_and_skips() -> void:
	var ctrl := _battle([0], [0])
	var b: BattleState = ctrl.b
	var x: Combatant = b.enemies[0]
	x.basic_attack = null
	x.atb = 0.999
	ctrl.tick(0.05)
	assert_push_error("sem ataque")
	assert_eq(x.atb, 0.0)
	assert_null(ctrl.executing)
	assert_false(b.queue.has(x))
	assert_signal_emit_count(ctrl, "action_started", 0)

func test_impact_and_finish_in_same_tick() -> void:
	var ctrl := _battle([0], [0])
	var b: BattleState = ctrl.b
	var x: Combatant = b.enemies[0]
	x.atb = 0.999
	ctrl.tick(0.05)
	ctrl.tick(2.0)
	assert_eq(_log, ["started:x", "impact:x", "finished:x"])
	assert_eq(x.atb, 0.0)
	assert_null(ctrl.executing)

func test_submit_null_errors_and_does_nothing() -> void:
	var ctrl := _battle([10], [0])
	ctrl.b.heroes[0].atb = 0.999
	ctrl.tick(0.05)
	assert_not_null(ctrl.session)
	ctrl.submit(null)
	assert_push_error("submit")
	assert_null(ctrl.executing)
	assert_not_null(ctrl.session, "sessão continua aberta")
	assert_signal_emit_count(ctrl, "action_started", 0)

func test_submit_without_session_errors() -> void:
	var ctrl := _battle([10], [0])
	var a := PendingAction.new()
	a.actor = ctrl.b.heroes[0]
	a.ability = Fixtures.hit(1.0)
	a.center = ctrl.b.enemies[0]
	ctrl.submit(a)
	assert_push_error("submit")
	assert_null(ctrl.executing)
	assert_signal_emit_count(ctrl, "action_started", 0)

func test_submit_while_executing_errors() -> void:
	var ctrl := _battle([10], [0])
	var b: BattleState = ctrl.b
	b.heroes[0].atb = 0.999
	ctrl.tick(0.05)
	var running := PendingAction.new()
	running.actor = b.enemies[0]
	running.ability = Fixtures.hit(1.0)
	running.center = b.heroes[0]
	ctrl.executing = running
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(s.actor.basic_attack))
	s.set_center(b.enemies[0])
	ctrl.submit(s.confirm())
	assert_push_error("submit")
	assert_same(ctrl.executing, running, "ação em execução intacta")
	assert_signal_emit_count(ctrl, "action_started", 0)

func test_fizzle_keeps_ap_spent_resets_atb_and_finishes() -> void:
	var ctrl := _battle([10], [0, 0])
	var b: BattleState = ctrl.b
	var h: Combatant = b.heroes[0]
	h.atb = 0.999
	ctrl.tick(0.05)
	var costly := Fixtures.hit(1.0)
	costly.ap_cost = 2
	var ap0: int = h.ap
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(costly))
	s.set_center(b.enemies[0])
	var results: Array[ActionResult] = []
	ctrl.action_impact.connect(func(_a: PendingAction, r: ActionResult) -> void: results.append(r))
	ctrl.submit(s.confirm())
	for e: Combatant in b.enemies:
		e.hp = 0
	ctrl.tick(costly.cast_time)
	assert_eq(results.size(), 1)
	assert_true(results[0].fizzled, "sem alvos válidos: falha")
	assert_eq(h.ap, ap0 - 2, "AP gasto é perdido (spec §4.6)")
	assert_eq(h.atb, 0.0)
	assert_null(ctrl.executing)
	assert_signal_emit_count(ctrl, "action_finished", 1)

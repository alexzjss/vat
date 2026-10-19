extends GutTest

## Modo ATB Ativo (M6): o tempo corre com o menu de um herói aberto.

const HERO_IDS: Array[StringName] = [&"a", &"b"]
const ENEMY_IDS: Array[StringName] = [&"x", &"y"]

var _log: Array[String] = []
var _cancelled: int = 0

func before_each() -> void:
	_log = []
	_cancelled = 0

func _battle(hero_speeds: Array[int], enemy_speeds: Array[int], active: bool = true) -> BattleController:
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
	ctrl.active_mode = active
	ctrl.hero_turn.connect(func(s: SelectionSession) -> void: _log.append("turn:%s" % s.actor.id))
	ctrl.action_started.connect(func(a: PendingAction) -> void: _log.append("started:%s>%s" % [a.actor.id, a.center.id]))
	ctrl.action_finished.connect(func(a: PendingAction) -> void: _log.append("finished:%s" % a.actor.id))
	ctrl.turn_lost.connect(func(c: Combatant) -> void: _log.append("lost:%s" % c.id))
	ctrl.session_cancelled.connect(func(_s: SelectionSession) -> void: _cancelled += 1)
	return ctrl

## Avança até `cond` valer (no máximo `max_ticks` passos de 0,05 s).
func _until(ctrl: BattleController, cond: Callable, max_ticks: int = 600) -> bool:
	for i: int in max_ticks:
		if cond.call():
			return true
		ctrl.tick(0.05)
	return cond.call()

func _choose_attack(ctrl: BattleController, target: Combatant) -> PendingAction:
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(s.actor.basic_attack))
	s.set_center(target)
	return s.confirm()

func test_wait_mode_still_pauses_with_session() -> void:
	var ctrl := _battle([20], [10], false)
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_true(ctrl.is_paused())
	var atb: float = ctrl.b.enemies[0].atb
	ctrl.tick(1.0)
	assert_eq(ctrl.b.enemies[0].atb, atb)

func test_active_mode_does_not_pause_and_enemy_acts_with_session_open() -> void:
	var ctrl := _battle([20], [10])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_false(ctrl.is_paused())
	var s: SelectionSession = ctrl.session
	assert_true(_until(ctrl, func() -> bool: return _log.has("started:x>a")), "inimigo age com o menu aberto")
	assert_eq(ctrl.session, s, "a sessao do heroi continua aberta")

func test_submit_during_execution_is_queued_and_starts_after() -> void:
	var ctrl := _battle([20], [10])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing != null))
	var foe_action: PendingAction = ctrl.executing
	ctrl.submit(_choose_attack(ctrl, ctrl.b.enemies[0]))
	assert_null(ctrl.session)
	assert_eq(ctrl.executing, foe_action, "a acao em curso nao e interrompida")
	assert_false(_log.has("started:a>x"))
	assert_true(_until(ctrl, func() -> bool: return _log.has("started:a>x")))
	assert_lt(_log.find("finished:x"), _log.find("started:a>x"), "comeca depois que a outra termina")

func test_queued_action_retargets_when_target_fell() -> void:
	var ctrl := _battle([20], [10, 10])
	var x: Combatant = ctrl.b.enemies[0]
	var y: Combatant = ctrl.b.enemies[1]
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing != null))
	ctrl.submit(_choose_attack(ctrl, y))
	y.hp = 0
	ctrl.b.queue.remove(y)
	assert_true(_until(ctrl, func() -> bool: return _log.has("started:a>x")), "redirecionada para o alvo valido")
	assert_false(_log.has("started:a>y"))
	assert_gt(x.hp, -1)

func test_queued_action_without_targets_is_lost_and_ap_stays() -> void:
	var ctrl := _battle([20, 5], [10])
	var a: Combatant = ctrl.b.heroes[0]
	var down: Combatant = ctrl.b.heroes[1]
	down.hp = 0
	var revive := EffectDef.new()
	revive.kind = EffectDef.Kind.REVIVE
	revive.scale = EffectDef.Scale.FIXED
	revive.potency = 10.0
	var ab := AbilityDef.new()
	ab.id = &"revive"
	ab.display_name = "Reviver"
	ab.ap_cost = 3
	ab.shape = AbilityDef.Shape.SINGLE
	ab.side = AbilityDef.Side.ALLIES
	ab.cast_time = 1.0
	ab.impact_time = 0.5
	ab.effects = [revive]
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing != null))
	var ap0: int = a.ap
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_ability(ab))
	s.set_center(down)
	ctrl.submit(s.confirm())
	assert_eq(a.ap, ap0 - 3)
	down.hp = 10
	assert_true(_until(ctrl, func() -> bool: return _log.has("lost:a")), "acao sem alvo e perdida")
	assert_eq(a.ap, ap0, "AP nao e gasto")
	assert_false(_log.has("started:a>b"))
	assert_eq(a.atb, 0.0)

func test_hero_falling_with_session_open_cancels_it_and_queue_goes_on() -> void:
	var ctrl := _battle([30, 10], [5])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	var a: Combatant = ctrl.session.actor
	assert_eq(a.id, &"a")
	var ap0: int = a.ap
	ctrl.session.choose_ability(a.basic_attack)
	a.hp = 0
	a.atb = 0.0
	ctrl.tick(0.05)
	assert_null(ctrl.session)
	assert_eq(_cancelled, 1)
	assert_eq(a.ap, ap0, "escolha desfeita")
	assert_true(_until(ctrl, func() -> bool: return _log.has("turn:b")), "o proximo heroi da fila abre o menu")
	assert_eq(ctrl.session.actor.id, &"b")

func test_other_hero_waits_while_a_session_is_open() -> void:
	var ctrl := _battle([30, 25], [1])
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	var first: StringName = ctrl.session.actor.id
	for i: int in 100:
		ctrl.tick(0.05)
	assert_eq(ctrl.session.actor.id, first)
	assert_eq(_log.count("turn:a") + _log.count("turn:b"), 1)
	assert_true(ctrl.b.queue.has(ctrl.b.heroes[1]) or ctrl.b.heroes[1].atb >= 1.0)

func test_queued_item_is_refunded_when_hero_falls_before_it_starts() -> void:
	var ctrl := _battle([20, 5], [10])
	var a: Combatant = ctrl.b.heroes[0]
	var x: Combatant = ctrl.b.enemies[0]
	var potion := ItemDef.new()
	potion.id = &"potion"
	potion.display_name = "Pocao"
	var fx := EffectDef.new()
	fx.kind = EffectDef.Kind.HEAL
	fx.scale = EffectDef.Scale.FIXED
	fx.potency = 10.0
	potion.effects = [fx]
	ctrl.b.inventory.add(potion, 2)
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing != null))
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_item(potion))
	s.set_center(a)
	ctrl.submit(s.confirm())
	assert_eq(ctrl.b.inventory.available(&"potion"), 1, "consumido ao confirmar")
	a.hp = 0
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing == null and ctrl._queued == null))
	assert_eq(ctrl.b.inventory.available(&"potion"), 2, "item devolvido")
	assert_false(_log.has("started:a>a"))
	assert_gt(x.hp, -1)

# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name BattleController
extends RefCounted

## Laço ATB da batalha. Ordem dentro de um tick: ATB -> execução -> próximo da fila.

signal hero_turn(session: SelectionSession)
signal action_started(a: PendingAction)
signal action_impact(a: PendingAction, r: ActionResult)
signal action_finished(a: PendingAction)
signal turn_lost(c: Combatant)
signal status_tick(c: Combatant, outcome: StatusSystem.AtbFullOutcome)
signal battle_ended(outcome: Outcome)

enum Outcome { ONGOING, VICTORY, DEFEAT }

var b: BattleState
var outcome: Outcome = Outcome.ONGOING
var session: SelectionSession
var executing: PendingAction
var _clock: AtbClock

func _init(p_b: BattleState) -> void:
	b = p_b
	_clock = AtbClock.new(b.cfg)

func is_paused() -> bool:
	return session != null

func tick(delta: float) -> void:
	if outcome != Outcome.ONGOING or is_paused():
		return
	_advance_atb(delta)
	if executing != null:
		_advance_execution(delta)
	if executing == null:
		_check_end()
		if outcome == Outcome.ONGOING:
			_start_next()

func submit(a: PendingAction) -> void:
	if a == null or executing != null or session == null:
		push_error("submit invalido: acao nula, ja executando ou sem sessao de heroi")
		return
	session = null
	_begin(a)

func _advance_atb(delta: float) -> void:
	b.tick += 1
	for c: Combatant in _clock.advance(delta, b.all(), b.queue):
		var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(c, b.living(b.enemies))
		status_tick.emit(c, out)
		if c.is_down():
			b.statuses.clear_all(c)
			c.atb = 0.0
			b.queue.remove(c)
		elif out.lost_turn:
			c.atb = 0.0
			turn_lost.emit(c)
		else:
			b.queue.push(c, b.tick)

func _advance_execution(delta: float) -> void:
	var a: PendingAction = executing
	a.elapsed += delta
	if not a.impacted and a.elapsed >= a.impact_time(b.cfg):
		var r: ActionResult = ActionExecutor.apply(a, b)
		a.impacted = true
		action_impact.emit(a, r)
	if a.elapsed >= a.cast_time(b.cfg):
		a.actor.atb = 0.0
		executing = null
		action_finished.emit(a)

## [P-plano] 9: só checado quando nenhuma ação está executando.
func _check_end() -> void:
	if outcome != Outcome.ONGOING:
		return
	if b.living(b.enemies).is_empty():
		outcome = Outcome.VICTORY
	elif b.living(b.heroes).is_empty():
		outcome = Outcome.DEFEAT
	else:
		return
	battle_ended.emit(outcome)

func _start_next() -> void:
	var c: Combatant = b.queue.pop_next()
	if c == null:
		return
	if c.team == Combatant.Team.ENEMY:
		var a: PendingAction = EnemyAI.decide(c, b)
		if a == null:
			c.atb = 0.0
			return
		_begin(a)
	else:
		session = SelectionSession.new(c, b)
		hero_turn.emit(session)

func _begin(a: PendingAction) -> void:
	a.elapsed = 0.0
	a.impacted = false
	executing = a
	action_started.emit(a)

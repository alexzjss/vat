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
## O herói da sessão aberta caiu (modo Ativo): a sessão foi desfeita e o menu deve fechar.
signal session_cancelled(s: SelectionSession)

enum Outcome { ONGOING, VICTORY, DEFEAT }

var b: BattleState
var outcome: Outcome = Outcome.ONGOING
var session: SelectionSession
var executing: PendingAction
## Multiplicador só do delta do ATB (velocidade da batalha); animações e ações não mudam.
var speed_mult: float = 1.0
## ATB Ativo: o tempo corre com o menu de um herói aberto (sem pausa). Em Espera (padrão) nada muda.
var active_mode: bool = false
var _clock: AtbClock
## Ação confirmada durante a execução de outra (só no modo Ativo); começa assim que ela termina.
var _queued: PendingAction

func _init(p_b: BattleState) -> void:
	b = p_b
	_clock = AtbClock.new(b.cfg)
	for h: Combatant in b.heroes:
		if h.is_down():
			continue
		for st: StatusDef in h.start_statuses:
			b.statuses.apply_forced(h, st)

func is_paused() -> bool:
	return session != null and not active_mode

func tick(delta: float) -> void:
	if outcome != Outcome.ONGOING or is_paused():
		return
	_cancel_session_if_down()
	_advance_atb(delta)
	if executing != null:
		_advance_execution(delta)
	if executing == null:
		_check_end()
		if outcome == Outcome.ONGOING:
			if _queued != null:
				_begin_queued()
			else:
				_start_next()

func submit(a: PendingAction) -> void:
	if a == null or session == null or (executing != null and not active_mode):
		push_error("submit invalido: acao nula, ja executando ou sem sessao de heroi")
		return
	session = null
	if executing != null:
		_queued = a
	else:
		_begin(a)

func _advance_atb(delta: float) -> void:
	b.tick += 1
	for c: Combatant in _clock.advance(delta * speed_mult, b.all(), b.queue):
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
	_drop_session()
	battle_ended.emit(outcome)

func _start_next() -> void:
	# Com a sessão de um herói aberta (modo Ativo) só os inimigos seguem; os outros heróis esperam.
	var c: Combatant = _pop_next_enemy() if session != null else b.queue.pop_next()
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
	if not _retarget(a):
		_lose(a)
		return
	a.elapsed = 0.0
	a.impacted = false
	executing = a
	action_started.emit(a)

func _pop_next_enemy() -> Combatant:
	b.queue.peek()
	for c: Combatant in b.queue.ordered():
		if c.team == Combatant.Team.ENEMY and not c.is_down():
			b.queue.remove(c)
			return c
	return null

func _begin_queued() -> void:
	var a: PendingAction = _queued
	_queued = null
	if a.actor.is_down():
		return
	_begin(a)

## Revalida o alvo no começo da ação (ele pode ter caído durante a espera): mantém, redireciona
## pela regra do Targeting ou devolve false se não há mais nenhum alvo.
func _retarget(a: PendingAction) -> bool:
	var c: Combatant = Targeting.redirect(a.shape(), a.side(), a.effects(), a.actor, a.center, a.center_pos, b)
	if c == null:
		return false
	if c != a.center:
		a.center = c
		a.center_pos = c.position
	return true

## Ação sem alvo: perdida sem gastar AP nem item; o turno termina.
func _lose(a: PendingAction) -> void:
	if a.item != null:
		b.inventory.refund(a.item.id)
	elif a.ability != null:
		a.actor.ap += a.ability.ap_cost
	a.actor.atb = 0.0
	turn_lost.emit(a.actor)

func _cancel_session_if_down() -> void:
	if session != null and session.actor.is_down():
		_drop_session()

func _drop_session() -> void:
	if session == null:
		return
	var s: SelectionSession = session
	s.back()
	session = null
	session_cancelled.emit(s)

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
## Silêncio (M11): a sessão aberta continua do mesmo herói, mas voltou ao comando raiz (técnica desfeita); o menu deve reabrir a raiz.
signal session_reset(s: SelectionSession)
## Confusão (M11): o combatente age sozinho (ataque básico num alvo sorteado) em vez de abrir menu ou consultar a IA.
signal confused_act(c: Combatant)
## O Pare de `c` acabou neste passo.
signal stop_ended(c: Combatant)

enum Outcome { ONGOING, VICTORY, DEFEAT, FLED }

var b: BattleState
var outcome: Outcome = Outcome.ONGOING
var session: SelectionSession
var executing: PendingAction
## Multiplicador só do delta do ATB (velocidade da batalha); animações e ações não mudam.
var speed_mult: float = 1.0
## ATB Ativo: o tempo corre com o menu de um herói aberto (sem pausa). Em Espera (padrão) nada muda.
var active_mode: bool = false
## Fuga (M7): barra de 0 a 1 que corre em tempo real (ver update_flee). Cheia, a batalha termina
## como FLED assim que nenhuma ação estiver executando.
var flee_gauge: float = 0.0
## false (chefes, standalone): a barra não enche.
var can_flee: bool = true
var _clock: AtbClock
## Ação confirmada durante a execução de outra (só no modo Ativo); começa assim que ela termina.
var _queued: PendingAction
## O menu da sessão aberta já foi avisado de que o herói está mudo.
var _silence_notified: bool = false

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
	_enforce_statuses()
	_advance_atb(delta)
	if executing != null:
		_advance_execution(delta)
	# O impacto pode ter aplicado Pare ou Silêncio: ninguém parado chega ao _start_next.
	_enforce_statuses()
	if executing == null:
		_try_flee()
		_check_end()
		if outcome == Outcome.ONGOING:
			if _queued != null:
				_begin_queued()
			else:
				_start_next()

## Fuga: `real_delta` é tempo real (ignora speed_mult e a pausa do modo Espera). Enche a
## `flee_base_rate * (Vel média dos heróis vivos + 1) / (Vel média dos inimigos vivos + 1)` por segundo
## enquanto `holding`; senão esvazia a `flee_decay`/s. Sem `can_flee` a barra fica em 0.
func update_flee(real_delta: float, holding: bool) -> void:
	if outcome != Outcome.ONGOING:
		return
	if not can_flee:
		flee_gauge = 0.0
		return
	if holding:
		flee_gauge = minf(1.0, flee_gauge + flee_rate() * real_delta)
	else:
		flee_gauge = maxf(0.0, flee_gauge - b.cfg.flee_decay * real_delta)
	_try_flee()

func flee_rate() -> float:
	return b.cfg.flee_base_rate * (_avg_speed(b.heroes) + 1.0) / (_avg_speed(b.enemies) + 1.0)

func _avg_speed(side: Array[Combatant]) -> float:
	var alive: Array[Combatant] = b.living(side)
	if alive.is_empty():
		return 0.0
	var sum: float = 0.0
	for c: Combatant in alive:
		sum += StatCalculator.effective(c, &"speed", b.cfg)
	return sum / alive.size()

## Barra cheia e nenhuma ação executando: encerra como FLED. A sessão aberta é desfeita e a ação
## enfileirada é reembolsada; HP, AP e itens já gastos ficam como estão.
func _try_flee() -> void:
	if outcome != Outcome.ONGOING or not can_flee or flee_gauge < 1.0 or executing != null:
		return
	outcome = Outcome.FLED
	_drop_session()
	_discard_queued()
	battle_ended.emit(outcome)

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
	# Pare conta em segundos de batalha (o ATB do afetado está parado); quem tem o ATB cheio volta à fila.
	for c: Combatant in b.statuses.tick_time(b.all(), delta * speed_mult):
		stop_ended.emit(c)
		if c.atb >= 1.0 and not b.queue.has(c) and not _is_busy(c):
			b.queue.push(c, b.tick)
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
		a.turn_owner().atb = 0.0
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
	_discard_queued()
	battle_ended.emit(outcome)

## Quem está com a vez nas mãos (executando, em sessão ou com ação enfileirada) não entra na fila.
func _is_busy(c: Combatant) -> bool:
	if executing != null and executing.turn_owner() == c:
		return true
	if session != null and session.actor == c:
		return true
	return _queued != null and _queued.turn_owner() == c

## Pare e Silêncio aplicados no meio da batalha. Pare: o combatente sai da fila mantendo o ATB cheio (volta
## quando o Pare acaba), a sessão aberta é desfeita e a ação enfileirada é reembolsada. Silêncio: a técnica
## escolhida na sessão é desfeita e a enfileirada é reembolsada (o herói volta à fila para escolher de novo).
func _enforce_statuses() -> void:
	for c: Combatant in b.all():
		if c.is_stopped() and not c.is_down():
			b.queue.remove(c)
	if session != null and session.actor.is_stopped():
		_drop_session()
	if _queued != null and _queued.turn_owner().is_stopped():
		_discard_queued()
	if session != null and session.actor.is_silenced() and not _silence_notified:
		_silence_notified = true
		if session.ability != null and session.technique_blocked(session.ability):
			session.back()
		session_reset.emit(session)
	if _queued != null:
		var q: PendingAction = _queued
		var o: Combatant = q.turn_owner()
		if q.caller == null and q.item == null and not q.is_limit and q.ability != o.basic_attack and o.is_silenced():
			_queued = null
			_refund(q)
			if not o.is_down() and o.atb >= 1.0 and not b.queue.has(o):
				b.queue.push(o, b.tick)

func _start_next() -> void:
	# Com a sessão de um herói aberta (modo Ativo) só os inimigos seguem; os outros heróis esperam.
	var c: Combatant = _pop_next_enemy() if session != null else b.queue.pop_next()
	if c == null:
		return
	if c.is_confused():
		var ca: PendingAction = EnemyAI.confused_action(c, b)
		if ca == null:
			c.atb = 0.0
			turn_lost.emit(c)
			return
		confused_act.emit(c)
		_begin(ca)
		return
	if c.team == Combatant.Team.ENEMY:
		var a: PendingAction = EnemyAI.decide(c, b)
		if a == null:
			c.atb = 0.0
			return
		_begin(a)
	else:
		session = SelectionSession.new(c, b)
		_silence_notified = c.is_silenced()
		hero_turn.emit(session)

func _begin(a: PendingAction) -> void:
	if not _retarget(a):
		_lose(a)
		return
	a.elapsed = 0.0
	a.impacted = false
	if a.is_limit:
		a.actor.limit = 0.0
	elif a.caller != null:
		a.caller.limit = maxf(0.0, a.caller.limit - b.cfg.support_cost)
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
	if a.turn_owner().is_down():
		_refund(a)
		return
	_begin(a)

## Ação enfileirada que nunca vai começar (herói caiu, batalha acabou): devolve item ou AP.
func _discard_queued() -> void:
	if _queued == null:
		return
	var a: PendingAction = _queued
	_queued = null
	_refund(a)

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
	_refund(a)
	a.turn_owner().atb = 0.0
	turn_lost.emit(a.turn_owner())

func _refund(a: PendingAction) -> void:
	if a.is_limit:
		a.actor.limit = 1.0
	if a.item != null:
		b.inventory.refund(a.item.id)
	elif a.ability != null:
		a.actor.ap += a.ability.ap_cost
		if a.caller != null:
			# Suporte: o AP e do heroi da reserva e ja foi gravado no HeroState ao escolher. O Limite do
			# chamador so e gasto em _begin, entao uma acao que nunca comecou nao tem o que devolver.
			a.actor.hero_state.ap = a.actor.ap

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

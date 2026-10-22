class_name EventPlayer
extends Node

## Executa um EventScript sobre um LocalMap (M10): roda o EventRunner e apresenta cada request
## (fala e escolha na DialogueBox, MoveActor/CameraTo/Wait por tween e timer, StartBattle pela LocalMap).
## Durante o evento o mapa fica congelado (LocalMap.set_event_frozen: jogador e inimigos parados, sem saída
## nem interação) e o Game não abre o menu de campo.
##
## Uso: `await event_player.play(script, map, state)`. Um evento por vez (play durante outro é ignorado).
## [method cancel] encerra na hora (Game Over, troca de mapa) sem aplicar mais nada.

## `completed` é false se o evento foi cancelado ou abortado.
signal finished(completed: bool)
## Um EndDemoStep pediu a tela de fim (M12); o Game a mostra.
signal end_demo_requested
## Resposta interna de cada apresentação; carrega a "geração" para ignorar callbacks de eventos cancelados.
signal _step_done(answer: int)

const CANCELLED: int = -999

var dialogue: DialogueBox
var active: bool = false
var runner: EventRunner

var _map: LocalMap
var _state: GameState
var _gen: int = 0

func _init() -> void:
	dialogue = DialogueBox.new()
	add_child(dialogue)

## Executa o roteiro até o fim. Devolve (ao ser aguardado) quando o evento termina ou é cancelado.
func play(event: EventScript, map: LocalMap, state: GameState) -> void:
	if active or event == null or map == null or state == null:
		return
	active = true
	_map = map
	_state = state
	_gen += 1
	var gen: int = _gen
	map.set_event_frozen(true)
	runner = EventRunner.new(event, state)
	runner.start()
	while not runner.finished:
		var answer: int = await _present(runner.current(), gen)
		if gen != _gen:
			return
		runner.resume(answer)
	var completed: bool = not runner.aborted
	_finish(completed)

## Encerra o evento atual sem aplicar mais nada; seguro sem evento em andamento.
func cancel() -> void:
	if not active:
		return
	_gen += 1
	_drop_waiters()
	_step_done.emit(CANCELLED)
	if runner != null:
		runner.cancel()
	_finish(false)

## Solta as ligações de espera deixadas por uma apresentação cancelada (uma ligação velha não pode
## ser confundida com a do próximo evento).
func _drop_waiters() -> void:
	var sigs: Array[Signal] = [dialogue.advanced, dialogue.chosen]
	if is_instance_valid(_map):
		sigs.append(_map.event_battle_finished)
	for sig: Signal in sigs:
		for c: Dictionary in sig.get_connections():
			var callable: Callable = c["callable"]
			if callable.get_object() == self:
				sig.disconnect(callable)

func _finish(completed: bool) -> void:
	dialogue.close()
	active = false
	if is_instance_valid(_map):
		_map.set_event_frozen(false)
	_map = null
	finished.emit(completed)

func _cps() -> float:
	return DialogueBox.speed_for(_state.cfg, _state.settings.text_speed)

func _done(gen: int, answer: int) -> void:
	if gen == _gen:
		_step_done.emit(answer)

func _done_with(answer: int, gen: int) -> void:
	_done(gen, answer)

func _node(path: NodePath) -> Node2D:
	return _map.get_node_or_null(path) as Node2D

func _present(req: EventRequest, gen: int) -> int:
	match req.kind:
		EventRequest.Kind.SAY:
			dialogue.advanced.connect(_done.bind(gen, 0), CONNECT_ONE_SHOT)
			dialogue.say(req.speaker, req.text, _cps())
		EventRequest.Kind.CHOICE:
			dialogue.chosen.connect(_done_with.bind(gen), CONNECT_ONE_SHOT)
			dialogue.ask(req.text, req.options, _cps())
		EventRequest.Kind.MOVE_ACTOR:
			if not _move_actor(req, gen):
				return 0
		EventRequest.Kind.WAIT:
			if req.seconds <= 0.0:
				return 0
			get_tree().create_timer(req.seconds).timeout.connect(_done.bind(gen, 0))
		EventRequest.Kind.CAMERA_TO:
			var marker: Node2D = _node(req.marker)
			if marker == null:
				push_error("EventPlayer: marcador '%s' não existe" % req.marker)
				return 0
			var t: float = _state.cfg.event_camera_time
			_map.event_camera_to(marker.global_position, t)
			if t <= 0.0:
				return 0
			get_tree().create_timer(t).timeout.connect(_done.bind(gen, 0))
		EventRequest.Kind.END_DEMO:
			end_demo_requested.emit()
			return 0
		EventRequest.Kind.START_BATTLE:
			_map.event_battle_finished.connect(_done_with.bind(gen), CONNECT_ONE_SHOT)
			_map.start_event_battle(req.encounter)
	return await _step_done

## Liga o tween do ator ao marcador; false se não há o que esperar (ator/marcador ausente ou já no lugar).
func _move_actor(req: EventRequest, gen: int) -> bool:
	var actor: Node2D = _node(req.actor)
	var marker: Node2D = _node(req.marker)
	if actor == null or marker == null:
		push_error("EventPlayer: MoveActor sem ator '%s' ou marcador '%s'" % [req.actor, req.marker])
		return false
	var target: Vector2 = marker.global_position
	var speed: float = req.speed if req.speed > 0.0 else _state.cfg.event_actor_speed
	var duration: float = actor.global_position.distance_to(target) / speed
	if duration <= 0.0:
		actor.global_position = target
		return false
	var tween: Tween = actor.create_tween()
	tween.tween_property(actor, "global_position", target, duration)
	tween.finished.connect(_done.bind(gen, 0))
	return true

class_name EventRunner
extends RefCounted

## Percorre um EventScript (M10), puro: sem Node, Input ou IO.
## Passos de regra (flags, itens, XP, técnicas, cura) são aplicados direto no GameState.
## Passos de apresentação viram um EventRequest em [method current]; o runner espera [method resume].
## Um trecho sem nenhum passo de apresentação que passe de BalanceConfig.event_max_steps passos
## (laço infinito) aborta o evento com push_error.

var state: GameState
## O roteiro terminou (fim, Goto/IfFlag para fora, aborto ou cancelamento).
var finished: bool = false
## Terminou por erro (laço, Label desconhecido).
var aborted: bool = false

var _steps: Array[EventStep] = []
var _labels: Dictionary[StringName, int] = {}
var _pc: int = 0
var _queue: Array[EventRequest] = []
var _current: EventRequest
var _rule_steps: int = 0

func _init(event: EventScript, game_state: GameState) -> void:
	state = game_state
	if event != null:
		_steps = event.steps.duplicate()
	for i: int in _steps.size():
		var l: LabelStep = _steps[i] as LabelStep
		if l != null and l.label_name != &"" and not _labels.has(l.label_name):
			_labels[l.label_name] = i

## Executa até o primeiro passo de apresentação (ou o fim).
func start() -> void:
	_run()

## O request em espera; null quando o evento terminou.
func current() -> EventRequest:
	return _current

## Responde ao request atual (índice da opção num CHOICE; ignorado nos demais) e segue.
func resume(answer: int = 0) -> void:
	if finished or _current == null:
		return
	var req: EventRequest = _current
	_current = null
	if req.kind == EventRequest.Kind.CHOICE:
		_apply_choice(req, answer)
	_run()

## Encerra o evento sem aplicar mais nada (ex.: Game Over no meio).
func cancel() -> void:
	finished = true
	_current = null
	_queue.clear()

func _apply_choice(req: EventRequest, answer: int) -> void:
	var flag: StringName = req.flag
	if flag != &"" and not req.options.is_empty():
		state.set_flag(flag, clampi(answer, 0, req.options.size() - 1))

func _run() -> void:
	var max_steps: int = state.cfg.event_max_steps
	while _current == null and not finished:
		if not _queue.is_empty():
			_current = _queue.pop_front()
			_rule_steps = 0
			return
		if _pc >= _steps.size():
			finished = true
			return
		_rule_steps += 1
		if _rule_steps > max_steps:
			push_error("EventRunner: mais de %d passos sem apresentação (laço infinito?); evento abortado" % max_steps)
			_abort()
			return
		var step: EventStep = _steps[_pc]
		_pc += 1
		if step != null:
			_exec(step)
	if _current != null:
		_rule_steps = 0

func _abort() -> void:
	aborted = true
	cancel()

func _exec(step: EventStep) -> void:
	if step is SayStep:
		var s: SayStep = step
		_present(EventRequest.say(s.speaker, s.text))
	elif step is ChoiceStep:
		var c: ChoiceStep = step
		if c.options.is_empty():
			return
		var r := EventRequest.new()
		r.kind = EventRequest.Kind.CHOICE
		r.text = c.prompt
		r.options = c.options
		r.flag = c.flag
		_present(r)
	elif step is SetFlagStep:
		var sf: SetFlagStep = step
		state.set_flag(sf.flag, sf.value)
	elif step is AddFlagStep:
		var af: AddFlagStep = step
		state.add_flag(af.flag, af.delta)
	elif step is IfFlagStep:
		var f: IfFlagStep = step
		if not IfFlagStep.compare(state.get_flag(f.flag), f.op, f.value):
			_jump(f.else_label)
	elif step is GotoStep:
		_jump((step as GotoStep).label)
	elif step is GiveItemStep:
		var gi: GiveItemStep = step
		if gi.item != null and gi.count > 0:
			state.inventory.add(gi.item, gi.count)
	elif step is GiveEquipmentStep:
		var ge: GiveEquipmentStep = step
		if ge.equipment != null and ge.count > 0:
			state.bag.add(ge.equipment, ge.count)
	elif step is GiveMoneyStep:
		state.add_money((step as GiveMoneyStep).amount)
	elif step is RecruitStep:
		_recruit(step as RecruitStep)
	elif step is EndDemoStep:
		var re := EventRequest.new()
		re.kind = EventRequest.Kind.END_DEMO
		_present(re)
	elif step is TeachStep:
		_teach(step as TeachStep)
	elif step is GrantXpStep:
		_grant_xp(step as GrantXpStep)
	elif step is HealStep:
		_heal((step as HealStep).pct)
	elif step is MoveActorStep:
		var m: MoveActorStep = step
		var rm := EventRequest.new()
		rm.kind = EventRequest.Kind.MOVE_ACTOR
		rm.actor = m.actor
		rm.marker = m.to_marker
		rm.speed = m.speed
		_present(rm)
	elif step is WaitStep:
		var rw := EventRequest.new()
		rw.kind = EventRequest.Kind.WAIT
		rw.seconds = (step as WaitStep).seconds
		_present(rw)
	elif step is CameraToStep:
		var rc := EventRequest.new()
		rc.kind = EventRequest.Kind.CAMERA_TO
		rc.marker = (step as CameraToStep).marker
		_present(rc)
	elif step is StartBattleStep:
		var sb: StartBattleStep = step
		if sb.encounter != null:
			var rb := EventRequest.new()
			rb.kind = EventRequest.Kind.START_BATTLE
			rb.encounter = sb.encounter
			_present(rb)
	# LabelStep (e qualquer outro passo desconhecido) não faz nada.

## Apresentações se enfileiram em ordem (depois das linhas de sistema já geradas).
func _present(req: EventRequest) -> void:
	_queue.append(req)

## Salta para o Label; vazio termina o evento; desconhecido aborta.
func _jump(label: StringName) -> void:
	if label == &"":
		finished = true
		return
	if not _labels.has(label):
		push_error("EventRunner: Label '%s' não existe; evento abortado" % label)
		_abort()
		return
	_pc = _labels[label]

func _system(text: String) -> void:
	_queue.append(EventRequest.say("", text))

func _recruit(r: RecruitStep) -> void:
	var lv: int = maxi(1, r.level) if r.level_mode == RecruitStep.LevelMode.FIXED else 0
	var h: HeroState = state.recruit(r.hero, lv)
	if h != null:
		_system("%s entrou no grupo!" % h.def.display_name)

func _teach(t: TeachStep) -> void:
	for h: HeroState in state.roster():
		if h.def.id != t.hero_id:
			continue
		if h.learn(t.ability_id):
			_system("%s aprendeu %s!" % [h.def.display_name, _ability_name(h, t.ability_id)])
		return

func _ability_name(h: HeroState, id: StringName) -> String:
	for a: AbilityDef in h.abilities():
		if a.id == id:
			return a.display_name
	return String(id)

## Quem recebe a XP narrativa (§5.6): regra e, sem `include_downed`, só quem está em pé.
func xp_targets(step: GrantXpStep) -> Array[HeroState]:
	var out: Array[HeroState] = []
	var pool: Array[HeroState] = state.heroes if step.rule == GrantXpStep.Rule.ACTIVE else state.roster()
	for h: HeroState in pool:
		if step.rule == GrantXpStep.Rule.LIST and not step.heroes.has(h.def.id):
			continue
		if h.hp <= 0 and not step.include_downed:
			continue
		out.append(h)
	return out

func _grant_xp(step: GrantXpStep) -> void:
	if step.amount <= 0:
		return
	for h: HeroState in xp_targets(step):
		var gained: int = XpCalculator.grant(h, step.amount, state.cfg)
		if gained > 0:
			_system("%s subiu para o Nv %d!" % [h.def.display_name, h.level])
		for a: AbilityDef in h.last_learned:
			_system("%s aprendeu %s!" % [h.def.display_name, a.display_name])

func _heal(pct: float) -> void:
	for h: HeroState in state.heroes:
		if h.hp <= 0:
			continue
		var hp_max: int = StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), state.cfg)
		h.hp = mini(hp_max, h.hp + ceili(float(hp_max) * clampf(pct, 0.0, 1.0)))

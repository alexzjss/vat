class_name TechniquePage
extends FieldPage

## Técnicas: usuário (ativos de pé com técnica de campo) → técnica "Nome — N AP" (cinza sem AP)
## → alvo no painel (SINGLE) ou uso direto (GROUP/ALL, sobre os ativos).

enum Step { USER, TECH, TARGET }

var step: Step = Step.USER
var user: HeroState = null
var _users: Array[HeroState] = []
var _techs: Array[AbilityDef] = []
var _user_cursor: int = 0

func enter() -> void:
	super.enter()
	user = null
	_user_cursor = 0
	_show_users()

func leave() -> void:
	step = Step.USER
	super.leave()

func move(delta: int) -> void:
	if step == Step.TARGET:
		menu.party_panel.pick_move(delta)
	else:
		super.move(delta)

func accept() -> void:
	match step:
		Step.USER:
			if cursor < _users.size():
				user = _users[cursor]
				_user_cursor = cursor
				cursor = 0
				_show_techs()
		Step.TECH:
			_choose_tech()
		Step.TARGET:
			_use_on_picked()

func cancel() -> bool:
	match step:
		Step.TARGET:
			menu.party_panel.end_pick()
			_say("")
			_show_techs()
			return true
		Step.TECH:
			cursor = _user_cursor
			_say("")
			_show_users()
			return true
	return false

func _choose_tech() -> void:
	if cursor >= _techs.size():
		return
	var ab: AbilityDef = _techs[cursor]
	if not _cursor_ok():
		_say("AP insuficiente.")
		return
	var cfg: BalanceConfig = state.cfg
	if ab.shape == AbilityDef.Shape.GROUP or ab.shape == AbilityDef.Shape.ALL:
		if FieldActions.use_technique(state, user, ab, null):
			_say("%s usou %s." % [_hero_name(user), ab.display_name])
			menu.refresh_party()
		else:
			_say("Ninguém precisa disso.")
		_show_techs()
		return
	var u: HeroState = user
	var filter: Callable = func(h: HeroState) -> bool: return FieldActions.can_use_technique(u, ab, h, cfg, state)
	if not state.roster().any(filter):
		_say("Ninguém precisa disso.")
		return
	step = Step.TARGET
	menu.party_panel.begin_pick(filter)
	_say("Usar %s em quem?" % ab.display_name)
	_render_list(false)

func _use_on_picked() -> void:
	var h: HeroState = menu.party_panel.picked()
	if h == null:
		return
	var ab: AbilityDef = _techs[cursor]
	if FieldActions.use_technique(state, user, ab, h):
		_say("%s usou %s em %s." % [_hero_name(user), ab.display_name, _hero_name(h)])
	else:
		_say("Ninguém precisa disso.")
	menu.party_panel.end_pick()
	menu.refresh_party()
	_show_techs()

func _show_users() -> void:
	step = Step.USER
	_users = []
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for h: HeroState in state.heroes:
		if h.hp > 0 and not FieldActions.field_techniques(h).is_empty():
			_users.append(h)
			texts.append(_hero_name(h))
			enabled.append(true)
	_set_entries(texts, enabled)
	if _users.is_empty():
		_say("Ninguém pode usar técnicas.")

func _show_techs() -> void:
	step = Step.TECH
	_techs = FieldActions.field_techniques(user)
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for ab: AbilityDef in _techs:
		var tech_text: String = "%s — %d AP" % [ab.display_name, ab.ap_cost]
		if ab.element != null:
			tech_text += " · " + ElementText.tag(ab.element)
		texts.append(tech_text)
		enabled.append(user.hp > 0 and user.ap >= ab.ap_cost)
	var nxt: LearnEntry = user.next_learn()
	if nxt != null:
		texts.append("Próxima: Nv %d" % nxt.level)
		enabled.append(false)
	_set_entries(texts, enabled)

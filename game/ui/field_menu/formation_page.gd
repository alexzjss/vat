class_name FormationPage
extends FieldPage

## Formação: roster numa lista ("Ativo N" / "Reserva", "Líder" no líder). Troca estilo FF:
## escolher um herói, depois outro → swap. Com um herói escolhido, a última linha é a ação extra
## "Para reserva" / "Para o grupo". Recusas mostram um aviso curto.

var selected: HeroState = null
var _roster: Array[HeroState] = []

func enter() -> void:
	super.enter()
	selected = null
	_rebuild()

func leave() -> void:
	selected = null
	super.leave()

func accept() -> void:
	if cursor < _roster.size():
		var h: HeroState = _roster[cursor]
		if selected == null:
			selected = h
			_say("Trocar %s com quem?" % _hero_name(h))
		elif selected == h:
			selected = null
			_say("")
		else:
			state.swap(selected, h)
			_say("%s e %s trocaram de lugar." % [_hero_name(selected), _hero_name(h)])
			_done()
			return
		_rebuild()
	elif selected != null:
		_extra_action()

func cancel() -> bool:
	if selected == null:
		return false
	selected = null
	_say("")
	_rebuild()
	return true

func _extra_action() -> void:
	var h: HeroState = selected
	if state.heroes.has(h):
		if state.to_reserve(h):
			_say("%s foi para a reserva." % _hero_name(h))
		else:
			_say("O grupo precisa de pelo menos 1 herói")
	else:
		if state.to_active(h):
			_say("%s entrou no grupo." % _hero_name(h))
		else:
			_say("Grupo cheio")
	_done()

func _done() -> void:
	var keep: HeroState = selected
	selected = null
	_rebuild()
	cursor = maxi(0, _roster.find(keep))
	_render_list()
	menu.refresh_party()

func _rebuild() -> void:
	_roster = state.roster()
	var leader: HeroState = state.leader()
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for i: int in _roster.size():
		var h: HeroState = _roster[i]
		var t: String = _hero_name(h) + " — "
		if i < state.heroes.size():
			t += "Ativo %d" % (i + 1)
			if h == leader:
				t += " · Líder"
		else:
			t += "Reserva"
		if h == selected:
			t = "* " + t
		texts.append(t)
		enabled.append(true)
	if selected != null:
		texts.append("Para reserva" if state.heroes.has(selected) else "Para o grupo")
		enabled.append(true)
	_set_entries(texts, enabled)

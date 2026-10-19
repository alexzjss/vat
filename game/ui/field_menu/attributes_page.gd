class_name AttributesPage
extends FieldPage

## Atributos: escolher no painel um herói com pontos pendentes → LevelUpScreen própria do menu.
## Ao fechar a tela, o painel atualiza; sem mais ninguém com pontos, volta à raiz.

var screen: LevelUpScreen

func _init() -> void:
	super._init()
	screen = LevelUpScreen.new()
	# O teclado chega pelo roteamento do FieldMenu (handle_input), não pela própria tela.
	screen.set_process_unhandled_input(false)
	add_child(screen)
	move_child(screen, 0)
	screen.closed.connect(_on_screen_closed)

func enter() -> void:
	super.enter()
	_begin()

func leave() -> void:
	if screen.visible:
		screen.leave()
	super.leave()

func move(delta: int) -> void:
	if screen.visible:
		screen.move(delta)
	else:
		menu.party_panel.pick_move(delta)

func adjust(delta: int) -> void:
	if screen.visible:
		screen.adjust(delta)

func accept() -> void:
	if screen.visible:
		screen.accept()
		return
	var h: HeroState = menu.party_panel.picked()
	if h == null:
		return
	menu.party_panel.end_pick()
	_say("")
	screen.open(h)

func cancel() -> bool:
	if screen.visible:
		screen.leave()
		return true
	return false

static func anyone_pending(s: GameState) -> bool:
	return s.roster().any(func(h: HeroState) -> bool: return h.pending_points > 0)

func _begin() -> void:
	menu.party_panel.begin_pick(func(h: HeroState) -> bool: return h.pending_points > 0)
	_say("Escolha quem vai distribuir pontos.")

func _on_screen_closed(_h: HeroState) -> void:
	menu.refresh_party()
	if not menu.is_open or menu.page != &"attributes":
		return
	if anyone_pending(state):
		_begin()
	else:
		menu.return_to_root()

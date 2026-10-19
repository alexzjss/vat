class_name DemoFieldMenu
extends Node

## Roteiro de debug (`-- --demo-field-menu`): deixa um herói caído, pontos pendentes e a reserva ferida,
## abre o menu de campo do Game e percorre as páginas (1,5 s por tela) para verificação com --write-movie.

func _ready() -> void:
	var game: Game = get_parent() as Game
	if game == null:
		push_error("DemoFieldMenu: precisa ser filho do Game")
		queue_free()
		return
	_run.call_deferred(game)

func _run(game: Game) -> void:
	var state: GameState = game.state
	state.heroes[1].hp = 0
	state.heroes[2].pending_points = 2
	state.reserve[0].hp = maxi(1, state.reserve[0].hp / 2)
	while not game.open_menu():
		await get_tree().process_frame
	var menu: FieldMenu = game.menu
	# Raiz → Itens com alvo → Status → Formação com um herói escolhido.
	await get_tree().create_timer(1.5, true).timeout
	menu.cursor = 0
	menu.accept()
	menu.item_page.accept()
	await get_tree().create_timer(1.5, true).timeout
	menu.cancel()
	menu.cancel()
	menu.cursor = 2
	menu.accept()
	menu.status_page.move(2)
	menu.status_page.accept()
	await get_tree().create_timer(1.5, true).timeout
	menu.cancel()
	menu.cancel()
	menu.cursor = 4
	menu.accept()
	menu.formation_page.accept()
	menu.formation_page.move(4)

class_name DemoM3
extends Node

## Roteiro de debug (`-- --demo-m3`): percorre o M3 sozinho, para verificação visual com --write-movie.
## Fere dois heróis, abre o menu de campo no mapa-múndi, usa Poção, usa Cura, abre Status, troca D↔E
## na Formação e fecha; depois entrega o resto ao DemoM2 (entra na área, encosta no inimigo, batalha
## com a nova formação e inimigos enfraquecidos, vence, volta ao mapa-múndi e termina).

## Tempo de cada tela do menu.
const SCREEN_TIME: float = 1.2

var game: Game

func _ready() -> void:
	game = get_parent() as Game
	if game == null:
		push_error("DemoM3: precisa ser filho do Game")
		queue_free()
		return
	_run.call_deferred()

func _wait() -> void:
	await get_tree().create_timer(SCREEN_TIME, true).timeout

func _run() -> void:
	var state: GameState = game.state
	for i: int in [0, 2]:
		state.heroes[i].hp = maxi(1, state.heroes[i].hp / 3)
	await _wait()
	while not game.open_menu():
		await get_tree().process_frame
	var menu: FieldMenu = game.menu
	print("DemoM3: menu aberto")
	await _wait()
	# Itens → Poção → primeiro herói ferido.
	menu.cursor = 0
	menu.accept()
	menu.item_page.accept()
	await _wait()
	menu.item_page.accept()
	print("DemoM3: %s" % menu.item_page.message())
	await _wait()
	menu.cancel()
	# Técnicas → primeiro usuário → Cura → primeiro herói ferido.
	menu.cursor = 1
	menu.accept()
	menu.technique_page.accept()
	menu.technique_page.accept()
	await _wait()
	menu.technique_page.accept()
	print("DemoM3: %s" % menu.technique_page.message())
	await _wait()
	menu.cancel()
	menu.cancel()
	# Status do líder.
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"status")
	menu.accept()
	menu.status_page.accept()
	await _wait()
	menu.cancel()
	menu.cancel()
	# Formação: D (Ativo 4) ↔ E (Reserva).
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"formation")
	menu.accept()
	menu.formation_page.cursor = 3
	menu.formation_page.accept()
	menu.formation_page.move(1)
	await _wait()
	menu.formation_page.accept()
	print("DemoM3: %s" % menu.formation_page.message())
	await _wait()
	menu.cancel()
	menu.cancel()
	print("DemoM3: menu fechado; grupo = %s" % ", ".join(state.heroes.map(
			func(h: HeroState) -> String: return h.def.display_name)))
	var walk := DemoM2.new()
	walk.name = "DemoM2"
	game.add_child(walk)
	queue_free()

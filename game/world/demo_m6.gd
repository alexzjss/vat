class_name DemoM6
extends Node

## Roteiro de debug (`-- --demo-m6`): percorre o M6 sozinho, para verificação visual com --write-movie.
## Entra na área de teste, anda até o ponto de descanso, descansa e salva (no diretório de saves de demo,
## nunca nos slots reais), reinicia os atributos do Teste A com o Cristal e mostra a página Salvar do menu.

## Tempo de cada tela.
const SCREEN_TIME: float = 1.2
## Raio para considerar o ponto de descanso alcançado.
const ARRIVE_DIST: float = 6.0

var game: Game

func _ready() -> void:
	game = get_parent() as Game
	if game == null:
		push_error("DemoM6: precisa ser filho do Game")
		queue_free()
		return
	_run.call_deferred()

func _wait(t: float = SCREEN_TIME) -> void:
	await get_tree().create_timer(t, true).timeout

func _log(text: String) -> void:
	print("DemoM6 [quadro %d]: %s" % [Engine.get_process_frames(), text])

func _run() -> void:
	await _wait(0.5)
	game.go_to(&"area_teste", &"Entry")
	while game.busy or not game.current is LocalMap:
		await get_tree().process_frame
	var map: LocalMap = game.current as LocalMap
	var state: GameState = game.state
	# Heróis feridos e com atributos distribuídos, para o descanso e o reinício terem o que mostrar.
	for h: HeroState in state.roster():
		h.hp = maxi(1, h.hp / 4)
		h.ap = 0
	var hero: HeroState = state.heroes[0]
	hero.allocated = Stats.make(2, 1, 1, 0)
	_log("na área, indo ao ponto de descanso")
	await _walk_to(map, map.rest_point.global_position)
	await _wait(0.6)
	_log("dentro do ponto: %s" % map.rest_point.player_inside)
	map.rest_point.request()
	_log("menu de descanso aberto")
	await _wait()
	game.rest_menu.accept()
	_log("descansou; escolhendo o slot (HP do líder %d)" % hero.hp)
	await _wait()
	game.rest_menu.accept()
	_log("salvou no slot 1: %s" % game.store.summary(1))
	await _wait()
	game.rest_menu.cancel()
	game.rest_menu.move(1)
	await _wait(0.6)
	game.rest_menu.accept()
	_log("escolhendo o herói para reiniciar")
	await _wait()
	game.rest_menu.accept()
	_log("%s reiniciado: pontos a distribuir %d" % [hero.def.display_name, hero.pending_points])
	await _wait()
	game.rest_menu.close()
	await _wait(0.4)
	while not game.open_menu():
		await get_tree().process_frame
	game.menu.cursor = FieldMenu.SAVE_INDEX
	game.menu.accept()
	_log("página Salvar do menu de campo")
	await _wait()
	game.menu.close()
	_log("ciclo concluído")

## Anda em linha reta (override_dir) até `target`.
func _walk_to(map: LocalMap, target: Vector2) -> void:
	var player: Player = map.player
	while player.global_position.distance_to(target) > ARRIVE_DIST:
		player.override_dir = (target - player.global_position).normalized()
		await get_tree().physics_frame
	player.override_dir = Vector2.ZERO

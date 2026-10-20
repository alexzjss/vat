class_name DemoM7
extends Node

## Roteiro de debug (`-- --demo-m7`): percorre o M7 sozinho, para verificação visual com --write-movie.
## Corre com o grupo em fila, toca o patrulheiro pelas costas (Ataque surpresa), foge segurando a tecla de fuga,
## depois toca o chefe e mostra "Não dá para fugir!".

const SCREEN_TIME: float = 1.0
const ARRIVE_DIST: float = 8.0
## Limite de quadros de física de cada espera (evita travar o roteiro).
const MAX_FRAMES: int = 1800

var game: Game

func _ready() -> void:
	game = get_parent() as Game
	if game == null:
		push_error("DemoM7: precisa ser filho do Game")
		queue_free()
		return
	_run.call_deferred()

func _wait(t: float = SCREEN_TIME) -> void:
	await get_tree().create_timer(t, true).timeout

func _log(text: String) -> void:
	print("DemoM7 [quadro %d]: %s" % [Engine.get_process_frames(), text])

func _run() -> void:
	await _wait(0.5)
	game.go_to(&"area_teste", &"Entry")
	while game.busy or not game.current is LocalMap:
		await get_tree().process_frame
	var map: LocalMap = game.current as LocalMap
	var player: Player = map.player
	_log("na área; correndo com o grupo em fila")
	player.override_run = 1
	await _walk_to(map, Vector2(900, 400))
	await _walk_to(map, Vector2(1140, 420))
	await _walk_to(map, Vector2(1180, 110))
	var patroller: MapEnemy = map.get_node("Patroller") as MapEnemy
	var guard: int = 0
	# Espera o patrulheiro sair do ponto da esquerda rumo à direita: o jogador chega por trás.
	while not (patroller.facing.x > 0.5 and patroller.global_position.x < 1340.0) and guard < MAX_FRAMES:
		guard += 1
		await get_tree().physics_frame
	_log("seguindo o patrulheiro por trás (frente %s)" % patroller.facing)
	guard = 0
	while map.battle == null and guard < MAX_FRAMES:
		guard += 1
		var target: Vector2 = patroller.global_position - patroller.facing * 24.0
		player.override_dir = (target - player.global_position).normalized()
		await get_tree().physics_frame
	player.override_dir = Vector2.ZERO
	player.override_run = 0
	if map.battle == null:
		_log("FALHA: a batalha não começou")
		return
	_log("batalha: faixa '%s'" % map.battle.banner_text_shown())
	await _wait(1.0)
	_log("segurando a tecla de fuga")
	var battle: BattleScene = map.battle
	battle.flee_input_override = 1
	guard = 0
	while is_instance_valid(battle) and not battle.is_queued_for_deletion() and guard < MAX_FRAMES:
		guard += 1
		await get_tree().process_frame
	_log("fuga concluída: batalha encerrada=%s, patrulheiro em recarga=%s" % [map.battle == null, patroller.in_cooldown()])
	player.override_run = 1
	# Contorna o patrulheiro (que o jogador empurraria) e segue pela faixa livre até o chefe.
	await _walk_to(map, player.global_position + Vector2(0, 100))
	await _walk_to(map, Vector2(2100, 200))
	var boss: MapEnemy = map.get_node("Boss") as MapEnemy
	_log("indo ao chefe")
	guard = 0
	while map.battle == null and guard < MAX_FRAMES:
		guard += 1
		player.override_dir = (boss.global_position - player.global_position).normalized()
		await get_tree().physics_frame
	player.override_dir = Vector2.ZERO
	player.override_run = 0
	if map.battle == null:
		_log("FALHA: a batalha do chefe não começou")
		return
	await _wait(1.0)
	map.battle.flee_input_override = 1
	await _wait(0.6)
	_log("chefe: mensagem '%s'" % map.battle.flee_message())
	await _wait(1.2)
	_log("ciclo concluído")

## Anda em linha reta (override_dir) até `target`.
func _walk_to(map: LocalMap, target: Vector2) -> void:
	var player: Player = map.player
	var guard: int = 0
	while player.global_position.distance_to(target) > ARRIVE_DIST and guard < MAX_FRAMES and map.battle == null:
		guard += 1
		player.override_dir = (target - player.global_position).normalized()
		await get_tree().physics_frame
	player.override_dir = Vector2.ZERO

class_name DemoM10
extends Node

## Roteiro de debug (`-- --demo-m10`): percorre a dungeon de teste do M10 sozinho, para verificacao visual com --write-movie.
## Le a placa, fala com o NPC (escolhe "Sim"), abre os dois baus, abre a porta com a chave, aciona o interruptor,
## pisa nas armadilhas (dano e batalha) e assiste a cena final.

## Limite de quadros de cada espera (evita travar o roteiro).
const MAX_FRAMES: int = 6000

var game: Game
var map: LocalMap

func _ready() -> void:
	game = get_parent() as Game
	if game == null:
		push_error("DemoM10: precisa ser filho do Game")
		queue_free()
		return
	_run.call_deferred()

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout

func _log(text: String) -> void:
	print("DemoM10 [quadro %d]: %s" % [Engine.get_process_frames(), text])

## Leva o jogador (e a camera) a `pos`.
func _put(pos: Vector2) -> void:
	map.player.global_position = pos
	map.camera.global_position = pos
	await _wait(0.4)

## Interage com o objeto ao alcance e passa todas as falas (escolha: primeira opcao).
func _talk(what: String) -> void:
	_log(what)
	if not map.try_interact():
		_log("FALHA: nada para interagir em '%s'" % what)
		return
	await _finish_event()

func _finish_event() -> void:
	var guard: int = 0
	await _wait(0.5)
	while game.event_player.active and guard < MAX_FRAMES:
		guard += 1
		var box: DialogueBox = game.event_player.dialogue
		if box.is_open:
			box.accept()
			await _wait(0.5)
			if box.is_open and box.options.is_empty() and not box.is_revealing():
				box.accept()
				await _wait(0.3)
		else:
			await get_tree().process_frame

func _run() -> void:
	await _wait(0.5)
	game.go_to(&"dungeon_teste", &"Entry")
	while game.busy or not game.current is LocalMap:
		await get_tree().process_frame
	map = game.current as LocalMap
	map.auto_battle = true
	map.demo_result = true
	await _wait(1.0)
	await _put(Vector2(330, 330))
	await _talk("placa")
	await _put(Vector2(520, 320))
	await _talk("NPC (Sim)")
	var hero: HeroState = game.state.heroes[0]
	_log("%s aprendeu rajada: %s" % [hero.def.display_name, hero.learned.has(&"rajada")])
	await _put(Vector2(620, 140))
	await _talk("bau da pocao")
	await _put(Vector2(620, 600))
	await _talk("bau da chave")
	await _put(Vector2(690, 360))
	await _talk("porta")
	await _put(Vector2(790, 360))
	await _put(Vector2(1000, 270))
	await _put(Vector2(1000, 360))
	_log("armadilha de dano; HP do lider: %d" % hero.hp)
	await _finish_event()
	await _put(Vector2(1250, 130))
	await _talk("interruptor")
	await _put(Vector2(1450, 360))
	await _put(Vector2(1580, 360))
	await _put(Vector2(1650, 360))
	_log("armadilha de batalha")
	await _finish_event()
	await _put(Vector2(1800, 360))
	await _put(Vector2(1880, 360))
	_log("cena final")
	await _finish_event()
	await _wait(1.0)
	_log("ciclo concluido; flags: %s" % [game.state.flags])

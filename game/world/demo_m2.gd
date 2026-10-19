class_name DemoM2
extends Node

## Roteiro de debug (`-- --demo-m2`): percorre o ciclo do M2 sozinho, para verificação visual
## com --write-movie. Mapa-múndi (Start → Área de teste) → área local (até o inimigo) →
## batalha no mapa com auto_battle e inimigos enfraquecidos (telas aceitas pelo roteiro da batalha) →
## saída → mapa-múndi. Dirige `Player.override_dir` por waypoints fixos dos mapas de teste,
## reavaliado a cada quadro de física; espera `Game.busy` (transições) e a batalha terminarem.

enum Step { TO_AREA, TO_ENEMY, IN_BATTLE, TO_EXIT, BACK_HOME, DONE }

## Raio para considerar um waypoint alcançado.
const ARRIVE_DIST: float = 8.0
## Mapa-múndi: entre a Água1 e a Montanha3, depois sobe para dentro da zona AreaTeste.
const OVERWORLD_PATH: Array[Vector2] = [Vector2(300, 600), Vector2(1900, 600), Vector2(1900, 500)]
## Área local: y = 400 passa abaixo do Obstáculo3 e acima do Obstáculo2; depois persegue o inimigo.
const LOCAL_TO_ENEMY_PATH: Array[Vector2] = [Vector2(180, 400), Vector2(1700, 400)]
## Do ponto do líder na arena até a saída, pelo mesmo corredor.
const LOCAL_TO_EXIT_PATH: Array[Vector2] = [Vector2(1440, 400), Vector2(60, 400)]
## De volta ao mapa-múndi: alguns passos para longe do local, depois para.
const HOME_PATH: Array[Vector2] = [Vector2(1700, 680)]
## HP dos inimigos do encontro no demo (ver _weaken_enemies).
const DEMO_ENEMY_HP: int = 2

var game: Game
var step: Step = Step.TO_AREA

var _map: Node2D
var _path: Array[Vector2] = []
var _index: int = 0
var _elapsed: float = 0.0

func _ready() -> void:
	game = get_parent() as Game
	if game == null:
		push_error("DemoM2: precisa ser filho do Game")
		queue_free()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if game == null or game.busy or game.current == null or step == Step.DONE:
		return
	if game.current != _map:
		_on_map_changed(game.current)
	var player: Player = _player()
	if player == null:
		return
	match step:
		Step.TO_AREA, Step.BACK_HOME:
			player.override_dir = _follow(player)
			if step == Step.BACK_HOME and _index >= _path.size():
				player.override_dir = Vector2.INF
				step = Step.DONE
				print("DemoM2: ciclo concluído em %.1f s" % _elapsed)
		Step.TO_ENEMY:
			var local: LocalMap = _map as LocalMap
			if local.battle != null:
				player.override_dir = Vector2.ZERO
				_weaken_enemies(local.battle)
				step = Step.IN_BATTLE
				print("DemoM2: batalha iniciada (%.1f s)" % _elapsed)
				return
			var dir: Vector2 = _follow(player)
			if _index >= _path.size():
				var targets: Array[MapEnemy] = local.enemies()
				dir = player.global_position.direction_to(targets[0].global_position) if not targets.is_empty() else Vector2.ZERO
			player.override_dir = dir
		Step.IN_BATTLE:
			var local: LocalMap = _map as LocalMap
			if local.battle == null and player.enabled:
				print("DemoM2: batalha terminada (%.1f s)" % _elapsed)
				_set_path(LOCAL_TO_EXIT_PATH)
				step = Step.TO_EXIT
		Step.TO_EXIT:
			player.override_dir = _follow(player)

## Novo mapa depois de uma transição: escolhe o trecho do roteiro conforme o tipo do mapa.
func _on_map_changed(map: Node2D) -> void:
	_map = map
	var local: LocalMap = map as LocalMap
	if local != null:
		local.auto_battle = true
		local.demo_result = true
		_set_path(LOCAL_TO_ENEMY_PATH)
		step = Step.TO_ENEMY
		print("DemoM2: área local (%.1f s)" % _elapsed)
	elif step == Step.TO_AREA:
		_set_path(OVERWORLD_PATH)
	else:
		# Volta da área (ou Game Over): passos finais no mapa-múndi.
		_set_path(HOME_PATH)
		step = Step.BACK_HOME
		print("DemoM2: de volta ao mapa-múndi (%.1f s)" % _elapsed)

## Só debug: no encontro X + Y, o Inimigo Y cura o X e o auto_battle (ataque básico, ~2 de dano)
## não vence nem com 1/4 do HP (demo_result); com DEMO_ENEMY_HP o roteiro chega à vitória e às telas.
func _weaken_enemies(battle: BattleScene) -> void:
	if battle.ctrl == null:
		return
	for e: Combatant in battle.ctrl.b.enemies:
		e.hp = mini(e.hp, DEMO_ENEMY_HP)

func _player() -> Player:
	var world: Overworld = _map as Overworld
	if world != null:
		return world.player
	var local: LocalMap = _map as LocalMap
	if local != null:
		return local.player
	return null

func _set_path(path: Array[Vector2]) -> void:
	_path = path
	_index = 0

## Direção para o waypoint atual (avança os alcançados); ZERO no fim do caminho.
func _follow(player: Player) -> Vector2:
	while _index < _path.size() and player.global_position.distance_to(_path[_index]) <= ARRIVE_DIST:
		_index += 1
	if _index >= _path.size():
		return Vector2.ZERO
	return player.global_position.direction_to(_path[_index])

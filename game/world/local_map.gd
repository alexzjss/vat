class_name LocalMap
extends Node2D

## Área local: jogador, inimigos de mapa, saída e encontro com batalha no próprio mapa.
## Ao tocar um inimigo, a BattleScene (modo MAP) roda sobre o mapa nas posições da arena.
## Debug: `-- --demo-local` roda a cena sozinha com auto_battle e leva o jogador até o inimigo
## (verificação visual com --write-movie).

signal exit_requested
signal game_over

const BATTLE_SCENE: PackedScene = preload("res://battle/battle_scene.tscn")
const MAP_RECT: Rect2 = Rect2(0, 0, 2400, 720)

## Batalha em andamento (null fora de batalha).
var battle: BattleScene
## Repassado à batalha (testes/demo).
var auto_battle: bool = false
## Repassado à batalha: inimigos enfraquecidos e telas roteirizadas (só debug, `--demo-m2`).
var demo_result: bool = false
## Semente do Dice da batalha; -1 = derivada de state.dice.
var dice_seed: int = -1
## Bloqueia encontros e saída (ex.: depois do Game Over, até o Game trocar de cena).
var locked: bool = false

var state: GameState
var _battle_enemy: MapEnemy

@onready var player: Player = $Player
@onready var camera: MapCamera = $MapCamera
@onready var exit_zone: Zone = $Exit
@onready var default_arena: BattleArena = $Arena

func _ready() -> void:
	exit_zone.entered.connect(_on_exit_entered)
	for e: MapEnemy in enemies():
		e.touched.connect(_on_enemy_touched)
	if OS.get_cmdline_user_args().has("--demo-local") and get_parent() == get_tree().root:
		_run_demo.call_deferred()

## Posiciona o jogador no marcador `spawn`, liga a câmera e configura os inimigos.
func setup(game_state: GameState, spawn: StringName) -> void:
	state = game_state
	player.cfg = state.cfg
	var marker: Node2D = get_node_or_null(NodePath(String(spawn))) as Node2D
	if marker == null:
		push_error("LocalMap: marcador '%s' não existe" % spawn)
	else:
		player.global_position = marker.global_position
	camera.follow = player
	camera.set_bounds(MAP_RECT)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	for e: MapEnemy in enemies():
		e.setup(state.cfg, state.dice)

func enemies() -> Array[MapEnemy]:
	var out: Array[MapEnemy] = []
	for child: Node in get_children():
		var e: MapEnemy = child as MapEnemy
		if e != null and not e.is_queued_for_deletion():
			out.append(e)
	return out

func _arena_for(enemy: MapEnemy) -> BattleArena:
	var a: BattleArena = enemy.arena()
	return a if a != null else default_arena

func _on_enemy_touched(enemy: MapEnemy) -> void:
	if battle != null or locked or state == null:
		return
	if enemy.encounter == null:
		push_error("LocalMap: inimigo '%s' sem encontro" % enemy.name)
		return
	_battle_enemy = enemy
	var arena: BattleArena = _arena_for(enemy)
	player.enabled = false
	for e: MapEnemy in enemies():
		e.frozen = true
	exit_zone.armed = false
	camera.slide_to(arena.center(), state.cfg.camera_slide_time)
	var from_pos: Vector2 = player.global_position
	player.visible = false
	enemy.visible = false
	var defs: Array[EnemyDef] = enemy.encounter.enemies
	battle = BATTLE_SCENE.instantiate() as BattleScene
	battle.balance = state.cfg
	battle.auto_battle = auto_battle
	battle.demo_result = demo_result
	battle.dice_seed = dice_seed if dice_seed >= 0 else state.dice.pick_index(1 << 30)
	battle.settings = state.settings
	battle.mode = BattleScene.Mode.MAP
	battle.position = Vector2.ZERO
	battle.finished.connect(_on_battle_finished)
	add_child(battle)
	# Síncrono logo após add_child: o _auto_start adiado da cena só é pulado se ctrl já existir.
	battle.start_with(state.heroes, defs, arena.hero_positions().slice(0, state.heroes.size()), arena.enemy_positions(defs.size()),
			state.inventory, from_pos)

func _on_battle_finished(outcome: BattleController.Outcome) -> void:
	var arena: BattleArena = _arena_for(_battle_enemy) if is_instance_valid(_battle_enemy) else default_arena
	battle.queue_free()
	battle = null
	if outcome != BattleController.Outcome.VICTORY:
		locked = true
		game_over.emit()
		return
	if is_instance_valid(_battle_enemy):
		_battle_enemy.queue_free()
	_battle_enemy = null
	player.global_position = arena.hero_positions()[0]
	player.visible = true
	player.enabled = true
	for e: MapEnemy in enemies():
		e.frozen = false
	exit_zone.armed = true
	camera.resume_follow(state.cfg.camera_slide_time)
	# Toques ignorados durante a batalha desarmaram os outros inimigos; rearma por último
	# (se um deles ainda encosta no líder, o novo encontro começa agora, com o mapa já restaurado).
	for e: MapEnemy in enemies():
		e.rearm()

func _on_exit_entered(_zone_id: StringName) -> void:
	if battle != null or locked:
		return
	exit_requested.emit()

# --- Roteiro de debug (--demo-local) ------------------------------------------------

func _run_demo() -> void:
	var defs: Array[CharacterDef] = []
	for id: String in ["teste_a", "teste_b", "teste_c"]:
		defs.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	var cfg: BalanceConfig = load("res://data/test/balance.tres") as BalanceConfig
	auto_battle = true
	setup(GameState.new_game(cfg, defs, items, counts, Dice.new(7), &"local", &"Entry"), &"Entry")
	# Leva o jogador para perto do inimigo e encosta nele.
	var enemy: MapEnemy = enemies()[0]
	enemy.frozen = true
	player.global_position = enemy.global_position + Vector2(-120, 0)
	camera.global_position = player.global_position
	player.override_dir = Vector2.RIGHT
	while battle == null:
		await get_tree().physics_frame
	player.override_dir = Vector2.ZERO

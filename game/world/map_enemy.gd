class_name MapEnemy
extends CharacterBody2D

signal touched(enemy: MapEnemy)

@export var encounter: EncounterDef
@export var region: Rect2 = Rect2()
@export var arena_path: NodePath
enum Behavior { WANDER, PATROL }
@export var behavior: Behavior = Behavior.WANDER
## Pontos da patrulha (mesmo espaço da posição do inimigo); só com Behavior.PATROL.
@export var patrol_points: PackedVector2Array = PackedVector2Array()
## Vê o jogador no cone e o persegue (ChaseMovement por cima do movimento base).
@export var chases: bool = false
## Invisível e sem toque até o jogador chegar a ambush_reveal_dist; aí aparece perseguindo (contato = emboscada).
@export var lurking: bool = false
## Inimigos do mesmo grupo (não vazio) perto do tocado entram na mesma batalha.
@export var group: StringName = &""
## Chefe de sala (M11): enquanto essa flag do GameState for 0, o inimigo fica invisível e sem toque.
@export var requires_flag: StringName = &""

## Longe demais para qualquer comportamento notar o jogador.
const FAR: Vector2 = Vector2(1.0e9, 1.0e9)

var movement: MapMovement
var frozen: bool = false
## Quem os comportamentos observam (a LocalMap define). Nulo = ninguém por perto.
var player: Node2D
## Frente do inimigo: direção da última velocidade diferente de zero (ZERO = nunca andou).
var facing: Vector2 = Vector2.ZERO

var _touch_armed: bool = true
## Já liberado pela flag (`requires_flag`); sem flag exigida vale sempre.
var _gate_open: bool = true
var _cfg: BalanceConfig
## Apareceu de um esconderijo: o contato conta sempre como emboscada.
var _revealed: bool = false
## Segundos restantes sem poder encostar (depois de uma fuga); o inimigo pisca.
var _cooldown: float = 0.0

## Sprite de mapa (M16): vem do primeiro inimigo do encontro que tiver `sprites` com folha de mapa. Null = o círculo.
var map_sprite: MapSprite

## Os pés ficam na borda de baixo do círculo (y = +14); a colisão não muda.
const FEET_Y: float = 14.0

@onready var _touch_area: Area2D = $TouchArea

func setup(cfg: BalanceConfig, dice: Dice) -> void:
	if movement == null:
		var base: MapMovement
		if behavior == Behavior.PATROL and not patrol_points.is_empty():
			base = PatrolMovement.new(patrol_points, cfg)
		else:
			base = WanderMovement.new(region, cfg, dice)
		movement = ChaseMovement.new(base, cfg) if chases or lurking else base
	_cfg = cfg

func _ready() -> void:
	_build_sprite()
	_touch_area.body_entered.connect(_on_touch_body_entered)
	if lurking:
		_set_hidden_state(true)
	if requires_flag != &"":
		_gate_open = false
		_set_hidden_state(true)
		sync_flag_gate()

func _physics_process(delta: float) -> void:
	sync_flag_gate()
	_tick_cooldown(delta)
	if frozen or movement == null:
		velocity = Vector2.ZERO
		if map_sprite != null:
			map_sprite.apply_motion(Vector2.ZERO)
		return
	var player_pos: Vector2 = player.global_position if player != null else FAR
	if lurking:
		if _cfg != null and global_position.distance_to(player_pos) <= _cfg.ambush_reveal_dist:
			reveal()
		else:
			velocity = Vector2.ZERO
			return
	velocity = movement.step(position, delta, player_pos)
	if velocity != Vector2.ZERO:
		facing = velocity.normalized()
	move_and_slide()
	if map_sprite != null:
		map_sprite.apply_motion(get_real_velocity())

## Segue a flag exigida: aparece (e passa a tocar) quando ela deixa de ser 0. Só muda de estado na transição,
## então o esconde-esconde da batalha e do `lurking` não é desfeito.
func sync_flag_gate() -> void:
	if requires_flag == &"":
		return
	var s: GameState = LocalMap.state_of(self)
	var open: bool = s != null and s.get_flag(requires_flag) != 0
	if open == _gate_open:
		return
	_gate_open = open
	_set_hidden_state(not open)

## O chefe de sala está liberado (sem flag exigida, sempre).
func gate_open() -> bool:
	return _gate_open

func arena() -> BattleArena:
	if arena_path.is_empty():
		return null
	return get_node_or_null(arena_path) as BattleArena

func is_chasing() -> bool:
	return _revealed or (movement != null and movement.is_chasing())

## O escondido aparece e avança perseguindo.
func reveal() -> void:
	if not lurking:
		return
	lurking = false
	_revealed = true
	_set_hidden_state(false)
	var chase: ChaseMovement = movement as ChaseMovement
	if chase != null:
		chase.force_chase()

func _set_hidden_state(on: bool) -> void:
	visible = not on
	_touch_area.set_deferred("monitoring", not on)

func in_cooldown() -> bool:
	return _cooldown > 0.0

## Depois de uma fuga: sem toque por `seconds`, piscando; ao acabar, rearma.
func begin_cooldown(seconds: float) -> void:
	_cooldown = seconds
	_touch_armed = false

func _tick_cooldown(delta: float) -> void:
	if _cooldown <= 0.0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	modulate.a = 0.35 if int(_cooldown * 8.0) % 2 == 0 and _cooldown > 0.0 else 1.0
	if _cooldown <= 0.0:
		modulate.a = 1.0
		rearm()

## Rearma o toque (menos durante o cooldown de fuga); se o jogador ainda estiver sobreposto, emite de novo.
func rearm() -> void:
	if _cooldown > 0.0 or lurking or not _gate_open:
		return
	_touch_armed = true
	if _touch_area == null:
		return
	for body: Node2D in _touch_area.get_overlapping_bodies():
		if body is Player:
			_emit_touch()
			return

func _on_touch_body_entered(body: Node2D) -> void:
	if body is Player:
		_emit_touch()

func _emit_touch() -> void:
	if not _touch_armed or not _gate_open:
		return
	_touch_armed = false
	touched.emit(self)

func _build_sprite() -> void:
	if encounter == null:
		return
	for e: EnemyDef in encounter.enemies:
		map_sprite = MapSprite.create(e.sprites, FEET_Y)
		if map_sprite != null:
			add_child(map_sprite)
			queue_redraw()
			return

func _draw() -> void:
	if map_sprite != null:
		return
	draw_circle(Vector2.ZERO, 14.0, Color(0.85, 0.15, 0.15))

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

## Longe demais para qualquer comportamento notar o jogador.
const FAR: Vector2 = Vector2(1.0e9, 1.0e9)

var movement: MapMovement
var frozen: bool = false
## Quem os comportamentos observam (a LocalMap define). Nulo = ninguém por perto.
var player: Node2D
## Frente do inimigo: direção da última velocidade diferente de zero (ZERO = nunca andou).
var facing: Vector2 = Vector2.ZERO

var _touch_armed: bool = true
var _cfg: BalanceConfig
## Apareceu de um esconderijo: o contato conta sempre como emboscada.
var _revealed: bool = false
## Segundos restantes sem poder encostar (depois de uma fuga); o inimigo pisca.
var _cooldown: float = 0.0

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
	_touch_area.body_entered.connect(_on_touch_body_entered)
	if lurking:
		_set_hidden_state(true)

func _physics_process(delta: float) -> void:
	_tick_cooldown(delta)
	if frozen or movement == null:
		velocity = Vector2.ZERO
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
	if _cooldown > 0.0 or lurking:
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
	if not _touch_armed:
		return
	_touch_armed = false
	touched.emit(self)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color(0.85, 0.15, 0.15))

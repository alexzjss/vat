class_name MapEnemy
extends CharacterBody2D

signal touched(enemy: MapEnemy)

@export var encounter: EncounterDef
@export var region: Rect2 = Rect2()
@export var arena_path: NodePath

var movement: MapMovement
var frozen: bool = false

var _touch_armed: bool = true
## Segundos restantes sem poder encostar (depois de uma fuga); o inimigo pisca.
var _cooldown: float = 0.0

@onready var _touch_area: Area2D = $TouchArea

func setup(cfg: BalanceConfig, dice: Dice) -> void:
	if movement == null:
		movement = WanderMovement.new(region, cfg, dice)

func _ready() -> void:
	_touch_area.body_entered.connect(_on_touch_body_entered)

func _physics_process(delta: float) -> void:
	_tick_cooldown(delta)
	if frozen or movement == null:
		velocity = Vector2.ZERO
		return
	velocity = movement.step(position, delta)
	move_and_slide()

func arena() -> BattleArena:
	if arena_path.is_empty():
		return null
	return get_node_or_null(arena_path) as BattleArena

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
	if _cooldown > 0.0:
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

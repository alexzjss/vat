class_name Player
extends CharacterBody2D

var cfg: BalanceConfig
var enabled: bool = true
## Se finito, substitui o input (testes e demo).
var override_dir: Vector2 = Vector2.INF

static func velocity_for(dir: Vector2, speed: float) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	return dir.normalized() * speed

func input_dir() -> Vector2:
	if override_dir.is_finite():
		return override_dir
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _physics_process(_delta: float) -> void:
	if enabled and cfg != null:
		velocity = velocity_for(input_dir(), cfg.player_speed)
		move_and_slide()
	else:
		velocity = Vector2.ZERO

func _draw() -> void:
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.25, 0.5, 0.95))

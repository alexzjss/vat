class_name WanderMovement
extends MapMovement

enum Mode { WAIT, MOVE }

var target: Vector2 = Vector2.ZERO

var _region: Rect2
var _cfg: BalanceConfig
var _dice: Dice
var _mode: Mode = Mode.WAIT
var _wait_left: float = 0.0
var _anchor: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0

func _init(region: Rect2, cfg: BalanceConfig, dice: Dice) -> void:
	_region = region
	_cfg = cfg
	_dice = dice
	_start_wait()

func step(pos: Vector2, delta: float) -> Vector2:
	if _mode == Mode.WAIT:
		_wait_left -= delta
		if _wait_left <= 0.0:
			_pick_target(pos)
			_mode = Mode.MOVE
			_anchor = pos
			_stuck_timer = 0.0
		return Vector2.ZERO
	if pos.distance_to(target) <= _cfg.wander_arrive_dist:
		_start_wait()
		return Vector2.ZERO
	if pos.distance_to(_anchor) >= _cfg.wander_arrive_dist:
		_anchor = pos
		_stuck_timer = 0.0
	else:
		_stuck_timer += delta
		if _stuck_timer >= _cfg.wander_stuck_time:
			_start_wait()
			return Vector2.ZERO
	return (target - pos).normalized() * _cfg.wander_speed

func _start_wait() -> void:
	_mode = Mode.WAIT
	_wait_left = _cfg.wander_wait_min + _dice.roll() * (_cfg.wander_wait_max - _cfg.wander_wait_min)

func _pick_target(pos: Vector2) -> void:
	if _region.has_point(pos):
		target = _region.position + Vector2(_dice.roll(), _dice.roll()) * _region.size
	else:
		# Fora da regiao: volta ao ponto mais proximo dentro dela (sem sorteio).
		target = pos.clamp(_region.position, _region.end)

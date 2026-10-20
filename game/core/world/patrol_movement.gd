# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name PatrolMovement
extends MapMovement

## Segue os pontos em laço, parando `patrol_wait` segundos em cada um.

var _points: PackedVector2Array
var _cfg: BalanceConfig
var _index: int = 0
var _waiting: bool = false
var _wait_left: float = 0.0

func _init(points: PackedVector2Array, cfg: BalanceConfig) -> void:
	_points = points
	_cfg = cfg

## Índice do ponto de destino atual.
func target_index() -> int:
	return _index

func step(pos: Vector2, delta: float, _player_pos: Vector2) -> Vector2:
	if _points.is_empty():
		return Vector2.ZERO
	if _waiting:
		_wait_left -= delta
		if _wait_left <= 0.0:
			_waiting = false
			_index = (_index + 1) % _points.size()
		return Vector2.ZERO
	var target: Vector2 = _points[_index]
	var dist: float = pos.distance_to(target)
	if dist <= _cfg.wander_arrive_dist:
		_waiting = true
		_wait_left = _cfg.patrol_wait
		return Vector2.ZERO
	var speed: float = _cfg.wander_speed
	if delta > 0.0 and dist <= speed * delta:
		return (target - pos) / delta
	return (target - pos) / dist * speed

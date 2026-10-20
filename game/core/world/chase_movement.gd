# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name ChaseMovement
extends MapMovement

## Decorador: anda como o movimento de dentro até ver o jogador no cone; então o persegue a
## `chase_speed`. Passando de `chase_give_up` desiste e o movimento de dentro retoma.

var chasing: bool = false
## Frente usada pelo cone: a direção da última velocidade do movimento de dentro.
var facing: Vector2 = Vector2.DOWN

var _inner: MapMovement
var _cfg: BalanceConfig

func _init(inner: MapMovement, cfg: BalanceConfig) -> void:
	_inner = inner
	_cfg = cfg

func is_chasing() -> bool:
	return chasing

## Começa a perseguir já (escondido que acabou de aparecer).
func force_chase() -> void:
	chasing = true

## Cone de visão: dentro de `range_px` e a no máximo metade de `full_angle_deg` da frente.
static func sees(pos: Vector2, facing_dir: Vector2, target: Vector2, range_px: float, full_angle_deg: float) -> bool:
	var to_target: Vector2 = target - pos
	if to_target.length() > range_px:
		return false
	if to_target == Vector2.ZERO or facing_dir == Vector2.ZERO:
		return true
	return absf(rad_to_deg(facing_dir.angle_to(to_target))) <= full_angle_deg / 2.0

func step(pos: Vector2, delta: float, player_pos: Vector2) -> Vector2:
	if chasing:
		if pos.distance_to(player_pos) > _cfg.chase_give_up:
			chasing = false
		else:
			return _toward(pos, player_pos)
	var v: Vector2 = _inner.step(pos, delta, player_pos)
	if v != Vector2.ZERO:
		facing = v.normalized()
	if sees(pos, facing, player_pos, _cfg.vision_range, _cfg.vision_angle):
		chasing = true
		return _toward(pos, player_pos)
	return v

func _toward(pos: Vector2, player_pos: Vector2) -> Vector2:
	var d: Vector2 = player_pos - pos
	if d == Vector2.ZERO:
		return Vector2.ZERO
	facing = d.normalized()
	return facing * _cfg.chase_speed

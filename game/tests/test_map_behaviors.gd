extends GutTest

## Comportamentos de inimigo no mapa (M7): patrulha, cone de visão, perseguição e escondido.

const NO_PLAYER: Vector2 = Vector2(1.0e9, 1.0e9)

var cfg: BalanceConfig
var root: Node2D

class FixedMove:
	extends MapMovement
	var v: Vector2 = Vector2.ZERO
	func step(_pos: Vector2, _delta: float, _player_pos: Vector2) -> Vector2:
		return v

func before_each() -> void:
	cfg = BalanceConfig.new()
	root = Node2D.new()
	add_child_autofree(root)

# --- Patrulha -------------------------------------------------------------------------

func _walk(m: PatrolMovement, pos: Vector2, seconds: float) -> Array[int]:
	var visited: Array[int] = []
	var dt: float = 0.05
	var t: float = 0.0
	while t < seconds:
		pos += m.step(pos, dt, NO_PLAYER) * dt
		t += dt
		var idx: int = m.target_index()
		if visited.is_empty() or visited[-1] != idx:
			visited.append(idx)
	return visited

func test_patrol_loops_through_points_in_order() -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100)])
	var visited: Array[int] = _walk(PatrolMovement.new(pts, cfg), Vector2.ZERO, 12.0)
	assert_gte(visited.size(), 5, "deu a volta")
	assert_eq(visited.slice(0, 5), [0, 1, 2, 0, 1])

func test_patrol_waits_at_each_point() -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	var m := PatrolMovement.new(pts, cfg)
	assert_eq(m.step(Vector2.ZERO, 0.05, NO_PLAYER), Vector2.ZERO, "chegou ao ponto 0 e para")
	var elapsed: float = 0.0
	while m.step(Vector2.ZERO, 0.05, NO_PLAYER) == Vector2.ZERO and elapsed < 5.0:
		elapsed += 0.05
	assert_almost_eq(elapsed, cfg.patrol_wait, 0.11)

func test_patrol_without_points_stands_still() -> void:
	assert_eq(PatrolMovement.new(PackedVector2Array(), cfg).step(Vector2.ZERO, 0.1, NO_PLAYER), Vector2.ZERO)

# --- Cone de visão --------------------------------------------------------------------

func test_vision_cone_range_and_angle() -> void:
	var r: float = cfg.vision_range
	var a: float = cfg.vision_angle
	assert_true(ChaseMovement.sees(Vector2.ZERO, Vector2.RIGHT, Vector2(r - 1.0, 0), r, a), "de frente e perto")
	assert_false(ChaseMovement.sees(Vector2.ZERO, Vector2.RIGHT, Vector2(r + 1.0, 0), r, a), "longe demais")
	var inside: Vector2 = Vector2.from_angle(deg_to_rad(a / 2.0 - 1.0)) * 100.0
	var outside: Vector2 = Vector2.from_angle(deg_to_rad(a / 2.0 + 1.0)) * 100.0
	assert_true(ChaseMovement.sees(Vector2.ZERO, Vector2.RIGHT, inside, r, a))
	assert_false(ChaseMovement.sees(Vector2.ZERO, Vector2.RIGHT, outside, r, a))
	assert_false(ChaseMovement.sees(Vector2.ZERO, Vector2.RIGHT, Vector2(-100, 0), r, a), "atras")

func test_chase_starts_on_sight_and_uses_chase_speed() -> void:
	var inner := FixedMove.new()
	inner.v = Vector2.RIGHT * 50.0
	var m := ChaseMovement.new(inner, cfg)
	assert_false(m.is_chasing())
	assert_eq(m.step(Vector2.ZERO, 0.1, Vector2(0, 300)), inner.v, "fora do cone: segue o movimento base")
	assert_false(m.is_chasing())
	var v: Vector2 = m.step(Vector2.ZERO, 0.1, Vector2(150, 0))
	assert_true(m.is_chasing())
	assert_almost_eq(v.length(), cfg.chase_speed, 0.001)
	assert_gt(v.x, 0.0)

func test_chase_gives_up_and_inner_resumes() -> void:
	var inner := FixedMove.new()
	inner.v = Vector2.LEFT * 40.0
	var m := ChaseMovement.new(inner, cfg)
	m.force_chase()
	assert_almost_eq(m.step(Vector2.ZERO, 0.1, Vector2(cfg.chase_give_up - 10.0, 0)).length(), cfg.chase_speed, 0.001)
	assert_true(m.is_chasing())
	var v: Vector2 = m.step(Vector2.ZERO, 0.1, Vector2(0, cfg.chase_give_up + 10.0))
	assert_false(m.is_chasing(), "desistiu")
	assert_eq(v, inner.v, "voltou ao movimento base")

# --- Escondido ------------------------------------------------------------------------

func _player_at(pos: Vector2) -> Player:
	var player: Player = (load("res://world/player.tscn") as PackedScene).instantiate() as Player
	player.cfg = cfg
	player.enabled = false
	player.position = pos
	root.add_child(player)
	return player

func _enemy(player: Player) -> MapEnemy:
	var e: MapEnemy = (load("res://world/map_enemy.tscn") as PackedScene).instantiate() as MapEnemy
	e.player = player
	e.position = Vector2.ZERO
	return e

func test_hidden_is_invisible_until_player_within_reveal_distance() -> void:
	var player: Player = _player_at(Vector2(500, 0))
	var e: MapEnemy = _enemy(player)
	e.lurking = true
	e.setup(cfg, Dice.new(3))
	root.add_child(e)
	assert_false(e.visible)
	await wait_physics_frames(2)
	player.position = Vector2(cfg.ambush_reveal_dist + 5.0, 0)
	await wait_physics_frames(3)
	assert_true(e.lurking, "ainda escondido")
	assert_false(e.visible)
	assert_false((e.get_node("TouchArea") as Area2D).monitoring)
	player.position = Vector2(cfg.ambush_reveal_dist - 5.0, 0)
	await wait_physics_frames(2)
	assert_false(e.lurking)
	assert_true(e.visible)
	assert_true(e.is_chasing(), "aparece perseguindo")

func test_revealed_contact_is_always_ambush() -> void:
	var e: MapEnemy = _enemy(_player_at(Vector2(500, 0)))
	e.lurking = true
	e.setup(cfg, Dice.new(3))
	root.add_child(e)
	e.reveal()
	e.movement = MapMovement.new()
	assert_eq(Initiative.classify(e.position, Vector2.RIGHT, e.is_chasing(), Vector2(-50, 0), cfg.backstab_angle), Initiative.Kind.AMBUSH)

func test_visible_chaser_follows_player_in_sight() -> void:
	var e: MapEnemy = _enemy(_player_at(Vector2(0, 150)))
	e.chases = true
	e.setup(cfg, Dice.new(3))
	root.add_child(e)
	e.movement = ChaseMovement.new(FixedMove.new(), cfg)
	await wait_physics_frames(10)
	assert_true(e.is_chasing())
	assert_gt(e.position.y, 0.0)

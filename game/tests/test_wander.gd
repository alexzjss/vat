extends GutTest

var cfg: BalanceConfig

func before_each() -> void:
	cfg = Fixtures.cfg()

func _run(m: WanderMovement, pos: Vector2, seconds: float) -> Vector2:
	var t: float = 0.0
	while t < seconds:
		pos += m.step(pos, 0.05, Vector2.ZERO) * 0.05
		t += 0.05
	return pos

func test_waits_then_moves_toward_target_in_region() -> void:
	var r: Rect2 = Rect2(0, 0, 100, 100)
	var m: WanderMovement = WanderMovement.new(r, cfg, ScriptedDice.new([0.0, 0.5, 0.5] as Array[float]))
	assert_eq(m.step(Vector2(10, 10), 0.6, Vector2.ZERO), Vector2.ZERO)
	var v: Vector2 = m.step(Vector2(10, 10), 0.05, Vector2.ZERO)
	assert_true(r.has_point(m.target))
	assert_almost_eq(v.length(), cfg.wander_speed, 0.001)

func test_never_leaves_region_over_time() -> void:
	var r: Rect2 = Rect2(50, 50, 120, 80)
	var m: WanderMovement = WanderMovement.new(r, cfg, Dice.new(3))
	var pos: Vector2 = Vector2(100, 90)
	for i: int in 400:
		pos += m.step(pos, 0.05, Vector2.ZERO) * 0.05
		assert_true(r.grow(cfg.wander_arrive_dist).has_point(pos))

func test_stuck_returns_to_wait() -> void:
	var m: WanderMovement = WanderMovement.new(Rect2(0, 0, 100, 100), cfg, ScriptedDice.new([0.0, 1.0, 1.0] as Array[float]))
	m.step(Vector2.ZERO, 1.0, Vector2.ZERO)
	var stuck: Vector2 = Vector2(5, 5)
	for i: int in 20:
		m.step(stuck, 0.05, Vector2.ZERO)
	assert_eq(m.step(stuck, 0.05, Vector2.ZERO), Vector2.ZERO)

func test_deterministic_with_same_seed() -> void:
	var r: Rect2 = Rect2(0, 0, 200, 200)
	var a: Vector2 = _run(WanderMovement.new(r, cfg, Dice.new(7)), Vector2(100, 100), 10.0)
	var b: Vector2 = _run(WanderMovement.new(r, cfg, Dice.new(7)), Vector2(100, 100), 10.0)
	assert_eq(a, b)

func test_outside_region_targets_nearest_point_inside() -> void:
	var r: Rect2 = Rect2(0, 0, 100, 100)
	var m: WanderMovement = WanderMovement.new(r, cfg, ScriptedDice.new([0.0, 0.5, 0.5] as Array[float]))
	m.step(Vector2(-50, 40), 0.6, Vector2.ZERO)
	m.step(Vector2(-50, 40), 0.05, Vector2.ZERO)
	assert_eq(m.target, Vector2(0, 40))

func test_map_movement_base_is_still() -> void:
	assert_eq(MapMovement.new().step(Vector2(3, 4), 0.1, Vector2.ZERO), Vector2.ZERO)

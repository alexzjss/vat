extends GutTest

var root: Node2D
var player: Player

func before_each() -> void:
	root = Node2D.new()
	add_child_autofree(root)
	player = (load("res://world/player.tscn") as PackedScene).instantiate() as Player
	player.cfg = BalanceConfig.new()
	player.override_dir = Vector2.ZERO
	root.add_child(player)

func test_diagonal_is_normalized() -> void:
	assert_almost_eq(Player.velocity_for(Vector2(1, 1), 200.0).length(), 200.0, 0.001)
	assert_eq(Player.velocity_for(Vector2.ZERO, 200.0), Vector2.ZERO)

func test_moves_with_override_and_stops_when_disabled() -> void:
	player.override_dir = Vector2.RIGHT
	await wait_physics_frames(10)
	assert_gt(player.global_position.x, 10.0)
	player.enabled = false
	await wait_physics_frames(2)
	var x: float = player.global_position.x
	await wait_physics_frames(10)
	assert_eq(player.global_position.x, x)

func test_blocked_by_wall() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 200)
	cs.shape = shape
	wall.add_child(cs)
	wall.position = Vector2(100, 0)
	root.add_child(wall)
	player.override_dir = Vector2.RIGHT
	for i in 60:
		await wait_physics_frames(1)
		assert_lte(player.global_position.x, 100.0 - 10.0 - 14.0 + 0.5)
	assert_gt(player.global_position.x, 50.0)

func test_camera_follows_then_slides_and_resumes() -> void:
	var cam := MapCamera.new()
	cam.follow = player
	root.add_child(cam)
	player.override_dir = Vector2.RIGHT
	await wait_physics_frames(10)
	player.override_dir = Vector2.ZERO
	await wait_physics_frames(3)
	assert_almost_eq(cam.global_position.x, player.global_position.x, 1.0)
	cam.slide_to(Vector2(500, 300), 0.1)
	await wait_seconds(0.4)
	assert_almost_eq(cam.global_position, Vector2(500, 300), Vector2(1, 1))
	player.override_dir = Vector2.LEFT
	await wait_physics_frames(5)
	assert_almost_eq(cam.global_position, Vector2(500, 300), Vector2(1, 1))
	player.override_dir = Vector2.ZERO
	cam.resume_follow(0.1)
	await wait_seconds(0.4)
	assert_almost_eq(cam.global_position, player.global_position, Vector2(1, 1))
	player.override_dir = Vector2.RIGHT
	await wait_physics_frames(5)
	player.override_dir = Vector2.ZERO
	await wait_physics_frames(3)
	assert_almost_eq(cam.global_position, player.global_position, Vector2(1, 1))

func test_camera_bounds() -> void:
	var cam: MapCamera = autofree(MapCamera.new())
	cam.set_bounds(Rect2(0, 0, 1000, 800))
	assert_eq(cam.limit_left, 0)
	assert_eq(cam.limit_top, 0)
	assert_eq(cam.limit_right, 1000)
	assert_eq(cam.limit_bottom, 800)

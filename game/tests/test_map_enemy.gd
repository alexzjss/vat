extends GutTest

var root: Node2D

func before_each() -> void:
	root = Node2D.new()
	add_child_autofree(root)

func _make_enemy(pos: Vector2, region: Rect2, seed_value: int = 5) -> MapEnemy:
	var enemy: MapEnemy = (load("res://world/map_enemy.tscn") as PackedScene).instantiate() as MapEnemy
	enemy.region = region
	enemy.position = pos
	enemy.setup(BalanceConfig.new(), Dice.new(seed_value))
	root.add_child(enemy)
	return enemy

func _make_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	wall.add_child(cs)
	wall.position = pos
	root.add_child(wall)

func _make_player(pos: Vector2) -> Player:
	var player: Player = (load("res://world/player.tscn") as PackedScene).instantiate() as Player
	player.cfg = BalanceConfig.new()
	player.override_dir = Vector2.ZERO
	player.position = pos
	root.add_child(player)
	return player

func test_enemy_stays_in_region_with_walls() -> void:
	var region := Rect2(0, 0, 200, 120)
	# Paredes ao redor da regiao.
	_make_wall(Vector2(100, -20), Vector2(400, 20))
	_make_wall(Vector2(100, 140), Vector2(400, 20))
	_make_wall(Vector2(-20, 60), Vector2(20, 400))
	_make_wall(Vector2(220, 60), Vector2(20, 400))
	var enemy: MapEnemy = _make_enemy(Vector2(100, 60), region)
	var limit: Rect2 = region.grow(BalanceConfig.new().wander_arrive_dist + 14.0)
	var moved: bool = false
	for i in 600:
		await wait_physics_frames(1)
		assert_true(limit.has_point(enemy.position), "fora da regiao no frame %d: %s" % [i, enemy.position])
		if enemy.position.distance_to(Vector2(100, 60)) > 5.0:
			moved = true
	assert_true(moved)

func test_frozen_enemy_does_not_move() -> void:
	var enemy: MapEnemy = _make_enemy(Vector2(100, 60), Rect2(0, 0, 200, 120))
	enemy.frozen = true
	await wait_physics_frames(120)
	assert_eq(enemy.position, Vector2(100, 60))

func test_touch_emits_once_until_rearm() -> void:
	var enemy: MapEnemy = _make_enemy(Vector2(0, 0), Rect2(0, 0, 0, 0))
	enemy.frozen = true
	watch_signals(enemy)
	var player: Player = _make_player(Vector2(500, 0))
	await wait_physics_frames(3)
	assert_signal_not_emitted(enemy, "touched")
	player.position = Vector2(20, 0)
	await wait_physics_frames(5)
	assert_signal_emit_count(enemy, "touched", 1)
	player.position = Vector2(20, 1)
	await wait_physics_frames(5)
	assert_signal_emit_count(enemy, "touched", 1)
	# Sai, rearma e entra de novo.
	player.position = Vector2(500, 0)
	await wait_physics_frames(3)
	enemy.rearm()
	player.position = Vector2(20, 0)
	await wait_physics_frames(5)
	assert_signal_emit_count(enemy, "touched", 2)

func test_rearm_while_overlapping_emits_again() -> void:
	var enemy: MapEnemy = _make_enemy(Vector2(0, 0), Rect2(0, 0, 0, 0))
	enemy.frozen = true
	watch_signals(enemy)
	_make_player(Vector2(20, 0))
	await wait_physics_frames(5)
	assert_signal_emit_count(enemy, "touched", 1)
	enemy.rearm()
	await wait_physics_frames(3)
	assert_signal_emit_count(enemy, "touched", 2)

func test_arena_positions_are_global() -> void:
	var arena := BattleArena.new()
	arena.position = Vector2(300, 200)
	for spot_name: String in ["HeroSpot1", "HeroSpot2", "HeroSpot3", "EnemySpot1", "EnemySpot2"]:
		var m := Marker2D.new()
		m.name = spot_name
		arena.add_child(m)
	(arena.get_node("HeroSpot1") as Marker2D).position = Vector2(-100, 0)
	(arena.get_node("EnemySpot1") as Marker2D).position = Vector2(100, 0)
	(arena.get_node("EnemySpot2") as Marker2D).position = Vector2(100, 50)
	root.add_child(arena)
	assert_eq(arena.hero_positions().size(), 3)
	assert_eq(arena.hero_positions()[0], Vector2(200, 200))
	assert_eq(arena.center(), Vector2(300, 200))
	var enemies: Array[Vector2] = arena.enemy_positions(2)
	assert_eq(enemies[0], Vector2(400, 200))
	assert_eq(enemies[1], Vector2(400, 250))
	var more: Array[Vector2] = arena.enemy_positions(3)
	assert_push_error("EnemySpot")
	assert_eq(more.size(), 3)
	assert_eq(more[2], Vector2(400, 250))

func test_zone_emits_entered_only_when_armed() -> void:
	var zone := Zone.new()
	zone.zone_id = &"town"
	zone.position = Vector2(0, 0)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 60)
	cs.shape = shape
	zone.add_child(cs)
	root.add_child(zone)
	watch_signals(zone)
	var player: Player = _make_player(Vector2(500, 0))
	await wait_physics_frames(3)
	zone.armed = false
	player.position = Vector2(0, 0)
	await wait_physics_frames(5)
	assert_signal_not_emitted(zone, "entered")
	player.position = Vector2(500, 0)
	await wait_physics_frames(3)
	zone.armed = true
	player.position = Vector2(0, 0)
	await wait_physics_frames(5)
	assert_signal_emit_count(zone, "entered", 1)
	assert_signal_emitted_with_parameters(zone, "entered", [&"town"])

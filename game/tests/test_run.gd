extends GutTest

## Corrida (M7): segurar `run` multiplica a velocidade do jogador por cfg.run_mult.

func _player(cfg: BalanceConfig) -> Player:
	var root := Node2D.new()
	add_child_autofree(root)
	var p: Player = (load("res://world/player.tscn") as PackedScene).instantiate() as Player
	p.cfg = cfg
	p.override_dir = Vector2.RIGHT
	root.add_child(p)
	return p

func test_speed_for_multiplies_when_running() -> void:
	var cfg := BalanceConfig.new()
	assert_almost_eq(Player.speed_for(cfg, false), cfg.player_speed, 0.001)
	assert_almost_eq(Player.speed_for(cfg, true), cfg.player_speed * cfg.run_mult, 0.001)
	assert_almost_eq(cfg.run_mult, 1.8, 0.0001)

func test_running_player_velocity() -> void:
	var cfg := BalanceConfig.new()
	var p: Player = _player(cfg)
	p.override_run = 0
	await wait_physics_frames(2)
	assert_almost_eq(p.velocity.x, cfg.player_speed, 0.01)
	p.override_run = 1
	await wait_physics_frames(2)
	assert_almost_eq(p.velocity.x, cfg.player_speed * cfg.run_mult, 0.01)

func test_run_travels_farther() -> void:
	var cfg := BalanceConfig.new()
	var walk: Player = _player(cfg)
	walk.override_run = 0
	var run: Player = _player(cfg)
	run.override_run = 1
	await wait_physics_frames(20)
	assert_gt(run.global_position.x, walk.global_position.x * 1.5)

func test_run_actions_exist() -> void:
	assert_true(InputMap.has_action("run"))
	assert_true(InputMap.has_action("flee"))

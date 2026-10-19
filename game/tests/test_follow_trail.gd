extends GutTest

## Rastro do líder (M7): amostras por distância, posição do seguidor k, reset e contagem de seguidores.

func test_samples_by_distance() -> void:
	var t := FollowTrail.new(10.0, 1, Vector2.ZERO)
	t.push(Vector2(4, 0))
	assert_eq(t.samples.size(), 1, "abaixo do espaçamento não amostra")
	t.push(Vector2(10, 0))
	assert_eq(t.samples.size(), 2)
	t.push(Vector2(15, 0))
	assert_eq(t.samples.size(), 2)
	t.push(Vector2(20, 0))
	assert_eq(t.samples.size(), 3)

func test_follower_k_is_at_sample_k_times_gap() -> void:
	var t := FollowTrail.new(10.0, 2, Vector2.ZERO)
	for i: int in range(1, 7):
		t.push(Vector2(10.0 * i, 0))
	# samples[0] = x60 ... samples[6] = x0
	assert_eq(t.position_of(1), Vector2(40, 0))
	assert_eq(t.position_of(2), Vector2(20, 0))
	assert_eq(t.position_of(3), Vector2(0, 0))

func test_short_trail_clamps_to_oldest() -> void:
	var t := FollowTrail.new(10.0, 1, Vector2(5, 5))
	assert_eq(t.position_of(3), Vector2(5, 5))

func test_reset_collapses_followers_on_leader() -> void:
	var t := FollowTrail.new(10.0, 1, Vector2.ZERO)
	for i: int in range(1, 5):
		t.push(Vector2(10.0 * i, 0))
	t.reset(Vector2(100, 100))
	assert_eq(t.samples.size(), 1)
	assert_eq(t.position_of(1), Vector2(100, 100))
	assert_eq(t.position_of(3), Vector2(100, 100))

func test_trim_keeps_only_needed_samples() -> void:
	var t := FollowTrail.new(10.0, 1, Vector2.ZERO)
	for i: int in range(1, 20):
		t.push(Vector2(10.0 * i, 0))
	t.trim(3)
	assert_eq(t.samples.size(), 4)
	assert_eq(t.samples[0], Vector2(190, 0))

func test_follower_count_tracks_formation() -> void:
	var cfg := Fixtures.cfg()
	var defs: Array[CharacterDef] = []
	for id: String in ["teste_a", "teste_b", "teste_c"]:
		defs.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	var state := GameState.new_game(cfg, defs, items, counts, Dice.new(7), &"local", &"Entry")
	var leader: Node2D = add_child_autofree(Node2D.new()) as Node2D
	var pf: PartyFollowers = add_child_autofree(PartyFollowers.new()) as PartyFollowers
	pf.setup(state, leader)
	assert_eq(pf.count(), state.heroes.size() - 1)
	var before: int = pf.count()
	state.heroes.pop_back()
	assert_eq(pf.count(), before - 1)
	state.heroes.resize(1)
	assert_eq(pf.count(), 0)

func test_hide_and_restart_resets_trail_on_leader() -> void:
	var cfg := Fixtures.cfg()
	var defs: Array[CharacterDef] = [load("res://data/test/heroes/teste_a.tres") as CharacterDef]
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	var state := GameState.new_game(cfg, defs, items, counts, Dice.new(7), &"local", &"Entry")
	var leader := Node2D.new()
	add_child_autofree(leader)
	var pf: PartyFollowers = add_child_autofree(PartyFollowers.new()) as PartyFollowers
	pf.setup(state, leader)
	pf.hide_all()
	assert_false(pf.visible)
	leader.global_position = Vector2(500, 0)
	pf.restart()
	assert_true(pf.visible)
	assert_eq(pf.follower_position(1), Vector2(500, 0))

extends GutTest

## Mapa-múndi: spawn por marcador, zona de local e ausência de inimigos.

const SCENE: String = "res://world/overworld.tscn"
const HEROES: Array[String] = ["teste_a", "teste_b", "teste_c"]

var world: Overworld
var state: GameState

func before_each() -> void:
	var defs: Array[CharacterDef] = []
	for id: String in HEROES:
		defs.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	state = GameState.new_game(Fixtures.cfg(), defs, items, counts, Dice.new(7), &"overworld", &"Start")
	world = (load(SCENE) as PackedScene).instantiate() as Overworld
	add_child_autofree(world)

func _player() -> Player:
	return world.get_node("Player") as Player

func _zone() -> Zone:
	return world.get_node("AreaTeste") as Zone

func test_spawn_at_marker() -> void:
	world.setup(state, &"AreaTesteReturn")
	var marker: Marker2D = world.get_node("AreaTesteReturn") as Marker2D
	assert_eq(_player().global_position, marker.global_position)
	var cam: MapCamera = world.get_node("MapCamera") as MapCamera
	assert_same(cam.follow, _player())

func test_spawn_defaults_to_start_and_errors_on_missing_marker() -> void:
	world.setup(state, &"Inexistente")
	assert_push_error("não existe")
	var start: Marker2D = world.get_node("Start") as Marker2D
	assert_eq(_player().global_position, start.global_position)

func test_entering_zone_emits_location_entered() -> void:
	world.setup(state, &"Start")
	watch_signals(world)
	_zone().entered.emit(&"area_teste")
	assert_signal_emit_count(world, "location_entered", 1)
	assert_signal_emitted_with_parameters(world, "location_entered", [&"area_teste"])

func test_walking_into_zone_emits_location_entered() -> void:
	world.setup(state, &"AreaTesteReturn")
	watch_signals(world)
	_player().override_dir = Vector2.UP
	await wait_physics_frames(60)
	_player().override_dir = Vector2.ZERO
	assert_signal_emit_count(world, "location_entered", 1)

func test_zone_id_and_label_text() -> void:
	assert_eq(_zone().zone_id, &"area_teste")
	assert_eq(_zone().label_text, "Área de teste")

func test_return_marker_is_outside_zone() -> void:
	var cs: CollisionShape2D = _zone().get_node("CollisionShape2D") as CollisionShape2D
	var size: Vector2 = (cs.shape as RectangleShape2D).size
	var rect := Rect2(_zone().global_position + cs.position - size / 2.0, size)
	var marker: Marker2D = world.get_node("AreaTesteReturn") as Marker2D
	assert_false(rect.has_point(marker.global_position))

func test_no_map_enemies_in_overworld() -> void:
	var found: int = 0
	var stack: Array[Node] = [world]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MapEnemy:
			found += 1
		stack.append_array(n.get_children())
	assert_eq(found, 0)

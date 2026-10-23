extends GutTest

## Ligações entre mapas (M12): MapLink, save/load em interiores, tela de fim e a varredura de todos os mapas de Game.MAPS.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"
const INTERIOR: StringName = &"teste_interior"

var game: Game

func before_each() -> void:
	game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.skip_title = true
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.maps[INTERIOR] = _interior_scene()
	add_child_autofree(game)

func after_each() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

## Interior de teste: um LocalMap com a ligação "Porta" de volta à área de teste, a pousada e dois marcadores.
func _interior_scene() -> PackedScene:
	var root: LocalMap = (load("res://world/local_map.tscn") as PackedScene).instantiate() as LocalMap
	for child: Node in root.get_children():
		if child is MapEnemy or child is RestPoint:
			root.remove_child(child)
			child.free()
	_marker(root, &"Entry", Vector2(300, 300))
	_marker(root, &"InnSpawn", Vector2(500, 300))
	var link := MapLink.new()
	link.name = "Porta"
	link.target_map = &"area_teste"
	link.target_spawn = &"Entry"
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 60)
	cs.shape = shape
	link.add_child(cs)
	link.position = Vector2(900, 300)
	root.add_child(link)
	link.owner = root
	cs.owner = root
	var inn := Inn.new()
	inn.name = "Pousada"
	inn.position = Vector2(500, 300)
	root.add_child(inn)
	inn.owner = root
	var packed := PackedScene.new()
	assert_eq(packed.pack(root), OK)
	root.free()
	return packed

func _marker(root: Node, marker_name: StringName, pos: Vector2) -> void:
	var m := Marker2D.new()
	m.name = marker_name
	m.position = pos
	root.add_child(m)
	m.owner = root

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	assert_false(game.busy, "transição terminou")

func _map() -> LocalMap:
	return game.current as LocalMap

func _player() -> Player:
	return game.current.get_node("Player") as Player

func _enter(map_id: StringName, spawn: StringName) -> void:
	game.go_to(map_id, spawn, false)
	await _wait_idle()

# --- MapLink --------------------------------------------------------------------------

func test_link_takes_player_to_target_spawn() -> void:
	await _enter(INTERIOR, &"Entry")
	assert_eq(game.current_map, INTERIOR)
	assert_eq(_player().global_position, (game.current.get_node("Entry") as Marker2D).global_position)
	var link: MapLink = game.current.get_node("Porta") as MapLink
	link.activated.emit(link.target_map, link.target_spawn)
	await _wait_idle()
	assert_eq(game.current_map, &"area_teste")
	assert_eq(_player().global_position, (game.current.get_node("Entry") as Marker2D).global_position)

func test_body_entering_link_activates_it() -> void:
	await _enter(INTERIOR, &"Entry")
	var link: MapLink = game.current.get_node("Porta") as MapLink
	var got: Array = []
	link.activated.connect(func(m: StringName, s: StringName) -> void: got.append([m, s]))
	link.body_entered.emit(_player())
	assert_eq(got, [[&"area_teste", &"Entry"]])

func test_disarmed_link_ignores_the_player() -> void:
	await _enter(INTERIOR, &"Entry")
	var link: MapLink = game.current.get_node("Porta") as MapLink
	link.armed = false
	var got: Array = []
	link.activated.connect(func(m: StringName, _s: StringName) -> void: got.append(m))
	link.body_entered.emit(_player())
	assert_eq(got.size(), 0)

func test_link_to_unknown_map_is_refused_without_moving() -> void:
	await _enter(INTERIOR, &"Entry")
	var link: MapLink = game.current.get_node("Porta") as MapLink
	link.activated.emit(&"nao_existe", &"X")
	assert_false(game.busy)
	assert_eq(game.current_map, INTERIOR)
	assert_push_error("mapa desconhecido")

func test_links_are_disarmed_during_event_and_rearmed_after() -> void:
	await _enter(INTERIOR, &"Entry")
	var link: MapLink = game.current.get_node("Porta") as MapLink
	assert_true(link.armed)
	_map().set_event_frozen(true)
	assert_false(link.armed, "evento desarma a ligação")
	_map().set_event_frozen(false)
	assert_true(link.armed)

func test_link_is_ignored_while_game_is_busy() -> void:
	await _enter(INTERIOR, &"Entry")
	var link: MapLink = game.current.get_node("Porta") as MapLink
	game.busy = true
	link.activated.emit(&"area_teste", &"Entry")
	assert_eq(game.current_map, INTERIOR)
	game.busy = false

# --- save e load em interiores --------------------------------------------------------

func test_save_and_load_in_interior_returns_to_interior_spawn() -> void:
	await _enter(INTERIOR, &"Entry")
	_player().global_position = (game.current.get_node("Pousada") as Inn).global_position
	assert_eq(game.save_spawn_here(), &"InnSpawn")
	assert_true(game.can_save())
	assert_true(game.save_to_slot(1))
	assert_eq(game.state.save_map, INTERIOR)
	assert_eq(game.state.save_spawn, &"InnSpawn")
	game.state.money = 99
	assert_true(game.continue_from_slot(1))
	await _wait_idle()
	assert_eq(game.current_map, INTERIOR)
	assert_eq(_player().global_position, (game.current.get_node("InnSpawn") as Marker2D).global_position)
	assert_eq(game.state.money, 0, "o load devolve o estado do slot")

func test_interior_outside_inn_cannot_save() -> void:
	await _enter(INTERIOR, &"Entry")
	assert_eq(game.save_spawn_here(), &"")
	assert_false(game.can_save())

func test_game_over_in_interior_returns_to_saved_interior_spawn() -> void:
	await _enter(INTERIOR, &"Entry")
	_player().global_position = (game.current.get_node("Pousada") as Inn).global_position
	game.rest_here()
	assert_eq(game.state.save_map, INTERIOR)
	game.state.heroes[0].hp = 0
	_map().game_over.emit()
	assert_not_null(game.game_over_screen)
	assert_eq(game.state.save_map, INTERIOR)
	assert_eq(game.state.save_spawn, &"InnSpawn")

# --- tela de fim ----------------------------------------------------------------------

func _end_demo() -> void:
	game.event_player.end_demo_requested.emit()

func test_end_demo_shows_end_screen_and_blocks_input() -> void:
	await _enter(&"area_teste", &"Entry")
	game.state.play_time = 125.0
	_end_demo()
	assert_not_null(game.end_screen)
	assert_false(game.can_open_menu(), "menu não abre na tela de fim")
	assert_false(game.can_play_event())
	assert_false(game._can_open_overlay())
	assert_string_contains(game.end_screen.body_text(), "Fim da demo")
	assert_string_contains(game.end_screen.body_text(), "02:05", "tempo de jogo")
	assert_string_contains(game.end_screen.body_text(), "Nv %d" % game.state.party_avg_level())

func test_end_screen_ignores_enter_right_after_it_appears() -> void:
	await _enter(&"area_teste", &"Entry")
	_end_demo()
	var es: EndScreen = game.end_screen
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	es._unhandled_input(ev)
	await get_tree().process_frame
	assert_same(game.end_screen, es, "Enter no primeiro quadro não sai da tela")
	es._process(EndScreen.INPUT_DELAY)
	assert_true(es.accepting_input())
	es._unhandled_input(ev)
	await get_tree().process_frame
	assert_null(game.end_screen, "depois da espera o Enter volta ao título")
	assert_true(game.in_title)

func test_end_demo_twice_keeps_one_screen() -> void:
	await _enter(&"area_teste", &"Entry")
	_end_demo()
	var first: EndScreen = game.end_screen
	_end_demo()
	assert_same(game.end_screen, first)

func test_play_time_stops_on_end_screen() -> void:
	await _enter(&"area_teste", &"Entry")
	_end_demo()
	var t: float = game.state.play_time
	game._process(5.0)
	assert_eq(game.state.play_time, t)

func test_end_screen_returns_to_title() -> void:
	await _enter(&"area_teste", &"Entry")
	_end_demo()
	game.end_screen.accept()
	await get_tree().process_frame
	assert_null(game.end_screen)
	assert_true(game.in_title)
	assert_not_null(game.title)
	assert_null(game.current, "o mapa saiu")

func test_end_demo_flags_the_stored_save_of_the_last_used_slot() -> void:
	await _enter(&"area_teste", &"Entry")
	var rp: RestPoint = game.current.get_node("RestPoint") as RestPoint
	_player().global_position = rp.global_position
	assert_true(game.save_to_slot(2))
	assert_eq(game.last_slot, 2)
	game.state.add_money(7)
	_end_demo()
	var loaded: GameState = game.store.read(2, Dice.new(1))
	assert_not_null(loaded)
	assert_eq(loaded.get_flag(&"fatia_concluida"), 1)
	assert_eq(loaded.money, 0, "o clear save não leva o estado vivo: só a flag entra no que estava gravado")
	assert_eq(game.store.summary(1)["status"], SaveStore.Status.EMPTY, "outros slots intactos")

func test_end_demo_without_used_slot_writes_nothing() -> void:
	await _enter(&"area_teste", &"Entry")
	assert_eq(game.last_slot, 0)
	_end_demo()
	for slot: int in range(1, SaveStore.SLOTS + 1):
		assert_eq(game.store.summary(slot)["status"], SaveStore.Status.EMPTY)

func test_continue_sets_last_slot() -> void:
	await _enter(&"area_teste", &"Entry")
	_player().global_position = (game.current.get_node("RestPoint") as RestPoint).global_position
	assert_true(game.save_to_slot(3))
	game.last_slot = 0
	assert_true(game.continue_from_slot(3))
	await _wait_idle()
	assert_eq(game.last_slot, 3)

func test_end_demo_from_event_step() -> void:
	await _enter(&"area_teste", &"Entry")
	var script := EventScript.new()
	var steps: Array[EventStep] = [EndDemoStep.new()]
	script.steps = steps
	await game.play_event(script)
	assert_not_null(game.end_screen)

# --- varredura de todos os mapas ------------------------------------------------------

func _find_all(root: Node, type: String) -> Array[Node]:
	return root.find_children("*", type, true, false)

func _scene_of(map_id: StringName) -> Node:
	return (Game.MAPS[map_id] as PackedScene).instantiate()

## A varredura mora em MapChecks.links (M16); o ContentLoader resume cada mapa (ligacoes, zonas, saidas, pousadas, descansos).
func test_every_map_link_exit_and_zone_points_to_an_existing_spawn() -> void:
	assert_gt(Game.MAPS.size(), 0)
	var maps: Dictionary[StringName, Dictionary] = {}
	var total_refs: int = 0
	for map_id: StringName in Game.MAPS:
		var packed: PackedScene = Game.MAPS[map_id]
		var scene: Node = packed.instantiate()
		maps[map_id] = ContentLoader.scan_map(map_id, packed.resource_path, scene)
		total_refs += (maps[map_id]["refs"] as Array).size()
		scene.free()
	assert_gt(total_refs, 10, "a varredura acha as ligacoes")
	var issues: Array[ValidationIssue] = MapChecks.links(maps)
	assert_eq(issues.size(), 0, "\n".join(issues.map(func(i: ValidationIssue) -> String: return i.to_text())))

func _assert_target(from_map: StringName, what: String, target_map: StringName, target_spawn: StringName) -> void:
	assert_true(Game.MAPS.has(target_map), "%s: %s -> mapa '%s' existe" % [from_map, what, target_map])
	if not Game.MAPS.has(target_map):
		return
	var target: Node = _scene_of(target_map)
	var marker: Node = target.get_node_or_null(NodePath(String(target_spawn)))
	assert_true(marker is Marker2D, "%s: %s -> marcador '%s' existe em '%s'" % [from_map, what, target_spawn, target_map])
	target.free()

func test_test_start_profile_points_to_existing_map_and_spawn() -> void:
	var p: StartProfile = load("res://data/test/start_teste.tres") as StartProfile
	_assert_target(&"perfil", "start_teste", p.map, p.spawn)

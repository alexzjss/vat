extends GutTest

## Interação (M10): escolha do interagível mais próximo, NPC/placa, ponto de descanso e, principalmente,
## a entrada não vazar: o accept do diálogo não aciona interact, menu de campo nem movimento.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

var game: Game
var map: LocalMap

func before_each() -> void:
	game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.skip_title = true
	add_child_autofree(game)

func after_each() -> void:
	Input.flush_buffered_events()
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1

func _enter_area() -> void:
	await _wait_idle()
	(game.current as Overworld).location_entered.emit(&"area_teste")
	await _wait_idle()
	map = game.current as LocalMap

## Tecla física (Enter casa com interact e ui_accept ao mesmo tempo, como no jogo real).
func _press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func _sign(text: String, offset: Vector2) -> Sign:
	var s := Sign.new()
	s.text = text
	s.position = map.player.position + offset
	map.add_interactable(s)
	return s

func _npc(line: String, offset: Vector2) -> Npc:
	var say := SayStep.new()
	say.speaker = "Ana"
	say.text = line
	var script := EventScript.new()
	script.steps = [say] as Array[EventStep]
	var n := Npc.new()
	n.event = script
	n.position = map.player.position + offset
	map.add_interactable(n)
	return n

# --- escolha do mais próximo (pura) --------------------------------------------

func test_picker_chooses_nearest() -> void:
	var pos: Array[Vector2] = [Vector2(100, 0), Vector2(30, 0), Vector2(0, 60)]
	assert_eq(InteractPicker.nearest(Vector2.ZERO, pos), 1)

func test_picker_empty_and_tie() -> void:
	assert_eq(InteractPicker.nearest(Vector2.ZERO, [] as Array[Vector2]), -1)
	var tie: Array[Vector2] = [Vector2(10, 0), Vector2(-10, 0)]
	assert_eq(InteractPicker.nearest(Vector2.ZERO, tie), 0, "empate: o primeiro")

# --- mapa ---------------------------------------------------------------------

func test_nearest_interactable_gets_the_interaction() -> void:
	await _enter_area()
	var far: Sign = _sign("longe", Vector2(40, 0))
	var near: Npc = _npc("perto", Vector2(0, 20))
	var got: Array[String] = []
	map.event_requested.connect(func(ev: EventScript) -> void:
		var say: SayStep = ev.steps[0] as SayStep
		got.append(say.text))
	assert_true(far.can_interact())
	assert_true(near.can_interact())
	assert_true(map.try_interact())
	assert_eq(got, ["perto"] as Array[String])
	game.event_player.cancel()

func test_interact_out_of_reach_does_nothing() -> void:
	await _enter_area()
	_sign("longe", Vector2(300, 0))
	assert_false(map.try_interact())
	assert_false(game.event_player.active)

func test_sign_shows_its_text() -> void:
	await _enter_area()
	_sign("Cuidado com o chão.", Vector2(30, 0))
	assert_true(map.try_interact())
	assert_true(game.event_player.active)
	assert_eq(game.event_player.dialogue._body.text, "Cuidado com o chão.")
	assert_eq(game.event_player.dialogue._name.text, "")
	game.event_player.cancel()

func test_npc_is_solid_and_speaks_with_name() -> void:
	await _enter_area()
	var n: Npc = _npc("Olá!", Vector2(30, 0))
	var blockers: int = 0
	for c: Node in n.get_children():
		if c is StaticBody2D:
			blockers += 1
	assert_eq(blockers, 1, "NPC bloqueia a passagem")
	assert_true(map.try_interact())
	assert_eq(game.event_player.dialogue._name.text, "Ana")
	game.event_player.cancel()

func test_no_interaction_while_event_runs() -> void:
	await _enter_area()
	_sign("a", Vector2(30, 0))
	assert_true(map.try_interact())
	assert_false(map.try_interact(), "evento em andamento")
	game.event_player.cancel()

func test_rest_point_still_works_through_the_router() -> void:
	await _enter_area()
	map.player.global_position = map.rest_point.global_position
	assert_true(map.rest_point is Interactable)
	assert_true(map.try_interact())
	assert_true(game.rest_menu.is_open, "menu de descanso abriu")
	game.rest_menu.close()

func test_closer_npc_wins_over_rest_point() -> void:
	await _enter_area()
	map.player.global_position = map.rest_point.global_position + Vector2(30, 0)
	_npc("oi", Vector2(5, 0))
	assert_true(map.try_interact())
	assert_true(game.event_player.active)
	assert_false(game.rest_menu.is_open)
	game.event_player.cancel()

# --- entrada não vaza ---------------------------------------------------------

func test_interact_key_starts_event_and_accept_advances_without_reopening() -> void:
	await _enter_area()
	var starts: Array[int] = [0]
	map.event_requested.connect(func(_e: EventScript) -> void: starts[0] += 1)
	_sign("uma fala bem curta", Vector2(30, 0))
	var d: DialogueBox = game.event_player.dialogue
	await _press(KEY_ENTER)
	assert_eq(starts[0], 1, "Enter interage")
	assert_true(d.is_open)
	assert_true(d.is_revealing() or d.shown_chars() > 0)
	await _press(KEY_ENTER)
	assert_eq(d.shown_chars(), "uma fala bem curta".length(), "primeiro Enter só completa o texto")
	assert_true(d.is_open)
	await _press(KEY_ENTER)
	assert_false(d.is_open, "segundo Enter fecha")
	assert_false(game.event_player.active)
	assert_eq(starts[0], 1, "o mesmo Enter não reabriu o evento")
	assert_false(game.menu.is_open)
	assert_false(game.rest_menu.is_open)

func test_accept_that_ends_event_does_not_interact_in_same_frame() -> void:
	await _enter_area()
	var starts: Array[int] = [0]
	map.event_requested.connect(func(_e: EventScript) -> void: starts[0] += 1)
	_sign("x", Vector2(30, 0))
	assert_true(map.try_interact())
	assert_eq(starts[0], 1)
	game.event_player.dialogue.accept()
	game.event_player.dialogue.accept()
	assert_false(game.event_player.active)
	assert_false(map.try_interact(), "no quadro em que o evento acabou, interact não vale")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(map.try_interact(), "depois disso volta a valer")
	game.event_player.cancel()

func test_event_end_does_not_open_menu_or_move_player() -> void:
	await _enter_area()
	_sign("x", Vector2(30, 0))
	var p0: Vector2 = map.player.global_position
	await _press(KEY_SPACE)
	assert_true(game.event_player.active)
	await _press(KEY_SPACE)
	await _press(KEY_SPACE)
	assert_false(game.event_player.active)
	assert_false(game.menu.is_open)
	assert_eq(map.player.global_position, p0, "jogador não se mexeu")
	assert_true(map.player.enabled)

func test_menu_key_during_event_is_ignored() -> void:
	await _enter_area()
	_sign("x", Vector2(30, 0))
	assert_true(map.try_interact())
	var ev := InputEventAction.new()
	ev.action = &"open_menu"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(game.menu.is_open)
	assert_true(game.event_player.active)
	game.event_player.cancel()

func test_choice_navigation_keys_do_not_move_player() -> void:
	await _enter_area()
	var c := ChoiceStep.new()
	c.prompt = "?"
	c.options = PackedStringArray(["A", "B"])
	c.flag = &"r"
	var script := EventScript.new()
	script.steps = [c] as Array[EventStep]
	var p0: Vector2 = map.player.global_position
	game.play_event(script)
	var d: DialogueBox = game.event_player.dialogue
	d.accept()
	await _press(KEY_DOWN)
	assert_eq(d.cursor, 1)
	await _press(KEY_ENTER)
	assert_eq(game.state.get_flag(&"r"), 1)
	assert_eq(map.player.global_position, p0)

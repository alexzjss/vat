extends GutTest

## DialogueBox (revelação, accept, escolha) e EventPlayer (apresentação dos requests, congelamento, MoveActor).

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

var game: Game
var map: LocalMap
var box: DialogueBox

func before_each() -> void:
	box = DialogueBox.new()
	add_child_autofree(box)

func _make_game() -> void:
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

func _say(text: String, speaker: String = "") -> SayStep:
	var s := SayStep.new()
	s.speaker = speaker
	s.text = text
	return s

func _script(steps: Array[EventStep]) -> EventScript:
	var e := EventScript.new()
	e.steps = steps
	return e

func _weak_encounter() -> EncounterDef:
	var enc := EncounterDef.new()
	enc.id = &"fraco"
	var list: Array[EnemyDef] = [Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 0), 100)]
	enc.enemies = list
	return enc

# --- DialogueBox ---------------------------------------------------------------

func test_speed_for_uses_config_table_and_clamps() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	assert_eq(DialogueBox.speed_for(cfg, 1), 30.0)
	assert_eq(DialogueBox.speed_for(cfg, 2), 60.0)
	assert_eq(DialogueBox.speed_for(cfg, 3), 120.0)
	assert_eq(DialogueBox.speed_for(cfg, 99), 120.0)
	assert_eq(DialogueBox.speed_for(cfg, 0), 30.0)

func test_text_reveals_at_chars_per_second() -> void:
	box.say("Ana", "0123456789", 10.0)
	assert_eq(box.shown_chars(), 0)
	box.tick(0.5)
	assert_eq(box.shown_chars(), 5)
	assert_true(box.is_revealing())
	box.tick(10.0)
	assert_eq(box.shown_chars(), 10)
	assert_false(box.is_revealing())

func test_faster_speed_reveals_more() -> void:
	box.say("", "0123456789ABCDEF", 30.0)
	box.tick(0.1)
	var slow: int = box.shown_chars()
	box.say("", "0123456789ABCDEF", 120.0)
	box.tick(0.1)
	assert_gt(box.shown_chars(), slow)

func test_accept_completes_then_advances() -> void:
	watch_signals(box)
	box.say("Ana", "texto longo o bastante", 1.0)
	box.accept()
	assert_eq(box.shown_chars(), "texto longo o bastante".length(), "primeiro accept completa")
	assert_signal_not_emitted(box, "advanced")
	box.accept()
	assert_signal_emit_count(box, "advanced", 1)

func test_system_line_hides_name_plate() -> void:
	box.say("", "sistema", 100.0)
	assert_false(box._plate.visible)
	box.say("Ana", "fala", 100.0)
	assert_true(box._plate.visible)
	assert_eq(box._name.text, "Ana")

func test_choice_navigation_and_confirm() -> void:
	watch_signals(box)
	box.ask("Quer?", PackedStringArray(["A", "B", "C"]), 1000.0)
	box.move(1)
	assert_eq(box.cursor, 0, "cursor parado enquanto o texto aparece")
	box.accept()
	assert_signal_not_emitted(box, "chosen", "primeiro accept só completa o texto")
	box.move(1)
	assert_eq(box.cursor, 1)
	box.move(-2)
	assert_eq(box.cursor, 2, "dá a volta")
	box.move(1)
	box.move(1)
	assert_eq(box.cursor, 1)
	box.accept()
	assert_signal_emitted_with_parameters(box, "chosen", [1])

func test_close_stops_input_handling() -> void:
	watch_signals(box)
	box.say("", "x", 1000.0)
	box.close()
	box.accept()
	assert_signal_not_emitted(box, "advanced")
	assert_false(box.visible)

func test_key_in_the_frame_that_opened_the_box_is_ignored() -> void:
	watch_signals(box)
	box.say("", "abc", 1000.0)
	box.tick(1.0)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	box._input(ev)
	assert_signal_not_emitted(box, "advanced", "tecla do mesmo quadro da abertura não avança")
	await get_tree().process_frame
	box._input(ev)
	assert_signal_emit_count(box, "advanced", 1)

# --- EventPlayer ---------------------------------------------------------------

func test_event_runs_dialogue_to_the_end() -> void:
	_make_game()
	await _enter_area()
	var flag := SetFlagStep.new()
	flag.flag = &"fim"
	var script: EventScript = _script([_say("um", "Ana"), _say("dois"), flag] as Array[EventStep])
	game.play_event(script)
	var d: DialogueBox = game.event_player.dialogue
	assert_true(game.event_player.active)
	assert_true(d.is_open)
	assert_eq(d._name.text, "Ana")
	d.accept()
	d.accept()
	assert_true(d.is_open, "segunda fala")
	assert_eq(d._body.text, "dois")
	assert_eq(game.state.get_flag(&"fim"), 0)
	d.accept()
	d.accept()
	assert_false(game.event_player.active)
	assert_false(d.is_open)
	assert_eq(game.state.get_flag(&"fim"), 1)

func test_event_text_speed_follows_settings() -> void:
	_make_game()
	await _enter_area()
	game.state.settings.text_speed = 3
	game.play_event(_script([_say("x")] as Array[EventStep]))
	assert_eq(game.event_player.dialogue.chars_per_second, 120.0)
	game.event_player.cancel()
	game.state.settings.text_speed = 1
	game.play_event(_script([_say("x")] as Array[EventStep]))
	assert_eq(game.event_player.dialogue.chars_per_second, 30.0)
	game.event_player.cancel()

func test_choice_event_stores_answer_in_flag() -> void:
	_make_game()
	await _enter_area()
	var c := ChoiceStep.new()
	c.prompt = "Quer?"
	c.options = PackedStringArray(["Sim", "Não"])
	c.flag = &"resp"
	game.play_event(_script([c] as Array[EventStep]))
	var d: DialogueBox = game.event_player.dialogue
	assert_eq(d.options, PackedStringArray(["Sim", "Não"]))
	d.accept()
	d.move(1)
	d.accept()
	assert_eq(game.state.get_flag(&"resp"), 1)
	assert_false(game.event_player.active)

func test_map_is_frozen_during_event_and_released_after() -> void:
	_make_game()
	await _enter_area()
	var enemy: MapEnemy = map.enemies()[0]
	map.player.override_dir = Vector2.RIGHT
	game.play_event(_script([_say("x")] as Array[EventStep]))
	assert_true(map.event_active)
	assert_false(map.player.enabled, "jogador parado")
	assert_true(enemy.frozen, "inimigos parados")
	assert_false(map.exit_zone.armed, "saída desarmada")
	assert_false(game.can_open_menu(), "menu de campo não abre")
	assert_false(game.open_menu())
	var p0: Vector2 = map.player.global_position
	var e0: Vector2 = enemy.global_position
	await wait_physics_frames(20)
	assert_eq(map.player.global_position, p0)
	assert_eq(enemy.global_position, e0)
	game.event_player.dialogue.accept()
	game.event_player.dialogue.accept()
	assert_false(map.event_active)
	assert_true(map.player.enabled)
	assert_false(enemy.frozen)
	assert_true(map.exit_zone.armed)
	assert_true(game.can_open_menu())

func test_second_event_is_ignored_while_one_runs() -> void:
	_make_game()
	await _enter_area()
	game.play_event(_script([_say("primeiro")] as Array[EventStep]))
	game.play_event(_script([_say("segundo")] as Array[EventStep]))
	assert_eq(game.event_player.dialogue._body.text, "primeiro")
	game.event_player.cancel()

func test_move_actor_reaches_marker() -> void:
	_make_game()
	await _enter_area()
	var marker := Marker2D.new()
	marker.name = "Alvo"
	marker.position = map.player.position + Vector2(100, 0)
	map.add_child(marker)
	var mv := MoveActorStep.new()
	mv.actor = ^"Player"
	mv.to_marker = ^"Alvo"
	mv.speed = 1000.0
	var done := SetFlagStep.new()
	done.flag = &"chegou"
	game.play_event(_script([mv, done] as Array[EventStep]))
	assert_true(game.event_player.active)
	var guard: int = 0
	while game.event_player.active and guard < 200:
		await get_tree().process_frame
		guard += 1
	assert_false(game.event_player.active, "evento terminou")
	assert_eq(map.player.global_position, marker.global_position)
	assert_eq(game.state.get_flag(&"chegou"), 1)

func test_move_actor_missing_node_does_not_hang() -> void:
	_make_game()
	await _enter_area()
	var mv := MoveActorStep.new()
	mv.actor = ^"Fantasma"
	mv.to_marker = ^"Nada"
	game.play_event(_script([mv, _say("depois")] as Array[EventStep]))
	assert_push_error("MoveActor")
	assert_true(game.event_player.dialogue.is_open, "seguiu para a fala seguinte")
	game.event_player.cancel()

func test_wait_and_camera_steps_finish_and_camera_follows_again() -> void:
	_make_game()
	await _enter_area()
	var marker := Marker2D.new()
	marker.name = "Alvo"
	marker.position = map.player.position + Vector2(300, 0)
	map.add_child(marker)
	game.state.cfg.event_camera_time = 0.05
	var w := WaitStep.new()
	w.seconds = 0.05
	var cam := CameraToStep.new()
	cam.marker = ^"Alvo"
	game.play_event(_script([w, cam] as Array[EventStep]))
	var guard: int = 0
	while game.event_player.active and guard < 300:
		await get_tree().process_frame
		guard += 1
	assert_false(game.event_player.active)
	assert_false(map._camera_detached)

func test_cancel_stops_event_and_releases_map() -> void:
	_make_game()
	await _enter_area()
	var flag := SetFlagStep.new()
	flag.flag = &"nao"
	game.play_event(_script([_say("x"), flag] as Array[EventStep]))
	game.event_player.cancel()
	assert_false(game.event_player.active)
	assert_false(game.event_player.dialogue.is_open)
	assert_false(map.event_active)
	assert_eq(game.state.get_flag(&"nao"), 0)
	game.event_player.cancel()

func test_changing_map_cancels_event() -> void:
	_make_game()
	await _enter_area()
	game.play_event(_script([_say("x")] as Array[EventStep]))
	game.go_to(&"overworld", &"Start", false)
	await _wait_idle()
	assert_false(game.event_player.active)
	assert_false(game.event_player.dialogue.is_open)
	game.play_event(_script([_say("y")] as Array[EventStep]))
	assert_false(game.event_player.active, "evento só roda em área local")

func test_game_over_cancels_event() -> void:
	_make_game()
	await _enter_area()
	game.play_event(_script([_say("x")] as Array[EventStep]))
	map.game_over.emit()
	assert_false(game.event_player.active)
	assert_false(game.event_player.dialogue.is_open)
	game.game_over_screen.queue_free()
	game.game_over_screen = null

func test_start_battle_waits_for_victory_then_continues() -> void:
	_make_game()
	await _enter_area()
	map.auto_battle = true
	var sb := StartBattleStep.new()
	sb.encounter = _weak_encounter()
	game.play_event(_script([sb, _say("pós-batalha")] as Array[EventStep]))
	assert_not_null(map.battle, "batalha começou")
	assert_false(game.event_player.dialogue.is_open, "espera a batalha")
	map.battle.set_process(false)
	map.battle.finished.emit(BattleController.Outcome.VICTORY)
	assert_null(map.battle)
	assert_true(game.event_player.dialogue.is_open, "retomou depois da vitória")
	assert_false(map.player.enabled, "mundo segue parado até o fim do evento")
	assert_true(map.event_active)
	game.event_player.cancel()
	assert_true(map.player.enabled)

func test_say_before_start_battle_closes_the_box_so_the_battle_gets_the_input() -> void:
	_make_game()
	await _enter_area()
	map.auto_battle = true
	var sb := StartBattleStep.new()
	sb.encounter = _weak_encounter()
	game.play_event(_script([_say("aviso"), sb] as Array[EventStep]))
	assert_true(game.event_player.dialogue.is_open, "o aviso aparece")
	game.event_player.dialogue.accept()
	game.event_player.dialogue.accept()
	assert_not_null(map.battle, "a batalha começou")
	assert_false(game.event_player.dialogue.is_open, "a caixa não fica aberta sobre a batalha (consumiria o Enter)")
	map.battle.set_process(false)
	map.battle.finished.emit(BattleController.Outcome.VICTORY)
	game.event_player.cancel()

func test_start_battle_defeat_is_game_over_not_continue() -> void:
	_make_game()
	await _enter_area()
	map.auto_battle = true
	var sb := StartBattleStep.new()
	sb.encounter = _weak_encounter()
	var after := SetFlagStep.new()
	after.flag = &"depois"
	game.play_event(_script([sb, after] as Array[EventStep]))
	map.battle.set_process(false)
	map.battle.finished.emit(BattleController.Outcome.DEFEAT)
	assert_false(game.event_player.active)
	assert_eq(game.state.get_flag(&"depois"), 0)
	assert_not_null(game.game_over_screen)
	game.game_over_screen.queue_free()
	game.game_over_screen = null

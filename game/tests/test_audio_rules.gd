extends GutTest

var defaults: Dictionary

func before_each() -> void:
	defaults = AudioRules.make_defaults({"battle_music": &"batalha", "victory_jingle": &"vitoria", "defeat_jingle": &"derrota"})

func _op(cmds: Array[Dictionary], i: int = 0) -> int:
	return int(cmds[i]["op"])

func test_enter_map_plays_map_music_with_half_second_fade() -> void:
	var c: Array[Dictionary] = AudioRules.on_enter_map(AudioRules.make_snapshot({"map_music": &"cidade"}))
	assert_eq(c.size(), 1)
	assert_eq(_op(c), AudioRules.Op.PLAY_MUSIC)
	assert_eq(c[0]["id"], &"cidade")
	assert_almost_eq(float(c[0]["fade"]), 0.5, 0.0001)

func test_enter_map_same_track_does_not_restart() -> void:
	var c: Array[Dictionary] = AudioRules.on_enter_map(AudioRules.make_snapshot({"map_music": &"cidade", "current": &"cidade"}))
	assert_eq(_op(c), AudioRules.Op.NOOP)

func test_enter_map_with_other_track_switches() -> void:
	var c: Array[Dictionary] = AudioRules.on_enter_map(AudioRules.make_snapshot({"map_music": &"masmorra", "current": &"cidade"}))
	assert_eq(_op(c), AudioRules.Op.PLAY_MUSIC)
	assert_eq(c[0]["id"], &"masmorra")

func test_enter_map_without_music_stops_current_or_does_nothing() -> void:
	var c: Array[Dictionary] = AudioRules.on_enter_map(AudioRules.make_snapshot({"current": &"cidade"}))
	assert_eq(_op(c), AudioRules.Op.STOP_MUSIC)
	c = AudioRules.on_enter_map(AudioRules.make_snapshot())
	assert_eq(_op(c), AudioRules.Op.NOOP)

func test_battle_start_uses_encounter_track() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"cidade", "in_battle": true, "battle_music": &"emboscada"})
	var c: Array[Dictionary] = AudioRules.on_battle_start(snap, defaults)
	assert_eq(_op(c), AudioRules.Op.PLAY_MUSIC)
	assert_eq(c[0]["id"], &"emboscada")

func test_battle_start_falls_back_to_default_battle_music() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"cidade", "in_battle": true})
	var c: Array[Dictionary] = AudioRules.on_battle_start(snap, defaults)
	assert_eq(c[0]["id"], &"batalha")

func test_battle_start_without_any_track_keeps_map_music() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"cidade", "in_battle": true})
	var c: Array[Dictionary] = AudioRules.on_battle_start(snap, AudioRules.make_defaults())
	assert_eq(c.size(), 1)
	assert_eq(_op(c), AudioRules.Op.NOOP)

func test_battle_start_same_track_does_not_restart() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"current": &"batalha", "in_battle": true})
	assert_eq(_op(AudioRules.on_battle_start(snap, defaults)), AudioRules.Op.NOOP)

func test_boss_uses_boss_default_only_when_no_own_track() -> void:
	var d: Dictionary = AudioRules.make_defaults({"battle_music": &"batalha", "boss_music": &"chefe"})
	var boss: Dictionary = AudioRules.make_snapshot({"in_battle": true, "boss": true})
	assert_eq(AudioRules.on_battle_start(boss, d)[0]["id"], &"chefe")
	boss["battle_music"] = &"chefe_x"
	assert_eq(AudioRules.on_battle_start(boss, d)[0]["id"], &"chefe_x")
	var plain: Dictionary = AudioRules.make_snapshot({"in_battle": true})
	assert_eq(AudioRules.on_battle_start(plain, d)[0]["id"], &"batalha")

func test_victory_plays_jingle_then_resumes_map_music() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"batalha", "outcome": AudioRules.Outcome.VICTORY})
	var c: Array[Dictionary] = AudioRules.on_battle_end(snap, defaults)
	assert_eq(_op(c), AudioRules.Op.PLAY_JINGLE)
	assert_eq(c[0]["id"], &"vitoria")
	assert_true(c[0]["resume"])
	assert_eq(c[0]["next_id"], &"cidade")

func test_victory_without_jingle_returns_to_map_music() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"batalha", "outcome": AudioRules.Outcome.VICTORY})
	var c: Array[Dictionary] = AudioRules.on_battle_end(snap, AudioRules.make_defaults())
	assert_eq(_op(c), AudioRules.Op.PLAY_MUSIC)
	assert_eq(c[0]["id"], &"cidade")

func test_victory_on_silent_map_resumes_to_silence() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"current": &"batalha", "outcome": AudioRules.Outcome.VICTORY})
	var c: Array[Dictionary] = AudioRules.on_battle_end(snap, defaults)
	assert_eq(_op(c), AudioRules.Op.PLAY_JINGLE)
	assert_eq(c[0]["next_id"], &"")
	c = AudioRules.on_battle_end(snap, AudioRules.make_defaults())
	assert_eq(_op(c), AudioRules.Op.STOP_MUSIC)

func test_defeat_plays_defeat_jingle_without_resuming() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"batalha", "outcome": AudioRules.Outcome.DEFEAT})
	var c: Array[Dictionary] = AudioRules.on_battle_end(snap, defaults)
	assert_eq(_op(c), AudioRules.Op.PLAY_JINGLE)
	assert_eq(c[0]["id"], &"derrota")
	assert_false(c[0]["resume"])
	c = AudioRules.on_battle_end(snap, AudioRules.make_defaults())
	assert_eq(_op(c), AudioRules.Op.STOP_MUSIC)

func test_fled_goes_straight_back_without_jingle() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"batalha", "outcome": AudioRules.Outcome.FLED})
	var c: Array[Dictionary] = AudioRules.on_battle_end(snap, defaults)
	assert_eq(c.size(), 1)
	assert_eq(_op(c), AudioRules.Op.PLAY_MUSIC)
	assert_eq(c[0]["id"], &"cidade")

func test_fled_when_battle_had_no_own_track_does_not_restart_map_music() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"cidade", "outcome": AudioRules.Outcome.FLED})
	assert_eq(_op(AudioRules.on_battle_end(snap, AudioRules.make_defaults())), AudioRules.Op.NOOP)

func test_outcome_none_does_nothing() -> void:
	assert_eq(_op(AudioRules.on_battle_end(AudioRules.make_snapshot({"current": &"batalha"}), defaults)), AudioRules.Op.NOOP)

func test_event_music_overrides_map_music() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"cidade", "event_music": &"tensao"})
	var c: Array[Dictionary] = AudioRules.on_event_music(snap)
	assert_eq(_op(c), AudioRules.Op.PLAY_MUSIC)
	assert_eq(c[0]["id"], &"tensao")
	snap["current"] = &"tensao"
	assert_eq(_op(AudioRules.on_event_music(snap)), AudioRules.Op.NOOP, "mesma faixa nao reinicia")

func test_event_override_survives_entering_a_map_until_it_changes() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"masmorra", "current": &"tensao", "event_music": &"tensao"})
	assert_eq(_op(AudioRules.on_enter_map(snap)), AudioRules.Op.NOOP)
	snap["event_music"] = &""
	var c: Array[Dictionary] = AudioRules.on_enter_map(snap)
	assert_eq(c[0]["id"], &"masmorra")

func test_event_stop_is_silence() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": &"cidade", "event_music": AudioRules.EVENT_STOP})
	assert_eq(_op(AudioRules.on_event_music(snap)), AudioRules.Op.STOP_MUSIC)
	snap["current"] = &""
	assert_eq(_op(AudioRules.on_event_music(snap)), AudioRules.Op.NOOP)

func test_event_music_during_battle_waits_for_the_field() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"current": &"batalha", "in_battle": true, "event_music": &"tensao"})
	assert_eq(_op(AudioRules.on_event_music(snap)), AudioRules.Op.NOOP)

func test_victory_returns_to_event_override_not_map_music() -> void:
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "event_music": &"tensao", "current": &"batalha", "outcome": AudioRules.Outcome.VICTORY})
	assert_eq(AudioRules.on_battle_end(snap, defaults)[0]["next_id"], &"tensao")

func test_empty_ids_never_error_in_any_rule() -> void:
	var empty: Dictionary = AudioRules.make_snapshot()
	var d: Dictionary = AudioRules.make_defaults()
	for outcome: int in [AudioRules.Outcome.NONE, AudioRules.Outcome.VICTORY, AudioRules.Outcome.DEFEAT, AudioRules.Outcome.FLED]:
		empty["outcome"] = outcome
		assert_eq(_op(AudioRules.on_battle_end(empty, d)), AudioRules.Op.NOOP)
	assert_eq(_op(AudioRules.on_enter_map(empty)), AudioRules.Op.NOOP)
	assert_eq(_op(AudioRules.on_battle_start(empty, d)), AudioRules.Op.NOOP)
	assert_eq(_op(AudioRules.on_event_music(empty)), AudioRules.Op.NOOP)

func test_snapshot_ignores_unknown_keys_and_has_defaults() -> void:
	var s: Dictionary = AudioRules.make_snapshot({"zzz": 1})
	assert_false(s.has("zzz"))
	assert_eq(s["outcome"], AudioRules.Outcome.NONE)
	assert_false(s["in_battle"])

func test_pitch_scale_stays_in_range() -> void:
	assert_almost_eq(AudioRules.pitch_scale(0.0, 1.0), 1.0, 0.0001)
	assert_almost_eq(AudioRules.pitch_scale(0.2, 1.0), 1.2, 0.0001)
	assert_almost_eq(AudioRules.pitch_scale(0.2, -1.0), 0.8, 0.0001)
	assert_almost_eq(AudioRules.pitch_scale(5.0, -1.0), 0.01, 0.0001, "variacao e limitada a 1; nunca tom zero")
	assert_almost_eq(AudioRules.pitch_scale(0.5, 9.0), 1.5, 0.0001, "sorteio fora de faixa e cortado")

func test_level_to_db() -> void:
	assert_almost_eq(AudioBuses.level_to_db(10, 10), 0.0, 0.0001)
	assert_almost_eq(AudioBuses.level_to_db(0, 10), -80.0, 0.0001)
	assert_almost_eq(AudioBuses.level_to_db(5, 10), linear_to_db(0.5), 0.0001)

func test_sound_bank_lookup_and_errors() -> void:
	var bank := SoundBank.new()
	assert_eq(bank.errors().size(), 0, "banco vazio e valido")
	var a := SoundDef.new()
	a.id = &"a"
	var a2 := SoundDef.new()
	a2.id = &"a"
	var empty := SoundDef.new()
	var m := MusicDef.new()
	m.id = &"m"
	var m2 := MusicDef.new()
	m2.id = &"m"
	bank.sounds = [a, a2, empty]
	bank.musics = [m, m2]
	assert_eq(bank.find_sound(&"a"), a)
	assert_null(bank.find_sound(&"zz"))
	assert_null(bank.find_sound(&""))
	assert_eq(bank.find_music(&"m"), m)
	assert_null(bank.find_music(&""))
	assert_eq(bank.errors().size(), 3, "id repetido de som, id vazio de som e id repetido de musica")

func test_shipped_bank_loads_and_is_valid() -> void:
	var bank: SoundBank = load("res://data/audio/sons.tres") as SoundBank
	assert_not_null(bank)
	assert_eq(bank.errors().size(), 0)

func test_sound_def_bus_names() -> void:
	var s := SoundDef.new()
	assert_eq(s.bus_name(), AudioBuses.EFFECTS)
	s.bus = SoundDef.Bus.INTERFACE
	assert_eq(s.bus_name(), AudioBuses.INTERFACE)

func test_default_bus_layout_has_four_buses_with_parents() -> void:
	var layout: AudioBusLayout = load("res://default_bus_layout.tres") as AudioBusLayout
	assert_not_null(layout)
	assert_eq(ProjectSettings.get_setting("audio/buses/default_bus_layout"), "res://default_bus_layout.tres")
	assert_eq(layout.get("bus/1/name"), AudioBuses.MUSIC)
	assert_eq(layout.get("bus/2/name"), AudioBuses.EFFECTS)
	assert_eq(layout.get("bus/3/name"), AudioBuses.INTERFACE)
	for i: int in [1, 2, 3]:
		assert_eq(layout.get("bus/%d/send" % i), AudioBuses.MASTER)
	assert_null(layout.get("bus/4/name"), "so quatro barramentos contando o Master")

extends GutTest

## O AudioDirector em modo headless: nenhum player e criado, so o estado e conferido. O ramo com som real nao roda
## aqui (nao ha driver de audio nos testes).

const GAME_SCENE: String = "res://world/game.tscn"

var director: AudioDirector
var bank: SoundBank

static func make_wav(seconds: float = 0.05) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 8000
	w.stereo = false
	var n: int = maxi(1, int(seconds * 8000.0))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i: int in n:
		data.encode_s16(i * 2, int(sin(float(i) * 0.2) * 8000.0))
	w.data = data
	return w

static func music(id: StringName, with_stream: bool = true, seconds: float = 0.05) -> MusicDef:
	var m := MusicDef.new()
	m.id = id
	m.stream = make_wav(seconds) if with_stream else null
	return m

static func sound(id: StringName, with_stream: bool = true) -> SoundDef:
	var s := SoundDef.new()
	s.id = id
	s.stream = make_wav() if with_stream else null
	return s

func before_each() -> void:
	director = AudioDirector.new()
	director.audible = false
	add_child_autofree(director)
	bank = SoundBank.new()
	bank.musics = [music(&"cidade"), music(&"batalha"), music(&"vitoria"), music(&"mudo", false)]
	bank.sounds = [sound(&"golpe"), sound(&"mudo", false)]

func test_headless_creates_no_players() -> void:
	var fresh := AudioDirector.new()
	add_child_autofree(fresh)
	assert_false(fresh.audible, "o jogo headless nao toca")
	assert_eq(fresh.get_child_count(), 0)

func test_play_music_sets_state_and_same_track_does_not_restart() -> void:
	director.play_music(bank.find_music(&"cidade"), 0.5)
	assert_eq(director.current_music_id, &"cidade")
	assert_eq(director.music_changes, 1)
	director.play_music(bank.find_music(&"cidade"), 0.5)
	assert_eq(director.music_changes, 1, "a mesma faixa nao reinicia")
	director.play_music(bank.find_music(&"batalha"), 0.0)
	assert_eq(director.current_music_id, &"batalha")
	assert_eq(director.music_changes, 2)

func test_stop_music() -> void:
	director.play_music(bank.find_music(&"cidade"))
	director.stop_music(0.3)
	assert_eq(director.current_music_id, &"")
	assert_eq(director.music_changes, 2)
	director.stop_music()
	assert_eq(director.music_changes, 2, "parar o silencio nao conta")

func test_missing_stream_or_def_is_ignored() -> void:
	director.play_music(bank.find_music(&"mudo"))
	director.play_music(null)
	assert_eq(director.current_music_id, &"")
	director.play_sfx(bank.find_sound(&"mudo"))
	director.play_sfx(null)
	assert_eq(director.sfx_played, 0)
	director.play_jingle(bank.find_music(&"mudo"))
	assert_eq(director.current_jingle_id, &"")

func test_sfx_records_state_and_respects_cooldown() -> void:
	var s: SoundDef = bank.find_sound(&"golpe")
	s.cooldown = 0.5
	director.play_sfx(s, Vector2(3, 4))
	assert_eq(director.last_sfx_id, &"golpe")
	assert_eq(director.last_sfx_position, Vector2(3, 4))
	assert_eq(director.sfx_played, 1)
	director.play_sfx(s)
	assert_eq(director.sfx_played, 1, "em cooldown")
	director.clock_offset += 0.6
	director.play_sfx(s)
	assert_eq(director.sfx_played, 2)
	s.cooldown = 0.0
	director.play_sfx(s)
	director.play_sfx(s)
	assert_eq(director.sfx_played, 4, "sem cooldown toca sempre")

func test_sfx_pitch_stays_within_variation_and_volume_is_kept() -> void:
	var s: SoundDef = bank.find_sound(&"golpe")
	s.pitch_variation = 0.2
	s.volume_db = -6.0
	var lo: float = 9.0
	var hi: float = 0.0
	for i: int in 60:
		director.play_sfx(s)
		lo = minf(lo, director.last_sfx_pitch)
		hi = maxf(hi, director.last_sfx_pitch)
	assert_between(lo, 0.8, 1.2)
	assert_between(hi, 0.8, 1.2)
	assert_gt(hi - lo, 0.05, "o tom realmente varia")
	assert_almost_eq(director.last_sfx_db, -6.0, 0.0001)
	s.pitch_variation = 0.0
	director.play_sfx(s)
	assert_almost_eq(director.last_sfx_pitch, 1.0, 0.0001)

func test_jingle_silences_music_then_resumes_after_it_ends() -> void:
	director.play_music(bank.find_music(&"batalha"))
	director.play_jingle(bank.find_music(&"vitoria"), true, &"cidade", bank)
	assert_eq(director.current_jingle_id, &"vitoria")
	assert_eq(director.current_music_id, &"")
	await wait_seconds(0.2)
	assert_eq(director.current_jingle_id, &"")
	assert_eq(director.current_music_id, &"cidade")

func test_jingle_without_resume_leaves_silence() -> void:
	director.play_music(bank.find_music(&"batalha"))
	director.play_jingle(bank.find_music(&"vitoria"), false, &"cidade", bank)
	await wait_seconds(0.2)
	assert_eq(director.current_jingle_id, &"")
	assert_eq(director.current_music_id, &"")

func test_new_music_cancels_pending_resume() -> void:
	director.play_jingle(bank.find_music(&"vitoria"), true, &"cidade", bank)
	director.play_music(bank.find_music(&"batalha"))
	await wait_seconds(0.2)
	assert_eq(director.current_music_id, &"batalha", "o jingle antigo nao sobrescreve a musica nova")

func test_duck_sets_and_releases() -> void:
	director.duck_music(-12.0, 0.05)
	assert_almost_eq(director.duck_db, -12.0, 0.0001)
	await wait_seconds(0.2)
	assert_almost_eq(director.duck_db, 0.0, 0.0001)

func test_run_executes_rules_commands() -> void:
	var defaults: Dictionary = AudioRules.make_defaults({"battle_music": &"batalha", "victory_jingle": &"vitoria"})
	director.run(AudioRules.on_enter_map(AudioRules.make_snapshot({"map_music": &"cidade"})), bank)
	assert_eq(director.current_music_id, &"cidade")
	director.run(AudioRules.on_enter_map(AudioRules.make_snapshot({"map_music": &"cidade", "current": director.current_music_id})), bank)
	assert_eq(director.music_changes, 1, "mesma faixa: sem reinicio")
	director.run(AudioRules.on_battle_start(AudioRules.make_snapshot({"current": director.current_music_id, "in_battle": true}), defaults), bank)
	assert_eq(director.current_music_id, &"batalha")
	var snap: Dictionary = AudioRules.make_snapshot({"map_music": &"cidade", "current": director.current_music_id, "outcome": AudioRules.Outcome.VICTORY})
	director.run(AudioRules.on_battle_end(snap, defaults), bank)
	assert_eq(director.current_jingle_id, &"vitoria")
	await wait_seconds(0.2)
	assert_eq(director.current_music_id, &"cidade")

func test_run_with_unknown_or_empty_ids_is_harmless() -> void:
	director.play_music(bank.find_music(&"cidade"))
	director.run([AudioRules.play_music(&"nao_existe", 0.1)] as Array[Dictionary], bank)
	assert_eq(director.current_music_id, &"", "id desconhecido vira silencio")
	director.run([AudioRules.noop(), AudioRules.stop_music(0.0), AudioRules.play_jingle(&"nada", true, &"cidade")] as Array[Dictionary], bank)
	assert_eq(director.current_music_id, &"cidade", "sem jingle a retomada acontece direto")
	director.run([AudioRules.play_music(&"cidade", 0.0)] as Array[Dictionary], null)
	assert_eq(director.current_music_id, &"")

func test_bus_names_resolve_to_existing_buses() -> void:
	for bus: StringName in AudioBuses.ALL:
		assert_gte(AudioServer.get_bus_index(bus), 0, "barramento %s existe" % bus)
	var master: int = AudioServer.get_bus_index(AudioBuses.MASTER)
	for bus: StringName in [AudioBuses.MUSIC, AudioBuses.EFFECTS, AudioBuses.INTERFACE]:
		assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)), AudioBuses.MASTER)
	assert_eq(master, 0)
	assert_eq(AudioServer.bus_count, 4)

func test_game_applies_volumes_to_buses() -> void:
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	game.balance = cfg
	game.skip_title = true
	game.settings_path = "user://test_audio_unused.cfg"
	add_child_autofree(game)
	assert_not_null(game.audio, "o Game cria o diretor")
	assert_not_null(game.sound_bank, "e carrega o banco padrao")
	game.settings.volume = 10
	game.settings.music_volume = 5
	game.settings.effects_volume = 0
	game.apply_settings()
	var idx := func(b: StringName) -> int: return AudioServer.get_bus_index(b)
	assert_almost_eq(AudioServer.get_bus_volume_db(idx.call(AudioBuses.MASTER)), 0.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(idx.call(AudioBuses.MUSIC)), linear_to_db(0.5), 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(idx.call(AudioBuses.EFFECTS)), -80.0, 0.001)
	assert_almost_eq(AudioServer.get_bus_volume_db(idx.call(AudioBuses.INTERFACE)), -80.0, 0.001)
	game.settings.music_volume = 10
	game.settings.effects_volume = 10
	game.apply_settings()
	for b: StringName in AudioBuses.ALL:
		assert_almost_eq(AudioServer.get_bus_volume_db(idx.call(b)), 0.0, 0.001)

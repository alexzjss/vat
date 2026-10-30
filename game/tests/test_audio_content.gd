extends GutTest

## Conteudo de audio da fatia (M19, Task 3): o banco `data/fatia/audio/sons_fatia.tres` carrega, cada id referenciado
## nos dados existe, os placeholders sao pequenos e o gerador e deterministico. E, num Game real da fatia com o banco
## de verdade, a musica segue o mapa, a batalha, o chefe e o jingle de vitoria.

const FATIA_SCENE: String = "res://world/game_fatia.tscn"
const BANK_PATH: String = "res://data/fatia/audio/sons_fatia.tres"
const DEFAULT_BANK_PATH: String = "res://data/audio/sons.tres"
const AUDIO_DIR: String = "res://art/_exemplo/audio"
const GENERATOR: String = "res://tools/audio/gen_placeholders.py"
const MAX_BYTES: int = 400 * 1024
const FATIA_MAPS: Dictionary = {
	&"cidade": &"musica_cidade", &"casa_1": &"musica_cidade", &"casa_2": &"musica_cidade",
	&"overworld_fatia": &"musica_estrada", &"estrada": &"musica_estrada",
	&"dungeon_1": &"musica_masmorra", &"dungeon_2": &"musica_masmorra",
}

var bank: SoundBank
var game: Game

func before_each() -> void:
	bank = load(BANK_PATH) as SoundBank

# --- arquivos .tres de uma pasta, recursivo ---

static func _tres_in(dir: String, out: Array[String] = []) -> Array[String]:
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_tres_in(dir.path_join(d), out)
	return out

# --- o banco ---

func test_the_slice_bank_loads_without_errors_and_is_complete() -> void:
	assert_not_null(bank, "banco da fatia carrega")
	assert_eq(bank.errors(), [] as Array[String])
	assert_eq(bank.musics.size(), 7, "5 musicas e 2 jingles")
	assert_eq(bank.sounds.size(), 15, "15 efeitos")

func test_every_def_has_a_loadable_stream_a_valid_bus_and_a_unique_id() -> void:
	var seen: Dictionary[StringName, bool] = {}
	for m: MusicDef in bank.musics:
		assert_false(seen.has(m.id), "id unico: %s" % m.id)
		seen[m.id] = true
		assert_true(m.stream is AudioStreamWAV, "%s tem stream" % m.id)
		assert_gt(m.stream.get_length(), 0.5, "%s tem duracao" % m.id)
		assert_eq(m.loop, not String(m.id).begins_with("jingle"), "%s: laco so nas musicas" % m.id)
	for s: SoundDef in bank.sounds:
		assert_false(seen.has(s.id), "id unico: %s" % s.id)
		seen[s.id] = true
		assert_true(s.stream is AudioStreamWAV, "%s tem stream" % s.id)
		assert_lt(s.stream.get_length(), 0.7, "%s e curto" % s.id)
		assert_true(s.bus_name() == AudioBuses.EFFECTS or s.bus_name() == AudioBuses.INTERFACE, "%s: barramento valido" % s.id)
		assert_between(s.pitch_variation, 0.0, 0.2, "%s: variacao pequena" % s.id)

func test_the_menu_and_text_sounds_use_the_interface_bus() -> void:
	for id: StringName in [&"sfx_menu_mover", &"sfx_menu_confirmar", &"sfx_menu_cancelar", &"sfx_texto"]:
		assert_eq(bank.find_sound(id).bus_name(), AudioBuses.INTERFACE, String(id))
	assert_eq(bank.find_sound(&"sfx_golpe").bus_name(), AudioBuses.EFFECTS)

func test_the_project_default_bank_stays_empty() -> void:
	var def: SoundBank = load(DEFAULT_BANK_PATH) as SoundBank
	assert_eq(def.sounds.size(), 0)
	assert_eq(def.musics.size(), 0)

# --- ids referenciados ---

func _check_sound(id: StringName, where: String) -> void:
	if id != &"":
		assert_not_null(bank.find_sound(id), "%s: som '%s' existe no banco" % [where, id])

func _check_music(id: StringName, where: String) -> void:
	if id != &"":
		assert_not_null(bank.find_music(id), "%s: musica '%s' existe no banco" % [where, id])

func test_the_slice_balance_audio_ids_exist_and_the_rest_equals_the_test_balance() -> void:
	var cfg: BalanceConfig = load("res://data/fatia/balance_fatia.tres") as BalanceConfig
	for id: StringName in [cfg.default_battle_music, cfg.boss_battle_music, cfg.victory_jingle, cfg.defeat_jingle]:
		assert_ne(id, &"")
		_check_music(id, "balance_fatia")
	for id: StringName in [cfg.sfx_menu_move, cfg.sfx_menu_confirm, cfg.sfx_menu_cancel, cfg.sfx_text_tick,
			cfg.sfx_open_chest, cfg.sfx_open_door, cfg.sfx_step, cfg.sfx_level_up]:
		assert_ne(id, &"")
		_check_sound(id, "balance_fatia")
	# Tudo que nao e de audio e identico ao balance de teste.
	var base: BalanceConfig = load("res://data/test/balance.tres") as BalanceConfig
	var audio_props: Array[String] = ["default_battle_music", "boss_battle_music", "victory_jingle", "defeat_jingle",
			"sfx_menu_move", "sfx_menu_confirm", "sfx_menu_cancel", "sfx_text_tick", "sfx_open_chest", "sfx_open_door",
			"sfx_step", "sfx_level_up"]
	var compared: int = 0
	for p: Dictionary in cfg.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or audio_props.has(String(p["name"])):
			continue
		var a: Variant = cfg.get(p["name"])
		var b: Variant = base.get(p["name"])
		if a is Array:
			assert_eq((a as Array).size(), (b as Array).size(), String(p["name"]))
		else:
			assert_eq(a, b, String(p["name"]))
		compared += 1
	assert_gt(compared, 50, "propriedades comparadas")
	# O balance de teste (e o banco padrao) continuam sem audio.
	assert_eq(base.default_battle_music, &"")
	assert_eq(base.sfx_step, &"")

func test_the_slice_maps_and_the_boss_encounter_reference_existing_music() -> void:
	var reg: MapRegistry = load("res://data/maps/registro.tres") as MapRegistry
	for id: StringName in FATIA_MAPS:
		var d: MapDef = reg.find(id)
		assert_eq(d.music, FATIA_MAPS[id], "musica de %s" % id)
		_check_music(d.music, "mapa " + String(id))
	for id: StringName in [&"overworld", &"area_teste", &"dungeon_teste"]:
		assert_eq(reg.find(id).music, &"", "mapa de teste %s sem musica" % id)
	var boss: EncounterDef = load("res://data/fatia/encounters/chefe_fatia.tres") as EncounterDef
	assert_eq(boss.music, &"musica_chefe")
	for path: String in _tres_in("res://data/fatia/encounters"):
		var e: EncounterDef = load(path) as EncounterDef
		if e.id != &"chefe_fatia":
			assert_eq(e.music, &"", "%s usa a musica de batalha padrao" % e.id)

func test_every_audio_id_in_the_data_exists_in_the_bank() -> void:
	var checked: int = 0
	for dir: String in ["res://data/fatia", "res://data/elements", "res://data/reactions", "res://data/test", "res://data/maps"]:
		for path: String in _tres_in(dir):
			if path.begins_with("res://data/fatia/audio"):
				continue
			var res: Resource = load(path)
			if res is AbilityDef:
				_check_sound((res as AbilityDef).sfx_cast, path)
				_check_sound((res as AbilityDef).sfx_impact, path)
			elif res is ItemDef:
				_check_sound((res as ItemDef).sfx_use, path)
			elif res is EnemyDef:
				_check_sound((res as EnemyDef).sfx_hit, path)
				_check_sound((res as EnemyDef).sfx_down, path)
			elif res is CharacterDef:
				_check_sound((res as CharacterDef).sfx_hit, path)
				_check_sound((res as CharacterDef).sfx_down, path)
			elif res is ElementDef:
				_check_sound((res as ElementDef).sfx_hit, path)
			elif res is ReactionDef:
				_check_sound((res as ReactionDef).sfx, path)
			elif res is StatusDef:
				_check_sound((res as StatusDef).sfx_apply, path)
			elif res is EncounterDef:
				_check_music((res as EncounterDef).music, path)
			elif res is MapDef:
				_check_music((res as MapDef).music, path)
			else:
				continue
			checked += 1
	assert_gt(checked, 100, "defs conferidos")

func test_the_slice_abilities_heroes_and_enemies_have_sounds() -> void:
	for path: String in _tres_in("res://data/fatia/abilities"):
		var a: AbilityDef = load(path) as AbilityDef
		assert_eq(a.sfx_cast, &"sfx_conjurar", path)
		assert_eq(a.sfx_impact, &"sfx_golpe", path)
	for path: String in _tres_in("res://data/fatia/enemies"):
		assert_eq((load(path) as EnemyDef).sfx_down, &"sfx_queda", path)
	for path: String in _tres_in("res://data/fatia/heroes"):
		assert_eq((load(path) as CharacterDef).sfx_hit, &"sfx_acerto", path)
	assert_eq((load("res://data/test/statuses/poison.tres") as StatusDef).sfx_apply, &"sfx_estado")
	assert_eq((load("res://data/elements/kagutsuchi.tres") as ElementDef).sfx_hit, &"sfx_golpe")

# --- arquivos ---

func test_the_placeholder_folder_stays_small() -> void:
	var total: int = 0
	var wavs: int = 0
	for f: String in DirAccess.get_files_at(AUDIO_DIR):
		if f.ends_with(".wav"):
			total += FileAccess.get_file_as_bytes(AUDIO_DIR.path_join(f)).size()
			wavs += 1
	assert_eq(wavs, 22)
	assert_lt(total, MAX_BYTES, "total %d bytes" % total)

func test_the_generator_is_deterministic() -> void:
	var out: String = ProjectSettings.globalize_path("res://").path_join(".godot/audio_gen_test")
	DirAccess.make_dir_recursive_absolute(out)
	var script: String = ProjectSettings.globalize_path(GENERATOR)
	var code: int = -1
	var log: Array = []
	for exe: String in ["python", "py", "python3"]:
		code = OS.execute(exe, [script, out], log)
		if code == 0:
			break
	if code != 0:
		pending("python indisponivel; gerador nao conferido")
		return
	var compared: int = 0
	for f: String in DirAccess.get_files_at(AUDIO_DIR):
		if f.ends_with(".wav"):
			var a: PackedByteArray = FileAccess.get_file_as_bytes(AUDIO_DIR.path_join(f))
			var b: PackedByteArray = FileAccess.get_file_as_bytes(out.path_join(f))
			assert_eq(a, b, "%s identico ao gerado" % f)
			compared += 1
	assert_eq(compared, 22)
	for f: String in DirAccess.get_files_at(out):
		DirAccess.remove_absolute(out.path_join(f))
	DirAccess.remove_absolute(out)

# --- no jogo ---

func _start() -> void:
	game = (load(FATIA_SCENE) as PackedScene).instantiate() as Game
	game.balance = game.balance.duplicate() as BalanceConfig
	game.balance.fade_time = 0.01
	game.world_seed = 7
	game.skip_title = true
	game.save_dir = "user://test_audio_content_saves/"
	game.settings_path = "user://test_audio_content_unused.cfg"
	add_child_autofree(game)

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1

func _go(map: StringName) -> void:
	game.go_to(map, &"Entry", false)
	await _wait_idle()

func test_the_slice_game_uses_the_slice_bank_and_balance() -> void:
	_start()
	assert_eq(game.sound_bank.resource_path, BANK_PATH)
	assert_eq(game.balance.victory_jingle, &"jingle_vitoria")
	assert_eq(game.balance.default_battle_music, &"musica_batalha")

func test_the_music_follows_the_map_the_boss_the_victory_jingle_and_comes_back() -> void:
	_start()
	await _wait_idle()
	assert_eq(game.audio.current_music_id, &"musica_cidade", "o jogo comeca na cidade")
	await _go(&"dungeon_1")
	assert_eq(game.audio.current_music_id, &"musica_masmorra")
	# Luta comum: a musica de batalha padrao.
	game.audio_battle_start(&"", false)
	assert_eq(game.audio.current_music_id, &"musica_batalha")
	game.audio_battle_end(BattleController.Outcome.FLED)
	assert_eq(game.audio.current_music_id, &"musica_masmorra", "fugir volta ao campo")
	# Chefe: a musica do encontro.
	var boss: EncounterDef = load("res://data/fatia/encounters/chefe_fatia.tres") as EncounterDef
	game.audio_battle_start(boss.music, SoundEvents.is_boss(boss))
	assert_eq(game.audio.current_music_id, &"musica_chefe")
	game.audio_battle_end(BattleController.Outcome.VICTORY)
	assert_eq(game.audio.current_jingle_id, &"jingle_vitoria", "vitoria toca o jingle")
	await get_tree().create_timer(2.6).timeout
	assert_eq(game.audio.current_jingle_id, &"", "o jingle acabou")
	assert_eq(game.audio.current_music_id, &"musica_masmorra", "e a musica do campo volta")

func test_the_overworld_and_the_houses_pick_their_music() -> void:
	_start()
	await _wait_idle()
	await _go(&"casa_1")
	assert_eq(game.audio.current_music_id, &"musica_cidade")
	await _go(&"cidade")
	assert_eq(game.audio.current_music_id, &"musica_cidade", "mesma musica entre mapas: sem reiniciar")
	await _go(&"estrada")
	assert_eq(game.audio.current_music_id, &"musica_estrada")

func _xp_requests(level_up_sound: StringName) -> Array[EventRequest]:
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.sfx_level_up = level_up_sound
	var hero: CharacterDef = load("res://data/fatia/heroes/teste_a_f.tres") as CharacterDef
	var g: GameState = GameState.new_game(cfg, [hero] as Array[CharacterDef], [], [], ScriptedDice.new(), &"cidade", &"Start")
	var step := GrantXpStep.new()
	step.amount = 100000
	var ev := EventScript.new()
	ev.steps = [step] as Array[EventStep]
	var r := EventRunner.new(ev, g)
	r.start()
	var out: Array[EventRequest] = []
	var guard: int = 0
	while not r.finished and guard < 50:
		guard += 1
		out.append(r.current())
		r.resume(0)
	return out

func test_xp_step_level_up_requests_the_level_up_sound_only_when_configured() -> void:
	var with_sound: Array[EventRequest] = _xp_requests(&"sfx_nivel")
	assert_eq(with_sound[0].kind, EventRequest.Kind.PLAY_SOUND)
	assert_eq(with_sound[0].sound_id, &"sfx_nivel")
	assert_eq(with_sound[1].kind, EventRequest.Kind.SAY)
	var without: Array[EventRequest] = _xp_requests(&"")
	assert_eq(without[0].kind, EventRequest.Kind.SAY, "sem som configurado, nada muda")

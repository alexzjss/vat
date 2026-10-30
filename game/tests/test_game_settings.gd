extends GutTest

var cfg: BalanceConfig
var s: GameSettings

func before_each() -> void:
	cfg = Fixtures.cfg()
	s = GameSettings.new(cfg)

func test_defaults() -> void:
	assert_eq(s.atb_mode, GameSettings.AtbMode.WAIT)
	assert_eq(s.battle_speed, 3)
	assert_almost_eq(s.speed_mult(), 1.0, 0.0001)
	assert_true(s.cursor_memory)
	assert_eq(s.text_speed, 2)
	assert_eq(s.volume, 10)
	assert_eq(s.music_volume, 10)
	assert_eq(s.effects_volume, 10)

func test_values_are_clamped() -> void:
	s.battle_speed = 99
	assert_eq(s.battle_speed, 5)
	assert_almost_eq(s.speed_mult(), 1.5, 0.0001)
	s.battle_speed = -3
	assert_eq(s.battle_speed, 1)
	assert_almost_eq(s.speed_mult(), 0.6, 0.0001)
	s.text_speed = 9
	assert_eq(s.text_speed, 3)
	s.text_speed = 0
	assert_eq(s.text_speed, 1)
	s.volume = 50
	assert_eq(s.volume, 10)
	s.volume = -1
	assert_eq(s.volume, 0)
	s.music_volume = 50
	assert_eq(s.music_volume, 10)
	s.music_volume = -1
	assert_eq(s.music_volume, 0)
	s.effects_volume = 50
	assert_eq(s.effects_volume, 10)
	s.effects_volume = -1
	assert_eq(s.effects_volume, 0)

func test_dict_round_trip() -> void:
	s.atb_mode = GameSettings.AtbMode.ACTIVE
	s.battle_speed = 5
	s.cursor_memory = false
	s.text_speed = 3
	s.volume = 4
	s.music_volume = 6
	s.effects_volume = 2
	var t := GameSettings.new(cfg)
	t.from_dict(s.to_dict())
	assert_eq(t.atb_mode, GameSettings.AtbMode.ACTIVE)
	assert_eq(t.battle_speed, 5)
	assert_false(t.cursor_memory)
	assert_eq(t.text_speed, 3)
	assert_eq(t.volume, 4)
	assert_eq(t.music_volume, 6)
	assert_eq(t.effects_volume, 2)

func test_old_settings_without_audio_volumes_load_with_defaults() -> void:
	var old: Dictionary = {"atb_mode": 1, "battle_speed": 4, "cursor_memory": false, "text_speed": 3, "volume": 5}
	s.from_dict(old)
	assert_eq(s.volume, 5)
	assert_eq(s.music_volume, 10)
	assert_eq(s.effects_volume, 10)
	assert_eq(s.battle_speed, 4)

func test_old_settings_file_without_audio_volumes_loads_with_defaults() -> void:
	var path: String = "user://test_settings_old.cfg"
	var cf := ConfigFile.new()
	cf.set_value(SettingsStore.SECTION, "volume", 3)
	cf.set_value(SettingsStore.SECTION, "battle_speed", 2)
	assert_eq(cf.save(path), OK)
	assert_true(SettingsStore.load_into(s, path))
	assert_eq(s.volume, 3)
	assert_eq(s.battle_speed, 2)
	assert_eq(s.music_volume, 10)
	assert_eq(s.effects_volume, 10)
	DirAccess.remove_absolute(path)

func test_audio_volumes_bad_types_ignored_and_out_of_range_clamped() -> void:
	s.music_volume = 4
	s.from_dict({"music_volume": "alto", "effects_volume": 99})
	assert_eq(s.music_volume, 4)
	assert_eq(s.effects_volume, 10)

func test_from_dict_ignores_missing_wrong_types_and_clamps() -> void:
	s.volume = 4
	s.from_dict({"volume": "alto", "battle_speed": 77, "cursor_memory": 1})
	assert_eq(s.volume, 4)
	assert_eq(s.battle_speed, 5)
	assert_true(s.cursor_memory)
	s.from_dict({})
	assert_eq(s.battle_speed, 5)

func test_store_round_trip_and_missing_file() -> void:
	var path: String = "user://test_settings.cfg"
	DirAccess.remove_absolute(path)
	assert_false(SettingsStore.load_into(s, path), "arquivo ausente mantem padroes")
	assert_eq(s.battle_speed, 3)
	s.atb_mode = GameSettings.AtbMode.ACTIVE
	s.volume = 7
	s.music_volume = 3
	s.effects_volume = 5
	assert_true(SettingsStore.save(s, path))
	var t := GameSettings.new(cfg)
	assert_true(SettingsStore.load_into(t, path))
	assert_eq(t.atb_mode, GameSettings.AtbMode.ACTIVE)
	assert_eq(t.volume, 7)
	assert_eq(t.music_volume, 3)
	assert_eq(t.effects_volume, 5)
	DirAccess.remove_absolute(path)

func test_speed_mult_scales_atb_only() -> void:
	var hs := HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 1)), cfg)
	var hero := Combatant.from_hero(hs, Vector2.ZERO)
	var foe := Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(10, 10, 5, 5)), &"x", Vector2.ZERO, cfg)
	var slow := BattleController.new(BattleState.create(cfg, ScriptedDice.new(), [hero], [foe]))
	slow.speed_mult = 0.5
	slow.tick(1.0)
	var half: float = hero.atb
	var hero2 := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 1)), cfg), Vector2.ZERO)
	var foe2 := Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(10, 10, 5, 5)), &"x", Vector2.ZERO, cfg)
	var normal := BattleController.new(BattleState.create(cfg, ScriptedDice.new(), [hero2], [foe2]))
	normal.tick(1.0)
	assert_gt(half, 0.0)
	assert_almost_eq(half * 2.0, hero2.atb, 0.0001)

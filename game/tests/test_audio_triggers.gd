extends GutTest

## Gatilhos de som e musica (M19) num Game real com um banco de teste: musica por mapa (sem reiniciar a mesma), batalha
## com e sem musica, vitoria, derrota e fuga, os passos de evento e os efeitos de menu, bau, porta, passos e texto.
## O audio e headless: so o estado do diretor e conferido.

const AD: GDScript = preload("res://tests/test_audio_director.gd")
const SCENE: String = "res://world/game.tscn"

var game: Game
var bank: SoundBank

func before_each() -> void:
	bank = SoundBank.new()
	bank.musics = [AD.music(&"cidade"), AD.music(&"masmorra"), AD.music(&"batalha"), AD.music(&"chefe"),
			AD.music(&"vitoria", true, 0.4), AD.music(&"derrota", true, 0.4)]
	bank.sounds = [AD.sound(&"passo"), AD.sound(&"bau"), AD.sound(&"porta"), AD.sound(&"tick"), AD.sound(&"move"),
			AD.sound(&"ok"), AD.sound(&"volta"), AD.sound(&"inimigo_hit"), AD.sound(&"inimigo_cai")]

func _registry(music_by_map: Dictionary) -> MapRegistry:
	var reg := MapRegistry.new()
	var defaults: MapRegistry = Game.default_registry()
	for id: StringName in music_by_map:
		var src: MapDef = defaults.find(id)
		var d := MapDef.new()
		d.id = id
		d.scene = src.scene
		d.kind = src.kind
		d.exit_spawn = src.exit_spawn
		d.music = music_by_map[id]
		reg.maps.append(d)
	return reg

## Um Game com o banco de teste e a musica por mapa dada. `setup` ajusta o BalanceConfig antes de entrar na arvore.
func _start(music_by_map: Dictionary, setup: Callable = Callable()) -> void:
	game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	if setup.is_valid():
		setup.call(cfg)
	game.balance = cfg
	game.world_seed = 7
	game.skip_title = true
	game.sound_bank = bank
	game.map_registry = _registry(music_by_map)
	game.settings_path = "user://test_audio_triggers_unused.cfg"
	add_child_autofree(game)

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	assert_false(game.busy, "transicao terminou")

func _go(map: StringName) -> void:
	game.go_to(map, &"Entry" if map != &"overworld" else &"Start")
	await _wait_idle()

func _enemy(id: StringName) -> EnemyDef:
	var d: EnemyDef = Fixtures.enemy_def(id, Stats.make(1, 1, 1, 0), 100)
	d.sfx_hit = &"inimigo_hit"
	d.sfx_down = &"inimigo_cai"
	return d

func _weak(music: StringName = &"", unique: StringName = &"") -> EncounterDef:
	var e := EncounterDef.new()
	e.id = &"fraco"
	e.music = music
	e.unique_id = unique
	e.enemies = [_enemy(&"x")] as Array[EnemyDef]
	return e

func _strong(music: StringName = &"") -> EncounterDef:
	var e := EncounterDef.new()
	e.id = &"forte"
	e.music = music
	var list: Array[EnemyDef] = []
	for id: StringName in [&"x", &"y"]:
		list.append(Fixtures.enemy_def(id, Stats.make(80, 40, 60, 0), 100))
	e.enemies = list
	return e

## Toca o inimigo do mapa e devolve a cena de batalha (sem rodar nada).
func _touch(map: LocalMap, enc: EncounterDef, auto: bool = true) -> BattleScene:
	map.auto_battle = auto
	map.dice_seed = 7
	var enemy: MapEnemy = map.enemies()[0]
	enemy.encounter = enc
	enemy.touched.emit(enemy)
	var s: BattleScene = map.battle
	assert_not_null(s, "batalha comecou")
	s.set_process(false)
	return s

func _run_battle(s: BattleScene) -> BattleController.Outcome:
	var steps: int = 0
	while s.ctrl.outcome == BattleController.Outcome.ONGOING and steps < 20000:
		s.ctrl.tick(0.1)
		steps += 1
	return s.ctrl.outcome

## Aceita as telas de resultado ate a batalha fechar.
func _accept_screens(s: BattleScene) -> void:
	var result: ResultScreen = s.get_node("UI/ResultScreen") as ResultScreen
	var level_up: LevelUpScreen = s.get_node("UI/LevelUpScreen") as LevelUpScreen
	if s.ctrl.outcome == BattleController.Outcome.VICTORY:
		result.accept()
		var guard: int = 0
		while level_up.visible and guard < 10:
			level_up.leave()
			guard += 1
	result.accept()

# --- musica por mapa ---

func test_a_map_with_music_plays_it_on_entry() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"masmorra"})
	assert_eq(game.audio.current_music_id, &"cidade")
	assert_eq(game.audio.music_changes, 1)
	await _go(&"area_teste")
	assert_eq(game.audio.current_music_id, &"masmorra")
	assert_eq(game.audio.music_changes, 2)

func test_the_same_music_on_another_map_does_not_restart() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"cidade"})
	assert_eq(game.audio.music_changes, 1)
	await _go(&"area_teste")
	assert_eq(game.audio.current_music_id, &"cidade")
	assert_eq(game.audio.music_changes, 1, "mesma musica: nao reinicia")

func test_a_map_without_music_stops_the_previous_one() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &""})
	assert_eq(game.audio.current_music_id, &"cidade")
	await _go(&"area_teste")
	assert_eq(game.audio.current_music_id, &"", "mapa sem musica: silencio")

# --- batalha ---

func test_a_battle_without_any_music_keeps_the_map_music() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"cidade"})
	await _go(&"area_teste")
	var changes: int = game.audio.music_changes
	var s: BattleScene = _touch(game.current as LocalMap, _weak())
	assert_eq(game.audio.current_music_id, &"cidade", "sem musica de batalha a do mapa continua")
	assert_eq(_run_battle(s), BattleController.Outcome.VICTORY)
	_accept_screens(s)
	assert_eq(game.audio.current_music_id, &"cidade")
	assert_eq(game.audio.music_changes, changes, "nada mudou")

func test_an_encounter_music_plays_and_the_map_music_returns_after_the_victory_jingle() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"cidade"}, func(c: BalanceConfig) -> void: c.victory_jingle = &"vitoria")
	await _go(&"area_teste")
	var s: BattleScene = _touch(game.current as LocalMap, _weak(&"batalha"))
	assert_eq(game.audio.current_music_id, &"batalha")
	assert_eq(_run_battle(s), BattleController.Outcome.VICTORY)
	assert_eq(game.audio.current_jingle_id, &"vitoria", "o jingle toca ao vencer")
	assert_eq(game.audio.current_music_id, &"")
	_accept_screens(s)
	await get_tree().create_timer(0.7).timeout
	assert_eq(game.audio.current_jingle_id, &"", "o jingle acabou")
	assert_eq(game.audio.current_music_id, &"cidade", "e a musica do mapa voltou")

func test_the_default_battle_music_is_used_when_the_encounter_has_none() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"cidade"}, func(c: BalanceConfig) -> void: c.default_battle_music = &"batalha")
	await _go(&"area_teste")
	var s: BattleScene = _touch(game.current as LocalMap, _weak())
	assert_eq(game.audio.current_music_id, &"batalha")
	assert_eq(_run_battle(s), BattleController.Outcome.VICTORY)
	_accept_screens(s)
	assert_eq(game.audio.current_music_id, &"cidade", "sem jingle de vitoria volta direto")

func test_a_boss_encounter_uses_the_boss_music_when_it_has_no_own() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"cidade"}, func(c: BalanceConfig) -> void:
		c.default_battle_music = &"batalha"
		c.boss_battle_music = &"chefe")
	await _go(&"area_teste")
	var s: BattleScene = _touch(game.current as LocalMap, _weak(&"", &"chefe_1"))
	assert_eq(game.audio.current_music_id, &"chefe")
	assert_eq(_run_battle(s), BattleController.Outcome.VICTORY)
	_accept_screens(s)

func test_defeat_plays_its_jingle_and_leaves_silence() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"cidade"}, func(c: BalanceConfig) -> void: c.defeat_jingle = &"derrota")
	await _go(&"area_teste")
	var s: BattleScene = _touch(game.current as LocalMap, _strong(&"batalha"))
	assert_eq(game.audio.current_music_id, &"batalha")
	assert_eq(_run_battle(s), BattleController.Outcome.DEFEAT)
	assert_eq(game.audio.current_jingle_id, &"derrota")
	_accept_screens(s)
	await get_tree().create_timer(0.7).timeout
	assert_eq(game.audio.current_music_id, &"", "depois da derrota nao volta musica (Game Over)")
	assert_not_null(game.game_over_screen)

func test_fleeing_returns_straight_to_the_map_music() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"cidade"})
	await _go(&"area_teste")
	var s: BattleScene = _touch(game.current as LocalMap, _strong(&"batalha"), false)
	assert_eq(game.audio.current_music_id, &"batalha")
	var guard: int = 0
	while s.ctrl.session == null and guard < 2000:
		s.ctrl.tick(0.05)
		guard += 1
	s.ctrl.update_flee(100.0, true)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.FLED)
	assert_eq(game.audio.current_music_id, &"cidade", "fuga: sem jingle")
	assert_eq(game.audio.current_jingle_id, &"")

# --- eventos ---

func _event(steps: Array[EventStep]) -> EventScript:
	return EventScript.of(steps)

func _music_step(id: StringName, fade: float = 0.5, stop: bool = false) -> PlayMusicStep:
	var m := PlayMusicStep.new()
	m.music_id = id
	m.fade = fade
	m.stop = stop
	return m

func _sound_step(id: StringName) -> PlaySoundStep:
	var s := PlaySoundStep.new()
	s.sound_id = id
	return s

func test_event_music_overrides_the_map_music_and_a_map_change_clears_it() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"cidade", &"dungeon_teste": &"masmorra"})
	await _go(&"area_teste")
	await game.play_event(_event([_music_step(&"batalha", 1.0)] as Array[EventStep]))
	assert_eq(game.audio.current_music_id, &"batalha", "o evento trocou a musica")
	await game.play_event(_event([_music_step(&"", 0.5, true)] as Array[EventStep]))
	assert_eq(game.audio.current_music_id, &"", "@musica parar")
	await game.play_event(_event([_music_step(&"chefe")] as Array[EventStep]))
	assert_eq(game.audio.current_music_id, &"chefe")
	await _go(&"overworld")
	assert_eq(game.audio.current_music_id, &"cidade", "a troca de mapa esquece o evento")
	await _go(&"area_teste")
	assert_eq(game.audio.current_music_id, &"cidade")

func test_event_music_chosen_during_a_battle_waits_for_its_end() -> void:
	_start({&"overworld": &"cidade", &"area_teste": &"cidade"})
	await _go(&"area_teste")
	var s: BattleScene = _touch(game.current as LocalMap, _weak(&"batalha"))
	game.audio_event_music(&"masmorra", 0.5, false)
	assert_eq(game.audio.current_music_id, &"batalha", "durante a batalha vale a dela")
	assert_eq(_run_battle(s), BattleController.Outcome.VICTORY)
	_accept_screens(s)
	assert_eq(game.audio.current_music_id, &"masmorra", "depois dela, a do evento")

func test_play_sound_step_plays_the_effect() -> void:
	_start({&"overworld": &"", &"area_teste": &""})
	await _go(&"area_teste")
	await game.play_event(_event([_sound_step(&"bau"), _sound_step(&"desconhecido")] as Array[EventStep]))
	assert_eq(game.audio.last_sfx_id, &"bau")
	assert_eq(game.audio.sfx_played, 1, "som desconhecido nao toca nem da erro")

# --- efeitos ---

func test_battle_hit_and_down_sounds_play_for_the_enemy() -> void:
	_start({&"overworld": &"", &"area_teste": &""})
	await _go(&"area_teste")
	var s: BattleScene = _touch(game.current as LocalMap, _weak())
	assert_eq(_run_battle(s), BattleController.Outcome.VICTORY)
	assert_gt(game.audio.sfx_played, 0, "o inimigo levou golpes")
	assert_true([&"inimigo_hit", &"inimigo_cai"].has(game.audio.last_sfx_id))
	_accept_screens(s)

func test_chest_and_door_sounds() -> void:
	_start({&"overworld": &"", &"area_teste": &""}, func(c: BalanceConfig) -> void:
		c.sfx_open_chest = &"bau"
		c.sfx_open_door = &"porta")
	await _go(&"area_teste")
	var map: LocalMap = game.current as LocalMap
	var chest := Chest.new()
	chest.opened_flag = &"bau_1"
	map.add_interactable(chest)
	chest._activate()
	assert_eq(game.audio.last_sfx_id, &"bau")
	var door := Door.new()
	door.open_flag = &"porta_1"
	map.add_interactable(door)
	door._activate()
	assert_eq(game.audio.last_sfx_id, &"porta")

func test_locked_door_does_not_play_the_open_sound() -> void:
	_start({&"overworld": &"", &"area_teste": &""}, func(c: BalanceConfig) -> void: c.sfx_open_door = &"porta")
	await _go(&"area_teste")
	var map: LocalMap = game.current as LocalMap
	var door := Door.new()
	door.open_flag = &"porta_2"
	var key := ItemDef.new()
	key.id = &"chave_x"
	door.key_item = key
	map.add_interactable(door)
	door._activate()
	assert_eq(game.audio.sfx_played, 0)

func test_steps_sound_once_per_step_distance() -> void:
	_start({&"overworld": &"", &"area_teste": &""}, func(c: BalanceConfig) -> void:
		c.sfx_step = &"passo"
		c.step_distance = 20.0)
	await _go(&"area_teste")
	var map: LocalMap = game.current as LocalMap
	map.player.override_dir = Vector2.RIGHT
	var before: Vector2 = map.player.global_position
	await wait_physics_frames(40)
	map.player.override_dir = Vector2.ZERO
	var walked: float = map.player.global_position.distance_to(before)
	assert_gt(walked, 20.0, "o jogador andou")
	assert_gt(game.audio.sfx_played, 0)
	assert_lte(game.audio.sfx_played, int(walked / 20.0) + 1, "no maximo um som por passo")

func test_standing_still_makes_no_step_sound() -> void:
	_start({&"overworld": &"", &"area_teste": &""}, func(c: BalanceConfig) -> void: c.sfx_step = &"passo")
	await _go(&"area_teste")
	await wait_physics_frames(20)
	assert_eq(game.audio.sfx_played, 0)

func test_field_menu_keys_play_move_confirm_and_cancel() -> void:
	_start({&"overworld": &"", &"area_teste": &""}, func(c: BalanceConfig) -> void:
		c.sfx_menu_move = &"move"
		c.sfx_menu_confirm = &"ok"
		c.sfx_menu_cancel = &"volta")
	assert_true(game.open_menu())
	game.menu._unhandled_input(_action(&"ui_down"))
	assert_eq(game.audio.last_sfx_id, &"move")
	game.menu._unhandled_input(_action(&"ui_accept"))
	assert_eq(game.audio.last_sfx_id, &"ok")
	game.menu._unhandled_input(_action(&"ui_cancel"))
	assert_eq(game.audio.last_sfx_id, &"volta")

func test_text_ticks_follow_the_cfg_interval_and_the_config_toggle() -> void:
	_start({&"overworld": &"", &"area_teste": &""}, func(c: BalanceConfig) -> void:
		c.sfx_text_tick = &"tick"
		c.text_tick_every = 2)
	await _go(&"area_teste")
	var ev := EventScript.of([EventScript.say("Um texto bem comprido para revelar", "Ana")] as Array[EventStep])
	game.play_event(ev)
	var box: DialogueBox = game.event_player.dialogue
	assert_eq(box.tick_every, 2)
	box.chars_per_second = 100.0
	box.tick(0.1)
	assert_eq(game.audio.sfx_played, 1, "10 letras revelam de uma vez: um tique por quadro")
	game.settings.text_sound = false
	box.tick(0.1)
	assert_eq(game.audio.sfx_played, 1, "Som do texto desligado na Config")
	game.settings.text_sound = true
	box.tick(0.1)
	assert_eq(game.audio.sfx_played, 2)

func test_title_stops_the_music_with_a_fade() -> void:
	_start({&"overworld": &"cidade"})
	assert_eq(game.audio.current_music_id, &"cidade")
	game._show_title()
	assert_eq(game.audio.current_music_id, &"")

func _action(name: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e

# --- sem audio configurado nada muda ---

func test_with_the_default_empty_bank_and_no_ids_nothing_makes_a_sound() -> void:
	game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.skip_title = true
	game.settings_path = "user://test_audio_triggers_unused.cfg"
	add_child_autofree(game)
	assert_eq(game.sound_bank.sounds.size(), 0, "banco padrao vazio")
	assert_eq(game.sound_bank.musics.size(), 0)
	await _go(&"area_teste")
	var s: BattleScene = _touch(game.current as LocalMap, _weak())
	assert_eq(_run_battle(s), BattleController.Outcome.VICTORY)
	_accept_screens(s)
	game.menu._unhandled_input(_action(&"ui_down"))
	await _go(&"overworld")
	assert_eq(game.audio.sfx_played, 0)
	assert_eq(game.audio.music_changes, 0)
	assert_eq(game.audio.current_music_id, &"")
	assert_eq(game.audio.current_jingle_id, &"")

func test_a_stub_bank_with_no_ids_set_stays_silent_too() -> void:
	_start({&"overworld": &"", &"area_teste": &""})
	await _go(&"area_teste")
	var s: BattleScene = _touch(game.current as LocalMap, _strong())
	assert_eq(_run_battle(s), BattleController.Outcome.DEFEAT)
	_accept_screens(s)
	assert_eq(game.audio.sfx_played, 0, "sem ids nos defs o banco cheio nao toca nada")
	assert_eq(game.audio.music_changes, 0)

func test_rest_and_shop_menu_keys_play_move_confirm_and_cancel() -> void:
	_start({&"overworld": &"", &"area_teste": &""}, func(c: BalanceConfig) -> void:
		c.sfx_menu_move = &"move"
		c.sfx_menu_confirm = &"ok"
		c.sfx_menu_cancel = &"volta")
	game.rest_menu.open(game, 0)
	game.rest_menu._unhandled_input(_action(&"ui_down"))
	assert_eq(game.audio.last_sfx_id, &"move", "descanso: mover")
	game.rest_menu._unhandled_input(_action(&"ui_cancel"))
	assert_eq(game.audio.last_sfx_id, &"volta", "descanso: voltar")
	game.shop_menu.open(game, load("res://data/fatia/shops/loja_cidade.tres") as ShopDef)
	game.shop_menu._unhandled_input(_action(&"ui_down"))
	assert_eq(game.audio.last_sfx_id, &"move", "loja: mover")
	game.shop_menu._unhandled_input(_action(&"ui_cancel"))
	assert_eq(game.audio.last_sfx_id, &"volta", "loja: voltar")

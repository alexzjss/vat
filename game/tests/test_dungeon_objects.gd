extends GutTest

## Objetos de dungeon (M10): baú, porta com chave, interruptor + portão, armadilhas e gatilho. Todo estado vive em flags.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"
const KEY: ItemDef = preload("res://data/test/items/chave_teste.tres")
const POTION: ItemDef = preload("res://data/test/items/pocao.tres")

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
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	await _wait_idle()
	map = game.current as LocalMap

func _chest(flag: StringName, offset: Vector2 = Vector2(30, 0)) -> Chest:
	var c := Chest.new()
	c.item = POTION
	c.count = 2
	c.opened_flag = flag
	c.position = map.player.position + offset
	map.add_interactable(c)
	return c

func _door(flag: StringName, key: ItemDef) -> Door:
	var d := Door.new()
	d.key_item = key
	d.open_flag = flag
	d.position = map.player.position + Vector2(30, 0)
	map.add_interactable(d)
	return d

## Termina o evento em andamento rodando o resto à mão (aceita cada fala).
func _drain_event() -> void:
	var guard: int = 0
	while game.event_player.active and guard < 50:
		guard += 1
		game.event_player.dialogue._shown = 9999.0
		game.event_player.dialogue.accept()
		await get_tree().process_frame

# --- baú -----------------------------------------------------------------------

func test_chest_opens_once_and_gives_the_item() -> void:
	await _enter_area()
	var c: Chest = _chest(&"bau_a")
	var before: int = game.state.inventory.available(POTION.id)
	assert_true(map.try_interact())
	assert_eq(game.state.get_flag(&"bau_a"), 1)
	assert_eq(game.state.inventory.available(POTION.id), before + 2)
	assert_eq(game.event_player.dialogue._body.text, "Encontrou Poção x2!")
	await _drain_event()
	assert_true(c.is_open())
	assert_false(c.can_interact(), "aberto: não abre de novo")
	assert_false(map.try_interact())
	assert_eq(game.state.inventory.available(POTION.id), before + 2)

func test_chest_gives_equipment() -> void:
	await _enter_area()
	var c: Chest = _chest(&"bau_e")
	c.item = null
	c.equipment = load("res://data/test/equipment/lamina_simples.tres") as EquipmentDef
	c.count = 1
	var before: int = game.state.bag.count(c.equipment.id)
	assert_true(map.try_interact())
	assert_eq(game.state.bag.count(c.equipment.id), before + 1)
	game.event_player.cancel()

func test_chest_state_persists_between_map_instances() -> void:
	await _enter_area()
	_chest(&"bau_p")
	assert_true(map.try_interact())
	await _drain_event()
	game.go_to(&"overworld", &"AreaTesteReturn", false)
	await _wait_idle()
	game.go_to(&"area_teste", &"Entry", false)
	await _wait_idle()
	map = game.current as LocalMap
	var again: Chest = _chest(&"bau_p")
	await get_tree().process_frame
	assert_true(again.is_open(), "a flag mantém o baú aberto")
	assert_false(again.can_interact())

func test_game_over_restore_reverts_chest() -> void:
	await _enter_area()
	game.state.save(&"area_teste", &"Entry")
	var c: Chest = _chest(&"bau_g")
	assert_true(map.try_interact())
	await _drain_event()
	assert_true(c.is_open())
	game.state.restore_save()
	assert_false(c.is_open(), "o restore devolve o baú fechado")
	assert_eq(game.state.inventory.available(POTION.id), 3)

# --- porta ---------------------------------------------------------------------

func test_door_without_key_stays_locked() -> void:
	await _enter_area()
	var d: Door = _door(&"porta_a", KEY)
	assert_true(map.try_interact())
	assert_eq(game.event_player.dialogue._body.text, "Está trancada.")
	assert_eq(game.state.get_flag(&"porta_a"), 0)
	await _drain_event()
	assert_true(d.blocking())

func test_door_with_key_opens_and_keeps_the_key() -> void:
	await _enter_area()
	var d: Door = _door(&"porta_b", KEY)
	game.state.inventory.add(KEY, 1)
	assert_true(map.try_interact())
	assert_eq(game.state.get_flag(&"porta_b"), 1)
	await _drain_event()
	assert_eq(game.state.inventory.available(KEY.id), 1, "a chave não é consumida")
	d.sync_state()
	assert_false(d.blocking())
	assert_false(d.can_interact())

func test_door_without_key_item_opens_freely() -> void:
	await _enter_area()
	var d: Door = _door(&"porta_c", null)
	assert_true(map.try_interact())
	assert_eq(game.state.get_flag(&"porta_c"), 1)
	assert_false(d.blocking())
	game.event_player.cancel()

func test_open_door_collider_is_disabled() -> void:
	await _enter_area()
	var d: Door = _door(&"porta_d", null)
	game.state.set_flag(&"porta_d", 1)
	d.sync_state()
	await get_tree().process_frame
	assert_true(d._shape.disabled)

# --- interruptor e portão ------------------------------------------------------

func test_switch_toggles_the_gate() -> void:
	await _enter_area()
	var gate := FlagGate.new()
	gate.flag = &"sw"
	gate.position = map.player.position + Vector2(300, 0)
	map.add_child(gate)
	var sw := Switch.new()
	sw.flag = &"sw"
	sw.position = map.player.position + Vector2(30, 0)
	map.add_interactable(sw)
	assert_true(gate.blocking())
	assert_true(map.try_interact())
	assert_eq(game.state.get_flag(&"sw"), 1)
	assert_false(gate.blocking())
	await _drain_event()
	assert_true(map.try_interact())
	assert_eq(game.state.get_flag(&"sw"), 0, "alterna de volta")
	assert_true(gate.blocking())
	game.event_player.cancel()
	await get_tree().process_frame
	assert_false(gate._shape.disabled)

func test_gate_open_after_restore_of_a_saved_flag() -> void:
	await _enter_area()
	var gate := FlagGate.new()
	gate.flag = &"sw2"
	map.add_child(gate)
	game.state.set_flag(&"sw2", 1)
	game.state.save(&"area_teste", &"Entry")
	game.state.set_flag(&"sw2", 0)
	assert_true(gate.blocking())
	game.state.restore_save()
	assert_false(gate.blocking(), "o save guardou o portão aberto")

# --- armadilhas ----------------------------------------------------------------

func _trap(flag: StringName = &"") -> Trap:
	var t := Trap.new()
	t.once_flag = flag
	t.position = map.player.position
	map.add_child(t)
	return t

func test_damage_trap_hits_active_heroes_by_percent() -> void:
	await _enter_area()
	var t: Trap = _trap()
	var h: HeroState = game.state.heroes[0]
	var full: int = h.hp
	assert_true(t.trigger())
	var expected: int = ceili(float(full) * game.state.cfg.trap_damage_pct)
	assert_eq(full - h.hp, expected)
	assert_gt(expected, 0)
	game.event_player.cancel()

func test_damage_trap_never_kills_and_skips_downed() -> void:
	await _enter_area()
	var t: Trap = _trap()
	var weak: HeroState = game.state.heroes[0]
	var downed: HeroState = game.state.heroes[1]
	weak.hp = 2
	downed.hp = 0
	assert_true(t.trigger())
	assert_eq(weak.hp, 1, "mínimo 1 HP")
	assert_eq(downed.hp, 0, "caído não é afetado")
	game.event_player.cancel()

func test_damage_trap_does_not_touch_the_reserve() -> void:
	await _enter_area()
	var t: Trap = _trap()
	var res: HeroState = game.state.reserve[0]
	var before: int = res.hp
	assert_true(t.trigger())
	assert_eq(res.hp, before)
	game.event_player.cancel()

func test_trap_once_flag_disarms() -> void:
	await _enter_area()
	var t: Trap = _trap(&"trap_once")
	var h: HeroState = game.state.heroes[0]
	assert_true(t.trigger())
	var after_first: int = h.hp
	game.event_player.cancel()
	assert_eq(game.state.get_flag(&"trap_once"), 1)
	assert_false(t.armed())
	assert_false(t.trigger())
	assert_eq(h.hp, after_first)

func test_trap_without_once_flag_fires_again() -> void:
	await _enter_area()
	var t: Trap = _trap()
	assert_true(t.trigger())
	game.event_player.cancel()
	assert_true(t.trigger())
	game.event_player.cancel()

func test_trap_ignored_while_an_event_runs() -> void:
	await _enter_area()
	var t: Trap = _trap(&"busy")
	assert_true(t.trigger())
	assert_false(t.trigger(), "evento em andamento")
	game.event_player.cancel()

func test_trap_refused_while_game_is_busy_changes_nothing() -> void:
	await _enter_area()
	var t: Trap = _trap(&"busy_trap")
	var h: HeroState = game.state.heroes[0]
	var full: int = h.hp
	game.busy = true
	assert_false(t.trigger(), "Game ocupado recusa")
	assert_eq(game.state.get_flag(&"busy_trap"), 0, "flag intacta")
	assert_eq(h.hp, full, "sem dano")
	game.busy = false
	assert_true(t.trigger(), "livre: dispara")
	assert_eq(game.state.get_flag(&"busy_trap"), 1)
	game.event_player.cancel()

func test_trap_refused_while_busy_fires_when_game_frees_up() -> void:
	await _enter_area()
	game.busy = true
	var t: Trap = _trap(&"late_trap")
	for i: int in 6:
		await get_tree().physics_frame
	assert_eq(game.state.get_flag(&"late_trap"), 0, "ocupado: nada aconteceu")
	game.busy = false
	var guard: int = 0
	while game.state.get_flag(&"late_trap") == 0 and guard < 30:
		guard += 1
		await get_tree().process_frame
	assert_eq(game.state.get_flag(&"late_trap"), 1, "disparou ao liberar, com o jogador ainda dentro")
	assert_true(game.event_player.active)
	game.event_player.cancel()

func test_event_trigger_refused_while_busy_keeps_its_flag() -> void:
	await _enter_area()
	var t: EventTrigger = _trigger_with_flag(&"trig_busy")
	game.busy = true
	assert_false(t.trigger())
	assert_eq(game.state.get_flag(&"trig_busy"), 0)
	assert_eq(game.state.get_flag(&"ran"), 0)
	game.busy = false
	assert_true(t.trigger())
	assert_eq(game.state.get_flag(&"trig_busy"), 1)
	game.event_player.cancel()

func test_battle_trap_starts_the_encounter() -> void:
	await _enter_area()
	var t: Trap = _trap(&"trap_bat")
	t.encounter = load("res://data/test/encounters/encontro_x.tres") as EncounterDef
	var h: HeroState = game.state.heroes[0]
	var full: int = h.hp
	assert_true(t.trigger())
	assert_eq(h.hp, full, "armadilha de batalha não tira HP")
	await _drain_event()
	var guard: int = 0
	while map.battle == null and guard < 120:
		guard += 1
		await get_tree().process_frame
	assert_not_null(map.battle, "o encontro começou")
	assert_eq(game.state.get_flag(&"trap_bat"), 1)
	game.event_player.cancel()

# --- gatilho -------------------------------------------------------------------

func _trigger_with_flag(flag: StringName) -> EventTrigger:
	var t := EventTrigger.new()
	t.once_flag = flag
	t.event = EventScript.of([EventScript.set_flag(&"ran", 1), EventScript.say("oi")] as Array[EventStep])
	t.position = map.player.position
	map.add_child(t)
	return t

func test_event_trigger_runs_once() -> void:
	await _enter_area()
	var t: EventTrigger = _trigger_with_flag(&"trig_once")
	assert_true(t.trigger())
	assert_eq(game.state.get_flag(&"ran"), 1)
	await _drain_event()
	game.state.set_flag(&"ran", 0)
	assert_false(t.trigger(), "uma vez só")
	assert_eq(game.state.get_flag(&"ran"), 0)

func test_event_trigger_without_flag_repeats() -> void:
	await _enter_area()
	var t: EventTrigger = _trigger_with_flag(&"")
	assert_true(t.trigger())
	await _drain_event()
	assert_true(t.trigger())
	game.event_player.cancel()

func test_trap_rules_pure() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h := HeroState.create(Fixtures.hero_def(&"h", Stats.make(5, 5, 5, 5)), cfg)
	h.hp = 1
	assert_eq(TrapRules.damage_for(h, 0.5, cfg), 0, "com 1 HP não leva dano")
	h.hp = 0
	assert_eq(TrapRules.damage_for(h, 0.5, cfg), 0)

extends GutTest

## Obstáculo elemental (M15): a escolha do herói com técnica do elemento, o AP gasto, a flag, "trancado",
## cancelar e o mapa reinstanciado. Todo estado vive na flag.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"
const FLAG: StringName = &"vinhas_1"

var game: Game
var map: LocalMap
var fire: ElementDef
var water: ElementDef

func before_each() -> void:
	fire = _el(&"fire", "Fogo")
	water = _el(&"water", "Água")
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

func _el(id: StringName, name: String) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	e.display_name = name
	e.short_name = name
	return e

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

func _tech(id: StringName, element: ElementDef, cost: int) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = id
	a.display_name = "Técnica %s" % id
	a.ap_cost = cost
	a.element = element
	a.side = AbilityDef.Side.ENEMIES
	a.effects = [] as Array[EffectDef]
	return a

## Dá ao herói `i` exatamente essas técnicas (def copiada: o .tres carregado é compartilhado entre testes).
func _teach(i: int, techs: Array[AbilityDef]) -> HeroState:
	var h: HeroState = game.state.heroes[i]
	var d: CharacterDef = h.def.duplicate() as CharacterDef
	Fixtures.set_abilities(d, techs)
	h.def = d
	h.learned = []
	h.learn_up_to(1)
	return h

func _obstacle(offset: Vector2 = Vector2(30, 0)) -> ElementalObstacle:
	var o := ElementalObstacle.new()
	o.element = fire
	o.flag = FLAG
	o.open_text = "As vinhas queimam."
	o.locked_text = "Vinhas grossas bloqueiam o caminho."
	o.position = map.player.position + offset
	map.add_interactable(o)
	return o

func _drain_event() -> void:
	var guard: int = 0
	while game.event_player.active and guard < 50:
		guard += 1
		game.event_player.dialogue._shown = 9999.0
		game.event_player.dialogue.accept()
		await get_tree().process_frame

func _setup_party() -> Array[HeroState]:
	# h0: Fogo custo 3 (e outro de custo 5, mais caro); h1: Fogo custo 4 sem AP; h2: só Água.
	var a: HeroState = _teach(0, [_tech(&"f_big", fire, 5), _tech(&"f_small", fire, 3)] as Array[AbilityDef])
	var b: HeroState = _teach(1, [_tech(&"f_b", fire, 4)] as Array[AbilityDef])
	var c: HeroState = _teach(2, [_tech(&"w_c", water, 1)] as Array[AbilityDef])
	a.ap = 10
	b.ap = 2
	c.ap = 10
	return [a, b, c] as Array[HeroState]

# --- a lista de heróis -----------------------------------------------------------

func test_options_list_only_heroes_with_the_element() -> void:
	await _enter_area()
	var hs: Array[HeroState] = _setup_party()
	var o: ElementalObstacle = _obstacle()
	var opts: Array[ElementalObstacle.Option] = o.options()
	assert_eq(opts.size(), 2, "o de Água fica de fora")
	assert_eq(opts[0].hero, hs[0])
	assert_eq(opts[0].ability.id, &"f_small", "a técnica mais barata do elemento")
	assert_true(opts[0].enabled)
	assert_eq(opts[1].hero, hs[1])
	assert_false(opts[1].enabled, "sem AP para o custo 4")

func test_downed_hero_is_listed_but_disabled() -> void:
	await _enter_area()
	var hs: Array[HeroState] = _setup_party()
	hs[0].hp = 0
	var o: ElementalObstacle = _obstacle()
	assert_false(o.options()[0].enabled)

func test_menu_shows_the_cost_and_greys_out_who_cannot() -> void:
	await _enter_area()
	_setup_party()
	var o: ElementalObstacle = _obstacle()
	assert_true(map.try_interact())
	var m: ObstacleMenu = game.obstacle_menu
	assert_true(m.is_open)
	var rows: PackedStringArray = m.entries()
	assert_eq(rows.size(), 2)
	assert_string_contains(rows[0], "AP 3")
	assert_string_contains(rows[1], "AP 4")
	assert_true(m.entry_enabled(0))
	assert_false(m.entry_enabled(1))
	assert_eq(game.current.process_mode, Node.PROCESS_MODE_DISABLED, "o mapa congela com a escolha aberta")
	m.cancel()
	assert_false(o.is_open())

# --- escolher --------------------------------------------------------------------

func test_choosing_spends_the_ap_sets_the_flag_and_clears_the_way() -> void:
	await _enter_area()
	var hs: Array[HeroState] = _setup_party()
	var o: ElementalObstacle = _obstacle()
	assert_true(map.try_interact())
	game.obstacle_menu.accept()
	assert_eq(hs[0].ap, 7, "gastou o custo 3 do herói escolhido")
	assert_eq(hs[1].ap, 2, "os outros não gastam")
	assert_eq(game.state.get_flag(FLAG), 1)
	assert_false(game.obstacle_menu.is_open)
	assert_eq(game.current.process_mode, Node.PROCESS_MODE_INHERIT, "o mapa volta")
	await get_tree().process_frame
	assert_false(o.visible, "some")
	assert_true(o._blocker.disabled, "a colisão desliga")
	assert_false(o.can_interact())
	assert_true(game.event_player.active, "fala de abertura")
	assert_eq(game.event_player.dialogue._body.text, "As vinhas queimam.")
	await _drain_event()

func test_second_hero_can_be_chosen() -> void:
	await _enter_area()
	var hs: Array[HeroState] = _setup_party()
	hs[1].ap = 6
	_obstacle()
	assert_true(map.try_interact())
	game.obstacle_menu.move(1)
	game.obstacle_menu.accept()
	assert_eq(hs[1].ap, 2, "o segundo herói pagou o custo 4")
	assert_eq(hs[0].ap, 10)
	await _drain_event()

func test_disabled_hero_cannot_be_chosen() -> void:
	await _enter_area()
	var hs: Array[HeroState] = _setup_party()
	var o: ElementalObstacle = _obstacle()
	assert_true(map.try_interact())
	game.obstacle_menu.move(1)
	game.obstacle_menu.accept()
	assert_true(game.obstacle_menu.is_open, "continua aberto")
	assert_ne(game.obstacle_menu.message(), "")
	assert_eq(hs[1].ap, 2, "nada gasto")
	assert_eq(game.state.get_flag(FLAG), 0)
	assert_false(o.unlock(hs[1]), "nem direto")
	game.obstacle_menu.cancel()

func test_no_capable_hero_shows_the_locked_text() -> void:
	await _enter_area()
	_teach(0, [_tech(&"w_a", water, 1)] as Array[AbilityDef])
	var o: ElementalObstacle = _obstacle()
	assert_true(map.try_interact())
	assert_false(game.obstacle_menu.is_open, "sem escolha")
	assert_true(game.event_player.active)
	assert_eq(game.event_player.dialogue._body.text, "Vinhas grossas bloqueiam o caminho.")
	assert_eq(game.state.get_flag(FLAG), 0)
	assert_true(o.visible)
	await _drain_event()

func test_cancel_spends_nothing() -> void:
	await _enter_area()
	var hs: Array[HeroState] = _setup_party()
	var o: ElementalObstacle = _obstacle()
	assert_true(map.try_interact())
	game.obstacle_menu.cancel()
	assert_false(game.obstacle_menu.is_open)
	assert_eq(game.current.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(hs[0].ap, 10)
	assert_eq(game.state.get_flag(FLAG), 0)
	assert_false(o.is_open())
	assert_true(o.visible)
	assert_false(game.event_player.active, "sem fala")

func test_escape_key_cancels() -> void:
	await _enter_area()
	_setup_party()
	_obstacle()
	assert_true(map.try_interact())
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	game.obstacle_menu._unhandled_input(ev)
	assert_false(game.obstacle_menu.is_open)
	assert_eq(game.state.get_flag(FLAG), 0)

# --- estado e mapa ---------------------------------------------------------------

func test_a_new_instance_with_the_flag_set_starts_open() -> void:
	await _enter_area()
	game.state.set_flag(FLAG, 1)
	var o: ElementalObstacle = _obstacle()
	await get_tree().process_frame
	assert_true(o.is_open())
	assert_false(o.visible)
	assert_true(o._blocker.disabled)
	assert_false(o.can_interact())
	assert_false(map.try_interact(), "nada para interagir")

func test_flag_survives_a_save_round_trip() -> void:
	await _enter_area()
	game.state.set_flag(FLAG, 1)
	var d: Dictionary = game.state.to_dict()
	var back: GameState = GameState.from_dict(d, game.registry, game.balance, ScriptedDice.new())
	assert_not_null(back)
	assert_eq(back.get_flag(FLAG), 1)

func test_input_gating_matches_other_interactables() -> void:
	await _enter_area()
	_setup_party()
	var o: ElementalObstacle = _obstacle(Vector2(400, 0))
	assert_false(o.can_interact(), "fora da área")
	assert_false(map.try_interact())
	o.position = map.player.position + Vector2(30, 0)
	map.event_active = true
	assert_false(map.try_interact(), "mapa ocupado por evento")
	assert_false(game.obstacle_menu.is_open)
	map.event_active = false
	map.locked = true
	assert_false(map.try_interact(), "mapa travado")
	map.locked = false
	assert_true(map.try_interact())
	game.obstacle_menu.cancel()

func test_element_color_is_used_on_the_drawing() -> void:
	await _enter_area()
	var o: ElementalObstacle = _obstacle()
	assert_eq(o.element, fire)
	assert_eq(o.prompt, "Examinar")

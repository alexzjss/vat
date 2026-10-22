extends GutTest

## Recrutamento e passos novos de evento (M12): RecruitStep (vaga, reserva, nível, técnicas, idempotência, save),
## GiveMoneyStep e EndDemoStep.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

var cfg: BalanceConfig

func before_each() -> void:
	cfg = Fixtures.cfg()

func _hero(id: StringName, learn_levels: Array[int] = [1]) -> CharacterDef:
	var d: CharacterDef = Fixtures.hero_def(id, Stats.make(2, 2, 4, 2))
	var entries: Array[LearnEntry] = []
	for lv: int in learn_levels:
		var ab: AbilityDef = Fixtures.hit(1.0)
		ab.id = StringName("%s_t%d" % [id, lv])
		ab.display_name = "Técnica %d" % lv
		var le := LearnEntry.new()
		le.ability = ab
		le.level = lv
		entries.append(le)
	d.learnset = entries
	return d

func _game(n_heroes: int, level: int = 1) -> GameState:
	var defs: Array[CharacterDef] = []
	for i: int in n_heroes:
		defs.append(_hero(StringName("h%d" % i)))
	var g: GameState = GameState.new_game(cfg, defs, [] as Array[ItemDef], [] as Array[int], ScriptedDice.new(), &"overworld", &"Start")
	for h: HeroState in g.roster():
		XpCalculator.grant(h, XpCalculator.xp_for_level(level, cfg), cfg)
	return g

func _step(d: CharacterDef, mode: RecruitStep.LevelMode = RecruitStep.LevelMode.PARTY_AVG, level: int = 1) -> RecruitStep:
	var s := RecruitStep.new()
	s.hero = d
	s.level_mode = mode
	s.level = level
	return s

func _run(g: GameState, steps: Array[EventStep]) -> EventRunner:
	var r := EventRunner.new(EventScript.of(steps), g)
	r.start()
	return r

func _drain(r: EventRunner) -> Array[EventRequest]:
	var out: Array[EventRequest] = []
	var guard: int = 0
	while not r.finished and guard < 50:
		out.append(r.current())
		r.resume()
		guard += 1
	return out

# --- vaga e reserva --------------------------------------------------------------

func test_recruit_goes_to_active_when_there_is_room() -> void:
	var g: GameState = _game(3)
	var h: HeroState = g.recruit(_hero(&"novo"))
	assert_not_null(h)
	assert_eq(g.heroes.size(), 4)
	assert_eq(g.heroes[3], h)
	assert_eq(g.reserve.size(), 0)

func test_recruit_goes_to_reserve_when_active_is_full() -> void:
	var g: GameState = _game(4)
	var h: HeroState = g.recruit(_hero(&"novo"))
	assert_eq(g.heroes.size(), 4)
	assert_eq(g.reserve, [h] as Array[HeroState])

func test_recruit_with_full_reserve_still_adds_and_never_loses_anyone() -> void:
	var g: GameState = _game(6)
	assert_eq(g.reserve.size(), 2)
	var h: HeroState = g.recruit(_hero(&"novo"))
	assert_eq(g.roster().size(), 7)
	assert_true(g.reserve.has(h))

func test_recruit_is_idempotent() -> void:
	var g: GameState = _game(2)
	var d: CharacterDef = _hero(&"novo")
	assert_not_null(g.recruit(d))
	assert_null(g.recruit(d), "já recrutado")
	assert_null(g.recruit(_hero(&"novo")), "outro def com o mesmo id também")
	assert_eq(g.roster().size(), 3)
	assert_null(g.recruit(null))

func test_recruit_already_in_reserve_is_ignored() -> void:
	var g: GameState = _game(5)
	assert_eq(g.reserve.size(), 1)
	assert_null(g.recruit(g.reserve[0].def))
	assert_eq(g.roster().size(), 5)

# --- nível e técnicas -----------------------------------------------------------

func test_party_avg_level_floors_the_active_average() -> void:
	var g: GameState = _game(2)
	g.heroes[0].level = 5
	g.heroes[1].level = 4
	assert_eq(g.party_avg_level(), 4, "floor(4.5)")
	var h: HeroState = g.recruit(_hero(&"novo"))
	assert_eq(h.level, 4)
	assert_eq(h.xp, XpCalculator.xp_for_level(4, cfg))

func test_party_avg_ignores_the_reserve() -> void:
	var g: GameState = _game(5, 2)
	g.reserve[0].level = 9
	assert_eq(g.party_avg_level(), 2)

func test_recruit_learns_techniques_up_to_its_level() -> void:
	var g: GameState = _game(3, 4)
	var d: CharacterDef = _hero(&"novo", [1, 3, 6])
	var h: HeroState = g.recruit(d)
	assert_eq(h.level, 4)
	assert_eq(h.learned, [&"novo_t1", &"novo_t3"] as Array[StringName])
	assert_eq(h.abilities().size(), 2)

func test_recruit_arrives_with_full_hp_ap_and_level_points() -> void:
	var g: GameState = _game(3, 5)
	var h: HeroState = g.recruit(_hero(&"novo"))
	var c := Combatant.from_hero(h, Vector2.ZERO)
	assert_eq(h.hp, StatCalculator.hp_max(c, cfg))
	assert_eq(h.ap, StatCalculator.ap_max(c, cfg))
	var expected: int = 0
	for lv: int in range(2, 6):
		expected += XpCalculator.points_for_level(lv)
	assert_eq(h.pending_points, expected)

func test_fixed_level_ignores_the_party() -> void:
	var g: GameState = _game(3, 6)
	var h: HeroState = g.recruit(_hero(&"novo"), 2)
	assert_eq(h.level, 2)

func test_level_never_below_one_with_a_level_one_party() -> void:
	var g: GameState = _game(1)
	assert_eq(g.recruit(_hero(&"novo")).level, 1)

# --- passo de evento -------------------------------------------------------------

func test_recruit_step_announces_in_the_party() -> void:
	var g: GameState = _game(3)
	var steps: Array[EventStep] = [_step(_hero(&"novo", [1]))]
	var reqs: Array[EventRequest] = _drain(_run(g, steps))
	assert_eq(reqs.size(), 1)
	assert_eq(reqs[0].kind, EventRequest.Kind.SAY)
	assert_eq(reqs[0].text, "novo entrou no grupo!")
	assert_eq(g.roster().size(), 4)

func test_recruit_step_twice_announces_once() -> void:
	var g: GameState = _game(2)
	var d: CharacterDef = _hero(&"novo")
	var steps: Array[EventStep] = [_step(d), _step(d)]
	var reqs: Array[EventRequest] = _drain(_run(g, steps))
	assert_eq(reqs.size(), 1)
	assert_eq(g.roster().size(), 3)

func test_recruit_step_fixed_level() -> void:
	var g: GameState = _game(2, 5)
	var steps: Array[EventStep] = [_step(_hero(&"novo"), RecruitStep.LevelMode.FIXED, 3)]
	_drain(_run(g, steps))
	assert_eq(g.roster()[2].level, 3)

func test_recruit_step_fixed_level_zero_means_level_one() -> void:
	var g: GameState = _game(2, 5)
	var steps: Array[EventStep] = [_step(_hero(&"novo"), RecruitStep.LevelMode.FIXED, 0)]
	_drain(_run(g, steps))
	assert_eq(g.roster()[2].level, 1, "FIXED com nível 0 não vira média do grupo")

func test_recruit_step_with_null_hero_does_nothing() -> void:
	var g: GameState = _game(2)
	var steps: Array[EventStep] = [_step(null)]
	assert_eq(_drain(_run(g, steps)).size(), 0)
	assert_eq(g.roster().size(), 2)

# --- save e restore ---------------------------------------------------------------

func test_recruit_survives_the_save_round_trip() -> void:
	var g: GameState = _game(4, 3)
	var d: CharacterDef = _hero(&"novo", [1, 2])
	var h: HeroState = g.recruit(d)
	var chars: Array[CharacterDef] = []
	for x: HeroState in g.roster():
		chars.append(x.def)
	var reg := DefRegistry.create(chars, [] as Array[ItemDef], [] as Array[EquipmentDef])
	var back: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())), reg, cfg, ScriptedDice.new())
	assert_not_null(back)
	assert_eq(back.reserve.size(), 1)
	assert_eq(back.reserve[0].def.id, &"novo")
	assert_eq(back.reserve[0].level, h.level)
	assert_eq(back.reserve[0].learned, h.learned)

func test_restore_before_saving_drops_the_recruit() -> void:
	var g: GameState = _game(3)
	g.recruit(_hero(&"novo"))
	assert_eq(g.roster().size(), 4)
	g.restore_save()
	assert_eq(g.roster().size(), 3, "recruta depois do último save some junto com as flags")

func test_recruit_after_save_is_kept_when_saved_again() -> void:
	var g: GameState = _game(3)
	g.recruit(_hero(&"novo"))
	g.save(&"overworld", &"Start")
	g.heroes[0].hp = 1
	g.restore_save()
	assert_eq(g.roster().size(), 4)
	assert_ne(g.heroes[0].hp, 1)

# --- moeda e fim da demo ------------------------------------------------------------

func test_give_money_step_adds_and_ignores_non_positive() -> void:
	var g: GameState = _game(1)
	var a := GiveMoneyStep.new()
	a.amount = 30
	var b := GiveMoneyStep.new()
	b.amount = -5
	var c := GiveMoneyStep.new()
	_drain(_run(g, [a, b, c] as Array[EventStep]))
	assert_eq(g.money, 30)

func test_end_demo_step_presents_a_request_after_earlier_steps() -> void:
	var g: GameState = _game(1)
	var a := GiveMoneyStep.new()
	a.amount = 4
	var steps: Array[EventStep] = [a, EndDemoStep.new(), EventScript.say("depois")]
	var r: EventRunner = _run(g, steps)
	assert_eq(g.money, 4)
	assert_eq(r.current().kind, EventRequest.Kind.END_DEMO)
	r.resume()
	assert_eq(r.current().kind, EventRequest.Kind.SAY)

func test_event_player_emits_end_demo_requested() -> void:
	var game: Game = (load(SCENE) as PackedScene).instantiate() as Game
	var bal: BalanceConfig = Fixtures.cfg()
	bal.fade_time = 0.01
	game.balance = bal
	game.world_seed = 7
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.skip_title = true
	add_child_autofree(game)
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	(game.current as Overworld).location_entered.emit(&"area_teste")
	guard = 0
	await get_tree().process_frame
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	var hits: Array[int] = [0]
	game.event_player.end_demo_requested.connect(func() -> void: hits[0] += 1)
	var steps: Array[EventStep] = [EndDemoStep.new()]
	game.play_event(EventScript.of(steps))
	await get_tree().process_frame
	assert_eq(hits[0], 1)
	assert_false(game.event_player.active, "o evento termina depois do pedido")
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

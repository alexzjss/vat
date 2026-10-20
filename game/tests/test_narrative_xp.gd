extends GutTest

## XP narrativa (spec §5.6): regras ACTIVE / ALL_RECRUITED / LIST, include_downed, subida de nível e técnicas.

var g: GameState
var cfg: BalanceConfig

func before_each() -> void:
	cfg = Fixtures.cfg()
	var defs: Array[CharacterDef] = []
	for id: StringName in [&"a", &"b", &"c", &"d", &"e"]:
		defs.append(Fixtures.hero_def(id, Stats.make(1, 1, 3, 2)))
	# 4 ativos (a..d) e 1 na reserva (e).
	g = GameState.new_game(cfg, defs, [], [], ScriptedDice.new(), &"overworld", &"Start")

func _xp(amount: int, rule: GrantXpStep.Rule, downed: bool = false, ids: Array[StringName] = []) -> EventRunner:
	var s := GrantXpStep.new()
	s.amount = amount
	s.rule = rule
	s.include_downed = downed
	s.heroes = ids
	var e := EventScript.new()
	e.steps = [s] as Array[EventStep]
	var r := EventRunner.new(e, g)
	r.start()
	return r

func _hero(id: StringName) -> HeroState:
	for h: HeroState in g.roster():
		if h.def.id == id:
			return h
	return null

func _texts(r: EventRunner) -> Array[String]:
	var out: Array[String] = []
	while not r.finished:
		out.append(r.current().text)
		r.resume()
	return out

func test_active_rule_skips_reserve() -> void:
	_xp(5, GrantXpStep.Rule.ACTIVE)
	for id: StringName in [&"a", &"b", &"c", &"d"]:
		assert_eq(_hero(id).xp, 5, String(id))
	assert_eq(_hero(&"e").xp, 0, "reserva fora de ACTIVE")

func test_all_recruited_includes_reserve() -> void:
	_xp(5, GrantXpStep.Rule.ALL_RECRUITED)
	for h: HeroState in g.roster():
		assert_eq(h.xp, 5, String(h.def.id))

func test_list_rule_only_listed_including_reserve() -> void:
	_xp(5, GrantXpStep.Rule.LIST, false, [&"b", &"e"] as Array[StringName])
	assert_eq(_hero(&"a").xp, 0)
	assert_eq(_hero(&"b").xp, 5)
	assert_eq(_hero(&"c").xp, 0)
	assert_eq(_hero(&"e").xp, 5)

func test_downed_excluded_by_default() -> void:
	_hero(&"b").hp = 0
	_hero(&"e").hp = 0
	_xp(5, GrantXpStep.Rule.ALL_RECRUITED)
	assert_eq(_hero(&"b").xp, 0)
	assert_eq(_hero(&"e").xp, 0)
	assert_eq(_hero(&"a").xp, 5)

func test_include_downed_true_grants_to_downed() -> void:
	_hero(&"b").hp = 0
	_hero(&"e").hp = 0
	_xp(5, GrantXpStep.Rule.ALL_RECRUITED, true)
	assert_eq(_hero(&"b").xp, 5)
	assert_eq(_hero(&"e").xp, 5)
	assert_eq(_hero(&"b").hp, 0, "XP não reanima")

func test_list_rule_with_downed_listed() -> void:
	_hero(&"c").hp = 0
	_xp(5, GrantXpStep.Rule.LIST, false, [&"c"] as Array[StringName])
	assert_eq(_hero(&"c").xp, 0)
	_xp(5, GrantXpStep.Rule.LIST, true, [&"c"] as Array[StringName])
	assert_eq(_hero(&"c").xp, 5)

func test_level_up_goes_through_xp_calculator() -> void:
	# xp_coef 10, modo A: nível 2 em 10, nível 3 em 40.
	var r: EventRunner = _xp(40, GrantXpStep.Rule.LIST, false, [&"a"] as Array[StringName])
	var h: HeroState = _hero(&"a")
	assert_eq(h.level, 3)
	assert_gt(h.pending_points, 0)
	assert_eq(_texts(r), ["a subiu para o Nv 3!"] as Array[String])

func test_no_message_without_level_up() -> void:
	var r: EventRunner = _xp(5, GrantXpStep.Rule.LIST, false, [&"a"] as Array[StringName])
	assert_true(r.finished, "sem subida de nível não há fala de sistema")

func test_system_lines_have_empty_speaker() -> void:
	var r: EventRunner = _xp(10, GrantXpStep.Rule.LIST, false, [&"a"] as Array[StringName])
	assert_eq(r.current().kind, EventRequest.Kind.SAY)
	assert_eq(r.current().speaker, "")

func test_level_up_teaches_learnset_technique() -> void:
	var ab: AbilityDef = Fixtures.hit(1.0)
	ab.id = &"nova"
	ab.display_name = "Nova"
	var entry := LearnEntry.new()
	entry.ability = ab
	entry.level = 2
	_hero(&"a").def.learnset = [entry] as Array[LearnEntry]
	var r: EventRunner = _xp(10, GrantXpStep.Rule.LIST, false, [&"a"] as Array[StringName])
	assert_true(_hero(&"a").learned.has(&"nova"))
	assert_eq(_texts(r), ["a subiu para o Nv 2!", "a aprendeu Nova!"] as Array[String])

func test_zero_or_negative_amount_does_nothing() -> void:
	_xp(0, GrantXpStep.Rule.ALL_RECRUITED)
	_xp(-5, GrantXpStep.Rule.ALL_RECRUITED)
	for h: HeroState in g.roster():
		assert_eq(h.xp, 0)

func test_max_level_caps_xp() -> void:
	cfg.max_level = 2
	_xp(1000, GrantXpStep.Rule.LIST, false, [&"a"] as Array[StringName])
	assert_eq(_hero(&"a").level, 2)
	assert_eq(_hero(&"a").xp, XpCalculator.xp_for_level(2, cfg))

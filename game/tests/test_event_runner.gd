extends GutTest

## EventRunner (M10): passos de regra, fluxo (IfFlag/Goto/Label), Choice, limite de passos e flags no save.

var g: GameState
var cfg: BalanceConfig

func before_each() -> void:
	cfg = Fixtures.cfg()
	var defs: Array[CharacterDef] = [
		Fixtures.hero_def(&"a", Stats.make(1, 1, 3, 2)),
		Fixtures.hero_def(&"b", Stats.make(1, 1, 3, 2)),
	]
	g = GameState.new_game(cfg, defs, [], [], ScriptedDice.new(), &"overworld", &"Start")

func _ev(steps: Array[EventStep]) -> EventScript:
	var e := EventScript.new()
	e.steps = steps
	return e

func _say(text: String, speaker: String = "") -> SayStep:
	var s := SayStep.new()
	s.speaker = speaker
	s.text = text
	return s

func _setf(flag: StringName, v: int) -> SetFlagStep:
	var s := SetFlagStep.new()
	s.flag = flag
	s.value = v
	return s

func _if(flag: StringName, op: IfFlagStep.Op, v: int, else_label: StringName) -> IfFlagStep:
	var s := IfFlagStep.new()
	s.flag = flag
	s.op = op
	s.value = v
	s.else_label = else_label
	return s

func _label(n: StringName) -> LabelStep:
	var l := LabelStep.new()
	l.label_name = n
	return l

func _goto(n: StringName) -> GotoStep:
	var s := GotoStep.new()
	s.label = n
	return s

func _run(steps: Array[EventStep]) -> EventRunner:
	var r := EventRunner.new(_ev(steps), g)
	r.start()
	return r

## Responde a todos os requests e devolve os textos vistos.
func _drain(r: EventRunner) -> Array[String]:
	var out: Array[String] = []
	var guard: int = 0
	while not r.finished and guard < 100:
		out.append(r.current().text)
		r.resume()
		guard += 1
	return out

func _registry() -> DefRegistry:
	var chars: Array[CharacterDef] = []
	for h: HeroState in g.roster():
		chars.append(h.def)
	return DefRegistry.create(chars, [] as Array[ItemDef], [] as Array[EquipmentDef])

func _reload(d: Dictionary) -> GameState:
	var json: Dictionary = JSON.parse_string(JSON.stringify(d))
	return GameState.from_dict(json, _registry(), cfg, ScriptedDice.new())

func test_set_and_add_flag() -> void:
	var add := AddFlagStep.new()
	add.flag = &"n"
	add.delta = 3
	var r: EventRunner = _run([_setf(&"n", 2), add, add] as Array[EventStep])
	assert_true(r.finished)
	assert_eq(g.get_flag(&"n"), 8)
	assert_eq(g.get_flag(&"nunca"), 0)

func test_empty_script_finishes() -> void:
	var r := EventRunner.new(EventScript.new(), g)
	r.start()
	assert_true(r.finished)
	assert_null(r.current())

func test_say_stops_runner_until_resume() -> void:
	var r: EventRunner = _run([_say("oi", "Ana"), _setf(&"x", 1)] as Array[EventStep])
	assert_false(r.finished)
	assert_eq(r.current().kind, EventRequest.Kind.SAY)
	assert_eq(r.current().speaker, "Ana")
	assert_eq(r.current().text, "oi")
	assert_eq(g.get_flag(&"x"), 0, "passo seguinte espera a fala")
	r.resume()
	assert_true(r.finished)
	assert_eq(g.get_flag(&"x"), 1)

func test_if_flag_every_operator() -> void:
	g.set_flag(&"f", 5)
	var cases: Array = [
		[IfFlagStep.Op.EQ, 5, true], [IfFlagStep.Op.EQ, 4, false],
		[IfFlagStep.Op.NE, 4, true], [IfFlagStep.Op.NE, 5, false],
		[IfFlagStep.Op.GT, 4, true], [IfFlagStep.Op.GT, 5, false],
		[IfFlagStep.Op.GE, 5, true], [IfFlagStep.Op.GE, 6, false],
		[IfFlagStep.Op.LT, 6, true], [IfFlagStep.Op.LT, 5, false],
		[IfFlagStep.Op.LE, 5, true], [IfFlagStep.Op.LE, 4, false],
	]
	for c: Array in cases:
		var r: EventRunner = _run([_if(&"f", c[0], c[1], &"fim"), _say("passou"), _label(&"fim")] as Array[EventStep])
		assert_eq(r.current() != null, c[2], "op %d valor %d" % [c[0], c[1]])

func test_if_flag_false_without_label_ends_event() -> void:
	var r: EventRunner = _run([_if(&"f", IfFlagStep.Op.EQ, 1, &""), _say("nao")] as Array[EventStep])
	assert_true(r.finished)
	assert_null(r.current())

func test_goto_skips_and_label_is_noop() -> void:
	var r: EventRunner = _run([_goto(&"b"), _say("pulado"), _label(&"b"), _say("chegou")] as Array[EventStep])
	assert_eq(_drain(r), ["chegou"] as Array[String])

func test_backward_goto_loop_with_counter() -> void:
	var add := AddFlagStep.new()
	add.flag = &"i"
	var r: EventRunner = _run([_label(&"top"), add, _if(&"i", IfFlagStep.Op.LT, 5, &""), _goto(&"top")] as Array[EventStep])
	assert_true(r.finished)
	assert_false(r.aborted)
	assert_eq(g.get_flag(&"i"), 5)

func _choice_script() -> Array[EventStep]:
	var c := ChoiceStep.new()
	c.prompt = "Quer?"
	c.options = PackedStringArray(["Sim", "Nao"])
	c.flag = &"resp"
	return [c, _if(&"resp", IfFlagStep.Op.EQ, 0, &"b"), _say("A"), _goto(&"fim"), _label(&"b"), _say("B"), _label(&"fim")] as Array[EventStep]

func test_choice_writes_flag_and_branches() -> void:
	var r: EventRunner = _run(_choice_script())
	assert_eq(r.current().kind, EventRequest.Kind.CHOICE)
	assert_eq(r.current().options, PackedStringArray(["Sim", "Nao"]))
	assert_eq(r.current().text, "Quer?")
	r.resume(1)
	assert_eq(g.get_flag(&"resp"), 1)
	assert_eq(_drain(r), ["B"] as Array[String])

func test_choice_first_option_branch() -> void:
	var r: EventRunner = _run(_choice_script())
	r.resume(0)
	assert_eq(g.get_flag(&"resp"), 0)
	assert_eq(_drain(r), ["A"] as Array[String])

func test_choice_answer_is_clamped() -> void:
	var c := ChoiceStep.new()
	c.options = PackedStringArray(["A", "B"])
	c.flag = &"r"
	var r: EventRunner = _run([c] as Array[EventStep])
	r.resume(99)
	assert_eq(g.get_flag(&"r"), 1)
	assert_true(r.finished)

func test_choice_without_options_is_skipped() -> void:
	var c := ChoiceStep.new()
	c.flag = &"r"
	var r: EventRunner = _run([c, _say("x")] as Array[EventStep])
	assert_eq(r.current().kind, EventRequest.Kind.SAY, "não trava numa escolha vazia")

func test_loop_without_presentation_aborts_at_limit() -> void:
	cfg.event_max_steps = 50
	var add := AddFlagStep.new()
	add.flag = &"n"
	var r: EventRunner = _run([_label(&"top"), add, _goto(&"top")] as Array[EventStep])
	assert_true(r.finished)
	assert_true(r.aborted)
	assert_null(r.current())
	assert_lte(g.get_flag(&"n"), 50)
	assert_gt(g.get_flag(&"n"), 10)
	assert_push_error("laço infinito")

func test_loop_with_presentation_does_not_abort() -> void:
	cfg.event_max_steps = 50
	var r: EventRunner = _run([_label(&"top"), _say("de novo"), _goto(&"top")] as Array[EventStep])
	for i: int in 200:
		assert_false(r.finished, "fala reinicia a contagem")
		r.resume()
	assert_false(r.aborted)

func test_unknown_label_aborts() -> void:
	var r: EventRunner = _run([_goto(&"nada"), _say("x")] as Array[EventStep])
	assert_true(r.finished)
	assert_true(r.aborted)
	assert_push_error("não existe")

func test_resume_after_finish_is_noop() -> void:
	var r: EventRunner = _run([_say("x")] as Array[EventStep])
	r.resume()
	r.resume()
	r.resume(3)
	assert_true(r.finished)

func test_cancel_stops_runner() -> void:
	var r: EventRunner = _run([_say("x"), _setf(&"f", 1)] as Array[EventStep])
	r.cancel()
	assert_true(r.finished)
	r.resume()
	assert_eq(g.get_flag(&"f"), 0)

func test_give_item_and_equipment() -> void:
	var item := ItemDef.new()
	item.id = &"pocao"
	item.display_name = "Poção"
	var eq := EquipmentDef.new()
	eq.id = &"espada"
	var gi := GiveItemStep.new()
	gi.item = item
	gi.count = 2
	var ge := GiveEquipmentStep.new()
	ge.equipment = eq
	ge.count = 1
	_run([gi, ge] as Array[EventStep])
	assert_eq(g.inventory.available(&"pocao"), 2)
	assert_eq(g.bag.count(&"espada"), 1)

func test_heal_restores_part_of_max_and_skips_downed() -> void:
	var hp_max: int = StatCalculator.hp_max(Combatant.from_hero(g.heroes[0], Vector2.ZERO), cfg)
	g.heroes[0].hp = 1
	g.heroes[1].hp = 0
	var h := HealStep.new()
	h.pct = 0.5
	_run([h] as Array[EventStep])
	assert_eq(g.heroes[0].hp, mini(hp_max, 1 + ceili(hp_max * 0.5)))
	assert_eq(g.heroes[1].hp, 0, "não reanima")
	_run([HealStep.new()] as Array[EventStep])
	assert_eq(g.heroes[0].hp, hp_max)

func test_presentation_steps_become_requests() -> void:
	var mv := MoveActorStep.new()
	mv.actor = ^"Npc"
	mv.to_marker = ^"Alvo"
	mv.speed = 50.0
	var w := WaitStep.new()
	w.seconds = 0.25
	var cam := CameraToStep.new()
	cam.marker = ^"Alvo"
	var sb := StartBattleStep.new()
	sb.encounter = EncounterDef.new()
	var r: EventRunner = _run([mv, w, cam, sb] as Array[EventStep])
	assert_eq(r.current().kind, EventRequest.Kind.MOVE_ACTOR)
	assert_eq(r.current().actor, ^"Npc")
	assert_eq(r.current().marker, ^"Alvo")
	assert_eq(r.current().speed, 50.0)
	r.resume()
	assert_eq(r.current().kind, EventRequest.Kind.WAIT)
	assert_eq(r.current().seconds, 0.25)
	r.resume()
	assert_eq(r.current().kind, EventRequest.Kind.CAMERA_TO)
	r.resume()
	assert_eq(r.current().kind, EventRequest.Kind.START_BATTLE)
	assert_not_null(r.current().encounter)
	r.resume()
	assert_true(r.finished)

func test_start_battle_without_encounter_is_skipped() -> void:
	var r: EventRunner = _run([StartBattleStep.new()] as Array[EventStep])
	assert_true(r.finished)

func test_teach_learns_event_technique_and_announces_once() -> void:
	var ab: AbilityDef = Fixtures.hit(1.0)
	ab.id = &"rajada"
	ab.display_name = "Rajada"
	var entry := LearnEntry.new()
	entry.ability = ab
	entry.level = 0
	g.heroes[0].def.learnset = [entry] as Array[LearnEntry]
	var t := TeachStep.new()
	t.hero_id = &"a"
	t.ability_id = &"rajada"
	var r: EventRunner = _run([t, t] as Array[EventStep])
	assert_true(g.heroes[0].learned.has(&"rajada"))
	assert_eq(r.current().speaker, "")
	assert_eq(r.current().text, "a aprendeu Rajada!")
	r.resume()
	assert_true(r.finished, "segunda vez não repete o aviso")

func test_teach_unknown_hero_or_ability_does_nothing() -> void:
	var t := TeachStep.new()
	t.hero_id = &"zzz"
	t.ability_id = &"rajada"
	var t2 := TeachStep.new()
	t2.hero_id = &"a"
	t2.ability_id = &"nao_existe"
	var r: EventRunner = _run([t, t2] as Array[EventStep])
	assert_true(r.finished)

func test_flags_roundtrip_in_save_dict() -> void:
	g.set_flag(&"bau_1", 1)
	g.set_flag(&"contador", 7)
	var loaded: GameState = _reload(g.to_dict())
	assert_not_null(loaded)
	assert_eq(loaded.get_flag(&"bau_1"), 1)
	assert_eq(loaded.get_flag(&"contador"), 7)
	assert_eq(loaded.flags.size(), 2)

func test_save_without_flags_has_no_field_and_loads() -> void:
	assert_false(g.to_dict().has("flags"), "campo opcional")
	var loaded: GameState = _reload(g.to_dict())
	assert_not_null(loaded)
	assert_true(loaded.flags.is_empty())

func test_invalid_flag_entries_are_ignored() -> void:
	var d: Dictionary = g.to_dict()
	d["flags"] = {"ok": 2, "": 1, "texto": "x", "lista": [1]}
	var loaded: GameState = _reload(d)
	assert_eq(loaded.flags.size(), 1)
	assert_eq(loaded.get_flag(&"ok"), 2)

func test_restore_save_reverts_flags() -> void:
	g.set_flag(&"antes", 1)
	g.save(&"overworld", &"Start")
	g.set_flag(&"antes", 5)
	g.set_flag(&"depois", 1)
	g.restore_save()
	assert_eq(g.get_flag(&"antes"), 1)
	assert_eq(g.get_flag(&"depois"), 0)
	g.set_flag(&"antes", 9)
	g.restore_save()
	assert_eq(g.get_flag(&"antes"), 1, "snapshot não é afetado por mudanças posteriores")

func test_give_item_respects_the_cap_and_tells_the_player() -> void:
	var item := ItemDef.new()
	item.id = &"pocao"
	item.display_name = "Poção"
	g.inventory.add(item, cfg.max_stack - 1)
	var gi := GiveItemStep.new()
	gi.item = item
	gi.count = 3
	var r: EventRunner = _run([gi, _say("depois")] as Array[EventStep])
	assert_eq(g.inventory.count(&"pocao"), cfg.max_stack)
	assert_eq(_drain(r), ["Poção: mochila cheia", "depois"] as Array[String])

func test_give_item_that_fits_says_nothing_and_key_items_ignore_the_cap() -> void:
	var item := ItemDef.new()
	item.id = &"erva"
	item.display_name = "Erva"
	item.key_item = true
	g.inventory.add(item, cfg.max_stack)
	var gi := GiveItemStep.new()
	gi.item = item
	var r: EventRunner = _run([gi] as Array[EventStep])
	assert_true(r.finished)
	assert_eq(g.inventory.count(&"erva"), cfg.max_stack + 1)

func test_give_equipment_respects_the_cap() -> void:
	var eq := EquipmentDef.new()
	eq.id = &"espada"
	eq.display_name = "Espada"
	g.bag.add(eq, cfg.max_stack)
	var ge := GiveEquipmentStep.new()
	ge.equipment = eq
	var r: EventRunner = _run([ge] as Array[EventStep])
	assert_eq(g.bag.count(&"espada"), cfg.max_stack)
	assert_eq(_drain(r), ["Espada: mochila cheia"] as Array[String])

# --- IfItemStep e TakeItemStep ----------------------------------------------------------

func _herb(key: bool = true) -> ItemDef:
	var item := ItemDef.new()
	item.id = &"erva"
	item.display_name = "Erva"
	item.key_item = key
	return item

func _if_item(item: ItemDef, n: int, else_label: StringName) -> IfItemStep:
	var s := IfItemStep.new()
	s.item = item
	s.count = n
	s.else_label = else_label
	return s

func _take(item: ItemDef, n: int) -> TakeItemStep:
	var s := TakeItemStep.new()
	s.item = item
	s.count = n
	return s

func test_if_item_follows_when_the_party_has_enough() -> void:
	var herb: ItemDef = _herb()
	g.inventory.add(herb, 2)
	var r: EventRunner = _run([_if_item(herb, 2, &"falta"), _say("tem"), _goto(&"fim"), _label(&"falta"), _say("falta"), _label(&"fim")] as Array[EventStep])
	assert_eq(_drain(r), ["tem"] as Array[String])

func test_if_item_jumps_to_else_when_short_or_missing() -> void:
	var herb: ItemDef = _herb()
	var steps: Array[EventStep] = [_if_item(herb, 2, &"falta"), _say("tem"), _goto(&"fim"), _label(&"falta"), _say("falta"), _label(&"fim")]
	assert_eq(_drain(_run(steps)), ["falta"] as Array[String], "sem o item")
	g.inventory.add(herb, 1)
	assert_eq(_drain(_run(steps)), ["falta"] as Array[String], "1 de 2")

func test_if_item_default_count_is_one_and_empty_else_ends_the_event() -> void:
	var herb: ItemDef = _herb()
	var s := IfItemStep.new()
	s.item = herb
	assert_eq(s.count, 1)
	var r: EventRunner = _run([s, _say("nunca")] as Array[EventStep])
	assert_true(r.finished, "falta e else vazio: termina")
	g.inventory.add(herb, 1)
	var r2: EventRunner = _run([s, _say("tem")] as Array[EventStep])
	assert_eq(_drain(r2), ["tem"] as Array[String])

func test_if_item_with_a_null_item_takes_the_else_branch() -> void:
	var r: EventRunner = _run([IfItemStep.new(), _say("nunca")] as Array[EventStep])
	assert_true(r.finished)

func test_take_item_removes_it_even_a_key_item_and_says_so() -> void:
	var herb: ItemDef = _herb(true)
	g.inventory.add(herb, 3)
	var r: EventRunner = _run([_take(herb, 2), _say("depois")] as Array[EventStep])
	assert_eq(g.inventory.count(&"erva"), 1)
	assert_eq(_drain(r), ["Entregou Erva x2!", "depois"] as Array[String])
	var r2: EventRunner = _run([_take(herb, 1)] as Array[EventStep])
	assert_eq(g.inventory.count(&"erva"), 0)
	assert_eq(r2.current().text, "Entregou Erva!")

func test_take_item_without_enough_takes_nothing_and_stays_quiet() -> void:
	var herb: ItemDef = _herb()
	g.inventory.add(herb, 1)
	var r: EventRunner = _run([_take(herb, 2)] as Array[EventStep])
	assert_true(r.finished)
	assert_eq(g.inventory.count(&"erva"), 1)

func _if_money(op: IfFlagStep.Op, amount: int, else_label: StringName) -> IfMoneyStep:
	var s := IfMoneyStep.new()
	s.op = op
	s.amount = amount
	s.else_label = else_label
	return s

func test_if_money_every_operator_and_else_jump() -> void:
	g.money = 50
	var cases: Array = [
		[IfFlagStep.Op.EQ, 50, true], [IfFlagStep.Op.EQ, 49, false],
		[IfFlagStep.Op.NE, 49, true], [IfFlagStep.Op.GE, 50, true], [IfFlagStep.Op.GE, 51, false],
		[IfFlagStep.Op.GT, 50, false], [IfFlagStep.Op.LT, 51, true], [IfFlagStep.Op.LE, 49, false],
	]
	for c: Array in cases:
		var r: EventRunner = _run([_if_money(c[0], c[1], &"fim"), _say("passou"), _label(&"fim")] as Array[EventStep])
		assert_eq(r.current() != null, c[2], "op %d valor %d" % [c[0], c[1]])

func test_if_money_false_without_label_ends_event() -> void:
	var r: EventRunner = _run([_if_money(IfFlagStep.Op.GE, 10, &""), _say("nao")] as Array[EventStep])
	assert_true(r.finished)
	assert_null(r.current())

func test_say_step_portrait_goes_into_request() -> void:
	var s := _say("oi", "Ana")
	s.portrait = &"feliz"
	var r: EventRunner = _run([s] as Array[EventStep])
	assert_eq(r.current().portrait, &"feliz")
	assert_eq(EventRequest.say("x", "y").portrait, &"")

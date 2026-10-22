extends GutTest

## RoteiroCompiler (M16): cada linha da sintaxe, escolhas executadas no EventRunner real, erros com linha, avisos.

var g: GameState
var _defs: Dictionary = {}

func before_each() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var hero: CharacterDef = Fixtures.hero_def(&"teste_a", Stats.make(1, 1, 3, 2))
	g = GameState.new_game(cfg, [hero] as Array[CharacterDef], [], [], ScriptedDice.new(), &"overworld", &"Start")
	_defs = {}
	var erva := ItemDef.new()
	erva.id = &"erva_teste"
	erva.display_name = "Erva de Teste"
	_defs["item/erva_teste"] = erva
	var capacete := EquipmentDef.new()
	capacete.id = &"capacete"
	capacete.display_name = "Capacete"
	_defs["equip/capacete"] = capacete
	_defs["hero/teste_a"] = hero
	var heroi_b: CharacterDef = Fixtures.hero_def(&"teste_b", Stats.make(1, 1, 3, 2))
	_defs["hero/teste_b"] = heroi_b
	var enc := EncounterDef.new()
	enc.id = &"duelo"
	_defs["encounter/duelo"] = enc
	var ab := AbilityDef.new()
	ab.id = &"golpe"
	_defs["ability/golpe"] = ab

func _res(kind: StringName, id: StringName) -> Resource:
	return _defs.get("%s/%s" % [kind, id]) as Resource

func _c(text: String) -> Dictionary:
	return RoteiroCompiler.compile(text, "t.roteiro", _res)

## Compila um evento só (sem erros esperados) e devolve seus passos.
func _steps(body: String) -> Array[EventStep]:
	var r: Dictionary = _c("@flag a\n@flag b\n@flag escolha\n=== e\n" + body)
	assert_eq(r.errors, [] as Array[String], "sem erros: " + body)
	var events: Dictionary = r.events
	return (events[&"e"] as EventScript).steps

func _errs(body: String) -> Array[String]:
	return _c(body).errors

## Roda o evento no runner; `answers` responde às escolhas em ordem. Devolve os textos das falas.
func _play(ev: EventScript, answers: Array[int] = []) -> Array[String]:
	var r := EventRunner.new(ev, g)
	r.start()
	var out: Array[String] = []
	var ai: int = 0
	var guard: int = 0
	while not r.finished and guard < 100:
		var q: EventRequest = r.current()
		if q.kind == EventRequest.Kind.CHOICE:
			out.append("?" + q.text)
			var a: int = answers[ai] if ai < answers.size() else 0
			ai += 1
			r.resume(a)
		else:
			out.append(q.text)
			r.resume()
		guard += 1
	assert_false(r.aborted, "evento não abortou")
	return out

func _event(text: String) -> EventScript:
	var r: Dictionary = _c(text)
	assert_eq(r.errors, [] as Array[String])
	var events: Dictionary = r.events
	return events[&"e"]

# --- falas ---

func test_say_and_system_line_and_portrait() -> void:
	var s: Array[EventStep] = _steps("Morador C: oi\nAna [feliz]: olá\n: Missão feita!")
	var a: SayStep = s[0]
	assert_eq(a.speaker, "Morador C")
	assert_eq(a.text, "oi")
	assert_eq(a.portrait, &"")
	var b: SayStep = s[1]
	assert_eq(b.speaker, "Ana")
	assert_eq(b.portrait, &"feliz")
	var c: SayStep = s[2]
	assert_eq(c.speaker, "")
	assert_eq(c.text, "Missão feita!")

func test_continuation_joins_with_newline() -> void:
	var s: Array[EventStep] = _steps("Ana: primeira\n| segunda\n| terceira")
	assert_eq((s[0] as SayStep).text, "primeira\nsegunda\nterceira")

func test_accents_and_colon_in_text() -> void:
	var s: Array[EventStep] = _steps("Zé Açaí: Olá! Preço: 3 moedas — ação")
	assert_eq((s[0] as SayStep).speaker, "Zé Açaí")
	assert_eq((s[0] as SayStep).text, "Olá! Preço: 3 moedas — ação")

func test_comments_and_blank_lines_ignored() -> void:
	var s: Array[EventStep] = _steps("# comentário\n\nAna: oi\n   \n# outro\nAna: tchau")
	assert_eq(s.size(), 3, "duas falas + fim")

func test_say_portrait_reaches_request() -> void:
	var ev: EventScript = _event("=== e\nAna [feliz]: oi")
	var r := EventRunner.new(ev, g)
	r.start()
	assert_eq(r.current().portrait, &"feliz")
	assert_eq(r.current().speaker, "Ana")

# --- fluxo ---

func test_labels_goto_and_implicit_fim() -> void:
	var s: Array[EventStep] = _steps("-> pula\nAna: ignorada\n== pula\nAna: chegou\n-> fim")
	assert_true(s[0] is GotoStep)
	assert_eq((s[0] as GotoStep).label, &"pula")
	assert_true(s[2] is LabelStep)
	assert_eq((s[2] as LabelStep).label_name, &"pula")
	var last: LabelStep = s[s.size() - 1] as LabelStep
	assert_eq(last.label_name, &"fim", "fim implícito no fim do evento")
	var ev := EventScript.new()
	ev.steps = s
	assert_eq(_play(ev), ["chegou"] as Array[String])

func test_fim_label_cannot_be_declared() -> void:
	var e: Array[String] = _errs("=== e\n== fim")
	assert_eq(e.size(), 1)
	assert_string_contains(e[0], "t.roteiro:2:")

# --- condições ---

func test_if_flag_pattern_inverts_operator() -> void:
	var cases: Dictionary = {
		"==": IfFlagStep.Op.NE, "!=": IfFlagStep.Op.EQ, ">=": IfFlagStep.Op.LT,
		"<=": IfFlagStep.Op.GT, ">": IfFlagStep.Op.LE, "<": IfFlagStep.Op.GE,
	}
	for sym: String in cases:
		var s: Array[EventStep] = _steps("? a %s 3 -> alvo\n== alvo" % sym)
		var f: IfFlagStep = s[0] as IfFlagStep
		assert_not_null(f, sym)
		assert_eq(f.op, cases[sym], "op invertido de " + sym)
		assert_eq(f.flag, &"a")
		assert_eq(f.value, 3)
		assert_eq(f.else_label, &"alvo", "o desvio vai no else")

func test_if_flag_runs_both_ways() -> void:
	var text: String = "@flag a\n=== e\n? a >= 2 -> alto\nAna: baixo\n-> fim\n== alto\nAna: alto"
	var ev: EventScript = _event(text)
	g.set_flag(&"a", 1)
	assert_eq(_play(ev), ["baixo"] as Array[String])
	g.set_flag(&"a", 2)
	assert_eq(_play(ev), ["alto"] as Array[String])
	g.set_flag(&"a", 5)
	assert_eq(_play(ev), ["alto"] as Array[String])

func test_if_item_runs_both_ways() -> void:
	var ev: EventScript = _event("=== e\n? item erva_teste 2 -> tem\nAna: falta\n-> fim\n== tem\nAna: tem")
	var s: Array[EventStep] = ev.steps
	assert_true(s[0] is IfItemStep)
	assert_eq((s[0] as IfItemStep).count, 2)
	assert_eq((s[0] as IfItemStep).item.id, &"erva_teste")
	assert_true(s[1] is GotoStep)
	assert_eq(_play(ev), ["falta"] as Array[String])
	g.grant_item(_defs["item/erva_teste"], 1)
	assert_eq(_play(ev), ["falta"] as Array[String])
	g.grant_item(_defs["item/erva_teste"], 1)
	assert_eq(_play(ev), ["tem"] as Array[String])

func test_if_item_default_count_is_one() -> void:
	var s: Array[EventStep] = _steps("? item erva_teste -> x\n== x")
	assert_eq((s[0] as IfItemStep).count, 1)

func test_if_money_runs_both_ways() -> void:
	var ev: EventScript = _event("=== e\n? dinheiro >= 50 -> rico\nAna: pobre\n-> fim\n== rico\nAna: rico")
	var m: IfMoneyStep = ev.steps[0] as IfMoneyStep
	assert_not_null(m)
	assert_eq(m.op, IfFlagStep.Op.LT)
	assert_eq(m.amount, 50)
	assert_eq(m.else_label, &"rico")
	g.money = 49
	assert_eq(_play(ev), ["pobre"] as Array[String])
	g.money = 50
	assert_eq(_play(ev), ["rico"] as Array[String])

# --- escolhas ---

func _choice_text(n: int) -> String:
	var t: String = "@flag escolha\n=== e\nAna: Vamos?\n"
	for i: int in n:
		t += "* Opção %d -> r%d\n" % [i, i]
	for i: int in n:
		t += "== r%d\nAna: caminho %d\n-> fim\n" % [i, i]
	return t

func test_choice_pattern() -> void:
	var s: Array[EventStep] = _event(_choice_text(3)).steps
	var c: ChoiceStep = s[0] as ChoiceStep
	assert_not_null(c, "a pergunta vira ChoiceStep")
	assert_eq(c.prompt, "Vamos?")
	assert_eq(c.options, PackedStringArray(["Opção 0", "Opção 1", "Opção 2"]))
	assert_true(String(c.flag).begins_with("_esc_e_"), "flag oculta gerada")
	# IfFlag(flag==0, else=skip1) Goto(r0) Label(skip1) IfFlag(flag==1, else=skip2) Goto(r1) Label(skip2) Goto(r2)
	var f0: IfFlagStep = s[1] as IfFlagStep
	assert_eq(f0.flag, c.flag)
	assert_eq(f0.op, IfFlagStep.Op.EQ)
	assert_eq(f0.value, 0)
	assert_eq((s[2] as GotoStep).label, &"r0")
	assert_eq((s[3] as LabelStep).label_name, f0.else_label)
	assert_eq((s[4] as IfFlagStep).value, 1)
	assert_eq((s[5] as GotoStep).label, &"r1")
	assert_true(s[6] is LabelStep)
	assert_eq((s[7] as GotoStep).label, &"r2", "a última opção é Goto direto")

func test_choice_with_two_options_goes_to_right_labels() -> void:
	var ev: EventScript = _event(_choice_text(2))
	assert_eq(_play(ev, [0] as Array[int]), ["?Vamos?", "caminho 0"] as Array[String])
	assert_eq(_play(ev, [1] as Array[int]), ["?Vamos?", "caminho 1"] as Array[String])

func test_choice_with_four_options_goes_to_right_labels() -> void:
	var ev: EventScript = _event(_choice_text(4))
	for i: int in 4:
		assert_eq(_play(ev, [i] as Array[int]), ["?Vamos?", "caminho %d" % i] as Array[String], "opção %d" % i)

func test_choice_with_one_option() -> void:
	var ev: EventScript = _event(_choice_text(1))
	assert_eq(_play(ev, [0] as Array[int]), ["?Vamos?", "caminho 0"] as Array[String])

func test_choice_option_to_fim_and_continuation_in_prompt() -> void:
	var ev: EventScript = _event("=== e\nAna: Linha um\n| linha dois?\n* Sim -> ok\n* Não -> fim\n== ok\nAna: valeu")
	assert_eq((ev.steps[0] as ChoiceStep).prompt, "Linha um\nlinha dois?")
	assert_eq(_play(ev, [0] as Array[int]), ["?Linha um\nlinha dois?", "valeu"] as Array[String])
	assert_eq(_play(ev, [1] as Array[int]), ["?Linha um\nlinha dois?"] as Array[String])

func test_two_choices_in_one_event_use_distinct_flags() -> void:
	var ev: EventScript = _event("=== e\nA: um?\n* x -> p\n* y -> p\n== p\nA: dois?\n* x -> q\n* y -> q\n== q\nA: fim")
	var flags: Array[StringName] = []
	for st: EventStep in ev.steps:
		if st is ChoiceStep:
			flags.append((st as ChoiceStep).flag)
	assert_eq(flags.size(), 2)
	assert_ne(flags[0], flags[1])

func test_choice_flag_not_reported_as_undeclared() -> void:
	var r: Dictionary = _c("=== e\nA: um?\n* x -> fim\n* y -> fim")
	assert_eq(r.errors, [] as Array[String])
	assert_eq(r.warnings, [] as Array[String])

# --- comandos ---

func test_set_and_add() -> void:
	var s: Array[EventStep] = _steps("@set a 3\n@add b -2")
	assert_eq((s[0] as SetFlagStep).flag, &"a")
	assert_eq((s[0] as SetFlagStep).value, 3)
	assert_eq((s[1] as AddFlagStep).flag, &"b")
	assert_eq((s[1] as AddFlagStep).delta, -2)

func test_give_take_commands() -> void:
	var s: Array[EventStep] = _steps("@give item erva_teste\n@give item erva_teste 3\n@give equip capacete\n@give equip capacete 2\n@give moedas 40\n@take item erva_teste 2\n@take item erva_teste")
	assert_eq((s[0] as GiveItemStep).item.id, &"erva_teste")
	assert_eq((s[0] as GiveItemStep).count, 1)
	assert_eq((s[1] as GiveItemStep).count, 3)
	assert_eq((s[2] as GiveEquipmentStep).equipment.id, &"capacete")
	assert_eq((s[2] as GiveEquipmentStep).count, 1)
	assert_eq((s[3] as GiveEquipmentStep).count, 2)
	assert_eq((s[4] as GiveMoneyStep).amount, 40)
	assert_eq((s[5] as TakeItemStep).count, 2)
	assert_eq((s[6] as TakeItemStep).count, 1)

func test_xp_command() -> void:
	var s: Array[EventStep] = _steps("@xp 120\n@xp 50 ativos\n@xp 30 todos")
	assert_eq((s[0] as GrantXpStep).amount, 120)
	assert_eq((s[0] as GrantXpStep).rule, GrantXpStep.Rule.ACTIVE)
	assert_eq((s[1] as GrantXpStep).rule, GrantXpStep.Rule.ACTIVE)
	assert_eq((s[2] as GrantXpStep).rule, GrantXpStep.Rule.ALL_RECRUITED)

func test_teach_heal_recruit_battle() -> void:
	var s: Array[EventStep] = _steps("@ensinar teste_a golpe\n@curar\n@curar 50\n@curar 25%\n@recrutar teste_b\n@recrutar teste_b nivel 4\n@batalha duelo")
	assert_eq((s[0] as TeachStep).hero_id, &"teste_a")
	assert_eq((s[0] as TeachStep).ability_id, &"golpe")
	assert_almost_eq((s[1] as HealStep).pct, 1.0, 0.0001)
	assert_almost_eq((s[2] as HealStep).pct, 0.5, 0.0001)
	assert_almost_eq((s[3] as HealStep).pct, 0.25, 0.0001)
	assert_eq((s[4] as RecruitStep).hero.id, &"teste_b")
	assert_eq((s[4] as RecruitStep).level_mode, RecruitStep.LevelMode.PARTY_AVG)
	assert_eq((s[5] as RecruitStep).level_mode, RecruitStep.LevelMode.FIXED)
	assert_eq((s[5] as RecruitStep).level, 4)
	assert_eq((s[6] as StartBattleStep).encounter.id, &"duelo")

func test_move_camera_wait_end_demo() -> void:
	var s: Array[EventStep] = _steps("@mover Npc Marker\n@mover Player Marker2 120.5\n@camera Marker\n@esperar 0.5\n@esperar 2\n@fim_demo")
	assert_eq((s[0] as MoveActorStep).actor, NodePath("Npc"))
	assert_eq((s[0] as MoveActorStep).to_marker, NodePath("Marker"))
	assert_eq((s[0] as MoveActorStep).speed, 0.0)
	assert_almost_eq((s[1] as MoveActorStep).speed, 120.5, 0.001)
	assert_eq((s[2] as CameraToStep).marker, NodePath("Marker"))
	assert_almost_eq((s[3] as WaitStep).seconds, 0.5, 0.001)
	assert_almost_eq((s[4] as WaitStep).seconds, 2.0, 0.001)
	assert_true(s[5] is EndDemoStep)

func test_compiled_rule_commands_run_in_game_state() -> void:
	var ev: EventScript = _event("@flag a\n=== e\n@give moedas 40\n@give item erva_teste 2\n@give equip capacete\n@take item erva_teste\n@set a 7\n@add a 1\n: pronto")
	assert_eq(_play(ev).size(), 2, "linha de entrega + pronto")
	assert_eq(g.money, 40)
	assert_eq(g.inventory.count(&"erva_teste"), 1)
	assert_eq(g.bag.count(&"capacete"), 1)
	assert_eq(g.get_flag(&"a"), 8)

# --- vários eventos, vazio ---

func test_several_events_in_one_file() -> void:
	var r: Dictionary = _c("# cabeçalho\n=== um\nAna: a\n=== dois\nAna: b\n== x\n=== tres\n: c")
	assert_eq(r.errors, [] as Array[String])
	var events: Dictionary = r.events
	assert_eq(events.keys().size(), 3)
	assert_true(events.has(&"um") and events.has(&"dois") and events.has(&"tres"))
	assert_eq(((events[&"um"] as EventScript).steps[0] as SayStep).text, "a")
	assert_eq(((events[&"tres"] as EventScript).steps[0] as SayStep).text, "c")
	for id: StringName in events:
		var st: Array[EventStep] = (events[id] as EventScript).steps
		assert_eq((st[st.size() - 1] as LabelStep).label_name, &"fim", "fim implícito em " + String(id))

func test_labels_are_per_event() -> void:
	var r: Dictionary = _c("=== um\n== x\n=== dois\n== x")
	assert_eq(r.errors, [] as Array[String])

func test_empty_file() -> void:
	for t: String in ["", "\n\n", "# só comentário\n"]:
		var r: Dictionary = _c(t)
		assert_eq(r.errors, [] as Array[String])
		assert_eq(r.warnings, [] as Array[String])
		var events: Dictionary = r.events
		assert_true(events.is_empty())

func test_crlf_and_bom() -> void:
	var r: Dictionary = _c("﻿=== e\r\nAna: oi\r\n| tchau\r\n")
	assert_eq(r.errors, [] as Array[String])
	var events: Dictionary = r.events
	assert_eq(((events[&"e"] as EventScript).steps[0] as SayStep).text, "oi\ntchau")

# --- flags ---

func test_undeclared_flag_warns_once_per_use_with_line() -> void:
	var r: Dictionary = _c("=== e\n@set misteriosa 1\n? outra == 1 -> fim")
	assert_eq(r.errors, [] as Array[String])
	var w: Array[String] = r.warnings
	assert_eq(w.size(), 2)
	assert_eq(w[0], "t.roteiro:2: flag 'misteriosa' usada sem '@flag misteriosa'")
	assert_string_contains(w[1], "t.roteiro:3:")

func test_declared_flag_after_use_is_fine() -> void:
	var r: Dictionary = _c("=== e\n@set x 1\n@flag x")
	assert_eq(r.warnings, [] as Array[String])

# --- erros ---

func test_error_line_outside_event() -> void:
	var e: Array[String] = _errs("Ana: oi\n=== e\nAna: ok")
	assert_eq(e, ["t.roteiro:1: linha fora de um evento (use '=== id' antes)"] as Array[String])

func test_error_duplicate_label() -> void:
	var e: Array[String] = _errs("=== e\n== a\nAna: x\n== a")
	assert_eq(e, ["t.roteiro:4: rótulo 'a' repetido (já definido na linha 2)"] as Array[String])

func test_error_unknown_label() -> void:
	var e: Array[String] = _errs("=== e\nAna: oi\n-> aceita\n? dinheiro >= 1 -> outro")
	assert_eq(e.size(), 2)
	assert_eq(e[0], "t.roteiro:3: rótulo 'aceita' não existe")
	assert_eq(e[1], "t.roteiro:4: rótulo 'outro' não existe")

func test_error_unknown_label_in_choice() -> void:
	var e: Array[String] = _errs("=== e\nAna: ok?\n* sim -> la")
	assert_eq(e, ["t.roteiro:3: rótulo 'la' não existe"] as Array[String])

func test_error_choice_without_options() -> void:
	var e: Array[String] = _errs("=== e\nAna: ok?\n* ->")
	assert_true(e.has("t.roteiro:3: opção vazia"))
	assert_true(e.has("t.roteiro:2: escolha sem opções"))

func test_error_option_without_question() -> void:
	var e: Array[String] = _errs("=== e\n* sim -> fim")
	assert_eq(e, ["t.roteiro:2: opção '*' sem pergunta antes (use 'Nome: pergunta?')"] as Array[String])

func test_error_choice_with_five_options() -> void:
	var e: Array[String] = _errs("=== e\nAna: ok?\n* a -> fim\n* b -> fim\n* c -> fim\n* d -> fim\n* e -> fim")
	assert_eq(e, ["t.roteiro:7: escolha com mais de 4 opções"] as Array[String])

func test_error_unknown_command() -> void:
	var e: Array[String] = _errs("=== e\n@voar alto")
	assert_eq(e, ["t.roteiro:2: comando desconhecido '@voar'"] as Array[String])

func test_error_unknown_ids() -> void:
	var e: Array[String] = _errs("=== e\n@give item nada\n@give equip nada\n@recrutar nada\n@batalha nada\n@ensinar teste_a nada\n@ensinar nada golpe\n? item nada -> fim")
	assert_eq(e, [
		"t.roteiro:2: item 'nada' não existe",
		"t.roteiro:3: equipamento 'nada' não existe",
		"t.roteiro:4: herói 'nada' não existe",
		"t.roteiro:5: encontro 'nada' não existe",
		"t.roteiro:6: habilidade 'nada' não existe",
		"t.roteiro:7: herói 'nada' não existe",
		"t.roteiro:8: item 'nada' não existe",
	] as Array[String])

func test_error_bad_numbers() -> void:
	var e: Array[String] = _errs("@flag a\n=== e\n@set a x\n@give moedas -3\n@xp 1.5\n@esperar abc\n? a == z -> fim\n@give item erva_teste 0\n@curar 150\n@recrutar teste_b nivel 0")
	assert_eq(e.size(), 8)
	assert_string_contains(e[0], "t.roteiro:3: número inválido")
	for i: int in range(1, 8):
		assert_string_contains(e[i], "t.roteiro:%d:" % (i + 3))

func test_error_continuation_without_say() -> void:
	var e: Array[String] = _errs("=== e\n| solta")
	assert_eq(e, ["t.roteiro:2: '|' continua uma fala, mas não há fala antes"] as Array[String])

func test_error_unrecognized_and_empty_say() -> void:
	var e: Array[String] = _errs("=== e\ntexto sem nome\nAna:")
	assert_eq(e.size(), 2)
	assert_string_contains(e[0], "t.roteiro:2:")
	assert_eq(e[1], "t.roteiro:3: fala vazia")

func test_error_duplicate_event() -> void:
	var e: Array[String] = _errs("=== e\n=== e")
	assert_eq(e, ["t.roteiro:2: evento 'e' repetido (já definido na linha 1)"] as Array[String])

func test_keeps_going_and_collects_all_errors() -> void:
	var r: Dictionary = _c("Ana: fora\n=== e\n@voar\nAna: ok\n-> nada\n@give item xx\n=== f\nAna: bom")
	var e: Array[String] = r.errors
	assert_eq(e.size(), 4)
	var events: Dictionary = r.events
	assert_true(events.has(&"f"), "o evento seguinte ainda compila")
	assert_string_contains(e[0], "t.roteiro:1:")
	assert_string_contains(e[1], "t.roteiro:3:")

func test_invalid_resolver_reports_unknown_ids() -> void:
	var r: Dictionary = RoteiroCompiler.compile("=== e\n@batalha duelo", "t.roteiro", Callable())
	assert_eq(r.errors, ["t.roteiro:2: encontro 'duelo' não existe"] as Array[String])

# --- RoteiroBook ---

func test_roteiro_book_holds_events() -> void:
	var b := RoteiroBook.new()
	b.events[&"e"] = _event("=== e\n: oi")
	assert_true(b.events.has(&"e"))

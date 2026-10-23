extends GutTest

## Nós de evento com `roteiro` + `event_id` (M16): o roteiro vale sobre o `.tres`, o id que falta é erro, e o `.tres`
## antigo continua valendo sem roteiro. Também o ContentIndex (ids de `res://data`).

func _say_event(text: String) -> EventScript:
	return EventScript.of([EventScript.say(text)] as Array[EventStep])

func _book(id: StringName, text: String) -> RoteiroBook:
	var b := RoteiroBook.new()
	b.events = {id: _say_event(text)}
	return b

func _first_text(ev: EventScript) -> String:
	return (ev.steps[0] as SayStep).text

# --- RoteiroBook.pick ---

func test_pick_without_a_book_returns_the_tres_event() -> void:
	var tres: EventScript = _say_event("do tres")
	assert_eq(RoteiroBook.pick(null, &"x", tres), tres)
	assert_null(RoteiroBook.pick(null, &"", null))

func test_pick_prefers_the_book_when_both_are_set() -> void:
	var tres: EventScript = _say_event("do tres")
	var ev: EventScript = RoteiroBook.pick(_book(&"x", "do roteiro"), &"x", tres)
	assert_eq(_first_text(ev), "do roteiro")

func test_pick_missing_id_logs_an_error_and_falls_back_to_the_tres() -> void:
	var tres: EventScript = _say_event("do tres")
	assert_eq(RoteiroBook.pick(_book(&"x", "a"), &"outro", tres, "Ana"), tres)
	assert_push_error("não tem o evento 'outro'")
	assert_null(RoteiroBook.pick(_book(&"x", "a"), &"", null))
	assert_push_error("não tem o evento")

# --- nós ---

func test_npc_uses_the_roteiro_over_the_tres() -> void:
	var n := Npc.new()
	n.event = _say_event("do tres")
	assert_eq(_first_text(n.effective_event()), "do tres", "sem roteiro, o .tres continua valendo")
	n.roteiro = _book(&"fala", "do roteiro")
	n.event_id = &"fala"
	assert_eq(_first_text(n.effective_event()), "do roteiro")
	n.free()

func test_npc_activation_requests_the_roteiro_event() -> void:
	var n := Npc.new()
	n.roteiro = _book(&"fala", "do roteiro")
	n.event_id = &"fala"
	watch_signals(n)
	n._activate()
	assert_signal_emitted(n, "event_requested")
	var args: Array = get_signal_parameters(n, "event_requested")
	assert_eq(_first_text(args[0] as EventScript), "do roteiro")
	n.free()

func test_sign_text_is_not_built_when_a_roteiro_is_set() -> void:
	var s := Sign.new()
	s.text = "texto solto"
	s.roteiro = _book(&"placa", "do roteiro")
	s.event_id = &"placa"
	watch_signals(s)
	s._activate()
	var args: Array = get_signal_parameters(s, "event_requested")
	assert_eq(_first_text(args[0] as EventScript), "do roteiro")
	s.free()

func test_sign_text_still_works_without_roteiro() -> void:
	var s := Sign.new()
	s.text = "texto solto"
	watch_signals(s)
	s._activate()
	var args: Array = get_signal_parameters(s, "event_requested")
	assert_eq(_first_text(args[0] as EventScript), "texto solto")
	s.free()

func test_event_trigger_uses_the_roteiro_over_the_tres() -> void:
	var t := EventTrigger.new()
	t.event = _say_event("do tres")
	assert_eq(_first_text(t.effective_event()), "do tres")
	t.roteiro = _book(&"cena", "do roteiro")
	t.event_id = &"cena"
	assert_eq(_first_text(t.effective_event()), "do roteiro")
	t.free()

func test_every_interactable_kind_has_the_roteiro_fields() -> void:
	for node: Interactable in [Npc.new(), Sign.new(), Chest.new(), Inn.new(), ShopKeeper.new()]:
		assert_null(node.roteiro)
		assert_eq(node.event_id, &"")
		node.free()

# --- ContentIndex ---

func test_content_index_resolves_each_kind_by_id() -> void:
	var ix: ContentIndex = RoteiroTools.scan_content()
	assert_eq(ix.resolve(&"item", &"erva_teste").get(&"id"), &"erva_teste")
	assert_true(ix.resolve(&"equip", &"capacete_teste_b_f") is EquipmentDef)
	assert_true(ix.resolve(&"hero", &"teste_d_f") is CharacterDef)
	assert_true(ix.resolve(&"encounter", &"chefe_fatia") is EncounterDef)
	assert_gt(ix.count(&"ability"), 5)

func test_content_index_unknown_id_and_wrong_kind_are_null() -> void:
	var ix: ContentIndex = RoteiroTools.scan_content()
	assert_null(ix.resolve(&"item", &"nao_existe"))
	assert_null(ix.resolve(&"hero", &"erva_teste"), "o id de um item não resolve como herói")
	assert_null(ix.resolve(&"coisa", &"erva_teste"))

func test_content_index_has_no_repeated_ids_in_the_data() -> void:
	assert_eq(RoteiroTools.scan_content().duplicates, [] as Array[String])

func test_content_index_keeps_the_first_of_a_repeated_id() -> void:
	var a := ItemDef.new()
	a.id = &"x"
	var b := ItemDef.new()
	b.id = &"x"
	var ix: ContentIndex = ContentIndex.from_resources([a, b])
	assert_eq(ix.resolve(&"item", &"x"), a)
	assert_eq(ix.duplicates.size(), 1)

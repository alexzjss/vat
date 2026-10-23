extends GutTest

## Retratos no diálogo (M16): resolução do falante, a DialogueBox e o EventPlayer.

var box: DialogueBox

func before_each() -> void:
	box = DialogueBox.new()
	add_child_autofree(box)

static func _tex(w: int, h: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create_empty(w, h, false, Image.FORMAT_RGBA8))

static func _art(expressions: Array[StringName]) -> SpriteSet:
	var s: SpriteSet = SpriteSet.new()
	for e: StringName in expressions:
		s.portraits[e] = _tex(96, 96)
	return s

static func _hero(display: String, art: SpriteSet) -> CharacterDef:
	var d: CharacterDef = Fixtures.hero_def(StringName(display.to_lower()), Stats.make(1, 1, 1, 0))
	d.display_name = display
	d.sprites = art
	return d

static func _speaker(id: StringName, display: String, art: SpriteSet) -> SpeakerDef:
	var d: SpeakerDef = SpeakerDef.new()
	d.id = id
	d.display_name = display
	d.sprites = art
	return d

# --- resolução ---

func test_hero_is_resolved_by_display_name() -> void:
	var art: SpriteSet = _art([&"neutro"])
	var heroes: Array[CharacterDef] = [_hero("Teste A", art)]
	assert_eq(SpeakerResolver.resolve("Teste A", heroes, [] as Array[SpeakerDef]), art)

func test_speaker_def_is_resolved_by_id_or_display_name() -> void:
	var art: SpriteSet = _art([&"neutro"])
	var speakers: Array[SpeakerDef] = [_speaker(&"morador_a_exemplo", "Morador A", art)]
	assert_eq(SpeakerResolver.resolve("Morador A", [] as Array[CharacterDef], speakers), art)
	assert_eq(SpeakerResolver.resolve("morador_a_exemplo", [] as Array[CharacterDef], speakers), art)

func test_hero_wins_over_speaker_def() -> void:
	var hero_art: SpriteSet = _art([&"neutro"])
	var other_art: SpriteSet = _art([&"neutro"])
	var heroes: Array[CharacterDef] = [_hero("Ana", hero_art)]
	var speakers: Array[SpeakerDef] = [_speaker(&"ana", "Ana", other_art)]
	assert_eq(SpeakerResolver.resolve("Ana", heroes, speakers), hero_art)

func test_unknown_empty_or_portraitless_speaker_resolves_to_null() -> void:
	var heroes: Array[CharacterDef] = [_hero("Teste A", SpriteSet.new())]
	var speakers: Array[SpeakerDef] = [_speaker(&"x", "X", null)]
	assert_null(SpeakerResolver.resolve("Ninguém", heroes, speakers))
	assert_null(SpeakerResolver.resolve("", heroes, speakers))
	assert_null(SpeakerResolver.resolve("Teste A", heroes, speakers), "sem retratos")
	assert_null(SpeakerResolver.resolve("X", heroes, speakers), "sem sprites")

func test_expression_falls_back_to_neutro() -> void:
	var art: SpriteSet = _art([&"neutro", &"feliz"])
	assert_eq(SpeakerResolver.portrait_of(art, &"feliz"), art.portraits[&"feliz"])
	assert_eq(SpeakerResolver.portrait_of(art, &""), art.portraits[&"neutro"])
	assert_eq(SpeakerResolver.portrait_of(art, &"bravo"), art.portraits[&"neutro"], "expressão inexistente")
	assert_null(SpeakerResolver.portrait_of(_art([&"feliz"]), &""), "sem neutro")
	assert_null(SpeakerResolver.portrait_of(null, &"feliz"))

func test_registry_finds_the_example_morador() -> void:
	SpeakerRegistry.reset()
	var found: SpeakerDef = null
	for s: SpeakerDef in SpeakerRegistry.speakers():
		if s.display_name == "Morador A":
			found = s
	assert_not_null(found)
	assert_true(found.sprites.portraits.has(&"neutro"))
	assert_eq(SpeakerResolver.resolve("Morador A", [] as Array[CharacterDef], SpeakerRegistry.speakers()), found.sprites)

# --- caixa ---

func test_box_without_portrait_is_as_before() -> void:
	box.say("Fulano", "Oi", 1000.0)
	assert_false(box.portrait_visible())
	assert_null(box.portrait_texture())
	box.say("Fulano", "Oi", 1000.0, SpriteSet.new())
	assert_false(box.portrait_visible(), "arte sem retratos")

func test_box_shows_the_expression_at_portrait_size() -> void:
	var art: SpriteSet = _art([&"neutro", &"feliz"])
	box.say("Teste A", "Oi", 1000.0, art, &"feliz")
	assert_true(box.portrait_visible())
	assert_eq(box.portrait_texture(), art.portraits[&"feliz"])
	await get_tree().process_frame
	assert_eq(box.portrait_rect().size, Vector2(96.0, 96.0))

func test_box_empty_expression_uses_neutro() -> void:
	var art: SpriteSet = _art([&"neutro", &"feliz"])
	box.say("Teste A", "Oi", 1000.0, art)
	assert_eq(box.portrait_texture(), art.portraits[&"neutro"])

func test_portrait_sits_left_and_text_shifts_right_only_with_it() -> void:
	box.say("Fulano", "Sem retrato", 1000.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var plain_x: float = box.body_rect().position.x
	box.say("Teste A", "Com retrato", 1000.0, _art([&"neutro"]))
	await get_tree().process_frame
	await get_tree().process_frame
	var p: Rect2 = box.portrait_rect()
	var b: Rect2 = box.body_rect()
	assert_almost_eq(p.position.x, plain_x, 1.0, "retrato onde começava o texto")
	assert_gte(b.position.x, p.end.x, "texto à direita do retrato")
	assert_gt(b.position.x, plain_x + 90.0)
	box.say("Fulano", "De novo sem", 1000.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_almost_eq(box.body_rect().position.x, plain_x, 0.5, "volta ao normal")

func test_choice_with_speaker_shows_the_portrait() -> void:
	var art: SpriteSet = _art([&"neutro", &"feliz"])
	box.ask("Quer ajuda?", PackedStringArray(["Sim", "Não"]), 1000.0, "Teste A", art, &"feliz")
	assert_true(box.portrait_visible())
	assert_eq(box.portrait_texture(), art.portraits[&"feliz"])
	assert_eq(box.options.size(), 2)
	box.ask("Sistema?", PackedStringArray(["Sim"]), 1000.0)
	assert_false(box.portrait_visible())

func test_close_hides_the_portrait() -> void:
	box.say("Teste A", "Oi", 1000.0, _art([&"neutro"]))
	box.close()
	assert_false(box.portrait_visible())

# --- EventPlayer ---

func _present(req: EventRequest, hero: CharacterDef) -> EventPlayer:
	var state: GameState = GameState.new_game(Fixtures.cfg(), [hero] as Array[CharacterDef], [], [], ScriptedDice.new(), &"cidade", &"Start")
	var player := EventPlayer.new()
	add_child_autofree(player)
	player._state = state
	player._present(req, 0)
	return player

func test_event_player_passes_portrait_to_the_box() -> void:
	var hero_art: SpriteSet = _art([&"neutro", &"feliz"])
	var hero: CharacterDef = _hero("Teste A", hero_art)
	var say: EventPlayer = _present(EventRequest.say("Teste A", "Oi", &"feliz"), hero)
	assert_true(say.dialogue.portrait_visible())
	assert_eq(say.dialogue.portrait_texture(), hero_art.portraits[&"feliz"])
	var stranger: EventPlayer = _present(EventRequest.say("Ninguém", "Oi"), hero)
	assert_false(stranger.dialogue.portrait_visible())

func test_event_player_choice_uses_speaker_portrait_with_neutro_fallback() -> void:
	var hero_art: SpriteSet = _art([&"neutro", &"feliz"])
	var hero: CharacterDef = _hero("Teste A", hero_art)
	var choice := EventRequest.new()
	choice.kind = EventRequest.Kind.CHOICE
	choice.speaker = "Teste A"
	choice.text = "?"
	choice.options = PackedStringArray(["a", "b"])
	var player: EventPlayer = _present(choice, hero)
	assert_eq(player.dialogue.portrait_texture(), hero_art.portraits[&"neutro"])

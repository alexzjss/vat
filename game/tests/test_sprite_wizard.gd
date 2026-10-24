extends GutTest

## Editor de arte (M17, Task 8): as sugestões de quadro a partir do tamanho da imagem, o SpriteSet montado, e a validação
## lida das propriedades, que tem de dar as mesmas mensagens que `SpriteSet.validate()` e o aviso do `ContentChecks`.

const Wizard: GDScript = preload("res://addons/vat_editor/logic/sprite_wizard.gd")

const ART: String = "res://art/_exemplo/"

func _tex(name: String) -> Texture2D:
	return load(ART + name) as Texture2D

func _size(name: String) -> Vector2i:
	return Vector2i(_tex(name).get_size())

# --- sugestões ---

func test_the_map_placeholder_is_read_as_a_map_sheet() -> void:
	for name: String in ["teste_a_map.png", "npc_map.png"]:
		var best: Dictionary = Wizard.best(_size(name))
		assert_eq(best["kind"], Wizard.KIND_MAP, name)
		assert_eq(best["frame"], Vector2i(32, 48))
		assert_eq(best["cols"], 3)
		assert_eq(best["rows"], 4)
		assert_true(best["exact"])

func test_the_battle_placeholders_are_read_as_battle_sheets() -> void:
	for name: String in ["teste_a_battle.png", "inimigo_f1_battle.png"]:
		var best: Dictionary = Wizard.best(_size(name))
		assert_eq(best["kind"], Wizard.KIND_BATTLE, name)
		assert_eq(best["frame"], Vector2i(64, 64))
		assert_eq(best["cols"], 3)
		assert_eq(best["rows"], 6)
		assert_true(best["exact"])

func test_the_portrait_placeholders_are_read_as_portraits() -> void:
	for name: String in ["teste_a_portrait_neutro.png", "teste_a_portrait_feliz.png", "morador_a_portrait_neutro.png"]:
		var best: Dictionary = Wizard.best(_size(name))
		assert_eq(best["kind"], Wizard.KIND_PORTRAIT, name)
		assert_eq(best["frame"], Vector2i(96, 96))
		assert_true(best["exact"])

func test_exact_readings_come_before_loose_ones() -> void:
	var all: Array[Dictionary] = Wizard.suggest(Vector2i(96, 192))
	assert_eq(all[0]["kind"], Wizard.KIND_MAP)
	var seen_loose: bool = false
	for s: Dictionary in all:
		if not s["exact"]:
			seen_loose = true
		else:
			assert_false(seen_loose, "uma leitura exata depois de uma aproximada")
	var kinds: Array = all.map(func(s: Dictionary) -> Variant: return s["kind"])
	assert_true(kinds.has(Wizard.KIND_PORTRAIT), "o retrato é sempre possível")

func test_a_wider_map_sheet_keeps_the_preset_frame() -> void:
	var s: Dictionary = Wizard.suggestion_for(Vector2i(128, 192), Wizard.KIND_MAP)
	assert_eq(s["frame"], Vector2i(32, 48))
	assert_eq(s["cols"], 4)
	assert_true(s["exact"])

func test_a_battle_sheet_with_fewer_rows_is_exact() -> void:
	var s: Dictionary = Wizard.suggestion_for(Vector2i(256, 192), Wizard.KIND_BATTLE)
	assert_eq(s["cols"], 4)
	assert_eq(s["rows"], 3)
	assert_true(s["exact"])

func test_a_battle_sheet_with_more_than_six_rows_is_not_exact() -> void:
	var s: Dictionary = Wizard.suggestion_for(Vector2i(128, 512), Wizard.KIND_BATTLE)
	assert_false(s.is_empty())
	assert_false(s["exact"])
	assert_true(s["rows"] <= Wizard.BATTLE_MAX_ROWS)

func test_odd_map_sizes_get_a_guess_that_divides_the_image() -> void:
	var s: Dictionary = Wizard.suggestion_for(Vector2i(100, 200), Wizard.KIND_MAP)
	assert_false(s["exact"])
	assert_eq(s["rows"], 4)
	assert_eq(s["frame"].y * 4, 200)
	assert_eq(s["frame"].x * s["cols"], 100)

func test_a_map_needs_a_height_divisible_by_four() -> void:
	assert_true(Wizard.suggestion_for(Vector2i(96, 190), Wizard.KIND_MAP).is_empty())

func test_odd_battle_sizes_use_square_frames() -> void:
	var s: Dictionary = Wizard.suggestion_for(Vector2i(100, 50), Wizard.KIND_BATTLE)
	assert_eq(s["frame"], Vector2i(50, 50))
	assert_eq(s["cols"], 2)
	assert_eq(s["rows"], 1)
	assert_false(s["exact"])

func test_a_size_with_no_battle_reading_has_none() -> void:
	assert_true(Wizard.suggestion_for(Vector2i(97, 53), Wizard.KIND_BATTLE).is_empty())

func test_any_size_can_be_a_portrait() -> void:
	var s: Dictionary = Wizard.suggestion_for(Vector2i(120, 80), Wizard.KIND_PORTRAIT)
	assert_eq(s["frame"], Vector2i(120, 80))
	assert_false(s["exact"])

func test_empty_image_has_no_suggestion() -> void:
	assert_eq(Wizard.suggest(Vector2i.ZERO).size(), 0)
	assert_eq(Wizard.best(Vector2i(-4, 10)), {})

func test_every_suggestion_fits_the_image() -> void:
	for w: int in [16, 24, 32, 48, 50, 64, 96, 100, 128, 192, 250, 384]:
		for h: int in [16, 32, 48, 64, 96, 100, 192, 200, 384, 512]:
			var size := Vector2i(w, h)
			for s: Dictionary in Wizard.suggest(size):
				var frame: Vector2i = s["frame"]
				assert_true(frame.x > 0 and frame.y > 0, str(size))
				assert_true(frame.x * s["cols"] <= w and frame.y * s["rows"] <= h, "%s %s" % [size, s["kind"]])

# --- montar ---

func test_build_map_sheet() -> void:
	var tex: Texture2D = _tex("teste_a_map.png")
	var set: SpriteSet = Wizard.build(tex, Wizard.best(_size("teste_a_map.png")))
	assert_eq(set.map_sheet, tex)
	assert_eq(set.map_frame, Vector2i(32, 48))
	assert_eq(set.walk_frames, 3)
	assert_eq(set.validate(), [] as Array[String])
	assert_eq(Wizard.messages(set), [] as Array[String])

func test_build_battle_sheet_keeps_every_default_animation_that_fits() -> void:
	var tex: Texture2D = _tex("teste_a_battle.png")
	var set: SpriteSet = Wizard.build(tex, Wizard.best(_size("teste_a_battle.png")))
	assert_eq(set.battle_sheet, tex)
	assert_eq(set.battle_frame, Vector2i(64, 64))
	assert_eq(set.anims.size(), 6)
	assert_eq(set.anims[&"idle"], Vector3i(0, 3, 6), "os quadros ficam limitados às 3 colunas")
	assert_eq(set.anims.get_typed_key_builtin(), TYPE_STRING_NAME)
	assert_eq(set.validate(), [] as Array[String])

func test_build_battle_sheet_drops_animations_below_the_last_row() -> void:
	var anims: Dictionary[StringName, Vector3i] = Wizard.battle_anims_for(4, 3)
	assert_eq(anims.size(), 3)
	assert_true(anims.has(&"idle") and anims.has(&"attack") and anims.has(&"cast"))
	assert_false(anims.has(&"hit"))
	assert_eq(Wizard.battle_anims_for(1, 1).size(), 1)

func test_build_portrait() -> void:
	var tex: Texture2D = _tex("teste_a_portrait_neutro.png")
	var set: SpriteSet = Wizard.build(tex, Wizard.best(_size("teste_a_portrait_neutro.png")))
	assert_eq(set.portraits[&"neutro"], tex)
	assert_eq(set.portrait_size, Vector2i(96, 96))
	assert_eq(set.portraits.get_typed_value_class_name(), &"Texture2D")
	assert_eq(Wizard.issues(set).size(), 0)

func test_create_refuses_bad_ids_folders_and_existing_files() -> void:
	var s: Dictionary = Wizard.best(_size("teste_a_map.png"))
	var path: String = ART + "teste_a_map.png"
	assert_false(Wizard.create(path, s, "Maiuscula", "res://art/x")["ok"])
	assert_false(Wizard.create(path, s, "", "res://art/x")["ok"])
	assert_false(Wizard.create(path, s, "ok", "C:/fora")["ok"])
	assert_false(Wizard.create(path, s, "teste_a", "res://art/_exemplo")["ok"], "o arquivo já existe")
	assert_false(Wizard.create(path, {}, "novo_x", "res://art/_exemplo")["ok"])
	assert_false(Wizard.create("res://art/nao_existe.png", s, "novo_x", "res://art/_exemplo")["ok"])

func test_create_returns_the_resource_and_the_path_without_saving() -> void:
	var s: Dictionary = Wizard.best(_size("teste_a_map.png"))
	var made: Dictionary = Wizard.create(ART + "teste_a_map.png", s, "novo_teste_x", "res://art/_exemplo")
	assert_true(made["ok"], made["error"])
	assert_eq(made["path"], "res://art/_exemplo/novo_teste_x.tres")
	assert_true(made["resource"] is SpriteSet)
	assert_false(FileAccess.file_exists(made["path"]))

func test_built_sets_save_and_reload_clean() -> void:
	var dir: String = "user://test_sprite_wizard/"
	DirAccess.make_dir_recursive_absolute(dir)
	for name: String in ["teste_a_map.png", "teste_a_battle.png", "teste_a_portrait_neutro.png"]:
		var set: SpriteSet = Wizard.build(_tex(name), Wizard.best(_size(name)))
		var path: String = dir + name.get_basename() + ".tres"
		assert_eq(ResourceSaver.save(set, path), OK, name)
		var back: SpriteSet = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SpriteSet
		assert_not_null(back, name)
		assert_eq(Wizard.messages(back), [] as Array[String], name)
		assert_eq(back.anims.size(), set.anims.size())
		assert_eq(back.anims.get_typed_key_builtin(), TYPE_STRING_NAME)
		assert_eq(back.portraits.size(), set.portraits.size())
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)

# --- validação ---

func _set_with_map(frame: Vector2i, walk: int) -> SpriteSet:
	var s := SpriteSet.new()
	s.map_sheet = _tex("teste_a_map.png")
	s.map_frame = frame
	s.walk_frames = walk
	return s

func test_valid_placeholders_have_no_messages() -> void:
	for name: String in ["teste_a.tres", "npc_exemplo.tres", "inimigo_f1.tres"]:
		var s: SpriteSet = load(ART + name)
		assert_eq(Wizard.messages(s), [] as Array[String], name)
		assert_eq(Wizard.issues(s).size(), 0, name)

func test_map_sheet_must_be_a_multiple_of_the_frame() -> void:
	var s: SpriteSet = _set_with_map(Vector2i(30, 48), 3)
	var msgs: Array[String] = Wizard.messages(s)
	assert_true(msgs.size() >= 1)
	assert_true((msgs[0] as String).contains("não é múltiplo"))

func test_map_sheet_needs_four_rows() -> void:
	var s: SpriteSet = _set_with_map(Vector2i(32, 96), 3)
	assert_true(Wizard.messages(s).any(func(m: String) -> bool: return m.contains("faltam linhas")))

func test_map_sheet_needs_enough_columns() -> void:
	var s: SpriteSet = _set_with_map(Vector2i(32, 48), 4)
	assert_true(Wizard.messages(s).any(func(m: String) -> bool: return m.contains("não cabem")))
	s.walk_frames = 0
	assert_true(Wizard.messages(s).any(func(m: String) -> bool: return m.contains("não cabem")))

func test_invalid_frames_are_reported() -> void:
	var s := SpriteSet.new()
	s.map_frame = Vector2i(0, 48)
	s.battle_frame = Vector2i(64, -1)
	var msgs: Array[String] = Wizard.messages(s)
	assert_eq(msgs.size(), 2)
	assert_true((msgs[0] as String).begins_with("map_frame inválido"))
	assert_true((msgs[1] as String).begins_with("battle_frame inválido"))

func test_battle_anims_must_stay_inside_the_sheet() -> void:
	var s := SpriteSet.new()
	s.battle_sheet = _tex("teste_a_battle.png")
	s.anims = {&"idle": Vector3i(0, 4, 6), &"down": Vector3i(6, 1, 1), &"ruim": Vector3i(0, 0, 5)}
	var msgs: Array[String] = Wizard.messages(s)
	assert_true(msgs.any(func(m: String) -> bool: return m.contains("anim 'idle' fica fora")))
	assert_true(msgs.any(func(m: String) -> bool: return m.contains("anim 'down' fica fora")))
	assert_true(msgs.any(func(m: String) -> bool: return m.contains("anim 'ruim': (linha, quadros, fps) inválido")))

func test_battle_sheet_must_be_a_multiple_of_the_frame() -> void:
	var s := SpriteSet.new()
	s.battle_sheet = _tex("teste_a_battle.png")
	s.battle_frame = Vector2i(50, 64)
	assert_true(Wizard.messages(s).any(func(m: String) -> bool: return m.contains("battle_sheet: tamanho")))

func test_a_portrait_without_an_image_is_a_warning() -> void:
	var s := SpriteSet.new()
	s.portraits = {&"neutro": null}
	var found: Array[ValidationIssue] = Wizard.issues(s)
	assert_eq(found.size(), 1)
	assert_false(found[0].is_error())
	assert_true(found[0].message.contains("neutro"))

func test_portraits_without_neutral_is_a_warning() -> void:
	var s := SpriteSet.new()
	s.portraits = {&"feliz": _tex("teste_a_portrait_feliz.png")}
	var found: Array[ValidationIssue] = Wizard.issues(s, "res://art/x.tres")
	assert_eq(found.size(), 1)
	assert_false(found[0].is_error())
	assert_eq(found[0].path, "res://art/x.tres")
	s.portraits[&"neutro"] = _tex("teste_a_portrait_neutro.png")
	assert_eq(Wizard.issues(s).size(), 0)
	s.portraits = {}
	assert_eq(Wizard.issues(s).size(), 0, "sem retratos não avisa")

func test_validation_matches_the_game_rules() -> void:
	var variants: Array[SpriteSet] = []
	for frame: Vector2i in [Vector2i(32, 48), Vector2i(30, 48), Vector2i(32, 96), Vector2i(0, 0), Vector2i(96, 192), Vector2i(48, 48)]:
		for walk: int in [0, 1, 3, 4]:
			variants.append(_set_with_map(frame, walk))
	for bframe: Vector2i in [Vector2i(64, 64), Vector2i(50, 64), Vector2i(64, 0), Vector2i(192, 384), Vector2i(32, 32)]:
		var s := SpriteSet.new()
		s.battle_sheet = _tex("teste_a_battle.png")
		s.battle_frame = bframe
		s.anims[&"extra"] = Vector3i(7, 2, 5)
		s.anims[&"zero"] = Vector3i(0, 0, 0)
		variants.append(s)
	for s: SpriteSet in variants:
		assert_eq(Wizard.messages(s), s.validate())
		var from_game: Array[ValidationIssue] = ContentChecks.sprite_sets([s])
		var errors: Array[String] = []
		for i: ValidationIssue in Wizard.issues(s):
			if i.is_error():
				errors.append(i.message)
		var game_errors: Array[String] = []
		for i: ValidationIssue in from_game:
			if i.is_error():
				game_errors.append(i.message)
		assert_eq(errors, game_errors)

func test_validation_of_null_is_empty() -> void:
	assert_eq(Wizard.messages(null).size(), 0)
	assert_eq(Wizard.issues(null).size(), 0)

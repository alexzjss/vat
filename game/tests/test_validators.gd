extends GutTest

## Validadores de conteúdo (M16): cada regra pega um caso quebrado em memória, e os dados reais não têm erro.

static func _tex(w: int, h: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create_empty(w, h, false, Image.FORMAT_RGBA8))

func _item(id: StringName, path: String = "") -> ItemDef:
	var i := ItemDef.new()
	i.id = id
	if path != "":
		i.take_over_path(path)
	return i

func _element(id: StringName, reacts: bool = true) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	e.reacts = reacts
	return e

func _reaction(a: ElementDef, b: ElementDef) -> ReactionDef:
	var r := ReactionDef.new()
	r.id = StringName("%s_%s" % [a.id, b.id])
	r.a = a
	r.b = b
	return r

func _table(list: Array[ReactionDef]) -> ReactionTable:
	var t := ReactionTable.new()
	t.reactions = list
	return t

func _hero(id: StringName) -> CharacterDef:
	return Fixtures.hero_def(id, Stats.make(5, 5, 5, 5))

func _enemy(id: StringName) -> EnemyDef:
	return Fixtures.enemy_def(id, Stats.make(5, 5, 5, 5))

func _msgs(issues: Array[ValidationIssue]) -> String:
	var out: PackedStringArray = []
	for i: ValidationIssue in issues:
		out.append(i.to_text())
	return "\n".join(out)

func _errors(issues: Array[ValidationIssue]) -> Array[ValidationIssue]:
	return ValidationIssue.errors_of(issues)

# --- ValidationIssue ---

func test_issue_formats_location_and_severity() -> void:
	var e: ValidationIssue = ValidationIssue.error("quebrou", "res://a.tres", 12)
	assert_true(e.is_error())
	assert_eq(e.to_text(), "res://a.tres:12: quebrou")
	var w: ValidationIssue = ValidationIssue.warning("cuidado", "res://b.tres")
	assert_false(w.is_error())
	assert_eq(w.to_text(), "res://b.tres: cuidado")
	assert_eq(ValidationIssue.warning("solto").to_text(), "solto")
	var all: Array[ValidationIssue] = [e, w]
	assert_eq(ValidationIssue.errors_of(all), [e] as Array[ValidationIssue])
	assert_eq(ValidationIssue.warnings_of(all), [w] as Array[ValidationIssue])

# --- ids únicos ---

func test_duplicate_id_in_the_same_kind_is_an_error() -> void:
	var res: Array = [_item(&"x"), _item(&"x"), _item(&"y")]
	var issues: Array[ValidationIssue] = ContentChecks.unique_ids(res)
	assert_eq(issues.size(), 1)
	assert_true(issues[0].is_error())
	assert_string_contains(issues[0].message, "repetido")
	assert_string_contains(issues[0].message, "'x'")

func test_same_id_in_different_kinds_is_fine_and_same_instance_is_not_a_duplicate() -> void:
	var it: ItemDef = _item(&"x")
	var eq := EquipmentDef.new()
	eq.id = &"x"
	assert_eq(ContentChecks.unique_ids([it, eq, it]).size(), 0)

func test_empty_id_is_an_error() -> void:
	var issues: Array[ValidationIssue] = ContentChecks.unique_ids([_item(&"")])
	assert_eq(issues.size(), 1)
	assert_string_contains(issues[0].message, "sem id")

# --- referências ---

func test_hero_without_basic_attack_or_with_empty_learn_entry() -> void:
	var h: CharacterDef = _hero(&"h")
	h.basic_attack = null
	var le := LearnEntry.new()
	h.learnset = [le] as Array[LearnEntry]
	var text: String = _msgs(ContentChecks.references([h]))
	assert_string_contains(text, "sem ataque básico")
	assert_string_contains(text, "learnset[0] sem habilidade")

func test_encounter_with_no_or_null_enemy() -> void:
	var e := EncounterDef.new()
	e.id = &"enc"
	assert_string_contains(_msgs(ContentChecks.references([e])), "sem inimigos")
	e.enemies = [null] as Array[EnemyDef]
	assert_string_contains(_msgs(ContentChecks.references([e])), "inimigo [0] vazio")

func test_shop_with_null_entries() -> void:
	var s := ShopDef.new()
	s.id = &"loja"
	s.items = [null] as Array[ItemDef]
	s.equipment = [null] as Array[EquipmentDef]
	var text: String = _msgs(ContentChecks.references([s]))
	assert_string_contains(text, "item [0] vazio")
	assert_string_contains(text, "equipamento [0] vazio")

func test_enemy_with_ai_rule_without_ability_and_empty_drop() -> void:
	var e: EnemyDef = _enemy(&"e")
	e.ai_rules = [AiRule.new()] as Array[AiRule]
	e.drops = [DropEntry.new()] as Array[DropEntry]
	var text: String = _msgs(ContentChecks.references([e]))
	assert_string_contains(text, "regra de IA [0] sem habilidade")
	assert_string_contains(text, "drop [0] sem item nem equipamento")

func test_boss_phase_ai_rule_without_ability() -> void:
	var e: EnemyDef = _enemy(&"e")
	var phase := BossPhase.new()
	phase.ai_rules = [AiRule.new()] as Array[AiRule]
	e.phases = [phase] as Array[BossPhase]
	assert_string_contains(_msgs(ContentChecks.references([e])), "fase 0")

func test_start_profile_refs() -> void:
	var p := StartProfile.new()
	assert_string_contains(_msgs(ContentChecks.references([p])), "grupo vazio")
	p.party = [null] as Array[CharacterDef]
	p.items = [_item(&"a")] as Array[ItemDef]
	var text: String = _msgs(ContentChecks.references([p]))
	assert_string_contains(text, "herói [0] vazio")
	assert_string_contains(text, "1 item(ns) e 0 quantidade(s)")

func test_apply_status_effect_without_status() -> void:
	var a := AbilityDef.new()
	a.id = &"a"
	var f := EffectDef.new()
	f.kind = EffectDef.Kind.APPLY_STATUS
	a.effects = [f] as Array[EffectDef]
	assert_string_contains(_msgs(ContentChecks.references([a])), "aplica estado sem estado")
	f.kind = EffectDef.Kind.REMOVE_STATUS
	assert_eq(ContentChecks.references([a]).size(), 0, "remover sem estado limpa os negativos: é válido")

func test_equipment_passive_without_status() -> void:
	var e := EquipmentDef.new()
	e.id = &"eq"
	e.passives = [EquipmentPassive.new()] as Array[EquipmentPassive]
	assert_string_contains(_msgs(ContentChecks.references([e])), "passiva [0] sem estado")

func test_event_step_references_and_labels() -> void:
	var script := EventScript.new()
	var recruit := RecruitStep.new()
	var battle := StartBattleStep.new()
	var give := GiveItemStep.new()
	var go := GotoStep.new()
	go.label = &"nada"
	var steps: Array[EventStep] = [recruit, battle, give, go, null]
	script.steps = steps
	var text: String = _msgs(ContentChecks.event_script(script, "res://e.tres"))
	assert_string_contains(text, "herói vazio")
	assert_string_contains(text, "encontro vazio")
	assert_string_contains(text, "item vazio")
	assert_string_contains(text, "rótulo 'nada' não existe")
	assert_string_contains(text, "passo [4] vazio")

func test_event_with_existing_label_is_clean() -> void:
	var script := EventScript.new()
	var go := GotoStep.new()
	go.label = &"fim"
	var l := LabelStep.new()
	l.label_name = &"fim"
	var steps: Array[EventStep] = [go, l]
	script.steps = steps
	assert_eq(ContentChecks.event_script(script, "x").size(), 0)

# --- nativos ---

func test_three_native_elements_is_an_error() -> void:
	var h: CharacterDef = _hero(&"h")
	h.elements = [_element(&"a"), _element(&"b"), _element(&"c")] as Array[ElementDef]
	var issues: Array[ValidationIssue] = ContentChecks.native_elements([h])
	assert_eq(issues.size(), 1)
	assert_true(issues[0].is_error())
	assert_string_contains(issues[0].message, "3 elementos nativos")
	h.elements = [_element(&"a"), _element(&"b")] as Array[ElementDef]
	assert_eq(ContentChecks.native_elements([h]).size(), 0)

func test_enemy_natives_are_checked_too() -> void:
	var e: EnemyDef = _enemy(&"e")
	e.elements = [_element(&"a"), _element(&"b"), _element(&"c")] as Array[ElementDef]
	assert_eq(ContentChecks.native_elements([e]).size(), 1)

# --- reações ---

func test_reaction_table_with_a_missing_pair_and_a_repeated_pair() -> void:
	var a: ElementDef = _element(&"a")
	var b: ElementDef = _element(&"b")
	var c: ElementDef = _element(&"c")
	var table: ReactionTable = _table([_reaction(a, b), _reaction(b, a)] as Array[ReactionDef])
	var text: String = _msgs(ContentChecks.reactions([a, b, c, table]))
	assert_string_contains(text, "par repetido")
	assert_string_contains(text, "par faltando")

func test_complete_reaction_table_is_clean() -> void:
	var a: ElementDef = _element(&"a")
	var b: ElementDef = _element(&"b")
	var table: ReactionTable = _table([_reaction(a, b)] as Array[ReactionDef])
	assert_eq(ContentChecks.reactions([a, b, table]).size(), 0)

func test_reaction_between_the_same_element() -> void:
	var a: ElementDef = _element(&"a")
	var table: ReactionTable = _table([_reaction(a, a)] as Array[ReactionDef])
	assert_string_contains(_msgs(ContentChecks.reactions([a, table])), "mesmo elemento")

# --- chefes ---

func test_boss_without_immunities_is_an_error() -> void:
	var boss: EnemyDef = _enemy(&"chefe")
	boss.role = EnemyDef.Role.CORE
	var part: EnemyDef = _enemy(&"parte")
	part.role = EnemyDef.Role.PART
	part.immunities = [&"doom"] as Array[StringName]
	var normal: EnemyDef = _enemy(&"comum")
	var issues: Array[ValidationIssue] = ContentChecks.bosses([boss, part, normal])
	assert_eq(issues.size(), 3, "o núcleo sem as duas e a parte sem Petrificação")
	assert_string_contains(_msgs(issues), "'chefe' não é imune a 'doom'")
	assert_string_contains(_msgs(issues), "'parte' não é imune a 'petrify'")
	boss.immunities = [&"doom", &"petrify"] as Array[StringName]
	part.immunities = [&"doom", &"petrify"] as Array[StringName]
	assert_eq(ContentChecks.bosses([boss, part, normal]).size(), 0)

# --- roteiros ---

func test_roteiro_with_a_broken_label_reports_the_line() -> void:
	var sources: Dictionary[String, String] = {"res://data/x/a.roteiro": "=== e\nAna: oi\n-> aceita"}
	var issues: Array[ValidationIssue] = ContentChecks.roteiros(sources, [])
	assert_eq(issues.size(), 1)
	assert_true(issues[0].is_error())
	assert_eq(issues[0].path, "res://data/x/a.roteiro")
	assert_eq(issues[0].line, 3)
	assert_eq(issues[0].message, "rótulo 'aceita' não existe")

func test_valid_roteiro_has_no_issue() -> void:
	var sources: Dictionary[String, String] = {"res://a.roteiro": "=== e\nAna: oi"}
	assert_eq(_errors(ContentChecks.roteiros(sources, [])).size(), 0)

func test_roteiro_unknown_id_is_resolved_against_the_resources() -> void:
	var sources: Dictionary[String, String] = {"res://a.roteiro": "=== e\n@give item pocao"}
	assert_eq(ContentChecks.roteiros(sources, []).size(), 1)
	assert_eq(ContentChecks.roteiros(sources, [_item(&"pocao")]).size(), 0)

# --- arte ---

func test_sprite_sheet_not_divisible_by_the_frame() -> void:
	var s := SpriteSet.new()
	s.battle_sheet = _tex(260, 384)
	s.take_over_path("res://art/x.tres")
	var issues: Array[ValidationIssue] = ContentChecks.sprite_sets([s])
	assert_eq(issues.size(), 1)
	assert_true(issues[0].is_error())
	assert_eq(issues[0].path, "res://art/x.tres")
	assert_string_contains(issues[0].message, "múltiplo")

func test_anim_outside_the_sheet() -> void:
	var s := SpriteSet.new()
	s.battle_sheet = _tex(256, 64)
	assert_string_contains(_msgs(ContentChecks.sprite_sets([s])), "fica fora da folha")

func test_sprite_set_of_a_hero_is_checked_once() -> void:
	var s := SpriteSet.new()
	s.battle_sheet = _tex(260, 384)
	var h: CharacterDef = _hero(&"h")
	h.sprites = s
	var e: EnemyDef = _enemy(&"e")
	e.sprites = s
	assert_eq(ContentChecks.sprite_sets([h, e, s]).size(), 1)

func test_valid_sprite_set_is_clean() -> void:
	var s := SpriteSet.new()
	s.battle_sheet = _tex(256, 384)
	assert_eq(ContentChecks.sprite_sets([s]).size(), 0)

func test_hero_and_enemy_without_battle_art_get_a_warning() -> void:
	var h: CharacterDef = _hero(&"h")
	var e: EnemyDef = _enemy(&"e")
	var drawn: CharacterDef = _hero(&"d")
	drawn.sprites = SpriteSet.new()
	drawn.sprites.battle_sheet = _tex(256, 384)
	var issues: Array[ValidationIssue] = ContentChecks.missing_battle_art([h, e, drawn])
	assert_eq(issues.size(), 2, "o com arte de batalha não avisa")
	for i: ValidationIssue in issues:
		assert_false(i.is_error())
	assert_string_contains(_msgs(issues), "herói 'h'")
	assert_string_contains(_msgs(issues), "inimigo 'e'")

func test_test_data_is_exempt_from_the_battle_art_warning() -> void:
	var h: CharacterDef = _hero(&"h")
	h.resource_path = "res://data/test/heroes/h.tres"
	var e: EnemyDef = _enemy(&"e")
	e.resource_path = "res://data/fatia/enemies/e.tres"
	var issues: Array[ValidationIssue] = ContentChecks.missing_battle_art([h, e])
	assert_eq(issues.size(), 1, "só o da fatia avisa")
	assert_string_contains(_msgs(issues), "inimigo 'e'")

func test_sprites_without_a_battle_sheet_still_warn() -> void:
	var h: CharacterDef = _hero(&"h")
	h.sprites = SpriteSet.new()
	assert_eq(ContentChecks.missing_battle_art([h]).size(), 1)

# --- mapas ---

func _maps(refs: Array[Dictionary]) -> Dictionary[StringName, Dictionary]:
	var a: Array[StringName] = [&"Entry"]
	var b: Array[StringName] = [&"Entry", &"Saida"]
	var out: Dictionary[StringName, Dictionary] = {}
	out[&"a"] = ContentBundle.map_info("res://a.tscn", a, refs)
	out[&"b"] = ContentBundle.map_info("res://b.tscn", b, [] as Array[Dictionary])
	return out

func test_link_to_a_missing_spawn_is_an_error() -> void:
	var refs: Array[Dictionary] = [ContentBundle.map_ref("MapLink Porta", &"b", &"Nada")]
	var issues: Array[ValidationIssue] = MapChecks.links(_maps(refs))
	assert_eq(issues.size(), 1)
	assert_true(issues[0].is_error())
	assert_eq(issues[0].path, "res://a.tscn")
	assert_string_contains(issues[0].message, "marcador 'Nada' não existe em 'b'")

func test_link_to_a_map_outside_game_maps_is_an_error() -> void:
	var refs: Array[Dictionary] = [ContentBundle.map_ref("MapLink Porta", &"c", &"Entry")]
	assert_string_contains(_msgs(MapChecks.links(_maps(refs))), "mapa 'c' não existe")

func test_valid_links_are_clean() -> void:
	var refs: Array[Dictionary] = [ContentBundle.map_ref("MapLink Porta", &"b", &"Saida"), ContentBundle.map_ref("pousada", &"a", &"Entry")]
	assert_eq(MapChecks.links(_maps(refs)).size(), 0)

func test_start_profile_must_point_to_an_existing_spawn() -> void:
	var p := StartProfile.new()
	p.map = &"a"
	p.spawn = &"Nada"
	assert_eq(MapChecks.profiles([p], _maps([] as Array[Dictionary])).size(), 1)
	p.spawn = &"Entry"
	assert_eq(MapChecks.profiles([p], _maps([] as Array[Dictionary])).size(), 0)

func test_scan_map_collects_markers_links_and_exit() -> void:
	var packed: PackedScene = Game.default_registry().scene_of(&"cidade")
	var scene: Node = packed.instantiate()
	var info: Dictionary = ContentLoader.scan_map(&"cidade", packed.resource_path, scene)
	scene.free()
	assert_true((info["markers"] as Array).has(&"Start"))
	assert_gt((info["refs"] as Array).size(), 0, "a cidade tem ligações")

# --- pacote ---

func test_run_aggregates_every_rule() -> void:
	var b := ContentBundle.new()
	var h: CharacterDef = _hero(&"h")
	h.elements = [_element(&"a"), _element(&"b"), _element(&"c")] as Array[ElementDef]
	b.resources = [h, _item(&"x"), _item(&"x")]
	var sources: Dictionary[String, String] = {"res://a.roteiro": "=== e\n-> nada"}
	b.roteiros = sources
	var issues: Array[ValidationIssue] = ContentChecks.run(b)
	var text: String = _msgs(issues)
	assert_string_contains(text, "repetido")
	assert_string_contains(text, "nativos")
	assert_string_contains(text, "rótulo 'nada'")
	assert_gt(ValidationIssue.warnings_of(issues).size(), 0, "o herói sem arte")

# --- roteiro + event_id nos mapas ---

func _book(ids: Array[StringName]) -> RoteiroBook:
	var b := RoteiroBook.new()
	for id: StringName in ids:
		b.events[id] = EventScript.new()
	return b

func test_roteiro_refs_accept_a_valid_id() -> void:
	var refs: Array[Dictionary] = [ContentBundle.roteiro_ref(&"vila", "Placa", _book([&"a"]), "res://x.roteiro", &"a")]
	assert_eq(ContentChecks.roteiro_refs(refs).size(), 0)

func test_roteiro_refs_bad_id_is_an_error() -> void:
	var refs: Array[Dictionary] = [ContentBundle.roteiro_ref(&"vila", "Placa", _book([&"a"]), "res://x.roteiro", &"b")]
	var issues: Array[ValidationIssue] = ContentChecks.roteiro_refs(refs)
	assert_eq(issues.size(), 1)
	assert_true(issues[0].is_error())
	assert_string_contains(issues[0].message, "'b'")
	assert_eq(issues[0].path, "res://x.roteiro")

func test_roteiro_refs_empty_id_is_an_error() -> void:
	var refs: Array[Dictionary] = [ContentBundle.roteiro_ref(&"vila", "Placa", _book([&"a"]), "res://x.roteiro", &"")]
	var issues: Array[ValidationIssue] = ContentChecks.roteiro_refs(refs)
	assert_eq(issues.size(), 1)
	assert_string_contains(issues[0].message, "vazio")

func test_roteiro_refs_null_book_is_an_error() -> void:
	var refs: Array[Dictionary] = [ContentBundle.roteiro_ref(&"vila", "Placa", null, "res://vila.tscn", &"a")]
	var issues: Array[ValidationIssue] = ContentChecks.roteiro_refs(refs)
	assert_eq(issues.size(), 1)
	assert_string_contains(issues[0].message, "não carregou")

func test_run_includes_roteiro_refs() -> void:
	var b := ContentBundle.new()
	b.roteiro_refs = [ContentBundle.roteiro_ref(&"vila", "Placa", _book([&"a"]), "res://x.roteiro", &"zzz")]
	assert_string_contains(_msgs(ContentChecks.run(b)), "'zzz'")

func test_portraits_without_neutro_warn() -> void:
	var s := SpriteSet.new()
	s.portraits = {&"feliz": _tex(8, 8)}
	s.take_over_path("res://art/p.tres")
	var issues: Array[ValidationIssue] = ContentChecks.sprite_sets([s])
	assert_eq(issues.size(), 1)
	assert_false(issues[0].is_error())
	assert_string_contains(issues[0].message, "neutro")
	s.portraits[&"neutro"] = _tex(8, 8)
	assert_eq(ContentChecks.sprite_sets([s]).size(), 0)

# --- dados reais ---

func test_real_content_has_no_errors() -> void:
	var issues: Array[ValidationIssue] = Validator.run_all()
	var errs: Array[ValidationIssue] = ValidationIssue.errors_of(issues)
	assert_eq(errs.size(), 0, _msgs(errs))

func test_real_content_covers_every_map_and_the_roteiros() -> void:
	var b: ContentBundle = ContentLoader.load_all()
	assert_eq(b.maps.size(), Game.default_registry().ids().size())
	assert_gte(b.roteiros.size(), 3)
	assert_gt(b.of_type(CharacterDef).size(), 4)
	assert_eq(ContentChecks.run(b).size(), Validator.run_all().size())

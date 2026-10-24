extends GutTest

## Lógica pura dos formulários de herói, inimigo e encontro (M17, Task 7): porcentagem, listas e dicionários tipados,
## sub-resources novos, escolhas, validação e a ida e volta de cada tipo (cópia de um `.tres` real da fatia em user://,
## edição pela lógica, salvar, recarregar e conferir todos os campos). Nada aqui grava em `res://data/`.

const Forms: GDScript = preload("res://addons/vat_editor/logic/forms.gd")

const TMP: String = "user://test_forms_logic/"
const HERO_SRC: String = "res://data/fatia/heroes/teste_a_f.tres"
const ENEMY_SRC: String = "res://data/fatia/enemies/guardiao_fatia.tres"
const ENCOUNTER_SRC: String = "res://data/fatia/encounters/chefe_fatia.tres"

func after_each() -> void:
	if not DirAccess.dir_exists_absolute(TMP):
		return
	for f: String in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP.path_join(f))
	DirAccess.remove_absolute(TMP)

## Copia o `.tres` real para user:// e carrega a cópia (cache novo).
func _copy(src: String) -> String:
	DirAccess.make_dir_recursive_absolute(TMP)
	var dst: String = TMP.path_join(src.get_file())
	var text: String = FileAccess.get_file_as_string(src)
	var f: FileAccess = FileAccess.open(dst, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return dst

func _open(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

## Relê do disco sem tocar na instância aberta.
func _fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

func _count(text: String, needle: String) -> int:
	return text.count(needle)

func _diff_keys(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	for k: Variant in a:
		if not b.has(k) or a[k] != b[k]:
			out.append(k)
	out.sort()
	return out

# --- porcentagem ---

func test_percent_conversion_edges() -> void:
	assert_eq(Forms.to_percent(0.3), 30.0)
	assert_eq(Forms.to_percent(1.0), 100.0)
	assert_eq(Forms.to_percent(1.5), 150.0)
	assert_eq(Forms.to_percent(-0.5), -50.0)
	assert_eq(Forms.to_percent(0.0), 0.0)
	assert_eq(Forms.to_percent(0.125), 12.5)
	assert_eq(Forms.from_percent(30.0), 0.3)
	assert_eq(Forms.from_percent(100.0), 1.0)
	assert_eq(Forms.from_percent(150.0), 1.5)
	assert_eq(Forms.from_percent(-50.0), -0.5)

func test_percent_round_trips_every_whole_percent() -> void:
	for p: int in range(-300, 301):
		assert_eq(Forms.to_percent(Forms.from_percent(float(p))), float(p), "%d%%" % p)

func test_sign_hint_says_what_the_value_means() -> void:
	assert_eq(Forms.sign_hint(100.0), "imune")
	assert_eq(Forms.sign_hint(150.0), "absorve")
	assert_eq(Forms.sign_hint(150.0, false), "imune")
	assert_eq(Forms.sign_hint(30.0), "resiste")
	assert_eq(Forms.sign_hint(-50.0), "fraqueza")
	assert_eq(Forms.sign_hint(0.0), "neutro")
	assert_eq(Forms.sign_hint(99.99), "resiste")

# --- descritores ---

func test_enum_labels_match_the_enums() -> void:
	assert_eq(Forms.CONDITION_LABELS.size(), AiRule.Condition.size())
	assert_eq(Forms.PICK_LABELS.size(), AiRule.TargetPick.size())
	assert_eq(Forms.ROLE_LABELS.size(), EnemyDef.Role.size())

func test_every_descriptor_names_a_real_property() -> void:
	var samples: Dictionary = {&"heroes": CharacterDef.new(), &"enemies": EnemyDef.new(), &"encounters": EncounterDef.new()}
	for kind: StringName in samples:
		var props: Array = []
		for p: Dictionary in (samples[kind] as Resource).get_property_list():
			props.append(p["name"])
		assert_false(Forms.fields(kind).is_empty())
		for d: Dictionary in Forms.fields(kind):
			assert_true(props.has(String(d["prop"])), "%s.%s" % [kind, d["prop"]])
	var rows: Dictionary = {Forms.ROW_LEARN: LearnEntry.new(), Forms.ROW_AI_RULE: AiRule.new(), Forms.ROW_DROP: DropEntry.new(), Forms.ROW_PHASE: BossPhase.new()}
	for row: StringName in rows:
		var rprops: Array = []
		for p: Dictionary in (rows[row] as Resource).get_property_list():
			rprops.append(p["name"])
		for c: Dictionary in Forms.columns(row):
			assert_true(rprops.has(String(c["prop"])), "%s.%s" % [row, c["prop"]])
		assert_not_null(Forms.new_row(row))

func test_hero_form_covers_every_authored_field() -> void:
	var props: Array = []
	for d: Dictionary in Forms.fields(&"heroes"):
		props.append(d["prop"])
	for want: StringName in [&"id", &"display_name", &"base", &"elements", &"element_resist", &"status_resist", &"basic_attack", &"limit_ability", &"weapon_types", &"starting_equipment", &"learnset", &"sprites"]:
		assert_true(props.has(want), String(want))

func test_enemy_form_covers_every_authored_field() -> void:
	var props: Array = []
	for d: Dictionary in Forms.fields(&"enemies"):
		props.append(d["prop"])
	for want: StringName in [&"id", &"display_name", &"level", &"base", &"xp_base", &"money", &"drops", &"abilities", &"ai_rules", &"immunities", &"resistances", &"phases", &"counter", &"counter_chance", &"counter_only_basic", &"role", &"shields_core", &"elements", &"element_resist", &"sprites"]:
		assert_true(props.has(want), String(want))

# --- sub-resources novos ---

func test_new_sub_resources_have_defaults() -> void:
	var s: Stats = Forms.new_stats(1, 2, 3, 4)
	assert_eq([s.strength, s.speed, s.vitality, s.aura], [1, 2, 3, 4])
	var le: LearnEntry = Forms.new_learn_entry()
	assert_eq(le.level, 1)
	assert_null(le.ability)
	var r: AiRule = Forms.new_ai_rule()
	assert_eq(r.condition, AiRule.Condition.ALWAYS)
	assert_eq(r.chance, 1.0)
	assert_false(r.telegraph)
	var d: DropEntry = Forms.new_drop()
	assert_eq([d.chance, d.count], [1.0, 1])

func test_new_boss_phase_goes_below_the_last_one() -> void:
	assert_eq(Forms.new_boss_phase().hp_below, 0.5)
	var a: BossPhase = BossPhase.new()
	a.hp_below = 0.66
	var b: BossPhase = Forms.new_boss_phase([a])
	assert_almost_eq(b.hp_below, 0.41, 0.0001)
	a.hp_below = 0.1
	assert_eq(Forms.new_boss_phase([a]).hp_below, 0.05)

func test_ensure_stats_creates_when_missing() -> void:
	var c := CharacterDef.new()
	assert_null(c.base)
	var s: Stats = Forms.ensure_stats(c)
	assert_eq(c.base, s)
	assert_eq(Forms.ensure_stats(c), s)

# --- listas e dicionários ---

func test_list_ops_keep_the_typed_array() -> void:
	var c := CharacterDef.new()
	var i0: int = Forms.list_add(c.learnset, Forms.new_learn_entry(null, 1))
	var i1: int = Forms.list_add(c.learnset, Forms.new_learn_entry(null, 5))
	assert_eq([i0, i1], [0, 1])
	assert_eq(Forms.list_move(c.learnset, 1, -1), 0)
	assert_eq(c.learnset[0].level, 5)
	assert_eq(Forms.list_move(c.learnset, 0, -1), 0, "no topo não sobe")
	assert_eq(Forms.list_move(c.learnset, 1, 1), 1, "no fim não desce")
	assert_eq(Forms.list_duplicate(c.learnset, 0), 1)
	assert_eq(c.learnset.size(), 3)
	assert_ne(c.learnset[0], c.learnset[1], "cópia independente")
	c.learnset[1].level = 9
	assert_eq(c.learnset[0].level, 5)
	assert_true(Forms.list_remove(c.learnset, 1))
	assert_false(Forms.list_remove(c.learnset, 7))
	assert_eq(c.learnset.size(), 2)
	assert_eq(c.learnset.get_typed_script(), LearnEntry)

func test_duplicating_a_reference_row_keeps_the_same_resource() -> void:
	var enc := EncounterDef.new()
	var e: EnemyDef = load("res://data/fatia/enemies/inimigo_f1.tres")
	Forms.list_add(enc.enemies, e)
	Forms.list_duplicate(enc.enemies, 0)
	assert_eq(enc.enemies.size(), 2)
	assert_eq(enc.enemies[1], e, "inimigo externo é referência, não cópia")

func test_duplicating_a_phase_copies_its_rules() -> void:
	var p := BossPhase.new()
	p.banner = "x"
	var rule := AiRule.new()
	rule.chance = 0.3
	p.ai_rules.append(rule)
	var q: BossPhase = Forms.copy_row(p) as BossPhase
	assert_eq(q.banner, "x")
	assert_eq(q.ai_rules.size(), 1)
	assert_ne(q.ai_rules[0], rule)
	q.ai_rules[0].chance = 0.9
	assert_eq(rule.chance, 0.3)
	assert_eq(p.ai_rules.size(), 1)

func test_names_toggle_keeps_order_and_no_repeats() -> void:
	var c := CharacterDef.new()
	Forms.names_toggle(c.weapon_types, &"blade", true)
	Forms.names_toggle(c.weapon_types, &"bow", true)
	Forms.names_toggle(c.weapon_types, &"blade", true)
	assert_eq(c.weapon_types, [&"blade", &"bow"] as Array[StringName])
	Forms.names_toggle(c.weapon_types, &"blade", false)
	Forms.names_toggle(c.weapon_types, &"nada", false)
	assert_eq(c.weapon_types, [&"bow"] as Array[StringName])

func test_dict_edit_keeps_the_typed_dictionary() -> void:
	var c := CharacterDef.new()
	Forms.dict_set_percent(c.element_resist, &"susanoo", -50.0)
	Forms.dict_set_percent(c.element_resist, &"atlas", 150.0)
	Forms.dict_set_percent(c.element_resist, &"fuhaku", 100.0)
	assert_eq(c.element_resist[&"susanoo"], -0.5)
	assert_eq(c.element_resist[&"atlas"], 1.5)
	assert_eq(c.element_resist[&"fuhaku"], 1.0)
	assert_eq(Forms.dict_percent(c.element_resist, &"atlas"), 150.0)
	assert_true(Forms.dict_rename(c.element_resist, &"atlas", &"indra"))
	assert_eq(c.element_resist.keys(), [&"susanoo", &"indra", &"fuhaku"])
	assert_eq(c.element_resist[&"indra"], 1.5)
	assert_false(Forms.dict_rename(c.element_resist, &"indra", &"susanoo"), "chave já usada")
	assert_eq(Forms.dict_next_free(c.element_resist, [&"susanoo", &"tsukuyomi"]), &"tsukuyomi")
	assert_eq(Forms.dict_next_free(c.element_resist, [&"susanoo"]), &"")
	assert_eq(c.element_resist.get_typed_key_builtin(), TYPE_STRING_NAME)
	assert_eq(c.element_resist.get_typed_value_builtin(), TYPE_FLOAT)

# --- escolhas ---

func _ids(list: Array[Dictionary]) -> Array[StringName]:
	return Forms.choice_ids(list)

func test_choices_list_the_content() -> void:
	assert_true(_ids(Forms.choices(Forms.SRC_ABILITY)).has(&"chama_f"))
	assert_true(_ids(Forms.choices(Forms.SRC_ITEM)).has(&"pocao_f"))
	assert_true(_ids(Forms.choices(Forms.SRC_EQUIP)).has(&"lamina_simples"))
	assert_true(_ids(Forms.choices(Forms.SRC_ENEMY)).has(&"guardiao_fatia"))
	assert_true(_ids(Forms.choices(Forms.SRC_ELEMENT)).has(&"kagutsuchi"))
	assert_true(_ids(Forms.choices(Forms.SRC_STATUS)).has(&"doom"))
	assert_true(_ids(Forms.choices(Forms.SRC_WEAPON)).has(&"blade"))
	assert_true(_ids(Forms.choices(Forms.SRC_SPRITES)).has(&"teste_a"))
	assert_true(Forms.choices(&"desconhecido").is_empty())

func test_choices_are_sorted_and_carry_resources() -> void:
	var list: Array[Dictionary] = Forms.choices(Forms.SRC_ENEMY)
	var ids: Array[StringName] = _ids(list)
	var sorted: Array[StringName] = ids.duplicate()
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	assert_eq(ids, sorted)
	for c: Dictionary in list:
		assert_true(c["value"] is EnemyDef)
		assert_true((c["label"] as String).begins_with(String(c["id"])))

# --- prévia em texto ---

func test_encounter_summary_groups_the_formation() -> void:
	var enc: EncounterDef = load(ENCOUNTER_SRC)
	var lines: PackedStringArray = Forms.encounter_summary(enc)
	assert_true(lines[0].begins_with("2× "), lines[0])
	assert_true(lines[1].begins_with("1× "), lines[1])
	assert_true(lines[lines.size() - 1].contains("Sem fuga"))
	assert_eq(Forms.encounter_summary(EncounterDef.new()), PackedStringArray(["Sem inimigos."]))

# --- validação ---

func test_validate_clean_slice_content() -> void:
	for path: String in [HERO_SRC, ENEMY_SRC, ENCOUNTER_SRC]:
		var res: Resource = load(path)
		assert_eq(ValidationIssue.errors_of(Forms.validate(res)).size(), 0, path)

func test_validate_reports_problems_of_the_open_resource() -> void:
	var enc := EncounterDef.new()
	enc.id = &"x"
	enc.resource_path = ""
	var msgs: Array[String] = []
	for i: ValidationIssue in Forms.validate(enc):
		msgs.append(i.message)
	assert_true(msgs.has("encontro 'x': sem inimigos"), str(msgs))
	Forms.list_add(enc.enemies, null)
	msgs.clear()
	for i: ValidationIssue in Forms.validate(enc):
		msgs.append(i.message)
	assert_true(msgs.has("encontro 'x': inimigo [0] vazio"), str(msgs))

func test_validate_hero_with_empty_learn_row_and_three_natives() -> void:
	var h: CharacterDef = (load(HERO_SRC) as CharacterDef).duplicate(false)
	h.learnset = h.learnset.duplicate()
	Forms.list_add(h.learnset, Forms.new_learn_entry())
	var k: ElementDef = load("res://data/elements/kagutsuchi.tres")
	var s: ElementDef = load("res://data/elements/susanoo.tres")
	var f: ElementDef = load("res://data/elements/fuhaku.tres")
	h.elements = [k, s, f] as Array[ElementDef]
	var msgs: String = "\n".join(Forms.validate(h).map(func(i: ValidationIssue) -> String: return i.message))
	assert_true(msgs.contains("sem habilidade"), msgs)
	assert_true(msgs.contains("3 elementos nativos"), msgs)

func test_validate_repeated_id_among_siblings() -> void:
	var a: CharacterDef = load(HERO_SRC)
	var b: CharacterDef = load("res://data/fatia/heroes/teste_b_f.tres")
	assert_eq(ValidationIssue.errors_of(Forms.validate(a, [a, b])).size(), 0)
	var clone: CharacterDef = a.duplicate(false)
	clone.resource_path = "res://data/fatia/heroes/_clone.tres"
	var errs: Array[ValidationIssue] = ValidationIssue.errors_of(Forms.validate(clone, [a, b]))
	assert_eq(errs.size(), 1)
	assert_true(errs[0].message.contains("repetido"), errs[0].message)

# --- salvar e reverter ---

func test_save_needs_a_file_path() -> void:
	assert_eq(Forms.save(null), ERR_INVALID_PARAMETER)
	assert_eq(Forms.save(Stats.new()), ERR_INVALID_PARAMETER)

func test_reload_restores_the_disk_values_in_the_same_instance() -> void:
	var path: String = _copy(HERO_SRC)
	var hero: CharacterDef = _open(path) as CharacterDef
	var original: Dictionary = Forms.snapshot(hero)
	Forms.ensure_stats(hero).strength = 99
	hero.display_name = "Outro"
	Forms.list_add(hero.learnset, Forms.new_learn_entry(null, 4))
	Forms.dict_set_percent(hero.element_resist, &"atlas", 50.0)
	assert_ne(Forms.snapshot(hero), original)
	var back: CharacterDef = Forms.reload_file(path) as CharacterDef
	assert_eq(back, hero, "a instância aberta recebe os dados do disco")
	assert_eq(Forms.snapshot(back), original)
	assert_eq(back.base.strength, 12)
	assert_eq(back.learnset.size(), 7)

# --- ida e volta: herói ---

func test_hero_round_trip() -> void:
	var path: String = _copy(HERO_SRC)
	var source_text: String = FileAccess.get_file_as_string(path)
	var hero: CharacterDef = _open(path) as CharacterDef
	var before: Dictionary = Forms.snapshot(hero)
	var sub_before: int = _count(source_text, "[sub_resource")
	# edição: um atributo, uma linha de técnica (e uma só por evento), uma afinidade, uma resistência a estado
	Forms.ensure_stats(hero).strength = 15
	var chama: AbilityDef = load("res://data/fatia/abilities/chama_f.tres")
	Forms.list_add(hero.learnset, Forms.new_learn_entry(chama, 7))
	Forms.list_add(hero.learnset, Forms.new_learn_entry(chama, 0))
	Forms.dict_set_percent(hero.element_resist, &"susanoo", -50.0)
	Forms.dict_set_percent(hero.element_resist, &"fuhaku", 100.0)
	Forms.dict_set_percent(hero.status_resist, &"doom", 150.0)
	var expected: Dictionary = Forms.snapshot(hero)
	assert_eq(Forms.save(hero), OK)
	var back: CharacterDef = _fresh(path) as CharacterDef
	assert_eq(Forms.snapshot(back), expected, "tudo volta como foi editado")
	# o que não foi editado não mudou
	assert_eq(_diff_keys(before, expected), ["base", "element_resist", "learnset", "status_resist"])
	assert_eq(back.base.strength, 15)
	assert_eq(back.base.speed, 8)
	assert_eq(back.learnset.size(), 9)
	assert_eq(back.learnset[7].level, 7)
	assert_eq(back.learnset[8].level, 0)
	assert_eq(back.element_resist[&"susanoo"], -0.5)
	assert_eq(back.element_resist[&"fuhaku"], 1.0)
	assert_eq(back.status_resist[&"doom"], 1.5)
	# tipos
	assert_eq(back.learnset.get_typed_script(), LearnEntry)
	assert_eq(back.starting_equipment.get_typed_script(), EquipmentDef)
	assert_eq(back.elements.get_typed_script(), ElementDef)
	assert_eq(back.weapon_types.get_typed_builtin(), TYPE_STRING_NAME)
	assert_eq(back.element_resist.get_typed_key_builtin(), TYPE_STRING_NAME)
	assert_eq(back.element_resist.get_typed_value_builtin(), TYPE_FLOAT)
	assert_eq(back.status_resist.get_typed_value_builtin(), TYPE_FLOAT)
	# sub-resources embutidos, referências externas
	var text: String = FileAccess.get_file_as_string(path)
	assert_eq(_count(text, "[sub_resource"), sub_before + 2, "as duas linhas novas entram embutidas")
	assert_eq(_count(text, "\nsprites = ExtResource"), 1, "a arte continua uma referência externa")
	assert_eq(back.sprites.resource_path, "res://art/_exemplo/teste_a.tres")
	assert_eq(back.basic_attack.resource_path, "res://data/test/abilities/golpe.tres")
	assert_eq(ValidationIssue.errors_of(Forms.validate(back)).size(), 0)
	assert_eq(ValidationIssue.errors_of(ContentChecks.references([back])).size(), 0)

# --- ida e volta: inimigo ---

func test_enemy_round_trip() -> void:
	var path: String = _copy(ENEMY_SRC)
	var enemy: EnemyDef = _open(path) as EnemyDef
	# o arquivo real compartilha a regra do combo entre a lista base e as fases
	assert_eq(enemy.ai_rules[0], enemy.phases[0].ai_rules[0])
	var before: Dictionary = Forms.snapshot(enemy)
	var brasa: AbilityDef = load("res://data/fatia/abilities/brasa_f.tres")
	var pocao: ItemDef = load("res://data/fatia/items/pocao_f.tres")
	Forms.ensure_stats(enemy).speed = 11
	var rule: AiRule = Forms.new_ai_rule(brasa)
	rule.telegraph = true
	rule.pick = AiRule.TargetPick.CLUSTER
	rule.chance = Forms.from_percent(40.0)
	Forms.list_add(enemy.ai_rules, rule)
	Forms.list_add(enemy.drops, Forms.new_drop(pocao))
	enemy.drops[0].chance = Forms.from_percent(25.0)
	enemy.drops[0].count = 2
	Forms.dict_set_percent(enemy.element_resist, &"atlas", 150.0)
	Forms.dict_set_percent(enemy.resistances, &"doom", 100.0)
	var phase: BossPhase = Forms.new_boss_phase(enemy.phases)
	phase.banner = "Fase 4"
	Forms.list_add(phase.ai_rules, Forms.new_ai_rule(brasa))
	Forms.list_add(enemy.phases, phase)
	Forms.list_duplicate(enemy.ai_rules, 2)
	var expected: Dictionary = Forms.snapshot(enemy)
	assert_eq(Forms.save(enemy), OK)
	var back: EnemyDef = _fresh(path) as EnemyDef
	assert_eq(Forms.snapshot(back), expected, "tudo volta como foi editado")
	assert_eq(_diff_keys(before, expected), ["ai_rules", "base", "drops", "element_resist", "phases", "resistances"])
	assert_eq(back.base.speed, 11)
	assert_eq(back.ai_rules.size(), 5, "uma regra nova e uma cópia")
	var added: AiRule = back.ai_rules[4]
	assert_eq([added.ability.id, added.telegraph, added.pick, added.chance], [&"brasa_f", true, AiRule.TargetPick.CLUSTER, 0.4])
	assert_ne(back.ai_rules[2], back.ai_rules[3], "a cópia é independente")
	assert_eq(back.ai_rules[3].ability, back.ai_rules[2].ability, "a cópia aponta para a mesma habilidade")
	assert_eq(back.drops.size(), 1)
	assert_eq([back.drops[0].item.id, back.drops[0].chance, back.drops[0].count], [&"pocao_f", 0.25, 2])
	assert_eq(back.element_resist[&"atlas"], 1.5)
	assert_eq(back.element_resist[&"indra"], 1.5, "o que já existia continua")
	assert_eq(back.resistances[&"doom"], 1.0)
	assert_eq(back.phases.size(), 3)
	assert_eq(back.phases[2].banner, "Fase 4")
	assert_almost_eq(back.phases[2].hp_below, 0.08, 0.0001)
	assert_eq(back.phases[0].banner, "Fase 2 (teste)")
	# regra compartilhada continua a mesma instância
	assert_eq(back.ai_rules[0], back.phases[0].ai_rules[0])
	assert_eq(back.ai_rules[0], back.phases[1].ai_rules[0])
	# tipos
	assert_eq(back.ai_rules.get_typed_script(), AiRule)
	assert_eq(back.drops.get_typed_script(), DropEntry)
	assert_eq(back.phases.get_typed_script(), BossPhase)
	assert_eq(back.phases[2].ai_rules.get_typed_script(), AiRule)
	assert_eq(back.abilities.get_typed_script(), AbilityDef)
	assert_eq(back.immunities.get_typed_builtin(), TYPE_STRING_NAME)
	assert_eq(back.element_resist.get_typed_key_builtin(), TYPE_STRING_NAME)
	assert_eq(back.resistances.get_typed_value_builtin(), TYPE_FLOAT)
	assert_eq(back.role, EnemyDef.Role.CORE)
	assert_eq(back.counter_chance, 0.5)
	assert_true(back.counter_only_basic)
	assert_eq(ValidationIssue.errors_of(Forms.validate(back)).size(), 0)

func test_enemy_round_trip_embeds_the_new_rows() -> void:
	var path: String = _copy(ENEMY_SRC)
	var text0: String = FileAccess.get_file_as_string(path)
	var enemy: EnemyDef = _open(path) as EnemyDef
	Forms.list_add(enemy.drops, Forms.new_drop(load("res://data/fatia/items/pocao_f.tres")))
	Forms.list_add(enemy.ai_rules, Forms.new_ai_rule(load("res://data/fatia/abilities/brasa_f.tres")))
	assert_eq(Forms.save(enemy), OK)
	var text: String = FileAccess.get_file_as_string(path)
	assert_eq(_count(text, "[sub_resource"), _count(text0, "[sub_resource") + 2)
	assert_eq(_count(text, "script_class=\"EnemyDef\""), 1)

# --- ida e volta: encontro ---

func test_encounter_round_trip() -> void:
	var path: String = _copy(ENCOUNTER_SRC)
	var enc: EncounterDef = _open(path) as EncounterDef
	var before: Dictionary = Forms.snapshot(enc)
	assert_eq(enc.enemies.size(), 3)
	var f1: EnemyDef = load("res://data/fatia/enemies/inimigo_f1.tres")
	Forms.list_add(enc.enemies, f1)
	var expected: Dictionary = Forms.snapshot(enc)
	assert_eq(Forms.save(enc), OK)
	var back: EncounterDef = _fresh(path) as EncounterDef
	assert_eq(Forms.snapshot(back), expected)
	assert_eq(_diff_keys(before, expected), ["enemies"])
	assert_eq(back.enemies.size(), 4)
	assert_eq(back.enemies[3].resource_path, "res://data/fatia/enemies/inimigo_f1.tres")
	assert_eq(back.enemies[0], back.enemies[1], "o mesmo inimigo duas vezes")
	assert_eq(back.enemies.get_typed_script(), EnemyDef)
	assert_false(back.can_flee)
	assert_eq(back.unique_id, &"chefe_fatia")
	assert_eq(ValidationIssue.errors_of(Forms.validate(back)).size(), 0)
	var text: String = FileAccess.get_file_as_string(path)
	assert_eq(_count(text, "[sub_resource"), 0, "encontro só tem referências")

func test_encounter_flags_round_trip() -> void:
	var path: String = _copy(ENCOUNTER_SRC)
	var enc: EncounterDef = _open(path) as EncounterDef
	enc.can_flee = true
	enc.unique_id = &""
	Forms.list_remove(enc.enemies, 2)
	assert_eq(Forms.save(enc), OK)
	var back: EncounterDef = _fresh(path) as EncounterDef
	assert_true(back.can_flee)
	assert_eq(back.unique_id, &"")
	assert_eq(back.enemies.size(), 2)

# --- arte ---

func test_sprite_animations_read_the_properties() -> void:
	var sprites: SpriteSet = load("res://art/_exemplo/teste_a.tres")
	var anims: Dictionary = Forms.sprite_animations(sprites)
	assert_true(anims.has(&"walk_down") and anims.has(&"walk_up"))
	assert_true(anims.has(&"idle"))
	for key: Variant in anims:
		var a: Dictionary = anims[key]
		assert_false((a["rects"] as Array).is_empty(), str(key))
		var size: Vector2 = (a["sheet"] as Texture2D).get_size()
		for r: Rect2i in a["rects"]:
			assert_true(r.end.x <= int(size.x) and r.end.y <= int(size.y), str(key))
	assert_true(anims[&"idle"]["loop"])
	assert_false(anims[&"attack"]["loop"])
	assert_eq(Forms.sprite_animations(null), {})
	assert_eq(Forms.sprite_animations(SpriteSet.new()), {})

# --- nomes dos estados ---

func test_status_names_are_in_portuguese() -> void:
	assert_eq(StatusNames.name_of(&"barrier"), "Barreira")
	assert_eq(StatusNames.name_of(&"berserk"), "Berserk")
	assert_eq(StatusNames.name_of(&"poison"), "Veneno")
	assert_eq(StatusNames.name_of(&"veneno"), "Veneno")
	assert_eq(StatusNames.name_of(&"regen"), "Regeneração")
	assert_eq(StatusNames.name_of(&"algo_novo"), "Algo Novo", "sem nome no mapa: o id com inicial maiúscula")

func test_the_game_page_and_the_editor_share_the_status_names() -> void:
	assert_eq(EquipPage.STATUS_NAMES, StatusNames.NAMES)
	for id: StringName in StatusNames.NAMES:
		assert_eq(EquipPage.status_name(id), StatusNames.name_of(id), String(id))
	assert_eq(EquipPage.status_name(&"desconhecido"), "Desconhecido")

func test_status_choices_show_names_and_tell_homonyms_apart() -> void:
	var list: Array[Dictionary] = [{"id": &"poison", "label": "poison"}, {"id": &"veneno", "label": "veneno"}, {"id": &"barrier", "label": "barrier"}]
	Forms.status_labels(list)
	assert_eq(list[0]["label"], "Veneno (poison)")
	assert_eq(list[1]["label"], "Veneno (veneno)")
	assert_eq(list[2]["label"], "Barreira")
	for c: Dictionary in Forms.choices(Forms.SRC_STATUS):
		assert_ne(c["label"], String(c["id"]).to_lower() if String(c["id"]) in StatusNames.NAMES else "", "o rótulo de %s não é o id cru" % c["id"])

# --- descritores novos ---

func _prop_names(res: Object) -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in res.get_property_list():
		out.append(p["name"])
	return out

func test_new_descriptors_point_to_real_properties() -> void:
	var targets: Dictionary = {&"shops": ShopDef.new(), &"items": ItemDef.new(), &"equipment": EquipmentDef.new(),
			&"speakers": SpeakerDef.new(), &"sprites": SpriteSet.new()}
	for kind: StringName in targets:
		var names: Array[String] = _prop_names(targets[kind])
		var fields: Array[Dictionary] = Forms.fields(kind)
		assert_false(fields.is_empty(), String(kind))
		for d: Dictionary in fields:
			assert_true(names.has(String(d["prop"])), "%s.%s" % [kind, d["prop"]])
	for row: StringName in [Forms.ROW_EFFECT, Forms.ROW_PASSIVE]:
		var sample: Resource = Forms.new_row(row)
		assert_not_null(sample, String(row))
		for d: Dictionary in Forms.columns(row):
			assert_true(_prop_names(sample).has(String(d["prop"])), "%s.%s" % [row, d["prop"]])

func test_new_enum_labels_match_the_enums() -> void:
	assert_eq(Forms.EFFECT_KIND_LABELS.size(), EffectDef.Kind.size())
	assert_eq(Forms.EFFECT_SCALE_LABELS.size(), EffectDef.Scale.size())
	assert_eq(Forms.PASSIVE_KIND_LABELS.size(), EquipmentPassive.Kind.size())
	assert_eq(Forms.SHAPE_LABELS.size(), AbilityDef.Shape.size())
	assert_eq(Forms.SIDE_LABELS.size(), AbilityDef.Side.size())
	var slots: Array[StringName] = []
	for c: Dictionary in Forms.SLOT_CHOICES:
		slots.append(c["value"])
	assert_eq(slots, EquipmentRules.SLOTS)

func test_effect_columns_follow_the_kind() -> void:
	assert_true(Forms.effect_column_visible(EffectDef.Kind.DAMAGE, &"potency"))
	assert_true(Forms.effect_column_visible(EffectDef.Kind.DAMAGE, &"dodgeable"))
	assert_true(Forms.effect_column_visible(EffectDef.Kind.REVIVE, &"potency"))
	assert_false(Forms.effect_column_visible(EffectDef.Kind.REVIVE, &"scale"))
	assert_false(Forms.effect_column_visible(EffectDef.Kind.SCAN, &"potency"))
	assert_false(Forms.effect_column_visible(EffectDef.Kind.DAMAGE, &"status"))
	assert_false(Forms.effect_column_visible(EffectDef.Kind.HEAL, &"dodgeable"))
	assert_true(Forms.effect_column_visible(EffectDef.Kind.APPLY_STATUS, &"status"))
	assert_true(Forms.effect_column_visible(EffectDef.Kind.APPLY_STATUS, &"chance"))
	assert_false(Forms.effect_column_visible(EffectDef.Kind.APPLY_STATUS, &"statuses"))
	assert_true(Forms.effect_column_visible(EffectDef.Kind.REMOVE_STATUS, &"statuses"))
	assert_true(Forms.effect_column_visible(EffectDef.Kind.REMOVE_STATUS, &"status"))
	assert_false(Forms.effect_column_visible(EffectDef.Kind.REVIVE, &"status"))
	assert_true(Forms.effect_column_visible(EffectDef.Kind.REVIVE, &"kind"))
	assert_true(Forms.passive_column_visible(EquipmentPassive.Kind.RESIST, &"amount"))
	assert_false(Forms.passive_column_visible(EquipmentPassive.Kind.IMMUNE, &"amount"))
	assert_true(Forms.passive_column_visible(EquipmentPassive.Kind.START_WITH, &"status"))

func test_every_real_effect_keeps_its_meaningful_columns_visible() -> void:
	# nada que o jogo usa pode ficar escondido: um efeito real mostra todas as colunas com valor fora do padrão
	for path: String in _tres_in(["res://data/fatia/items", "res://data/test/items"]):
		var item: ItemDef = load(path)
		for e: EffectDef in item.effects:
			if e.status != null:
				assert_true(Forms.effect_column_visible(e.kind, &"status"), path)
			if not e.statuses.is_empty():
				assert_true(Forms.effect_column_visible(e.kind, &"statuses"), path)
			if e.kind == EffectDef.Kind.DAMAGE or e.kind == EffectDef.Kind.HEAL or e.kind == EffectDef.Kind.REVIVE or e.kind == EffectDef.Kind.RESTORE_AP:
				assert_true(Forms.effect_column_visible(e.kind, &"potency"), path)
			if e.kind == EffectDef.Kind.DAMAGE or e.kind == EffectDef.Kind.HEAL:
				assert_true(Forms.effect_column_visible(e.kind, &"scale"), path)
			if e.dodgeable:
				assert_true(Forms.effect_column_visible(e.kind, &"dodgeable"), path)

func _tres_in(folders: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for f: String in folders:
		for file_name: String in DirAccess.get_files_at(f):
			if file_name.get_extension() == "tres":
				out.append(f.path_join(file_name))
	return out

func test_copying_an_effect_is_independent() -> void:
	var fx: EffectDef = load("res://data/fatia/items/pocao_f.tres").effects[0]
	var poison: StatusDef = load("res://data/test/statuses/poison.tres")
	var src: EffectDef = Forms.new_effect(EffectDef.Kind.REMOVE_STATUS)
	src.statuses.append(poison)
	var copy: EffectDef = Forms.copy_row(src) as EffectDef
	copy.statuses.clear()
	assert_eq(src.statuses.size(), 1)
	assert_eq(Forms.copy_row(fx).potency, fx.potency)

# --- lojas: venda, quem veste, arquivos ---

func test_sell_value_matches_the_game_rules() -> void:
	var cfg := BalanceConfig.new()
	for path: String in _tres_in(["res://data/fatia/items", "res://data/fatia/equipment", "res://data/test/items", "res://data/test/equipment"]):
		var def: Resource = load(path)
		var price: int = int(def.get(&"price"))
		assert_eq(Forms.sell_value(price, cfg.sell_ratio), ShopRules.sell_value(def, cfg), path)
		assert_eq(Forms.can_sell(def, cfg.sell_ratio), ShopRules.can_sell(def, cfg), path)
	assert_eq(Forms.sell_value(10, 0.5), 5)
	assert_eq(Forms.sell_value(7, 0.5), 3, "arredonda para baixo")
	assert_eq(Forms.sell_value(0, 0.5), 0)
	assert_false(Forms.can_sell(null, 0.5))

func test_sell_ratio_is_the_one_the_game_loads() -> void:
	var cfg: BalanceConfig = load(Forms.BALANCE_PATH)
	assert_eq(Forms.sell_ratio(), cfg.sell_ratio)

func test_who_can_equip_matches_the_game_rules() -> void:
	var heroes: Array[Resource] = []
	for path: String in _tres_in(["res://data/fatia/heroes", "res://data/test/heroes"]):
		heroes.append(load(path))
	var equipment: Array[String] = _tres_in(["res://data/fatia/equipment", "res://data/test/equipment"])
	assert_gt(equipment.size(), 3)
	for path: String in equipment:
		var e: EquipmentDef = load(path)
		for h: CharacterDef in heroes:
			assert_eq(Forms.hero_can_equip(h, e), EquipmentRules.can_equip(h, e, e.slot), "%s x %s" % [h.id, e.id])
	# acessório vale para todos; sem herói ou sem equipamento, ninguém
	var acc := EquipmentDef.new()
	acc.slot = &"accessory"
	assert_true(Forms.hero_can_equip(heroes[0], acc))
	assert_false(Forms.hero_can_equip(null, acc))
	assert_false(Forms.hero_can_equip(heroes[0], null))

func test_equipment_offers_the_heroes_of_its_own_data_tree() -> void:
	var all: Array[Dictionary] = Forms.choices(Forms.SRC_HERO)
	var slice_ids: Array[StringName] = Forms.choice_ids(Forms.heroes_near(all, "res://data/fatia/equipment/lamina_aco_f.tres"))
	assert_eq(slice_ids.size(), 5)
	assert_true(slice_ids.has(&"teste_a_f") and not slice_ids.has(&"teste_a"))
	var test_ids: Array[StringName] = Forms.choice_ids(Forms.heroes_near(all, "res://data/test/equipment/lamina.tres"))
	assert_true(test_ids.has(&"teste_a") and not test_ids.has(&"teste_a_f"))
	assert_eq(Forms.heroes_near([] as Array[Dictionary], "res://data/fatia/x.tres").size(), 0)

func test_equippers_text() -> void:
	var slice: Array[Resource] = Forms.slice_heroes(Forms.choices(Forms.SRC_HERO).map(func(c: Dictionary) -> Variant: return c["value"]))
	assert_eq(slice.size(), 5, "os 5 heróis da fatia, sem os de teste")
	var blade: EquipmentDef = load("res://data/fatia/equipment/lamina_aco_f.tres")
	var who: String = Forms.equippers_text(blade, slice)
	assert_true(who.contains("Teste A") and who.contains("Teste D"), who)
	assert_false(who.contains("Teste B"), who)
	var acc := EquipmentDef.new()
	acc.slot = &"accessory"
	assert_eq(Forms.equippers_text(acc, slice), "todos")
	var nobody := EquipmentDef.new()
	nobody.slot = &"weapon"
	nobody.weapon_type = &"espada_inexistente"
	assert_eq(Forms.equippers_text(nobody, slice), "ninguém")
	assert_eq(Forms.equippers_text(null, slice), "—")

func test_shop_rows_of_the_slice_shop() -> void:
	var shop: ShopDef = load("res://data/fatia/shops/loja_cidade.tres")
	var slice: Array[Resource] = Forms.slice_heroes(Forms.choices(Forms.SRC_HERO).map(func(c: Dictionary) -> Variant: return c["value"]))
	var potion: Dictionary = Forms.shop_row(shop.items[0], 0.5, slice)
	assert_eq(potion["price"], shop.items[0].price)
	assert_eq(potion["sell"], shop.items[0].price / 2)
	assert_false(potion["equipment"])
	var blade: Dictionary = Forms.shop_row(shop.equipment[0], 0.5, slice)
	assert_true(blade["equipment"])
	assert_ne(blade["who"], "")
	var empty: Dictionary = Forms.shop_row(null, 0.5, slice)
	assert_eq(empty["name"], "(escolha)")
	assert_eq(empty["price"], 0)
	assert_false(empty["sellable"])
	var key: ItemDef = ItemDef.new()
	key.key_item = true
	key.price = 100
	assert_false(Forms.shop_row(key, 0.5, slice)["sellable"], "item-chave não vende")

func test_shop_save_paths_lists_only_what_changed() -> void:
	var shop: ShopDef = load("res://data/fatia/shops/loja_cidade.tres")
	var a: ItemDef = load("res://data/fatia/items/pocao_f.tres")
	var b: EquipmentDef = load("res://data/fatia/equipment/lamina_aco_f.tres")
	var originals: Dictionary = {a: a.price, b: b.price}
	assert_eq(Forms.shop_save_paths(shop, originals), [shop.resource_path] as Array[String])
	var saved_price: int = a.price
	a.price = saved_price + 5
	assert_eq(Forms.shop_save_paths(shop, originals), [shop.resource_path, a.resource_path] as Array[String])
	b.price += 1
	var paths: Array[String] = Forms.shop_save_paths(shop, originals)
	assert_eq(paths.size(), 3)
	assert_eq(paths[0], shop.resource_path)
	a.price = saved_price
	b.price -= 1
	assert_eq(Forms.shop_save_paths(shop, originals).size(), 1, "voltar ao preço original tira o arquivo da lista")
	assert_eq(Forms.shop_save_paths(null, {}).size(), 0)

# --- ida e volta: loja, item, equipamento ---

## Copia `src` para user:// trocando as referências `res://...` de `swap` pelas cópias (já em user://).
func _copy_swapping(src: String, swap: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(TMP)
	var dst: String = TMP.path_join(src.get_file())
	var text: String = FileAccess.get_file_as_string(src)
	for from: String in swap:
		text = text.replace(from, swap[from])
	var f: FileAccess = FileAccess.open(dst, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	return dst

func test_shop_round_trip_writes_the_edited_price_to_the_item() -> void:
	var potion_src: String = "res://data/fatia/items/pocao_f.tres"
	var blade_src: String = "res://data/fatia/equipment/lamina_aco_f.tres"
	var real_potion_price: int = (load(potion_src) as ItemDef).price
	var real_blade_price: int = (load(blade_src) as EquipmentDef).price
	var potion_path: String = _copy(potion_src)
	var blade_path: String = _copy(blade_src)
	var shop_path: String = _copy_swapping("res://data/fatia/shops/loja_cidade.tres", {potion_src: potion_path, blade_src: blade_path})
	var potion: ItemDef = _open(potion_path) as ItemDef
	var blade: EquipmentDef = _open(blade_path) as EquipmentDef
	var shop: ShopDef = _open(shop_path) as ShopDef
	assert_eq(shop.items[0], potion, "a loja usa a cópia")
	assert_eq(shop.equipment[0], blade)
	var originals: Dictionary = {potion: potion.price, blade: blade.price}
	var before: Dictionary = Forms.snapshot(shop)
	# editar os preços na tabela escreve no item e no equipamento, e a loja ganha uma linha e perde outra
	potion.price = 25
	blade.price = 120
	Forms.list_remove(shop.items, 4)
	Forms.list_add(shop.items, load("res://data/fatia/items/chave_f.tres"))
	var paths: Array[String] = Forms.shop_save_paths(shop, originals)
	assert_eq(paths.size(), 3)
	assert_eq(paths[0], shop_path)
	assert_true(paths.has(potion_path) and paths.has(blade_path))
	for p: String in paths:
		assert_eq(Forms.save(_resource_at(p, [shop, potion, blade])), OK, p)
	assert_eq((_fresh(potion_path) as ItemDef).price, 25)
	assert_eq((_fresh(blade_path) as EquipmentDef).price, 120)
	assert_true(FileAccess.get_file_as_string(potion_path).contains("price = 25"))
	var back: ShopDef = _fresh(shop_path) as ShopDef
	assert_eq(back.items.size(), 5)
	assert_eq(back.items[4].resource_path, "res://data/fatia/items/chave_f.tres")
	assert_eq(back.items.get_typed_script(), ItemDef)
	assert_eq(back.equipment.get_typed_script(), EquipmentDef)
	assert_eq(back.id, &"loja_cidade")
	assert_eq(_diff_keys(before, Forms.snapshot(back)), ["items"])
	# os arquivos de verdade não mudaram
	assert_eq((load(potion_src) as ItemDef).price, real_potion_price)
	assert_eq((load(blade_src) as EquipmentDef).price, real_blade_price)
	assert_true(FileAccess.get_file_as_string(potion_src).contains("price = %d" % real_potion_price))

func _resource_at(path: String, candidates: Array) -> Resource:
	for r: Resource in candidates:
		if r.resource_path == path:
			return r
	return null

func test_item_round_trip_with_effects() -> void:
	var path: String = _copy("res://data/fatia/items/pocao_f.tres")
	var item: ItemDef = _open(path) as ItemDef
	var before: Dictionary = Forms.snapshot(item)
	var poison: StatusDef = load("res://data/test/statuses/poison.tres")
	var fx: EffectDef = Forms.new_effect(EffectDef.Kind.REMOVE_STATUS)
	fx.status = poison
	fx.statuses.append(poison)
	fx.chance = 0.75
	var dmg: EffectDef = Forms.new_effect()
	dmg.scale = EffectDef.Scale.AURA
	dmg.potency = 2.5
	dmg.dodgeable = true
	Forms.list_add(item.effects, fx)
	Forms.list_add(item.effects, dmg)
	Forms.list_move(item.effects, 2, -1)
	item.shape = AbilityDef.Shape.GROUP
	item.side = AbilityDef.Side.BOTH
	item.key_item = true
	item.price = 33
	item.display_name = "Poção Forte"
	var expected: Dictionary = Forms.snapshot(item)
	assert_eq(Forms.save(item), OK)
	var back: ItemDef = _fresh(path) as ItemDef
	assert_eq(Forms.snapshot(back), expected)
	assert_eq(back.effects.size(), 3)
	assert_eq(back.effects.get_typed_script(), EffectDef)
	assert_eq(back.effects[1].potency, 2.5)
	assert_eq(back.effects[1].scale, EffectDef.Scale.AURA)
	assert_true(back.effects[1].dodgeable)
	assert_eq(back.effects[2].kind, EffectDef.Kind.REMOVE_STATUS)
	assert_eq(back.effects[2].chance, 0.75)
	assert_eq(back.effects[2].status.resource_path, "res://data/test/statuses/poison.tres")
	assert_eq(back.effects[2].statuses.size(), 1)
	assert_eq(back.effects[2].statuses.get_typed_script(), StatusDef)
	assert_eq(back.shape, AbilityDef.Shape.GROUP)
	assert_eq(back.side, AbilityDef.Side.BOTH)
	assert_true(back.key_item)
	assert_eq(back.price, 33)
	assert_eq(back.display_name, "Poção Forte")
	assert_eq(back.id, &"pocao_f")
	assert_eq(_diff_keys(before, expected), ["display_name", "effects", "key_item", "price", "shape", "side"])
	assert_eq(ValidationIssue.errors_of(Forms.validate(back)).size(), 0)
	var text: String = FileAccess.get_file_as_string(path)
	assert_eq(_count(text, "script_class=\"ItemDef\""), 1)
	assert_eq(_count(text, "[sub_resource"), 3)

func test_item_effects_can_be_removed_and_duplicated() -> void:
	var path: String = _copy("res://data/fatia/items/pocao_f.tres")
	var item: ItemDef = _open(path) as ItemDef
	Forms.list_duplicate(item.effects, 0)
	assert_eq(item.effects.size(), 2)
	assert_ne(item.effects[0], item.effects[1])
	item.effects[1].potency = 99.0
	assert_ne(item.effects[0].potency, 99.0)
	Forms.list_remove(item.effects, 0)
	assert_eq(Forms.save(item), OK)
	var back: ItemDef = _fresh(path) as ItemDef
	assert_eq(back.effects.size(), 1)
	assert_eq(back.effects[0].potency, 99.0)

func test_equipment_round_trip_with_passives_and_element_resist() -> void:
	var path: String = _copy("res://data/fatia/equipment/lamina_aco_f.tres")
	var equip: EquipmentDef = _open(path) as EquipmentDef
	var before: Dictionary = Forms.snapshot(equip)
	var poison: StatusDef = load("res://data/test/statuses/poison.tres")
	var fire: ElementDef = load("res://data/elements/amaterasu.tres")
	Forms.list_add(equip.passives, Forms.new_passive(EquipmentPassive.Kind.RESIST, poison))
	equip.passives[0].amount = 0.4
	Forms.list_add(equip.passives, Forms.new_passive(EquipmentPassive.Kind.IMMUNE, poison))
	Forms.list_add(equip.passives, Forms.new_passive(EquipmentPassive.Kind.START_WITH, poison))
	Forms.dict_set_percent(equip.element_resist, fire.id, 30.0)
	Forms.dict_set_percent(equip.element_resist, &"kagutsuchi", -50.0)
	Forms.names_toggle(equip.allowed_ids, &"teste_a_f", true)
	Forms.names_toggle(equip.allowed_ids, &"teste_d_f", true)
	Forms.ensure_stats(equip, &"modifiers").speed = 2
	equip.slot = &"armor"
	equip.weapon_type = &""
	equip.price = 99
	equip.element = fire
	var expected: Dictionary = Forms.snapshot(equip)
	assert_eq(Forms.save(equip), OK)
	var back: EquipmentDef = _fresh(path) as EquipmentDef
	assert_eq(Forms.snapshot(back), expected)
	assert_eq(back.passives.size(), 3)
	assert_eq(back.passives.get_typed_script(), EquipmentPassive)
	assert_eq(back.passives[0].kind, EquipmentPassive.Kind.RESIST)
	assert_eq(back.passives[0].amount, 0.4)
	assert_eq(back.passives[0].status.resource_path, "res://data/test/statuses/poison.tres")
	assert_eq(back.passives[2].kind, EquipmentPassive.Kind.START_WITH)
	assert_eq(back.element_resist.size(), 2)
	assert_eq(back.element_resist.get_typed_key_builtin(), TYPE_STRING_NAME)
	assert_eq(back.element_resist.get_typed_value_builtin(), TYPE_FLOAT)
	assert_eq(back.element_resist[fire.id], 0.3)
	assert_eq(back.element_resist[&"kagutsuchi"], -0.5)
	assert_eq(back.allowed_ids, [&"teste_a_f", &"teste_d_f"] as Array[StringName])
	assert_eq(back.allowed_ids.get_typed_builtin(), TYPE_STRING_NAME)
	assert_eq(back.modifiers.speed, 2)
	assert_eq(back.modifiers.strength, 4, "os outros atributos ficam")
	assert_eq(back.slot, &"armor")
	assert_eq(back.weapon_type, &"")
	assert_eq(back.price, 99)
	assert_eq(back.element.resource_path, fire.resource_path)
	assert_eq(back.id, &"lamina_aco_f")
	assert_eq(ValidationIssue.errors_of(Forms.validate(back)).size(), 0)
	assert_true(_diff_keys(before, expected).has("passives") and _diff_keys(before, expected).has("element_resist"))

func test_equipment_choice_values_are_the_game_ones() -> void:
	var weapons: Array[StringName] = []
	for c: Dictionary in Forms.WEAPON_CHOICES:
		weapons.append(c["value"])
	for path: String in _tres_in(["res://data/fatia/equipment", "res://data/test/equipment"]):
		var e: EquipmentDef = load(path)
		assert_true(weapons.has(e.weapon_type), "%s: tipo de arma %s" % [path, e.weapon_type])

# --- arte: anims e retratos ---

func test_next_anim_and_expression() -> void:
	var anims: Dictionary = {}
	assert_eq(Forms.next_anim(anims), [&"idle", Vector3i(0, 1, 6)])
	anims[&"idle"] = Vector3i(0, 4, 6)
	assert_eq(Forms.next_anim(anims), [&"attack", Vector3i(1, 1, 6)])
	assert_eq(Forms.next_anim(anims, 1), [&"attack", Vector3i(0, 1, 6)], "limitada às linhas da folha")
	for n: StringName in Forms.STANDARD_ANIMS:
		anims[n] = Vector3i(0, 1, 1)
	assert_eq((Forms.next_anim(anims)[0] as StringName), &"anim_1")
	var portraits: Dictionary = {}
	assert_eq(Forms.next_expression(portraits), &"neutro")
	portraits[&"neutro"] = null
	assert_eq(Forms.next_expression(portraits), &"feliz")
	for n: StringName in Forms.STANDARD_EXPRESSIONS:
		portraits[n] = null
	assert_eq(Forms.next_expression(portraits), &"retrato_1")

func test_sheet_rows_and_texture_choices() -> void:
	var tex: Texture2D = load("res://art/_exemplo/teste_a_battle.png")
	assert_eq(Forms.sheet_rows(tex, Vector2i(64, 64)), 6)
	assert_eq(Forms.sheet_rows(tex, Vector2i(64, 0)), 0)
	assert_eq(Forms.sheet_rows(null, Vector2i(64, 64)), 0)
	var found: Array[String] = []
	for c: Dictionary in Forms.texture_choices():
		found.append(String(c["id"]))
		assert_true(c["value"] is Texture2D)
	assert_true(found.has("res://art/_exemplo/teste_a_map.png"))
	assert_true(found.has("res://art/_exemplo/teste_a_portrait_feliz.png"))

func test_sprite_set_round_trip_with_anims_and_portraits() -> void:
	var path: String = _copy("res://art/_exemplo/teste_a.tres")
	var sprites: SpriteSet = _open(path) as SpriteSet
	var before: Dictionary = Forms.snapshot(sprites)
	assert_eq(sprites.anims.size(), 6)
	assert_eq(sprites.portraits.size(), 2)
	# renomear uma animação mantém o valor e a posição; adicionar usa a linha seguinte; um retrato sai e outro entra
	assert_true(Forms.dict_rename(sprites.anims, &"idle", &"parado"))
	sprites.anims[&"hit"] = Vector3i(3, 1, 12)
	var extra: Array = Forms.next_anim(sprites.anims, Forms.sheet_rows(sprites.battle_sheet, sprites.battle_frame))
	sprites.anims[extra[0]] = extra[1]
	assert_eq(extra[0], &"idle", "o nome padrão que ficou livre com a troca")
	assert_eq(extra[1], Vector3i(5, 1, 6), "a linha seguinte à maior em uso, limitada à folha")
	sprites.anims.erase(&"cast")
	sprites.portraits.erase(&"feliz")
	sprites.portraits[&"triste"] = load("res://art/_exemplo/teste_a_portrait_feliz.png")
	sprites.walk_fps = 6.0
	sprites.walk_frames = 3
	sprites.battle_faces_right = false
	sprites.portrait_size = Vector2i(96, 96)
	var expected: Dictionary = Forms.snapshot(sprites)
	assert_eq(Forms.save(sprites), OK)
	var back: SpriteSet = _fresh(path) as SpriteSet
	assert_eq(Forms.snapshot(back), expected)
	assert_eq(back.anims.size(), 6)
	assert_eq(back.anims[&"idle"], Vector3i(5, 1, 6))
	assert_eq(back.anims[&"parado"], Vector3i(0, 2, 4))
	assert_eq(back.anims[&"hit"], Vector3i(3, 1, 12))
	assert_false(back.anims.has(&"cast"))
	assert_eq(back.anims.get_typed_key_builtin(), TYPE_STRING_NAME)
	assert_eq(back.anims.get_typed_value_builtin(), TYPE_VECTOR3I)
	assert_eq(back.portraits.size(), 2)
	assert_true(back.portraits.has(&"neutro") and back.portraits.has(&"triste"))
	assert_false(back.portraits.has(&"feliz"))
	assert_eq(back.portraits.get_typed_value_class_name(), &"Texture2D")
	assert_eq(back.portraits[&"triste"].resource_path, "res://art/_exemplo/teste_a_portrait_feliz.png")
	assert_eq(back.walk_fps, 6.0)
	assert_false(back.battle_faces_right)
	assert_eq(back.map_sheet.resource_path, "res://art/_exemplo/teste_a_map.png")
	assert_eq(back.map_sheet, sprites.map_sheet)
	assert_true(_diff_keys(before, expected).has("anims") and _diff_keys(before, expected).has("portraits"))
	var Wizard: GDScript = load("res://addons/vat_editor/logic/sprite_wizard.gd")
	assert_eq(ValidationIssue.errors_of(Wizard.issues(back)).size(), 0)

func test_sprite_set_round_trip_keeps_an_empty_portrait_set_valid() -> void:
	var path: String = _copy("res://art/_exemplo/teste_a.tres")
	var sprites: SpriteSet = _open(path) as SpriteSet
	sprites.portraits.clear()
	sprites.anims.clear()
	assert_eq(Forms.save(sprites), OK)
	var back: SpriteSet = Forms.reload_file(path) as SpriteSet
	assert_eq(back.portraits.size(), 0)
	assert_eq(back.anims.size(), 0)
	assert_eq(Forms.snapshot(back), Forms.snapshot(sprites))

func test_speaker_round_trip_keeps_the_art_reference() -> void:
	var path: String = _copy("res://art/_exemplo/morador_a_exemplo.tres")
	var speaker: SpeakerDef = _open(path) as SpeakerDef
	speaker.display_name = "Morador Z"
	assert_eq(Forms.save(speaker), OK)
	var back: SpeakerDef = _fresh(path) as SpeakerDef
	assert_eq(back.display_name, "Morador Z")
	assert_eq(back.sprites.resource_path, "res://art/_exemplo/npc_exemplo.tres")
	assert_eq(back.id, &"morador_a_exemplo")

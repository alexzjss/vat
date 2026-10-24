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

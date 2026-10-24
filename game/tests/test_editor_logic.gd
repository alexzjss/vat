extends GutTest

## Lógica pura do painel VAT do editor (M16): categorias, listagem, linhas, criação a partir de modelo, argumentos de
## teste, agrupamento dos achados e a fronteira (o jogo nunca carrega nada de addons/vat_editor).

const Categories: GDScript = preload("res://addons/vat_editor/logic/vat_categories.gd")
const Catalog: GDScript = preload("res://addons/vat_editor/logic/vat_catalog.gd")
const Rows: GDScript = preload("res://addons/vat_editor/logic/vat_rows.gd")
const NewEntry: GDScript = preload("res://addons/vat_editor/logic/vat_new_entry.gd")
const RunArgs: GDScript = preload("res://addons/vat_editor/logic/vat_run_args.gd")
const Issues: GDScript = preload("res://addons/vat_editor/logic/vat_issues.gd")
const Roteiros: GDScript = preload("res://addons/vat_editor/logic/vat_roteiros.gd")

const TMP: String = "user://test_editor_logic/"

func after_each() -> void:
	_rm_tree(TMP)

func _rm_tree(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		_rm_tree(dir.path_join(d))
	DirAccess.remove_absolute(dir)

func _touch(path: String, text: String = "") -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _item(id: StringName, price: int = 0) -> ItemDef:
	var i := ItemDef.new()
	i.id = id
	i.display_name = "Item %s" % id
	i.price = price
	return i

# --- categorias ---

func test_there_are_thirteen_categories_in_tab_order() -> void:
	var expected: Array[StringName] = [&"heroes", &"enemies", &"abilities", &"items", &"equipment", &"encounters",
			&"shops", &"statuses", &"elements", &"reactions", &"terrain", &"speakers", &"sprites"]
	assert_eq(Categories.keys(), expected)

func test_every_category_has_a_template_that_loads_and_matches() -> void:
	for key: StringName in Categories.keys():
		var cat: Dictionary = Categories.get_category(key)
		var tpl: Resource = load(cat["template"]) as Resource
		assert_not_null(tpl, "modelo de %s" % key)
		assert_true(Categories.matches(key, tpl), "o modelo de %s é da classe %s" % [key, cat["script_class"]])
		assert_eq(Categories.key_of(tpl), key)
		assert_true((cat["new_folder"] as String).begins_with("res://"))
		assert_false((cat["columns"] as Array).is_empty(), "colunas-chave de %s" % key)

func test_matches_checks_the_class() -> void:
	var item: ItemDef = _item(&"x")
	assert_true(Categories.matches(&"items", item))
	assert_false(Categories.matches(&"heroes", item))
	assert_false(Categories.matches(&"nao_existe", item))
	assert_false(Categories.matches(&"items", null))
	assert_eq(Categories.key_of(item), &"items")
	assert_eq(Categories.key_of(Resource.new()), &"")

func test_default_new_folder_is_the_slice_one() -> void:
	assert_eq(Categories.get_category(&"items")["new_folder"], "res://data/fatia/items")
	assert_eq(Categories.get_category(&"heroes")["new_folder"], "res://data/fatia/heroes")
	assert_eq(Categories.get_category(&"elements")["new_folder"], "res://data/elements")

func test_templates_save_and_reload_with_the_new_id() -> void:
	for key: StringName in Categories.keys():
		var built: Dictionary = NewEntry.build(key, "tmp_%s" % key, "res://data/fatia/tmp_nao_existe", null, [])
		assert_true(built["ok"], "%s: %s" % [key, built["error"]])
		var path: String = TMP + (built["path"] as String).get_file()
		DirAccess.make_dir_recursive_absolute(TMP)
		assert_eq(ResourceSaver.save(built["resource"], path), OK, "salva %s" % key)
		var back: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert_not_null(back)
		# a arte (SpriteSet) não tem id: a linha usa o nome do arquivo
		assert_eq(StringName(Rows.id_of(back)), StringName("tmp_%s" % key))
		assert_true(Categories.matches(key, back))

# --- listagem ---

func test_list_paths_is_recursive_sorted_and_only_tres() -> void:
	_touch(TMP + "b.tres")
	_touch(TMP + "a.tres")
	_touch(TMP + "ignorado.txt")
	_touch(TMP + "sub/c.tres")
	var folders: Array[String] = [TMP.trim_suffix("/"), "user://nao_existe"]
	var paths: Array[String] = Catalog.list_paths(folders)
	assert_eq(paths, [TMP + "a.tres", TMP + "b.tres", TMP + "sub/c.tres"] as Array[String])

func test_load_category_returns_only_resources_of_that_class() -> void:
	var heroes: Array[Resource] = Catalog.load_category(&"heroes")
	assert_gt(heroes.size(), 5, "heróis da fatia e de teste")
	for r: Resource in heroes:
		assert_true(r is CharacterDef)
	var enemies: Array[Resource] = Catalog.load_category(&"enemies")
	assert_gt(enemies.size(), 0)
	for r: Resource in enemies:
		assert_true(r is EnemyDef)
	var speakers: Array[Resource] = Catalog.load_category(&"speakers")
	for r: Resource in speakers:
		assert_true(r is SpeakerDef, "a pasta art tem SpriteSet também, que fica de fora")
	assert_eq(Catalog.load_category(&"nada").size(), 0)

func test_find_by_id_uses_the_index_for_indexed_kinds_and_a_scan_for_the_rest() -> void:
	var item: ItemDef = _item(&"pocao_x")
	var enemy := EnemyDef.new()
	enemy.id = &"orc_x"
	var all: Array = [item, enemy]
	assert_eq(Catalog.find_by_id(&"items", &"pocao_x", all), item)
	assert_eq(Catalog.find_by_id(&"enemies", &"orc_x", all), enemy)
	assert_null(Catalog.find_by_id(&"items", &"orc_x", all), "o id de outro tipo não conta")
	assert_null(Catalog.find_by_id(&"enemies", &"pocao_x", all))

# --- linhas ---

func test_headers_are_id_name_and_the_key_columns() -> void:
	assert_eq(Rows.headers(&"items"), PackedStringArray(["Id", "Nome", "Preço", "Chave"]))
	assert_eq(Rows.headers(&"enemies"), PackedStringArray(["Id", "Nome", "Nível", "XP"]))
	assert_eq(Rows.headers(&"abilities"), PackedStringArray(["Id", "Nome", "PA", "Elemento"]))

func test_row_formats_an_item() -> void:
	var item: ItemDef = _item(&"pocao_x", 30)
	item.key_item = true
	item.take_over_path("res://data/test/_fake_item.tres")
	var row: Dictionary = Rows.row(&"items", item)
	assert_eq(row["id"], "pocao_x")
	assert_eq(row["name"], "Item pocao_x")
	assert_eq(row["path"], "res://data/test/_fake_item.tres")
	assert_eq(row["cells"], PackedStringArray(["pocao_x", "Item pocao_x", "30", "sim"]))

func test_row_cells_match_the_headers_for_real_data_in_every_category() -> void:
	for key: StringName in Categories.keys():
		var list: Array[Resource] = Catalog.load_category(key)
		if list.is_empty():
			continue
		var row: Dictionary = Rows.row(key, list[0])
		assert_eq((row["cells"] as PackedStringArray).size(), Rows.headers(key).size(), "colunas de %s" % key)

func test_format_cell_modes() -> void:
	assert_eq(Rows.format_cell(5, "val"), "5")
	assert_eq(Rows.format_cell(0.25, "val"), "0.25")
	assert_eq(Rows.format_cell(null, "val"), "")
	assert_eq(Rows.format_cell([1, 2, 3], "count"), "3")
	assert_eq(Rows.format_cell({"a": 1}, "count"), "1")
	assert_eq(Rows.format_cell(null, "count"), "0")
	assert_eq(Rows.format_cell(true, "bool"), "sim")
	assert_eq(Rows.format_cell(false, "bool"), "não")
	assert_eq(Rows.format_cell(StatusDef.Kind.SLEEP, "kind"), "sleep")
	assert_eq(Rows.format_cell(null, "ids"), "-")
	var e := ElementDef.new()
	e.id = &"fogo_x"
	assert_eq(Rows.format_cell(e, "ids"), "fogo_x")
	var e2 := ElementDef.new()
	e2.id = &"agua_x"
	assert_eq(Rows.format_cell([e, e2], "ids"), "fogo_x, agua_x")
	assert_eq(Rows.format_cell(SpriteSet.new(), "ids"), "(embutido)", "sem id e sem caminho")

func test_filter_matches_any_cell_case_insensitively() -> void:
	var rows: Array[Dictionary] = Rows.rows(&"items", [_item(&"pocao_x", 30), _item(&"eter_x", 90)])
	assert_eq(Rows.filter(rows, "").size(), 2, "busca vazia mostra tudo")
	assert_eq(Rows.filter(rows, "POCAO").size(), 1)
	assert_eq(Rows.filter(rows, "90").size(), 1, "acha pela coluna de preço")
	assert_eq(Rows.filter(rows, " eter ").size(), 1, "ignora espaços nas pontas")
	assert_eq(Rows.filter(rows, "zzz").size(), 0)

# --- novo e duplicar ---

func test_id_error_rules() -> void:
	assert_ne(NewEntry.id_error(""), "")
	assert_ne(NewEntry.id_error("Maiuscula"), "")
	assert_ne(NewEntry.id_error("com espaco"), "")
	assert_ne(NewEntry.id_error("1comeca_com_numero"), "")
	assert_ne(NewEntry.id_error("acentuação"), "")
	assert_eq(NewEntry.id_error("pocao_2"), "")

func test_target_path_joins_folder_and_id() -> void:
	assert_eq(NewEntry.target_path("res://data/fatia/items", "x"), "res://data/fatia/items/x.tres")
	assert_eq(NewEntry.target_path("res://data/fatia/items/", "x"), "res://data/fatia/items/x.tres")

func test_new_from_template_has_the_new_id_and_template_fields() -> void:
	var built: Dictionary = NewEntry.build(&"items", "pocao_nova", "res://data/fatia/items", null, [])
	assert_true(built["ok"], built["error"])
	assert_eq(built["path"], "res://data/fatia/items/pocao_nova.tres")
	var item: ItemDef = built["resource"] as ItemDef
	assert_not_null(item)
	assert_eq(item.id, &"pocao_nova")
	assert_eq(item.display_name, "Novo item", "o resto vem do modelo")
	assert_eq(item.price, 10)
	var tpl: ItemDef = load("res://addons/vat_editor/templates/items.tres") as ItemDef
	assert_eq(tpl.id, &"novo_item", "o modelo em si não muda")

func test_new_hero_template_has_stats_and_a_basic_attack() -> void:
	var built: Dictionary = NewEntry.build(&"heroes", "heroi_novo", "res://data/fatia/heroes", null, [])
	assert_true(built["ok"], built["error"])
	var hero: CharacterDef = built["resource"] as CharacterDef
	assert_not_null(hero.base)
	assert_not_null(hero.basic_attack)
	var tpl: CharacterDef = load("res://addons/vat_editor/templates/heroes.tres") as CharacterDef
	assert_ne(hero.base, tpl.base, "os atributos embutidos são copiados, não compartilhados")
	assert_eq(hero.basic_attack, tpl.basic_attack, "a habilidade externa continua a mesma referência")

func test_duplicate_id_is_refused_for_indexed_and_other_kinds() -> void:
	var hero_ids: Array[Resource] = Catalog.load_category(&"heroes")
	var all: Array = []
	all.append_array(hero_ids)
	all.append_array(Catalog.load_category(&"enemies"))
	var existing_hero: StringName = hero_ids[0].get(&"id")
	var built: Dictionary = NewEntry.build(&"heroes", String(existing_hero), "res://data/fatia/heroes", null, all)
	assert_false(built["ok"])
	assert_string_contains(built["error"], "já existe")
	assert_null(built["resource"])
	var existing_enemy: StringName = Catalog.load_category(&"enemies")[0].get(&"id")
	var again: Dictionary = NewEntry.build(&"enemies", String(existing_enemy), "res://data/fatia/enemies", null, all)
	assert_false(again["ok"], "inimigos não passam pelo ContentIndex, mas também são recusados")
	var other_kind: Dictionary = NewEntry.build(&"items", String(existing_hero), "res://data/fatia/items", null, all)
	assert_true(other_kind["ok"], "o mesmo id em outro tipo é permitido")

func test_duplicate_flow_copies_the_source_with_the_new_id() -> void:
	var src: ItemDef = _item(&"original", 42)
	var built: Dictionary = NewEntry.build(&"items", "copia", "res://data/fatia/items", src, [src])
	assert_true(built["ok"], built["error"])
	var copy: ItemDef = built["resource"] as ItemDef
	assert_ne(copy, src)
	assert_eq(copy.id, &"copia")
	assert_eq(copy.price, 42)
	assert_eq(copy.display_name, "Item original")
	assert_eq(src.id, &"original", "o original não muda")

func test_duplicate_of_the_wrong_category_is_refused() -> void:
	var built: Dictionary = NewEntry.build(&"heroes", "heroi_x", "res://data/fatia/heroes", _item(&"x"), [])
	assert_false(built["ok"])
	assert_string_contains(built["error"], "categoria")

func test_bad_id_folder_and_existing_file_are_refused() -> void:
	assert_false(NewEntry.build(&"items", "Ruim", "res://data/fatia/items", null, [])["ok"])
	assert_false(NewEntry.build(&"items", "ok_id", "C:/fora", null, [])["ok"])
	assert_false(NewEntry.build(&"items", "ok_id", "res://data/../x", null, [])["ok"])
	assert_false(NewEntry.build(&"nada", "ok_id", "res://data", null, [])["ok"])
	var existing_file: Dictionary = NewEntry.build(&"items", "erva_teste", "res://data/fatia/items", null, [])
	assert_false(existing_file["ok"], "o arquivo já existe, mesmo sem o recurso estar na lista")
	assert_string_contains(existing_file["error"], "arquivo")

# --- argumentos de teste ---

func test_play_map_args() -> void:
	assert_eq(RunArgs.play_map(&"cidade"), PackedStringArray(["--start-map=cidade"]))
	assert_eq(RunArgs.play_map(&"cidade", &"Entry"), PackedStringArray(["--start-map=cidade", "--spawn=Entry"]))
	assert_eq(RunArgs.to_setting(RunArgs.play_map(&"casa_1", &"Porta")), "--start-map=casa_1 --spawn=Porta")

func test_process_args_put_the_flags_after_the_double_dash() -> void:
	var cmd: PackedStringArray = RunArgs.process_args("E:/proj/game", RunArgs.play_map(&"cidade", &"Entry"))
	assert_eq(cmd, PackedStringArray(["--path", "E:/proj/game", "--", "--start-map=cidade", "--spawn=Entry"]))
	var dash: int = cmd.find("--")
	assert_eq(Game.parse_dev_flags(cmd.slice(dash + 1))["start_map"], &"cidade", "o jogo só vê o que vem depois do --")

func test_battle_args() -> void:
	assert_eq(RunArgs.battle(&"enc_f1", 7), PackedStringArray(["--battle=enc_f1", "--level=7"]))
	assert_eq(RunArgs.battle(&"enc_f1", 0), PackedStringArray(["--battle=enc_f1", "--level=1"]), "nível mínimo 1")
	assert_eq(RunArgs.battle(&"enc_f1", 3, &"estrada", &"Start"),
			PackedStringArray(["--start-map=estrada", "--spawn=Start", "--battle=enc_f1", "--level=3"]))
	assert_eq(RunArgs.to_setting(PackedStringArray()), "")

func test_markers_come_from_the_scene_and_feed_the_args() -> void:
	var markers: Array[StringName] = RunArgs.markers_of(Game.default_registry().scene_of(&"cidade"))
	assert_false(markers.is_empty())
	for m: StringName in markers:
		assert_true(RunArgs.play_map(&"cidade", m)[1].ends_with(String(m)))
	assert_true(RunArgs.markers_of(null).is_empty())

func test_the_args_are_understood_by_the_game() -> void:
	var dev: Dictionary = Game.parse_dev_flags(RunArgs.battle(&"enc_f1", 4, &"cidade", &"Entry"))
	assert_eq(dev["start_map"], &"cidade")
	assert_eq(dev["spawn"], &"Entry")
	assert_eq(dev["battle"], &"enc_f1")
	assert_eq(dev["level"], "4")

# --- achados do validador ---

func test_issues_group_by_severity() -> void:
	var list: Array[ValidationIssue] = [
		ValidationIssue.warning("sem arte", "res://a.tres"),
		ValidationIssue.error("id repetido", "res://b.tres"),
		ValidationIssue.error("rótulo quebrado", "res://c.roteiro", 12),
	]
	var g: Dictionary = Issues.group(list)
	assert_eq((g["errors"] as Array).size(), 2)
	assert_eq((g["warnings"] as Array).size(), 1)
	assert_eq(Issues.summary(list), "2 erro(s), 1 aviso(s).")
	var none: Array[ValidationIssue] = []
	assert_eq(Issues.summary(none), "Tudo certo: nenhum erro e nenhum aviso.")

func test_outcome_reports_a_failed_child_instead_of_all_clear() -> void:
	var missing: Dictionary = Issues.outcome(0, false, "")
	assert_false(missing["ok"])
	assert_eq(missing["message"], "Falha ao rodar o validador (código 0)")
	var crashed: Dictionary = Issues.outcome(2, true, "")
	assert_false(crashed["ok"])
	assert_eq(crashed["message"], "Falha ao rodar o validador (código 2)")
	var clean: Dictionary = Issues.outcome(0, true, "")
	assert_true(clean["ok"])
	assert_eq(clean["message"], "Tudo certo: nenhum erro e nenhum aviso.")
	var line: String = ValidationIssue.error("id repetido", "res://b.tres").to_line()
	var with_errors: Dictionary = Issues.outcome(1, true, line)
	assert_true(with_errors["ok"])
	assert_eq(with_errors["message"], "1 erro(s), 0 aviso(s).")

func test_issue_entries_carry_text_path_and_line() -> void:
	var e: Dictionary = Issues.entry(ValidationIssue.error("rótulo quebrado", "res://c.roteiro", 12))
	assert_eq(e["text"], "res://c.roteiro:12: rótulo quebrado")
	assert_eq(e["path"], "res://c.roteiro")
	assert_eq(e["line"], 12)
	assert_true(e["error"])
	var w: Dictionary = Issues.entry(ValidationIssue.warning("sem arte"))
	assert_eq(w["text"], "sem arte")
	assert_false(w["error"])
	var list: Array[ValidationIssue] = [ValidationIssue.warning("a"), ValidationIssue.error("b")]
	assert_eq(Issues.entries(list).size(), 2)

func test_target_kind_by_extension() -> void:
	assert_eq(Issues.target_kind("res://data/x.tres"), &"resource")
	assert_eq(Issues.target_kind("res://data/x.res"), &"resource")
	assert_eq(Issues.target_kind("res://data/fatia/roteiro/cidade.roteiro"), &"roteiro")
	assert_eq(Issues.target_kind("res://world/fatia/cidade.tscn"), &"scene")
	assert_eq(Issues.target_kind(""), &"none")

func test_issue_lines_round_trip_through_the_child_process_output() -> void:
	var e: ValidationIssue = ValidationIssue.error("rótulo \"x \" quebrado", "res://c.roteiro", 12)
	var back: ValidationIssue = ValidationIssue.from_line(e.to_line())
	assert_eq(back.severity, ValidationIssue.Severity.ERROR)
	assert_eq(back.message, e.message)
	assert_eq(back.path, "res://c.roteiro")
	assert_eq(back.line, 12)
	assert_null(ValidationIssue.from_line("== AVISOS (0) =="), "linha comum é ignorada")
	assert_null(ValidationIssue.from_line("VATISSUE {quebrado"))
	var w: ValidationIssue = ValidationIssue.warning("sem arte", "res://a.tres")
	var output: String = "Godot Engine v4\n%s\nlixo\n%s\r\n" % [e.to_line(), w.to_line()]
	var parsed: Array[ValidationIssue] = Issues.parse_output(output)
	assert_eq(parsed.size(), 2)
	assert_eq(parsed[1].severity, ValidationIssue.Severity.WARNING)
	assert_eq(parsed[1].path, "res://a.tres")
	var args: PackedStringArray = Issues.child_args("E:/proj/game", "E:/out.txt")
	assert_true(args.has("--headless"))
	assert_eq(args[args.size() - 1], "--json=E:/out.txt")
	assert_true(args.has("res://tools/validate/check_all.gd"))

func test_real_validation_groups_without_errors() -> void:
	var issues: Array[ValidationIssue] = ContentChecks.missing_battle_art([EnemyDef.new()])
	assert_eq((Issues.group(issues)["warnings"] as Array).size(), 1)

# --- roteiros ---

func test_parse_message_splits_line_and_text() -> void:
	assert_eq(Roteiros.parse_message("cidade.roteiro:12: rótulo 'x' não existe"), {"line": 12, "message": "rótulo 'x' não existe"})
	assert_eq(Roteiros.parse_message("sem linha"), {"line": 0, "message": "sem linha"})
	assert_eq(Roteiros.format_finding({"line": 3, "message": "oi"}), "linha 3: oi")
	assert_eq(Roteiros.format_finding({"line": 0, "message": "oi"}), "oi")

func test_report_lists_events_and_errors_of_a_file() -> void:
	var index: ContentIndex = RoteiroTools.scan_content()
	var good: Dictionary = Roteiros.report("res://data/fatia/roteiro/cidade.roteiro", index)
	assert_gt((good["events"] as Array).size(), 0)
	assert_eq((good["errors"] as Array).size(), 0)
	_touch(TMP + "ruim.roteiro", "=== ruim\nMorador: oi\n-> sumiu\n")
	var bad: Dictionary = Roteiros.report(TMP + "ruim.roteiro", index)
	assert_gt((bad["errors"] as Array).size(), 0, "o texto quebrado dá erro")
	assert_gt(int((bad["errors"] as Array)[0]["line"]), 0, "com a linha")
	var all: Array[Dictionary] = Roteiros.scan(index)
	assert_gt(all.size(), 2, "os três roteiros da fatia")

# --- fronteira ---

func _runtime_files(dir: String, out: Array[String]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "tscn", "tres"]:
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		if d != ".godot":
			_runtime_files(dir.path_join(d), out)

func test_the_game_never_loads_anything_from_the_editor_addon() -> void:
	var files: Array[String] = []
	for root: String in ["res://core", "res://battle", "res://world", "res://ui", "res://data", "res://art"]:
		_runtime_files(root, files)
	assert_gt(files.size(), 100, "varreu o código do jogo")
	var offenders: Array[String] = []
	for path: String in files:
		if FileAccess.get_file_as_string(path).contains("vat_editor"):
			offenders.append(path)
	assert_eq(offenders, [] as Array[String], "o jogo exportado não pode depender de addons/vat_editor")

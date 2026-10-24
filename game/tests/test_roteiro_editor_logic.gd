extends GutTest

## Lógica do editor de blocos do roteiro (M17): as listas dos menus, os campos de cada tipo de bloco, as edições,
## o mapa linha -> bloco dos erros, o dirty e a ida e volta byte a byte do arquivo aberto e salvo sem edição.

const Options: GDScript = preload("res://addons/vat_editor/logic/roteiro_options.gd")
const Logic: GDScript = preload("res://addons/vat_editor/logic/roteiro_editor_logic.gd")
const Kind = RoteiroBlock.Kind

const BOOKS: Array[String] = [
	"res://data/fatia/roteiro/cidade.roteiro",
	"res://data/fatia/roteiro/casas.roteiro",
	"res://data/fatia/roteiro/dungeon.roteiro",
]
const TMP: String = "user://test_roteiro_editor/"

static var _index: ContentIndex

static func _content() -> ContentIndex:
	if _index == null:
		_index = RoteiroTools.scan_content()
	return _index

func after_each() -> void:
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _doc(text: String) -> RoteiroDoc:
	return RoteiroDoc.parse(text)["doc"] as RoteiroDoc

func _cidade() -> RoteiroDoc:
	return _doc(_read(BOOKS[0]))

func _errors(doc: RoteiroDoc) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in Logic.diagnostics(doc, "t.roteiro", _content()):
		if d["severity"] == "erro":
			out.append(d)
	return out

# --- listas dos menus ---

func test_content_lists_come_from_the_index_sorted() -> void:
	var ix: ContentIndex = _content()
	assert_true(Options.items(ix).has("erva_teste"))
	assert_true(Options.equipment(ix).has("capacete_teste_b_f"))
	assert_true(Options.heroes(ix).has("teste_a_f"))
	assert_true(Options.encounters(ix).has("enc_f1"))
	assert_true(Options.abilities(ix).has("chama_f"))
	for list: Array[String] in [Options.items(ix), Options.heroes(ix), Options.encounters(ix)]:
		var sorted: Array[String] = list.duplicate()
		sorted.sort()
		assert_eq(list, sorted, "em ordem alfabética")
	assert_eq(Options.items(null), [] as Array[String])

func test_display_shows_the_id_and_the_name() -> void:
	var shown: String = Options.display(_content(), &"item", "erva_teste")
	assert_true(shown.begins_with("erva_teste - "), shown)
	assert_eq(Options.display(_content(), &"item", "nao_existe"), "nao_existe")

func _speaker(id: StringName, display: String, expressions: Array[StringName]) -> SpeakerDef:
	var s := SpeakerDef.new()
	s.id = id
	s.display_name = display
	s.sprites = SpriteSet.new()
	for e: StringName in expressions:
		s.sprites.portraits[e] = PlaceholderTexture2D.new()
	return s

func test_speakers_are_hero_names_plus_speaker_defs_without_repeats() -> void:
	var heroes: Array[CharacterDef] = Options.hero_defs(_content())
	assert_false(heroes.is_empty())
	var defs: Array[SpeakerDef] = [_speaker(&"morador_x", "Morador X", [&"neutro"]), _speaker(&"sem_nome", "", [])]
	defs.append(_speaker(&"dup", heroes[0].display_name, []))
	var names: Array[String] = Options.speakers(heroes, defs)
	assert_true(names.has(heroes[0].display_name))
	assert_true(names.has("Morador X"))
	assert_true(names.has("sem_nome"), "sem nome mostra o id")
	assert_eq(names.count(heroes[0].display_name), 1)

func test_expressions_of_a_speaker_are_its_portrait_keys_with_neutral_first() -> void:
	var defs: Array[SpeakerDef] = [_speaker(&"morador_x", "Morador X", [&"feliz", &"triste", &"neutro"])]
	var none: Array[CharacterDef] = []
	assert_eq(Options.expressions("Morador X", none, defs), ["neutro", "feliz", "triste"] as Array[String])
	assert_eq(Options.expressions("Outro", none, defs), [] as Array[String])
	assert_eq(Options.expressions("", none, defs), [] as Array[String])

func test_flags_merge_declared_and_used_across_documents() -> void:
	var a: RoteiroDoc = _doc("@flag declarada\n=== e\n@set usada 1\n? outra >= 1 -> fim\n")
	var b: RoteiroDoc = _doc("=== f\n@add usada 2\n@add so_em_b 1\n")
	assert_eq(Options.flags([a, b]), ["declarada", "outra", "so_em_b", "usada"] as Array[String])
	assert_eq(Options.flags([]), [] as Array[String])

func test_project_flags_include_missao_estado() -> void:
	var docs: Array[RoteiroDoc] = Logic.load_docs(BOOKS)
	assert_eq(docs.size(), 3)
	assert_true(Options.flags(docs).has("missao_estado"))

func test_labels_of_an_event_end_with_fim() -> void:
	var e: RoteiroEvent = _cidade().find_event("morador_c")
	assert_eq(Options.labels(e), ["ativa", "entrega", "inicio", "aceita", "recusa", "fim"] as Array[String])
	assert_eq(Options.labels(null), ["fim"] as Array[String])

func test_ops() -> void:
	assert_eq(Options.ops(), ["==", "!=", ">=", "<=", ">", "<"] as Array[String])

# --- campos por tipo ---

## Valor de exemplo por tipo de controle, que sobrevive à ida e volta pelo texto.
func _sample(spec: Dictionary) -> Variant:
	match str(spec["type"]):
		"speaker": return "Ana"
		"expr": return "feliz"
		"line", "multiline", "raw": return "Um texto"
		"flag": return "uma_flag"
		"item": return "erva_teste"
		"equip": return "capacete_teste_b_f"
		"hero": return "teste_a_f"
		"ability": return "chama_f"
		"encounter": return "enc_f1"
		"label", "newlabel": return "alvo"
		"op": return ">="
		"int": return 7
		"pct": return 40
		"float": return 1.5
		"bool": return true
		"text": return "Algo"
	return null

func test_every_editable_kind_has_known_field_types_and_real_properties() -> void:
	var known: Array[String] = ["speaker", "expr", "line", "multiline", "flag", "item", "equip", "hero", "ability",
			"encounter", "label", "newlabel", "op", "int", "float", "pct", "bool", "options", "text", "raw"]
	for k: int in RoteiroBlock.Kind.values():
		var b: RoteiroBlock = RoteiroBlock.make(k)
		for f: Dictionary in Logic.fields(k):
			assert_true(known.has(str(f["type"])), "tipo de campo %s" % f["type"])
			assert_true(f["name"] in b, "%s tem a propriedade %s" % [Logic.title(k), f["name"]])
	assert_true(Logic.fields(Kind.EM_BRANCO).is_empty())
	assert_true(Logic.fields(Kind.FIM_DEMO).is_empty())
	assert_ne(Logic.title(Kind.FALA), "?")

func test_field_values_survive_the_text_round_trip_for_every_kind() -> void:
	for k: int in RoteiroBlock.Kind.values():
		if k == Kind.OUTRO or k == Kind.EM_BRANCO or k == Kind.COMENTARIO:
			continue
		var b: RoteiroBlock = Logic.new_block(k)
		for f: Dictionary in Logic.fields(k):
			if f["type"] != "options":
				Logic.set_field(b, f["name"], _sample(f))
		if k == Kind.ESCOLHA:
			Logic.set_option(b, 0, "Sim", "alvo")
			Logic.set_option(b, 1, "Não", "fim")
		var doc := RoteiroDoc.new()
		var e: RoteiroEvent = doc.add_event("t")
		e.add_block(b)
		var back: RoteiroDoc = _doc(RoteiroDoc.to_text(doc))
		var bb: RoteiroBlock = back.events[0].blocks[0]
		assert_true(bb.equals(b), "%s volta igual do texto" % Logic.title(k))
		for f: Dictionary in Logic.fields(k):
			if f["type"] != "options":
				assert_eq(Logic.get_field(bb, f["name"]), Logic.get_field(b, f["name"]), "%s.%s" % [Logic.title(k), f["name"]])

func test_set_field_clamps_to_the_field_limits_and_converts_ids() -> void:
	var item: RoteiroBlock = Logic.new_block(Kind.DAR_ITEM)
	Logic.set_field(item, "amount", -4)
	assert_eq(item.amount, 1, "quantidade mínima 1")
	Logic.set_field(item, "ref", " erva_teste ")
	assert_eq(item.ref, &"erva_teste")
	var heal: RoteiroBlock = Logic.new_block(Kind.CURAR)
	Logic.set_field(heal, "pct", 400)
	assert_eq(heal.pct, 100)
	Logic.set_field(heal, "pct", 0)
	assert_eq(heal.pct, 1)
	var comment: RoteiroBlock = Logic.new_block(Kind.COMENTARIO)
	Logic.set_field(comment, "text", "a\nb")
	assert_eq(comment.text, "a b", "comentário é de uma linha")
	Logic.set_field(comment, "inexistente", 1)
	assert_eq(comment.text, "a b")

func test_new_blocks_have_the_kind_defaults() -> void:
	assert_eq(Logic.new_block(Kind.DAR_ITEM).amount, 1)
	assert_eq(Logic.new_block(Kind.SE_FLAG).op, "==")
	assert_eq(Logic.new_block(Kind.ESCOLHA).options.size(), 2)
	assert_eq(Logic.new_block(Kind.CURAR).pct, 100)

func test_the_add_menu_covers_every_editable_kind_once() -> void:
	var seen: Array[int] = []
	for c: Dictionary in Logic.CATEGORIES:
		for k: int in c["kinds"]:
			assert_false(seen.has(k), "tipo repetido no menu")
			seen.append(k)
	for k: int in RoteiroBlock.Kind.values():
		if k != Kind.OUTRO and k != Kind.EM_BRANCO:
			assert_true(seen.has(k), "%s está no menu" % Logic.title(k))

# --- opções de escolha ---

func test_a_choice_keeps_at_least_one_option_and_at_most_four() -> void:
	var c: RoteiroBlock = Logic.new_block(Kind.ESCOLHA)
	assert_true(Logic.remove_option(c, 1))
	assert_eq(c.options.size(), 1)
	assert_false(Logic.remove_option(c, 0), "a última opção fica")
	assert_eq(c.options.size(), 1)
	assert_false(Logic.remove_option(c, 5))
	for i: int in 3:
		assert_true(Logic.add_option(c))
	assert_eq(c.options.size(), 4)
	assert_false(Logic.add_option(c), "no máximo 4")
	Logic.set_option(c, 2, "Talvez", "depois")
	assert_eq(c.options[2].text, "Talvez")
	assert_eq(c.options[2].label, &"depois")

# --- edições em lista ---

func test_insert_remove_duplicate_and_move_visible() -> void:
	var doc: RoteiroDoc = _doc("=== e\nA: um\n\nA: dois\nA: três\n")
	var blocks: Array[RoteiroBlock] = doc.events[0].blocks
	assert_eq(blocks.size(), 4, "a linha em branco é um bloco escondido")
	assert_eq(Logic.visible(blocks), [0, 2, 3] as Array[int])
	var moved: int = Logic.move_visible(blocks, 2, -1)
	assert_eq(moved, 0, "sobe por cima do vizinho visível")
	assert_eq(blocks[0].text, "dois")
	assert_eq(Logic.move_visible(blocks, 0, -1), -1, "no topo não sobe")
	assert_eq(Logic.move_visible(blocks, 3, 1), -1, "no fim não desce")
	var dup: RoteiroBlock = Logic.duplicate_at(blocks, 0)
	assert_eq(dup.text, "dois")
	assert_eq(blocks[1].text, "dois")
	assert_ne(dup, blocks[0])
	var at: int = Logic.insert_after(blocks, 1, Logic.new_block(Kind.SISTEMA))
	assert_eq(at, 2)
	assert_eq(Logic.insert_after(blocks, -1, Logic.new_block(Kind.SISTEMA)), blocks.size() - 1)
	Logic.remove_at(blocks, 0)
	assert_eq(blocks[0].text, "dois")

func test_leading_comments_edit_as_text() -> void:
	var doc: RoteiroDoc = _doc("# a\n# b\n=== e\nX: oi\n")
	var e: RoteiroEvent = doc.events[0]
	assert_eq(Logic.leading_text(e), "a\nb")
	Logic.set_leading_text(e, "novo\nsegundo")
	assert_true(RoteiroDoc.to_text(doc).contains("# novo\n# segundo\n=== e\n"))
	Logic.set_leading_text(e, "  ")
	assert_eq(e.leading.size(), 0)

func test_unknown_lines_show_as_raw_and_convert_to_comments() -> void:
	var doc: RoteiroDoc = _doc("=== e\nX: oi\n@coisa estranha\n")
	var raw: RoteiroBlock = doc.events[0].blocks[1]
	assert_eq(raw.kind, Kind.OUTRO)
	assert_eq(_errors(doc).size(), 1)
	Logic.convert_to_comment(raw)
	assert_eq(raw.kind, Kind.COMENTARIO)
	assert_eq(raw.text, "@coisa estranha")
	assert_eq(_errors(doc).size(), 0, "virou comentário e o erro sumiu")

# --- linha -> bloco ---

func test_line_map_matches_the_generated_text_for_the_slice_files() -> void:
	for path: String in BOOKS:
		var doc: RoteiroDoc = _doc(_read(path))
		var lines: PackedStringArray = RoteiroDoc.to_text(doc).split("\n")
		var covered: int = 0
		for m: Dictionary in Logic.line_map(doc):
			var want: PackedStringArray
			var e: RoteiroEvent = null if int(m["event"]) < 0 else doc.events[int(m["event"])]
			match m["zone"]:
				&"items": want = RoteiroDoc.block_lines(doc.items[int(m["index"])])
				&"leading": want = RoteiroDoc.block_lines(e.leading[int(m["index"])])
				&"blocks": want = RoteiroDoc.block_lines(e.blocks[int(m["index"])])
				_: want = PackedStringArray(["=== " + e.id])
			var got: PackedStringArray = lines.slice(int(m["start"]) - 1, int(m["end"]))
			assert_eq(got, want, "%s linhas %d-%d" % [path.get_file(), m["start"], m["end"]])
			covered += got.size()
		var non_blank: int = 0
		for l: String in lines:
			if l != "":
				non_blank += 1
		assert_eq(covered, non_blank, "todas as linhas de texto têm bloco (%s)" % path.get_file())

func test_locate_finds_the_block_of_a_line() -> void:
	var doc: RoteiroDoc = _doc("@flag f\n\n# lead\n=== e\nX: um\n== r\n-> fim\n")
	assert_eq(Logic.locate(doc, 1)["zone"], &"items")
	assert_eq(Logic.locate(doc, 3)["zone"], &"leading")
	assert_eq(Logic.locate(doc, 4)["zone"], &"header")
	var m: Dictionary = Logic.locate(doc, 6)
	assert_eq(m["zone"], &"blocks")
	assert_eq(m["index"], 1)
	assert_eq(Logic.locate(doc, 99), {})

func test_an_error_line_maps_to_its_block() -> void:
	var doc: RoteiroDoc = _cidade()
	var e: RoteiroEvent = doc.find_event("morador_c")
	var target: int = -1
	for i: int in e.blocks.size():
		if e.blocks[i].kind == Kind.SE_ITEM:
			target = i
	assert_gt(target, -1)
	assert_eq(_errors(doc).size(), 0, "o arquivo da fatia compila sem erros")
	e.blocks[target].ref = &"item_que_nao_existe"
	var errs: Array[Dictionary] = _errors(doc)
	assert_eq(errs.size(), 1)
	var loc: Dictionary = errs[0]["loc"]
	assert_eq(loc["zone"], &"blocks")
	assert_eq(doc.events[int(loc["event"])].id, "morador_c")
	assert_eq(loc["index"], target, "o erro cai no bloco editado")
	assert_true(str(errs[0]["message"]).contains("item_que_nao_existe"))

func test_warnings_are_reported_with_their_block_too() -> void:
	var doc: RoteiroDoc = _doc("=== e\n@set sem_declarar 1\n")
	var found: Array[Dictionary] = Logic.diagnostics(doc, "t.roteiro", _content())
	assert_eq(found.size(), 1)
	assert_eq(found[0]["severity"], "aviso")
	assert_eq(found[0]["loc"]["index"], 0)

# --- editar pelos helpers e compilar ---

func test_a_doc_built_with_the_helpers_compiles_cleanly() -> void:
	var doc := RoteiroDoc.new()
	var e: RoteiroEvent = doc.add_event(Logic.unused_event_id(doc))
	assert_not_null(e)
	var decl: RoteiroBlock = Logic.new_block(Kind.DECLARAR_FLAG)
	Logic.set_field(decl, "ref", "visto")
	Logic.insert_after(doc.items, -1, decl)
	var say: RoteiroBlock = Logic.new_block(Kind.FALA)
	Logic.set_field(say, "speaker", "Ana")
	Logic.set_field(say, "text", "Olá!\nTudo bem?")
	Logic.insert_after(e.blocks, -1, say)
	var ask: RoteiroBlock = Logic.new_block(Kind.ESCOLHA)
	Logic.set_field(ask, "text", "Aceita?")
	Logic.set_option(ask, 0, "Sim", "sim")
	Logic.set_option(ask, 1, "Não", "fim")
	Logic.insert_after(e.blocks, -1, ask)
	var label: RoteiroBlock = Logic.new_block(Kind.ROTULO)
	Logic.set_field(label, "target", "sim")
	Logic.insert_after(e.blocks, -1, label)
	var set_flag: RoteiroBlock = Logic.new_block(Kind.DEFINIR_FLAG)
	Logic.set_field(set_flag, "ref", "visto")
	Logic.set_field(set_flag, "amount", 1)
	Logic.insert_after(e.blocks, -1, set_flag)
	var give: RoteiroBlock = Logic.new_block(Kind.DAR_ITEM)
	Logic.set_field(give, "ref", "erva_teste")
	Logic.set_field(give, "amount", 2)
	Logic.insert_after(e.blocks, -1, give)
	assert_eq(Logic.diagnostics(doc, "t.roteiro", _content()), [] as Array[Dictionary])
	var r: Dictionary = RoteiroTools.compile_text(RoteiroDoc.to_text(doc), "t.roteiro", _content())
	assert_true((r["events"] as Dictionary).has(&"novo_evento"))
	var sim: Dictionary = EventSimulator.simulate((r["events"] as Dictionary)[&"novo_evento"] as EventScript,
			{"answers": [0], "items": {}, "index": _content()})
	assert_eq(sim["items"]["erva_teste"], 2)
	assert_eq(sim["flags"]["visto"], 1)

func test_unused_event_id_skips_the_ones_in_use() -> void:
	var doc: RoteiroDoc = _doc("=== novo_evento\n=== novo_evento_2\n")
	assert_eq(Logic.unused_event_id(doc), "novo_evento_3")
	assert_eq(Logic.unused_event_id(RoteiroDoc.new()), "novo_evento")

func test_renaming_an_event_changes_only_its_header_line() -> void:
	var doc: RoteiroDoc = _cidade()
	var before: PackedStringArray = RoteiroDoc.to_text(doc).split("\n")
	assert_true(doc.rename_event("morador_d", "morador_dd"))
	var after: PackedStringArray = RoteiroDoc.to_text(doc).split("\n")
	assert_eq(after.size(), before.size())
	var changed: int = 0
	for i: int in before.size():
		if before[i] != after[i]:
			changed += 1
			assert_eq(before[i], "=== morador_d")
			assert_eq(after[i], "=== morador_dd")
	assert_eq(changed, 1)
	assert_false(doc.rename_event("morador_a", "morador_b"), "id já em uso")
	assert_false(doc.rename_event("morador_a", "com espaco"), "id inválido")
	assert_eq(_errors(doc).size(), 0)

func test_removing_an_event_removes_only_its_lines() -> void:
	var doc: RoteiroDoc = _cidade()
	var others: Array[String] = []
	for e: RoteiroEvent in doc.events:
		if e.id != "morador_e":
			others.append(e.id)
	assert_true(doc.remove_event("morador_e"))
	var back: RoteiroDoc = _doc(RoteiroDoc.to_text(doc))
	var ids: Array[String] = []
	for e: RoteiroEvent in back.events:
		ids.append(e.id)
	assert_eq(ids, others)

# --- sessão: dirty e salvar ---

func test_opening_and_saving_without_edits_keeps_every_slice_file_byte_identical() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	for path: String in BOOKS:
		var copy: String = TMP.path_join(path.get_file())
		var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
		var f: FileAccess = FileAccess.open(copy, FileAccess.WRITE)
		f.store_buffer(original)
		f.close()
		var s: Variant = Logic.Session.open(copy)
		assert_not_null(s)
		var session: Logic.Session = s
		assert_false(session.dirty(), "recém-aberto não está sujo (%s)" % path.get_file())
		assert_eq(session.save(), OK)
		assert_eq(FileAccess.get_file_as_bytes(copy), original, "bytes iguais em %s" % path.get_file())

func test_the_original_morador_c_text_is_what_the_session_writes() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var path: String = TMP.path_join("cidade.roteiro")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(_read(BOOKS[0]))
	f.close()
	var session: Logic.Session = Logic.Session.open(path)
	assert_eq(session.text(), _read(BOOKS[0]))
	assert_false(session.text().contains("\r"), "LF, sem CR")

func test_dirty_follows_edits_saves_and_reverts() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var path: String = TMP.path_join("t.roteiro")
	var session: Logic.Session = Logic.Session.from_text(path, "=== e\nAna: oi\n")
	assert_false(session.dirty())
	session.doc.events[0].blocks[0].text = "olá"
	assert_true(session.dirty())
	session.doc.events[0].blocks[0].text = "oi"
	assert_false(session.dirty(), "voltar ao mesmo texto limpa o aviso")
	session.doc.events[0].blocks[0].text = "tchau"
	assert_eq(session.save(), OK)
	assert_false(session.dirty())
	assert_eq(_read(path), "=== e\nAna: tchau\n")
	session.doc.add_event("outro")
	assert_true(session.dirty())
	session.revert()
	assert_false(session.dirty())
	assert_eq(session.doc.events.size(), 1)

func test_a_non_canonical_file_is_not_dirty_until_edited_and_is_rewritten_canonical() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	var path: String = TMP.path_join("n.roteiro")
	var session: Logic.Session = Logic.Session.from_text(path, "\n\n=== e\r\n\r\n\r\nAna:   oi\r\n\r\n")
	assert_false(session.dirty())
	assert_eq(session.save(), OK)
	assert_eq(_read(path), "=== e\nAna: oi\n")

func test_open_of_a_missing_file_is_null_and_save_to_a_bad_path_fails() -> void:
	assert_null(Logic.Session.open("user://test_roteiro_editor/nao_existe.roteiro"))
	var session: Logic.Session = Logic.Session.from_text("user://pasta_que_nao_existe_xyz/a.roteiro", "=== e\n")
	session.doc.add_event("b")
	assert_ne(session.save(), OK)
	assert_true(session.dirty(), "falhou: continua sujo")

# --- falante e expressão livres (M17) ---

func test_speaker_and_expression_lose_the_characters_that_change_the_line() -> void:
	var say: RoteiroBlock = Logic.new_block(Kind.FALA)
	Logic.set_field(say, "speaker", "Dr: Silva")
	assert_eq(say.speaker, "Dr Silva")
	Logic.set_field(say, "expr", " [feliz]\n ")
	assert_eq(say.expr, "feliz")
	Logic.set_field(say, "speaker", "A[b]\nc ")
	assert_eq(say.speaker, "Abc")

func test_speaker_starting_with_a_reserved_character_is_rejected_and_keeps_the_old_value() -> void:
	var say: RoteiroBlock = Logic.new_block(Kind.FALA)
	Logic.set_field(say, "speaker", "Ana")
	for bad: String in ["*Voz*", "#x", "@x", "?x", "|x", "=x", "-x", " [*Voz]"]:
		assert_ne(Logic.field_error(say, "speaker", bad), "", bad)
		Logic.set_field(say, "speaker", bad)
		assert_eq(say.speaker, "Ana", bad)
	assert_eq(Logic.field_error(say, "speaker", "Dr: Silva"), "")
	assert_eq(Logic.field_error(say, "speaker", ""), "")
	assert_eq(Logic.field_error(say, "text", "*qualquer coisa"), "")

func test_sanitized_speech_round_trips_through_the_text() -> void:
	var doc: RoteiroDoc = _doc("=== e\nAna: oi\n")
	var say: RoteiroBlock = doc.events[0].blocks[0]
	Logic.set_field(say, "speaker", "Dr: Silva")
	Logic.set_field(say, "expr", "[neutro]")
	var text: String = RoteiroDoc.to_text(doc)
	var back: RoteiroBlock = _doc(text).events[0].blocks[0]
	assert_eq(back.kind, Kind.FALA)
	assert_eq(back.speaker, "Dr Silva")
	assert_eq(back.expr, "neutro")
	assert_eq(RoteiroDoc.to_text(_doc(text)), text, "estável")

func test_option_text_is_one_trimmed_line_and_round_trips() -> void:
	var doc: RoteiroDoc = _doc("=== e\nAna: e então?\n* sim -> fim\n")
	var choice: RoteiroBlock = doc.events[0].blocks[0]
	Logic.set_option(choice, 0, "  -> # @ ?\nvamos  ", "fim")
	assert_eq(choice.options[0].text, "-> # @ ? vamos")
	var back: RoteiroBlock = _doc(RoteiroDoc.to_text(doc)).events[0].blocks[0]
	assert_eq(back.kind, Kind.ESCOLHA)
	assert_eq(back.options[0].text, "-> # @ ? vamos")

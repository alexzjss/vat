extends GutTest

## Modelo em blocos do roteiro (M17): ida e volta `parse` -> `to_text` -> `parse`, idempotência do texto canônico,
## comentários e linhas em branco, linhas desconhecidas, e o texto canônico dos 3 `.roteiro` da fatia compilando
## igual ao arquivo original.

const Migration: GDScript = preload("res://tests/test_roteiro_migration.gd")
const Kind = RoteiroBlock.Kind
const BOOKS: Array[String] = [
	"res://data/fatia/roteiro/cidade.roteiro",
	"res://data/fatia/roteiro/casas.roteiro",
	"res://data/fatia/roteiro/dungeon.roteiro",
]

## Todos os tipos de bloco, com ids reais da fatia, para compilar sem erro.
const SAMPLE: String = """# Cabeçalho do arquivo
@flag chave
@flag outra

# Comentário colado no evento
=== tudo
Morador A [neutro]: Olá, tudo bem? Isso -> não é um salto: tem ':' e 'ç'.
: Aviso do sistema.
Morador E: Primeira linha.
| Segunda linha.
|
| Quarta linha, depois de uma em branco.
# comentário no meio
: Pergunta, certo?
* Sim -> sim
* Não -> nao
== sim
? chave == 0 -> nao
? chave != -3 -> nao
? chave >= 1 -> nao
? chave <= 2 -> nao
? chave > 3 -> nao
? chave < 4 -> nao
? item erva_teste -> nao
? item erva_teste 3 -> nao
? dinheiro >= 50 -> nao
? dinheiro == 0 -> nao
@set chave 1
@add chave -2
@flag naoa
@give item erva_teste
@give item erva_teste 4
@give equip capacete_teste_b_f
@give equip capacete_teste_b_f 2
@give moedas 40
@take item erva_teste
@take item erva_teste 2
@xp 120
@xp 30 todos
@ensinar teste_d_f chama_f
@curar
@curar 50%
@recrutar teste_d_f
@recrutar teste_d_f nivel 5
@batalha enc_f1
@mover Player Spot
@mover Player Spot 1.5
@camera BossSpot
@esperar 0.6
@esperar 2
-> fim
== nao

Teste D [feliz]: Depois da linha em branco.
@fim_demo
"""

# --- utilidades ---

static var _index: ContentIndex

static func _content() -> ContentIndex:
	if _index == null:
		_index = RoteiroTools.scan_content()
	return _index

func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(f, path)
	return f.get_as_text()

## parse -> to_text -> parse: o modelo é igual e o texto não muda mais. Devolve o texto canônico.
func _round_trip(text: String, label: String = "") -> String:
	var a: Dictionary = RoteiroDoc.parse(text)
	var doc_a: RoteiroDoc = a["doc"]
	var canon: String = RoteiroDoc.to_text(doc_a)
	var b: Dictionary = RoteiroDoc.parse(canon)
	var doc_b: RoteiroDoc = b["doc"]
	assert_true(doc_a.equals(doc_b), "modelos iguais depois da volta %s" % label)
	assert_eq(RoteiroDoc.to_text(doc_b), canon, "to_text idempotente %s" % label)
	assert_eq(b["errors"].size(), a["errors"].size(), "mesmos erros %s" % label)
	return canon

func _blocks_of(text: String) -> Array[RoteiroBlock]:
	var doc: RoteiroDoc = RoteiroDoc.parse(text)["doc"]
	return doc.events[0].blocks

func _kinds(blocks: Array[RoteiroBlock]) -> Array:
	var out: Array = []
	for b: RoteiroBlock in blocks:
		out.append(b.kind)
	return out

func _compiled_desc(text: String) -> Dictionary:
	var r: Dictionary = RoteiroCompiler.compile(text, "x.roteiro", _content().resolver())
	var out: Dictionary = {"errors": r["errors"], "warnings": r["warnings"], "events": {}}
	var evs: Dictionary = r["events"]
	for id: StringName in evs:
		out["events"][id] = Migration.describe_all(evs[id] as EventScript)
	return out

# --- cada tipo de bloco ---

func test_sample_parses_without_errors_and_covers_every_kind() -> void:
	var r: Dictionary = RoteiroDoc.parse(SAMPLE)
	assert_eq(r["errors"], [] as Array[String])
	var doc: RoteiroDoc = r["doc"]
	var seen: Dictionary = {}
	for b: RoteiroBlock in doc.items:
		seen[b.kind] = true
	for e: RoteiroEvent in doc.events:
		for b: RoteiroBlock in e.blocks:
			seen[b.kind] = true
	for k: int in RoteiroBlock.Kind.values():
		if k != RoteiroBlock.Kind.OUTRO:
			assert_true(seen.has(k), "tipo %s no exemplo" % RoteiroBlock.Kind.keys()[k])

func test_sample_round_trips_and_is_idempotent() -> void:
	_round_trip(SAMPLE)

func test_sample_compiles_the_same_after_the_round_trip() -> void:
	var canon: String = _round_trip(SAMPLE)
	var want: Dictionary = _compiled_desc(SAMPLE)
	assert_eq(want["errors"], [] as Array[String], "o exemplo compila")
	assert_eq(_compiled_desc(canon), want)

func test_fields_of_each_kind() -> void:
	var b: Array[RoteiroBlock] = _blocks_of(SAMPLE)
	var fala: RoteiroBlock = b[0]
	assert_eq(fala.kind, Kind.FALA)
	assert_eq([fala.speaker, fala.expr], ["Morador A", "neutro"])
	assert_eq(fala.text, "Olá, tudo bem? Isso -> não é um salto: tem ':' e 'ç'.")
	assert_eq(b[1].kind, Kind.SISTEMA)
	var multi: RoteiroBlock = b[2]
	assert_eq(multi.text, "Primeira linha.\nSegunda linha.\n\nQuarta linha, depois de uma em branco.")
	assert_eq(b[3].kind, Kind.COMENTARIO)
	assert_eq(b[3].text, "comentário no meio")
	var esc: RoteiroBlock = b[4]
	assert_eq(esc.kind, Kind.ESCOLHA)
	assert_eq(esc.text, "Pergunta, certo?")
	assert_eq(esc.options.size(), 2)
	assert_eq([esc.options[1].text, esc.options[1].label], ["Não", &"nao"])
	assert_eq(b[5].kind, Kind.ROTULO)
	assert_eq(b[5].target, &"sim")
	var sf: RoteiroBlock = b[7]
	assert_eq([sf.kind, sf.ref, sf.op, sf.amount, sf.target], [Kind.SE_FLAG, &"chave", "!=", -3, &"nao"])
	var si: RoteiroBlock = b[12]
	assert_eq([si.kind, si.ref, si.amount], [Kind.SE_ITEM, &"erva_teste", 1])
	assert_eq(b[13].amount, 3)
	var sd: RoteiroBlock = b[14]
	assert_eq([sd.kind, sd.op, sd.amount], [Kind.SE_DINHEIRO, ">=", 50])

func test_command_fields() -> void:
	var by_kind: Dictionary = {}
	for blk: RoteiroBlock in _blocks_of(SAMPLE):
		if not by_kind.has(blk.kind):
			by_kind[blk.kind] = []
		(by_kind[blk.kind] as Array).append(blk)
	assert_eq([by_kind[Kind.DEFINIR_FLAG][0].ref, by_kind[Kind.DEFINIR_FLAG][0].amount], [&"chave", 1])
	assert_eq(by_kind[Kind.SOMAR_FLAG][0].amount, -2)
	assert_eq(by_kind[Kind.DECLARAR_FLAG][0].ref, &"naoa")
	assert_eq([by_kind[Kind.DAR_ITEM][1].ref, by_kind[Kind.DAR_ITEM][1].amount], [&"erva_teste", 4])
	assert_eq(by_kind[Kind.DAR_EQUIP][1].amount, 2)
	assert_eq(by_kind[Kind.DAR_MOEDAS][0].amount, 40)
	assert_eq(by_kind[Kind.TIRAR_ITEM][1].amount, 2)
	assert_false(by_kind[Kind.XP][0].everyone)
	assert_true(by_kind[Kind.XP][1].everyone)
	assert_eq([by_kind[Kind.ENSINAR][0].ref, by_kind[Kind.ENSINAR][0].ref2], [&"teste_d_f", &"chama_f"])
	assert_eq([by_kind[Kind.CURAR][0].pct, by_kind[Kind.CURAR][1].pct], [100, 50])
	assert_eq([by_kind[Kind.RECRUTAR][0].amount, by_kind[Kind.RECRUTAR][1].amount], [0, 5])
	assert_eq(by_kind[Kind.BATALHA][0].ref, &"enc_f1")
	assert_eq([by_kind[Kind.MOVER][1].ref, by_kind[Kind.MOVER][1].ref2, by_kind[Kind.MOVER][1].seconds], [&"Player", &"Spot", 1.5])
	assert_eq(by_kind[Kind.CAMERA][0].ref, &"BossSpot")
	assert_eq([by_kind[Kind.ESPERAR][0].seconds, by_kind[Kind.ESPERAR][1].seconds], [0.6, 2.0])
	assert_eq(by_kind[Kind.FIM_DEMO].size(), 1)

func test_canonical_lines_of_each_kind() -> void:
	var canon: String = _round_trip(SAMPLE)
	for want: String in [
		"@curar\n", "@curar 50%\n", "@give item erva_teste\n", "@give item erva_teste 4\n", "@xp 120\n", "@xp 30 todos\n",
		"@recrutar teste_d_f\n", "@recrutar teste_d_f nivel 5\n", "@mover Player Spot\n", "@mover Player Spot 1.5\n",
		"@esperar 0.6\n", "@esperar 2\n", "? item erva_teste -> nao\n", "? item erva_teste 3 -> nao\n",
		"* Sim -> sim\n", "* Não -> nao\n", "|\n", "| Segunda linha.\n",
	]:
		assert_true(canon.contains(want), "canônico tem %s" % want.strip_edges())

func test_non_canonical_spellings_normalize_to_the_same_model() -> void:
	var loose: String = "=== e\n  ?   flag   ==   +1   ->   r  \n@curar 100%\n@give item erva_teste 1\n@esperar 0,6\n@xp 5 ativos\n== r\n@mover Player Spot 0\n"
	var tight: String = "=== e\n? flag == 1 -> r\n@curar\n@give item erva_teste\n@esperar 0.6\n@xp 5\n== r\n@mover Player Spot\n"
	var a: RoteiroDoc = RoteiroDoc.parse(loose)["doc"]
	var b: RoteiroDoc = RoteiroDoc.parse(tight)["doc"]
	assert_true(a.equals(b))
	assert_eq(RoteiroDoc.to_text(a), tight)

# --- texto ---

func test_accents_colon_and_arrow_in_text_survive() -> void:
	var t: String = "=== e\nNome [feliz]: Ação: não -> sim | talvez # ok? ã é í ô ü.\n: Placa: saída -> leste.\n"
	var canon: String = _round_trip(t)
	assert_eq(canon, t)
	var blocks: Array[RoteiroBlock] = _blocks_of(t)
	assert_eq(blocks[0].text, "Ação: não -> sim | talvez # ok? ã é í ô ü.")
	assert_eq(blocks[1].kind, Kind.SISTEMA)
	assert_eq(blocks[1].text, "Placa: saída -> leste.")

func test_multi_line_speech_with_pipes() -> void:
	var t: String = "=== e\nA: um\n| dois\n|\n| quatro\n: sistema\n| segunda do sistema\n"
	assert_eq(_round_trip(t), t)
	var blocks: Array[RoteiroBlock] = _blocks_of(t)
	assert_eq(blocks[0].text, "um\ndois\n\nquatro")
	assert_eq(blocks[1].text, "sistema\nsegunda do sistema")

func test_multi_line_question_of_a_choice() -> void:
	var t: String = "=== e\nA [x]: pergunta\n| continua?\n* Sim -> fim\n* Não -> fim\n"
	assert_eq(_round_trip(t), t)
	var c: RoteiroBlock = _blocks_of(t)[0]
	assert_eq(c.kind, Kind.ESCOLHA)
	assert_eq(c.text, "pergunta\ncontinua?")
	assert_eq([c.speaker, c.expr], ["A", "x"])

func test_option_text_keeps_arrows_before_the_last_one() -> void:
	var t: String = "=== e\n: Escolha?\n* a -> b -> fim\n"
	var c: RoteiroBlock = _blocks_of(t)[0]
	assert_eq(c.options[0].text, "a -> b")
	assert_eq(c.options[0].label, &"fim")
	assert_eq(_round_trip(t), t)

func test_four_options_are_accepted_and_a_fifth_is_an_error() -> void:
	var t: String = "=== e\n: Q?\n* a -> fim\n* b -> fim\n* c -> fim\n* d -> fim\n"
	assert_eq(RoteiroDoc.parse(t)["errors"], [] as Array[String])
	var r: Dictionary = RoteiroDoc.parse(t + "* e -> fim\n")
	assert_eq(r["errors"], ["7: escolha com mais de 4 opções"])
	var doc: RoteiroDoc = r["doc"]
	assert_eq(doc.events[0].blocks[0].options.size(), 4)
	assert_eq(doc.events[0].blocks[1].kind, Kind.OUTRO)

func test_bom_crlf_and_tabs_are_read_like_the_compiler() -> void:
	var t: String = "﻿=== e\r\n\tA:\ttexto\r\n@give moedas 3\r\n"
	var r: Dictionary = RoteiroDoc.parse(t)
	assert_eq(r["errors"], [] as Array[String])
	var canon: String = RoteiroDoc.to_text(r["doc"])
	assert_eq(canon, "=== e\nA: texto\n@give moedas 3\n")
	assert_false(canon.contains("\r"))

# --- comentários e linhas em branco ---

func test_comments_and_blank_lines_are_kept() -> void:
	var t: String = "# topo\n@flag f\n\n# do evento\n=== a\nX: oi\n\n# no meio\nX: tchau\n\n\n=== b\n# no começo de b\n: fim\n# final\n"
	var canon: String = _round_trip(t)
	assert_eq(canon, "# topo\n@flag f\n\n# do evento\n=== a\nX: oi\n\n# no meio\nX: tchau\n\n=== b\n# no começo de b\n: fim\n# final\n")
	var doc: RoteiroDoc = RoteiroDoc.parse(t)["doc"]
	assert_eq(doc.items.size(), 2)
	assert_eq(doc.events[0].leading.size(), 1)
	assert_eq(doc.events[0].leading[0].text, "do evento")
	assert_eq(_kinds(doc.events[0].blocks), [Kind.FALA, Kind.EM_BRANCO, Kind.COMENTARIO, Kind.FALA])
	assert_eq(doc.events[1].blocks[0].kind, Kind.COMENTARIO)
	assert_eq(doc.events[1].blocks[2].text, "final")

func test_comment_between_speech_and_continuation_or_options_keeps_the_meaning() -> void:
	var t: String = "=== e\nA: um\n# nota\n| dois\n: Q?\n# outra\n* s -> fim\n"
	var canon: String = _round_trip(t)
	var want: Dictionary = _compiled_desc("@flag x\n" + t)
	var got: Dictionary = _compiled_desc("@flag x\n" + canon)
	assert_eq(got, want)
	var blocks: Array[RoteiroBlock] = _blocks_of(t)
	assert_eq(blocks[0].text, "um\ndois")
	assert_eq(blocks[2].kind, Kind.ESCOLHA)

func test_a_hash_after_text_is_part_of_the_text() -> void:
	var t: String = "=== e\nA: veja #3\n"
	assert_eq(_blocks_of(t)[0].text, "veja #3")
	assert_eq(_round_trip(t), t)

func test_empty_text_and_blank_only_text() -> void:
	var doc: RoteiroDoc = RoteiroDoc.parse("")["doc"]
	assert_eq(RoteiroDoc.to_text(doc), "")
	assert_eq(RoteiroDoc.to_text(RoteiroDoc.parse("\n\n  \n")["doc"]), "")

func test_a_blank_line_precedes_every_event_and_the_text_ends_with_one_newline() -> void:
	var canon: String = RoteiroDoc.to_text(RoteiroDoc.parse("=== a\nX: 1\n=== b\nX: 2\n\n\n\n")["doc"])
	assert_eq(canon, "=== a\nX: 1\n\n=== b\nX: 2\n")

# --- linhas desconhecidas ---

func test_unknown_lines_survive_as_raw_blocks_with_the_compiler_errors() -> void:
	var t: String = "=== e\n@xyz 1 2\nsem dois pontos\n@give item\nNome:\nA [x: oi\n== a b\n->\n? flag ~ 1 -> fim\n@xp abc\n@esperar -1\n@curar 150\n| solta\n* solta -> fim\n@fim_demo extra\n"
	var r: Dictionary = RoteiroDoc.parse(t)
	var errs: Array = r["errors"]
	assert_eq(errs.size(), 14)
	assert_eq(errs[0], "2: comando desconhecido '@xyz'")
	assert_eq(errs[1], "3: linha não reconhecida (fala é 'Nome: texto')")
	assert_eq(errs[3], "5: fala vazia")
	assert_eq(errs[4], "6: colchete do retrato não foi fechado")
	assert_eq(errs[6], "8: nome de rótulo inválido ('')")
	assert_eq(errs[9], "11: número fora do intervalo (mínimo 0.0): '-1'")
	assert_eq(errs[10], "12: porcentagem de cura fora de 1 a 100: '150'")
	assert_eq(errs[11], "13: '|' continua uma fala, mas não há fala antes")
	assert_eq(errs[12], "14: opção '*' sem pergunta antes (use 'Nome: pergunta?')")
	var doc: RoteiroDoc = r["doc"]
	var raws: Array[String] = []
	for b: RoteiroBlock in doc.events[0].blocks:
		assert_eq(b.kind, Kind.OUTRO)
		raws.append(b.text)
	assert_eq(raws[0], "@xyz 1 2")
	assert_eq(raws.size(), 14)
	var canon: String = _round_trip(t)
	assert_eq(canon, t)

func test_errors_match_the_compiler_messages_line_by_line() -> void:
	# Mesmas linhas e mensagens do compilador (sem o nome do arquivo), para erros que não dependem de ids.
	var t: String = "linha solta\n@set x\n=== a b\n? x\n? item\n? dinheiro ~ 1 -> fim\n: Q?\n== r\n* sem seta\n"
	var mine: Array = RoteiroDoc.parse(t)["errors"]
	var theirs: Array = []
	for e: String in RoteiroCompiler.compile(t, "x", _content().resolver())["errors"]:
		theirs.append(e.substr(2))
	# O compilador também acusa semântica ('rótulo não existe', duplicados): só vale o que é sintático.
	for m: String in mine:
		assert_true(theirs.has(m), "o compilador também acusa: %s" % m)
	assert_gte(mine.size(), 7)

func test_a_choice_without_options_reports_the_question_line() -> void:
	var r: Dictionary = RoteiroDoc.parse("=== e\n: Q?\n* sem seta\n@fim_demo\n")
	assert_true((r["errors"] as Array).has("2: escolha sem opções"))
	assert_true((r["errors"] as Array).has("3: opção sem '-> rótulo'"))
	var t: String = "=== e\n: Q?\n* sem seta\n@fim_demo\n"
	assert_eq(_round_trip(t), t)

func test_event_id_with_space_is_reported_but_kept() -> void:
	var r: Dictionary = RoteiroDoc.parse("=== a b\nX: oi\n")
	assert_eq(r["errors"], ["1: id de evento inválido ('a b'): use uma palavra, sem espaços"])
	assert_eq(RoteiroDoc.to_text(r["doc"]), "=== a b\nX: oi\n")

func test_lines_before_the_first_event() -> void:
	var t: String = "@flag f\nfala solta: x\n@give moedas 1\n=== e\nX: oi\n"
	var r: Dictionary = RoteiroDoc.parse(t)
	assert_eq(r["errors"], ["2: linha fora de um evento (use '=== id' antes)", "3: linha fora de um evento (use '=== id' antes)"])
	assert_eq(RoteiroDoc.to_text(r["doc"]), "@flag f\nfala solta: x\n@give moedas 1\n\n=== e\nX: oi\n")
	_round_trip(t)

# --- as edições ---

func test_block_edit_helpers() -> void:
	var doc: RoteiroDoc = RoteiroDoc.parse("=== e\nA: 1\nA: 2\nA: 3\n")["doc"]
	var ev: RoteiroEvent = doc.events[0]
	var extra: RoteiroBlock = RoteiroBlock.make(Kind.DAR_MOEDAS)
	extra.amount = 5
	assert_eq(ev.add_block(extra), 3)
	assert_eq(ev.add_block(RoteiroBlock.make(Kind.FIM_DEMO), 0), 0)
	assert_eq(_kinds(ev.blocks), [Kind.FIM_DEMO, Kind.FALA, Kind.FALA, Kind.FALA, Kind.DAR_MOEDAS])
	assert_true(ev.move_block(0, 4))
	assert_eq(ev.blocks[4].kind, Kind.FIM_DEMO)
	assert_eq(ev.blocks[3].kind, Kind.DAR_MOEDAS)
	assert_false(ev.move_block(9, 0))
	var copy: RoteiroBlock = ev.duplicate_block(0)
	assert_eq(ev.blocks.size(), 6)
	assert_true(copy.equals(ev.blocks[0]))
	assert_ne(copy, ev.blocks[0])
	copy.text = "mudou"
	assert_ne(ev.blocks[0].text, "mudou")
	ev.remove_block(0)
	ev.remove_block(0)
	ev.remove_block(99)
	assert_eq(ev.blocks.size(), 4)
	assert_eq(RoteiroDoc.to_text(doc), "=== e\nA: 2\nA: 3\n@give moedas 5\n@fim_demo\n")

func test_choice_copy_does_not_share_options() -> void:
	var doc: RoteiroDoc = RoteiroDoc.parse("=== e\n: Q?\n* a -> fim\n")["doc"]
	var ev: RoteiroEvent = doc.events[0]
	var c: RoteiroBlock = ev.duplicate_block(0)
	c.options[0].text = "outra"
	assert_eq(ev.blocks[0].options[0].text, "a")

func test_event_helpers() -> void:
	var doc: RoteiroDoc = RoteiroDoc.parse("=== a\n== um\n== dois\n-> fim\n=== b\nX: oi\n")["doc"]
	assert_eq(doc.find_event("a").labels(), [&"um", &"dois"] as Array[StringName])
	assert_null(doc.find_event("zzz"))
	assert_true(doc.rename_event("a", "alfa"))
	assert_null(doc.find_event("a"))
	assert_false(doc.rename_event("alfa", "b"), "id de outro evento")
	assert_false(doc.rename_event("alfa", "com espaço"))
	assert_false(doc.rename_event("alfa", ""))
	assert_false(doc.rename_event("nao_existe", "x"))
	assert_true(doc.rename_event("alfa", "alfa"))
	assert_not_null(doc.add_event("novo"))
	assert_null(doc.add_event("novo"), "repetido")
	assert_null(doc.add_event("a b"))
	assert_eq(RoteiroDoc.to_text(doc), "=== alfa\n== um\n== dois\n-> fim\n\n=== b\nX: oi\n\n=== novo\n")
	assert_true(doc.remove_event("novo"))
	assert_false(doc.remove_event("novo"))
	assert_eq(doc.events.size(), 2)

func test_flags_used_and_declared() -> void:
	var t: String = "@flag a\n@flag b\n=== e\n? a == 0 -> fim\n@set c 1\n@add a 1\n@flag d\n? item x -> fim\n=== f\n? c > 0 -> fim\n"
	var doc: RoteiroDoc = RoteiroDoc.parse(t)["doc"]
	assert_eq(doc.flags_used(), [&"a", &"c"] as Array[StringName])
	assert_eq(doc.flags_declared(), [&"a", &"b", &"d"] as Array[StringName])

func test_float_formatting_reparses_to_the_same_value() -> void:
	for v: float in [0.0, 0.5, 0.6, 1.5, 2.0, 0.25, 10.75, 3.0, 0.1]:
		var b: RoteiroBlock = RoteiroBlock.make(Kind.ESPERAR)
		b.seconds = v
		var doc := RoteiroDoc.new()
		var ev: RoteiroEvent = doc.add_event("e")
		ev.add_block(b)
		var back: RoteiroDoc = RoteiroDoc.parse(RoteiroDoc.to_text(doc))["doc"]
		assert_eq(back.events[0].blocks[0].seconds, v, "segundos %s" % v)

func test_blocks_built_by_code_serialize_and_reparse() -> void:
	var doc := RoteiroDoc.new()
	var ev: RoteiroEvent = doc.add_event("novo")
	var sf: RoteiroBlock = RoteiroBlock.make(Kind.SE_FLAG)
	sf.ref = &"missao"
	sf.op = ">="
	sf.amount = 2
	sf.target = &"fim"
	ev.add_block(sf)
	var esc: RoteiroBlock = RoteiroBlock.make(Kind.ESCOLHA)
	esc.text = "Vai?"
	esc.options.append(RoteiroBlock.Option.make("Sim", &"fim"))
	ev.add_block(esc)
	var text: String = RoteiroDoc.to_text(doc)
	assert_eq(text, "=== novo\n? missao >= 2 -> fim\n: Vai?\n* Sim -> fim\n")
	var r: Dictionary = RoteiroDoc.parse(text)
	assert_eq(r["errors"], [] as Array[String])
	assert_true(doc.equals(r["doc"]))

# --- os 3 arquivos da fatia ---

func test_slice_files_compile_the_same_through_the_model() -> void:
	for path: String in BOOKS:
		var text: String = _read(path)
		var r: Dictionary = RoteiroDoc.parse(text)
		assert_eq(r["errors"], [] as Array[String], path)
		var canon: String = _round_trip(text, path)
		var want: Dictionary = _compiled_desc(text)
		assert_eq(want["errors"], [] as Array[String], path)
		assert_eq((want["events"] as Dictionary).size() > 0, true, path)
		assert_eq(_compiled_desc(canon), want, "equivalente: %s" % path)

func test_slice_files_are_already_canonical() -> void:
	for path: String in BOOKS:
		var text: String = _read(path)
		assert_eq(RoteiroDoc.to_text(RoteiroDoc.parse(text)["doc"]), text, "canônico: %s" % path)
		assert_false(text.contains("\r"), "LF: %s" % path)

func test_slice_files_keep_their_comments() -> void:
	var cidade: RoteiroDoc = RoteiroDoc.parse(_read(BOOKS[0]))["doc"]
	assert_eq(cidade.items[0].kind, Kind.COMENTARIO)
	assert_eq(cidade.flags_declared(), [&"missao_estado"] as Array[StringName])
	var morador_c: RoteiroEvent = cidade.find_event("morador_c")
	assert_eq(morador_c.leading.size(), 1)
	assert_true(morador_c.leading[0].text.begins_with("Missão secundária"))
	assert_eq(morador_c.labels(), [&"ativa", &"entrega", &"inicio", &"aceita", &"recusa"] as Array[StringName])

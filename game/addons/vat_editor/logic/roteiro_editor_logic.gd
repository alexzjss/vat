@tool
extends RefCounted

## Cola testável entre a UI do editor de blocos e o modelo `RoteiroDoc` (M17): os campos de cada tipo de bloco, as
## edições nas listas de blocos, o mapa linha do texto -> bloco (para destacar o bloco de um erro), os achados do
## compilador e a sessão de um arquivo (dirty e salvar). Sem Node: só o IO de ler e gravar o `.roteiro` na `Session`.

const Roteiros: GDScript = preload("res://addons/vat_editor/logic/vat_roteiros.gd")
const Kind = RoteiroBlock.Kind

const MAX_OPTIONS: int = 4
const HEADER_EVENT: int = -1

## Menu "+ Adicionar bloco": categoria -> tipos.
const CATEGORIES: Array[Dictionary] = [
	{"label": "Texto", "kinds": [Kind.FALA, Kind.SISTEMA, Kind.COMENTARIO]},
	{"label": "Fluxo", "kinds": [Kind.ESCOLHA, Kind.ROTULO, Kind.IR_PARA]},
	{"label": "Condições", "kinds": [Kind.SE_FLAG, Kind.SE_ITEM, Kind.SE_DINHEIRO]},
	{"label": "Flags", "kinds": [Kind.DEFINIR_FLAG, Kind.SOMAR_FLAG, Kind.DECLARAR_FLAG]},
	{"label": "Itens e dinheiro", "kinds": [Kind.DAR_ITEM, Kind.DAR_EQUIP, Kind.DAR_MOEDAS, Kind.TIRAR_ITEM]},
	{"label": "Grupo", "kinds": [Kind.XP, Kind.ENSINAR, Kind.CURAR, Kind.RECRUTAR]},
	{"label": "Ações", "kinds": [Kind.BATALHA, Kind.MOVER, Kind.CAMERA, Kind.ESPERAR, Kind.FIM_DEMO]},
]

const TITLES: Dictionary = {
	Kind.FALA: "Fala", Kind.SISTEMA: "Sistema", Kind.COMENTARIO: "Comentário", Kind.ESCOLHA: "Escolha",
	Kind.ROTULO: "Rótulo", Kind.IR_PARA: "Ir para", Kind.SE_FLAG: "Se flag", Kind.SE_ITEM: "Se item",
	Kind.SE_DINHEIRO: "Se dinheiro", Kind.DEFINIR_FLAG: "Definir flag", Kind.SOMAR_FLAG: "Somar à flag",
	Kind.DECLARAR_FLAG: "Declarar flag", Kind.DAR_ITEM: "Dar item", Kind.DAR_EQUIP: "Dar equipamento",
	Kind.DAR_MOEDAS: "Dar moedas", Kind.TIRAR_ITEM: "Tirar item", Kind.XP: "XP", Kind.ENSINAR: "Ensinar técnica",
	Kind.CURAR: "Curar", Kind.RECRUTAR: "Recrutar", Kind.BATALHA: "Batalha", Kind.MOVER: "Mover",
	Kind.CAMERA: "Câmera", Kind.ESPERAR: "Esperar", Kind.FIM_DEMO: "Fim da demo", Kind.OUTRO: "Linha não entendida",
	Kind.EM_BRANCO: "Linha em branco",
}

static func title(kind: int) -> String:
	return str(TITLES.get(kind, "?"))

# --- campos por tipo ---------------------------------------------------------------------

static func _f(name: String, label: String, type: String, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"name": name, "label": label, "type": type}
	d.merge(extra)
	return d

## Os campos de um tipo de bloco, na ordem do cartão. `name` é a propriedade do `RoteiroBlock`; `type` diz o controle:
## speaker, expr, line (uma linha), multiline, flag (lista com digitação), item, equip, hero, ability, encounter (lista
## fechada), label (lista com digitação), newlabel (texto), op, int, float, pct, bool, options, text (texto livre) e raw.
static func fields(kind: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match kind:
		Kind.FALA:
			out = [_f("speaker", "Falante", "speaker"), _f("expr", "Expressão", "expr"), _f("text", "Texto", "multiline")]
		Kind.SISTEMA:
			out = [_f("text", "Texto", "multiline")]
		Kind.COMENTARIO:
			out = [_f("text", "Comentário", "line")]
		Kind.ESCOLHA:
			out = [_f("speaker", "Falante", "speaker"), _f("expr", "Expressão", "expr"),
					_f("text", "Pergunta", "multiline"), _f("options", "Opções", "options")]
		Kind.ROTULO:
			out = [_f("target", "Nome", "newlabel")]
		Kind.IR_PARA:
			out = [_f("target", "Rótulo", "label")]
		Kind.SE_FLAG:
			out = [_f("ref", "Flag", "flag"), _f("op", "É", "op"), _f("amount", "Valor", "int", {"min": -999999, "max": 999999}),
					_f("target", "Então ir para", "label")]
		Kind.SE_ITEM:
			out = [_f("ref", "Item", "item"), _f("amount", "Quantidade", "int", {"min": 1, "max": 999}),
					_f("target", "Se tiver, ir para", "label")]
		Kind.SE_DINHEIRO:
			out = [_f("op", "Moedas", "op"), _f("amount", "Valor", "int", {"min": 0, "max": 999999}),
					_f("target", "Então ir para", "label")]
		Kind.DEFINIR_FLAG:
			out = [_f("ref", "Flag", "flag"), _f("amount", "Valor", "int", {"min": -999999, "max": 999999})]
		Kind.SOMAR_FLAG:
			out = [_f("ref", "Flag", "flag"), _f("amount", "Somar", "int", {"min": -999999, "max": 999999})]
		Kind.DECLARAR_FLAG:
			out = [_f("ref", "Flag", "flag")]
		Kind.DAR_ITEM, Kind.TIRAR_ITEM:
			out = [_f("ref", "Item", "item"), _f("amount", "Quantidade", "int", {"min": 1, "max": 999})]
		Kind.DAR_EQUIP:
			out = [_f("ref", "Equipamento", "equip"), _f("amount", "Quantidade", "int", {"min": 1, "max": 999})]
		Kind.DAR_MOEDAS:
			out = [_f("amount", "Moedas", "int", {"min": 1, "max": 999999})]
		Kind.XP:
			out = [_f("amount", "XP", "int", {"min": 1, "max": 999999}), _f("everyone", "Para todos os recrutados", "bool")]
		Kind.ENSINAR:
			out = [_f("ref", "Herói", "hero"), _f("ref2", "Técnica", "ability")]
		Kind.CURAR:
			out = [_f("pct", "Cura (%)", "pct", {"min": 1, "max": 100})]
		Kind.RECRUTAR:
			out = [_f("ref", "Herói", "hero"), _f("amount", "Nível (0 = média do grupo)", "int", {"min": 0, "max": 99})]
		Kind.BATALHA:
			out = [_f("ref", "Encontro", "encounter")]
		Kind.MOVER:
			out = [_f("ref", "Ator", "text"), _f("ref2", "Marcador", "text"),
					_f("seconds", "Velocidade (0 = padrão)", "float", {"min": 0.0, "max": 9999.0, "step": 0.1})]
		Kind.CAMERA:
			out = [_f("ref", "Marcador", "text")]
		Kind.ESPERAR:
			out = [_f("seconds", "Segundos", "float", {"min": 0.0, "max": 9999.0, "step": 0.1})]
		Kind.OUTRO:
			out = [_f("text", "Linha original", "raw")]
	return out

static func field_spec(kind: int, name: String) -> Dictionary:
	for f: Dictionary in fields(kind):
		if f["name"] == name:
			return f
	return {}

## O valor de um campo, como o controle o mostra (texto, número ou bool).
static func get_field(b: RoteiroBlock, name: String) -> Variant:
	match name:
		"target", "ref", "ref2":
			return String(b.get(name))
		_:
			return b.get(name)

## Caracteres que mudariam o sentido da linha de fala (`Nome [expressão]: texto`) se ficassem no falante ou na expressão.
const HEAD_FORBIDDEN: Array[String] = [":", "[", "]", "\n", "\r"]
## Falante que começa com isto viraria outro tipo de linha ao reler o texto (comentário, comando, opção, rótulo...).
const SPEAKER_RESERVED_START: String = "#@?*|=-"

## O falante ou a expressão como vai para o arquivo: sem `:`, `[`, `]` nem quebras de linha, aparado.
static func clean_head(text: String) -> String:
	var out: String = text
	for ch: String in HEAD_FORBIDDEN:
		out = out.replace(ch, "")
	return out.strip_edges()

## Por que `set_field` recusaria `value` neste campo ("" se aceita). Só o falante recusa: um nome que começa com
## `# @ ? * | = -` mudaria de sentido ao reler o arquivo. A UI mostra a mensagem em vermelho no cartão.
static func field_error(b: RoteiroBlock, name: String, value: Variant) -> String:
	if name != "speaker" or field_spec(b.kind, name).is_empty():
		return ""
	var cleaned: String = clean_head(str(value))
	if cleaned != "" and SPEAKER_RESERVED_START.contains(cleaned[0]):
		return "O falante não pode começar com '%s'." % cleaned[0]
	return ""

## Grava um campo, convertendo o tipo e respeitando os limites do campo. Nome desconhecido ou valor recusado
## (`field_error`): não faz nada e o valor anterior fica.
static func set_field(b: RoteiroBlock, name: String, value: Variant) -> void:
	var spec: Dictionary = field_spec(b.kind, name)
	if spec.is_empty() or field_error(b, name, value) != "":
		return
	match str(spec["type"]):
		"int", "pct":
			b.set(name, clampi(int(value), int(spec.get("min", -999999)), int(spec.get("max", 999999))))
		"float":
			b.set(name, clampf(float(value), float(spec.get("min", 0.0)), float(spec.get("max", 9999.0))))
		"bool":
			b.set(name, bool(value))
		"line":
			b.set(name, str(value).replace("\n", " "))
		"speaker", "expr":
			b.set(name, clean_head(str(value)))
		"multiline", "raw":
			b.set(name, str(value))
		_:
			if name in ["target", "ref", "ref2"]:
				b.set(name, StringName(str(value).strip_edges()))
			else:
				b.set(name, value)

## Bloco novo com os padrões do tipo; a escolha já traz 2 opções (apontando para `fim`).
static func new_block(kind: int) -> RoteiroBlock:
	var b: RoteiroBlock = RoteiroBlock.make(kind)
	if kind == Kind.ESCOLHA:
		b.options.append(RoteiroBlock.Option.make("", &"fim"))
		b.options.append(RoteiroBlock.Option.make("", &"fim"))
	return b

# --- opções de uma escolha ---------------------------------------------------------------

static func add_option(b: RoteiroBlock) -> bool:
	if b.kind != Kind.ESCOLHA or b.options.size() >= MAX_OPTIONS:
		return false
	b.options.append(RoteiroBlock.Option.make("", &"fim"))
	return true

## Tira a opção `i`. Sempre fica pelo menos uma.
static func remove_option(b: RoteiroBlock, i: int) -> bool:
	if b.kind != Kind.ESCOLHA or b.options.size() <= 1 or i < 0 or i >= b.options.size():
		return false
	b.options.remove_at(i)
	return true

static func set_option(b: RoteiroBlock, i: int, text: String, label: String) -> void:
	if i >= 0 and i < b.options.size():
		b.options[i].text = text.replace("\n", " ").strip_edges()
		b.options[i].label = StringName(label.strip_edges())

# --- edições numa lista de blocos (evento ou cabeçalho do arquivo) ------------------------

## Índices dos blocos que o editor mostra (as linhas em branco ficam escondidas, mas continuam no modelo).
static func visible(blocks: Array[RoteiroBlock]) -> Array[int]:
	var out: Array[int] = []
	for i: int in blocks.size():
		if blocks[i].kind != Kind.EM_BRANCO:
			out.append(i)
	return out

## Insere logo depois do bloco `index` (-1 = no fim). Devolve onde ficou.
static func insert_after(blocks: Array[RoteiroBlock], index: int, b: RoteiroBlock) -> int:
	var at: int = blocks.size() if index < 0 or index >= blocks.size() else index + 1
	blocks.insert(at, b)
	return at

static func remove_at(blocks: Array[RoteiroBlock], index: int) -> void:
	if index >= 0 and index < blocks.size():
		blocks.remove_at(index)

## Sobe (`direction` -1) ou desce (+1) o bloco `index` por cima do vizinho visível. Devolve o novo índice, ou -1 se
## não há para onde ir.
static func move_visible(blocks: Array[RoteiroBlock], index: int, direction: int) -> int:
	var vis: Array[int] = visible(blocks)
	var pos: int = vis.find(index)
	if pos < 0:
		return -1
	var to_pos: int = pos + (1 if direction > 0 else -1)
	if to_pos < 0 or to_pos >= vis.size():
		return -1
	var to: int = vis[to_pos]
	var b: RoteiroBlock = blocks[index]
	blocks.remove_at(index)
	blocks.insert(to, b)
	return to

static func duplicate_at(blocks: Array[RoteiroBlock], index: int) -> RoteiroBlock:
	if index < 0 or index >= blocks.size():
		return null
	var c: RoteiroBlock = blocks[index].copy()
	c.line = 0
	blocks.insert(index + 1, c)
	return c

## Transforma uma linha não entendida em comentário (a linha crua vira o texto; um `#` do começo não se repete).
static func convert_to_comment(b: RoteiroBlock) -> void:
	if b.kind != Kind.OUTRO:
		return
	b.kind = Kind.COMENTARIO
	b.text = b.text.strip_edges().trim_prefix("#").strip_edges()

## Comentários colados no `===` do evento, um por linha.
static func leading_text(e: RoteiroEvent) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for c: RoteiroBlock in e.leading:
		lines.append(c.text)
	return "\n".join(lines)

static func set_leading_text(e: RoteiroEvent, text: String) -> void:
	e.leading.clear()
	if text.strip_edges() == "":
		return
	for l: String in text.split("\n"):
		var c: RoteiroBlock = RoteiroBlock.make(Kind.COMENTARIO)
		c.text = l.strip_edges()
		e.leading.append(c)

# --- linha do texto -> bloco -------------------------------------------------------------

## Para cada trecho do texto gerado por `RoteiroDoc.to_text`: `{start, end, event, zone, index}` (linhas 1-based,
## inclusive). `event` é o índice em `doc.events` (-1 = o cabeçalho do arquivo); `zone` é `&"items"` (o cabeçalho),
## `&"leading"`, `&"header"` (a linha `===`) ou `&"blocks"`; `index` é a posição na lista da zona.
static func line_map(doc: RoteiroDoc) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var st: Dictionary = {"count": 0, "last_blank": true}
	for i: int in doc.items.size():
		_map_block(out, st, doc.items[i], HEADER_EVENT, &"items", i)
	for ei: int in doc.events.size():
		var e: RoteiroEvent = doc.events[ei]
		_push(st, "")
		for ci: int in e.leading.size():
			_map_block(out, st, e.leading[ci], ei, &"leading", ci)
		var start: int = int(st["count"]) + 1
		_push(st, "===" if e.id == "" else "=== " + e.id)
		out.append({"start": start, "end": int(st["count"]), "event": ei, "zone": &"header", "index": -1})
		for bi: int in e.blocks.size():
			_map_block(out, st, e.blocks[bi], ei, &"blocks", bi)
	return out

## Mesma regra de `RoteiroDoc._push`: uma linha em branco nunca abre o texto nem vem depois de outra.
static func _push(st: Dictionary, line: String) -> bool:
	if line == "" and (int(st["count"]) == 0 or bool(st["last_blank"])):
		return false
	st["count"] = int(st["count"]) + 1
	st["last_blank"] = line == ""
	return true

static func _map_block(out: Array[Dictionary], st: Dictionary, b: RoteiroBlock, event: int, zone: StringName, index: int) -> void:
	var start: int = int(st["count"]) + 1
	for l: String in RoteiroDoc.block_lines(b):
		_push(st, l)
	var end: int = int(st["count"])
	if end >= start:
		out.append({"start": start, "end": end, "event": event, "zone": zone, "index": index})

## O trecho que contém `line` (1-based), ou `{}`.
static func locate(doc: RoteiroDoc, line: int) -> Dictionary:
	for m: Dictionary in line_map(doc):
		if line >= int(m["start"]) and line <= int(m["end"]):
			return m
	return {}

## Os erros e avisos do compilador sobre o texto gerado de `doc`:
## `{severity: "erro"|"aviso", line, message, loc}` com `loc` do `locate` (`{}` se a linha não é de nenhum bloco).
static func diagnostics(doc: RoteiroDoc, source_name: String, index: ContentIndex) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var map: Array[Dictionary] = line_map(doc)
	var r: Dictionary = RoteiroTools.compile_text(RoteiroDoc.to_text(doc), source_name, index)
	for pair: Array in [["erro", r["errors"]], ["aviso", r["warnings"]]]:
		for m: Variant in (pair[1] as Array):
			var f: Dictionary = Roteiros.parse_message(str(m))
			var line: int = int(f["line"])
			var loc: Dictionary = {}
			for e: Dictionary in map:
				if line >= int(e["start"]) and line <= int(e["end"]):
					loc = e
					break
			out.append({"severity": pair[0], "line": line, "message": f["message"], "loc": loc})
	return out

## Lê todos os `.roteiro` de `paths` como documentos (o que não abre é ignorado). Para as flags do projeto.
static func load_docs(paths: Array[String]) -> Array[RoteiroDoc]:
	var out: Array[RoteiroDoc] = []
	for p: String in paths:
		var f: FileAccess = FileAccess.open(p, FileAccess.READ)
		if f != null:
			out.append(RoteiroDoc.parse(f.get_as_text())["doc"] as RoteiroDoc)
	return out

## Id de evento sugerido que não existe ainda no documento (`novo_evento`, `novo_evento_2`...).
static func unused_event_id(doc: RoteiroDoc, base: String = "novo_evento") -> String:
	if doc.find_event(base) == null:
		return base
	var n: int = 2
	while doc.find_event("%s_%d" % [base, n]) != null:
		n += 1
	return "%s_%d" % [base, n]

# --- sessão de um arquivo ----------------------------------------------------------------

## Um arquivo aberto no editor: o documento, o texto de referência (o canônico do que foi aberto ou salvo) e o
## "não salvo" (o texto de agora difere do de referência). Abrir e salvar sem editar não muda um byte de um arquivo já
## canônico (os 3 da fatia são).
class Session extends RefCounted:
	var path: String = ""
	var doc: RoteiroDoc
	var baseline: String = ""
	## Erros de leitura (`parse`): linhas que o compilador não entende viram blocos OUTRO e entram aqui.
	var parse_errors: Array[String] = []

	## Lê o arquivo em `p_path`; null se não abre.
	static func open(p_path: String) -> Session:
		var f: FileAccess = FileAccess.open(p_path, FileAccess.READ)
		if f == null:
			return null
		return from_text(p_path, f.get_as_text())

	static func from_text(p_path: String, text: String) -> Session:
		var s := Session.new()
		s.path = p_path
		var r: Dictionary = RoteiroDoc.parse(text)
		s.doc = r["doc"]
		s.parse_errors.assign(r["errors"])
		s.baseline = RoteiroDoc.to_text(s.doc)
		return s

	func text() -> String:
		return RoteiroDoc.to_text(doc)

	func dirty() -> bool:
		return text() != baseline

	## Grava o texto canônico (LF) em `path`. Devolve o erro do Godot (OK = gravou); só então deixa de estar "sujo".
	func save() -> Error:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		var t: String = text()
		f.store_string(t)
		f.close()
		baseline = t
		return OK

	## Volta ao último texto salvo/aberto, descartando as edições.
	func revert() -> void:
		doc = RoteiroDoc.parse(baseline)["doc"]

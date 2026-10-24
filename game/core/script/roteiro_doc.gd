class_name RoteiroDoc
extends RefCounted

## Modelo em blocos de um arquivo `.roteiro` (M17): `parse(texto)` -> doc, `to_text(doc)` -> texto canônico.
## Pura: sem Node e sem IO. O modelo é sintático: não resolve ids nem checa rótulos, flags ou eventos repetidos
## (isso é do `RoteiroCompiler`, que roda sobre o texto gerado). A ida e volta é `to_text(parse(t))` compilando
## igual a `t`, e `to_text` é idempotente.
##
## Linhas que o compilador não entende viram um bloco OUTRO (a linha crua) e entram na lista de erros, então
## nada se perde. A tokenização espelha a do compilador (BOM, CRLF, tabs, `#` só na linha inteira, o primeiro
## `:` separa falante e texto, `|` continua a fala, `*` vira opção da pergunta anterior).
##
## Formato canônico: LF; uma linha em branco antes de cada `===` (e dos comentários colados nele); os blocos em
## ordem; uma linha por bloco (fala com `|` nas linhas extras; opções `* texto -> rótulo` sem recuo); inteiros
## sem `+` nem zeros; `@curar` com `N%` (sem argumento quando 100); quantidade 1 e velocidade 0 omitidas;
## no máximo uma linha em branco seguida; termina com um único `\n`.

const _OPS: Array[String] = ["==", "!=", ">=", "<=", ">", "<"]
const _BAD_LABEL_CHARS: Array[String] = [" ", "-", ">", "|", "*", "#", "@", "?", ":", "=", "[", "]"]

## Itens antes do primeiro evento: comentários, linhas em branco e `@flag` do arquivo (e linhas fora de lugar).
var items: Array[RoteiroBlock] = []
var events: Array[RoteiroEvent] = []

## Lê o texto. Devolve `{doc: RoteiroDoc, errors: Array[String]}`; cada erro é "<linha>: <mensagem>".
static func parse(text: String) -> Dictionary:
	var p := _Parser.new()
	p.run(text)
	return {"doc": p.doc, "errors": p.errors}

# --- consultas e edições ---

func find_event(id: String) -> RoteiroEvent:
	for e: RoteiroEvent in events:
		if e.id == id:
			return e
	return null

## Cria um evento vazio no fim. Devolve null se o id é inválido ou já existe.
func add_event(id: String) -> RoteiroEvent:
	if not valid_event_id(id) or find_event(id) != null:
		return null
	var e: RoteiroEvent = RoteiroEvent.make(id)
	events.append(e)
	return e

func remove_event(id: String) -> bool:
	for i: int in events.size():
		if events[i].id == id:
			events.remove_at(i)
			return true
	return false

## Troca o id de um evento. Falha (false) se `old_id` não existe, `new_id` é inválido ou já é de outro evento.
func rename_event(old_id: String, new_id: String) -> bool:
	var e: RoteiroEvent = find_event(old_id)
	if e == null or not valid_event_id(new_id):
		return false
	var other: RoteiroEvent = find_event(new_id)
	if other != null and other != e:
		return false
	e.id = new_id
	return true

static func valid_event_id(id: String) -> bool:
	return id != "" and not id.contains(" ") and not id.contains("\t") and not id.contains("\n")

## Flags usadas em condições e em `@set`/`@add` (sem repetir, na ordem em que aparecem).
func flags_used() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: RoteiroEvent in events:
		for b: RoteiroBlock in e.blocks:
			match b.kind:
				RoteiroBlock.Kind.SE_FLAG, RoteiroBlock.Kind.DEFINIR_FLAG, RoteiroBlock.Kind.SOMAR_FLAG:
					if not out.has(b.ref):
						out.append(b.ref)
	return out

## Flags declaradas com `@flag` (no arquivo ou dentro de um evento).
func flags_declared() -> Array[StringName]:
	var out: Array[StringName] = []
	var all: Array[RoteiroBlock] = items.duplicate()
	for e: RoteiroEvent in events:
		all.append_array(e.blocks)
	for b: RoteiroBlock in all:
		if b.kind == RoteiroBlock.Kind.DECLARAR_FLAG and not out.has(b.ref):
			out.append(b.ref)
	return out

func equals(other: RoteiroDoc) -> bool:
	if other == null or items.size() != other.items.size() or events.size() != other.events.size():
		return false
	for i: int in items.size():
		if not items[i].equals(other.items[i]):
			return false
	for i: int in events.size():
		if not events[i].equals(other.events[i]):
			return false
	return true

# --- texto canônico ---

static func to_text(doc: RoteiroDoc) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for b: RoteiroBlock in doc.items:
		_emit(lines, b)
	for e: RoteiroEvent in doc.events:
		_push(lines, "")
		for c: RoteiroBlock in e.leading:
			_emit(lines, c)
		lines.append("===" if e.id == "" else "=== " + e.id)
		for b: RoteiroBlock in e.blocks:
			_emit(lines, b)
	while not lines.is_empty() and lines[lines.size() - 1] == "":
		lines.remove_at(lines.size() - 1)
	if lines.is_empty():
		return ""
	return "\n".join(lines) + "\n"

## Uma linha em branco nunca abre o arquivo nem vem depois de outra.
static func _push(lines: PackedStringArray, line: String) -> void:
	if line == "" and (lines.is_empty() or lines[lines.size() - 1] == ""):
		return
	lines.append(line)

static func _emit(lines: PackedStringArray, b: RoteiroBlock) -> void:
	for l: String in block_lines(b):
		_push(lines, l)

## As linhas de texto de um bloco (a mesma saída de `to_text`).
static func block_lines(b: RoteiroBlock) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	match b.kind:
		RoteiroBlock.Kind.FALA, RoteiroBlock.Kind.ESCOLHA:
			var head: String = b.speaker
			if b.expr != "":
				head = ("[%s]" % b.expr) if head == "" else "%s [%s]" % [head, b.expr]
			_speech(out, head, b.text)
			if b.kind == RoteiroBlock.Kind.ESCOLHA:
				for o: RoteiroBlock.Option in b.options:
					out.append("* %s -> %s" % [o.text, o.label])
		RoteiroBlock.Kind.SISTEMA:
			_speech(out, "", b.text)
		RoteiroBlock.Kind.COMENTARIO:
			out.append("#" if b.text == "" else "# " + b.text)
		RoteiroBlock.Kind.ROTULO:
			out.append("== %s" % b.target)
		RoteiroBlock.Kind.IR_PARA:
			out.append("-> %s" % b.target)
		RoteiroBlock.Kind.SE_FLAG:
			out.append("? %s %s %d -> %s" % [b.ref, b.op, b.amount, b.target])
		RoteiroBlock.Kind.SE_ITEM:
			out.append("? item %s%s -> %s" % [b.ref, _qty(b.amount), b.target])
		RoteiroBlock.Kind.SE_DINHEIRO:
			out.append("? dinheiro %s %d -> %s" % [b.op, b.amount, b.target])
		RoteiroBlock.Kind.DEFINIR_FLAG:
			out.append("@set %s %d" % [b.ref, b.amount])
		RoteiroBlock.Kind.SOMAR_FLAG:
			out.append("@add %s %d" % [b.ref, b.amount])
		RoteiroBlock.Kind.DECLARAR_FLAG:
			out.append("@flag %s" % b.ref)
		RoteiroBlock.Kind.DAR_ITEM:
			out.append("@give item %s%s" % [b.ref, _qty(b.amount)])
		RoteiroBlock.Kind.DAR_EQUIP:
			out.append("@give equip %s%s" % [b.ref, _qty(b.amount)])
		RoteiroBlock.Kind.DAR_MOEDAS:
			out.append("@give moedas %d" % b.amount)
		RoteiroBlock.Kind.TIRAR_ITEM:
			out.append("@take item %s%s" % [b.ref, _qty(b.amount)])
		RoteiroBlock.Kind.XP:
			out.append("@xp %d%s" % [b.amount, " todos" if b.everyone else ""])
		RoteiroBlock.Kind.ENSINAR:
			out.append("@ensinar %s %s" % [b.ref, b.ref2])
		RoteiroBlock.Kind.CURAR:
			out.append("@curar" if b.pct == 100 else "@curar %d%%" % b.pct)
		RoteiroBlock.Kind.RECRUTAR:
			out.append("@recrutar %s%s" % [b.ref, (" nivel %d" % b.amount) if b.amount > 0 else ""])
		RoteiroBlock.Kind.BATALHA:
			out.append("@batalha %s" % b.ref)
		RoteiroBlock.Kind.MOVER:
			out.append("@mover %s %s%s" % [b.ref, b.ref2, "" if b.seconds == 0.0 else " " + fmt_float(b.seconds)])
		RoteiroBlock.Kind.CAMERA:
			out.append("@camera %s" % b.ref)
		RoteiroBlock.Kind.ESPERAR:
			out.append("@esperar %s" % fmt_float(b.seconds))
		RoteiroBlock.Kind.FIM_DEMO:
			out.append("@fim_demo")
		RoteiroBlock.Kind.OUTRO:
			out.append(b.text)
		RoteiroBlock.Kind.EM_BRANCO:
			out.append("")
	return out

static func _speech(out: PackedStringArray, head: String, text: String) -> void:
	var parts: PackedStringArray = text.split("\n")
	out.append("%s: %s" % [head, parts[0]])
	for i: int in range(1, parts.size()):
		out.append("|" if parts[i] == "" else "| " + parts[i])

static func _qty(n: int) -> String:
	return "" if n == 1 else " %d" % n

## Real que o compilador lê de volta com o mesmo valor: inteiro sem ponto, o resto na forma curta.
static func fmt_float(v: float) -> String:
	if v == floorf(v) and absf(v) < 1.0e9:
		return str(int(v))
	return str(v)

# --- leitura ---

class _Parser extends RefCounted:
	var doc: RoteiroDoc = RoteiroDoc.new()
	var errors: Array[String] = []
	## A lista que recebe os blocos agora (`doc.items` antes do primeiro `===`, depois `event.blocks`).
	var container: Array[RoteiroBlock] = []
	var event: RoteiroEvent = null
	var in_event: bool = false
	## Índice, em `container`, da última fala que ainda aceita `|` ou `*` (-1 = nenhuma).
	var pending: int = -1
	var choice: RoteiroBlock = null
	var msg: String = ""

	func _init() -> void:
		container = doc.items

	func run(text: String) -> void:
		if text.begins_with("﻿"):
			text = text.substr(1)
		var lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
		for i: int in lines.size():
			_line(lines[i].replace("\t", " ").strip_edges(), i + 1)
		_close_choice()
		_strip_blanks()

	func _err(n: int, m: String) -> void:
		errors.append("%d: %s" % [n, m])

	func _add(b: RoteiroBlock, n: int) -> void:
		b.line = n
		container.append(b)

	## Registra a linha crua como bloco OUTRO e o erro.
	func _outro(raw: String, n: int, m: String) -> void:
		_err(n, m)
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.OUTRO)
		b.text = raw
		_add(b, n)

	func _strip_blanks() -> void:
		while not container.is_empty() and container[container.size() - 1].kind == RoteiroBlock.Kind.EM_BRANCO:
			container.remove_at(container.size() - 1)

	func _line(raw: String, n: int) -> void:
		if raw == "":
			if not container.is_empty() and container[container.size() - 1].kind != RoteiroBlock.Kind.EM_BRANCO:
				_add(RoteiroBlock.make(RoteiroBlock.Kind.EM_BRANCO), n)
			return
		if raw.begins_with("#"):
			var c: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.COMENTARIO)
			c.text = raw.substr(1).strip_edges()
			_add(c, n)
		elif raw.begins_with("==="):
			_end_event()
			_begin_event(raw.substr(3).strip_edges(), n)
		elif raw.begins_with("|"):
			_continuation(raw, n)
		elif raw.begins_with("*"):
			_option(raw, n)
		else:
			_close_choice()
			pending = -1
			if raw.begins_with("@"):
				_command(raw, n)
			elif not in_event:
				_outro(raw, n, "linha fora de um evento (use '=== id' antes)")
			elif raw.begins_with("=="):
				_label(raw, n)
			elif raw.begins_with("->"):
				var t: String = raw.substr(2).strip_edges()
				if _valid_label(t):
					var g: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.IR_PARA)
					g.target = StringName(t)
					_add(g, n)
				else:
					_outro(raw, n, msg)
			elif raw.begins_with("?"):
				_condition(raw, n)
			else:
				_say(raw, n)

	# --- eventos ---

	func _end_event() -> void:
		_close_choice()
		pending = -1
		in_event = false

	func _begin_event(id: String, n: int) -> void:
		# Comentários colados no `===` passam a ser do evento; a linha em branco antes dele é do formato.
		var lead: Array[RoteiroBlock] = []
		if container.is_empty() or container[container.size() - 1].kind != RoteiroBlock.Kind.EM_BRANCO:
			while not container.is_empty() and container[container.size() - 1].kind == RoteiroBlock.Kind.COMENTARIO:
				lead.push_front(container.pop_back())
		_strip_blanks()
		event = RoteiroEvent.make(id)
		event.line = n
		event.leading = lead
		doc.events.append(event)
		container = event.blocks
		in_event = true
		if not RoteiroDoc.valid_event_id(id):
			_err(n, "id de evento inválido ('%s'): use uma palavra, sem espaços" % id)

	func _label(raw: String, n: int) -> void:
		var name: String = raw.substr(2).strip_edges()
		if not _valid_label(name):
			_outro(raw, n, msg)
		elif name == "fim":
			_outro(raw, n, "rótulo 'fim' é implícito e não pode ser declarado")
		else:
			var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.ROTULO)
			b.target = StringName(name)
			_add(b, n)

	func _valid_label(name: String) -> bool:
		var bad: bool = name == "" or name.begins_with("_")
		for ch: String in RoteiroDoc._BAD_LABEL_CHARS:
			if name.contains(ch):
				bad = true
		if bad:
			msg = "nome de rótulo inválido ('%s')" % name
		return not bad

	# --- falas e escolhas ---

	func _say(raw: String, n: int) -> void:
		var colon: int = raw.find(":")
		if colon < 0:
			_outro(raw, n, "linha não reconhecida (fala é 'Nome: texto')")
			return
		var head: String = raw.substr(0, colon).strip_edges()
		var body: String = raw.substr(colon + 1).strip_edges()
		var portrait: String = ""
		if head.contains("["):
			var lb: int = head.rfind("[")
			if not head.ends_with("]"):
				_outro(raw, n, "colchete do retrato não foi fechado")
				return
			portrait = head.substr(lb + 1, head.length() - lb - 2).strip_edges()
			head = head.substr(0, lb).strip_edges()
		if body == "":
			_outro(raw, n, "fala vazia")
			return
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.SISTEMA if head == "" and portrait == "" else RoteiroBlock.Kind.FALA)
		b.speaker = head
		b.expr = portrait
		b.text = body
		pending = container.size()
		_add(b, n)

	func _continuation(raw: String, n: int) -> void:
		if not in_event or choice != null or pending < 0:
			_outro(raw, n, "'|' continua uma fala, mas não há fala antes")
			return
		container[pending].text += "\n" + raw.substr(1).strip_edges()

	func _option(raw: String, n: int) -> void:
		if not in_event:
			_outro(raw, n, "linha fora de um evento (use '=== id' antes)")
			return
		if choice == null:
			if pending < 0:
				_outro(raw, n, "opção '*' sem pergunta antes (use 'Nome: pergunta?')")
				return
			var s: RoteiroBlock = container[pending]
			var c: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.ESCOLHA)
			c.speaker = s.speaker
			c.expr = s.expr
			c.text = s.text
			c.line = s.line
			container[pending] = c
			choice = c
			pending = -1
		var body: String = raw.substr(1).strip_edges()
		var arrow: int = body.rfind("->")
		if arrow < 0:
			_outro(raw, n, "opção sem '-> rótulo'")
			return
		var label: String = body.substr(arrow + 2).strip_edges()
		var opt: String = body.substr(0, arrow).strip_edges()
		if opt == "":
			_outro(raw, n, "opção vazia")
			return
		if not _valid_label(label):
			_outro(raw, n, msg)
			return
		if choice.options.size() >= RoteiroCompiler.MAX_OPTIONS:
			_outro(raw, n, "escolha com mais de %d opções" % RoteiroCompiler.MAX_OPTIONS)
			return
		choice.options.append(RoteiroBlock.Option.make(opt, StringName(label)))

	func _close_choice() -> void:
		if choice != null and choice.options.is_empty():
			_err(choice.line, "escolha sem opções")
		choice = null

	# --- condições ---

	func _condition(raw: String, n: int) -> void:
		var b: RoteiroBlock = _parse_condition(raw.substr(1).strip_edges())
		if b == null:
			_outro(raw, n, msg)
		else:
			_add(b, n)

	func _parse_condition(body: String) -> RoteiroBlock:
		var arrow: int = body.rfind("->")
		if arrow < 0:
			msg = "condição sem '-> rótulo'"
			return null
		var label: String = body.substr(arrow + 2).strip_edges()
		var tok: PackedStringArray = body.substr(0, arrow).strip_edges().split(" ", false)
		if tok.is_empty():
			msg = "condição vazia"
			return null
		if not _valid_label(label):
			return null
		var b: RoteiroBlock
		if tok[0] == "item":
			if tok.size() < 2 or tok.size() > 3:
				msg = "uso: ? item id [N] -> rótulo"
				return null
			var count: Variant = _num(tok[2], 1) if tok.size() == 3 else 1
			if count == null:
				return null
			b = RoteiroBlock.make(RoteiroBlock.Kind.SE_ITEM)
			b.ref = StringName(tok[1])
			b.amount = count
		elif tok[0] == "dinheiro":
			if tok.size() != 3 or not RoteiroDoc._OPS.has(tok[1]):
				msg = "uso: ? dinheiro >= N -> rótulo (operadores: == != >= <= > <)"
				return null
			var amount: Variant = _num(tok[2], 0)
			if amount == null:
				return null
			b = RoteiroBlock.make(RoteiroBlock.Kind.SE_DINHEIRO)
			b.op = tok[1]
			b.amount = amount
		else:
			if tok.size() != 3 or not RoteiroDoc._OPS.has(tok[1]):
				msg = "uso: ? flag == N -> rótulo (operadores: == != >= <= > <)"
				return null
			var value: Variant = _num(tok[2])
			if value == null:
				return null
			b = RoteiroBlock.make(RoteiroBlock.Kind.SE_FLAG)
			b.ref = StringName(tok[0])
			b.op = tok[1]
			b.amount = value
		b.target = StringName(label)
		return b

	# --- comandos @ ---

	func _command(raw: String, n: int) -> void:
		var tok: PackedStringArray = raw.substr(1).strip_edges().split(" ", false)
		if tok.is_empty():
			_outro(raw, n, "comando '@' vazio")
			return
		var cmd: String = tok[0]
		var args: PackedStringArray = tok.slice(1)
		if cmd == "flag":
			if args.size() != 1:
				_outro(raw, n, "uso: @flag nome")
			else:
				var d: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.DECLARAR_FLAG)
				d.ref = StringName(args[0])
				_add(d, n)
			return
		if not in_event:
			_outro(raw, n, "linha fora de um evento (use '=== id' antes)")
			return
		msg = ""
		var b: RoteiroBlock = null
		match cmd:
			"set", "add": b = _cmd_flag(cmd, args)
			"give": b = _cmd_give(args)
			"take": b = _cmd_take(args)
			"xp": b = _cmd_xp(args)
			"ensinar": b = _cmd_teach(args)
			"curar": b = _cmd_heal(args)
			"recrutar": b = _cmd_recruit(args)
			"batalha":
				if args.size() != 1:
					msg = "uso: @batalha encontro"
				else:
					b = RoteiroBlock.make(RoteiroBlock.Kind.BATALHA)
					b.ref = StringName(args[0])
			"mover": b = _cmd_move(args)
			"camera":
				if args.size() != 1:
					msg = "uso: @camera marcador"
				else:
					b = RoteiroBlock.make(RoteiroBlock.Kind.CAMERA)
					b.ref = StringName(args[0])
			"esperar":
				if args.size() != 1:
					msg = "uso: @esperar segundos"
				else:
					var secs: Variant = _real(args[0], 0.0)
					if secs != null:
						b = RoteiroBlock.make(RoteiroBlock.Kind.ESPERAR)
						b.seconds = secs
			"fim_demo":
				if args.is_empty():
					b = RoteiroBlock.make(RoteiroBlock.Kind.FIM_DEMO)
				else:
					msg = "@fim_demo não leva argumentos"
			_:
				msg = "comando desconhecido '@%s'" % cmd
		if b == null:
			_outro(raw, n, msg)
		else:
			_add(b, n)

	func _cmd_flag(cmd: String, args: PackedStringArray) -> RoteiroBlock:
		if args.size() != 2:
			msg = "uso: @%s flag N" % cmd
			return null
		var v: Variant = _num(args[1])
		if v == null:
			return null
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.DEFINIR_FLAG if cmd == "set" else RoteiroBlock.Kind.SOMAR_FLAG)
		b.ref = StringName(args[0])
		b.amount = v
		return b

	func _cmd_give(args: PackedStringArray) -> RoteiroBlock:
		if args.size() == 2 and args[0] == "moedas":
			var amount: Variant = _num(args[1], 1)
			if amount == null:
				return null
			var m: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.DAR_MOEDAS)
			m.amount = amount
			return m
		if (args.size() != 2 and args.size() != 3) or (args[0] != "item" and args[0] != "equip"):
			msg = "uso: @give item id [N] | @give equip id [N] | @give moedas N"
			return null
		var count: Variant = _num(args[2], 1) if args.size() == 3 else 1
		if count == null:
			return null
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.DAR_ITEM if args[0] == "item" else RoteiroBlock.Kind.DAR_EQUIP)
		b.ref = StringName(args[1])
		b.amount = count
		return b

	func _cmd_take(args: PackedStringArray) -> RoteiroBlock:
		if (args.size() != 2 and args.size() != 3) or args[0] != "item":
			msg = "uso: @take item id [N]"
			return null
		var count: Variant = _num(args[2], 1) if args.size() == 3 else 1
		if count == null:
			return null
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.TIRAR_ITEM)
		b.ref = StringName(args[1])
		b.amount = count
		return b

	func _cmd_xp(args: PackedStringArray) -> RoteiroBlock:
		if args.is_empty() or args.size() > 2:
			msg = "uso: @xp N [ativos|todos]"
			return null
		var amount: Variant = _num(args[0], 1)
		if amount == null:
			return null
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.XP)
		b.amount = amount
		if args.size() == 2:
			if args[1] == "todos":
				b.everyone = true
			elif args[1] != "ativos":
				msg = "grupo de XP desconhecido '%s' (use ativos ou todos)" % args[1]
				return null
		return b

	func _cmd_teach(args: PackedStringArray) -> RoteiroBlock:
		if args.size() != 2:
			msg = "uso: @ensinar heroi habilidade"
			return null
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.ENSINAR)
		b.ref = StringName(args[0])
		b.ref2 = StringName(args[1])
		return b

	func _cmd_heal(args: PackedStringArray) -> RoteiroBlock:
		if args.size() > 1:
			msg = "uso: @curar [pct]"
			return null
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.CURAR)
		if args.size() == 1:
			var v: Variant = _num(args[0].trim_suffix("%"), 1)
			if v == null:
				return null
			if v > 100:
				msg = "porcentagem de cura fora de 1 a 100: '%s'" % args[0]
				return null
			b.pct = v
		return b

	func _cmd_recruit(args: PackedStringArray) -> RoteiroBlock:
		if args.is_empty() or args.size() == 2 or args.size() > 3 or (args.size() == 3 and args[1] != "nivel"):
			msg = "uso: @recrutar heroi [nivel N]"
			return null
		var lvl: Variant = _num(args[2], 1) if args.size() == 3 else 0
		if lvl == null:
			return null
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.RECRUTAR)
		b.ref = StringName(args[0])
		b.amount = lvl
		return b

	func _cmd_move(args: PackedStringArray) -> RoteiroBlock:
		if args.size() < 2 or args.size() > 3:
			msg = "uso: @mover ator marcador [velocidade]"
			return null
		var speed: Variant = _real(args[2], 0.0) if args.size() == 3 else 0.0
		if speed == null:
			return null
		var b: RoteiroBlock = RoteiroBlock.make(RoteiroBlock.Kind.MOVER)
		b.ref = StringName(args[0])
		b.ref2 = StringName(args[1])
		b.seconds = speed
		return b

	# --- números (as mesmas regras e mensagens do compilador) ---

	func _num(tok: String, min_v: int = -2147483647) -> Variant:
		if not tok.is_valid_int():
			msg = "número inválido: '%s'" % tok
			return null
		var v: int = tok.to_int()
		if v < min_v:
			msg = "número fora do intervalo (mínimo %d): '%s'" % [min_v, tok]
			return null
		return v

	func _real(tok: String, min_v: float) -> Variant:
		var t: String = tok.replace(",", ".")
		if not t.is_valid_float():
			msg = "número inválido: '%s'" % tok
			return null
		var v: float = t.to_float()
		if v < min_v:
			msg = "número fora do intervalo (mínimo %s): '%s'" % [min_v, tok]
			return null
		return v

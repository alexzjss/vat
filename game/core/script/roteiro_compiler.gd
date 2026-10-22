class_name RoteiroCompiler
extends RefCounted

## Compilador puro do roteiro em texto (`.roteiro`, M16): texto -> EventScript por evento.
## Sem Node e sem IO. Os ids (item, equip, hero, encounter, ability) resolvem por um Callable injetado:
## `resolver(kind: StringName, id: StringName) -> Resource` (null = não existe).
## Segue compilando depois de um erro e junta todos. Mensagens: "<arquivo>:<linha>: <mensagem>".
##
## Padrões gerados:
## - Escolha (`Nome: pergunta?` + `* opção -> rótulo`): ChoiceStep(flag oculta `_esc_<evento>_<n>`, índice 0-based),
##   depois, para cada opção menos a última, IfFlag(flag == i, else = _esc_<evento>_<n>_<i+1>) + Goto(rótulo) + Label(_esc_..._<i+1>);
##   a última opção é só Goto(rótulo).
## - `? flag op N -> r`: IfFlag(flag, op invertido, N, else = r) (o salto vai no else).
## - `? dinheiro op N -> r`: IfMoney com o mesmo desenho.
## - `? item id [N] -> r`: IfItem(item, N, else = _cond_<evento>_<n>) + Goto(r) + Label(_cond_<evento>_<n>).
## - Todo evento termina com LabelStep(fim).

const MAX_OPTIONS: int = 4
const END_LABEL: StringName = &"fim"

var _source: String = ""
var _resolver: Callable
var _errors: Array[String] = []
var _warnings: Array[String] = []
var _events: Dictionary[StringName, EventScript] = {}
var _event_lines: Dictionary[StringName, int] = {}
var _declared: Dictionary[StringName, bool] = {}
## [flag, linha] de cada uso de flag, conferido contra `@flag` no fim do arquivo.
var _flag_uses: Array = []

var _in_event: bool = false
var _ev_id: StringName = &""
var _steps: Array[EventStep] = []
var _labels: Dictionary[StringName, int] = {}
## [rótulo, linha] das referências do autor, conferidas no fim do evento.
var _refs: Array = []
var _gen: int = 0
var _choice_count: int = 0
var _pending_say: SayStep
var _pending_idx: int = -1
var _pending_line: int = 0
var _choice: ChoiceStep
var _choice_line: int = 0
var _choice_opts: Array = []

## Compila `text`. `source_name` aparece nas mensagens. Devolve `{events, errors, warnings}`.
static func compile(text: String, source_name: String, resolver: Callable) -> Dictionary:
	var c := RoteiroCompiler.new()
	c._source = source_name
	c._resolver = resolver
	c._run(text)
	return {"events": c._events, "errors": c._errors, "warnings": c._warnings}

func _run(text: String) -> void:
	if text.begins_with("﻿"):
		text = text.substr(1)
	var lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var last: int = 0
	for i: int in lines.size():
		last = i + 1
		_line(lines[i].replace("\t", " ").strip_edges(), last)
	_end_event()
	for use: Array in _flag_uses:
		var f: StringName = use[0]
		if not _declared.has(f):
			_warn(use[1], "flag '%s' usada sem '@flag %s'" % [f, f])

func _err(line: int, msg: String) -> void:
	_errors.append("%s:%d: %s" % [_source, line, msg])

func _warn(line: int, msg: String) -> void:
	_warnings.append("%s:%d: %s" % [_source, line, msg])

# --- linhas ---

func _line(raw: String, n: int) -> void:
	if raw == "" or raw.begins_with("#"):
		return
	if raw.begins_with("==="):
		_end_event()
		_begin_event(raw.substr(3).strip_edges(), n)
	elif raw.begins_with("|"):
		_continuation(raw.substr(1).strip_edges(), n)
	elif raw.begins_with("*"):
		_option(raw.substr(1).strip_edges(), n)
	else:
		_close_choice()
		_pending_say = null
		if raw.begins_with("@"):
			_command(raw.substr(1).strip_edges(), n)
		elif not _in_event:
			_err(n, "linha fora de um evento (use '=== id' antes)")
		elif raw.begins_with("=="):
			_label(raw.substr(2).strip_edges(), n)
		elif raw.begins_with("->"):
			var target: String = raw.substr(2).strip_edges()
			if _valid_label(target, n):
				_steps.append(_goto(StringName(target)))
				_refs.append([StringName(target), n])
		elif raw.begins_with("?"):
			_condition(raw.substr(1).strip_edges(), n)
		else:
			_say(raw, n)

func _begin_event(id: String, n: int) -> void:
	_in_event = true
	_ev_id = StringName(id)
	_steps = []
	_labels = {}
	_refs = []
	_gen = 0
	_choice_count = 0
	_pending_say = null
	_choice = null
	if id == "" or id.contains(" "):
		_err(n, "id de evento inválido ('%s'): use uma palavra, sem espaços" % id)
		_ev_id = &""
	elif _events.has(_ev_id) or _event_lines.has(_ev_id):
		_err(n, "evento '%s' repetido (já definido na linha %d)" % [id, _event_lines[_ev_id]])
		_ev_id = &""
	else:
		_event_lines[_ev_id] = n

func _end_event() -> void:
	if not _in_event:
		return
	_close_choice()
	for ref: Array in _refs:
		var l: StringName = ref[0]
		if l != END_LABEL and not _labels.has(l):
			_err(ref[1], "rótulo '%s' não existe" % l)
	var lab := LabelStep.new()
	lab.label_name = END_LABEL
	_steps.append(lab)
	if _ev_id != &"":
		var e := EventScript.new()
		e.steps = _steps
		_events[_ev_id] = e
	_in_event = false
	_pending_say = null

func _label(name: String, n: int) -> void:
	if not _valid_label(name, n):
		return
	var l := StringName(name)
	if l == END_LABEL:
		_err(n, "rótulo 'fim' é implícito e não pode ser declarado")
	elif _labels.has(l):
		_err(n, "rótulo '%s' repetido (já definido na linha %d)" % [name, _labels[l]])
	else:
		_labels[l] = n
		var s := LabelStep.new()
		s.label_name = l
		_steps.append(s)

func _valid_label(name: String, n: int) -> bool:
	var bad: bool = name == "" or name.begins_with("_")
	for ch: String in [" ", "-", ">", "|", "*", "#", "@", "?", ":", "=", "[", "]"]:
		if name.contains(ch):
			bad = true
	if bad:
		_err(n, "nome de rótulo inválido ('%s')" % name)
	return not bad

# --- falas e escolhas ---

func _say(raw: String, n: int) -> void:
	var colon: int = raw.find(":")
	if colon < 0:
		_err(n, "linha não reconhecida (fala é 'Nome: texto')")
		return
	var head: String = raw.substr(0, colon).strip_edges()
	var body: String = raw.substr(colon + 1).strip_edges()
	var portrait: String = ""
	if head.contains("["):
		var lb: int = head.rfind("[")
		if not head.ends_with("]"):
			_err(n, "colchete do retrato não foi fechado")
			return
		portrait = head.substr(lb + 1, head.length() - lb - 2).strip_edges()
		head = head.substr(0, lb).strip_edges()
	if body == "":
		_err(n, "fala vazia")
		return
	var s := SayStep.new()
	s.speaker = head
	s.text = body
	s.portrait = StringName(portrait)
	_pending_idx = _steps.size()
	_pending_line = n
	_steps.append(s)
	_pending_say = s

func _continuation(body: String, n: int) -> void:
	if not _in_event or _choice != null or _pending_say == null:
		_err(n, "'|' continua uma fala, mas não há fala antes")
		return
	_pending_say.text += "\n" + body

func _option(body: String, n: int) -> void:
	if not _in_event:
		_err(n, "linha fora de um evento (use '=== id' antes)")
		return
	if _choice == null:
		if _pending_say == null:
			_err(n, "opção '*' sem pergunta antes (use 'Nome: pergunta?')")
			return
		_choice_count += 1
		_choice = ChoiceStep.new()
		_choice.prompt = _pending_say.text
		_choice.flag = StringName("_esc_%s_%d" % [_ev_id, _choice_count])
		_choice_line = _pending_line
		_choice_opts = []
		_steps[_pending_idx] = _choice
		_pending_say = null
	var arrow: int = body.rfind("->")
	if arrow < 0:
		_err(n, "opção sem '-> rótulo'")
		return
	var label: String = body.substr(arrow + 2).strip_edges()
	var opt: String = body.substr(0, arrow).strip_edges()
	if opt == "":
		_err(n, "opção vazia")
		return
	if not _valid_label(label, n):
		return
	if _choice_opts.size() >= MAX_OPTIONS:
		_err(n, "escolha com mais de %d opções" % MAX_OPTIONS)
		return
	_choice.options.append(opt)
	_choice_opts.append([StringName(label), n])
	_refs.append([StringName(label), n])

func _close_choice() -> void:
	if _choice == null:
		return
	if _choice_opts.is_empty():
		_err(_choice_line, "escolha sem opções")
	for i: int in _choice_opts.size():
		var target: StringName = _choice_opts[i][0]
		if i < _choice_opts.size() - 1:
			var skip := StringName("%s_%d" % [_choice.flag, i + 1])
			_steps.append(_if_flag(_choice.flag, IfFlagStep.Op.EQ, i, skip))
			_steps.append(_goto(target))
			var lab := LabelStep.new()
			lab.label_name = skip
			_steps.append(lab)
		else:
			_steps.append(_goto(target))
	_choice = null
	_choice_opts = []

# --- condições ---

const _OPS: Dictionary[String, IfFlagStep.Op] = {
	"==": IfFlagStep.Op.EQ, "!=": IfFlagStep.Op.NE, ">=": IfFlagStep.Op.GE,
	"<=": IfFlagStep.Op.LE, ">": IfFlagStep.Op.GT, "<": IfFlagStep.Op.LT,
}

static func _invert(op: IfFlagStep.Op) -> IfFlagStep.Op:
	match op:
		IfFlagStep.Op.EQ: return IfFlagStep.Op.NE
		IfFlagStep.Op.NE: return IfFlagStep.Op.EQ
		IfFlagStep.Op.GT: return IfFlagStep.Op.LE
		IfFlagStep.Op.GE: return IfFlagStep.Op.LT
		IfFlagStep.Op.LT: return IfFlagStep.Op.GE
		_: return IfFlagStep.Op.GT

func _condition(body: String, n: int) -> void:
	var arrow: int = body.rfind("->")
	if arrow < 0:
		_err(n, "condição sem '-> rótulo'")
		return
	var label: String = body.substr(arrow + 2).strip_edges()
	var tok: PackedStringArray = body.substr(0, arrow).strip_edges().split(" ", false)
	if tok.is_empty():
		_err(n, "condição vazia")
		return
	if not _valid_label(label, n):
		return
	var target := StringName(label)
	if tok[0] == "item":
		if tok.size() < 2 or tok.size() > 3:
			_err(n, "uso: ? item id [N] -> rótulo")
			return
		var item: ItemDef = _resolve(&"item", tok[1], n) as ItemDef
		var count: Variant = _num(tok[2], n, 1) if tok.size() == 3 else 1
		if item == null or count == null:
			return
		_gen += 1
		var skip := StringName("_cond_%s_%d" % [_ev_id, _gen])
		var s := IfItemStep.new()
		s.item = item
		s.count = count
		s.else_label = skip
		_steps.append(s)
		_steps.append(_goto(target))
		var lab := LabelStep.new()
		lab.label_name = skip
		_steps.append(lab)
	elif tok[0] == "dinheiro":
		if tok.size() != 3 or not _OPS.has(tok[1]):
			_err(n, "uso: ? dinheiro >= N -> rótulo (operadores: == != >= <= > <)")
			return
		var amount: Variant = _num(tok[2], n, 0)
		if amount == null:
			return
		var m := IfMoneyStep.new()
		m.op = _invert(_OPS[tok[1]])
		m.amount = amount
		m.else_label = target
		_steps.append(m)
	else:
		if tok.size() != 3 or not _OPS.has(tok[1]):
			_err(n, "uso: ? flag == N -> rótulo (operadores: == != >= <= > <)")
			return
		var value: Variant = _num(tok[2], n)
		if value == null:
			return
		_use_flag(tok[0], n)
		_steps.append(_if_flag(StringName(tok[0]), _invert(_OPS[tok[1]]), value, target))
	_refs.append([target, n])

# --- comandos @ ---

func _command(body: String, n: int) -> void:
	var tok: PackedStringArray = body.split(" ", false)
	if tok.is_empty():
		_err(n, "comando '@' vazio")
		return
	var cmd: String = tok[0]
	var args: PackedStringArray = tok.slice(1)
	if cmd == "flag":
		if args.size() != 1:
			_err(n, "uso: @flag nome")
		else:
			_declared[StringName(args[0])] = true
		return
	if not _in_event:
		_err(n, "linha fora de um evento (use '=== id' antes)")
		return
	var step: EventStep = null
	match cmd:
		"set", "add": step = _cmd_flag(cmd, args, n)
		"give": step = _cmd_give(args, n)
		"take": step = _cmd_take(args, n)
		"xp": step = _cmd_xp(args, n)
		"ensinar": step = _cmd_teach(args, n)
		"curar": step = _cmd_heal(args, n)
		"recrutar": step = _cmd_recruit(args, n)
		"batalha": step = _cmd_battle(args, n)
		"mover": step = _cmd_move(args, n)
		"camera":
			if args.size() != 1:
				_err(n, "uso: @camera marcador")
			else:
				var c := CameraToStep.new()
				c.marker = NodePath(args[0])
				step = c
		"esperar":
			var secs: Variant = _real(args[0], n, 0.0) if args.size() == 1 else null
			if args.size() != 1:
				_err(n, "uso: @esperar segundos")
			elif secs != null:
				var w := WaitStep.new()
				w.seconds = secs
				step = w
		"fim_demo":
			if args.is_empty():
				step = EndDemoStep.new()
			else:
				_err(n, "@fim_demo não leva argumentos")
		_:
			_err(n, "comando desconhecido '@%s'" % cmd)
	if step != null:
		_steps.append(step)

func _cmd_flag(cmd: String, args: PackedStringArray, n: int) -> EventStep:
	if args.size() != 2:
		_err(n, "uso: @%s flag N" % cmd)
		return null
	var v: Variant = _num(args[1], n)
	if v == null:
		return null
	_use_flag(args[0], n)
	if cmd == "set":
		var s := SetFlagStep.new()
		s.flag = StringName(args[0])
		s.value = v
		return s
	var a := AddFlagStep.new()
	a.flag = StringName(args[0])
	a.delta = v
	return a

func _cmd_give(args: PackedStringArray, n: int) -> EventStep:
	if args.size() == 2 and args[0] == "moedas":
		var amount: Variant = _num(args[1], n, 1)
		if amount == null:
			return null
		var m := GiveMoneyStep.new()
		m.amount = amount
		return m
	if (args.size() != 2 and args.size() != 3) or (args[0] != "item" and args[0] != "equip"):
		_err(n, "uso: @give item id [N] | @give equip id [N] | @give moedas N")
		return null
	var count: Variant = _num(args[2], n, 1) if args.size() == 3 else 1
	if args[0] == "item":
		var item: ItemDef = _resolve(&"item", args[1], n) as ItemDef
		if item == null or count == null:
			return null
		var gi := GiveItemStep.new()
		gi.item = item
		gi.count = count
		return gi
	var eq: EquipmentDef = _resolve(&"equip", args[1], n) as EquipmentDef
	if eq == null or count == null:
		return null
	var ge := GiveEquipmentStep.new()
	ge.equipment = eq
	ge.count = count
	return ge

func _cmd_take(args: PackedStringArray, n: int) -> EventStep:
	if (args.size() != 2 and args.size() != 3) or args[0] != "item":
		_err(n, "uso: @take item id [N]")
		return null
	var count: Variant = _num(args[2], n, 1) if args.size() == 3 else 1
	var item: ItemDef = _resolve(&"item", args[1], n) as ItemDef
	if item == null or count == null:
		return null
	var t := TakeItemStep.new()
	t.item = item
	t.count = count
	return t

func _cmd_xp(args: PackedStringArray, n: int) -> EventStep:
	if args.is_empty() or args.size() > 2:
		_err(n, "uso: @xp N [ativos|todos]")
		return null
	var amount: Variant = _num(args[0], n, 1)
	if amount == null:
		return null
	var x := GrantXpStep.new()
	x.amount = amount
	if args.size() == 2:
		if args[1] == "todos":
			x.rule = GrantXpStep.Rule.ALL_RECRUITED
		elif args[1] != "ativos":
			_err(n, "grupo de XP desconhecido '%s' (use ativos ou todos)" % args[1])
			return null
	return x

func _cmd_teach(args: PackedStringArray, n: int) -> EventStep:
	if args.size() != 2:
		_err(n, "uso: @ensinar heroi habilidade")
		return null
	var hero: Resource = _resolve(&"hero", args[0], n)
	var ability: Resource = _resolve(&"ability", args[1], n)
	if hero == null or ability == null:
		return null
	var t := TeachStep.new()
	t.hero_id = StringName(args[0])
	t.ability_id = StringName(args[1])
	return t

func _cmd_heal(args: PackedStringArray, n: int) -> EventStep:
	if args.size() > 1:
		_err(n, "uso: @curar [pct]")
		return null
	var pct: int = 100
	if args.size() == 1:
		var raw: String = args[0].trim_suffix("%")
		var v: Variant = _num(raw, n, 1)
		if v == null:
			return null
		if v > 100:
			_err(n, "porcentagem de cura fora de 1 a 100: '%s'" % args[0])
			return null
		pct = v
	var h := HealStep.new()
	h.pct = float(pct) / 100.0
	return h

func _cmd_recruit(args: PackedStringArray, n: int) -> EventStep:
	if args.is_empty() or args.size() == 2 or args.size() > 3 or (args.size() == 3 and args[1] != "nivel"):
		_err(n, "uso: @recrutar heroi [nivel N]")
		return null
	var hero: CharacterDef = _resolve(&"hero", args[0], n) as CharacterDef
	var lvl: Variant = _num(args[2], n, 1) if args.size() == 3 else 1
	if hero == null or lvl == null:
		return null
	var r := RecruitStep.new()
	r.hero = hero
	if args.size() == 3:
		r.level_mode = RecruitStep.LevelMode.FIXED
		r.level = lvl
	return r

func _cmd_battle(args: PackedStringArray, n: int) -> EventStep:
	if args.size() != 1:
		_err(n, "uso: @batalha encontro")
		return null
	var enc: EncounterDef = _resolve(&"encounter", args[0], n) as EncounterDef
	if enc == null:
		return null
	var b := StartBattleStep.new()
	b.encounter = enc
	return b

func _cmd_move(args: PackedStringArray, n: int) -> EventStep:
	if args.size() < 2 or args.size() > 3:
		_err(n, "uso: @mover ator marcador [velocidade]")
		return null
	var speed: Variant = _real(args[2], n, 0.0) if args.size() == 3 else 0.0
	if speed == null:
		return null
	var m := MoveActorStep.new()
	m.actor = NodePath(args[0])
	m.to_marker = NodePath(args[1])
	m.speed = speed
	return m

# --- utilidades ---

func _goto(label: StringName) -> GotoStep:
	var g := GotoStep.new()
	g.label = label
	return g

func _if_flag(flag: StringName, op: IfFlagStep.Op, value: int, else_label: StringName) -> IfFlagStep:
	var s := IfFlagStep.new()
	s.flag = flag
	s.op = op
	s.value = value
	s.else_label = else_label
	return s

func _use_flag(flag: String, n: int) -> void:
	_flag_uses.append([StringName(flag), n])

## Inteiro >= `min_v`; null (com erro registrado) se não for.
func _num(tok: String, n: int, min_v: int = -2147483647) -> Variant:
	if not tok.is_valid_int():
		_err(n, "número inválido: '%s'" % tok)
		return null
	var v: int = tok.to_int()
	if v < min_v:
		_err(n, "número fora do intervalo (mínimo %d): '%s'" % [min_v, tok])
		return null
	return v

func _real(tok: String, n: int, min_v: float) -> Variant:
	var t: String = tok.replace(",", ".")
	if not t.is_valid_float():
		_err(n, "número inválido: '%s'" % tok)
		return null
	var v: float = t.to_float()
	if v < min_v:
		_err(n, "número fora do intervalo (mínimo %s): '%s'" % [min_v, tok])
		return null
	return v

const _KIND_NAMES: Dictionary[StringName, String] = {
	&"item": "item", &"equip": "equipamento", &"hero": "herói", &"encounter": "encontro", &"ability": "habilidade",
}

func _resolve(kind: StringName, id: String, n: int) -> Resource:
	var res: Resource = null
	if _resolver.is_valid():
		res = _resolver.call(kind, StringName(id)) as Resource
	if res == null:
		_err(n, "%s '%s' não existe" % [_KIND_NAMES.get(kind, String(kind)), id])
	return res

class_name RoteiroBlock
extends RefCounted

## Um bloco do roteiro (M17): uma linha da sintaxe do `.roteiro` (ou uma fala com `|` e uma escolha com as opções).
## Modelo sintático: os ids ficam como foram escritos, sem resolver. Pura: sem Node e sem IO.
##
## Campos usados por tipo (os outros ficam no padrão):
## - FALA: speaker, expr, text (`\n` = linha `|`).   SISTEMA: text.   COMENTARIO: text.
## - ESCOLHA: speaker, expr, text (a pergunta), options.
## - ROTULO / IR_PARA: target.
## - SE_FLAG: ref (flag), op, amount (valor), target.   SE_ITEM: ref (item), amount (quantidade), target.
##   SE_DINHEIRO: op, amount, target.
## - DEFINIR_FLAG: ref, amount.   SOMAR_FLAG: ref, amount (delta, pode ser negativo).   DECLARAR_FLAG: ref.
## - DAR_ITEM / DAR_EQUIP / TIRAR_ITEM: ref, amount (quantidade >= 1).   DAR_MOEDAS: amount.
## - XP: amount, everyone (`todos`).   ENSINAR: ref (herói), ref2 (habilidade).   CURAR: pct (1 a 100).
## - RECRUTAR: ref (herói), amount (nível; 0 = não fixa).   BATALHA: ref (encontro).
## - MOVER: ref (ator), ref2 (marcador), seconds (velocidade).   CAMERA: ref (marcador).   ESPERAR: seconds.
## - OUTRO: text (a linha crua, que não foi entendida).   EM_BRANCO: nada.

## Só se acrescenta no fim: os valores podem ser gravados.
enum Kind {
	FALA, SISTEMA, COMENTARIO, ESCOLHA, ROTULO, IR_PARA,
	SE_FLAG, SE_ITEM, SE_DINHEIRO,
	DEFINIR_FLAG, SOMAR_FLAG, DECLARAR_FLAG,
	DAR_ITEM, DAR_EQUIP, DAR_MOEDAS, TIRAR_ITEM,
	XP, ENSINAR, CURAR, RECRUTAR,
	BATALHA, MOVER, CAMERA, ESPERAR, FIM_DEMO,
	OUTRO, EM_BRANCO,
}

## Uma opção de escolha: `* text -> label`.
class Option extends RefCounted:
	var text: String = ""
	var label: StringName = &""

	static func make(p_text: String, p_label: StringName) -> Option:
		var o := Option.new()
		o.text = p_text
		o.label = p_label
		return o

var kind: Kind = Kind.COMENTARIO
var speaker: String = ""
var expr: String = ""
var text: String = ""
var options: Array[Option] = []
var target: StringName = &""
var ref: StringName = &""
var ref2: StringName = &""
var op: String = ""
var amount: int = 0
var seconds: float = 0.0
var pct: int = 100
var everyone: bool = false
## Linha de origem (1-based) quando veio de `parse`, 0 se criado por código. Não entra na comparação.
var line: int = 0

static func make(p_kind: Kind) -> RoteiroBlock:
	var b := RoteiroBlock.new()
	b.kind = p_kind
	match p_kind:
		Kind.SE_FLAG, Kind.SE_DINHEIRO:
			b.op = "=="
		Kind.DAR_ITEM, Kind.DAR_EQUIP, Kind.TIRAR_ITEM, Kind.SE_ITEM:
			b.amount = 1
		Kind.DAR_MOEDAS, Kind.XP:
			b.amount = 1
	return b

func copy() -> RoteiroBlock:
	var b := RoteiroBlock.new()
	b.kind = kind
	b.speaker = speaker
	b.expr = expr
	b.text = text
	for o: Option in options:
		b.options.append(Option.make(o.text, o.label))
	b.target = target
	b.ref = ref
	b.ref2 = ref2
	b.op = op
	b.amount = amount
	b.seconds = seconds
	b.pct = pct
	b.everyone = everyone
	b.line = line
	return b

## Igualdade de conteúdo (ignora `line`).
func equals(other: RoteiroBlock) -> bool:
	if other == null or kind != other.kind or speaker != other.speaker or expr != other.expr or text != other.text:
		return false
	if target != other.target or ref != other.ref or ref2 != other.ref2 or op != other.op:
		return false
	if amount != other.amount or not is_equal_approx(seconds, other.seconds) or pct != other.pct or everyone != other.everyone:
		return false
	if options.size() != other.options.size():
		return false
	for i: int in options.size():
		if options[i].text != other.options[i].text or options[i].label != other.options[i].label:
			return false
	return true

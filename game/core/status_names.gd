class_name StatusNames
extends RefCounted

## Nome exibido dos estados (StatusDef não tem nome), em português. Puro: o menu de campo, o bestiário e o editor do painel
## VAT usam o mesmo mapa. Ids genéricos em inglês e português.

const NAMES: Dictionary[StringName, String] = {
	&"poison": "Veneno", &"veneno": "Veneno", &"sleep": "Sono", &"sono": "Sono",
	&"paralysis": "Paralisia", &"paralisia": "Paralisia", &"haste": "Pressa", &"pressa": "Pressa",
	&"slow": "Lentidão", &"lentidao": "Lentidão", &"barrier": "Barreira", &"barreira": "Barreira",
	&"bleed": "Sangramento", &"sangramento": "Sangramento",
	&"burn": "Queimadura", &"freeze": "Congelado", &"wet": "Molhado", &"petrify": "Petrificação",
	&"doom": "Contagem", &"taunt": "Provocar", &"berserk": "Berserk", &"reflect": "Reflexo",
	&"confusion": "Confusão", &"silence": "Silêncio", &"blind": "Cegueira", &"stop": "Pare", &"regen": "Regeneração",
}

## O nome do estado `id` (ou o id com a inicial maiúscula, se não está no mapa).
static func name_of(id: StringName) -> String:
	return NAMES.get(id, String(id).capitalize())

# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
## Marcas elementais (M14). Puro: sem Dice, sem Node. Um alvo guarda no maximo uma marca.
class_name MarkRules
extends RefCounted

## Um golpe com `element` e `affinity` (ja resolvida) deixa marca? So elemento que reage, e so se o golpe chegou
## ao alvo: imune e absorcao nao marcam; neutro (null) e Radioativo (`reacts` falso) tambem nao.
## Barreira que absorve tudo ainda marca (o golpe acertou); o chamador ja descartou esquiva e erro.
static func marks(element: ElementDef, affinity: int) -> bool:
	if element == null or not element.reacts:
		return false
	return affinity != ElementMath.Affinity.IMMUNE and affinity != ElementMath.Affinity.ABSORB

## O alvo carrega uma marca de elemento diferente de `element` (candidata a reacao).
static func has_other(target: Combatant, element: ElementDef) -> bool:
	return target.mark != null and element != null and target.mark.id != element.id

static func set_mark(target: Combatant, element: ElementDef, turns: int) -> void:
	target.mark = element
	target.mark_turns = turns if element != null else 0

static func clear(target: Combatant) -> void:
	target.mark = null
	target.mark_turns = 0

## Id da marca que o alvo carrega ao fim do golpe; vazio se nao ha marca ou o alvo caiu.
static func id_of(target: Combatant) -> StringName:
	if target.mark == null or target.is_down():
		return &""
	return target.mark.id

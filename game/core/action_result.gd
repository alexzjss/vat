# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name ActionResult
extends RefCounted

var fizzled: bool = false
var targets: Array[Combatant] = []
## Entradas: {target_id, kind, amount, dodged, status_result, missed, shielded, element, affinity}
## `element` = id do elemento (&"" = neutro); `affinity` = ElementMath.Affinity. Absorver gera um hit HEAL.
var hits: Array[Dictionary] = []
var downed: Array[Combatant] = []

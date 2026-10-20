# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name ActionResult
extends RefCounted

var fizzled: bool = false
var targets: Array[Combatant] = []
## Entradas: {target_id, kind, amount, dodged, status_result, missed}
var hits: Array[Dictionary] = []
var downed: Array[Combatant] = []

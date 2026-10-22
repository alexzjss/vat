# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name ActionResult
extends RefCounted

var fizzled: bool = false
var targets: Array[Combatant] = []
## Entradas: {target_id, kind, amount, dodged, status_result, missed, shielded, element, affinity}
## `reflected_from` = id de quem refletiu (Reflexo, M15; vazio = normal).
## `element` = id do elemento (&"" = neutro); `affinity` = ElementMath.Affinity. Absorver gera um hit HEAL.
var hits: Array[Dictionary] = []
var downed: Array[Combatant] = []
## Scan (M15): ids (EnemyDef.id) dos inimigos que o Scan revelou nesta acao, sem repeticao. Quem hospeda o
## GameState os grava em `bestiary` (GameState.record_result); o executor nao conhece o GameState.
var scanned: Array[StringName] = []

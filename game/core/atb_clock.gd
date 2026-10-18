# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name AtbClock
extends RefCounted

var _cfg: BalanceConfig

func _init(cfg: BalanceConfig) -> void:
	_cfg = cfg

## Enche o ATB de quem não está caído, não está na fila e ainda não está cheio.
## Devolve quem chegou a 1.0 neste passo; o chamador decide fila x turno perdido.
func advance(delta: float, combatants: Array[Combatant], queue: ReadyQueue) -> Array[Combatant]:
	var reached: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.is_down() or c.atb >= 1.0 or queue.has(c):
			continue
		c.atb = minf(1.0, c.atb + StatCalculator.atb_rate(c, _cfg) * delta)
		if c.atb >= 1.0:
			reached.append(c)
	return reached

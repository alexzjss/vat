# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name AtbClock
extends RefCounted

var _cfg: BalanceConfig

func _init(cfg: BalanceConfig) -> void:
	_cfg = cfg

## Enche o ATB de quem não está caído, parado (Pare), na fila ou já cheio.
## Devolve quem chegou a 1.0 neste passo; o chamador decide fila x turno perdido.
func advance(delta: float, combatants: Array[Combatant], queue: ReadyQueue) -> Array[Combatant]:
	var reached: Array[Combatant] = []
	var avg: float = _living_avg_speed(combatants)
	for c: Combatant in combatants:
		if c.is_down() or c.atb >= 1.0 or c.is_stopped() or queue.has(c):
			continue
		c.atb = minf(1.0, c.atb + StatCalculator.atb_rate(c, _cfg, avg) * delta)
		if c.atb >= 1.0:
			reached.append(c)
	return reached

func _living_avg_speed(combatants: Array[Combatant]) -> float:
	var total: float = 0.0
	var n: int = 0
	for c: Combatant in combatants:
		if not c.is_down():
			total += StatCalculator.effective(c, &"speed", _cfg)
			n += 1
	return total / n if n > 0 else -1.0

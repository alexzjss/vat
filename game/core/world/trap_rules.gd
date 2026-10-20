class_name TrapRules
extends RefCounted

## Dano de armadilha (M10), puro: tira `pct` do HP máximo dos heróis ativos em pé, sem nunca matar (mínimo 1 HP).

## Dano que `h` leva: pct do HP máximo (arredondado para cima), limitado a deixar 1 HP; 0 para quem já caiu.
static func damage_for(h: HeroState, pct: float, cfg: BalanceConfig) -> int:
	if h.hp <= 0 or pct <= 0.0:
		return 0
	var hp_max: int = StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), cfg)
	return clampi(ceili(float(hp_max) * pct), 0, h.hp - 1)

## Aplica o dano aos ativos; devolve o total tirado.
static func apply(state: GameState, pct: float) -> int:
	var total: int = 0
	for h: HeroState in state.heroes:
		var d: int = damage_for(h, pct, state.cfg)
		h.hp -= d
		total += d
	return total

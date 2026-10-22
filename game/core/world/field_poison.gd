class_name FieldPoison
extends RefCounted

## Veneno no mapa (M15), puro: a cada `poison_step_px` andados, cada heroi ativo envenenado perde `poison_field_pct`
## do HP maximo (minimo 1 de dano), sem nunca cair: o HP para em 1, como em FF. Quem esta na reserva nao anda e nao perde.
## O resto de um passo nao completo fica em `GameState.poison_walk_px` (nao vai no save).

## O heroi carrega um estado persistente do tipo Veneno?
static func is_poisoned(h: HeroState, cfg: BalanceConfig) -> bool:
	for id: StringName in h.field_statuses:
		var d: StatusDef = cfg.persistent_status(id)
		if d != null and d.kind == StatusDef.Kind.POISON:
			return true
	return false

## Dano de um tique em `h`: pct do HP maximo (minimo 1), limitado a deixar 1 HP; 0 se nao esta envenenado ou ja caiu.
static func damage_for(h: HeroState, cfg: BalanceConfig) -> int:
	if h.hp <= 1 or not is_poisoned(h, cfg):
		return 0
	var hp_max: int = StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), cfg)
	return clampi(maxi(1, floori(float(hp_max) * cfg.poison_field_pct)), 0, h.hp - 1)

## Um tique nos ativos; devolve o total tirado.
static func tick(state: GameState) -> int:
	var total: int = 0
	for h: HeroState in state.heroes:
		var d: int = damage_for(h, state.cfg)
		h.hp -= d
		total += d
	return total

## O grupo andou `px` pixels: roda um tique por `poison_step_px` completo. Devolve o total tirado.
static func walk(state: GameState, px: float) -> int:
	if px <= 0.0 or state.cfg.poison_step_px <= 0.0:
		return 0
	state.poison_walk_px += px
	var total: int = 0
	while state.poison_walk_px >= state.cfg.poison_step_px:
		state.poison_walk_px -= state.cfg.poison_step_px
		total += tick(state)
	return total

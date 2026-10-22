# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name Targeting
extends RefCounted

static func wants_downed(effects: Array[EffectDef]) -> bool:
	for e: EffectDef in effects:
		if e.kind == EffectDef.Kind.REVIVE:
			return true
	return false

static func _sides(side: AbilityDef.Side, actor: Combatant, b: BattleState) -> Array[Combatant]:
	match side:
		AbilityDef.Side.ENEMIES:
			return b.foes_of(actor)
		AbilityDef.Side.ALLIES:
			return b.allies_of(actor)
	return b.all()

## Cura de Petrificacao (M15): um REMOVE_STATUS que cita o estado PETRIFY pode mirar um petrificado.
static func cures_petrify(effects: Array[EffectDef]) -> bool:
	for e: EffectDef in effects:
		if e.kind != EffectDef.Kind.REMOVE_STATUS:
			continue
		if e.status != null and e.status.kind == StatusDef.Kind.PETRIFY:
			return true
		for s: StatusDef in e.statuses:
			if s != null and s.kind == StatusDef.Kind.PETRIFY:
				return true
	return false

## Provocar (M15): entre `cands`, o provocador vivo do lado inimigo de `actor` (estado TAUNT, nao petrificado) com
## mais duracao restante em turnos; empate: o primeiro. Nulo sem provocador. So a IA usa: a escolha do jogador nunca e forcada.
static func taunter(cands: Array[Combatant], actor: Combatant) -> Combatant:
	var best: Combatant = null
	var best_left: int = -1
	for c: Combatant in cands:
		if c.team == actor.team or c.is_out():
			continue
		for s: ActiveStatus in c.statuses:
			if s.def.kind == StatusDef.Kind.TAUNT and s.remaining > best_left:
				best = c
				best_left = s.remaining
	return best

static func _valid(arr: Array[Combatant], effects: Array[EffectDef]) -> Array[Combatant]:
	var downed: bool = wants_downed(effects)
	var petrified_ok: bool = cures_petrify(effects)
	var out: Array[Combatant] = []
	for c: Combatant in arr:
		if c.is_down() != downed:
			continue
		# Petrificado nao e alvo de nada, salvo da propria cura.
		if c.is_petrified() and not petrified_ok:
			continue
		out.append(c)
	return out

static func candidates(shape: AbilityDef.Shape, side: AbilityDef.Side, effects: Array[EffectDef], actor: Combatant, b: BattleState) -> Array[Combatant]:
	if shape == AbilityDef.Shape.CIRCLE_SELF:
		return [actor]
	return _valid(_sides(side, actor, b), effects)

static func _dist_to_segment(p: Vector2, a: Vector2, c: Vector2) -> float:
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, c)
	return p.distance_to(closest)

static func area(shape: AbilityDef.Shape, side: AbilityDef.Side, effects: Array[EffectDef], radius: float, width: float, actor: Combatant, center: Combatant, b: BattleState) -> Array[Combatant]:
	var valid: Array[Combatant] = _valid(_sides(side, actor, b), effects)
	var out: Array[Combatant] = []
	match shape:
		AbilityDef.Shape.SINGLE:
			out.append(center)
		AbilityDef.Shape.GROUP:
			for c: Combatant in _valid(b.allies_of(center), effects):
				out.append(c)
		AbilityDef.Shape.ALL:
			out = valid
		AbilityDef.Shape.CIRCLE_TARGET:
			for c: Combatant in valid:
				if c.position.distance_to(center.position) <= radius:
					out.append(c)
		AbilityDef.Shape.CIRCLE_SELF:
			for c: Combatant in valid:
				if c.position.distance_to(actor.position) <= radius:
					out.append(c)
		AbilityDef.Shape.LINE:
			for c: Combatant in valid:
				if _dist_to_segment(c.position, actor.position, center.position) <= width / 2.0:
					out.append(c)
	return out

static func redirect(shape: AbilityDef.Shape, side: AbilityDef.Side, effects: Array[EffectDef], actor: Combatant, original_center: Combatant, original_pos: Vector2, b: BattleState) -> Combatant:
	if shape == AbilityDef.Shape.CIRCLE_SELF:
		return actor
	var cands: Array[Combatant] = candidates(shape, side, effects, actor, b)
	if cands.has(original_center):
		return original_center
	var best: Combatant = null
	var best_d: float = INF
	for c: Combatant in cands:
		var d: float = c.position.distance_to(original_pos)
		if d < best_d:
			best_d = d
			best = c
	return best

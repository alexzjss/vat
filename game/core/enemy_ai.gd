# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name EnemyAI
extends RefCounted

static func decide(actor: Combatant, b: BattleState) -> PendingAction:
	if actor.enemy_def != null:
		var silenced: bool = actor.is_silenced()
		# Chefe (M11): a fase atual substitui as regras; o laco (e o Silencio) e o mesmo.
		for rule: AiRule in actor.ai_rules():
			if rule.ability == null or rule.ability.ap_cost > actor.ap:
				continue
			# Silêncio: as regras de técnica são puladas; só o ataque básico segue valendo.
			if silenced and rule.ability != actor.basic_attack:
				continue
			if not _condition_holds(rule, actor, b):
				continue
			if rule.chance < 1.0 and b.dice.roll() >= rule.chance:
				continue
			var center: Combatant = _pick_center(rule, actor, b)
			if center == null:
				continue
			var pa: PendingAction = _make(actor, rule.ability, center)
			if rule.telegraph:
				# Anunciada: o AP so e gasto quando a acao sai (BattleController).
				pa.telegraph = true
			else:
				actor.ap -= rule.ability.ap_cost
			return pa
	if actor.basic_attack == null:
		push_error("EnemyAI: %s sem ataque basico" % actor.id)
		return null
	# Assume-se que basic_attack nao custa AP (custo 0).
	var target: Combatant = _lowest_hp(b.living(b.foes_of(actor)))
	if target == null:
		return null
	return _make(actor, actor.basic_attack, target)

## Confusão (M11): ataque básico num alvo sorteado entre todos os combatentes vivos, menos o próprio.
## Nulo se não há ataque básico nem alvo.
static func confused_action(actor: Combatant, b: BattleState) -> PendingAction:
	if actor.basic_attack == null:
		return null
	var cands: Array[Combatant] = []
	for c: Combatant in b.living(b.all()):
		if c != actor:
			cands.append(c)
	if cands.is_empty():
		return null
	var pa: PendingAction = _make(actor, actor.basic_attack, cands[b.dice.pick_index(cands.size())])
	pa.confused = true
	return pa

static func _make(actor: Combatant, ability: AbilityDef, center: Combatant) -> PendingAction:
	var pa := PendingAction.new()
	pa.actor = actor
	pa.ability = ability
	pa.center = center
	pa.center_pos = center.position
	return pa

static func _condition_holds(rule: AiRule, actor: Combatant, b: BattleState) -> bool:
	if rule.condition == AiRule.Condition.ALLY_HP_BELOW:
		return not _below(b.living(b.allies_of(actor)), rule.threshold, b).is_empty()
	if rule.condition == AiRule.Condition.PART_DOWN:
		for c: Combatant in b.allies_of(actor):
			if c.is_down() and c.enemy_def != null and c.enemy_def.role == EnemyDef.Role.PART:
				return true
		return false
	if rule.condition == AiRule.Condition.CAN_REACT:
		return not _reacting_targets(rule.ability, actor, b).is_empty()
	return true

static func _below(arr: Array[Combatant], threshold: float, b: BattleState) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c: Combatant in arr:
		if float(c.hp) < threshold * float(StatCalculator.hp_max(c, b.cfg)):
			out.append(c)
	return out

static func _pick_center(rule: AiRule, actor: Combatant, b: BattleState) -> Combatant:
	var a: AbilityDef = rule.ability
	var cands: Array[Combatant] = Targeting.candidates(a.shape, a.side, a.effects, actor, b)
	if cands.is_empty():
		return null
	match rule.pick:
		AiRule.TargetPick.SELF:
			return actor if cands.has(actor) else null
		AiRule.TargetPick.RANDOM_ENEMY:
			return cands[b.dice.pick_index(cands.size())]
		AiRule.TargetPick.NEAREST:
			return _by_distance(cands, actor, false)
		AiRule.TargetPick.FARTHEST:
			return _by_distance(cands, actor, true)
		AiRule.TargetPick.CLUSTER:
			return _cluster(rule.ability, cands, actor, b)
		AiRule.TargetPick.REACTION_TARGET:
			return _reaction_center(a, cands, actor, b)
	if rule.condition == AiRule.Condition.ALLY_HP_BELOW:
		# [P-plano] 19: o alvo é um aliado abaixo do limiar, o de menor fração de HP.
		return _lowest_hp_ratio(_below(cands, rule.threshold, b), b)
	return _lowest_hp(cands)

## Mais perto (ou mais longe) do ator; empate: o primeiro.
static func _by_distance(arr: Array[Combatant], actor: Combatant, farthest: bool) -> Combatant:
	var best: Combatant = null
	var best_d: float = 0.0
	for c: Combatant in arr:
		var d: float = c.position.distance_to(actor.position)
		if best == null or (d > best_d if farthest else d < best_d):
			best = c
			best_d = d
	return best

## O centro que pega mais alvos na area da habilidade; empate: o primeiro.
static func _cluster(a: AbilityDef, arr: Array[Combatant], actor: Combatant, b: BattleState) -> Combatant:
	var best: Combatant = null
	var best_n: int = -1
	for c: Combatant in arr:
		var n: int = Targeting.area(a.shape, a.side, a.effects, a.radius, a.width, actor, c, b).size()
		if n > best_n:
			best = c
			best_n = n
	return best

## Menor HP/HP máx.; empate: o primeiro. Nulo se vazio.
static func _lowest_hp_ratio(arr: Array[Combatant], b: BattleState) -> Combatant:
	var best: Combatant = null
	var best_ratio: float = INF
	for c: Combatant in arr:
		var m: int = StatCalculator.hp_max(c, b.cfg)
		var ratio: float = float(c.hp) / float(m) if m > 0 else 0.0
		if best == null or ratio < best_ratio:
			best = c
			best_ratio = ratio
	return best

## Menor HP; empate: o primeiro.
static func _lowest_hp(arr: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	for c: Combatant in arr:
		if best == null or c.hp < best.hp:
			best = c
	return best

## Alvos validos (vivos) da habilidade cuja marca reage com o elemento efetivo dela (M14): o golpe marcaria
## (nao e imune nem absorve) e a tabela tem o par. Sem elemento, sem marca ou tabela vazia: nenhum.
static func _reacting_targets(a: AbilityDef, actor: Combatant, b: BattleState) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var el: ElementDef = ElementMath.element_of(a, actor)
	if el == null:
		return out
	for c: Combatant in Targeting.candidates(a.shape, a.side, a.effects, actor, b):
		if c.is_down() or not MarkRules.has_other(c, el):
			continue
		var aff: int = ElementMath.affinity_of(ElementMath.total_resist(el, c))
		if MarkRules.marks(el, aff) and ReactionRules.find(b.reactions, c.mark, el) != null:
			out.append(c)
	return out

## REACTION_TARGET: o alvo reagente de menor HP (empate: o primeiro). Em area o centro tambem e o alvo reagente
## (nao se compara quantos a area pega: simples). Sem alvo reagente: nulo, e a regra e pulada.
static func _reaction_center(a: AbilityDef, _cands: Array[Combatant], actor: Combatant, b: BattleState) -> Combatant:
	return _lowest_hp(_reacting_targets(a, actor, b))

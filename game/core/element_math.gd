# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
## Elementos e afinidade (M13). Puro: sem Dice, sem estado. Ponto unico por onde o dano elemental passa.
class_name ElementMath
extends RefCounted

## Novos valores sempre no fim. Guardado como int em `ActionResult.hits[i]["affinity"]`.
enum Affinity { NEUTRAL, WEAK, RESIST, IMMUNE, ABSORB }

const MAX_NATIVES: int = 2

## Elemento efetivo: o da habilidade; senao o da arma, so no ataque basico; senao neutro (null).
## Itens nao tem habilidade (null) e sao neutros. Contra-ataque e Limite seguem a mesma regra
## (o Limite nunca e o ataque basico). No Suporte `actor` e o reserva, dono da arma e da habilidade.
static func element_of(ability: AbilityDef, actor: Combatant) -> ElementDef:
	if ability == null:
		return null
	if ability.element != null:
		return ability.element
	if actor != null and ability == actor.basic_attack:
		return actor.weapon_element
	return null

## Afinidade total do alvo ao elemento: base + equipamentos (ja somados no Combatant).
static func total_resist(element: ElementDef, target: Combatant) -> float:
	if element == null:
		return 0.0
	return float(target.element_resist.get(element.id, 0.0))

## true se o elemento esta entre os nativos do atacante.
static func is_native(element: ElementDef, actor: Combatant) -> bool:
	return element != null and actor.elements.has(element)

## Rotulo da afinidade para um total de resistencia ja somado.
static func affinity_of(total: float) -> Affinity:
	if is_zero_approx(total):
		return Affinity.NEUTRAL
	if total < 0.0:
		return Affinity.WEAK
	if is_zero_approx(total - 1.0):
		return Affinity.IMMUNE
	if total < 1.0:
		return Affinity.RESIST
	return Affinity.ABSORB

## Sangue: multiplicador de dano que cresce quanto menor o HP do atacante (1.0 com HP cheio).
static func blood_multiplier(actor: Combatant, cfg: BalanceConfig) -> float:
	var hp_max: int = StatCalculator.hp_max(actor, cfg)
	if hp_max <= 0:
		return 1.0
	var ratio: float = clampf(float(actor.hp) / float(hp_max), 0.0, 1.0)
	return 1.0 + cfg.blood_low_hp_bonus * (1.0 - ratio)

## Aplica bonus de mesmo elemento e afinidade ao dano (ja com defesa e variacao).
## Devolve {damage, heal, affinity}: `heal` > 0 so quando absorve (damage = 0 nesse caso).
## Minimo de 1 de dano so em neutro/fraco/resistiu; imune = 0.
static func resolve(dmg: int, element: ElementDef, actor: Combatant, target: Combatant, cfg: BalanceConfig) -> Dictionary:
	if element == null:
		return {"damage": dmg, "heal": 0, "affinity": Affinity.NEUTRAL}
	var out: int = dmg
	if is_native(element, actor):
		out = maxi(1, floori(float(out) * cfg.same_element_bonus))
	if element.rule == ElementDef.Rule.BLOOD:
		var bonus: float = blood_multiplier(actor, cfg)
		if bonus > 1.0:
			out = maxi(1, floori(float(out) * bonus))
	if element.rule == ElementDef.Rule.RADIOACTIVE:
		# Ignora afinidade (ate imunidade e absorcao); o bonus de mesmo elemento ja valeu acima.
		return {"damage": out, "heal": 0, "affinity": Affinity.NEUTRAL}
	var total: float = total_resist(element, target)
	var aff: Affinity = affinity_of(total)
	var m: float = 1.0 - total
	match aff:
		Affinity.IMMUNE:
			return {"damage": 0, "heal": 0, "affinity": aff}
		Affinity.ABSORB:
			return {"damage": 0, "heal": floori(float(out) * -m), "affinity": aff}
		Affinity.NEUTRAL:
			return {"damage": out, "heal": 0, "affinity": aff}
	return {"damage": maxi(1, floori(float(out) * m)), "heal": 0, "affinity": aff}

## Erros de dados: nativos acima do maximo, nulos ou repetidos. Vazio = ok.
static func native_errors(owner_id: StringName, elements: Array[ElementDef]) -> Array[String]:
	var errs: Array[String] = []
	if elements.size() > MAX_NATIVES:
		errs.append("%s: %d elementos nativos (maximo %d)" % [owner_id, elements.size(), MAX_NATIVES])
	for i: int in elements.size():
		if elements[i] == null:
			errs.append("%s: elemento nativo nulo" % owner_id)
		elif elements.find(elements[i]) != i:
			errs.append("%s: elemento nativo repetido (%s)" % [owner_id, elements[i].id])
	return errs

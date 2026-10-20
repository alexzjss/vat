# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name PendingAction
extends RefCounted

var actor: Combatant
var ability: AbilityDef
var item: ItemDef
var center: Combatant
var center_pos: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var impacted: bool = false
## Golpe de Limite (M8): a barra de `actor` zera quando a acao comeca.
var is_limit: bool = false
## Suporte (M8.5): `actor` e o heroi da reserva (Combatant temporario, fora de b.heroes) e `caller` quem o chamou.
## O ATB zerado no fim e o Limite gasto sao de `caller`; o credito de contribuicao tambem.
var caller: Combatant
## Confusão (M11): ataque básico automático que pode acertar qualquer combatente vivo (lado BOTH).
var confused: bool = false
## Chefe (M11): a IA escolheu uma regra anunciada; o controlador guarda a acao em Combatant.charging em vez de executar.
var telegraph: bool = false
## Chefe (M11): contra-ataque. Nao usa nem zera o ATB de quem contra-ataca.
var is_counter: bool = false

## Quem gasta o turno: o chamador no Suporte, senao o proprio ator.
func turn_owner() -> Combatant:
	return caller if caller != null else actor

func shape() -> AbilityDef.Shape:
	return item.shape if item != null else ability.shape

func side() -> AbilityDef.Side:
	if confused:
		return AbilityDef.Side.BOTH
	return item.side if item != null else ability.side

func effects() -> Array[EffectDef]:
	return item.effects if item != null else ability.effects

func radius() -> float:
	return 0.0 if item != null else ability.radius

func width() -> float:
	return 0.0 if item != null else ability.width

func cast_time(cfg: BalanceConfig) -> float:
	return cfg.item_cast_time if item != null else ability.cast_time

func impact_time(cfg: BalanceConfig) -> float:
	return cfg.item_impact_time if item != null else ability.impact_time

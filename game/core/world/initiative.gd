# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): o ângulo vem do BalanceConfig.
class_name Initiative
extends RefCounted

## Tipo de contato entre o jogador e um inimigo de mapa (decidido no toque).
enum Kind { NORMAL, PREEMPTIVE, AMBUSH }

## PREEMPTIVE: o jogador toca pelas costas (ângulo entre a frente do inimigo e o vetor
## inimigo->jogador acima de `backstab_deg`). AMBUSH: o inimigo estava perseguindo (ou escondido).
## Perseguir vence o ângulo. Sem frente definida (inimigo nunca andou) não há costas: NORMAL.
static func classify(enemy_pos: Vector2, enemy_facing: Vector2, enemy_chasing: bool,
		player_pos: Vector2, backstab_deg: float) -> Kind:
	if enemy_chasing:
		return Kind.AMBUSH
	var to_player: Vector2 = player_pos - enemy_pos
	if enemy_facing == Vector2.ZERO or to_player == Vector2.ZERO:
		return Kind.NORMAL
	if absf(rad_to_deg(enemy_facing.angle_to(to_player))) > backstab_deg:
		return Kind.PREEMPTIVE
	return Kind.NORMAL

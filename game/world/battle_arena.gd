class_name BattleArena
extends Node2D

## Marcadores de posicao da cena de batalha no mapa (HeroSpot1..4, EnemySpot1..N).
## A LocalMap usa os primeiros hero_positions() conforme o numero de herois ativos.

func hero_positions() -> Array[Vector2]:
	return _spots("HeroSpot")

func enemy_positions(n: int) -> Array[Vector2]:
	var all: Array[Vector2] = _spots("EnemySpot")
	var result: Array[Vector2] = []
	if n > all.size():
		push_error("BattleArena: EnemySpot insuficientes (%d marcadores para %d inimigos)" % [all.size(), n])
	for i: int in n:
		if all.is_empty():
			result.append(global_position)
		else:
			result.append(all[mini(i, all.size() - 1)])
	return result

## Quantas posições de inimigo a arena tem.
func enemy_count() -> int:
	return _spots("EnemySpot").size()

## Onde o heroi da reserva aparece no Suporte (marcador SupportSpot, opcional); nao finito = sem marcador.
func support_position() -> Vector2:
	if has_node("SupportSpot"):
		return (get_node("SupportSpot") as Node2D).global_position
	return Vector2.INF

func center() -> Vector2:
	return global_position

func _spots(prefix: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var i: int = 1
	while has_node(prefix + str(i)):
		result.append((get_node(prefix + str(i)) as Node2D).global_position)
		i += 1
	return result

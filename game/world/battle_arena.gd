class_name BattleArena
extends Node2D

## Marcadores de posicao da cena de batalha no mapa (HeroSpot1..3, EnemySpot1..N).

func hero_positions() -> Array[Vector2]:
	return _spots("HeroSpot")

func enemy_positions(n: int) -> Array[Vector2]:
	var all: Array[Vector2] = _spots("EnemySpot")
	var result: Array[Vector2] = []
	if n > all.size():
		push_error("BattleArena: EnemySpot insuficientes (%d marcadores para %d inimigos)" % [all.size(), n])
	for i in n:
		if all.is_empty():
			result.append(global_position)
		else:
			result.append(all[mini(i, all.size() - 1)])
	return result

func center() -> Vector2:
	return global_position

func _spots(prefix: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var i: int = 1
	while has_node(prefix + str(i)):
		result.append((get_node(prefix + str(i)) as Node2D).global_position)
		i += 1
	return result

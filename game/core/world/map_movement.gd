class_name MapMovement
extends RefCounted

## Interface plugavel de movimento de inimigo de mapa. Devolve a velocidade desejada.
## `player_pos` e a posicao do jogador (so os comportamentos que reagem a ele usam).
func step(_pos: Vector2, _delta: float, _player_pos: Vector2) -> Vector2:
	return Vector2.ZERO

## Perseguindo o jogador agora (decorador de perseguição sobrescreve).
func is_chasing() -> bool:
	return false

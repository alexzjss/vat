class_name MapMovement
extends RefCounted

## Interface plugavel de movimento de inimigo de mapa. Devolve a velocidade desejada.
func step(_pos: Vector2, _delta: float) -> Vector2:
	return Vector2.ZERO

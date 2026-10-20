class_name InteractPicker
extends RefCounted

## Escolha pura do interagível: entre os candidatos ao alcance, o mais próximo de `from`
## (empate: o primeiro da lista).

## Índice do mais próximo; -1 se não há candidatos.
static func nearest(from: Vector2, positions: Array[Vector2]) -> int:
	var best: int = -1
	var best_d: float = INF
	for i: int in positions.size():
		var d: float = from.distance_squared_to(positions[i])
		if d < best_d:
			best_d = d
			best = i
	return best

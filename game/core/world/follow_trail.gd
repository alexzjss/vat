class_name FollowTrail
extends RefCounted

## Rastro do líder: uma amostra de posição a cada `spacing` px andados.
## O seguidor k fica na amostra k * gap (0 = a mais recente). Lógica pura, sem nós.

var spacing: float
var gap: int
## samples[0] é a mais recente.
var samples: Array[Vector2] = []

func _init(p_spacing: float, p_gap: int, start: Vector2 = Vector2.ZERO) -> void:
	spacing = p_spacing
	gap = p_gap
	reset(start)

## Recomeça o rastro na posição dada (todos os seguidores caem nela).
func reset(pos: Vector2) -> void:
	samples = [pos]

## Informa a posição atual do líder; guarda uma amostra nova a cada `spacing` px.
func push(pos: Vector2) -> void:
	if spacing <= 0.0 or pos.distance_to(samples[0]) < spacing:
		return
	samples.push_front(pos)

## Posição do seguidor k (k >= 1); antes de haver amostras suficientes, usa a mais antiga.
func position_of(k: int) -> Vector2:
	return samples[mini(k * gap, samples.size() - 1)]

## Descarta amostras que nenhum seguidor (até max_followers) pode usar.
func trim(max_followers: int) -> void:
	var keep: int = max_followers * gap + 1
	if samples.size() > keep:
		samples.resize(keep)

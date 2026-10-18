class_name Dice
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

## Valor em [0, 1).
func roll() -> float:
	return _rng.randf()

func pick_index(n: int) -> int:
	return clampi(int(roll() * n), 0, maxi(n - 1, 0))

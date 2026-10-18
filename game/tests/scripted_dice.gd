class_name ScriptedDice
extends Dice

var _values: Array[float]
var _i: int = 0

func _init(values: Array[float] = []) -> void:
	super._init(0)
	_values = values

func roll() -> float:
	if _i < _values.size():
		_i += 1
		return _values[_i - 1]
	return 0.99

class_name IfFlagStep
extends EventStep

enum Op { EQ, NE, GT, GE, LT, LE }

## Condição verdadeira: segue para o próximo passo. Falsa: salta para o Label `else_label`
## (vazio = termina o evento).
@export var flag: StringName = &""
@export var op: Op = Op.EQ
@export var value: int = 1
@export var else_label: StringName = &""

static func compare(actual: int, p_op: Op, expected: int) -> bool:
	match p_op:
		Op.EQ: return actual == expected
		Op.NE: return actual != expected
		Op.GT: return actual > expected
		Op.GE: return actual >= expected
		Op.LT: return actual < expected
		_: return actual <= expected

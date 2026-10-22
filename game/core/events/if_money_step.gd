class_name IfMoneyStep
extends EventStep

## Condição sobre o dinheiro do grupo (M16). Verdadeira: segue para o próximo passo.
## Falsa: salta para o Label `else_label` (vazio = termina o evento).
@export var op: IfFlagStep.Op = IfFlagStep.Op.GE
@export var amount: int = 0
@export var else_label: StringName = &""

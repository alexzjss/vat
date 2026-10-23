class_name ChoiceStep
extends EventStep

## Pergunta com opções; grava na flag o índice escolhido (0 = primeira opção).
@export var prompt: String = ""
@export var options: PackedStringArray = PackedStringArray()
@export var flag: StringName = &""
## Quem pergunta (placa na caixa de diálogo) e a expressão do retrato; vazio = pergunta de sistema, sem placa (M16).
@export var speaker: String = ""
@export var portrait: StringName = &""

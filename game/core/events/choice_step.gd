class_name ChoiceStep
extends EventStep

## Pergunta com opções; grava na flag o índice escolhido (0 = primeira opção).
@export var prompt: String = ""
@export var options: PackedStringArray = PackedStringArray()
@export var flag: StringName = &""

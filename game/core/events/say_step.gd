class_name SayStep
extends EventStep

## Uma fala. `speaker` vazio = texto de sistema (sem placa de nome).
@export var speaker: String = ""
@export_multiline var text: String = ""
## Expressão do retrato de quem fala (M16); vazio = sem retrato. A UI resolve pelo nome do falante.
@export var portrait: StringName = &""

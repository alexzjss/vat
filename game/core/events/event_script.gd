class_name EventScript
extends Resource

## Roteiro de um evento: passos executados em ordem pelo EventRunner. Lê e grava só flags (GameState.flags).
@export var steps: Array[EventStep] = []

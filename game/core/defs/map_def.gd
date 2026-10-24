@tool
class_name MapDef
extends Resource

## Um mapa jogável do registro (M17): id, nome, cena, tipo e, se tiver `$Exit`, o marcador do mapa-múndi onde o jogador reaparece.

enum Kind { CIDADE, INTERIOR, MASMORRA, MUNDO, TESTE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export var kind: Kind = Kind.CIDADE
## Marcador do `overworld` onde o jogador reaparece ao sair pelo `$Exit` deste mapa. Vazio = usa "Start".
@export var exit_spawn: StringName = &""

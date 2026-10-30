@tool
class_name MusicDef
extends Resource

## Uma musica (ou jingle) do M19, tocada no barramento Música.

@export var id: StringName = &""
@export var display_name: String = ""
@export var stream: AudioStream
@export var volume_db: float = 0.0
@export var loop: bool = true

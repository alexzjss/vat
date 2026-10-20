class_name EventRequest
extends RefCounted

## Um passo de apresentação que o EventRunner entrega a quem executa (EventPlayer). O runner
## fica parado até `resume(answer)`.

enum Kind { SAY, CHOICE, MOVE_ACTOR, WAIT, CAMERA_TO, START_BATTLE }

var kind: Kind = Kind.SAY
var speaker: String = ""
var text: String = ""
var options: PackedStringArray = PackedStringArray()
## CHOICE: flag que recebe o índice escolhido.
var flag: StringName = &""
var actor: NodePath = NodePath("")
var marker: NodePath = NodePath("")
var speed: float = 0.0
var seconds: float = 0.0
var encounter: EncounterDef

static func say(p_speaker: String, p_text: String) -> EventRequest:
	var r := EventRequest.new()
	r.kind = Kind.SAY
	r.speaker = p_speaker
	r.text = p_text
	return r

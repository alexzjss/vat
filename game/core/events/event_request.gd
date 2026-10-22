class_name EventRequest
extends RefCounted

## Um passo de apresentação que o EventRunner entrega a quem executa (EventPlayer). O runner
## fica parado até `resume(answer)`.

## Novos valores sempre no fim.
enum Kind { SAY, CHOICE, MOVE_ACTOR, WAIT, CAMERA_TO, START_BATTLE, END_DEMO }

var kind: Kind = Kind.SAY
var speaker: String = ""
var text: String = ""
## SAY: expressão do retrato (M16); vazio = sem retrato.
var portrait: StringName = &""
var options: PackedStringArray = PackedStringArray()
## CHOICE: flag que recebe o índice escolhido.
var flag: StringName = &""
var actor: NodePath = NodePath("")
var marker: NodePath = NodePath("")
var speed: float = 0.0
var seconds: float = 0.0
var encounter: EncounterDef

static func say(p_speaker: String, p_text: String, p_portrait: StringName = &"") -> EventRequest:
	var r := EventRequest.new()
	r.kind = Kind.SAY
	r.speaker = p_speaker
	r.text = p_text
	r.portrait = p_portrait
	return r

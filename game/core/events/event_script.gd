class_name EventScript
extends Resource

## Roteiro de um evento: passos executados em ordem pelo EventRunner. Lê e grava só flags (GameState.flags).
@export var steps: Array[EventStep] = []

## Roteiro montado em código (objetos de dungeon que só mudam estado).
static func of(p_steps: Array[EventStep]) -> EventScript:
	var s := EventScript.new()
	s.steps = p_steps
	return s

static func say(text: String, speaker: String = "") -> SayStep:
	var st := SayStep.new()
	st.speaker = speaker
	st.text = text
	return st

static func set_flag(flag: StringName, value: int) -> SetFlagStep:
	var st := SetFlagStep.new()
	st.flag = flag
	st.value = value
	return st

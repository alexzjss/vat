@tool
class_name SoundDef
extends Resource

## Um efeito sonoro (M19). `pitch_variation` e uma fracao (0.1 = o tom varia de 0.9x a 1.1x a cada toque).

enum Bus { EFFECTS, INTERFACE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var stream: AudioStream
@export var volume_db: float = 0.0
@export_range(0.0, 1.0, 0.01) var pitch_variation: float = 0.0
@export var bus: Bus = Bus.EFFECTS
## Segundos minimos entre dois toques do mesmo som (0 = sem limite).
@export var cooldown: float = 0.0

func bus_name() -> StringName:
	return AudioBuses.INTERFACE if bus == Bus.INTERFACE else AudioBuses.EFFECTS

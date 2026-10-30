class_name AudioBuses
extends RefCounted

## Nomes dos barramentos de audio (`default_bus_layout.tres`) e a conversao de volume. Puro: quem fala com o
## AudioServer e o AudioDirector.

const MASTER: StringName = &"Master"
const MUSIC: StringName = &"Música"
const EFFECTS: StringName = &"Efeitos"
const INTERFACE: StringName = &"Interface"

## Todos os barramentos do layout, na ordem do arquivo (o pai de cada um, exceto o Master, e o Master).
const ALL: Array[StringName] = [&"Master", &"Música", &"Efeitos", &"Interface"]

## Volume do menu (0..max) em dB: escala linear, 0 vira -80 dB (mudo).
static func level_to_db(level: int, level_max: int) -> float:
	var v: float = float(level) / float(maxi(1, level_max))
	return linear_to_db(v) if v > 0.0 else -80.0

## Suspende o ambiente de um mapa (tom do CanvasModulate e luzes) enquanto um fundo de batalha cobre a tela,
## para o fundo e os combatentes aparecerem com as cores originais. `restore` devolve tudo como estava.
class_name MapAmbience
extends RefCounted

## Neutraliza o ambiente de `map` e devolve o estado para `restore`.
static func suspend(map: Node) -> Dictionary:
	var saved: Dictionary = {"modulates": {}, "lights": []}
	for node: Node in map.find_children("*", "CanvasModulate", true, false):
		var cm: CanvasModulate = node as CanvasModulate
		saved["modulates"][cm] = cm.color
		cm.color = Color.WHITE
	for node: Node in map.find_children("*", "Light2D", true, false):
		var light: Light2D = node as Light2D
		if light.enabled:
			saved["lights"].append(light)
			light.enabled = false
	return saved

static func restore(saved: Dictionary) -> void:
	var modulates: Dictionary = saved.get("modulates", {})
	for cm: Variant in modulates:
		if is_instance_valid(cm):
			(cm as CanvasModulate).color = modulates[cm]
	for light: Variant in saved.get("lights", []):
		if is_instance_valid(light):
			(light as Light2D).enabled = true

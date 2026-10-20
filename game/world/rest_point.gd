class_name RestPoint
extends Interactable

## Ponto de descanso: com o jogador dentro da área, a tecla `interact` pede o menu de descanso
## (o sinal `interacted` da base). `spawn_name` é o marcador do mapa gravado no save feito aqui.

@export var spawn_name: StringName = &"RestSpawn"
@export var label_text: String = "Descanso"

func _ready() -> void:
	super._ready()
	var rect: Rect2 = _shape_rect()
	var fill := ColorRect.new()
	fill.color = Color(0.3, 0.8, 0.9, 0.25)
	fill.position = rect.position
	fill.size = rect.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	var label := Label.new()
	label.text = "%s (Enter)" % label_text
	label.position = rect.position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

class_name Npc
extends Interactable

## NPC (M10): losango verde que fala quando o jogador interage. Sólido; o roteiro vem de `event`.
## Pode ser movido por MoveActor (o bloqueio acompanha, é filho).

@export var display_name: String = ""

const COLOR: Color = Color(0.3, 0.8, 0.4)

func _init() -> void:
	solid = true

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(16, 0), Vector2(0, 18), Vector2(-16, 0)]), COLOR)

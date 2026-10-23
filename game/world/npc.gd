class_name Npc
extends Interactable

## NPC (M10): losango verde que fala quando o jogador interage. Sólido; o roteiro vem de `event`.
## Pode ser movido por MoveActor (o bloqueio acompanha, é filho).

@export var display_name: String = ""
## Arte opcional (M16): `speaker.sprites` com folha de mapa troca o losango por um AnimatedSprite2D.
@export var speaker: SpeakerDef

## Os pés ficam na ponta de baixo do losango (y = +18); a colisão não muda.
const FEET_Y: float = 18.0

var map_sprite: MapSprite
var _last_pos: Vector2

const COLOR: Color = Color(0.3, 0.8, 0.4)

func _init() -> void:
	solid = true

func _ready() -> void:
	super._ready()
	if speaker != null:
		map_sprite = MapSprite.create(speaker.sprites, FEET_Y)
	if map_sprite != null:
		add_child(map_sprite)
		_last_pos = global_position
	else:
		set_physics_process(false)

## Vira para onde o NPC anda (MoveActor); parado, mantém a direção.
func _physics_process(_delta: float) -> void:
	if map_sprite == null:
		return
	map_sprite.apply_motion(global_position - _last_pos)
	_last_pos = global_position

func _draw() -> void:
	if map_sprite != null:
		return
	draw_colored_polygon(PackedVector2Array([Vector2(0, -18), Vector2(16, 0), Vector2(0, 18), Vector2(-16, 0)]), COLOR)

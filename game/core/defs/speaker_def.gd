class_name SpeakerDef
extends Resource

## Quem fala ou aparece no mapa sem ser herói (NPCs). Resolvido por `id` ou `display_name` (M16).

@export var id: StringName
@export var display_name: String = ""
@export var sprites: SpriteSet

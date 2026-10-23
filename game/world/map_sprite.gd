class_name MapSprite
extends AnimatedSprite2D

## Sprite de mapa de um personagem (M16), montado em tempo de execução a partir de um [SpriteSet].
## Animações `walk_<dir>` (em laço) e `idle_<dir>` (só o quadro do meio), com dir em down/left/right/up.
## Ancoragem: a borda de baixo do quadro fica em `feet_y`, no espaço do nó dono, e o quadro é centrado em x.
## Quem usa chama [method apply_motion] a cada quadro de física com o deslocamento ou a velocidade.
## Sem movimento a direção anterior é mantida.

var facing: SpriteSet.Facing = SpriteSet.Facing.DOWN
var moving: bool = false
var sprite_set: SpriteSet

## Cria o MapSprite para `sprites`, ou null se o conjunto não tem folha de mapa.
static func create(sprites: SpriteSet, feet_y: float) -> MapSprite:
	if sprites == null or not sprites.has_map_art():
		return null
	var s: MapSprite = MapSprite.new()
	s.setup(sprites, feet_y)
	return s

func setup(sprites: SpriteSet, feet_y: float) -> void:
	sprite_set = sprites
	centered = false
	position = Vector2(-float(sprites.map_frame.x / 2), feet_y - float(sprites.map_frame.y))
	sprite_frames = MapSprite.build_frames(sprites)
	_play()

## SpriteFrames com walk_<dir> e idle_<dir> para as quatro direções.
static func build_frames(sprites: SpriteSet) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	for f: int in SpriteSet.Facing.values():
		var facing_id: SpriteSet.Facing = f as SpriteSet.Facing
		var dir: StringName = SpriteSet.facing_name(facing_id)
		var rects: Array[Rect2i] = sprites.map_frames(facing_id)
		var walk: StringName = StringName("walk_%s" % dir)
		frames.add_animation(walk)
		frames.set_animation_speed(walk, sprites.walk_fps)
		frames.set_animation_loop(walk, true)
		for r: Rect2i in rects:
			frames.add_frame(walk, MapSprite._atlas(sprites.map_sheet, r))
		var idle: StringName = StringName("idle_%s" % dir)
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 1.0)
		frames.set_animation_loop(idle, false)
		if not rects.is_empty():
			frames.add_frame(idle, MapSprite._atlas(sprites.map_sheet, rects[sprites.idle_index()]))
	return frames

static func _atlas(sheet: Texture2D, r: Rect2i) -> AtlasTexture:
	var a: AtlasTexture = AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(r)
	return a

## `motion` (velocidade ou deslocamento do quadro): diferente de zero = andando e vira para ele.
func apply_motion(motion: Vector2) -> void:
	facing = SpriteSet.facing_from(motion, facing)
	moving = motion.length_squared() > 0.0001
	_play()

func animation_for(is_moving: bool, f: SpriteSet.Facing) -> StringName:
	return StringName("%s_%s" % ["walk" if is_moving else "idle", SpriteSet.facing_name(f)])

func _play() -> void:
	var anim: StringName = animation_for(moving, facing)
	if animation != anim:
		play(anim)
	elif moving and not is_playing():
		play(anim)

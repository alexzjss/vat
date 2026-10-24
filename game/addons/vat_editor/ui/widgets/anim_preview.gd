@tool
extends VBoxContainer

## Prévia pequena de UMA animação (M17): uma `SubViewport` com um `AnimatedSprite2D` que toca os quadros de uma linha da
## folha, sempre em laço, ampliado em escala inteira (pixel art). Serve para as 4 direções da folha de mapa e para cada
## linha da tabela de animações de batalha. Os quadros vêm de `Forms.row_rects`, que lê só o tamanho da imagem.

const Forms: GDScript = preload("res://addons/vat_editor/logic/forms.gd")
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)

var box: int = 96
var _caption: Label
var _stage: ColorRect
var _viewport: SubViewport
var _sprite: AnimatedSprite2D
var _frames: int = 0

func _init(p_box: int = 96) -> void:
	box = p_box
	_caption = Label.new()
	_caption.add_theme_color_override("font_color", COLOR_MUTED)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_caption)
	_stage = ColorRect.new()
	_stage.color = Color(0.12, 0.12, 0.15)
	_stage.custom_minimum_size = Vector2(box, box)
	add_child(_stage)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(box, box)
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(box, box) * 0.5
	_viewport.add_child(_sprite)

## Toca a linha `row` de `sheet` (`count` quadros de `frame` px a `fps`). Sem folha ou sem quadros que caibam, mostra o aviso.
func show_row(sheet: Texture2D, frame: Vector2i, row: int, count: int, fps: float, caption: String) -> void:
	var rects: Array[Rect2i] = Forms.row_rects(sheet, frame, row, count) if sheet != null else ([] as Array[Rect2i])
	_frames = rects.size()
	_caption.text = caption if not rects.is_empty() else "%s (fora da folha)" % caption
	_stage.modulate = Color.WHITE if not rects.is_empty() else Color(1, 1, 1, 0.35)
	if rects.is_empty():
		_sprite.stop()
		_sprite.sprite_frames = null
		return
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"play")
	frames.set_animation_speed(&"play", maxf(fps, 1.0))
	frames.set_animation_loop(&"play", true)
	for r: Rect2i in rects:
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = Rect2(r)
		frames.add_frame(&"play", tex)
	_sprite.sprite_frames = frames
	var fit: float = floorf(minf(float(box) / maxf(frame.x, 1), float(box) / maxf(frame.y, 1)))
	_sprite.scale = Vector2.ONE * maxf(fit, 1.0)
	_sprite.play(&"play")

## Quantos quadros estão tocando (0 = nada), para conferir na captura.
func frame_count() -> int:
	return _frames

func is_playing() -> bool:
	return _sprite.is_playing()

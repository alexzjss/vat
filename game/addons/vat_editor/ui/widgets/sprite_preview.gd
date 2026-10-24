@tool
extends VBoxContainer

## Prévia de um `SpriteSet` (M17): uma `SubViewport` com um `AnimatedSprite2D` que toca a animação escolhida (andar do mapa
## nas 4 direções, ou as de batalha), montada como `world/map_sprite.gd` e `battle/battle_sprite.gd`. Os scripts do jogo não
## são `@tool`, então os quadros vêm de `Forms.sprite_animations`, que lê só as propriedades do recurso.

const Forms: GDScript = preload("res://addons/vat_editor/logic/forms.gd")
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)
const VIEW_SIZE: Vector2i = Vector2i(160, 160)

var _info: Label
var _picker: OptionButton
var _stage: ColorRect
var _viewport: SubViewport
var _sprite: AnimatedSprite2D
var _names: Array[StringName] = []
var _frame_size: Dictionary = {}

func _init() -> void:
	_info = Label.new()
	_info.add_theme_color_override("font_color", COLOR_MUTED)
	add_child(_info)
	var row := HBoxContainer.new()
	add_child(row)
	_stage = ColorRect.new()
	_stage.color = Color(0.12, 0.12, 0.15)
	_stage.custom_minimum_size = Vector2(VIEW_SIZE)
	_stage.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_stage)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(VIEW_SIZE) * 0.5
	_viewport.add_child(_sprite)
	_picker = OptionButton.new()
	_picker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_picker.item_selected.connect(func(i: int) -> void: _play(i))
	row.add_child(_picker)
	# as animações que não repetem tocam de novo, para a prévia nunca ficar parada
	_sprite.animation_finished.connect(func() -> void: _sprite.play())

## Mostra o `SpriteSet` (ou o aviso de que não há arte, se null).
func show_sprites(sprites: Resource) -> void:
	_names.clear()
	_picker.clear()
	_frame_size.clear()
	var anims: Dictionary = Forms.sprite_animations(sprites)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for key: Variant in anims:
		var a: Dictionary = anims[key]
		var anim_name: StringName = key
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, a["fps"])
		frames.set_animation_loop(anim_name, false)
		for r: Rect2i in a["rects"]:
			var tex := AtlasTexture.new()
			tex.atlas = a["sheet"]
			tex.region = Rect2(r)
			frames.add_frame(anim_name, tex)
		_names.append(anim_name)
		_picker.add_item("%s: %s" % [a["group"], anim_name])
		_frame_size[anim_name] = (a["rects"] as Array)[0].size
	_sprite.sprite_frames = frames
	_picker.visible = not _names.is_empty()
	_stage.visible = not _names.is_empty()
	if sprites == null:
		_info.text = "Sem arte: o jogo desenha as formas geométricas."
	elif _names.is_empty():
		_info.text = "Este SpriteSet não tem folha de mapa nem de batalha."
	else:
		_info.text = "%d animação(ões)." % _names.size()
	if _names.is_empty():
		_sprite.stop()
		return
	var pick: int = _names.find(&"idle")
	_picker.select(maxi(pick, 0))
	_play(maxi(pick, 0))

func _play(i: int) -> void:
	if i < 0 or i >= _names.size():
		return
	var fs: Vector2i = _frame_size[_names[i]]
	var fit: float = floorf(minf(float(VIEW_SIZE.x) / maxf(fs.x, 1), float(VIEW_SIZE.y) / maxf(fs.y, 1)))
	_sprite.scale = Vector2.ONE * maxf(fit, 1.0)
	_sprite.play(_names[i])

## Animação tocando agora (para conferir na captura).
func current_animation() -> StringName:
	return _sprite.animation if not _names.is_empty() else &""

## Camada de pós-processamento HD-2D (tilt-shift, bloom, gradação, vinheta).
## Fica na camada 0, acima do mundo e abaixo de toda a UI (camadas >= 1).
class_name Hd2dPost
extends CanvasLayer

const SHADER: Shader = preload("res://fx/hd2d_post.gdshader")
## Parâmetros por modo: no mapa a faixa nítida é larga; na batalha estreita e mais borrada.
const MODES: Dictionary[StringName, Dictionary] = {
	&"map": {"focus_y": 0.55, "focus_band": 0.22, "blur_max": 2.2},
	&"battle": {"focus_y": 0.45, "focus_band": 0.28, "blur_max": 3.0},
}
const BLEND_TIME: float = 0.4

var mode: StringName = &"map"
var rect: ColorRect
var _tween: Tween

func _ready() -> void:
	layer = 0
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)
	_apply(MODES[mode], 0.0)

## Troca de modo com transição suave. Modos desconhecidos são ignorados.
func set_mode(new_mode: StringName) -> void:
	if new_mode == mode or not MODES.has(new_mode):
		return
	mode = new_mode
	_apply(MODES[mode], BLEND_TIME)

func set_enabled(on: bool) -> void:
	visible = on

func _apply(params: Dictionary, time: float) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	var mat: ShaderMaterial = rect.material
	if time <= 0.0:
		for key: String in params:
			mat.set_shader_parameter(key, params[key])
		return
	_tween = create_tween().set_parallel()
	for key: String in params:
		var from: float = mat.get_shader_parameter(key)
		_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter(key, v), from, float(params[key]), time)

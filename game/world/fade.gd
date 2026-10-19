class_name Fade
extends CanvasLayer

## Cortina preta em tela cheia para transições de cena (acima da UI da batalha).

signal done

@onready var rect: ColorRect = $Rect

var _tween: Tween

func _ready() -> void:
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0

## Escurece a tela em `time` segundos (awaitável).
func fade_out(time: float) -> void:
	await _fade_to(1.0, time)

## Clareia a tela em `time` segundos (awaitável).
func fade_in(time: float) -> void:
	await _fade_to(0.0, time)

func _fade_to(alpha: float, time: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if time <= 0.0:
		# Mesmo sem duração, espera um quadro: quem chama pode estar num callback de física.
		await get_tree().process_frame
		rect.modulate.a = alpha
		done.emit()
		return
	_tween = create_tween()
	_tween.tween_property(rect, "modulate:a", alpha, time)
	await _tween.finished
	done.emit()

class_name MapCamera
extends Camera2D

var follow: Node2D
var _following: bool = true
var _tween: Tween

func _process(_delta: float) -> void:
	if _following and follow != null:
		global_position = follow.global_position

func slide_to(p: Vector2, time: float) -> void:
	_following = false
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", p, time)

func resume_follow(time: float) -> void:
	_following = false
	_kill_tween()
	if follow == null:
		_following = true
		return
	_tween = create_tween()
	_tween.tween_property(self, "global_position", follow.global_position, time)
	_tween.finished.connect(func() -> void: _following = true)

func set_bounds(r: Rect2) -> void:
	limit_left = int(r.position.x)
	limit_top = int(r.position.y)
	limit_right = int(r.end.x)
	limit_bottom = int(r.end.y)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

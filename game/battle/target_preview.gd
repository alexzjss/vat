class_name TargetPreview
extends Node2D

## Prévia de alvo: círculo (CIRCLE_TARGET/CIRCLE_SELF), faixa (LINE) e anel em quem está
## na área. Só desenha; a área vem de SelectionSession.preview_area().
## Fica abaixo das CombatantView na árvore: a área aparece sob os combatentes.

const AREA_COLOR: Color = Color(1.0, 0.85, 0.3, 0.9)
const AREA_FILL: Color = Color(1.0, 0.85, 0.3, 0.12)
const RING_COLOR: Color = Color(1.0, 0.95, 0.4)
const CURSOR_COLOR: Color = Color(1.0, 1.0, 1.0)
const RING_RADIUS: float = 50.0
const CURSOR_OFFSET: float = 66.0

var session: SelectionSession

func _init() -> void:
	visible = false

func show_for(s: SelectionSession) -> void:
	session = s
	visible = true
	queue_redraw()

func hide_preview() -> void:
	session = null
	visible = false
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func area() -> Array[Combatant]:
	if session == null:
		return []
	return session.preview_area()

func _draw() -> void:
	if session == null or session.center == null:
		return
	var actor_pos: Vector2 = session.actor.position
	var center_pos: Vector2 = session.center.position
	match session.shape():
		AbilityDef.Shape.CIRCLE_TARGET:
			_circle(center_pos, session.radius())
		AbilityDef.Shape.CIRCLE_SELF:
			_circle(actor_pos, session.radius())
		AbilityDef.Shape.LINE:
			_band(actor_pos, center_pos, session.width())
	for c: Combatant in area():
		draw_arc(c.position, RING_RADIUS, 0.0, TAU, 48, RING_COLOR, 3.0, true)
	_cursor(center_pos)

func _circle(p: Vector2, r: float) -> void:
	if r <= 0.0:
		return
	draw_circle(p, r, AREA_FILL)
	draw_arc(p, r, 0.0, TAU, 96, AREA_COLOR, 2.0, true)

func _band(from: Vector2, to: Vector2, w: float) -> void:
	var dir: Vector2 = to - from
	if dir.length() < 0.001 or w <= 0.0:
		return
	var n: Vector2 = dir.normalized().orthogonal() * (w / 2.0)
	var pts := PackedVector2Array([from + n, to + n, to - n, from - n])
	draw_colored_polygon(pts, AREA_FILL)
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, AREA_COLOR, 2.0, true)

func _cursor(p: Vector2) -> void:
	var tip: Vector2 = p + Vector2(0.0, -CURSOR_OFFSET)
	var tri := PackedVector2Array([tip, tip + Vector2(-10.0, -16.0), tip + Vector2(10.0, -16.0)])
	draw_colored_polygon(tri, CURSOR_COLOR)

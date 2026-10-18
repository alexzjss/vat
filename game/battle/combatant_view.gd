class_name CombatantView
extends Node2D

## Geometria provisória de um combatente: quadrado azul (herói) / círculo vermelho (inimigo),
## nome, barras HP/AP/ATB, estados em texto; cinza quando caído; números flutuantes.

const SIZE: float = 64.0
const BAR_W: float = 96.0
const BAR_H: float = 7.0
const HERO_COLOR: Color = Color(0.25, 0.45, 0.95)
const ENEMY_COLOR: Color = Color(0.9, 0.25, 0.25)
const DOWN_COLOR: Color = Color(0.4, 0.4, 0.4)
const STATUS_LABELS: Dictionary[StatusDef.Kind, String] = {
	StatusDef.Kind.POISON: "VEN",
	StatusDef.Kind.SLEEP: "SONO",
	StatusDef.Kind.PARALYSIS: "PAR",
	StatusDef.Kind.HASTE: "PRESSA",
	StatusDef.Kind.SLOW: "LENTO",
	StatusDef.Kind.BARRIER: "BAR",
	StatusDef.Kind.ATTR_MOD: "ATR+",
}

var combatant: Combatant
var cfg: BalanceConfig
var highlighted: bool = false

func bind(c: Combatant, p_cfg: BalanceConfig) -> void:
	combatant = c
	cfg = p_cfg
	position = c.position
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if combatant == null:
		return
	var down: bool = combatant.is_down()
	var half: float = SIZE / 2.0
	if combatant.team == Combatant.Team.HERO:
		draw_rect(Rect2(-half, -half, SIZE, SIZE), DOWN_COLOR if down else HERO_COLOR)
	else:
		draw_circle(Vector2.ZERO, half, DOWN_COLOR if down else ENEMY_COLOR)
	if highlighted:
		draw_rect(Rect2(-half - 4.0, -half - 4.0, SIZE + 8.0, SIZE + 8.0), Color.YELLOW, false, 3.0)
	var font: Font = ThemeDB.fallback_font
	var x0: float = -BAR_W / 2.0
	draw_string(font, Vector2(x0, -half - 10.0), combatant.display_name, HORIZONTAL_ALIGNMENT_CENTER, BAR_W, 16)
	var y: float = half + 8.0
	var hp_max: int = StatCalculator.hp_max(combatant, cfg)
	var ap_max: int = StatCalculator.ap_max(combatant, cfg)
	_bar(Vector2(x0, y), _ratio(combatant.hp, hp_max), Color(0.2, 0.85, 0.3))
	draw_string(font, Vector2(x0 + BAR_W + 4.0, y + BAR_H), "%d/%d" % [combatant.hp, hp_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	y += BAR_H + 4.0
	_bar(Vector2(x0, y), _ratio(combatant.ap, ap_max), Color(0.3, 0.6, 1.0))
	draw_string(font, Vector2(x0 + BAR_W + 4.0, y + BAR_H), "%d/%d" % [combatant.ap, ap_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	y += BAR_H + 4.0
	_bar(Vector2(x0, y), clampf(combatant.atb, 0.0, 1.0), Color(0.95, 0.8, 0.2))
	y += BAR_H + 16.0
	draw_string(font, Vector2(x0, y), status_text(), HORIZONTAL_ALIGNMENT_CENTER, BAR_W, 12)

func _ratio(v: int, m: int) -> float:
	return clampf(float(v) / float(m), 0.0, 1.0) if m > 0 else 0.0

func _bar(origin: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(origin, Vector2(BAR_W * ratio, BAR_H)), color)

func status_text() -> String:
	var parts: PackedStringArray = []
	for s: ActiveStatus in combatant.statuses:
		parts.append(STATUS_LABELS.get(s.def.kind, String(s.def.id)))
	return " ".join(parts)

## Mostra o resultado de um hit de ActionResult sobre este combatente.
func show_hit(hit: Dictionary) -> void:
	var kind: EffectDef.Kind = hit["kind"]
	var amount: int = hit["amount"]
	if hit["dodged"]:
		float_text("Esquiva", Color.WHITE)
		return
	match kind:
		EffectDef.Kind.DAMAGE:
			float_text("-%d" % amount, Color(1.0, 0.4, 0.4))
		EffectDef.Kind.HEAL, EffectDef.Kind.REVIVE:
			float_text("+%d" % amount, Color(0.4, 1.0, 0.5))
		EffectDef.Kind.RESTORE_AP:
			float_text("+%d AP" % amount, Color(0.5, 0.7, 1.0))
		EffectDef.Kind.APPLY_STATUS:
			var res: int = hit["status_result"]
			if res == StatusSystem.ApplyResult.IMMUNE:
				float_text("Imune", Color.WHITE)
			elif res == StatusSystem.ApplyResult.RESISTED:
				float_text("Resistiu", Color.WHITE)

func float_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.position = Vector2(-20.0, -SIZE)
	add_child(label)
	var tw: Tween = label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 40.0, 0.8)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(label.queue_free)

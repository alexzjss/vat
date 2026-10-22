class_name CombatantView
extends Node2D

## Geometria provisória de um combatente: quadrado azul (herói) / círculo vermelho (inimigo),
## nome, barras HP/AP/ATB, estados em texto; cinza quando caído; números flutuantes.

const SIZE: float = 64.0
const BAR_W: float = 96.0
const BAR_H: float = 7.0
## Nome: tamanho base e mínimo da fonte. Nome longo encolhe até o mínimo e, se ainda não couber, termina em "…".
const NAME_SIZE: int = 16
const NAME_MIN_SIZE: int = 10
const ELLIPSIS: String = "…"
## Área ocupada pelo HUD de um inimigo (nome, corpo, barras e números de HP/AP), relativa à posição dele. As arenas
## espaçam os pontos de inimigo para que estes retângulos não se sobreponham.
const HUD_RECT: Rect2 = Rect2(-48.0, -58.0, 150.0, 131.0)
const HERO_COLOR: Color = Color(0.25, 0.45, 0.95)
const ENEMY_COLOR: Color = Color(0.9, 0.25, 0.25)
const LIMIT_COLOR: Color = Color(0.95, 0.55, 0.15)
const LIMIT_FULL_COLOR: Color = Color(1.0, 0.95, 0.5)
const DOWN_COLOR: Color = Color(0.4, 0.4, 0.4)
const CONTAM_COLOR: Color = Color(0.75, 0.95, 0.3)
const BLEED_COLOR: Color = Color(0.85, 0.12, 0.2)
const SELF_DAMAGE_COLOR: Color = Color(1.0, 0.55, 0.45)
## Altura (acima do numero) do rotulo de afinidade / nome do efeito.
const LABEL_LIFT: float = 22.0
const STATUS_LABELS: Dictionary[StatusDef.Kind, String] = {
	StatusDef.Kind.POISON: "VEN",
	StatusDef.Kind.SLEEP: "SONO",
	StatusDef.Kind.PARALYSIS: "PAR",
	StatusDef.Kind.HASTE: "PRESSA",
	StatusDef.Kind.SLOW: "LENTO",
	StatusDef.Kind.BARRIER: "BAR",
	StatusDef.Kind.ATTR_MOD: "ATR+",
	StatusDef.Kind.STOP: "PARE",
	StatusDef.Kind.CONFUSION: "CNF",
	StatusDef.Kind.SILENCE: "SIL",
	StatusDef.Kind.BLIND: "CEG",
	StatusDef.Kind.REGEN: "REG",
}
## Buff/debuff: abreviação do atributo + sinal da potência (FOR+, VEL-...).
const ATTR_LABELS: Dictionary[StringName, String] = {
	&"strength": "FOR",
	&"vitality": "VIT",
	&"speed": "VEL",
	&"aura": "AUR",
}

var combatant: Combatant
var cfg: BalanceConfig
var highlighted: bool = false
## Nucleo de chefe protegido por uma parte (M11): a cena atualiza todo quadro; o HUD avisa "Protegido".
var shielded: bool = false

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
	if combatant.is_charging() and not down:
		draw_arc(Vector2.ZERO, half + 8.0, 0.0, TAU, 40, Color(1.0, 0.6, 0.1), 4.0)
	var font: Font = ThemeDB.fallback_font
	var x0: float = -BAR_W / 2.0
	var fit: Dictionary = fit_name(font, combatant.display_name, BAR_W)
	draw_string(font, Vector2(x0, -half - 10.0), fit["text"], HORIZONTAL_ALIGNMENT_CENTER, BAR_W, fit["size"])
	if shielded and not down:
		draw_string(font, Vector2(x0, -half - 28.0), "Protegido", HORIZONTAL_ALIGNMENT_CENTER, BAR_W, 14, Color(0.55, 0.8, 1.0))
	if combatant.is_charging() and not down:
		draw_string(font, Vector2(x0, -half - 28.0), "Preparando", HORIZONTAL_ALIGNMENT_CENTER, BAR_W, 14, Color(1.0, 0.7, 0.2))
	var contam: String = contamination_text()
	if contam != "" and not down:
		draw_string(font, Vector2(half + 6.0, -half + 12.0), contam, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, CONTAM_COLOR)
	var y: float = half + 8.0
	var hp_max: int = StatCalculator.hp_max(combatant, cfg)
	var ap_max: int = StatCalculator.ap_max(combatant, cfg)
	var shown_hp: int = hp_shown()
	_bar(Vector2(x0, y), _ratio(shown_hp, hp_max), Color(0.2, 0.85, 0.3))
	draw_string(font, Vector2(x0 + BAR_W + 4.0, y + BAR_H), "%d/%d" % [shown_hp, hp_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	y += BAR_H + 4.0
	_bar(Vector2(x0, y), _ratio(combatant.ap, ap_max), Color(0.3, 0.6, 1.0))
	draw_string(font, Vector2(x0 + BAR_W + 4.0, y + BAR_H), "%d/%d" % [combatant.ap, ap_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	y += BAR_H + 4.0
	_bar(Vector2(x0, y), clampf(combatant.atb, 0.0, 1.0), Color(0.95, 0.8, 0.2))
	if combatant.team == Combatant.Team.HERO:
		y += BAR_H + 4.0
		_bar(Vector2(x0, y), clampf(combatant.limit, 0.0, 1.0), limit_color())
	y += BAR_H + 16.0
	draw_string(font, Vector2(x0, y), status_text(), HORIZONTAL_ALIGNMENT_CENTER, BAR_W, 12)

## HP exibido: a corrosao da contaminacao pode deixar o HP acima do maximo por instantes; so a vista limita.
func hp_shown() -> int:
	if combatant == null:
		return 0
	return mini(combatant.hp, StatCalculator.hp_max(combatant, cfg))

## Indicador de contaminacao (M13): vazio em 0.
func contamination_text() -> String:
	if combatant == null or combatant.contamination <= 0:
		return ""
	return "Contam. %d" % combatant.contamination

## Ajusta o nome à largura `max_w`: encolhe a fonte de `base_size` até `min_size`; se ainda passar, corta e termina em "…".
## Devolve {"text": String, "size": int}.
static func fit_name(font: Font, text: String, max_w: float, base_size: int = NAME_SIZE, min_size: int = NAME_MIN_SIZE) -> Dictionary:
	for size: int in range(base_size, min_size - 1, -1):
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
			return {"text": text, "size": size}
	var cut: String = text
	while not cut.is_empty() and font.get_string_size(cut + ELLIPSIS, HORIZONTAL_ALIGNMENT_LEFT, -1, min_size).x > max_w:
		cut = cut.substr(0, cut.length() - 1)
	return {"text": cut + ELLIPSIS, "size": min_size}

## Barra de Limite cheia pisca entre dois tons (relogio de parede; so visual).
func limit_color() -> Color:
	if combatant != null and combatant.limit >= 1.0 and Time.get_ticks_msec() % 500 < 250:
		return LIMIT_FULL_COLOR
	return LIMIT_COLOR

func _ratio(v: int, m: int) -> float:
	return clampf(float(v) / float(m), 0.0, 1.0) if m > 0 else 0.0

func _bar(origin: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), Color(0.15, 0.15, 0.15))
	draw_rect(Rect2(origin, Vector2(BAR_W * ratio, BAR_H)), color)

func status_text() -> String:
	var parts: PackedStringArray = []
	for s: ActiveStatus in combatant.statuses:
		parts.append(status_label(s))
	return " ".join(parts)

static func status_label(s: ActiveStatus) -> String:
	if s.def.kind == StatusDef.Kind.ATTR_MOD and ATTR_LABELS.has(s.def.attr):
		return ATTR_LABELS[s.def.attr] + ("-" if s.def.potency < 0 else "+")
	return STATUS_LABELS.get(s.def.kind, String(s.def.id))

## Mostra o resultado de um hit de ActionResult sobre este combatente.
func show_hit(hit: Dictionary) -> void:
	var kind: EffectDef.Kind = hit["kind"]
	var amount: int = hit["amount"]
	if hit.get("missed", false):
		float_text("Errou", Color.WHITE)
		return
	if hit["dodged"]:
		float_text("Esquiva", Color.WHITE)
		return
	var element_id: StringName = hit.get("element", &"")
	var aff: int = hit.get("affinity", ElementMath.Affinity.NEUTRAL)
	var aff_label: String = ElementText.affinity_label(aff)
	var tint: Color = ElementText.color_of(element_id)
	match kind:
		EffectDef.Kind.DAMAGE:
			if amount == 0 and aff == ElementMath.Affinity.IMMUNE:
				float_text(aff_label, tint)
			elif amount == 0:
				# Ex.: Barreira absorveu todo o dano.
				float_text("Bloqueado", Color.WHITE)
			else:
				float_text(("Protegido -%d" if hit.get("shielded", false) else "-%d") % amount, Color(1.0, 0.4, 0.4))
				if aff_label != "":
					float_text(aff_label, tint, LABEL_LIFT)
			var burst: int = hit.get("burst", 0)
			if burst > 0:
				float_text("Contaminação! -%d" % burst, CONTAM_COLOR, LABEL_LIFT * (2.0 if aff_label != "" else 1.0))
		EffectDef.Kind.HEAL, EffectDef.Kind.REVIVE:
			float_text("+%d" % amount, ElementText.ABSORB_NUMBER_COLOR if aff == ElementMath.Affinity.ABSORB else Color(0.4, 1.0, 0.5))
			if aff_label != "":
				float_text(aff_label, tint, LABEL_LIFT)
		EffectDef.Kind.RESTORE_AP:
			float_text("+%d AP" % amount, Color(0.5, 0.7, 1.0))
		EffectDef.Kind.APPLY_STATUS:
			var res: int = hit["status_result"]
			if res == StatusSystem.ApplyResult.IMMUNE:
				float_text("Imune", Color.WHITE)
			elif res == StatusSystem.ApplyResult.RESISTED:
				float_text("Resistiu", Color.WHITE)

## Efeitos do golpe sobre o atacante: roubo de vida (verde) e dano que o proprio golpe causa nele.
func show_attacker_effects(lifesteal: int, self_damage: int) -> void:
	if lifesteal > 0:
		float_text("+%d" % lifesteal, ElementText.ABSORB_NUMBER_COLOR)
	if self_damage > 0:
		float_text("-%d" % self_damage, SELF_DAMAGE_COLOR, LABEL_LIFT if lifesteal > 0 else 0.0)

## Sangramento cobrou quando o afetado agiu: numero e o nome do estado.
func show_bleed(amount: int) -> void:
	float_text("-%d" % amount, BLEED_COLOR)
	float_text("Sangramento", BLEED_COLOR, LABEL_LIFT)

func float_text(text: String, color: Color, lift: float = 0.0) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.position = Vector2(-20.0, -SIZE - lift)
	add_child(label)
	var tw: Tween = label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 40.0, 0.8)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(label.queue_free)

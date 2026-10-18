class_name DebugPanel
extends Control

## Painel de debug (F1): fila ATB, ação em execução, estados e tabela de contribuição.
## O texto é montado só a partir do estado (build_text); refresh só atribui quando visível.

var _label: Label

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	_label = Label.new()
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 12)
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 6.0
	_label.offset_top = 4.0
	_label.clip_text = true
	add_child(_label)

func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode == KEY_F1:
		toggle()

func toggle() -> void:
	visible = not visible

func text() -> String:
	return _label.text

func refresh(b: BattleState, ctrl: BattleController) -> void:
	if not visible:
		return
	_label.text = build_text(b, ctrl)

func build_text(b: BattleState, ctrl: BattleController) -> String:
	var lines: PackedStringArray = []
	lines.append("Fila ATB")
	var order: Array[Combatant] = b.queue.ordered()
	if order.is_empty():
		lines.append("  -")
	for i: int in order.size():
		var c: Combatant = order[i]
		lines.append("  %d. %s (Vel %d)" % [i + 1, c.id, StatCalculator.effective(c, &"speed", b.cfg)])
	lines.append(_executing_line(ctrl))
	lines.append("Estados")
	var any_status: bool = false
	for c: Combatant in b.all():
		if c.statuses.is_empty():
			continue
		any_status = true
		var parts: PackedStringArray = []
		for s: ActiveStatus in c.statuses:
			var p: String = "%s (%d) ← %s" % [s.def.id, s.remaining, s.source_id]
			if s.def.kind == StatusDef.Kind.BARRIER:
				p += " [%d]" % s.barrier_left
			parts.append(p)
		lines.append("  %s: %s" % [c.id, ", ".join(parts)])
	if not any_status:
		lines.append("  -")
	lines.append("Contribuição")
	var data: Dictionary = b.ledger.entries()
	var enemy_ids: Array = data.keys()
	enemy_ids.sort()
	if enemy_ids.is_empty():
		lines.append("  -")
	for eid: StringName in enemy_ids:
		lines.append("  %s:" % eid)
		var per: Dictionary = data[eid]
		var hero_ids: Array = per.keys()
		hero_ids.sort()
		for hid: StringName in hero_ids:
			lines.append("    %s: %.1f" % [hid, float(per[hid])])
		lines.append("    total: %.1f" % b.ledger.total_against(eid))
	lines.append("Wait: %s" % ("sim" if ctrl.is_paused() else "não"))
	return "\n".join(lines)

func _executing_line(ctrl: BattleController) -> String:
	var a: PendingAction = ctrl.executing
	if a == null:
		return "Executando: -"
	var name: String = a.item.display_name if a.item != null else a.ability.display_name
	return "Executando: %s -> %s %.2f/%.2f" % [a.actor.id, name, a.elapsed, a.cast_time(ctrl.b.cfg)]

@tool
extends HBoxContainer

## Os 4 atributos de um `Stats` (M17): Força, Velocidade, Vitalidade e Aura. Edita o `Stats` no lugar.

signal changed

const ATTRS: Array[StringName] = [&"strength", &"speed", &"vitality", &"aura"]
const LABELS: Array[String] = ["Força", "Velocidade", "Vitalidade", "Aura"]

var stats: Resource

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func bind(p_stats: Resource) -> void:
	stats = p_stats
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for i: int in ATTRS.size():
		var l := Label.new()
		l.text = LABELS[i]
		add_child(l)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 9999
		spin.step = 1
		spin.value = int(stats.get(ATTRS[i])) if stats != null else 0
		spin.editable = stats != null
		spin.custom_minimum_size.x = 80
		var attr: StringName = ATTRS[i]
		spin.value_changed.connect(func(v: float) -> void:
			stats.set(attr, int(v))
			changed.emit())
		add_child(spin)

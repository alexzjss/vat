@tool
extends VBoxContainer

## Editor de um dicionário "id -> fração" mostrado em porcentagem (M17): a chave é escolhida numa lista, o valor é um campo em
## % com a dica do sinal (resiste, fraqueza, imune, absorve). Edita o próprio dicionário tipado, no lugar. Base de
## `ElementDictEditor` (element_dict_editor.gd) e `StatusDictEditor` (status_dict_editor.gd).

const Forms: GDScript = preload("res://addons/vat_editor/logic/forms.gd")
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)

signal changed

## Dica do sinal: elementos absorvem acima de 100%, estados só chegam a imune.
var absorbs: bool = true
var help: String = ""
var dict: Dictionary = {}
var choices: Array[Dictionary] = []
var _rows: VBoxContainer
var _add: Button

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func bind(p_dict: Dictionary, p_choices: Array[Dictionary]) -> void:
	dict = p_dict
	choices = p_choices
	_rebuild()

## O texto de uma opção na lista (as subclasses trocam).
func choice_label(c: Dictionary) -> String:
	return c["label"]

func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	if help != "":
		var h := Label.new()
		h.text = help
		h.add_theme_color_override("font_color", COLOR_MUTED)
		add_child(h)
	_rows = VBoxContainer.new()
	add_child(_rows)
	for k: Variant in dict.keys():
		_rows.add_child(_make_row(k as StringName))
	_add = Button.new()
	_add.text = "+ Adicionar"
	_add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add.pressed.connect(_on_add)
	_add.disabled = Forms.dict_next_free(dict, Forms.choice_ids(choices)) == &""
	add_child(_add)

func _make_row(key: StringName) -> Control:
	var row := HBoxContainer.new()
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(8, 8)
	swatch.color = _color_of(key)
	row.add_child(swatch)
	var pick := OptionButton.new()
	pick.custom_minimum_size.x = 170
	pick.clip_text = true
	var at: int = -1
	for i: int in choices.size():
		pick.add_item(choice_label(choices[i]))
		if choices[i]["id"] == key:
			at = i
	if at == -1:
		pick.add_item("%s (fora da lista)" % key)
		at = choices.size()
	pick.select(at)
	row.add_child(pick)
	var spin := SpinBox.new()
	spin.min_value = -1000.0
	spin.max_value = 1000.0
	spin.step = 0.01
	spin.custom_arrow_step = 1.0
	spin.suffix = "%"
	spin.value = Forms.dict_percent(dict, key)
	spin.custom_minimum_size.x = 110
	row.add_child(spin)
	var hint := Label.new()
	hint.text = Forms.sign_hint(spin.value, absorbs)
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.custom_minimum_size.x = 70
	row.add_child(hint)
	var remove := Button.new()
	remove.text = "✕"
	remove.tooltip_text = "Remover"
	row.add_child(remove)
	var current: Array[StringName] = [key]
	spin.value_changed.connect(func(v: float) -> void:
		Forms.dict_set_percent(dict, current[0], v)
		hint.text = Forms.sign_hint(v, absorbs)
		changed.emit())
	pick.item_selected.connect(func(i: int) -> void:
		if i >= choices.size():
			return
		var to: StringName = choices[i]["id"]
		if Forms.dict_rename(dict, current[0], to):
			current[0] = to
			swatch.color = _color_of(to)
			changed.emit()
		else:
			pick.select(_index_of(current[0])))
	remove.pressed.connect(func() -> void:
		dict.erase(current[0])
		_rebuild()
		changed.emit())
	return row

func _index_of(key: StringName) -> int:
	for i: int in choices.size():
		if choices[i]["id"] == key:
			return i
	return choices.size()

func _color_of(key: StringName) -> Color:
	for c: Dictionary in choices:
		if c["id"] == key and c["value"] is Resource:
			var col: Variant = (c["value"] as Resource).get(&"color")
			if col is Color:
				return col
	return Color(0, 0, 0, 0)

func _on_add() -> void:
	var key: StringName = Forms.dict_next_free(dict, Forms.choice_ids(choices))
	if key == &"":
		return
	Forms.dict_set_percent(dict, key, 0.0)
	_rebuild()
	changed.emit()

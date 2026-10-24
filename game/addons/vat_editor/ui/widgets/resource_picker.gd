@tool
extends HBoxContainer

## Seletor de um recurso (ou nome) de uma lista (M17): um campo de busca e a lista suspensa, com "(nenhum)". As opções vêm
## de `Forms.choices(fonte)`: `[{value, id, label}]`. O valor é o próprio recurso (ou o `StringName`); o recurso atual aparece
## sempre na lista, mesmo que a busca o esconda ou que ele não esteja nas pastas do Banco.

signal picked(value: Variant)

const NONE_LABEL: String = "(nenhum)"

var allow_none: bool = true
var _options: Array[Dictionary] = []
var _value: Variant = null
var _filter: LineEdit
var _menu: OptionButton
## Índice (em `_options`) de cada item do menu; -1 = "(nenhum)", -2 = o valor atual fora da lista.
var _map: Array[int] = []

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter = LineEdit.new()
	_filter.placeholder_text = "Buscar"
	_filter.clear_button_enabled = true
	_filter.custom_minimum_size.x = 90
	_filter.text_changed.connect(func(_t: String) -> void: _rebuild())
	add_child(_filter)
	_menu = OptionButton.new()
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu.fit_to_longest_item = false
	_menu.clip_text = true
	_menu.item_selected.connect(_on_selected)
	add_child(_menu)

func setup(options: Array[Dictionary], value: Variant, p_allow_none: bool = true) -> void:
	_options = options
	_value = value
	allow_none = p_allow_none
	_filter.text = ""
	_rebuild()

func get_value() -> Variant:
	return _value

func set_value(value: Variant) -> void:
	_value = value
	_rebuild()

static func same(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return a == null and b == null
	if a is Resource and b is Resource:
		var ra: Resource = a
		var rb: Resource = b
		return ra == rb or (ra.resource_path != "" and ra.resource_path == rb.resource_path)
	return a == b

func _label_of_value(value: Variant) -> String:
	if value is Resource:
		var r: Resource = value
		var id: String = str(r.get(&"id"))
		return id if id != "" else r.resource_path.get_file()
	return str(value)

func _rebuild() -> void:
	_menu.clear()
	_map.clear()
	var needle: String = _filter.text.strip_edges().to_lower()
	if allow_none:
		_menu.add_item(NONE_LABEL)
		_map.append(-1)
	var selected: int = 0
	var found: bool = _value == null
	for i: int in _options.size():
		var c: Dictionary = _options[i]
		var is_current: bool = same(c["value"], _value)
		if is_current:
			found = true
		if needle != "" and not is_current and not (c["label"] as String).to_lower().contains(needle):
			continue
		_menu.add_item(c["label"])
		_map.append(i)
		if is_current:
			selected = _map.size() - 1
	if not found:
		_menu.add_item("%s (fora da lista)" % _label_of_value(_value))
		_map.append(-2)
		selected = _map.size() - 1
	if _menu.item_count > 0:
		_menu.select(selected)

func _on_selected(item: int) -> void:
	if item < 0 or item >= _map.size():
		return
	var at: int = _map[item]
	if at == -2:
		return
	_value = null if at == -1 else _options[at]["value"]
	picked.emit(_value)

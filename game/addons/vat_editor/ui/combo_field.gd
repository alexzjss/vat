@tool
extends HBoxContainer

## Campo de texto com uma lista de sugestões (M17): digita-se livremente (um falante novo, uma flag nova, um rótulo
## ainda não declarado) ou escolhe-se na lista. A lista vem de `suggestions: Callable() -> Array[String]` e é lida
## só ao abrir o menu, então reflete o estado de agora.

signal value_changed(text: String)

var suggestions: Callable
var edit: LineEdit
var menu: MenuButton
var _items: Array[String] = []

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit = LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(func(t: String) -> void: value_changed.emit(t))
	add_child(edit)
	menu = MenuButton.new()
	menu.text = "▾"
	menu.flat = false
	menu.tooltip_text = "Escolher da lista"
	var popup: PopupMenu = menu.get_popup()
	popup.about_to_popup.connect(_fill)
	popup.index_pressed.connect(_picked)
	add_child(menu)

var text: String:
	get:
		return edit.text
	set(v):
		edit.text = v

func _fill() -> void:
	var popup: PopupMenu = menu.get_popup()
	popup.clear()
	_items = []
	if suggestions.is_valid():
		_items.assign(suggestions.call())
	for s: String in _items:
		popup.add_item(s)
	if _items.is_empty():
		popup.add_item("(sem sugestões)")
		popup.set_item_disabled(0, true)

func _picked(i: int) -> void:
	if i >= 0 and i < _items.size():
		edit.text = _items[i]
		value_changed.emit(_items[i])

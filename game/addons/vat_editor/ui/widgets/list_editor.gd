@tool
extends VBoxContainer

## Lista editável genérica (M17): uma linha por item, com subir, descer, duplicar e remover, e "Adicionar" no fim. Edita o
## próprio array (tipado) no lugar, pela lógica de `forms.gd`. O conteúdo de cada linha vem de uma fábrica.
##   make_row: Callable(item: Variant, index: int) -> Control
##   make_item: Callable() -> Variant   (o que "Adicionar" põe; sem ela, null)
## `changed` sai a cada mudança de estrutura (adicionar, remover, mover, duplicar); a fábrica avisa as edições de dentro.

const Forms: GDScript = preload("res://addons/vat_editor/logic/forms.gd")
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)

signal changed

var items: Array = []
var make_row: Callable
var make_item: Callable
var max_items: int = 0
var add_text: String = "+ Adicionar"
var empty_text: String = "(vazio)"
var _rows: VBoxContainer
var _add: Button

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func bind(p_items: Array, p_make_row: Callable, p_make_item: Callable = Callable(), p_max: int = 0) -> void:
	items = p_items
	make_row = p_make_row
	make_item = p_make_item
	max_items = p_max
	rebuild()

func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rows = VBoxContainer.new()
	add_child(_rows)
	if items.is_empty():
		var e := Label.new()
		e.text = empty_text
		e.add_theme_color_override("font_color", COLOR_MUTED)
		_rows.add_child(e)
	for i: int in items.size():
		_rows.add_child(_make_line(i))
	_add = Button.new()
	_add.text = add_text
	_add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add.disabled = max_items > 0 and items.size() >= max_items
	_add.pressed.connect(_on_add)
	add_child(_add)

func _make_line(i: int) -> Control:
	var line := HBoxContainer.new()
	var n := Label.new()
	n.text = "%d." % (i + 1)
	n.custom_minimum_size.x = 24
	n.add_theme_color_override("font_color", COLOR_MUTED)
	n.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	line.add_child(n)
	var content: Control = make_row.call(items[i], i) as Control
	if content == null:
		content = Label.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(content)
	var up: Button = _tool(line, "↑", "Subir")
	up.disabled = i == 0
	up.pressed.connect(func() -> void: _apply(Forms.list_move(items, i, -1) != i))
	var down: Button = _tool(line, "↓", "Descer")
	down.disabled = i == items.size() - 1
	down.pressed.connect(func() -> void: _apply(Forms.list_move(items, i, 1) != i))
	var dup: Button = _tool(line, "⧉", "Duplicar")
	dup.disabled = max_items > 0 and items.size() >= max_items
	dup.pressed.connect(func() -> void: _apply(Forms.list_duplicate(items, i) >= 0))
	var rm: Button = _tool(line, "✕", "Remover")
	rm.pressed.connect(func() -> void: _apply(Forms.list_remove(items, i)))
	return line

func _tool(parent: Node, text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(b)
	return b

func _apply(did_change: bool) -> void:
	if not did_change:
		return
	rebuild()
	changed.emit()

func _on_add() -> void:
	if max_items > 0 and items.size() >= max_items:
		return
	var item: Variant = make_item.call() if make_item.is_valid() else null
	Forms.list_add(items, item)
	rebuild()
	changed.emit()

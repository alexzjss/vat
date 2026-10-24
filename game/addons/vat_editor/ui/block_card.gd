@tool
extends PanelContainer

## Cartão de um bloco do roteiro (M17): o título do tipo e os campos dele (LineEdit, TextEdit, SpinBox, OptionButton ou
## a lista com digitação), mais subir, descer, duplicar e apagar. Edita o `RoteiroBlock` na hora; quem monta os cartões
## escuta os sinais. Os campos de cada tipo vêm de `roteiro_editor_logic.gd`, as listas dos menus de `ctx`:
##
## `ctx` (Callables): `ids(kind) -> Array[String]`, `display(kind, id) -> String`, `speakers() -> Array[String]`,
## `expressions(speaker) -> Array[String]`, `flags() -> Array[String]`, `labels() -> Array[String]`.

const Logic: GDScript = preload("res://addons/vat_editor/logic/roteiro_editor_logic.gd")
const ComboField: GDScript = preload("res://addons/vat_editor/ui/combo_field.gd")

## Um campo mudou (sem mudar a estrutura): o dono só recompila.
signal edited
## A forma do cartão mudou (opções de uma escolha, conversão): o dono remonta os cartões.
signal restructure
signal move_requested(direction: int)
signal duplicate_requested
signal delete_requested
## O usuário mexeu neste cartão (ponto de inserção do próximo "+ Adicionar bloco").
signal touched

const COLOR_RAW: Color = Color(1.0, 0.85, 0.4)
const COLOR_ERROR: Color = Color(1.0, 0.4, 0.4)
const COLOR_TITLE: Color = Color(0.75, 0.85, 1.0)
const KIND_OF_FIELD: Dictionary = {
	"item": &"item", "equip": &"equip", "hero": &"hero", "ability": &"ability", "encounter": &"encounter",
}

var block: RoteiroBlock
var ctx: Dictionary = {}
var _style: StyleBoxFlat
## Avisos em vermelho por campo (`field_error`), criados junto com os controles.
var _hints: Dictionary = {}

func setup(p_block: RoteiroBlock, p_ctx: Dictionary) -> void:
	block = p_block
	ctx = p_ctx
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.16, 0.18, 0.22)
	_style.set_corner_radius_all(4)
	_style.set_border_width_all(2)
	_style.border_color = Color(0.16, 0.18, 0.22)
	_style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", _style)
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(_header())
	var specs: Array[Dictionary] = Logic.fields(block.kind)
	if not specs.is_empty():
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 4)
		box.add_child(grid)
		for spec: Dictionary in specs:
			var label := Label.new()
			label.text = spec["label"]
			label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			grid.add_child(label)
			var control: Control = _control_for(spec)
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(control)
	gui_input.connect(_on_gui_input)

func set_highlight(on: bool) -> void:
	_style.border_color = Color(1.0, 0.45, 0.4) if on else Color(0.16, 0.18, 0.22)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		touched.emit()

func _header() -> Control:
	var row := HBoxContainer.new()
	var title := Label.new()
	title.text = Logic.title(block.kind)
	title.add_theme_color_override("font_color", COLOR_RAW if block.kind == RoteiroBlock.Kind.OUTRO else COLOR_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_icon_button(row, "▲", "Subir", func() -> void: move_requested.emit(-1))
	_icon_button(row, "▼", "Descer", func() -> void: move_requested.emit(1))
	_icon_button(row, "Duplicar", "Copiar este bloco logo abaixo", func() -> void: duplicate_requested.emit())
	_icon_button(row, "Apagar", "Apagar este bloco", func() -> void: delete_requested.emit())
	return row

func _icon_button(parent: Node, text: String, tip: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void:
		touched.emit()
		handler.call())
	parent.add_child(b)

func _write(field: String, value: Variant) -> void:
	var error: String = Logic.field_error(block, field, value)
	var hint: Label = _hints.get(field) as Label
	if hint != null:
		hint.text = error
		hint.visible = error != ""
	Logic.set_field(block, field, value)
	touched.emit()
	edited.emit()

func _control_for(spec: Dictionary) -> Control:
	var field: String = spec["name"]
	match str(spec["type"]):
		"speaker":
			return _combo(field, func() -> Array[String]: return _call_list(&"speakers"))
		"expr":
			return _combo(field, func() -> Array[String]: return _call_list(&"expressions", block.speaker))
		"flag":
			return _combo(field, func() -> Array[String]: return _call_list(&"flags"))
		"label":
			return _combo(field, func() -> Array[String]: return _call_list(&"labels"))
		"line", "newlabel", "text":
			var le := LineEdit.new()
			le.text = str(Logic.get_field(block, field))
			le.text_changed.connect(func(t: String) -> void: _write(field, t))
			return le
		"multiline":
			return _multiline(field)
		"item", "equip", "hero", "ability", "encounter":
			return _picker(field, KIND_OF_FIELD[str(spec["type"])])
		"op":
			return _op_picker(field)
		"int", "pct":
			return _spin(field, spec, 1.0)
		"float":
			return _spin(field, spec, float(spec.get("step", 0.1)))
		"bool":
			var cb := CheckBox.new()
			cb.button_pressed = bool(Logic.get_field(block, field))
			cb.toggled.connect(func(on: bool) -> void: _write(field, on))
			return cb
		"options":
			return _options_editor()
		"raw":
			return _raw_view()
	return Label.new()

func _call_list(key: StringName, arg: Variant = null) -> Array[String]:
	var out: Array[String] = []
	var c: Callable = ctx.get(key, Callable())
	if c.is_valid():
		out.assign(c.call() if arg == null else c.call(arg))
	return out

func _combo(field: String, source: Callable) -> Control:
	var cf: HBoxContainer = ComboField.new()
	cf.suggestions = source
	cf.text = str(Logic.get_field(block, field))
	cf.value_changed.connect(func(t: String) -> void: _write(field, t))
	if field != "speaker":
		return cf
	# O falante recusado (começa com `# @ ? * | = -`) mantém o valor anterior: o aviso vermelho diz por quê.
	var col := VBoxContainer.new()
	col.add_child(cf)
	var hint := Label.new()
	hint.add_theme_color_override("font_color", COLOR_ERROR)
	hint.visible = false
	col.add_child(hint)
	_hints[field] = hint
	return col

func _multiline(field: String) -> Control:
	var te := TextEdit.new()
	te.text = str(Logic.get_field(block, field))
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.scroll_fit_content_height = true
	te.custom_minimum_size = Vector2(240, 54)
	te.text_changed.connect(func() -> void: _write(field, te.text))
	return te

## Lista fechada de ids: "(nenhum)", os do conteúdo e, se o valor atual não existe, ele mesmo marcado.
func _picker(field: String, kind: StringName) -> Control:
	var ob := OptionButton.new()
	var current: String = str(Logic.get_field(block, field))
	var ids: Array[String] = []
	var ids_call: Callable = ctx.get(&"ids", Callable())
	if ids_call.is_valid():
		ids.assign(ids_call.call(kind))
	var shown: Callable = ctx.get(&"display", Callable())
	ob.add_item("(nenhum)")
	ob.set_item_metadata(0, "")
	var select: int = 0
	for id: String in ids:
		ob.add_item(str(shown.call(kind, id)) if shown.is_valid() else id)
		ob.set_item_metadata(ob.item_count - 1, id)
		if id == current:
			select = ob.item_count - 1
	if current != "" and select == 0:
		ob.add_item("%s (não existe)" % current)
		ob.set_item_metadata(ob.item_count - 1, current)
		select = ob.item_count - 1
	ob.selected = select
	ob.item_selected.connect(func(i: int) -> void: _write(field, str(ob.get_item_metadata(i))))
	return ob

func _op_picker(field: String) -> Control:
	var ob := OptionButton.new()
	var ops: Array[String] = ["==", "!=", ">=", "<=", ">", "<"]
	for o: String in ops:
		ob.add_item(o)
	ob.selected = maxi(0, ops.find(str(Logic.get_field(block, field))))
	ob.item_selected.connect(func(i: int) -> void: _write(field, ops[i]))
	return ob

func _spin(field: String, spec: Dictionary, step: float) -> Control:
	var sb := SpinBox.new()
	sb.min_value = float(spec.get("min", -999999))
	sb.max_value = float(spec.get("max", 999999))
	sb.step = step
	sb.value = float(Logic.get_field(block, field))
	sb.custom_minimum_size = Vector2(110, 0)
	sb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sb.value_changed.connect(func(v: float) -> void: _write(field, v))
	return sb

func _raw_view() -> Control:
	var col := VBoxContainer.new()
	var raw := Label.new()
	raw.text = block.text
	raw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raw.add_theme_color_override("font_color", COLOR_RAW)
	col.add_child(raw)
	var hint := Label.new()
	hint.text = "O compilador não entende esta linha (veja o erro no rodapé). Ela se mantém como está."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	col.add_child(hint)
	var btn := Button.new()
	btn.text = "Converter em comentário"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	btn.pressed.connect(func() -> void:
		Logic.convert_to_comment(block)
		edited.emit()
		restructure.emit())
	col.add_child(btn)
	return col

# --- opções de uma escolha ---

func _options_editor() -> Control:
	var col := VBoxContainer.new()
	for i: int in block.options.size():
		col.add_child(_option_row(i))
	var add := Button.new()
	add.text = "+ Opção"
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add.disabled = block.options.size() >= Logic.MAX_OPTIONS
	add.tooltip_text = "No máximo %d opções" % Logic.MAX_OPTIONS
	add.pressed.connect(func() -> void:
		if Logic.add_option(block):
			edited.emit()
			restructure.emit())
	col.add_child(add)
	return col

func _option_row(i: int) -> Control:
	var row := HBoxContainer.new()
	var n := Label.new()
	n.text = "%d." % (i + 1)
	row.add_child(n)
	var text := LineEdit.new()
	text.placeholder_text = "Texto da opção"
	text.text = block.options[i].text
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var arrow := Label.new()
	arrow.text = "→"
	row.add_child(arrow)
	var label: HBoxContainer = ComboField.new()
	label.suggestions = func() -> Array[String]: return _call_list(&"labels")
	label.text = String(block.options[i].label)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var apply: Callable = func(_t: String = "") -> void:
		Logic.set_option(block, i, text.text, label.text)
		touched.emit()
		edited.emit()
	text.text_changed.connect(apply)
	label.value_changed.connect(apply)
	var remove := Button.new()
	remove.text = "✕"
	remove.tooltip_text = "Tirar esta opção (a escolha mantém ao menos uma)"
	remove.disabled = block.options.size() <= 1
	remove.pressed.connect(func() -> void:
		if Logic.remove_option(block, i):
			edited.emit()
			restructure.emit())
	row.add_child(remove)
	return row

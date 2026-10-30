@tool
extends PanelContainer

## Cartão de um bloco do roteiro (M17): o título do tipo e os campos dele (LineEdit, TextEdit, SpinBox, OptionButton ou
## a lista com digitação), mais subir, descer, duplicar e apagar. Edita o `RoteiroBlock` na hora; quem monta os cartões
## escuta os sinais. Os campos de cada tipo vêm de `roteiro_editor_logic.gd`, as listas dos menus de `ctx`:
##
## `ctx` (Callables): `ids(kind) -> Array[String]`, `display(kind, id) -> String`, `speakers() -> Array[String]`,
## `expressions(speaker) -> Array[String]`, `flags() -> Array[String]`, `labels() -> Array[String]`.
##
## Arrastar (M18): o título é a alça (`_get_drag`); o cartão inteiro, campos incluídos, aceita a soltura (o `Control` do
## Godot só repassa para o pai quando o filho não trata, então todos os filhos recebem o mesmo encaminhamento) e mostra
## uma linha acima ou abaixo conforme a metade em que o mouse está. Quem monta os cartões põe `index` e `drop_filter`.

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
## Soltaram o bloco `from_index` em cima deste cartão (`after`: na metade de baixo).
signal drop_requested(from_index: int, after: bool)

## Chave do dicionário que o arrastar leva: o índice do bloco no modelo.
const DRAG_KEY: String = "vat_block"
const COLOR_DROP: Color = Color(0.4, 0.8, 1.0)

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
## Posição do bloco no modelo (a lista que o dono edita); -1 até o dono dizer.
var index: int = -1
## `(from_index, hovered_index, after) -> bool`: soltar ali mudaria alguma coisa? Sem filtro, sempre.
var drop_filter: Callable = Callable()
var _title: Label
var _overlay: Control
## Onde a linha de soltura aparece: -1 em cima, 1 embaixo, 0 em lugar nenhum.
var _mark: int = 0

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
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_mark)
	add_child(_overlay)
	_forward_drops(self)

func set_highlight(on: bool) -> void:
	_style.border_color = Color(1.0, 0.45, 0.4) if on else Color(0.16, 0.18, 0.22)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		touched.emit()

func _header() -> Control:
	var row := HBoxContainer.new()
	var title := Label.new()
	_title = title
	title.text = Logic.title(block.kind)
	# A alça do arrastar: o título (um Label ignora o mouse por padrão).
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.mouse_default_cursor_shape = Control.CURSOR_DRAG
	title.tooltip_text = "Arraste para reordenar (cuidado com rótulos, desvios e escolhas: mover muda o que roda)"
	title.set_drag_forwarding(_get_drag, _can_drop_from.bind(title), _drop_from.bind(title))
	title.gui_input.connect(_on_gui_input)
	title.add_theme_color_override("font_color", COLOR_RAW if block.kind == RoteiroBlock.Kind.OUTRO else COLOR_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	_icon_button(row, "▲", "Subir", func() -> void: move_requested.emit(-1))
	_icon_button(row, "▼", "Descer", func() -> void: move_requested.emit(1))
	_icon_button(row, "Duplicar", "Copiar este bloco logo abaixo", func() -> void: duplicate_requested.emit())
	_icon_button(row, "Apagar", "Apagar este bloco", func() -> void: delete_requested.emit())
	return row

# --- arrastar e soltar ---

func _get_drag(_at: Vector2) -> Variant:
	touched.emit()
	var preview := Label.new()
	preview.text = "%s  (%s)" % [Logic.title(block.kind), _summary()]
	preview.add_theme_color_override("font_color", COLOR_TITLE)
	preview.add_theme_stylebox_override("normal", _style)
	_title.set_drag_preview(preview)
	return {DRAG_KEY: index}

## Um resumo curto do bloco para a prévia do arrastar: o primeiro campo de texto que tiver.
func _summary() -> String:
	for key: String in ["text", "target", "ref"]:
		var v: String = str(block.get(key)).replace("\n", " ").strip_edges()
		if v != "":
			return v.left(32) + ("..." if v.length() > 32 else "")
	return "sem texto"

## Todo `Control` do cartão (e ele mesmo) aceita a soltura; a posição vem sempre em coordenadas do cartão.
func _forward_drops(root: Control) -> void:
	for c: Node in root.find_children("*", "Control", true, false):
		var ctrl: Control = c as Control
		if ctrl == _title or ctrl == _overlay:
			continue
		ctrl.set_drag_forwarding(Callable(), _can_drop_from.bind(ctrl), _drop_from.bind(ctrl))
	set_drag_forwarding(Callable(), _can_drop, _drop)

func _can_drop_from(at: Vector2, data: Variant, ctrl: Control) -> bool:
	return _can_drop(_to_card(at, ctrl), data)

func _drop_from(at: Vector2, data: Variant, ctrl: Control) -> void:
	_drop(_to_card(at, ctrl), data)

func _to_card(at: Vector2, ctrl: Control) -> Vector2:
	return get_global_transform().affine_inverse() * (ctrl.get_global_transform() * at)

func _is_block_drag(data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has(DRAG_KEY)

func _is_after(at: Vector2) -> bool:
	return at.y > size.y * 0.5

## Aceita se for um bloco e se soltar aqui mudar algo; desenha a linha acima ou abaixo.
func _can_drop(at: Vector2, data: Variant) -> bool:
	if not _is_block_drag(data):
		return false
	var after: bool = _is_after(at)
	var ok: bool = not drop_filter.is_valid() or bool(drop_filter.call(int((data as Dictionary)[DRAG_KEY]), after))
	if ok:
		show_drop_mark(1 if after else -1)
	else:
		show_drop_mark(0)
	return ok

func _drop(at: Vector2, data: Variant) -> void:
	show_drop_mark(0)
	if _is_block_drag(data):
		drop_requested.emit(int((data as Dictionary)[DRAG_KEY]), _is_after(at))

## A linha de soltura: -1 em cima do cartão, 1 embaixo, 0 apaga.
func show_drop_mark(where: int) -> void:
	if where == _mark:
		return
	_mark = where
	if _overlay != null:
		_overlay.queue_redraw()

func drop_mark() -> int:
	return _mark

func _draw_mark() -> void:
	if _mark == 0:
		return
	var y: float = -4.0 if _mark < 0 else _overlay.size.y + 4.0
	_overlay.draw_rect(Rect2(-8.0, y - 1.5, _overlay.size.x + 16.0, 3.0), COLOR_DROP)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_MOUSE_EXIT:
		show_drop_mark(0)

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

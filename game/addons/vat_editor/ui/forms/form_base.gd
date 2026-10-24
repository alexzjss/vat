@tool
extends VBoxContainer

## Base dos formulários do Banco (M17): herói, inimigo e encontro. Monta os campos a partir dos descritores de
## `logic/forms.gd`, edita a MESMA instância do Resource que o Inspector mostra e só grava em **Salvar**
## (`ResourceSaver.save(res, res.resource_path)`). **Reverter** relê o arquivo (`CACHE_MODE_REPLACE`) e a instância aberta
## volta ao que está no disco. Um indicador "não salvo" mostra o estado, e o painel pergunta antes de trocar de item.
## Embaixo do cabeçalho fica a validação ao vivo do recurso aberto (os checks puros do M16).
##
## As subclasses só dizem o `kind` (a categoria do Banco) e, se precisam, acrescentam algo em `_build_extra`.

const Forms: GDScript = preload("res://addons/vat_editor/logic/forms.gd")
const ResourcePicker: GDScript = preload("res://addons/vat_editor/ui/widgets/resource_picker.gd")
const ElementDictEditor: GDScript = preload("res://addons/vat_editor/ui/widgets/element_dict_editor.gd")
const StatusDictEditor: GDScript = preload("res://addons/vat_editor/ui/widgets/status_dict_editor.gd")
const ListEditor: GDScript = preload("res://addons/vat_editor/ui/widgets/list_editor.gd")
const StatsEditor: GDScript = preload("res://addons/vat_editor/ui/widgets/stats_editor.gd")
const SpritePreview: GDScript = preload("res://addons/vat_editor/ui/widgets/sprite_preview.gd")

const COLOR_ERROR: Color = Color(1.0, 0.45, 0.4)
const COLOR_WARNING: Color = Color(1.0, 0.85, 0.4)
const COLOR_OK: Color = Color(0.5, 0.85, 0.55)
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)
const LABEL_WIDTH: float = 200.0

signal status(text: String)
signal saved(path: String)
signal reverted(res: Resource)
signal dirty_changed(dirty: bool)

## A categoria do Banco (`heroes`, `enemies`, `encounters`) e o nome do tipo na tela.
var kind: StringName = &""
var kind_label: String = ""
var res: Resource
## Os outros recursos da categoria, para o aviso de id repetido.
var siblings: Array = []
var _dirty: bool = false
var _title: Label
var _path_label: Label
var _dirty_label: Label
var _save_button: Button
var _revert_button: Button
var _issues: VBoxContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _choice_cache: Dictionary = {}

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	add_child(head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	head.add_child(_title)
	_dirty_label = Label.new()
	head.add_child(_dirty_label)
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(space)
	_save_button = Button.new()
	_save_button.text = "Salvar"
	_save_button.pressed.connect(func() -> void: save())
	head.add_child(_save_button)
	_revert_button = Button.new()
	_revert_button.text = "Reverter"
	_revert_button.tooltip_text = "Descarta as alterações e relê o arquivo"
	_revert_button.pressed.connect(func() -> void: revert())
	head.add_child(_revert_button)
	_path_label = Label.new()
	_path_label.add_theme_color_override("font_color", COLOR_MUTED)
	_path_label.clip_text = true
	add_child(_path_label)
	_issues = VBoxContainer.new()
	add_child(_issues)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

# --- estado ----------------------------------------------------------------------------------------------------

func is_dirty() -> bool:
	return _dirty

## Rola o corpo do formulário até `pixels` (conferência visual).
func scroll_to(pixels: int) -> void:
	_scroll.scroll_vertical = pixels

## Abre `p_res` no formulário (limpo). `p_siblings`: os outros da categoria.
func edit(p_res: Resource, p_siblings: Array = []) -> void:
	res = p_res
	siblings = p_siblings
	_choice_cache.clear()
	_set_dirty(false)
	rebuild()

## Grava no arquivo do recurso. Devolve true se gravou.
func save() -> bool:
	if res == null:
		return false
	var err: Error = Forms.save(res)
	if err != OK:
		status.emit("Não foi possível salvar %s (erro %d)." % [res.resource_path, err])
		return false
	_set_dirty(false)
	saved.emit(res.resource_path)
	status.emit("Salvo: %s" % res.resource_path)
	return true

## Descarta as alterações: relê o arquivo e a instância aberta (a do Inspector) volta ao que está no disco.
func revert() -> void:
	if res == null:
		return
	var back: Resource = Forms.reload_file(res.resource_path)
	if back == null:
		status.emit("Não foi possível reler %s." % res.resource_path)
		return
	res = back
	res.emit_changed()
	res.notify_property_list_changed()
	_set_dirty(false)
	rebuild()
	reverted.emit(res)
	status.emit("Revertido: %s" % res.resource_path)

func _set_dirty(value: bool) -> void:
	var changed: bool = value != _dirty
	_dirty = value
	_dirty_label.text = "  ● não salvo" if _dirty else ""
	_dirty_label.add_theme_color_override("font_color", COLOR_WARNING)
	_revert_button.disabled = not _dirty
	_save_button.disabled = not _dirty
	if changed:
		dirty_changed.emit(_dirty)

## Toda edição passa por aqui: marca como não salvo, avisa o Inspector (mesma instância) e revalida.
func touch() -> void:
	if res == null:
		return
	res.emit_changed()
	res.notify_property_list_changed()
	_set_dirty(true)
	refresh_issues()
	_after_touch()

func _after_touch() -> void:
	pass

# --- validação -------------------------------------------------------------------------------------------------

func refresh_issues() -> void:
	for c: Node in _issues.get_children():
		_issues.remove_child(c)
		c.queue_free()
	if res == null:
		return
	var issues: Array[ValidationIssue] = Forms.validate(res, siblings)
	if issues.is_empty():
		_issues.add_child(_note("Validação: sem problemas.", COLOR_OK))
		return
	for i: ValidationIssue in issues:
		_issues.add_child(_note(("Erro: " if i.is_error() else "Aviso: ") + i.message, COLOR_ERROR if i.is_error() else COLOR_WARNING))

func _note(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

# --- montagem --------------------------------------------------------------------------------------------------

func rebuild() -> void:
	for c: Node in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_title.text = "%s: %s" % [kind_label, str(res.get(&"id"))] if res != null else kind_label
	_path_label.text = res.resource_path if res != null else ""
	if res != null:
		var group: String = ""
		for d: Dictionary in Forms.fields(kind):
			if d.has("group") and d["group"] != group:
				group = d["group"]
				_body.add_child(_section(group))
			_add_field(_body, res, d)
		_build_extra(_body)
	refresh_issues()

## Gancho das subclasses: algo depois dos campos.
func _build_extra(_body_box: VBoxContainer) -> void:
	pass

func _section(text: String) -> Control:
	var box := VBoxContainer.new()
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	box.add_child(gap)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	box.add_child(l)
	box.add_child(HSeparator.new())
	return box

## Um campo com o rótulo: ao lado para os simples, em cima para os que ocupam a largura toda.
func _add_field(parent: Control, target: Resource, d: Dictionary) -> void:
	var wide: bool = [Forms.T_REFS, Forms.T_NAMES, Forms.T_PCT_DICT, Forms.T_ROWS, Forms.T_SPRITES].has(d["type"])
	var control: Control = control_for(target, d)
	if wide:
		var box := VBoxContainer.new()
		var l := Label.new()
		l.text = d["label"]
		box.add_child(l)
		box.add_child(control)
		parent.add_child(box)
	else:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = d["label"]
		l.custom_minimum_size.x = LABEL_WIDTH
		row.add_child(l)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(control)
		parent.add_child(row)

func _choices(source: StringName) -> Array[Dictionary]:
	if not _choice_cache.has(source):
		_choice_cache[source] = Forms.choices(source)
	return _choice_cache[source]

## O controle que edita `d["prop"]` de `target` (o recurso aberto, ou uma linha de lista).
func control_for(target: Resource, d: Dictionary) -> Control:
	var prop: StringName = d["prop"]
	match d["type"]:
		Forms.T_ID:
			var e := LineEdit.new()
			e.text = str(target.get(prop))
			e.text_changed.connect(func(t: String) -> void:
				target.set(prop, StringName(t.strip_edges()))
				touch())
			return e
		Forms.T_TEXT:
			var e := LineEdit.new()
			e.text = str(target.get(prop))
			e.text_changed.connect(func(t: String) -> void:
				target.set(prop, t)
				touch())
			return e
		Forms.T_INT:
			var s := SpinBox.new()
			s.min_value = d.get("min", 0)
			s.max_value = d.get("max", 9999)
			s.step = 1
			s.value = int(target.get(prop))
			s.custom_minimum_size.x = 100
			s.value_changed.connect(func(v: float) -> void:
				target.set(prop, int(v))
				touch())
			return _left(s)
		Forms.T_PCT:
			var s := SpinBox.new()
			s.min_value = 0.0
			s.max_value = 100.0
			s.step = 0.01
			s.custom_arrow_step = 1.0
			s.suffix = "%"
			s.value = Forms.to_percent(float(target.get(prop)))
			s.custom_minimum_size.x = 100
			s.value_changed.connect(func(v: float) -> void:
				target.set(prop, Forms.from_percent(v))
				touch())
			return _left(s)
		Forms.T_BOOL:
			var c := CheckBox.new()
			c.button_pressed = bool(target.get(prop))
			c.toggled.connect(func(on: bool) -> void:
				target.set(prop, on)
				touch())
			return _left(c)
		Forms.T_ENUM:
			var o := OptionButton.new()
			for label: String in d["options"]:
				o.add_item(label)
			o.select(clampi(int(target.get(prop)), 0, o.item_count - 1))
			o.item_selected.connect(func(i: int) -> void:
				target.set(prop, i)
				touch())
			return _left(o)
		Forms.T_STATS:
			return _stats_control(target, prop)
		Forms.T_REF:
			var p: Control = ResourcePicker.new()
			p.call(&"setup", _choices(d["source"]), target.get(prop))
			p.connect(&"picked", func(v: Variant) -> void:
				target.set(prop, v)
				touch())
			return p
		Forms.T_REFS:
			return _refs_control(target, d)
		Forms.T_NAMES:
			return _names_control(target, d)
		Forms.T_PCT_DICT:
			var ed: Control = ElementDictEditor.new() if d["source"] == Forms.SRC_ELEMENT else StatusDictEditor.new()
			ed.call(&"bind", target.get(prop), _choices(d["source"]))
			ed.connect(&"changed", touch)
			return ed
		Forms.T_ROWS:
			return _rows_control(target, d)
		Forms.T_SPRITES:
			return _sprites_control(target, d)
	return Label.new()

## Mantém o controle estreito dentro de uma linha larga.
func _left(c: Control) -> Control:
	var box := HBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(c)
	return box

func _stats_control(target: Resource, prop: StringName) -> Control:
	var stats: Resource = target.get(prop)
	if stats == null:
		var b := Button.new()
		b.text = "Criar atributos"
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func() -> void:
			Forms.ensure_stats(target, prop)
			touch()
			rebuild())
		return b
	var ed: Control = StatsEditor.new()
	ed.call(&"bind", stats)
	ed.connect(&"changed", touch)
	return ed

func _refs_control(target: Resource, d: Dictionary) -> Control:
	var arr: Array = target.get(d["prop"])
	var options: Array[Dictionary] = _choices(d["source"])
	var le: Control = ListEditor.new()
	le.set(&"empty_text", "(nenhum)")
	var make_row: Callable = func(item: Variant, index: int) -> Control:
		var p: Control = ResourcePicker.new()
		p.call(&"setup", options, item)
		p.connect(&"picked", func(v: Variant) -> void:
			arr[index] = v
			touch())
		return p
	le.call(&"bind", arr, make_row, Callable(), int(d.get("max_count", 0)))
	le.connect(&"changed", touch)
	return le

func _names_control(target: Resource, d: Dictionary) -> Control:
	var arr: Array = target.get(d["prop"])
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array[StringName] = Forms.choice_ids(_choices(d["source"]))
	for v: Variant in arr:
		if not ids.has(v):
			ids.append(v)
	for id: StringName in ids:
		var c := CheckBox.new()
		c.text = String(id)
		c.button_pressed = arr.has(id)
		c.toggled.connect(func(on: bool) -> void:
			Forms.names_toggle(arr, id, on)
			touch())
		flow.add_child(c)
	if ids.is_empty():
		flow.add_child(_note("(nenhuma opção)", COLOR_MUTED))
	return flow

func _sprites_control(target: Resource, d: Dictionary) -> Control:
	var prop: StringName = d["prop"]
	var box := VBoxContainer.new()
	var preview: Control = SpritePreview.new()
	var p: Control = ResourcePicker.new()
	p.call(&"setup", _choices(d["source"]), target.get(prop))
	p.connect(&"picked", func(v: Variant) -> void:
		target.set(prop, v)
		preview.call(&"show_sprites", v)
		touch())
	box.add_child(p)
	box.add_child(preview)
	preview.call(&"show_sprites", target.get(prop))
	return box

# --- linhas de lista -------------------------------------------------------------------------------------------

func _rows_control(target: Resource, d: Dictionary) -> Control:
	var arr: Array = target.get(d["prop"])
	var row_kind: StringName = d["row"]
	var le: Control = ListEditor.new()
	le.set(&"empty_text", "(nenhuma linha)")
	var make_row: Callable = func(item: Variant, _index: int) -> Control:
		return _row_control(row_kind, item as Resource)
	var make_item: Callable = func() -> Variant:
		return Forms.new_row(row_kind, arr)
	le.call(&"bind", arr, make_row, make_item)
	le.connect(&"changed", touch)
	return le

## Uma linha: cada coluna com a legenda em cima, lado a lado (quebra se faltar largura). As fases têm a lista de regras dentro.
func _row_control(row_kind: StringName, item: Resource) -> Control:
	if item == null:
		return _note("(linha vazia)", COLOR_ERROR)
	# a fase empilha os campos (a lista de regras de dentro precisa da largura toda); as demais linhas correm lado a lado
	var flow: Container = VBoxContainer.new() if row_kind == Forms.ROW_PHASE else HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var controls: Dictionary = {}
	for col: Dictionary in Forms.columns(row_kind):
		var box := VBoxContainer.new()
		var cap := Label.new()
		cap.text = col["label"]
		cap.add_theme_color_override("font_color", COLOR_MUTED)
		box.add_child(cap)
		var c: Control = control_for(item, col)
		if row_kind != Forms.ROW_PHASE and (col["type"] == Forms.T_TEXT or col["type"] == Forms.T_REF):
			c.custom_minimum_size.x = 220
		box.add_child(c)
		flow.add_child(box)
		controls[col["prop"]] = box
	match row_kind:
		Forms.ROW_AI_RULE:
			_wire_ai_rule(item as AiRule, controls)
		Forms.ROW_DROP:
			_wire_drop(item as DropEntry, controls)
		Forms.ROW_LEARN:
			_wire_learn(item as LearnEntry, controls)
	return flow

## O limiar de HP só vale para "Aliado com HP abaixo de".
func _wire_ai_rule(rule: AiRule, controls: Dictionary) -> void:
	var threshold_box: Control = controls[&"threshold"]
	threshold_box.visible = rule.condition == AiRule.Condition.ALLY_HP_BELOW
	var cond_box: Control = controls[&"condition"]
	var opt: OptionButton = _find_first(cond_box, "OptionButton") as OptionButton
	opt.item_selected.connect(func(i: int) -> void: threshold_box.visible = i == AiRule.Condition.ALLY_HP_BELOW)

## Um drop é item ou equipamento, não os dois: escolher um limpa o outro.
func _wire_drop(drop: DropEntry, controls: Dictionary) -> void:
	var item_pick: Control = _find_first(controls[&"item"], "HBoxContainer", true)
	var equip_pick: Control = _find_first(controls[&"equipment"], "HBoxContainer", true)
	item_pick.connect(&"picked", func(v: Variant) -> void:
		if v != null:
			drop.equipment = null
			equip_pick.call(&"set_value", null)
			touch())
	equip_pick.connect(&"picked", func(v: Variant) -> void:
		if v != null:
			drop.item = null
			item_pick.call(&"set_value", null)
			touch())

## Nível 0 = só por evento.
func _wire_learn(entry: LearnEntry, controls: Dictionary) -> void:
	var box: VBoxContainer = controls[&"level"]
	var hint := Label.new()
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.text = "só por evento" if entry.level == 0 else ""
	box.add_child(hint)
	var spin: SpinBox = _find_first(box, "SpinBox") as SpinBox
	spin.value_changed.connect(func(v: float) -> void: hint.text = "só por evento" if int(v) == 0 else "")

## O primeiro descendente da classe nativa `cls`. Com `picker`, o primeiro que tem o sinal `picked` (o ResourcePicker).
func _find_first(root: Node, cls: String, picker: bool = false) -> Node:
	for c: Node in root.get_children():
		if (not picker and c.is_class(cls)) or (picker and c.has_signal(&"picked")):
			return c
		var deeper: Node = _find_first(c, cls, picker)
		if deeper != null:
			return deeper
	return null

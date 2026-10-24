@tool
extends "res://addons/vat_editor/ui/forms/form_base.gd"

## Formulário de loja (M17): id e nome, e a tabela do que ela vende, itens e equipamentos. Cada linha tem o seletor do item,
## o PREÇO (editável), a venda calculada com a razão de venda do jogo e, nos equipamentos, quem pode vestir (pela lista de quem
## veste, o tipo de arma e as armas dos heróis da fatia). Linhas se acrescentam e se removem pelo seletor.
##
## O preço pertence ao item ou equipamento, não à loja: editar na tabela muda o `price` do recurso (vale em todas as lojas).
## Por isso **Salvar** grava a loja E cada item ou equipamento cujo preço mudou, e a lista de arquivos que serão gravados fica
## sempre visível antes de salvar. Reverter relê a loja e esses arquivos.

var ratio: float = 0.5
var heroes: Array = []
## Item ou equipamento -> preço de quando entrou na tabela (para saber quais arquivos gravar).
var _orig_prices: Dictionary = {}
var _table: VBoxContainer
var _files: Label

func _init() -> void:
	super._init()
	kind = &"shops"
	kind_label = "Loja"

func edit(p_res: Resource, p_siblings: Array = []) -> void:
	_orig_prices.clear()
	super.edit(p_res, p_siblings)

func _build_extra(body: VBoxContainer) -> void:
	ratio = Forms.sell_ratio()
	heroes = Forms.slice_heroes(_choices(Forms.SRC_HERO).map(func(c: Dictionary) -> Variant: return c["value"]))
	body.add_child(_section("O que a loja vende"))
	body.add_child(_note("O preço é do item ou equipamento: editar aqui muda o recurso e vale em todas as lojas. "
			+ "A venda rende floor(preço × %s) (razão de venda do jogo: %d%%); preço 0 e item-chave não vendem." % [str(ratio), roundi(ratio * 100.0)], COLOR_MUTED))
	_table = VBoxContainer.new()
	body.add_child(_table)
	body.add_child(_section("Arquivos gravados ao salvar"))
	_files = Label.new()
	_files.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_files)
	_fill_table()

func _after_touch() -> void:
	_refresh_files()

# --- tabela ----------------------------------------------------------------------------------------------------

func _fill_table() -> void:
	for c: Node in _table.get_children():
		_table.remove_child(c)
		c.queue_free()
	if res == null:
		return
	_add_group("Itens", res.get(&"items"), Forms.SRC_ITEM, false)
	_add_group("Equipamentos", res.get(&"equipment"), Forms.SRC_EQUIP, true)
	_refresh_files()

func _add_group(title: String, arr: Array, source: StringName, is_equipment: bool) -> void:
	var head := Label.new()
	head.text = "%s (%d)" % [title, arr.size()]
	head.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	_table.add_child(head)
	_table.add_child(_header_row(is_equipment))
	var options: Array[Dictionary] = _choices(source)
	for i: int in arr.size():
		_table.add_child(_make_row(arr, i, options, is_equipment))
	var add := Button.new()
	add.text = "+ Adicionar %s" % ("equipamento" if is_equipment else "item")
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add.pressed.connect(func() -> void:
		Forms.list_add(arr, null)
		touch()
		_fill_table())
	_table.add_child(add)

func _header_row(is_equipment: bool) -> Control:
	var row := HBoxContainer.new()
	var name_head: Label = _cell("Nome", 0)
	name_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_head)
	row.add_child(_cell("Preço", 100))
	row.add_child(_cell("Venda", 70))
	if is_equipment:
		row.add_child(_cell("Quem veste", 150))
	var gap := Control.new()
	gap.custom_minimum_size.x = 110
	row.add_child(gap)
	return row

func _cell(text: String, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = width
	l.add_theme_color_override("font_color", COLOR_MUTED)
	return l

func _make_row(arr: Array, index: int, options: Array[Dictionary], is_equipment: bool) -> Control:
	var def: Resource = arr[index] as Resource
	_remember(def)
	var info: Dictionary = Forms.shop_row(def, ratio, heroes)
	var row := HBoxContainer.new()
	var picker: Control = ResourcePicker.new()
	picker.call(&"setup", options, def)
	picker.connect(&"picked", func(v: Variant) -> void:
		arr[index] = v
		touch()
		_fill_table())
	row.add_child(picker)
	var price := SpinBox.new()
	price.min_value = 0
	price.max_value = 999999
	price.step = 1
	price.value = info["price"]
	price.editable = def != null
	price.custom_minimum_size.x = 100
	price.tooltip_text = "Preço do item (vale em todas as lojas)"
	row.add_child(price)
	var sell := _cell(_sell_text(info), 70)
	row.add_child(sell)
	if is_equipment:
		var who := _cell(str(info["who"]), 150)
		who.clip_text = true
		who.tooltip_text = str(info["who"])
		row.add_child(who)
	if def != null:
		price.value_changed.connect(func(v: float) -> void:
			def.set(&"price", int(v))
			def.emit_changed()
			sell.text = _sell_text(Forms.shop_row(def, ratio, heroes))
			touch())
	var tools := HBoxContainer.new()
	tools.custom_minimum_size.x = 110
	row.add_child(tools)
	var up := _tool(tools, "↑", "Subir")
	up.disabled = index == 0
	up.pressed.connect(func() -> void: _apply_move(arr, index, -1))
	var down := _tool(tools, "↓", "Descer")
	down.disabled = index == arr.size() - 1
	down.pressed.connect(func() -> void: _apply_move(arr, index, 1))
	var remove := _tool(tools, "✕", "Tirar da loja")
	remove.pressed.connect(func() -> void:
		Forms.list_remove(arr, index)
		touch()
		_fill_table())
	return row

func _tool(parent: Node, text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	parent.add_child(b)
	return b

func _apply_move(arr: Array, index: int, delta: int) -> void:
	if Forms.list_move(arr, index, delta) != index:
		touch()
		_fill_table()

func _sell_text(info: Dictionary) -> String:
	return str(info["sell"]) if info["sellable"] else "não vende"

## Guarda o preço de quando o recurso entrou na tabela (a base para saber o que mudou).
func _remember(def: Resource) -> void:
	if def != null and not _orig_prices.has(def):
		_orig_prices[def] = int(def.get(&"price"))

func _refresh_files() -> void:
	if _files == null or res == null:
		return
	var paths: Array[String] = Forms.shop_save_paths(res, _orig_prices)
	var lines := PackedStringArray()
	for p: String in paths:
		lines.append("• " + p + ("  (preço alterado)" if p != res.resource_path else "  (a loja)"))
	_files.text = "\n".join(lines)

# --- salvar e reverter -----------------------------------------------------------------------------------------

## Grava a loja e, antes dela, cada item ou equipamento cujo preço mudou. Para no primeiro erro.
func save() -> bool:
	if res == null:
		return false
	var extra := PackedStringArray()
	for p: String in Forms.shop_save_paths(res, _orig_prices):
		if p == res.resource_path:
			continue
		var err: Error = Forms.save(_def_at(p))
		if err != OK:
			status.emit("Não foi possível salvar %s (erro %d)." % [p, err])
			return false
		extra.append(p)
	var shop_err: Error = Forms.save(res)
	if shop_err != OK:
		status.emit("Não foi possível salvar %s (erro %d)." % [res.resource_path, shop_err])
		return false
	for k: Variant in _orig_prices:
		_orig_prices[k] = int((k as Resource).get(&"price"))
	_set_dirty(false)
	_refresh_files()
	if not extra.is_empty():
		files_written.emit(extra)
	saved.emit(res.resource_path)
	status.emit("Salvo: %s%s" % [res.resource_path, "" if extra.is_empty() else " e %d preço(s) em itens/equipamentos" % extra.size()])
	return true

func _def_at(path: String) -> Resource:
	for k: Variant in _orig_prices:
		if (k as Resource).resource_path == path:
			return k as Resource
	return null

## Relê a loja e os arquivos de itens e equipamentos que ela tocou.
func revert() -> void:
	if res == null:
		return
	for k: Variant in _orig_prices.keys():
		var def: Resource = k as Resource
		if def.resource_path != "" and int(def.get(&"price")) != int(_orig_prices[k]):
			Forms.reload_file(def.resource_path)
			def.emit_changed()
		_orig_prices[k] = int(def.get(&"price"))
	super.revert()

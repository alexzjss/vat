@tool
extends ConfirmationDialog

## Diálogo "Novo mapa" (M17), UI fina sobre `logic/map_wizard.gd` (o plano) e `logic/map_builder.gd` (a cena). Pede id, nome,
## tipo, tamanho em tiles e tile base; mostra o tamanho em pixels e os erros ao vivo; ao confirmar, monta a cena, grava em
## `world/mapas/<id>.tscn`, cria o `MapDef`, registra no `MapRegistry`, atualiza o FileSystem e abre a cena no editor.

const Wizard: GDScript = preload("res://addons/vat_editor/logic/map_wizard.gd")
const Builder: GDScript = preload("res://addons/vat_editor/logic/map_builder.gd")

const COLOR_ERROR: Color = Color(1.0, 0.45, 0.4)
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)

## O mapa foi criado: `id` do `MapDef` novo.
signal created(id: StringName)

var id_edit: LineEdit
var name_edit: LineEdit
var kind_option: OptionButton
var width_spin: SpinBox
var height_spin: SpinBox
var base_option: OptionButton
var size_label: Label
var error_label: Label
## Onde o registro mora.
var registry_path: String = Game.DEFAULT_REGISTRY_PATH

func _init() -> void:
	title = "Novo mapa"
	ok_button_text = "Criar"
	cancel_button_text = "Cancelar"
	dialog_hide_on_ok = false
	min_size = Vector2i(520, 0)

func _ready() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	id_edit = LineEdit.new()
	id_edit.placeholder_text = "minha_vila"
	_row(grid, "Id (a-z, 0-9 e _):", id_edit)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "(opcional; senão deriva do id)"
	_row(grid, "Nome:", name_edit)
	kind_option = OptionButton.new()
	for k: int in Wizard.KINDS:
		kind_option.add_item(Wizard.kind_label(k), k)
	_row(grid, "Tipo:", kind_option)
	width_spin = _spin(Wizard.MIN_W, Wizard.MAX_W, 75)
	_row(grid, "Largura (tiles):", width_spin)
	height_spin = _spin(Wizard.MIN_H, Wizard.MAX_H, 23)
	_row(grid, "Altura (tiles):", height_spin)
	base_option = OptionButton.new()
	for i: int in Wizard.BASE_TILES.size():
		base_option.add_item(str(Wizard.BASE_TILES[i]["label"]), i)
	_row(grid, "Tile base:", base_option)
	size_label = Label.new()
	size_label.add_theme_color_override("font_color", COLOR_MUTED)
	box.add_child(size_label)
	error_label = Label.new()
	error_label.add_theme_color_override("font_color", COLOR_ERROR)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(error_label)
	id_edit.text_changed.connect(func(_t: String) -> void: refresh())
	name_edit.text_changed.connect(func(_t: String) -> void: refresh())
	kind_option.item_selected.connect(_on_kind_selected)
	width_spin.value_changed.connect(func(_v: float) -> void: refresh())
	height_spin.value_changed.connect(func(_v: float) -> void: refresh())
	base_option.item_selected.connect(func(_i: int) -> void: refresh())
	confirmed.connect(_on_confirmed)
	_select_default_base()
	refresh()

func _row(grid: GridContainer, text: String, control: Control) -> void:
	var l := Label.new()
	l.text = text
	grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)

func _spin(lo: int, hi: int, value: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = value
	return s

## Abre o diálogo limpo (com `id` já preenchido, se vier).
func open_for(id: String = "") -> void:
	id_edit.text = id
	name_edit.text = ""
	_select_default_base()
	refresh()
	popup_centered()
	id_edit.grab_focus()

func _on_kind_selected(_i: int) -> void:
	_select_default_base()
	refresh()

func _select_default_base() -> void:
	var base: Vector2i = Wizard.default_base(kind_option.get_selected_id())
	for i: int in Wizard.BASE_TILES.size():
		if Wizard.BASE_TILES[i]["cell"] == base:
			base_option.select(i)

## Os dados do formulário, no formato de `Wizard.plan`.
func params() -> Dictionary:
	return {
		"id": id_edit.text.strip_edges(),
		"name": name_edit.text,
		"kind": kind_option.get_selected_id(),
		"width": int(width_spin.value),
		"height": int(height_spin.value),
		"base": Wizard.BASE_TILES[base_option.get_selected_id()]["cell"],
	}

func _registry() -> MapRegistry:
	return Game.default_registry()

## Recalcula o plano, mostra o tamanho em pixels e os erros, e liga ou desliga o Criar.
func refresh() -> void:
	var p: Dictionary = params()
	var px: Vector2i = Wizard.size_px(p["width"], p["height"])
	size_label.text = "%d x %d tiles = %d x %d px" % [p["width"], p["height"], px.x, px.y]
	var plan: Dictionary = Wizard.plan(p, _registry())
	var errors: Array = plan["errors"]
	error_label.text = "\n".join(PackedStringArray(errors)) if p["id"] != "" else ""
	get_ok_button().disabled = not plan["ok"]

func _on_confirmed() -> void:
	var plan: Dictionary = Wizard.plan(params(), _registry())
	if not plan["ok"]:
		error_label.text = "\n".join(PackedStringArray(plan["errors"]))
		return
	var scene: PackedScene = Builder.build(plan)
	if scene == null:
		error_label.text = "Não foi possível montar a cena a partir do modelo."
		return
	var err: String = Builder.write(plan, scene, _registry(), registry_path)
	if err != "":
		error_label.text = err
		return
	hide()
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	fs.update_file(plan["scene_path"])
	fs.update_file(plan["def_path"])
	fs.update_file(registry_path)
	fs.scan()
	EditorInterface.open_scene_from_path(plan["scene_path"])
	created.emit(StringName(plan["id"]))

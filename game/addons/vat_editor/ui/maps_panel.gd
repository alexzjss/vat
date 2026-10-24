@tool
extends VBoxContainer

## Aba "Mapas" do painel VAT (M17): a lista do `MapRegistry` (id, nome, tipo, cena) com Novo mapa…, Abrir e Remover do
## registro (a cena não é apagada; pede confirmação). UI fina: o trabalho está em `logic/map_wizard.gd` e `logic/map_builder.gd`.

const Wizard: GDScript = preload("res://addons/vat_editor/logic/map_wizard.gd")
const Builder: GDScript = preload("res://addons/vat_editor/logic/map_builder.gd")
const WizardDialog: GDScript = preload("res://addons/vat_editor/ui/map_wizard_dialog.gd")

const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)

signal status(text: String)

var tree: Tree
var summary: Label
var open_button: Button
var remove_button: Button
var wizard: ConfirmationDialog
var _confirm_remove: ConfirmationDialog
var _pending_remove: StringName = &""

func _init() -> void:
	name = "Mapas"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	summary = Label.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(summary)
	_button(top, "Novo mapa…", func() -> void: open_wizard())
	open_button = _button(top, "Abrir", _on_open_pressed)
	remove_button = _button(top, "Remover do registro", _on_remove_pressed)
	tree = Tree.new()
	tree.columns = 4
	tree.column_titles_visible = true
	var titles: Array[String] = ["Id", "Nome", "Tipo", "Cena"]
	for i: int in 4:
		tree.set_column_title(i, titles[i])
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 150)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 200)
	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 110)
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.item_selected.connect(_update_buttons)
	tree.item_activated.connect(_on_open_pressed)
	add_child(tree)
	var hint := Label.new()
	hint.text = "Novo mapa cria a cena em world/mapas/ a partir de um modelo e a registra. Remover do registro não apaga a cena."
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	add_child(hint)
	wizard = WizardDialog.new()
	wizard.created.connect(_on_created)
	add_child(wizard)
	_confirm_remove = ConfirmationDialog.new()
	_confirm_remove.title = "Remover do registro"
	_confirm_remove.ok_button_text = "Remover"
	_confirm_remove.cancel_button_text = "Cancelar"
	_confirm_remove.confirmed.connect(_do_remove)
	add_child(_confirm_remove)
	refresh()

func _button(parent: Node, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	parent.add_child(b)
	return b

func _registry() -> MapRegistry:
	return Game.default_registry()

## Relê o registro e refaz a lista.
func refresh() -> void:
	tree.clear()
	var root: TreeItem = tree.create_item()
	var reg: MapRegistry = _registry()
	for d: MapDef in reg.maps:
		if d == null:
			continue
		var it: TreeItem = tree.create_item(root)
		it.set_text(0, String(d.id))
		it.set_text(1, d.display_name)
		it.set_text(2, _kind_text(d.kind))
		it.set_text(3, d.scene.resource_path if d.scene != null else "(sem cena)")
		it.set_metadata(0, String(d.id))
	summary.text = "%d mapa(s) no registro" % reg.maps.size()
	_update_buttons()

func _kind_text(kind: int) -> String:
	return "Teste" if kind == MapDef.Kind.TESTE else Wizard.kind_label(kind)

func _selected_id() -> StringName:
	var it: TreeItem = tree.get_selected()
	return StringName(str(it.get_metadata(0))) if it != null else &""

func _update_buttons() -> void:
	var has: bool = _selected_id() != &""
	open_button.disabled = not has
	remove_button.disabled = not has

func open_wizard(id: String = "") -> void:
	wizard.call(&"open_for", id)

func _on_created(id: StringName) -> void:
	refresh()
	status.emit("Mapa '%s' criado e registrado." % id)

func _on_open_pressed() -> void:
	var def: MapDef = _registry().find(_selected_id())
	if def == null or def.scene == null:
		return
	EditorInterface.open_scene_from_path(def.scene.resource_path)
	status.emit("Aberto %s" % def.scene.resource_path)

func _on_remove_pressed() -> void:
	_pending_remove = _selected_id()
	if _pending_remove == &"":
		return
	_confirm_remove.dialog_text = "Tirar o mapa '%s' do registro?\nA cena e o MapDef ficam no disco; ligações que apontam para ele passam a acusar erro na validação." % _pending_remove
	_confirm_remove.popup_centered()

func _do_remove() -> void:
	var err: String = Builder.unregister(_registry(), _pending_remove, Game.DEFAULT_REGISTRY_PATH)
	if err != "":
		status.emit(err)
		return
	EditorInterface.get_resource_filesystem().update_file(Game.DEFAULT_REGISTRY_PATH)
	status.emit("Mapa '%s' tirado do registro." % _pending_remove)
	refresh()

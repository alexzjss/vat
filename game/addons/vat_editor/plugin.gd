@tool
extends EditorPlugin

## Plugin do editor do VAT (M16). Só do editor: o jogo exportado não carrega nada daqui.
## Registra o importador de `.roteiro` e a aba "VAT" da tela principal (vat_panel.gd).
##
## Captura de tela para conferência: `godot --path game --editor -- --vat-capture=<arquivo.png> [--vat-tab=<aba>]`
## abre o editor, mostra a aba VAT (e a sub-aba pedida: Banco, Roteiros, Validar ou Testar), salva a imagem e sai.
## Na aba Mapas: `--vat-wizard[=<id>]` abre o diálogo Novo mapa (com esse id).
## Na aba Mundo: `--vat-tests` mostra também os mapas de teste.
## Na aba Banco: `--vat-sub=<categoria>` (a chave, como `heroes`, `enemies`, `encounters`, ou o rótulo) escolhe a categoria e
## `--vat-pick=<id>` abre esse item no formulário; `--vat-scroll=<px,px,...>` salva mais uma imagem (`<arquivo>_s1.png`, ...)
## com o formulário rolado a cada posição (o formulário é mais alto que a tela). Na categoria Arte, `--vat-art-wizard=<res://...png>`
## abre o assistente "Criar a partir de uma imagem" com essa imagem (a janela dele vai para `<arquivo>_assistente.png`).
## Na aba Roteiros: `--vat-sub=Lista|Editor|Simular` escolhe a sub-vista, `--vat-event=<id>` abre esse evento (no primeiro
## arquivo que o tem) e `--vat-answers=<0,1,..>` roda a simulação com essas respostas (no Simular).
## `--vat-open-scene=<res://...tscn>` abre a cena na tela 2D (a paleta de objetos aparece), `--vat-select=<caminho do nó>` seleciona
## um nó dela (o Inspector mostra os menus) e `--vat-add=<prefab>` adiciona o prefab pela paleta, confere o undo/redo e o seleciona.

const RoteiroImporter: GDScript = preload("res://addons/vat_editor/roteiro_importer.gd")
const VatPanel: GDScript = preload("res://addons/vat_editor/vat_panel.gd")
const ObjectPalette: GDScript = preload("res://addons/vat_editor/ui/object_palette.gd")
const VatInspectorPlugin: GDScript = preload("res://addons/vat_editor/inspector/vat_inspector_plugin.gd")
const CAPTURE_FLAG: String = "--vat-capture="
const TAB_FLAG: String = "--vat-tab="
const SUB_FLAG: String = "--vat-sub="
const PICK_FLAG: String = "--vat-pick="
const SCROLL_FLAG: String = "--vat-scroll="
const EVENT_FLAG: String = "--vat-event="
const ANSWERS_FLAG: String = "--vat-answers="
const WIZARD_FLAG: String = "--vat-wizard"
const OPEN_SCENE_FLAG: String = "--vat-open-scene="
const SELECT_FLAG: String = "--vat-select="
const ADD_FLAG: String = "--vat-add="
const TESTS_FLAG: String = "--vat-tests"
const ART_WIZARD_FLAG: String = "--vat-art-wizard="

var _roteiro_importer: EditorImportPlugin
var _panel: Control
var _palette: Control
var _inspector_plugin: EditorInspectorPlugin

func _enter_tree() -> void:
	_roteiro_importer = RoteiroImporter.new()
	add_import_plugin(_roteiro_importer)
	_panel = VatPanel.new()
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_panel.hide()
	_palette = ObjectPalette.new()
	_palette.set(&"plugin", self)
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _palette)
	scene_changed.connect(_on_scene_changed)
	scene_closed.connect(func(_path: String) -> void: _on_scene_changed(null))
	_inspector_plugin = VatInspectorPlugin.new()
	_inspector_plugin.set(&"open_editor", open_roteiro_event)
	add_inspector_plugin(_inspector_plugin)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_inspector_plugin.invalidate)
	_on_scene_changed(EditorInterface.get_edited_scene_root())
	_capture_if_asked.call_deferred()

func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
	if _palette != null:
		remove_control_from_docks(_palette)
		_palette.queue_free()
		_palette = null
	if _roteiro_importer != null:
		remove_import_plugin(_roteiro_importer)
		_roteiro_importer = null
	if _panel != null:
		_panel.queue_free()
		_panel = null

## A paleta liga ou desliga conforme a cena aberta (só `LocalMap` e `Overworld`).
func _on_scene_changed(root: Node) -> void:
	if _palette != null:
		_palette.call(&"refresh", root)

## Guarda o último clique na vista 2D para a paleta colocar o prefab ali. Não consome o evento. (Não usa `_handles` +
## `_forward_canvas_gui_input`: um plugin de tela principal que "trata" um nó faz o editor pular para a aba VAT ao selecioná-lo.)
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or _palette == null:
		return
	var container: Control = EditorInterface.get_editor_viewport_2d().get_parent() as Control
	if container == null or not container.is_visible_in_tree():
		return
	if container.get_global_rect().has_point(mb.global_position):
		_palette.call(&"note_click", container.get_global_transform().affine_inverse() * mb.global_position)

## "Abrir no editor de blocos": mostra a aba VAT em Roteiros > Editor com o arquivo e o evento (chamado pelo Inspector).
func open_roteiro_event(path: String, event_id: String) -> void:
	EditorInterface.set_main_screen_editor("VAT")
	_panel.call(&"open_roteiro_event", path, event_id)

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if _panel != null:
		_panel.visible = visible

func _get_plugin_name() -> String:
	return "VAT"

func _get_plugin_icon() -> Texture2D:
	var base: Control = EditorInterface.get_base_control()
	for icon: StringName in [&"Database", &"ResourcePreloader", &"Object"]:
		if base.has_theme_icon(icon, &"EditorIcons"):
			return base.get_theme_icon(icon, &"EditorIcons")
	return null

func _capture_if_asked() -> void:
	var out: String = ""
	var tab: String = "Banco"
	var sub: String = ""
	var pick: String = ""
	var scrolls: PackedStringArray = PackedStringArray()
	var tab_given: bool = false
	var event_id: String = ""
	var answers: String = ""
	var wizard: bool = false
	var wizard_id: String = ""
	var open_scene: String = ""
	var select_path: String = ""
	var add_id: String = ""
	var with_tests: bool = false
	var art_wizard: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(CAPTURE_FLAG):
			out = a.trim_prefix(CAPTURE_FLAG)
		elif a.begins_with(TAB_FLAG):
			tab = a.trim_prefix(TAB_FLAG)
			tab_given = true
		elif a.begins_with(SUB_FLAG):
			sub = a.trim_prefix(SUB_FLAG)
		elif a.begins_with(PICK_FLAG):
			pick = a.trim_prefix(PICK_FLAG)
		elif a.begins_with(SCROLL_FLAG):
			scrolls = a.trim_prefix(SCROLL_FLAG).split(",", false)
		elif a.begins_with(EVENT_FLAG):
			event_id = a.trim_prefix(EVENT_FLAG)
		elif a.begins_with(ANSWERS_FLAG):
			answers = a.trim_prefix(ANSWERS_FLAG)
		elif a.begins_with(OPEN_SCENE_FLAG):
			open_scene = a.trim_prefix(OPEN_SCENE_FLAG)
		elif a.begins_with(SELECT_FLAG):
			select_path = a.trim_prefix(SELECT_FLAG)
		elif a.begins_with(ADD_FLAG):
			add_id = a.trim_prefix(ADD_FLAG)
		elif a == TESTS_FLAG:
			with_tests = true
		elif a.begins_with(ART_WIZARD_FLAG):
			art_wizard = a.trim_prefix(ART_WIZARD_FLAG)
		elif a == WIZARD_FLAG or a.begins_with(WIZARD_FLAG + "="):
			wizard = true
			tab = "Mapas"
			wizard_id = a.trim_prefix(WIZARD_FLAG + "=") if a.contains("=") else ""
	if sub != "" and not tab_given:
		tab = "Roteiros"
	if out == "":
		return
	if open_scene != "":
		await _capture_scene(out, open_scene, select_path, add_id)
		return
	EditorInterface.set_main_screen_editor("VAT")
	for i: int in 10:
		await get_tree().process_frame
	var tabs: TabContainer = _panel.tabs
	for i: int in tabs.get_tab_count():
		if tabs.get_tab_title(i) == tab:
			tabs.current_tab = i
	if tab == "Banco" and (sub != "" or pick != ""):
		_panel.show_bank(sub, pick)
	if art_wizard != "":
		_panel.show_art_wizard(art_wizard)
	if tab == "Mapas":
		_panel.show_maps(wizard, wizard_id)
	if tab == "Mundo":
		_panel.show_world(with_tests)
	if tab == "Validar":
		await _panel.run_validation()
	if sub != "" and tab == "Roteiros":
		await _panel.show_roteiro(sub, event_id, answers)
	for i: int in 90:
		await get_tree().process_frame
	var img: Image = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	print("vat-capture: %s (%d)" % [out, err])
	var report: String = _panel.form_report()
	if report != "":
		print("vat-capture: formulário: %s" % report)
	for i: int in scrolls.size():
		_panel.call(&"scroll_form", int(scrolls[i]))
		for f: int in 20:
			await get_tree().process_frame
		var more: Image = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		var more_out: String = "%s_s%d.png" % [out.get_basename(), i + 1]
		print("vat-capture: %s (%d)" % [more_out, more.save_png(more_out)])
	if art_wizard != "":
		var art_dlg: Image = _panel.art_wizard_image()
		print("vat-capture (assistente de arte): %d" % art_dlg.save_png(out.get_basename() + "_assistente.png"))
	if wizard:
		# O diálogo é uma janela própria no editor: a captura da janela principal não o mostra, então grava a dele ao lado.
		var dlg: Image = _panel.maps_panel.wizard.get_texture().get_image()
		print("vat-capture (diálogo): %d" % dlg.save_png(out.get_basename() + "_dialogo.png"))
	get_tree().quit(0 if err == OK else 1)

## Captura da tela 2D com a cena aberta: a paleta de objetos à vista, um nó selecionado (o Inspector com os menus) e,
## com `add_id`, o prefab adicionado pela paleta (confere nome, dono, flags, seleção e o undo/redo antes de capturar).
func _capture_scene(out: String, scene_path: String, select_path: String, add_id: String) -> void:
	# O editor reabre as cenas da última sessão e ativa uma delas: espera isso acabar, abre a pedida e confere que ficou ativa.
	for i: int in 120:
		await get_tree().process_frame
	for attempt: int in 5:
		EditorInterface.open_scene_from_path(scene_path)
		for i: int in 30:
			await get_tree().process_frame
		var current: Node = EditorInterface.get_edited_scene_root()
		if current != null and current.scene_file_path == scene_path:
			break
	EditorInterface.set_main_screen_editor("2D")
	for i: int in 10:
		await get_tree().process_frame
	# No Godot 4.7 o dock é embrulhado num `EditorDock`; ele sabe se trazer à frente. Antes, era a aba do TabContainer.
	var dock: Node = _palette.get_parent()
	if dock != null and dock.has_method(&"make_visible"):
		dock.call(&"make_visible")
	elif dock is TabContainer:
		(dock as TabContainer).current_tab = (dock as TabContainer).get_tab_idx_from_control(_palette)
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null:
		print("vat-capture: a cena não abriu (%s)" % scene_path)
		get_tree().quit(1)
		return
	if add_id != "":
		await _check_add(root, add_id)
	if select_path != "":
		var target: Node = root.get_node_or_null(NodePath(select_path))
		if target == null:
			print("vat-capture: nó não encontrado (%s)" % select_path)
		else:
			var sel: EditorSelection = EditorInterface.get_selection()
			sel.clear()
			sel.add_node(target)
			EditorInterface.edit_node(target)
	for i: int in 60:
		await get_tree().process_frame
	var img: Image = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	print("vat-capture: %s (%d)" % [out, err])
	get_tree().quit(0 if err == OK else 1)

func _check_add(root: Node, prefab_id: String) -> void:
	var before: int = root.get_child_count()
	var node: Node = _palette.call(&"add_prefab", StringName(prefab_id))
	if node == null:
		print("vat-add: não adicionou %s" % prefab_id)
		return
	var props: Dictionary = {}
	for p: Dictionary in node.get_property_list():
		if String(p["name"]).ends_with("flag") and int(p["type"]) == TYPE_STRING_NAME:
			props[p["name"]] = node.get(p["name"])
	var selected: bool = EditorInterface.get_selection().get_selected_nodes().has(node)
	print("vat-add: nome=%s dono_ok=%s posicao=%s selecionado=%s flags=%s filhos=%d->%d" % [node.name, node.owner == root, (node as Node2D).position, selected, props, before, root.get_child_count()])
	var history: UndoRedo = get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(root))
	history.undo()
	print("vat-add: depois do undo filhos=%d" % root.get_child_count())
	history.redo()
	print("vat-add: depois do redo filhos=%d (nó de volta=%s)" % [root.get_child_count(), is_instance_valid(node) and node.get_parent() == root])
	await get_tree().process_frame

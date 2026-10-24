@tool
extends VBoxContainer

## Painel "VAT" da tela principal do editor (M16). UI fina: monta os controles e entrega o trabalho à lógica pura em
## `logic/` (categorias, listagem, linhas, criação, argumentos de teste, achados) e aos validadores e ao compilador do
## roteiro. Nada daqui roda no jogo.
##
## Abas: Banco (lista os `.tres` por categoria, mostra no Inspector, Novo / Duplicar / Mostrar no FileSystem; heróis, inimigos
## e encontros ganham também um formulário à direita da lista, M17),
## Mapas (o registro de mapas e o assistente Novo mapa, M17),
## Roteiros (sub-vistas Lista, os eventos e erros dos `.roteiro`; Editor, o editor de blocos; e Simular, o simulador de
## eventos, M17), Validar (tools/validate/check_all.gd num processo à parte) e Testar
## (roda o jogo com os flags de dev).
##
## Abrir um `.roteiro` numa linha: o script editor do Godot só abre `Script`, e `.roteiro` é um recurso importado
## (RoteiroBook), então não há `edit_script` possível. Um clique seleciona o arquivo no FileSystem; duplo clique (ou Enter)
## também o abre no editor de texto padrão do sistema com `OS.shell_open`, e a linha do achado fica na barra de estado.
##
## Testar daqui: abre o jogo (cena principal do projeto) num processo à parte, `godot --path <projeto> -- <flags>`, com
## `OS.create_process`. O caminho "oficial" (`ProjectSettings` `editor/run/main_run_args` + `EditorInterface.play_main_scene()`)
## foi testado no Godot 4.7.2 e não repassa os argumentos quando o ajuste é feito por script (o diálogo "Personalizar
## instâncias de execução" guarda o texto na própria interface), por isso o painel não o usa. Custo: o jogo não aparece
## no Depurador do editor.

const Categories: GDScript = preload("res://addons/vat_editor/logic/vat_categories.gd")
const Catalog: GDScript = preload("res://addons/vat_editor/logic/vat_catalog.gd")
const Rows: GDScript = preload("res://addons/vat_editor/logic/vat_rows.gd")
const NewEntry: GDScript = preload("res://addons/vat_editor/logic/vat_new_entry.gd")
const RunArgs: GDScript = preload("res://addons/vat_editor/logic/vat_run_args.gd")
const Issues: GDScript = preload("res://addons/vat_editor/logic/vat_issues.gd")
const Roteiros: GDScript = preload("res://addons/vat_editor/logic/vat_roteiros.gd")
const RoteiroEditor: GDScript = preload("res://addons/vat_editor/ui/roteiro_editor.gd")
const EventSimulatorPanel: GDScript = preload("res://addons/vat_editor/ui/event_simulator_panel.gd")
const MapsPanel: GDScript = preload("res://addons/vat_editor/ui/maps_panel.gd")
const WorldPanel: GDScript = preload("res://addons/vat_editor/ui/world_graph_panel.gd")
const HeroForm: GDScript = preload("res://addons/vat_editor/ui/forms/hero_form.gd")
const EnemyForm: GDScript = preload("res://addons/vat_editor/ui/forms/enemy_form.gd")
const EncounterForm: GDScript = preload("res://addons/vat_editor/ui/forms/encounter_form.gd")

## Categoria do Banco -> formulário (as demais só têm o Inspector).
const FORM_SCRIPTS: Dictionary = {&"heroes": HeroForm, &"enemies": EnemyForm, &"encounters": EncounterForm}

const COLOR_ERROR: Color = Color(1.0, 0.45, 0.4)
const COLOR_WARNING: Color = Color(1.0, 0.85, 0.4)
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)

var tabs: TabContainer
var status: Label

# Banco
var category_bar: TabBar
var search: LineEdit
var list: Tree
var count_label: Label
var new_button: Button
var duplicate_button: Button
var reveal_button: Button
var _resources: Dictionary = {}
var _category: StringName = &""
var _loaded_once: bool = false
var _new_dialog: ConfirmationDialog
var _new_id: LineEdit
var _new_folder: LineEdit
var _new_info: Label
var _new_error: Label
var _new_source: Resource
## Formulários do Banco (M17): a divisão lista | formulário, o painel do formulário, um formulário por categoria (criado ao
## primeiro uso), o caminho aberto nele, e a pergunta de "alterações não salvas" ao trocar de item.
var bank_split: HSplitContainer
var form_holder: VBoxContainer
var form_hint: Label
var _forms: Dictionary = {}
var _open_path: String = ""
var _restoring: bool = false
var _guard_dialog: ConfirmationDialog
var _guard_then: Callable
var _guard_cancel: Callable

# Roteiros
var roteiro_sub: TabContainer
var roteiro_tree: Tree
var roteiro_summary: Label
var roteiro_editor: HSplitContainer
var simulator: HSplitContainer
var _content_index: ContentIndex

# Mapas
var maps_panel: VBoxContainer

# Mundo
var world_panel: VBoxContainer

# Validar
var validate_tree: Tree
var validate_summary: Label

# Testar
var map_option: OptionButton
var spawn_option: OptionButton
var encounter_option: OptionButton
var level_spin: SpinBox
var arena_option: OptionButton
var _game_pid: int = -1

func _init() -> void:
	name = "VAT"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	status = Label.new()
	status.text = "Painel VAT pronto."
	status.clip_text = true
	add_child(status)
	_build_bank()
	_build_roteiros()
	_build_maps()
	_build_world()
	_build_validate()
	_build_test()
	tabs.tab_changed.connect(_on_tab_changed)
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if is_visible_in_tree() and not _loaded_once:
		_loaded_once = true
		_reload_all()

func _on_tab_changed(index: int) -> void:
	var title: String = tabs.get_tab_title(index)
	if title == "Roteiros" and roteiro_tree.get_root() == null:
		_scan_roteiros()
	elif title == "Mapas":
		maps_panel.call(&"refresh")
	elif title == "Mundo":
		world_panel.call(&"refresh")

func _say(text: String) -> void:
	status.text = text

func _reload_all() -> void:
	_content_index = null
	for key: StringName in Categories.keys():
		_resources[key] = Catalog.load_category(key)
	_refresh_list()
	_fill_encounters()

# --- Banco -----------------------------------------------------------------------------

func _build_bank() -> void:
	var page := VBoxContainer.new()
	page.name = "Banco"
	tabs.add_child(page)
	category_bar = TabBar.new()
	category_bar.tab_alignment = TabBar.ALIGNMENT_LEFT
	category_bar.clip_tabs = false
	for c: Dictionary in Categories.all():
		category_bar.add_tab(c["label"])
	_category = Categories.keys()[0]
	category_bar.tab_changed.connect(_on_category_changed)
	page.add_child(category_bar)
	bank_split = HSplitContainer.new()
	bank_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(bank_split)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.custom_minimum_size.x = 360
	bank_split.add_child(left)
	var top := HBoxContainer.new()
	left.add_child(top)
	search = LineEdit.new()
	search.placeholder_text = "Buscar por id, nome ou coluna"
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(_t: String) -> void: _refresh_list())
	top.add_child(search)
	count_label = Label.new()
	top.add_child(count_label)
	list = Tree.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.hide_root = true
	list.column_titles_visible = true
	list.select_mode = Tree.SELECT_ROW
	list.item_selected.connect(_on_row_selected)
	list.item_activated.connect(_on_row_selected)
	left.add_child(list)
	var buttons := HBoxContainer.new()
	left.add_child(buttons)
	new_button = _button(buttons, "Novo...", _on_new_pressed)
	duplicate_button = _button(buttons, "Duplicar...", _on_duplicate_pressed)
	reveal_button = _button(buttons, "Mostrar no FileSystem", _on_reveal_pressed)
	_button(buttons, "Atualizar", func() -> void: _guard_dirty(_reload_all))
	form_holder = VBoxContainer.new()
	form_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form_holder.size_flags_stretch_ratio = 1.2
	form_holder.custom_minimum_size.x = 520
	form_holder.visible = FORM_SCRIPTS.has(_category)
	bank_split.add_child(form_holder)
	form_hint = Label.new()
	form_hint.text = "Selecione um item da lista para editar aqui."
	form_hint.add_theme_color_override("font_color", COLOR_MUTED)
	form_holder.add_child(form_hint)
	_build_guard_dialog()
	_build_new_dialog()

func _button(parent: Node, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	parent.add_child(b)
	return b

func _build_new_dialog() -> void:
	_new_dialog = ConfirmationDialog.new()
	_new_dialog.dialog_hide_on_ok = false
	_new_dialog.ok_button_text = "Criar"
	_new_dialog.cancel_button_text = "Cancelar"
	_new_dialog.min_size = Vector2i(520, 0)
	var box := VBoxContainer.new()
	_new_dialog.add_child(box)
	_new_info = Label.new()
	box.add_child(_new_info)
	box.add_child(_labelled("Id (letras minúsculas, números e _):"))
	_new_id = LineEdit.new()
	_new_id.text_submitted.connect(func(_t: String) -> void: _on_new_confirmed())
	box.add_child(_new_id)
	box.add_child(_labelled("Pasta:"))
	_new_folder = LineEdit.new()
	box.add_child(_new_folder)
	_new_error = Label.new()
	_new_error.add_theme_color_override("font_color", COLOR_ERROR)
	_new_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_new_error)
	_new_dialog.confirmed.connect(_on_new_confirmed)
	add_child(_new_dialog)

func _labelled(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _on_category_changed(index: int) -> void:
	if _restoring or Categories.keys()[index] == _category:
		return
	var back: int = Categories.keys().find(_category)
	_guard_dirty(func() -> void: _switch_category(index), func() -> void:
		_restoring = true
		category_bar.current_tab = back
		_restoring = false)

func _switch_category(index: int) -> void:
	_category = Categories.keys()[index]
	_open_path = ""
	_show_form(null)
	_refresh_list()

func _current_rows() -> Array[Dictionary]:
	return Rows.rows(_category, _resources.get(_category, []))

func _refresh_list(select_path: String = "") -> void:
	var was_restoring: bool = _restoring
	_restoring = true
	_fill_list(select_path)
	_restoring = was_restoring

func _fill_list(select_path: String) -> void:
	var all_rows: Array[Dictionary] = _current_rows()
	var shown: Array[Dictionary] = Rows.filter(all_rows, search.text)
	var headers: PackedStringArray = Rows.headers(_category)
	list.clear()
	list.columns = headers.size()
	for i: int in headers.size():
		list.set_column_title(i, headers[i])
		list.set_column_expand(i, i <= 1)
		list.set_column_custom_minimum_width(i, 130 if i > 1 else 150)
	var root: TreeItem = list.create_item()
	for r: Dictionary in shown:
		var item: TreeItem = list.create_item(root)
		var cells: PackedStringArray = r["cells"]
		for i: int in cells.size():
			item.set_text(i, cells[i])
		item.set_metadata(0, r["path"])
		item.set_tooltip_text(0, r["path"])
		if select_path != "" and r["path"] == select_path:
			item.select(0)
			list.scroll_to_item(item)
	count_label.text = "%d de %d" % [shown.size(), all_rows.size()]

func _selected_path() -> String:
	var item: TreeItem = list.get_selected()
	return str(item.get_metadata(0)) if item != null else ""

func _on_row_selected() -> void:
	if _restoring:
		return
	var path: String = _selected_path()
	if path == "" or path == _open_path:
		return
	var back: String = _open_path
	_guard_dirty(func() -> void: _open_in_forms(path), func() -> void: _refresh_list(back))

## Abre o recurso no Inspector e, nas categorias com formulário, no formulário.
func _open_in_forms(path: String) -> void:
	var res: Resource = load(path)
	if res == null:
		return
	EditorInterface.edit_resource(res)
	_say(path)
	_open_path = path
	_show_form(res)

## Mostra o formulário da categoria atual com `res` (null = só a dica). As categorias sem formulário escondem o painel.
func _show_form(res: Resource) -> void:
	form_holder.visible = FORM_SCRIPTS.has(_category)
	for f: Variant in _forms.values():
		(f as Control).visible = false
	form_hint.visible = true
	if res == null or not FORM_SCRIPTS.has(_category):
		return
	if not _forms.has(_category):
		_forms[_category] = _make_form(_category)
	var form: Control = _forms[_category]
	form.call(&"edit", res, _resources.get(_category, []))
	form.visible = true
	form_hint.visible = false

func _make_form(category: StringName) -> Control:
	var form: Control = (FORM_SCRIPTS[category] as GDScript).new()
	form_holder.add_child(form)
	form.connect(&"status", _say)
	form.connect(&"saved", _on_form_saved)
	form.connect(&"reverted", func(r: Resource) -> void: EditorInterface.edit_resource(r))
	if form.has_signal(&"play_requested"):
		form.connect(&"play_requested", _on_form_play)
	return form

func _active_form() -> Control:
	if _open_path == "" or not _forms.has(_category):
		return null
	return _forms[_category] as Control

func _on_form_saved(path: String) -> void:
	EditorInterface.get_resource_filesystem().update_file(path)
	_refresh_list(path)

## "Testar encontro" do formulário: escolhe o encontro na aba Testar e roda (nível e arena dessa aba).
func _on_form_play(encounter_id: StringName) -> void:
	_fill_encounters()
	for i: int in encounter_option.item_count:
		if encounter_option.get_item_text(i) == String(encounter_id):
			encounter_option.select(i)
			_on_play_battle_pressed()
			return
	_say("Encontro '%s' não está na lista do Testar." % encounter_id)

# --- alterações não salvas ---

func _build_guard_dialog() -> void:
	_guard_dialog = ConfirmationDialog.new()
	_guard_dialog.title = "Alterações não salvas"
	_guard_dialog.ok_button_text = "Salvar"
	_guard_dialog.cancel_button_text = "Cancelar"
	_guard_dialog.add_button("Descartar", true, "discard")
	_guard_dialog.confirmed.connect(_on_guard_save)
	_guard_dialog.custom_action.connect(_on_guard_discard)
	_guard_dialog.canceled.connect(_on_guard_cancel)
	add_child(_guard_dialog)

## Roda `then` já se o formulário aberto está limpo. Se tem alterações, pergunta: Salvar, Descartar (relê o arquivo) ou
## Cancelar (roda `cancel`).
func _guard_dirty(then: Callable, cancel: Callable = Callable()) -> void:
	var form: Control = _active_form()
	if form == null or not form.call(&"is_dirty"):
		then.call()
		return
	_guard_then = then
	_guard_cancel = cancel
	_guard_dialog.dialog_text = "%s tem alterações não salvas.\nSalvar antes de continuar?" % _open_path.get_file()
	_guard_dialog.popup_centered()

func _on_guard_save() -> void:
	var form: Control = _active_form()
	if form != null and not form.call(&"save"):
		_on_guard_cancel()
		return
	_guard_then.call()

func _on_guard_discard(action: StringName) -> void:
	if action != &"discard":
		return
	_guard_dialog.hide()
	var form: Control = _active_form()
	if form != null:
		form.call(&"revert")
	_guard_then.call()

func _on_guard_cancel() -> void:
	if _guard_cancel.is_valid():
		_guard_cancel.call()

## Rola o formulário aberto (conferência visual).
func scroll_form(pixels: int) -> void:
	var form: Control = _active_form()
	if form != null:
		form.call(&"scroll_to", pixels)

## Para a conferência visual: abre a categoria (a chave ou o rótulo) e, com `pick_id`, o item com esse id no formulário.
func show_bank(category: String, pick_id: String) -> void:
	if not _loaded_once:
		_loaded_once = true
		_reload_all()
	var all: Array[Dictionary] = Categories.all()
	for i: int in all.size():
		if String(all[i]["key"]) == category or String(all[i]["label"]).to_lower() == category.to_lower():
			_restoring = true
			category_bar.current_tab = i
			_restoring = false
			_switch_category(i)
	if pick_id == "":
		return
	for r: Variant in _resources.get(_category, []):
		if str((r as Resource).get(&"id")) == pick_id:
			_refresh_list((r as Resource).resource_path)
			_open_in_forms((r as Resource).resource_path)
			return
	_say("Id '%s' não encontrado em %s." % [pick_id, _category])

func _on_reveal_pressed() -> void:
	var path: String = _selected_path()
	if path == "":
		_say("Selecione uma entrada da lista primeiro.")
		return
	EditorInterface.select_file(path)
	_say("Mostrado no FileSystem: %s" % path)

func _on_new_pressed() -> void:
	_guard_dirty(func() -> void: _open_new_dialog(null))

func _on_duplicate_pressed() -> void:
	var path: String = _selected_path()
	if path == "":
		_say("Selecione a entrada a duplicar.")
		return
	_guard_dirty(func() -> void: _open_new_dialog(load(path)))

func _open_new_dialog(source: Resource) -> void:
	_new_source = source
	var cat: Dictionary = Categories.get_category(_category)
	if source == null:
		_new_dialog.title = "Novo: %s" % cat["label"]
		_new_info.text = "Cria a partir do modelo %s." % str(cat["template"]).get_file()
		_new_folder.text = cat["new_folder"]
	else:
		_new_dialog.title = "Duplicar: %s" % str(source.get(&"id"))
		_new_info.text = "Copia %s com um id novo." % source.resource_path
		_new_folder.text = source.resource_path.get_base_dir()
	_new_id.text = ""
	_new_error.text = ""
	_new_dialog.popup_centered()
	_new_id.grab_focus()

func _on_new_confirmed() -> void:
	var built: Dictionary = NewEntry.build(_category, _new_id.text.strip_edges(), _new_folder.text.strip_edges(),
			_new_source, _resources.get(_category, []))
	if not built["ok"]:
		_new_error.text = built["error"]
		return
	var res: Resource = built["resource"]
	var path: String = built["path"]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error = ResourceSaver.save(res, path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		_new_error.text = "Não foi possível salvar %s (erro %d)." % [path, err]
		return
	_new_dialog.hide()
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	fs.update_file(path)
	fs.scan()
	_resources[_category] = Catalog.load_category(_category)
	search.text = ""
	_refresh_list(path)
	_open_in_forms(path)
	EditorInterface.select_file(path)
	_say("Criado %s" % path)

# --- Roteiros --------------------------------------------------------------------------

func _build_roteiros() -> void:
	var outer := VBoxContainer.new()
	outer.name = "Roteiros"
	tabs.add_child(outer)
	roteiro_sub = TabContainer.new()
	roteiro_sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(roteiro_sub)
	var page := VBoxContainer.new()
	page.name = "Lista"
	roteiro_sub.add_child(page)
	roteiro_editor = RoteiroEditor.new()
	roteiro_editor.name = "Editor"
	roteiro_editor.content = _content
	roteiro_editor.status.connect(_say)
	roteiro_editor.saved.connect(func(_p: String) -> void: _scan_roteiros())
	roteiro_sub.add_child(roteiro_editor)
	simulator = EventSimulatorPanel.new()
	simulator.name = "Simular"
	simulator.content = _content
	simulator.text_provider = roteiro_editor.current_text_for
	simulator.status.connect(_say)
	roteiro_sub.add_child(simulator)
	roteiro_sub.tab_changed.connect(_on_roteiro_sub_changed)
	var top := HBoxContainer.new()
	page.add_child(top)
	_button(top, "Atualizar", _scan_roteiros)
	roteiro_summary = Label.new()
	top.add_child(roteiro_summary)
	roteiro_tree = Tree.new()
	roteiro_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roteiro_tree.hide_root = true
	roteiro_tree.item_selected.connect(_on_roteiro_selected)
	roteiro_tree.item_activated.connect(_on_roteiro_activated)
	page.add_child(roteiro_tree)
	var hint := Label.new()
	hint.text = "Clique: seleciona o arquivo no FileSystem. Duplo clique: abre no editor de texto do sistema (a linha aparece na barra de estado)."
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	page.add_child(hint)

## O índice de conteúdo (`res://data`), carregado uma vez e compartilhado com o editor de blocos e o simulador.
func _content() -> ContentIndex:
	if _content_index == null:
		_content_index = RoteiroTools.scan_content()
	return _content_index

func _on_roteiro_sub_changed(index: int) -> void:
	match roteiro_sub.get_tab_title(index):
		"Editor":
			roteiro_editor.ensure_loaded()
		"Simular":
			simulator.ensure_loaded()

## Mostra a sub-vista `sub` (Lista, Editor ou Simular) da aba Roteiros, já no evento `event_id` (o primeiro arquivo que o
## tem). No Simular, `answers` (ex.: "0") preenche as respostas e a simulação roda. Para a captura de tela.
func show_roteiro(sub: String, event_id: String = "", answers: String = "") -> void:
	for i: int in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Roteiros":
			tabs.current_tab = i
	for i: int in roteiro_sub.get_tab_count():
		if roteiro_sub.get_tab_title(i) == sub:
			roteiro_sub.current_tab = i
	if sub == "Lista":
		_scan_roteiros()
		return
	roteiro_editor.ensure_loaded()
	var path: String = roteiro_editor.find_event_path(event_id) if event_id != "" else ""
	if path != "":
		roteiro_editor.select_event(path, event_id)
	if sub == "Simular":
		simulator.ensure_loaded()
		if path != "":
			simulator.select(path, event_id)
		if answers != "":
			simulator.set_answers(answers)
			await simulator.run_simulation()

## "Abrir no editor de blocos" do Inspector: Roteiros > Editor com o arquivo e o evento.
func open_roteiro_event(path: String, event_id: String) -> void:
	for i: int in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Roteiros":
			tabs.current_tab = i
	for i: int in roteiro_sub.get_tab_count():
		if roteiro_sub.get_tab_title(i) == "Editor":
			roteiro_sub.current_tab = i
	roteiro_editor.ensure_loaded()
	roteiro_editor.open_event_guarded(path, event_id)

func _scan_roteiros() -> void:
	roteiro_tree.clear()
	var root: TreeItem = roteiro_tree.create_item()
	var reports: Array[Dictionary] = Roteiros.scan(RoteiroTools.scan_content())
	var errors: int = 0
	var warnings: int = 0
	for rep: Dictionary in reports:
		var errs: Array = rep["errors"]
		var warns: Array = rep["warnings"]
		var evs: Array = rep["events"]
		errors += errs.size()
		warnings += warns.size()
		var file_item: TreeItem = roteiro_tree.create_item(root)
		file_item.set_text(0, "%s  (%d eventos, %d erros, %d avisos)" % [str(rep["path"]).get_file(), evs.size(), errs.size(), warns.size()])
		file_item.set_metadata(0, {"path": rep["path"], "line": 0})
		file_item.set_tooltip_text(0, rep["path"])
		for f: Dictionary in errs:
			_finding_item(file_item, rep["path"], f, "erro", COLOR_ERROR)
		for f: Dictionary in warns:
			_finding_item(file_item, rep["path"], f, "aviso", COLOR_WARNING)
		for e: String in evs:
			var ev_item: TreeItem = roteiro_tree.create_item(file_item)
			ev_item.set_text(0, "evento %s" % e)
			ev_item.set_custom_color(0, COLOR_MUTED)
			ev_item.set_metadata(0, {"path": rep["path"], "line": 0})
		file_item.collapsed = errs.is_empty() and warns.is_empty()
	roteiro_summary.text = "%d arquivo(s), %d erro(s), %d aviso(s)" % [reports.size(), errors, warnings]
	_say(roteiro_summary.text)

func _finding_item(parent: TreeItem, path: String, f: Dictionary, label: String, color: Color) -> void:
	var item: TreeItem = roteiro_tree.create_item(parent)
	item.set_text(0, "%s, %s" % [label, Roteiros.format_finding(f)])
	item.set_custom_color(0, color)
	item.set_metadata(0, {"path": path, "line": f["line"]})

func _on_roteiro_selected() -> void:
	var item: TreeItem = roteiro_tree.get_selected()
	if item != null and item.get_metadata(0) is Dictionary:
		EditorInterface.select_file(str(item.get_metadata(0)["path"]))

func _on_roteiro_activated() -> void:
	var item: TreeItem = roteiro_tree.get_selected()
	if item != null and item.get_metadata(0) is Dictionary:
		var meta: Dictionary = item.get_metadata(0)
		_open_roteiro(str(meta["path"]), int(meta["line"]))

func _open_roteiro(path: String, line: int) -> void:
	EditorInterface.select_file(path)
	OS.shell_open(ProjectSettings.globalize_path(path))
	_say("%s%s aberto no editor de texto do sistema." % [path, ":%d" % line if line > 0 else ""])

# --- Validar ---------------------------------------------------------------------------

func _build_maps() -> void:
	maps_panel = MapsPanel.new()
	maps_panel.connect(&"status", _say)
	tabs.add_child(maps_panel)

func _build_world() -> void:
	world_panel = WorldPanel.new()
	world_panel.connect(&"status", _say)
	tabs.add_child(world_panel)

## Para a captura de tela: mostra a aba Mundo, com ou sem os mapas de teste.
func show_world(with_tests: bool = false) -> void:
	for i: int in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Mundo":
			tabs.current_tab = i
	world_panel.call(&"show_tests", with_tests)

## Para a captura de tela: mostra a aba Mapas e, com `wizard`, abre o diálogo Novo mapa (com `wizard_id` no campo de id).
func show_maps(wizard: bool = false, wizard_id: String = "") -> void:
	for i: int in tabs.get_tab_count():
		if tabs.get_tab_title(i) == "Mapas":
			tabs.current_tab = i
	if wizard:
		maps_panel.call(&"open_wizard", wizard_id)

func _build_validate() -> void:
	var page := VBoxContainer.new()
	page.name = "Validar"
	tabs.add_child(page)
	var top := HBoxContainer.new()
	page.add_child(top)
	_button(top, "Validar tudo", _on_validate_pressed)
	validate_summary = Label.new()
	top.add_child(validate_summary)
	validate_tree = Tree.new()
	validate_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	validate_tree.hide_root = true
	validate_tree.item_selected.connect(_on_issue_selected)
	validate_tree.item_activated.connect(_on_issue_activated)
	page.add_child(validate_tree)

func _on_validate_pressed() -> void:
	await run_validation()

## Roda os validadores num Godot headless à parte (os scripts do jogo não são `@tool`, então não executam dentro do
## editor) sem travar a interface, e preenche a árvore. Público para a captura de tela.
func run_validation() -> void:
	validate_summary.text = "Validando (pode levar alguns segundos)..."
	var out_file: String = ProjectSettings.globalize_path("user://vat_validate.txt")
	DirAccess.make_dir_recursive_absolute("user://")
	DirAccess.remove_absolute(out_file)
	var args: PackedStringArray = Issues.child_args(ProjectSettings.globalize_path("res://"), out_file)
	var worker := Thread.new()
	worker.start(func() -> int: return OS.execute(OS.get_executable_path(), args))
	while worker.is_alive():
		await get_tree().process_frame
	var exit_code: int = int(worker.wait_to_finish())
	var exists: bool = FileAccess.file_exists(out_file)
	var res: Dictionary = Issues.outcome(exit_code, exists, FileAccess.get_file_as_string(out_file) if exists else "")
	validate_tree.clear()
	if not bool(res["ok"]):
		validate_summary.text = String(res["message"])
		validate_summary.add_theme_color_override("font_color", COLOR_ERROR)
		_say(validate_summary.text)
		return
	validate_summary.remove_theme_color_override("font_color")
	var issues: Array[ValidationIssue] = res["issues"]
	var g: Dictionary = Issues.group(issues)
	var root: TreeItem = validate_tree.create_item()
	_issue_group(root, "Erros", g["errors"], COLOR_ERROR)
	_issue_group(root, "Avisos", g["warnings"], COLOR_WARNING)
	validate_summary.text = String(res["message"])
	_say(validate_summary.text)

func _issue_group(root: TreeItem, title: String, issues: Array, color: Color) -> void:
	var head: TreeItem = validate_tree.create_item(root)
	head.set_text(0, "%s (%d)" % [title, issues.size()])
	head.set_custom_color(0, color)
	head.set_selectable(0, false)
	for i: ValidationIssue in issues:
		var e: Dictionary = Issues.entry(i)
		var item: TreeItem = validate_tree.create_item(head)
		item.set_text(0, e["text"])
		item.set_metadata(0, e)

func _on_issue_selected() -> void:
	var item: TreeItem = validate_tree.get_selected()
	if item == null or not item.get_metadata(0) is Dictionary:
		return
	var e: Dictionary = item.get_metadata(0)
	if Issues.target_kind(e["path"]) != &"roteiro":
		_open_issue(e)

func _on_issue_activated() -> void:
	var item: TreeItem = validate_tree.get_selected()
	if item != null and item.get_metadata(0) is Dictionary:
		_open_issue(item.get_metadata(0))

func _open_issue(e: Dictionary) -> void:
	var path: String = e["path"]
	match Issues.target_kind(path):
		&"resource":
			var res: Resource = load(path)
			if res != null:
				EditorInterface.edit_resource(res)
			EditorInterface.select_file(path)
		&"roteiro":
			_open_roteiro(path, int(e["line"]))
		&"scene":
			EditorInterface.select_file(path)
		_:
			_say(e["text"])

# --- Testar ----------------------------------------------------------------------------

func _build_test() -> void:
	var page := VBoxContainer.new()
	page.name = "Testar"
	tabs.add_child(page)
	page.add_child(_labelled("Jogar este mapa (perfil da fatia, saves em user://demo_saves/):"))
	var row := HBoxContainer.new()
	page.add_child(row)
	map_option = OptionButton.new()
	var map_ids: Array[String] = []
	for k: StringName in Game.default_registry().ids():
		map_ids.append(String(k))
	map_ids.sort()
	for m: String in map_ids:
		map_option.add_item(m)
	map_option.item_selected.connect(func(_i: int) -> void: _fill_spawns())
	row.add_child(map_option)
	spawn_option = OptionButton.new()
	row.add_child(spawn_option)
	_button(row, "Jogar este mapa", _on_play_map_pressed)
	page.add_child(HSeparator.new())
	page.add_child(_labelled("Testar encontro (luta na arena do mapa escolhido; sem mapa, a do mapa inicial):"))
	var row2 := HBoxContainer.new()
	page.add_child(row2)
	encounter_option = OptionButton.new()
	row2.add_child(encounter_option)
	row2.add_child(_labelled("nível"))
	level_spin = SpinBox.new()
	level_spin.min_value = 1
	level_spin.max_value = 99
	level_spin.value = Game.DEV_BATTLE_LEVEL
	row2.add_child(level_spin)
	row2.add_child(_labelled("mapa"))
	arena_option = OptionButton.new()
	arena_option.add_item("(inicial)")
	for m: String in map_ids:
		arena_option.add_item(m)
	row2.add_child(arena_option)
	_button(row2, "Testar encontro", _on_play_battle_pressed)
	_button(page, "Parar o jogo", stop_game)
	_fill_spawns()
	_fill_encounters()

func _fill_spawns() -> void:
	spawn_option.clear()
	spawn_option.add_item("(padrão)")
	var map_id := StringName(map_option.get_item_text(map_option.selected))
	for m: StringName in RunArgs.markers_of(Game.default_registry().scene_of(map_id)):
		spawn_option.add_item(String(m))

func _fill_encounters() -> void:
	if encounter_option == null:
		return
	encounter_option.clear()
	var found: Array = _resources.get(&"encounters", [])
	if found.is_empty():
		found = Catalog.load_category(&"encounters")
	for r: Variant in found:
		encounter_option.add_item(str((r as Resource).get(&"id")))

func _selected_spawn() -> StringName:
	return &"" if spawn_option.selected <= 0 else StringName(spawn_option.get_item_text(spawn_option.selected))

func _on_play_map_pressed() -> void:
	var map_id := StringName(map_option.get_item_text(map_option.selected))
	run_game(RunArgs.play_map(map_id, _selected_spawn()))

func _on_play_battle_pressed() -> void:
	if encounter_option.item_count == 0:
		_say("Nenhum encontro na lista.")
		return
	var enc := StringName(encounter_option.get_item_text(encounter_option.selected))
	var arena: StringName = &"" if arena_option.selected <= 0 else StringName(arena_option.get_item_text(arena_option.selected))
	run_game(RunArgs.battle(enc, int(level_spin.value), arena))

## Roda o jogo com `args` como argumentos do jogo, num processo à parte (substitui um teste em andamento).
func run_game(args: PackedStringArray) -> void:
	stop_game()
	var cmd: PackedStringArray = RunArgs.process_args(ProjectSettings.globalize_path("res://"), args)
	_game_pid = OS.create_process(OS.get_executable_path(), cmd)
	if _game_pid <= 0:
		_say("Não foi possível iniciar o jogo.")
		return
	_say("Jogo iniciado (pid %d) com: %s" % [_game_pid, RunArgs.to_setting(args)])

func stop_game() -> void:
	if _game_pid > 0 and OS.is_process_running(_game_pid):
		OS.kill(_game_pid)
	_game_pid = -1

func _exit_tree() -> void:
	stop_game()

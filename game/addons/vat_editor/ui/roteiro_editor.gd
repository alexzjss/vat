@tool
extends HSplitContainer

## Editor de blocos do roteiro (M17), sub-vista "Editor" da aba Roteiros. À esquerda os `.roteiro` e os eventos; no centro
## os blocos do evento escolhido, um cartão por bloco; no rodapé os erros e avisos do compilador, ao vivo. Lê e grava o
## mesmo `.roteiro`, no formato canônico (`RoteiroDoc`). A lógica fica em `logic/roteiro_editor_logic.gd` e
## `logic/roteiro_options.gd`; aqui só há controles.
##
## Salvar grava o arquivo (LF) e o reimporta: `update_file` (para arquivo novo) e `reimport_files` do
## `EditorFileSystem`, então o `RoteiroBook` do jogo se atualiza na hora.

const Logic: GDScript = preload("res://addons/vat_editor/logic/roteiro_editor_logic.gd")
const Options: GDScript = preload("res://addons/vat_editor/logic/roteiro_options.gd")
const Catalog: GDScript = preload("res://addons/vat_editor/logic/vat_catalog.gd")
const BlockCard: GDScript = preload("res://addons/vat_editor/ui/block_card.gd")

## Mensagem para a barra de estado do painel.
signal status(text: String)
## O arquivo foi gravado (a lista de roteiros do painel se atualiza).
signal saved(path: String)

const COLOR_ERROR: Color = Color(1.0, 0.45, 0.4)
const COLOR_WARNING: Color = Color(1.0, 0.85, 0.4)
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)
const NEW_FILE_FOLDER: String = "res://data/fatia/roteiro"
const NO_EVENT: int = -2

## `Callable() -> ContentIndex`, dado pelo painel (o índice é compartilhado com o simulador).
var content: Callable

var session: Logic.Session
var current: int = NO_EVENT
var _hero_defs: Array[CharacterDef] = []
var _speaker_defs: Array[SpeakerDef] = []
var _other_docs: Dictionary = {}
var _loaded: bool = false
var _anchor: int = -1
var _cards: Dictionary = {}
var _selecting: bool = false

var file_tree: Tree
var title_label: Label
var dirty_label: Label
var leading_box: VBoxContainer
var leading_edit: TextEdit
var cards_box: VBoxContainer
var scroll: ScrollContainer
var empty_label: Label
var add_menu: MenuButton
var diag_tree: Tree
var diag_summary: Label
var save_button: Button
var text_button: Button
var new_event_button: Button
var rename_button: Button
var delete_button: Button
var _diag_timer: Timer
var _prompt: ConfirmationDialog
var _prompt_edit: LineEdit
var _prompt_info: Label
var _prompt_error: Label
var _prompt_action: Callable
var _confirm: ConfirmationDialog
var _confirm_action: Callable
var _guard_dialog: ConfirmationDialog
var _guard_then: Callable
var _guard_discard: bool = false
var _guard_cancel: Callable
var _text_dialog: AcceptDialog
var _text_view: TextEdit

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	_build_left()
	_build_center()
	_build_dialogs()
	_diag_timer = Timer.new()
	_diag_timer.one_shot = true
	_diag_timer.wait_time = 0.3
	_diag_timer.timeout.connect(_refresh_diagnostics)
	add_child(_diag_timer)
	_show_current()

# --- montagem ----------------------------------------------------------------------------

func _build_left() -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(230, 0)
	add_child(left)
	file_tree = Tree.new()
	file_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	file_tree.hide_root = true
	file_tree.item_selected.connect(_on_tree_selected)
	left.add_child(file_tree)
	var row1 := HFlowContainer.new()
	left.add_child(row1)
	_button(row1, "Novo arquivo", _on_new_file)
	new_event_button = _button(row1, "Novo evento", _on_new_event)
	rename_button = _button(row1, "Renomear", _on_rename_event)
	delete_button = _button(row1, "Apagar evento", _on_delete_event)
	_button(row1, "Atualizar", reload_all)

func _build_center() -> void:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(center)
	var top := HBoxContainer.new()
	center.add_child(top)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	top.add_child(title_label)
	dirty_label = Label.new()
	top.add_child(dirty_label)
	text_button = _button(top, "Ver texto", _on_view_text)
	save_button = _button(top, "Salvar", save)
	leading_box = VBoxContainer.new()
	center.add_child(leading_box)
	var lead_label := Label.new()
	lead_label.text = "Comentários do evento (colados no ===):"
	lead_label.add_theme_color_override("font_color", COLOR_MUTED)
	leading_box.add_child(lead_label)
	leading_edit = TextEdit.new()
	leading_edit.scroll_fit_content_height = true
	leading_edit.custom_minimum_size = Vector2(0, 36)
	leading_edit.placeholder_text = "(sem comentários)"
	leading_edit.text_changed.connect(_on_leading_changed)
	leading_box.add_child(leading_edit)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	empty_label = Label.new()
	empty_label.add_theme_color_override("font_color", COLOR_MUTED)
	inner.add_child(empty_label)
	cards_box = VBoxContainer.new()
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("separation", 6)
	inner.add_child(cards_box)
	add_menu = MenuButton.new()
	add_menu.text = "+ Adicionar bloco"
	add_menu.flat = false
	add_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_build_add_menu()
	inner.add_child(add_menu)
	diag_summary = Label.new()
	center.add_child(diag_summary)
	diag_tree = Tree.new()
	diag_tree.custom_minimum_size = Vector2(0, 110)
	diag_tree.hide_root = true
	diag_tree.item_selected.connect(_on_diag_selected)
	center.add_child(diag_tree)

func _build_add_menu() -> void:
	var popup: PopupMenu = add_menu.get_popup()
	for c: Dictionary in Logic.CATEGORIES:
		var sub := PopupMenu.new()
		sub.name = str(c["label"])
		var kinds: Array = c["kinds"]
		for k: int in kinds:
			sub.add_item(Logic.title(k), k)
		sub.id_pressed.connect(_on_add_kind)
		popup.add_child(sub)
		popup.add_submenu_item(str(c["label"]), sub.name)

func _button(parent: Node, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	parent.add_child(b)
	return b

func _build_dialogs() -> void:
	_prompt = ConfirmationDialog.new()
	_prompt.dialog_hide_on_ok = false
	_prompt.min_size = Vector2i(460, 0)
	var box := VBoxContainer.new()
	_prompt.add_child(box)
	_prompt_info = Label.new()
	_prompt_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_prompt_info)
	_prompt_edit = LineEdit.new()
	_prompt_edit.text_submitted.connect(func(_t: String) -> void: _on_prompt_ok())
	box.add_child(_prompt_edit)
	_prompt_error = Label.new()
	_prompt_error.add_theme_color_override("font_color", COLOR_ERROR)
	box.add_child(_prompt_error)
	_prompt.confirmed.connect(_on_prompt_ok)
	add_child(_prompt)
	_confirm = ConfirmationDialog.new()
	_confirm.confirmed.connect(func() -> void: _confirm_action.call())
	add_child(_confirm)
	_guard_dialog = ConfirmationDialog.new()
	_guard_dialog.title = "Alterações não salvas"
	_guard_dialog.ok_button_text = "Salvar"
	_guard_dialog.cancel_button_text = "Cancelar"
	_guard_dialog.add_button("Não salvar", false, "skip")
	_guard_dialog.confirmed.connect(_on_guard_save)
	_guard_dialog.custom_action.connect(_on_guard_custom)
	_guard_dialog.canceled.connect(func() -> void:
		if _guard_cancel.is_valid():
			_guard_cancel.call())
	add_child(_guard_dialog)
	_text_dialog = AcceptDialog.new()
	_text_dialog.title = "Texto do roteiro (somente leitura)"
	_text_dialog.min_size = Vector2i(720, 520)
	_text_dialog.ok_button_text = "Fechar"
	var tbox := VBoxContainer.new()
	_text_dialog.add_child(tbox)
	_text_view = TextEdit.new()
	_text_view.editable = false
	_text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tbox.add_child(_text_view)
	var copy := Button.new()
	copy.text = "Copiar"
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_text_view.text)
		status.emit("Texto copiado para a área de transferência."))
	tbox.add_child(copy)
	add_child(_text_dialog)

# --- conteúdo e lista de arquivos --------------------------------------------------------

func ensure_loaded() -> void:
	if not _loaded:
		reload_all()

## Relê o conteúdo (menus) e a lista de arquivos. Mantém o arquivo e o evento abertos.
func reload_all() -> void:
	_loaded = true
	var index: ContentIndex = _index()
	_hero_defs = Options.hero_defs(index)
	_speaker_defs.clear()
	for r: Resource in Catalog.load_category(&"speakers"):
		if r is SpeakerDef:
			_speaker_defs.append(r as SpeakerDef)
	_reload_other_docs()
	_fill_tree()
	if session == null:
		var paths: Array[String] = RoteiroTools.find_roteiros("res://")
		if not paths.is_empty():
			open_file(paths[0], false)
	_show_current()

func _index() -> ContentIndex:
	return content.call() as ContentIndex if content.is_valid() else ContentIndex.from_resources([])

func _reload_other_docs() -> void:
	_other_docs.clear()
	for p: String in RoteiroTools.find_roteiros("res://"):
		var docs: Array[RoteiroDoc] = Logic.load_docs([p] as Array[String])
		if not docs.is_empty():
			_other_docs[p] = docs[0]

func _fill_tree() -> void:
	file_tree.clear()
	var root: TreeItem = file_tree.create_item()
	for p: String in RoteiroTools.find_roteiros("res://"):
		var f: TreeItem = file_tree.create_item(root)
		f.set_text(0, p.get_file())
		f.set_tooltip_text(0, p)
		f.set_metadata(0, {"path": p, "event": NO_EVENT})
		if session != null and session.path == p:
			f.collapsed = false
			var h: TreeItem = file_tree.create_item(f)
			h.set_text(0, "(cabeçalho do arquivo)")
			h.set_custom_color(0, COLOR_MUTED)
			h.set_metadata(0, {"path": p, "event": Logic.HEADER_EVENT})
			for i: int in session.doc.events.size():
				var e: TreeItem = file_tree.create_item(f)
				e.set_text(0, "evento %s" % session.doc.events[i].id)
				e.set_metadata(0, {"path": p, "event": i})
		else:
			f.collapsed = true
			# Um filho só para mostrar a setinha; o conteúdo vem ao abrir o arquivo.
			var stub: TreeItem = file_tree.create_item(f)
			stub.set_text(0, "…")
			stub.set_selectable(0, false)
	_select_in_tree()

func _select_in_tree() -> void:
	if session == null:
		return
	_selecting = true
	var root: TreeItem = file_tree.get_root()
	var item: TreeItem = root.get_first_child() if root != null else null
	while item != null:
		var meta: Dictionary = item.get_metadata(0)
		if meta["path"] == session.path:
			item.collapsed = false
			var child: TreeItem = item.get_first_child()
			while child != null:
				if child.get_metadata(0) is Dictionary and int((child.get_metadata(0) as Dictionary)["event"]) == current:
					child.select(0)
					file_tree.scroll_to_item(child)
				child = child.get_next()
		item = item.get_next()
	_selecting = false

func _on_tree_selected() -> void:
	if _selecting:
		return
	var item: TreeItem = file_tree.get_selected()
	if item == null or not item.get_metadata(0) is Dictionary:
		return
	var meta: Dictionary = item.get_metadata(0)
	_handle_selection.call_deferred(str(meta["path"]), int(meta["event"]))

func _handle_selection(path: String, event: int) -> void:
	if session != null and path == session.path and event != NO_EVENT:
		if event == current:
			return
		_guard_switch(false, func() -> void: _set_current(event), _restore_selection)
	elif session == null or path != session.path:
		_guard_switch(true, func() -> void: open_file(path), _restore_selection)

## Abre o arquivo e o evento pedidos de fora (o Inspector). Com edição não salva em outro arquivo, a confirmação decide.
func open_event_guarded(path: String, event_id: String) -> void:
	if session != null and session.path == path:
		select_event(path, event_id)
		return
	_guard_switch(true, func() -> void: select_event(path, event_id), func() -> void: pass)

func _restore_selection() -> void:
	_select_in_tree()

# --- abrir, trocar, salvar ----------------------------------------------------------------

## Abre um arquivo (sem perguntar nada: quem chama já tratou o "não salvo"). O primeiro evento fica selecionado.
func open_file(path: String, refresh_tree: bool = true) -> void:
	var s: Logic.Session = Logic.Session.open(path)
	if s == null:
		status.emit("Não foi possível abrir %s." % path)
		return
	session = s
	_anchor = -1
	current = 0 if not s.doc.events.is_empty() else (Logic.HEADER_EVENT if not s.doc.items.is_empty() else NO_EVENT)
	if refresh_tree:
		_fill_tree()
	_show_current()
	status.emit("Aberto %s (%d evento(s))." % [path, s.doc.events.size()])

## Abre o arquivo e escolhe o evento pelo id. False se o arquivo não tem o evento.
func select_event(path: String, event_id: String) -> bool:
	if session == null or session.path != path:
		open_file(path)
	if session == null:
		return false
	for i: int in session.doc.events.size():
		if session.doc.events[i].id == event_id:
			_set_current(i)
			return true
	return false

## O caminho do arquivo que tem o evento `event_id` (o primeiro), ou "".
func find_event_path(event_id: String) -> String:
	for p: String in RoteiroTools.find_roteiros("res://"):
		var docs: Array[RoteiroDoc] = Logic.load_docs([p] as Array[String])
		if not docs.is_empty() and docs[0].find_event(event_id) != null:
			return p
	return ""

func _set_current(event: int) -> void:
	current = event
	_anchor = -1
	_select_in_tree()
	_show_current()

func is_dirty() -> bool:
	return session != null and session.dirty()

## Pergunta antes de trocar quando há edições não salvas. `file_switch`: trocar de arquivo descarta as edições
## ("Não salvar" as perde); trocar de evento no mesmo arquivo as mantém no documento ("Não salvar" só troca).
func _guard_switch(file_switch: bool, then: Callable, on_cancel: Callable) -> void:
	if not is_dirty():
		then.call()
		return
	_guard_then = then
	_guard_cancel = on_cancel
	_guard_discard = file_switch
	_guard_dialog.dialog_text = "%s tem alterações não salvas.%s" % [session.path.get_file(),
			" Se não salvar, elas se perdem." if file_switch else " Se não salvar, elas continuam no documento aberto, mas não vão para o arquivo."]
	_guard_dialog.popup_centered()

func _on_guard_save() -> void:
	if save():
		_guard_then.call()
	elif _guard_cancel.is_valid():
		_guard_cancel.call()

func _on_guard_custom(action: StringName) -> void:
	if action != &"skip":
		return
	_guard_dialog.hide()
	if _guard_discard:
		session.revert()
	_guard_then.call()

## Grava o arquivo e o reimporta. False se não gravou.
func save() -> bool:
	if session == null:
		return false
	var err: Error = session.save()
	if err != OK:
		status.emit("Não foi possível gravar %s (erro %d)." % [session.path, err])
		return false
	_reimport(session.path)
	_other_docs[session.path] = RoteiroDoc.parse(session.text())["doc"]
	var errors: int = 0
	for d: Dictionary in Logic.diagnostics(session.doc, session.path.get_file(), _index()):
		if d["severity"] == "erro":
			errors += 1
	status.emit("Salvo %s%s" % [session.path, "" if errors == 0 else " (com %d erro(s): a importação falha até corrigir)" % errors])
	saved.emit(session.path)
	_update_dirty()
	return true

## Reimporta o `.roteiro` no editor: `update_file` registra um arquivo novo e `reimport_files` roda o importador.
func _reimport(path: String) -> void:
	var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if fs == null:
		return
	fs.update_file(path)
	fs.reimport_files(PackedStringArray([path]))

# --- vista do evento atual -----------------------------------------------------------------

func _container() -> Array[RoteiroBlock]:
	if session == null:
		return []
	if current == Logic.HEADER_EVENT:
		return session.doc.items
	if current >= 0 and current < session.doc.events.size():
		return session.doc.events[current].blocks
	return []

func _show_current() -> void:
	if title_label == null:
		return
	var has_event: bool = session != null and current >= 0 and current < session.doc.events.size()
	var is_header: bool = session != null and current == Logic.HEADER_EVENT
	leading_box.visible = has_event
	add_menu.visible = has_event or is_header
	save_button.disabled = session == null
	text_button.disabled = session == null
	new_event_button.disabled = session == null
	rename_button.disabled = not has_event
	delete_button.disabled = not has_event
	if session == null:
		title_label.text = "Nenhum arquivo aberto."
	elif has_event:
		title_label.text = "%s  >  %s" % [session.path.get_file(), session.doc.events[current].id]
		leading_edit.text = Logic.leading_text(session.doc.events[current])
	elif is_header:
		title_label.text = "%s  >  cabeçalho do arquivo (comentários e @flag antes do primeiro evento)" % session.path.get_file()
	else:
		title_label.text = session.path.get_file()
	_rebuild_cards()
	_refresh_diagnostics()
	_update_dirty()

func _context() -> Dictionary:
	return {
		&"ids": func(kind: StringName) -> Array[String]: return Options.ids(_index(), kind),
		&"display": func(kind: StringName, id: String) -> String: return Options.display(_index(), kind, id),
		&"speakers": func() -> Array[String]: return Options.speakers(_hero_defs, _speaker_defs),
		&"expressions": func(speaker: String) -> Array[String]: return Options.expressions(speaker, _hero_defs, _speaker_defs),
		&"flags": _project_flags,
		&"labels": _current_labels,
	}

func _project_flags() -> Array[String]:
	var docs: Array = []
	for p: Variant in _other_docs:
		if session == null or p != session.path:
			docs.append(_other_docs[p])
	if session != null:
		docs.append(session.doc)
	return Options.flags(docs)

func _current_labels() -> Array[String]:
	if session != null and current >= 0 and current < session.doc.events.size():
		return Options.labels(session.doc.events[current])
	return Options.labels(null)

func _rebuild_cards(scroll_to_index: int = -1) -> void:
	for c: Node in cards_box.get_children():
		cards_box.remove_child(c)
		c.queue_free()
	_cards.clear()
	var blocks: Array[RoteiroBlock] = _container()
	var vis: Array[int] = Logic.visible(blocks)
	empty_label.visible = vis.is_empty()
	if session == null:
		empty_label.text = "Escolha um arquivo à esquerda."
	elif current == NO_EVENT:
		empty_label.text = "Este arquivo ainda não tem eventos. Use Novo evento."
	else:
		empty_label.text = "Sem blocos. Use + Adicionar bloco."
	var ctx: Dictionary = _context()
	for i: int in vis:
		var card: PanelContainer = BlockCard.new()
		card.setup(blocks[i], ctx)
		var index: int = i
		card.edited.connect(_on_edited)
		card.restructure.connect(func() -> void: _rebuild_cards(index))
		card.move_requested.connect(func(dir: int) -> void: _on_move(index, dir))
		card.duplicate_requested.connect(func() -> void: _on_duplicate(index))
		card.delete_requested.connect(func() -> void: _on_delete(index))
		card.touched.connect(func() -> void: _anchor = index)
		cards_box.add_child(card)
		_cards[i] = card
	if scroll_to_index >= 0 and _cards.has(scroll_to_index):
		_scroll_to_card.call_deferred(scroll_to_index)

func _scroll_to_card(i: int) -> void:
	if _cards.has(i) and is_instance_valid(_cards[i]):
		scroll.ensure_control_visible(_cards[i])

# --- edições -----------------------------------------------------------------------------

func _on_edited() -> void:
	_update_dirty()
	_diag_timer.start()

func _on_leading_changed() -> void:
	if session != null and current >= 0 and current < session.doc.events.size():
		Logic.set_leading_text(session.doc.events[current], leading_edit.text)
		_on_edited()

func _on_add_kind(kind: int) -> void:
	if session == null:
		return
	var blocks: Array[RoteiroBlock] = _container()
	var at: int = Logic.insert_after(blocks, _anchor, Logic.new_block(kind))
	_anchor = at
	_after_structure(at)

func _on_move(index: int, dir: int) -> void:
	var to: int = Logic.move_visible(_container(), index, dir)
	if to >= 0:
		_anchor = to
		_after_structure(to)

func _on_duplicate(index: int) -> void:
	if Logic.duplicate_at(_container(), index) != null:
		_anchor = index + 1
		_after_structure(index + 1)

func _on_delete(index: int) -> void:
	Logic.remove_at(_container(), index)
	_anchor = -1
	_after_structure(-1)

func _after_structure(scroll_to_index: int) -> void:
	_rebuild_cards(scroll_to_index)
	_refresh_diagnostics()
	_update_dirty()

func _update_dirty() -> void:
	if dirty_label == null:
		return
	var dirty: bool = is_dirty()
	dirty_label.text = "● não salvo" if dirty else ("salvo" if session != null else "")
	dirty_label.add_theme_color_override("font_color", COLOR_WARNING if dirty else COLOR_MUTED)

# --- diagnósticos ------------------------------------------------------------------------

func _refresh_diagnostics() -> void:
	if diag_tree == null:
		return
	diag_tree.clear()
	var root: TreeItem = diag_tree.create_item()
	if session == null:
		diag_summary.text = ""
		return
	var found: Array[Dictionary] = Logic.diagnostics(session.doc, session.path.get_file(), _index())
	var errors: int = 0
	var warnings: int = 0
	for d: Dictionary in found:
		var item: TreeItem = diag_tree.create_item(root)
		var is_error: bool = d["severity"] == "erro"
		if is_error:
			errors += 1
		else:
			warnings += 1
		item.set_text(0, "%s, linha %d: %s" % [d["severity"], d["line"], d["message"]])
		item.set_custom_color(0, COLOR_ERROR if is_error else COLOR_WARNING)
		item.set_metadata(0, d["loc"])
	diag_summary.text = "%d erro(s), %d aviso(s)" % [errors, warnings] if not found.is_empty() else "Sem erros nem avisos."
	_highlight(-1)

func _on_diag_selected() -> void:
	var item: TreeItem = diag_tree.get_selected()
	if item == null or not item.get_metadata(0) is Dictionary:
		return
	var loc: Dictionary = item.get_metadata(0)
	if loc.is_empty():
		return
	go_to_location(loc)

## Mostra o bloco de `loc` (do `Logic.locate`): troca para o evento dele e o destaca.
func go_to_location(loc: Dictionary) -> void:
	var event: int = int(loc["event"])
	if event != current:
		_set_current(event)
	var zone: StringName = loc["zone"]
	if zone == &"items" or zone == &"blocks":
		_highlight(int(loc["index"]))
		_scroll_to_card(int(loc["index"]))
	else:
		_highlight(-1)

func _highlight(index: int) -> void:
	for i: int in _cards:
		(_cards[i] as PanelContainer).set_highlight(i == index)

# --- diálogos de arquivo e evento ------------------------------------------------------------

func _open_prompt(title: String, info: String, initial: String, action: Callable) -> void:
	_prompt.title = title
	_prompt_info.text = info
	_prompt_edit.text = initial
	_prompt_error.text = ""
	_prompt_action = action
	_prompt.popup_centered()
	_prompt_edit.grab_focus()
	_prompt_edit.select_all()

func _on_prompt_ok() -> void:
	var err: String = str(_prompt_action.call(_prompt_edit.text.strip_edges()))
	if err != "":
		_prompt_error.text = err
		return
	_prompt.hide()

func _on_new_file() -> void:
	var folder: String = session.path.get_base_dir() if session != null else NEW_FILE_FOLDER
	_open_prompt("Novo arquivo de roteiro", "Nome do arquivo (sem extensão); fica em %s." % folder, "novo_roteiro",
			func(file_name: String) -> String: return _create_file(folder, file_name))

func _create_file(folder: String, file_name: String) -> String:
	if file_name == "" or file_name.contains("/") or file_name.contains("\\") or file_name.contains(".") or file_name.contains(" "):
		return "Use só letras, números e _ (sem espaços, pontos ou barras)."
	var path: String = folder.path_join(file_name + ".roteiro")
	if FileAccess.file_exists(path):
		return "Já existe %s." % path
	var doc := RoteiroDoc.new()
	doc.add_event("novo_evento")
	DirAccess.make_dir_recursive_absolute(folder)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "Não foi possível criar %s (erro %d)." % [path, FileAccess.get_open_error()]
	f.store_string(RoteiroDoc.to_text(doc))
	f.close()
	_reimport(path)
	_reload_other_docs()
	open_file(path)
	saved.emit(path)
	status.emit("Criado %s" % path)
	return ""

func _on_new_event() -> void:
	if session == null:
		return
	_open_prompt("Novo evento", "Id do evento (uma palavra, sem espaços).", Logic.unused_event_id(session.doc),
			func(id: String) -> String:
				var e: RoteiroEvent = session.doc.add_event(id)
				if e == null:
					return "Id inválido ou já usado neste arquivo."
				_fill_tree()
				_set_current(session.doc.events.size() - 1)
				return "")

func _on_rename_event() -> void:
	if session == null or current < 0:
		return
	var old: String = session.doc.events[current].id
	_open_prompt("Renomear evento", "Os mapas que usam o evento \"%s\" (campo event_id) NÃO são atualizados: ajuste-os depois." % old,
			old, func(id: String) -> String:
				if id == old:
					return ""
				if not session.doc.rename_event(old, id):
					return "Id inválido ou já usado neste arquivo."
				_fill_tree()
				_show_current()
				return "")

func _on_delete_event() -> void:
	if session == null or current < 0:
		return
	var id: String = session.doc.events[current].id
	_confirm.title = "Apagar evento"
	_confirm.dialog_text = "Apagar o evento \"%s\" e todos os seus blocos? (Só vai para o arquivo ao salvar; os mapas que o usam ficam sem ele.)" % id
	_confirm.ok_button_text = "Apagar"
	_confirm_action = func() -> void:
		session.doc.remove_event(id)
		current = mini(current, session.doc.events.size() - 1)
		if current < 0:
			current = Logic.HEADER_EVENT if not session.doc.items.is_empty() else NO_EVENT
		_fill_tree()
		_show_current()
	_confirm.popup_centered()

func _on_view_text() -> void:
	if session == null:
		return
	_text_view.text = session.text()
	_text_dialog.popup_centered()

## O texto de `path` como ele ficará: o do documento aberto se for o mesmo arquivo, senão o do disco.
func current_text_for(path: String) -> String:
	if session != null and session.path == path:
		return session.text()
	return FileAccess.get_file_as_string(path)

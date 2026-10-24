@tool
extends VBoxContainer

## Paleta de objetos (M17): um dock do editor com um botão por prefab de `world/prefabs/`. Só fica ativa quando a cena
## aberta é um `LocalMap` (todos os prefabs menos a zona) ou um `Overworld` (zona, marcador de spawn, placa, gatilho de
## evento). Clicar instancia o prefab na cena aberta, pelo `EditorUndoRedoManager` (Ctrl+Z desfaz): na posição do último
## clique na vista 2D ou, sem clique, no centro da vista, sempre na grade de 32, com nome único, flags provisórias trocadas
## por flags únicas e o nó novo selecionado. "Ajustar à grade" e "Renomear com id" agem nos nós selecionados.
## A lógica (lista, grade, nomes, flags, posição) é pura e está em `logic/palette.gd`; aqui só se liga ao editor.

const Palette: GDScript = preload("res://addons/vat_editor/logic/palette.gd")

var plugin: EditorPlugin

var _hint: Label
var _grid: GridContainer
var _snap_button: Button
var _rename_button: Button
var _status: Label
var _kind: StringName = Palette.KIND_NONE
var _buttons: Dictionary = {}
## Último clique na vista 2D, em coordenadas locais da raiz da cena (null = ainda não houve).
var _last_click: Variant = null

func _init() -> void:
	name = "Objetos"
	custom_minimum_size = Vector2(190, 0)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)
	add_child(HSeparator.new())
	_snap_button = _tool_button("Ajustar à grade", "Alinha os nós selecionados à grade de 32 px.", snap_selection)
	_rename_button = _tool_button("Renomear com id", "Troca as flags provisórias (ou repetidas) dos nós selecionados por flags únicas do mapa.", rename_selection)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	refresh(null)

func _tool_button(text: String, tip: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(handler)
	add_child(b)
	return b

## Refaz os botões para a cena aberta (`root` nulo = nenhuma). Mapa de outro tipo: tudo desligado.
func refresh(root: Node) -> void:
	var kind: StringName = Palette.kind_of_node(root)
	if kind != _kind or _buttons.is_empty():
		_kind = kind
		_last_click = null
		_rebuild_buttons()
	var enabled: bool = kind != Palette.KIND_NONE
	_hint.text = "" if enabled else "Abra um mapa (LocalMap ou Overworld) para usar a paleta."
	_hint.visible = not enabled
	for b: Button in _buttons.values():
		b.disabled = not enabled
	_snap_button.disabled = not enabled
	_rename_button.disabled = not enabled

func _rebuild_buttons() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	_buttons.clear()
	for p: Dictionary in Palette.prefabs_for(_kind):
		var b := Button.new()
		b.text = String(p["name"])
		b.icon = _icon(p["icons"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = "Adiciona %s no centro da vista (ou no último clique), na grade." % String(p["name"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(add_prefab.bind(p["id"]))
		_grid.add_child(b)
		_buttons[p["id"]] = b

func _icon(names: Array) -> Texture2D:
	var base: Control = EditorInterface.get_base_control()
	for n: String in names:
		if base.has_theme_icon(n, &"EditorIcons"):
			return base.get_theme_icon(n, &"EditorIcons")
	return null

## Os botões atuais (id do prefab -> Button), para os testes e a captura.
func buttons() -> Dictionary:
	return _buttons

func status_text() -> String:
	return _status.text

# --- cena e vista -------------------------------------------------------------------------------------------

func _root() -> Node2D:
	return EditorInterface.get_edited_scene_root() as Node2D

## O clique do usuário na vista 2D (em coordenadas da vista do editor), guardado em coordenadas locais da raiz.
func note_click(viewport_pos: Vector2) -> void:
	var root: Node2D = _root()
	if root == null:
		return
	var vp: Viewport = root.get_viewport()
	if vp == null:
		return
	var world: Vector2 = vp.global_canvas_transform.affine_inverse() * viewport_pos
	_last_click = root.get_global_transform().affine_inverse() * world

## O centro da vista 2D em coordenadas locais da raiz, ou null se não há vista.
func view_center() -> Variant:
	var root: Node2D = _root()
	if root == null:
		return null
	var vp: Viewport = root.get_viewport()
	if vp == null:
		return null
	var size: Vector2 = vp.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return null
	var world: Vector2 = vp.global_canvas_transform.affine_inverse() * (size / 2.0)
	return root.get_global_transform().affine_inverse() * world

func _map_id(root: Node) -> String:
	return Palette.map_id_for(root.scene_file_path, Game.default_registry(), String(root.name))

# --- ações --------------------------------------------------------------------------------------------------

## Instancia o prefab `id` na cena aberta (com undo) e o seleciona. Devolve o nó, ou null se não coube.
func add_prefab(id: StringName) -> Node:
	var root: Node2D = _root()
	if root == null or Palette.prefabs_for(Palette.kind_of_node(root)).filter(func(p: Dictionary) -> bool: return p["id"] == id).is_empty():
		return null
	var scene: PackedScene = load(Palette.prefab_path(id)) as PackedScene
	if scene == null:
		_say("Prefab não encontrado: %s." % id)
		return null
	var node: Node = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	node.name = Palette.unique_name(String(node.name), Palette.collect_names(root))
	var node2d: Node2D = node as Node2D
	if node2d != null:
		node2d.position = Palette.placement(_last_click, view_center())
	var changes: Dictionary = Palette.flag_changes(Palette.flag_props_of(node), _map_id(root), Palette.collect_flags(root))
	for k: Variant in changes:
		node.set(k, changes[k])
	var ur: EditorUndoRedoManager = plugin.get_undo_redo()
	ur.create_action("Adicionar %s" % node.name, UndoRedo.MERGE_DISABLE, root)
	ur.add_do_method(root, &"add_child", node, true)
	ur.add_do_method(node, &"set_owner", root)
	ur.add_do_reference(node)
	ur.add_undo_method(root, &"remove_child", node)
	ur.commit_action()
	var sel: EditorSelection = EditorInterface.get_selection()
	sel.clear()
	sel.add_node(node)
	EditorInterface.edit_node(node)
	_say("%s adicionado." % node.name)
	return node

## Alinha à grade os nós 2D selecionados (com undo).
func snap_selection() -> int:
	var root: Node2D = _root()
	if root == null:
		return 0
	var moves: Array[Dictionary] = []
	for n: Node in EditorInterface.get_selection().get_selected_nodes():
		var n2: Node2D = n as Node2D
		if n2 == null or n2 == root:
			continue
		var target: Vector2 = Palette.snap(n2.position)
		if target != n2.position:
			moves.append({"node": n2, "from": n2.position, "to": target})
	if moves.is_empty():
		_say("Nada a ajustar.")
		return 0
	var ur: EditorUndoRedoManager = plugin.get_undo_redo()
	ur.create_action("Ajustar à grade", UndoRedo.MERGE_DISABLE, root)
	for m: Dictionary in moves:
		ur.add_do_property(m["node"], &"position", m["to"])
		ur.add_undo_property(m["node"], &"position", m["from"])
	ur.commit_action()
	_say("%d nó(s) ajustado(s)." % moves.size())
	return moves.size()

## Troca as flags provisórias (ou repetidas) dos nós selecionados por flags únicas do mapa (com undo).
func rename_selection() -> int:
	var root: Node2D = _root()
	if root == null:
		return 0
	var selected: Array[Node] = []
	selected.assign(EditorInterface.get_selection().get_selected_nodes())
	var taken: Array[String] = Palette.collect_flags(root, selected)
	var map_id: String = _map_id(root)
	var edits: Array[Dictionary] = []
	for n: Node in selected:
		if n == root:
			continue
		var props: Dictionary = Palette.flag_props_of(n)
		var ch: Dictionary = Palette.flag_changes(props, map_id, taken)
		for k: Variant in ch:
			edits.append({"node": n, "prop": k, "from": props[k], "to": ch[k]})
			taken.append(String(ch[k]))
	if edits.is_empty():
		_say("Nenhuma flag provisória ou repetida nos selecionados.")
		return 0
	var ur: EditorUndoRedoManager = plugin.get_undo_redo()
	ur.create_action("Renomear com id", UndoRedo.MERGE_DISABLE, root)
	for e: Dictionary in edits:
		ur.add_do_property(e["node"], e["prop"], e["to"])
		ur.add_undo_property(e["node"], e["prop"], e["from"])
	ur.commit_action()
	_say("%d flag(s) renomeada(s)." % edits.size())
	return edits.size()

func _say(text: String) -> void:
	_status.text = text

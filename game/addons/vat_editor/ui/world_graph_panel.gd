@tool
extends VBoxContainer

## Aba "Mundo" do painel VAT (M17): um `GraphNode` por mapa do registro e uma seta por ligação (`MapLink`, `Zone`, `$Exit`).
## Ligação quebrada sai em vermelho (porta própria de cada nó, de cor vermelha) e entra na lista "Ligações quebradas" ao lado;
## o nó envolvido ganha o aviso. Clique duplo num nó abre a cena; clicar numa seta ou num item da lista abre a cena de origem
## e seleciona o nó dela. As posições dos nós ficam em `addons/vat_editor/mundo_layout.cfg`. UI fina: a conta está em
## `logic/world_graph.gd`.

const WorldGraph: GDScript = preload("res://addons/vat_editor/logic/world_graph.gd")

const COLOR_OK: Color = Color(0.75, 0.8, 0.85)
const COLOR_BROKEN: Color = Color(1.0, 0.25, 0.25)
const COLOR_WARN: Color = Color(1.0, 0.7, 0.3)
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)
## Tipos de porta: 0 = ligação boa, 1 = ligação quebrada (as cores das portas dão a cor da linha).
const PORT_OK: int = 0
const PORT_BROKEN: int = 1
const KIND_COLORS: Array[Color] = [
	Color(0.24, 0.5, 0.3), Color(0.55, 0.42, 0.25), Color(0.5, 0.27, 0.4), Color(0.25, 0.4, 0.62), Color(0.4, 0.4, 0.44),
]
const KIND_ICONS: Array[Array] = [
	["Groups", "Node2D"], ["Window", "Control"], ["TileMap", "Tree"], ["World", "Environment", "Object"], ["Tools", "Node"],
]
const EDGE_PICK_DISTANCE: float = 8.0

signal status(text: String)

var graph_edit: GraphEdit
var summary: Label
var tests_check: CheckBox
var side: Tree
var layout_path: String = WorldGraph.LAYOUT_PATH

var _graph: Dictionary = {}
var _shown: Dictionary = {}
var _groups: Dictionary = {}
var _selected_map: String = ""
var _hover_key: String = ""
var _auto_fit: bool = true

func _init() -> void:
	name = "Mundo"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	var top := HBoxContainer.new()
	add_child(top)
	summary = Label.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(summary)
	tests_check = CheckBox.new()
	tests_check.text = "mostrar mapas de teste"
	tests_check.toggled.connect(func(_on: bool) -> void: refresh())
	top.add_child(tests_check)
	_button(top, "Atualizar", func() -> void: refresh())
	_button(top, "Reorganizar", reorganize)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.custom_minimum_size = Vector2(480, 300)
	graph_edit.minimap_enabled = false
	graph_edit.right_disconnects = false
	graph_edit.show_menu = false
	graph_edit.add_valid_connection_type(PORT_OK, PORT_OK)
	graph_edit.gui_input.connect(_on_graph_input)
	graph_edit.resized.connect(func() -> void: _fit.call_deferred())
	split.add_child(graph_edit)
	side = Tree.new()
	side.custom_minimum_size = Vector2(340, 0)
	side.hide_root = true
	side.select_mode = Tree.SELECT_ROW
	side.item_selected.connect(_on_side_selected)
	split.add_child(side)
	var hint := Label.new()
	hint.text = "Clique duplo num mapa abre a cena. Clicar numa seta ou num item da lista abre a cena de origem e seleciona o nó. Arraste os mapas para arrumar; a posição fica gravada."
	hint.add_theme_color_override("font_color", COLOR_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	refresh()

func _button(parent: Node, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	parent.add_child(b)
	return b

func _registry() -> MapRegistry:
	return Game.default_registry()

## Para a captura de tela e para quem quiser: liga ou desliga os mapas de teste.
func show_tests(on: bool) -> void:
	tests_check.set_pressed_no_signal(on)
	refresh()

# --- desenho ------------------------------------------------------------------------------------------------

## Relê o registro e as cenas e refaz o grafo (as posições gravadas valem; mapas novos entram no layout automático).
func refresh() -> void:
	_graph = WorldGraph.build(_registry())
	_rebuild(WorldGraph.load_layout(layout_path))

## Joga fora as posições gravadas e volta ao layout automático.
func reorganize() -> void:
	if FileAccess.file_exists(layout_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(layout_path))
	_graph = WorldGraph.build(_registry())
	_rebuild({})
	status.emit("Mapas reorganizados no layout automático.")

func _rebuild(saved: Dictionary) -> void:
	_clear()
	_shown = _graph if tests_check.button_pressed else WorldGraph.without_tests(_graph)
	var positions: Dictionary = WorldGraph.merged_layout(_shown, saved)
	var broken_count: Dictionary = {}
	for e: Dictionary in _shown["edges"]:
		if bool(e["broken"]):
			broken_count[e["from"]] = int(broken_count.get(e["from"], 0)) + 1
			broken_count[e["to"]] = int(broken_count.get(e["to"], 0)) + 1
	var incoming: Dictionary = {}
	var outgoing: Dictionary = {}
	for e: Dictionary in _shown["edges"]:
		outgoing[e["from"]] = int(outgoing.get(e["from"], 0)) + 1
		incoming[e["to"]] = int(incoming.get(e["to"], 0)) + 1
	for n: Dictionary in _shown["nodes"]:
		var id: String = n["id"]
		graph_edit.add_child(_make_node(n, positions[id], int(broken_count.get(id, 0)), int(outgoing.get(id, 0)), int(incoming.get(id, 0))))
	_connect_edges()
	_auto_fit = true
	_fit.call_deferred()
	_fill_side()
	var n_edges: int = (_shown["edges"] as Array).size()
	var bad: int = WorldGraph.broken_edges(_shown).size()
	summary.text = "%d mapa(s), %d ligação(ões), %d quebrada(s), %d inalcançável(is)" % [(_shown["nodes"] as Array).size(), n_edges, bad, (_shown["unreachable"] as Array).size()]

## Ajusta o zoom e a rolagem para o grafo todo caber na vista (nunca amplia além de 1). Vale enquanto ninguém mexer na
## vista: o tamanho do GraphEdit ainda muda nos primeiros quadros, então `resized` ajusta de novo.
func _fit() -> void:
	if not _auto_fit:
		return
	var bounds := Rect2()
	var first: bool = true
	for c: Node in graph_edit.get_children():
		var gn := c as GraphNode
		if gn == null:
			continue
		var r := Rect2(gn.position_offset, gn.size)
		bounds = r if first else bounds.merge(r)
		first = false
	if first or graph_edit.size.x < 100.0 or graph_edit.size.y < 100.0:
		return
	var margin: float = 24.0
	var avail: Vector2 = graph_edit.size - Vector2(margin, margin) * 2.0
	graph_edit.zoom = clampf(minf(avail.x / maxf(bounds.size.x, 1.0), avail.y / maxf(bounds.size.y, 1.0)), 0.3, 1.0)
	# O GraphEdit reajusta a rolagem ao mudar o zoom: põe a rolagem no quadro seguinte.
	await get_tree().process_frame
	if _auto_fit:
		graph_edit.scroll_offset = (bounds.position - Vector2(margin, margin) / graph_edit.zoom) * graph_edit.zoom

func _clear() -> void:
	graph_edit.clear_connections()
	for c: Node in graph_edit.get_children():
		if c is GraphNode:
			graph_edit.remove_child(c)
			c.queue_free()
	_groups.clear()
	_hover_key = ""
	graph_edit.tooltip_text = ""

func _make_node(n: Dictionary, pos: Vector2, broken: int, outgoing: int, incoming: int) -> GraphNode:
	var kind: int = clampi(int(n["kind"]), 0, KIND_COLORS.size() - 1)
	var id: String = n["id"]
	var node := GraphNode.new()
	node.name = id
	node.title = ("⚠ " if broken > 0 else "") + String(n["name"])
	node.position_offset = pos
	node.set_meta(&"map_id", id)
	node.tooltip_text = "%s\n%s" % [id, String(n["scene"])]
	for style_name: String in ["titlebar", "titlebar_selected"]:
		var box := StyleBoxFlat.new()
		box.bg_color = KIND_COLORS[kind] if style_name == "titlebar" else KIND_COLORS[kind].lightened(0.25)
		box.set_corner_radius_all(4)
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		node.add_theme_stylebox_override(style_name, box)
	var icon: Texture2D = _icon(kind)
	if icon != null:
		var rect := TextureRect.new()
		rect.texture = icon
		rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		node.get_titlebar_hbox().add_child(rect)
		node.get_titlebar_hbox().move_child(rect, 0)
	var spawns: int = (n["spawns"] as Array).size()
	var counts: Dictionary = n["counts"]
	# Linha 0: o tipo, com as portas das ligações boas. Linha 1: o resto, com as portas das quebradas (vermelhas).
	var kind_row := Label.new()
	kind_row.text = "%s · %d entrada(s)" % [n["kind_label"], spawns]
	node.add_child(kind_row)
	var info := Label.new()
	var info_text: String = "saem %d · chegam %d" % [outgoing, incoming]
	if (_shown["unreachable"] as Array).has(id):
		info_text += "\ninalcançável"
		info.add_theme_color_override("font_color", COLOR_WARN)
	elif broken > 0:
		info_text += "\n%d quebrada(s)" % broken
		info.add_theme_color_override("font_color", COLOR_BROKEN)
	else:
		info.add_theme_color_override("font_color", COLOR_MUTED)
	info.text = info_text
	node.add_child(info)
	node.set_slot(0, true, PORT_OK, COLOR_OK, true, PORT_OK, COLOR_OK)
	node.set_slot(1, broken > 0, PORT_BROKEN, COLOR_BROKEN, broken > 0, PORT_BROKEN, COLOR_BROKEN)
	node.gui_input.connect(_on_node_input.bind(id))
	node.dragged.connect(_on_node_dragged.bind(node))
	node.node_selected.connect(_on_node_selected.bind(id))
	return node

func _icon(kind: int) -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	var base: Control = EditorInterface.get_base_control()
	for icon_name: String in KIND_ICONS[kind]:
		if base.has_theme_icon(icon_name, &"EditorIcons"):
			return base.get_theme_icon(icon_name, &"EditorIcons")
	return null

## Uma conexão por par (origem, destino, boa/quebrada); o que ela leva fica em `_groups`.
func _connect_edges() -> void:
	var present: Dictionary = {}
	for n: Dictionary in _shown["nodes"]:
		present[n["id"]] = true
	for e: Dictionary in _shown["edges"]:
		if not present.has(e["from"]) or not present.has(e["to"]) or e["from"] == e["to"]:
			continue
		var port: int = PORT_BROKEN if bool(e["broken"]) else PORT_OK
		var key: String = _key(e["from"], e["to"], port)
		if not _groups.has(key):
			_groups[key] = []
			graph_edit.connect_node(StringName(e["from"]), port, StringName(e["to"]), port)
		(_groups[key] as Array).append(e)

func _key(from: String, to: String, port: int) -> String:
	return "%s|%s|%d" % [from, to, port]

func _group_key(conn: Dictionary) -> String:
	return _key(String(conn["from_node"]), String(conn["to_node"]), int(conn["from_port"]))

## Os rótulos das ligações de um grupo, um por linha (o texto do tooltip).
func group_text(edges: Array) -> String:
	var lines: Array[String] = []
	for e: Dictionary in edges:
		lines.append("%s%s" % [e["label"], " (QUEBRADA: %s)" % e["message"] if bool(e["broken"]) else ""])
	return "\n".join(lines)

# --- lista lateral ------------------------------------------------------------------------------------------

func _fill_side() -> void:
	side.clear()
	var root: TreeItem = side.create_item()
	var broken: Array[Dictionary] = WorldGraph.broken_edges(_shown)
	var head: TreeItem = side.create_item(root)
	head.set_text(0, "Ligações quebradas (%d)" % broken.size())
	head.set_selectable(0, false)
	head.set_custom_color(0, COLOR_BROKEN if not broken.is_empty() else COLOR_MUTED)
	for e: Dictionary in broken:
		_edge_item(head, e, true)
	var lost: Array = _shown["unreachable"]
	if not lost.is_empty():
		var h2: TreeItem = side.create_item(root)
		h2.set_text(0, "Inalcançáveis (%d)" % lost.size())
		h2.set_selectable(0, false)
		h2.set_custom_color(0, COLOR_WARN)
		for id: String in lost:
			var it: TreeItem = side.create_item(h2)
			it.set_text(0, id)
			it.set_metadata(0, {"map": id})
	if _selected_map != "" and _find_node(_selected_map) != null:
		var h3: TreeItem = side.create_item(root)
		h3.set_text(0, "Ligações de %s" % _selected_map)
		h3.set_selectable(0, false)
		for e: Dictionary in WorldGraph.edges_of(_shown, _selected_map):
			_edge_item(h3, e, false)

func _edge_item(parent: TreeItem, e: Dictionary, with_message: bool) -> void:
	var it: TreeItem = side.create_item(parent)
	var text: String = "%s -> %s (%s)" % [e["from"], e["to"], e["label"]]
	if with_message:
		text += "\n   " + String(e["message"])
	it.set_text(0, text)
	it.set_autowrap_mode(0, TextServer.AUTOWRAP_WORD_SMART)
	it.set_metadata(0, {"edge": e})
	if bool(e["broken"]):
		it.set_custom_color(0, COLOR_BROKEN)
		it.set_tooltip_text(0, String(e["message"]))

func _on_side_selected() -> void:
	var it: TreeItem = side.get_selected()
	if it == null or not (it.get_metadata(0) is Dictionary):
		return
	var meta: Dictionary = it.get_metadata(0)
	if meta.has("edge"):
		open_edge(meta["edge"])
	elif meta.has("map"):
		open_map(String(meta["map"]))

# --- interação ----------------------------------------------------------------------------------------------

func _find_node(id: String) -> GraphNode:
	return graph_edit.get_node_or_null(NodePath(id)) as GraphNode

func _on_node_selected(id: String) -> void:
	_selected_map = id
	_fill_side()

func _on_node_input(event: InputEvent, id: String) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click:
		open_map(id)

func _on_node_dragged(_from: Vector2, to: Vector2, node: GraphNode) -> void:
	var err: Error = WorldGraph.save_layout(layout_path, {String(node.name): to})
	if err != OK:
		status.emit("Não foi possível gravar %s (erro %d)." % [layout_path, err])

func _on_graph_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var key: String = _key_at(motion.position)
		if key != _hover_key:
			_hover_key = key
			graph_edit.tooltip_text = group_text(_groups[key]) if _groups.has(key) else ""
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		_auto_fit = false
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var key: String = _key_at(mb.position)
		if _groups.has(key):
			var edges: Array = _groups[key]
			status.emit(group_text(edges).replace("\n", " | "))
			open_edge(edges[0])

func _key_at(point: Vector2) -> String:
	var conn: Dictionary = graph_edit.get_closest_connection_at_point(point, EDGE_PICK_DISTANCE)
	return _group_key(conn) if not conn.is_empty() else ""

## Abre a cena do mapa no editor.
func open_map(id: String) -> void:
	var path: String = _scene_path(id)
	if path == "":
		status.emit("O mapa '%s' não tem cena." % id)
		return
	EditorInterface.open_scene_from_path(path)
	status.emit("Aberto %s" % path)

## Abre a cena de origem da ligação e seleciona o nó dela (o Inspector mostra o destino e o ponto de entrada).
func open_edge(e: Dictionary) -> void:
	var path: String = _scene_path(String(e["from"]))
	if path == "":
		return
	EditorInterface.open_scene_from_path(path)
	for i: int in 3:
		await get_tree().process_frame
	var root: Node = EditorInterface.get_edited_scene_root()
	var target: Node = root.get_node_or_null(NodePath(String(e["source"]))) if root != null else null
	if target == null:
		status.emit("Aberto %s (o nó '%s' não foi achado)." % [path, e["source"]])
		return
	var sel: EditorSelection = EditorInterface.get_selection()
	sel.clear()
	sel.add_node(target)
	EditorInterface.edit_node(target)
	status.emit("%s: %s" % [path, e["label"]])

func _scene_path(id: String) -> String:
	var def: MapDef = _registry().find(StringName(id))
	return def.scene.resource_path if def != null and def.scene != null else ""

@tool
extends EditorInspectorPlugin

## Escolhas em lista no Inspector (M17). Troca só estas propriedades, o resto do Inspector fica como está:
## - `MapLink.target_map`/`target_spawn` e `Zone.zone_id`/`spawn`: os mapas do registro e os marcadores do mapa de destino;
## - `roteiro` + `event_id` (qualquer nó que tenha os dois): o livro `.roteiro`, os eventos dele e o botão
##   "Abrir no editor de blocos";
## - `MapEnemy.encounter`, `ShopKeeper.shop`, `Npc.speaker`, `ElementalObstacle.element`: os recursos de `res://data`.
## A lógica (quem ganha o quê, as listas, o que é inválido) está em `logic/inspector_picks.gd`; aqui só se desenha.

const Picks: GDScript = preload("res://addons/vat_editor/logic/inspector_picks.gd")
const Palette: GDScript = preload("res://addons/vat_editor/logic/palette.gd")
const ChoiceProperty: GDScript = preload("res://addons/vat_editor/inspector/choice_property.gd")
const DATA_ROOT: String = "res://data"
## Pastas de `res://data` que não têm recursos de conteúdo (o registro de mapas carregaria todas as cenas).
const SKIP_DIRS: Array[String] = ["maps"]

## Callable(path: String, event_id: String) que abre o editor de blocos na aba VAT (quem registra o plugin entrega).
var open_editor: Callable

var _resources: Array[Resource] = []
var _scanned: bool = false

func invalidate() -> void:
	_scanned = false
	_resources = []

func _can_handle(object: Object) -> bool:
	var node: Node = object as Node
	if node == null or node.get_script() == null:
		return false
	var chain: Array[String] = Palette.script_chain(node.get_script() as Script)
	for cls: String in chain:
		if Picks.MAP_PROPS.has(cls) or Picks.RESOURCE_PROPS.has(cls):
			return true
	return _has_pair(node)

func _has_pair(object: Object) -> bool:
	var names: Array[String] = []
	for p: Dictionary in object.get_property_list():
		names.append(String(p["name"]))
	return Picks.has_roteiro_pair(names)

func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint, _hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	var script: Script = object.get_script() as Script
	if script == null:
		return false
	var chain: Array[String] = Palette.script_chain(script)
	var pair: bool = _has_pair(object)
	var pick: Dictionary = Picks.pick_for(chain, StringName(name), pair)
	if pick.is_empty():
		return false
	var prop := ChoiceProperty.new() as EditorProperty
	match StringName(pick["kind"]):
		Picks.PICK_MAP:
			_setup_map(prop)
		Picks.PICK_SPAWN:
			_setup_spawn(prop, name)
		Picks.PICK_BOOK:
			_setup_book(prop)
		Picks.PICK_EVENT:
			_setup_event(prop)
		Picks.PICK_RESOURCE:
			_setup_resource(prop, str(pick["resource_class"]))
		_:
			prop.free()
			return false
	add_property_editor(name, prop, false, name.capitalize())
	if StringName(pick["kind"]) == Picks.PICK_EVENT:
		add_custom_control(_open_button(object))
	return true

# --- mapas e marcadores ------------------------------------------------------------------------------------

func _registry() -> MapRegistry:
	return Game.default_registry()

func _setup_map(prop: EditorProperty) -> void:
	prop.set(&"lister", func(_o: Object) -> Array[String]: return Picks.map_ids(_registry()))
	prop.set(&"reader", func(o: Object) -> String: return String(o.get(prop.get_edited_property())))
	prop.set(&"writer", func(k: String) -> Variant: return StringName(k))
	prop.set(&"problem", func(_o: Object, k: String) -> String: return Picks.map_problem(_registry(), k))

func _setup_spawn(prop: EditorProperty, name: String) -> void:
	var map_prop: String = String(Picks.SPAWN_MAP_PROP[name])
	prop.set(&"lister", func(o: Object) -> Array[String]: return Picks.spawns_for_map(_registry(), StringName(o.get(map_prop))))
	prop.set(&"reader", func(o: Object) -> String: return String(o.get(prop.get_edited_property())))
	prop.set(&"writer", func(k: String) -> Variant: return StringName(k))
	prop.set(&"problem", func(o: Object, k: String) -> String: return Picks.spawn_problem(_registry(), String(o.get(map_prop)), k))

# --- livro e evento ------------------------------------------------------------------------------------------

func _setup_book(prop: EditorProperty) -> void:
	prop.set(&"lister", func(_o: Object) -> Array[String]: return Picks.book_paths(RoteiroTools.find_roteiros("res://")))
	prop.set(&"reader", func(o: Object) -> String:
		var book: RoteiroBook = o.get(&"roteiro") as RoteiroBook
		return "" if book == null else book.resource_path)
	prop.set(&"labeler", func(k: String) -> String: return k.get_file())
	prop.set(&"writer", func(k: String) -> Variant: return Picks.resource_for_key(k))
	prop.set(&"problem", func(_o: Object, k: String) -> String: return "" if k == "" or ResourceLoader.exists(k) else "o arquivo não existe")

func _setup_event(prop: EditorProperty) -> void:
	prop.set(&"lister", func(o: Object) -> Array[String]: return Picks.event_ids(o.get(&"roteiro") as RoteiroBook))
	prop.set(&"reader", func(o: Object) -> String: return String(o.get(&"event_id")))
	prop.set(&"writer", func(k: String) -> Variant: return StringName(k))
	prop.set(&"problem", func(o: Object, k: String) -> String: return Picks.event_problem(o.get(&"roteiro") as RoteiroBook, k))

func _open_button(object: Object) -> Control:
	var button := Button.new()
	button.text = "Abrir no editor de blocos"
	button.tooltip_text = "Abre este evento na aba VAT, em Roteiros > Editor."
	button.pressed.connect(func() -> void: _open(object))
	return button

func _open(object: Object) -> void:
	var book: RoteiroBook = object.get(&"roteiro") as RoteiroBook
	if book == null or book.resource_path == "":
		push_warning("VAT: escolha um roteiro antes de abrir o editor de blocos.")
		return
	if open_editor.is_valid():
		open_editor.call(book.resource_path, String(object.get(&"event_id")))

# --- recursos de conteúdo ------------------------------------------------------------------------------------

func _setup_resource(prop: EditorProperty, resource_class: String) -> void:
	var by_path: Dictionary = {}
	prop.set(&"lister", func(_o: Object) -> Array[String]:
		var keys: Array[String] = []
		by_path.clear()
		for opt: Dictionary in Picks.resource_options(_all_resources(), resource_class):
			var res: Resource = opt["resource"]
			keys.append(res.resource_path)
			by_path[res.resource_path] = String(opt["label"])
		return keys)
	prop.set(&"reader", func(o: Object) -> String:
		var res: Resource = o.get(prop.get_edited_property()) as Resource
		if res == null:
			return ""
		return res.resource_path if res.resource_path != "" else "(embutido)")
	prop.set(&"labeler", func(k: String) -> String: return String(by_path.get(k, k.get_file())))
	prop.set(&"writer", func(k: String) -> Variant: return Picks.resource_for_key(k))

func _all_resources() -> Array[Resource]:
	if not _scanned:
		_resources = []
		_scan(DATA_ROOT)
		_scanned = true
	return _resources

func _scan(dir: String) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for f: String in files:
		if f.get_extension() == "tres":
			var res: Resource = load(dir.path_join(f))
			if res != null:
				_resources.append(res)
	var dirs: PackedStringArray = DirAccess.get_directories_at(dir)
	dirs.sort()
	for d: String in dirs:
		if not SKIP_DIRS.has(d):
			_scan(dir.path_join(d))

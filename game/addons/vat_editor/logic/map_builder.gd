@tool
extends RefCounted

## Monta o mapa do plano do assistente (M17) sem depender do editor: instancia o modelo, pinta o chão e a borda, posiciona
## os marcadores, a arena, o jogador e a câmera e empacota a cena. `write` grava a cena e o `MapDef` e registra no
## `MapRegistry`. O editor só chama estas funções (ver `ui/map_wizard_dialog.gd`); os testes as chamam com pastas temporárias.

const Wizard: GDScript = preload("res://addons/vat_editor/logic/map_wizard.gd")

## A cena do mapa novo (null se o modelo não carrega). Não grava nada.
static func build(plan: Dictionary) -> PackedScene:
	var template: PackedScene = load(str(plan["template"])) as PackedScene
	if template == null:
		return null
	var root: Node2D = template.instantiate() as Node2D
	root.name = StringName(str(plan["root_name"]))
	_paint(root.get_node(^"Chão") as TileMapLayer, plan["floor"])
	_paint(root.get_node(^"Paredes") as TileMapLayer, plan["walls"])
	var start: Vector2 = plan["start"]
	(root.get_node(^"Start") as Node2D).position = start
	(root.get_node(^"Entry") as Node2D).position = plan["entry"]
	(root.get_node(^"Player") as Node2D).position = start
	var cam: Camera2D = root.get_node(^"MapCamera") as Camera2D
	cam.position = start
	var bounds: Rect2 = plan["bounds"]
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)
	var arena: Node2D = root.get_node_or_null(^"Arena") as Node2D
	if arena != null:
		arena.position = plan["arena_pos"]
	root.set(&"map_bounds", bounds)
	# O mapa novo não é herdeiro do modelo: a cena guarda os próprios nós.
	root.scene_file_path = ""
	var packed := PackedScene.new()
	var err: Error = packed.pack(root)
	root.free()
	return packed if err == OK else null

static func _paint(layer: TileMapLayer, cells: Dictionary) -> void:
	for c: Vector2i in cells:
		layer.set_cell(c, Wizard.TILE_SOURCE, cells[c])

## Registra o mapa em memória: um `MapDef` novo no fim de `registry.maps`.
static func register(registry: MapRegistry, plan: Dictionary, scene: PackedScene) -> MapDef:
	var def := MapDef.new()
	def.id = StringName(str(plan["id"]))
	def.display_name = str(plan["name"])
	def.scene = scene
	def.kind = int(plan["kind"]) as MapDef.Kind
	registry.maps.append(def)
	return def

## Grava a cena (`plan.scene_path`) e o `MapDef` (`plan.def_path`) e o registro em `registry_path`. Devolve "" ou a mensagem de erro.
static func write(plan: Dictionary, scene: PackedScene, registry: MapRegistry, registry_path: String) -> String:
	var scene_path: String = str(plan["scene_path"])
	var def_path: String = str(plan["def_path"])
	# Nada pré-existente é sobrescrito (e, por isso, também nada pré-existente é apagado ao desfazer).
	for p: String in [scene_path, def_path]:
		if FileAccess.file_exists(p):
			return "Já existe um arquivo em %s." % p
	DirAccess.make_dir_recursive_absolute(scene_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(def_path.get_base_dir())
	var err: Error = ResourceSaver.save(scene, scene_path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		return "Não foi possível salvar %s (erro %d)." % [scene_path, err]
	var def := MapDef.new()
	def.id = StringName(str(plan["id"]))
	def.display_name = str(plan["name"])
	def.scene = scene
	def.kind = int(plan["kind"]) as MapDef.Kind
	err = ResourceSaver.save(def, def_path, ResourceSaver.FLAG_CHANGE_PATH)
	if err != OK:
		_discard([scene_path, def_path])
		return "Não foi possível salvar %s (erro %d)." % [def_path, err]
	registry.maps.append(def)
	err = ResourceSaver.save(registry, registry_path)
	if err != OK:
		registry.maps.erase(def)
		_discard([scene_path, def_path])
		return "Não foi possível salvar o registro %s (erro %d)." % [registry_path, err]
	return ""

## Apaga os arquivos que `write` acabou de criar, para uma gravação que falhou não deixar mapa solto no disco.
static func _discard(paths: Array[String]) -> void:
	for p: String in paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

## Tira o mapa `id` do registro e grava `registry_path`; a cena e o `MapDef` ficam no disco. Devolve "" ou a mensagem de erro.
static func unregister(registry: MapRegistry, id: StringName, registry_path: String) -> String:
	var def: MapDef = registry.find(id)
	if def == null:
		return "O mapa '%s' não está no registro." % id
	registry.maps.erase(def)
	var err: Error = ResourceSaver.save(registry, registry_path)
	if err != OK:
		registry.maps.append(def)
		return "Não foi possível salvar o registro %s (erro %d)." % [registry_path, err]
	return ""

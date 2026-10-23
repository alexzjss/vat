extends GutTest

## Mapas da fatia em TileMapLayer (M16): o tileset placeholder, a colisão equivalente à dos retângulos antigos
## (amostras salvas em golden/map_walls.json), spawns e nós de jogo livres e todos os destinos alcançáveis.

const MAPS: Array[String] = [
	"res://world/fatia/cidade.tscn",
	"res://world/fatia/casa_1.tscn",
	"res://world/fatia/casa_2.tscn",
	"res://world/fatia/overworld_fatia.tscn",
	"res://world/fatia/estrada.tscn",
	"res://world/fatia/dungeon_1.tscn",
	"res://world/fatia/dungeon_2.tscn",
]
const TILESET: String = "res://art/tiles/placeholder_32.tres"
const GOLDEN: String = "res://tests/golden/map_walls.json"
## Tiles da folha que colidem (coluna, linha): parede, água, parede interna e as variantes sólidas.
const SOLID_TILES: Array[Vector2i] = [Vector2i(3, 0), Vector2i(4, 0), Vector2i(6, 0), Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]

var _golden: Dictionary = {}

func before_all() -> void:
	var f: FileAccess = FileAccess.open(GOLDEN, FileAccess.READ)
	_golden = JSON.parse_string(f.get_as_text()) as Dictionary

func _load_map(path: String) -> Node2D:
	var root: Node2D = (load(path) as PackedScene).instantiate() as Node2D
	add_child_autofree(root)
	return root

## Posição no mapa (a raiz fica na origem; soma as posições até a raiz).
func _pos(n: Node2D, root: Node) -> Vector2:
	var p: Vector2 = Vector2.ZERO
	var cur: Node = n
	while cur != null and cur != root:
		var c2: Node2D = cur as Node2D
		if c2 != null:
			p += c2.position
		cur = cur.get_parent()
	return p

func _spawn_of(root: Node2D) -> Vector2:
	var m: Node2D = root.get_node_or_null(^"Start") as Node2D
	if m == null:
		m = root.get_node(^"Entry") as Node2D
	return m.position

func _bounds_of(root: Node2D) -> Rect2:
	return Overworld.MAP_RECT if root is Overworld else LocalMap.MAP_RECT

## Retângulo (pixels) da forma retangular de um Area2D; um ponto de 0x0 se não há forma retangular.
func _area_rect(a: Area2D, root: Node) -> Rect2:
	for c: Node in a.get_children():
		var cs: CollisionShape2D = c as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			var size: Vector2 = (cs.shape as RectangleShape2D).size
			var center: Vector2 = _pos(a, root) + cs.position
			return Rect2(center - size / 2.0, size)
	return Rect2(_pos(a, root), Vector2.ZERO)

# --- tileset ---------------------------------------------------------------------------------

func test_tileset_physics_matches_old_walls() -> void:
	var ts: TileSet = load(TILESET) as TileSet
	assert_not_null(ts)
	assert_eq(ts.tile_size, Vector2i(32, 32))
	assert_eq(ts.get_physics_layers_count(), 1)
	# Igual aos StaticBody2D antigos: camada 1, máscara 0 (jogador e inimigos de mapa usam máscara 1).
	assert_eq(ts.get_physics_layer_collision_layer(0), 1)
	assert_eq(ts.get_physics_layer_collision_mask(0), 0)
	var src: TileSetAtlasSource = ts.get_source(0) as TileSetAtlasSource
	assert_eq(src.get_tiles_count(), 20)
	for i: int in src.get_tiles_count():
		var coords: Vector2i = src.get_tile_id(i)
		var data: TileData = src.get_tile_data(coords, 0)
		var solid: bool = data.get_collision_polygons_count(0) > 0
		assert_eq(solid, SOLID_TILES.has(coords), "colisão do tile %s" % coords)

func test_tileset_texture_is_32px_grid() -> void:
	var ts: TileSet = load(TILESET) as TileSet
	var src: TileSetAtlasSource = ts.get_source(0) as TileSetAtlasSource
	assert_eq(src.texture.get_size(), Vector2(320, 64))
	assert_eq(src.texture_region_size, Vector2i(32, 32))

# --- estrutura dos mapas -----------------------------------------------------------------------

func test_maps_have_layers_and_no_old_geometry() -> void:
	for path: String in MAPS:
		var root: Node2D = _load_map(path)
		for layer_name: String in ["Chão", "Paredes", "Decoração"]:
			var layer: TileMapLayer = root.get_node_or_null(NodePath(layer_name)) as TileMapLayer
			assert_not_null(layer, "%s: camada %s" % [path, layer_name])
			if layer != null:
				assert_eq(layer.tile_set.resource_path, TILESET, "%s: tileset de %s" % [path, layer_name])
				assert_eq(layer.position, Vector2.ZERO)
		assert_eq((root.get_node(^"Decoração") as TileMapLayer).get_used_cells().size(), 0, "%s: Decoração vazia" % path)
		assert_gt((root.get_node(^"Chão") as TileMapLayer).get_used_cells().size(), 0)
		assert_gt((root.get_node(^"Paredes") as TileMapLayer).get_used_cells().size(), 0)
		for child: Node in root.get_children():
			assert_false(child is ColorRect, "%s: ColorRect %s sobrou" % [path, child.name])
			if child is StaticBody2D:
				assert_not_null(child.get_script(), "%s: StaticBody2D %s sem script (parede antiga?)" % [path, child.name])

# --- (a) spawns e nós de jogo livres ---------------------------------------------------------------

func test_markers_and_spawns_have_free_surroundings() -> void:
	for path: String in MAPS:
		var root: Node2D = _load_map(path)
		var grid: TileGrid = TileGrid.from_map(root)
		for child: Node in root.get_children():
			var m: Marker2D = child as Marker2D
			if m != null:
				# A célula do marcador é livre e a caixa do jogador (28 px + 4 px de folga) não toca parede. A vizinhança de
				# 3x3 células é pedida só quando há folga: um marcador pode ficar colado à parede (RestSpawn da dungeon 2).
				assert_false(grid.is_solid_at(m.position), "%s: marcador %s dentro de parede" % [path, m.name])
				assert_true(grid.box_free(m.position, Vector2(36, 36)), "%s: marcador %s %s encosta em parede" % [path, m.name, m.position])
		var player: Node2D = root.get_node(^"Player") as Node2D
		assert_true(grid.area_free(player.position, 1), "%s: jogador %s" % [path, player.position])

func test_gameplay_nodes_are_not_inside_walls() -> void:
	for path: String in MAPS:
		var root: Node2D = _load_map(path)
		var grid: TileGrid = TileGrid.from_map(root)
		var has_enemies: bool = false
		for child: Node in root.get_children():
			if child is Area2D:
				assert_false(grid.is_solid_at((child as Area2D).position), "%s: %s dentro de parede" % [path, child.name])
			var e: MapEnemy = child as MapEnemy
			if e == null:
				continue
			has_enemies = true
			assert_true(grid.area_free(e.position, 0), "%s: inimigo %s dentro de parede" % [path, e.name])
			# Rota de patrulha: os pontos e os trechos entre eles; região de vagar: todas as células.
			for i: int in e.patrol_points.size():
				var a: Vector2 = e.patrol_points[i]
				assert_true(grid.area_free(a, 0), "%s: %s ponto %s" % [path, e.name, a])
				if i > 0:
					var b: Vector2 = e.patrol_points[i - 1]
					var steps: int = int(a.distance_to(b) / 8.0) + 1
					for s: int in steps + 1:
						var p: Vector2 = b.lerp(a, float(s) / float(steps))
						assert_false(grid.is_solid_at(p), "%s: %s rota atravessa parede em %s" % [path, e.name, p])
			if e.region.size != Vector2.ZERO:
				var c0: Vector2i = TileGrid.cell_of(e.region.position)
				var c1: Vector2i = TileGrid.cell_of(e.region.end - Vector2(0.01, 0.01))
				for cy: int in range(c0.y, c1.y + 1):
					for cx: int in range(c0.x, c1.x + 1):
						assert_false(grid.is_solid_cell(Vector2i(cx, cy)), "%s: região de %s cobre parede em %s" % [path, e.name, Vector2i(cx, cy)])
		if has_enemies:
			# Depois da vitória o jogador volta para o primeiro HeroSpot da arena.
			var spot: Node2D = root.get_node(^"Arena/HeroSpot1") as Node2D
			assert_true(grid.area_free(_pos(spot, root), 0), "%s: HeroSpot1 em parede" % path)

# --- (b) as paredes antigas continuam bloqueadas -----------------------------------------------------

func test_old_wall_samples_are_blocked() -> void:
	for path: String in MAPS:
		assert_true(_golden.has(path), "golden sem %s" % path)
		var root: Node2D = _load_map(path)
		var grid: TileGrid = TileGrid.from_map(root)
		var walls: Array = (_golden[path] as Dictionary)["walls"] as Array
		assert_gt(walls.size(), 0)
		var checked: int = 0
		for w: Variant in walls:
			var wall: Dictionary = w as Dictionary
			for s: Variant in wall["samples"] as Array:
				var pt: Vector2 = Vector2(float((s as Array)[0]), float((s as Array)[1]))
				assert_true(grid.is_solid_at(pt), "%s: %s amostra %s não bloqueia" % [path, wall["name"], pt])
				checked += 1
		assert_gt(checked, 0)

# --- (c) todos os destinos alcançáveis ------------------------------------------------------------------

func test_every_link_door_and_interactable_is_reachable_from_spawn() -> void:
	for path: String in MAPS:
		var root: Node2D = _load_map(path)
		var grid: TileGrid = TileGrid.from_map(root)
		var b: Rect2 = _bounds_of(root)
		var cells: Rect2i = Rect2i(-3, -3, int(ceil(b.size.x / 32.0)) + 6, int(ceil(b.size.y / 32.0)) + 6)
		var reached: Dictionary[Vector2i, bool] = grid.flood(TileGrid.cell_of(_spawn_of(root)), cells)
		assert_gt(reached.size(), 100, "%s: spawn principal preso" % path)
		var links: int = 0
		for child: Node in root.get_children():
			# Portões fechados (FlagGate) e obstáculos não contam como parede: a checagem só olha os tiles.
			var m: Marker2D = child as Marker2D
			if m != null:
				assert_true(reached.has(TileGrid.cell_of(m.position)), "%s: marcador %s inalcançável" % [path, m.name])
			var a: Area2D = child as Area2D
			if a == null:
				continue
			var rect: Rect2 = _area_rect(a, root)
			var ok: bool = TileGrid.touches(reached, rect) if rect.size != Vector2.ZERO \
					else TileGrid.touches(reached, Rect2(rect.position - Vector2(48, 48), Vector2(96, 96)))
			assert_true(ok, "%s: %s (%s) inalcançável" % [path, a.name, rect])
			if a is MapLink or a is Zone or a is Door:
				links += 1
		assert_gt(links, 0, "%s: sem links/portas?" % path)

# --- (d) limites do mapa ------------------------------------------------------------------------------------

func test_map_bounds_unchanged() -> void:
	for path: String in MAPS:
		var root: Node2D = _load_map(path)
		var gb: Array = (_golden[path] as Dictionary)["bounds"] as Array
		var golden_rect: Rect2 = Rect2(float(gb[0]), float(gb[1]), float(gb[2]), float(gb[3]))
		assert_eq(_bounds_of(root), golden_rect, "%s: limites do mapa" % path)
		var grid: TileGrid = TileGrid.from_map(root)
		# O chão cobre o mapa inteiro (e nada fora dele, exceto a linha de parede de baixo em mapas de 720 px).
		var cells_w: int = int(ceil(golden_rect.size.x / 32.0))
		var cells_h: int = int(ceil(golden_rect.size.y / 32.0))
		var floor_layer: TileMapLayer = root.get_node(^"Chão") as TileMapLayer
		var fr: Rect2i = floor_layer.get_used_rect()
		assert_eq(fr, Rect2i(0, 0, cells_w, cells_h), "%s: área do chão" % path)
		assert_true(Rect2i(0, 0, cells_w, cells_h).encloses(grid.used_rect), "%s: tiles fora dos limites" % path)

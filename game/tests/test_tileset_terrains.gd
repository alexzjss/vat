extends GutTest

## Terrain set do tileset placeholder (M18): 1 terrain set "combinar lados" com 6 terrenos, um tile base cada, e a
## folha/colisão/ids intactos (a tabela do art/tiles/README.md). Pintar pelo pincel de terreno, sem a arte final, dá o
## mesmo padrão sólido/livre da pintura manual.

const TILESET: String = "res://art/tiles/placeholder_32.tres"
const SIDES: Array[int] = [
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_SIDE,
]

## A tabela do README: coordenada -> colide.
const SHEET: Dictionary[Vector2i, bool] = {
	Vector2i(0, 0): false, Vector2i(1, 0): false, Vector2i(2, 0): false, Vector2i(3, 0): true, Vector2i(4, 0): true,
	Vector2i(5, 0): false, Vector2i(6, 0): true, Vector2i(7, 0): false, Vector2i(8, 0): false, Vector2i(9, 0): false,
	Vector2i(0, 1): true, Vector2i(1, 1): true, Vector2i(2, 1): true, Vector2i(3, 1): true, Vector2i(4, 1): true,
	Vector2i(5, 1): true, Vector2i(6, 1): false, Vector2i(7, 1): false, Vector2i(8, 1): false, Vector2i(9, 1): false,
}
## Terreno -> [nome, tile base, colide].
const TERRAINS: Array = [
	["Grama", Vector2i(2, 0), false], ["Caminho", Vector2i(1, 0), false], ["Parede", Vector2i(3, 0), true],
	["Água", Vector2i(4, 0), true], ["Piso interno", Vector2i(5, 0), false], ["Parede interna", Vector2i(6, 0), true],
]

var _ts: TileSet

func before_each() -> void:
	_ts = load(TILESET) as TileSet

func _atlas() -> TileSetAtlasSource:
	return _ts.get_source(0) as TileSetAtlasSource

func test_sheet_collision_and_ids_unchanged() -> void:
	var atlas: TileSetAtlasSource = _atlas()
	assert_eq(_ts.tile_size, Vector2i(32, 32))
	assert_eq(atlas.texture_region_size, Vector2i(32, 32))
	assert_eq(atlas.texture.get_size(), Vector2(320, 64))
	assert_eq(_ts.get_source_count(), 1)
	assert_eq(atlas.get_tiles_count(), SHEET.size())
	assert_eq(_ts.get_physics_layers_count(), 1)
	assert_eq(_ts.get_physics_layer_collision_layer(0), 1)
	assert_eq(_ts.get_physics_layer_collision_mask(0), 0)
	for c: Vector2i in SHEET:
		assert_true(atlas.has_tile(c), "tile %s existe" % c)
		var data: TileData = atlas.get_tile_data(c, 0)
		var solid: bool = data.get_collision_polygons_count(0) > 0
		assert_eq(solid, SHEET[c], "colisão de %s" % c)
		if solid:
			assert_eq(data.get_collision_polygons_count(0), 1)
			assert_eq(data.get_collision_polygon_points(0, 0), PackedVector2Array([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)]))

func test_one_match_sides_terrain_set_with_six_terrains() -> void:
	assert_eq(_ts.get_terrain_sets_count(), 1)
	assert_eq(_ts.get_terrain_set_mode(0), TileSet.TERRAIN_MODE_MATCH_SIDES)
	assert_eq(_ts.get_terrains_count(0), TERRAINS.size())
	for i: int in TERRAINS.size():
		assert_eq(_ts.get_terrain_name(0, i), TERRAINS[i][0])
		assert_ne(_ts.get_terrain_color(0, i), Color(), "cor do terreno %d" % i)
		for j: int in range(i + 1, TERRAINS.size()):
			assert_ne(_ts.get_terrain_color(0, i), _ts.get_terrain_color(0, j), "cores distintas")

func test_each_terrain_has_exactly_one_base_tile_with_consistent_bits() -> void:
	var atlas: TileSetAtlasSource = _atlas()
	var count: Dictionary[int, int] = {}
	for c: Vector2i in SHEET:
		var data: TileData = atlas.get_tile_data(c, 0)
		var terrain: int = data.terrain
		if terrain == -1:
			assert_eq(data.terrain_set, -1, "%s sem terreno não deve ter terrain set" % c)
			continue
		count[terrain] = count.get(terrain, 0) + 1
		assert_eq(data.terrain_set, 0)
		assert_eq(c, TERRAINS[terrain][1], "o tile base do terreno %d" % terrain)
		assert_eq(SHEET[c], TERRAINS[terrain][2], "colisão do terreno %d" % terrain)
		for side: int in SIDES:
			assert_eq(data.get_terrain_peering_bit(side), terrain, "bit %d de %s" % [side, c])
	for i: int in TERRAINS.size():
		assert_eq(count.get(i, 0), 1, "um tile base para o terreno %d" % i)
	assert_eq(count.size(), TERRAINS.size())

func test_dungeon_floors_and_decor_are_outside_every_terrain() -> void:
	var atlas: TileSetAtlasSource = _atlas()
	for c: Vector2i in [Vector2i(0, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(0, 1), Vector2i(1, 1),
			Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1)]:
		assert_eq(atlas.get_tile_data(c, 0).terrain, -1, "%s" % c)

# --- pincel de terreno x pintura manual ---------------------------------------------------------

const W: int = 24
const H: int = 14

func _layer() -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = _ts
	add_child_autofree(l)
	return l

func _atlas_cells(layer: TileMapLayer) -> Dictionary[Vector2i, Vector2i]:
	var out: Dictionary[Vector2i, Vector2i] = {}
	for c: Vector2i in layer.get_used_cells():
		out[c] = layer.get_cell_atlas_coords(c)
	return out

func _solid_of(layer: TileMapLayer) -> Dictionary:
	var grid := TileGrid.new()
	grid.add_layer(layer)
	var out: Dictionary = {}
	for y: int in H:
		for x: int in W:
			if grid.is_solid_cell(Vector2i(x, y)):
				out[Vector2i(x, y)] = true
	return out

func test_terrain_brush_matches_manual_painting_for_floor_path_and_wall_ring() -> void:
	var grass: Array[Vector2i] = []
	var path: Array[Vector2i] = []
	var ring: Array[Vector2i] = []
	for y: int in H:
		for x: int in W:
			var c := Vector2i(x, y)
			if x == 0 or y == 0 or x == W - 1 or y == H - 1:
				ring.append(c)
			elif y == 6:
				path.append(c)
			else:
				grass.append(c)
	# À mão: o tile base de cada terreno.
	var hand_floor: TileMapLayer = _layer()
	var hand_walls: TileMapLayer = _layer()
	for c: Vector2i in grass:
		hand_floor.set_cell(c, 0, Vector2i(2, 0))
	for c: Vector2i in path:
		hand_floor.set_cell(c, 0, Vector2i(1, 0))
	for c: Vector2i in ring:
		hand_walls.set_cell(c, 0, Vector2i(3, 0))
	# Pelo pincel: a grama, depois o caminho (um terreno por vez), e a borda como parede.
	var brush_floor: TileMapLayer = _layer()
	var brush_walls: TileMapLayer = _layer()
	brush_floor.set_cells_terrain_connect(grass, 0, 0, false)
	brush_floor.set_cells_terrain_connect(path, 0, 1, false)
	brush_walls.set_cells_terrain_connect(ring, 0, 2, false)
	assert_eq(_atlas_cells(brush_floor), _atlas_cells(hand_floor), "só os tiles base, nas mesmas células")
	assert_eq(_atlas_cells(brush_walls), _atlas_cells(hand_walls))
	assert_eq(_solid_of(brush_walls), _solid_of(hand_walls), "paredes sólidas iguais")
	assert_eq(_solid_of(brush_floor), _solid_of(hand_floor), "chão livre igual")
	assert_eq(_solid_of(brush_walls).size(), 2 * W + 2 * (H - 2))
	assert_eq(_solid_of(brush_floor).size(), 0)

func test_every_terrain_brush_paints_its_base_tile_alone_and_in_a_patch() -> void:
	for i: int in TERRAINS.size():
		var l: TileMapLayer = _layer()
		l.set_cells_terrain_connect([Vector2i(3, 3)] as Array[Vector2i], 0, i, false)
		assert_eq(l.get_cell_atlas_coords(Vector2i(3, 3)), TERRAINS[i][1], "terreno %d" % i)
		var big: TileMapLayer = _layer()
		var cells: Array[Vector2i] = []
		for y: int in 5:
			for x: int in 7:
				cells.append(Vector2i(x, y))
		big.set_cells_terrain_connect(cells, 0, i, false)
		for c: Vector2i in cells:
			assert_eq(big.get_cell_atlas_coords(c), TERRAINS[i][1], "terreno %d em %s" % [i, c])

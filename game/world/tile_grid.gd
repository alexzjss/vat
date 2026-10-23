class_name TileGrid
extends RefCounted

## Grade de colisão dos TileMapLayers de um mapa (M16). Uma célula é sólida se o tile pintado tem polígono de
## colisão na camada de física 0 do TileSet. Pura (só lê o nó do mapa, sem árvore): serve aos testes e às
## ferramentas que conferem se spawns, portas e caminhos continuam livres depois de pintar o mapa.

const TILE: int = 32
const PHYSICS_LAYER: int = 0

var _solid: Dictionary[Vector2i, bool] = {}
## Retângulo (em células) coberto por tiles de qualquer camada.
var used_rect: Rect2i = Rect2i()

## Lê todos os TileMapLayer filhos diretos de `root`. As camadas devem estar na origem do mapa.
static func from_map(root: Node) -> TileGrid:
	var grid := TileGrid.new()
	for child: Node in root.get_children():
		var layer: TileMapLayer = child as TileMapLayer
		if layer != null:
			grid.add_layer(layer)
	return grid

func add_layer(layer: TileMapLayer) -> void:
	var ts: TileSet = layer.tile_set
	for cell: Vector2i in layer.get_used_cells():
		used_rect = Rect2i(cell, Vector2i.ONE) if used_rect.size == Vector2i.ZERO else used_rect.expand(cell).expand(cell + Vector2i.ONE)
		if ts == null or ts.get_physics_layers_count() <= PHYSICS_LAYER:
			continue
		var data: TileData = layer.get_cell_tile_data(cell)
		if data != null and data.get_collision_polygons_count(PHYSICS_LAYER) > 0:
			_solid[cell] = true

static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))

func is_solid_cell(c: Vector2i) -> bool:
	return _solid.has(c)

func is_solid_at(p: Vector2) -> bool:
	return _solid.has(cell_of(p))

## Todas as células a até `radius` células (Chebyshev) de `p` estão livres?
func area_free(p: Vector2, radius: int = 1) -> bool:
	var c: Vector2i = cell_of(p)
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if is_solid_cell(c + Vector2i(dx, dy)):
				return false
	return true

## O retângulo de tamanho `size` centrado em `p` não toca nenhuma célula sólida?
func box_free(p: Vector2, size: Vector2) -> bool:
	var c0: Vector2i = cell_of(p - size / 2.0)
	var c1: Vector2i = cell_of(p + size / 2.0 - Vector2(0.01, 0.01))
	for cy: int in range(c0.y, c1.y + 1):
		for cx: int in range(c0.x, c1.x + 1):
			if is_solid_cell(Vector2i(cx, cy)):
				return false
	return true

## Células livres alcançáveis a partir de `start` (vizinhança de 4) dentro de `bounds`. Vazio se `start` é sólida.
func flood(start: Vector2i, bounds: Rect2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {}
	if is_solid_cell(start) or not bounds.has_point(start):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	var head: int = 0
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d: Vector2i in dirs:
			var nxt: Vector2i = cur + d
			if seen.has(nxt) or not bounds.has_point(nxt) or is_solid_cell(nxt):
				continue
			seen[nxt] = true
			queue.append(nxt)
	return seen

## Alguma célula livre alcançada toca `rect` (em pixels)?
static func touches(reached: Dictionary[Vector2i, bool], rect: Rect2) -> bool:
	var c0: Vector2i = cell_of(rect.position)
	var c1: Vector2i = cell_of(rect.end - Vector2(0.01, 0.01))
	for cy: int in range(c0.y, c1.y + 1):
		for cx: int in range(c0.x, c1.x + 1):
			if reached.has(Vector2i(cx, cy)):
				return true
	return false

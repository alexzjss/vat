@tool
extends RefCounted

## Assistente "Novo mapa" (M17), a parte pura: valida id, tamanho, tipo e tile base e calcula o plano do mapa (as células do
## chão e da borda, os marcadores, a arena e os limites da câmera). Não toca em cena nem em disco além de perguntar se a cena
## já existe; quem monta a cena é `map_builder.gd` e quem chama no editor é `ui/map_wizard_dialog.gd`.

const TILE: int = 32
const MIN_W: int = 40
const MIN_H: int = 23
const MAX_W: int = 160
const MAX_H: int = 100
const SCENE_DIR: String = "res://world/mapas"
const DEF_DIR: String = "res://data/maps"
const TEMPLATE_DIR: String = "res://addons/vat_editor/templates/maps"
## Fonte do atlas no `placeholder_32.tres` (veja art/tiles/README.md).
const TILE_SOURCE: int = 0

const WALL: Vector2i = Vector2i(3, 0)
const WATER: Vector2i = Vector2i(4, 0)
const INNER_WALL: Vector2i = Vector2i(6, 0)

## Tiles de chão que o assistente oferece como base (coordenada na folha; todos sem colisão).
const BASE_TILES: Array[Dictionary] = [
	{"label": "Chão", "cell": Vector2i(0, 0)},
	{"label": "Caminho", "cell": Vector2i(1, 0)},
	{"label": "Grama", "cell": Vector2i(2, 0)},
	{"label": "Piso interno", "cell": Vector2i(5, 0)},
	{"label": "Piso da pousada", "cell": Vector2i(6, 1)},
	{"label": "Masmorra A", "cell": Vector2i(7, 1)},
	{"label": "Masmorra B", "cell": Vector2i(8, 1)},
	{"label": "Masmorra C", "cell": Vector2i(9, 1)},
]

## Os tipos que o assistente cria. `ring` = espessura da borda; `arena`/`followers` = o tipo é um `LocalMap` (com `$Arena`).
const KINDS: Array[int] = [MapDef.Kind.CIDADE, MapDef.Kind.INTERIOR, MapDef.Kind.MASMORRA, MapDef.Kind.MUNDO]

static func kind_info(kind: int) -> Dictionary:
	match kind:
		MapDef.Kind.CIDADE:
			return {"label": "Cidade", "template": "cidade", "base": Vector2i(2, 0), "wall": WALL, "ring": 1, "local": true}
		MapDef.Kind.INTERIOR:
			return {"label": "Interior", "template": "interior", "base": Vector2i(5, 0), "wall": INNER_WALL, "ring": 1, "local": true}
		MapDef.Kind.MASMORRA:
			return {"label": "Masmorra", "template": "masmorra", "base": Vector2i(7, 1), "wall": INNER_WALL, "ring": 1, "local": true}
		MapDef.Kind.MUNDO:
			return {"label": "Mapa-múndi", "template": "mundo", "base": Vector2i(2, 0), "wall": WATER, "ring": 2, "local": false}
	return {}

static func kind_label(kind: int) -> String:
	return str(kind_info(kind).get("label", "?"))

static func default_base(kind: int) -> Vector2i:
	return kind_info(kind).get("base", Vector2i(0, 0))

static func base_label(cell: Vector2i) -> String:
	for b: Dictionary in BASE_TILES:
		if b["cell"] == cell:
			return str(b["label"])
	return "?"

# --- validação ---------------------------------------------------------------------------------

## "" se o id serve; senão a mensagem. `registry` pode ser null. A cena não pode existir em `scene_dir`.
static func id_error(id: String, registry: MapRegistry, scene_dir: String = SCENE_DIR) -> String:
	if id == "":
		return "Informe um id."
	var re := RegEx.new()
	re.compile("^[a-z][a-z0-9_]*$")
	if re.search(id) == null:
		return "O id deve usar só letras minúsculas, números e _, começando por letra."
	if registry != null and registry.has(StringName(id)):
		return "O id '%s' já está no registro de mapas." % id
	if FileAccess.file_exists(scene_path(id, scene_dir)):
		return "Já existe a cena %s." % scene_path(id, scene_dir)
	return ""

static func size_error(width: int, height: int) -> String:
	if width < MIN_W or height < MIN_H:
		return "O mapa deve ter pelo menos %d x %d tiles." % [MIN_W, MIN_H]
	if width > MAX_W or height > MAX_H:
		return "O mapa deve ter no máximo %d x %d tiles." % [MAX_W, MAX_H]
	return ""

static func kind_error(kind: int) -> String:
	return "" if KINDS.has(kind) else "Tipo de mapa desconhecido."

static func base_error(base: Vector2i) -> String:
	for b: Dictionary in BASE_TILES:
		if b["cell"] == base:
			return ""
	return "Tile base inválido."

static func size_px(width: int, height: int) -> Vector2i:
	return Vector2i(width * TILE, height * TILE)

static func scene_path(id: String, scene_dir: String = SCENE_DIR) -> String:
	return scene_dir.trim_suffix("/").path_join(id + ".tscn")

static func def_path(id: String, def_dir: String = DEF_DIR) -> String:
	return def_dir.trim_suffix("/").path_join(id + ".tres")

## "minha_vila" -> "MinhaVila" (nome do nó raiz).
static func root_name(id: String) -> String:
	var out: String = ""
	for part: String in id.split("_", false):
		out += part.capitalize().replace(" ", "")
	return out

## "minha_vila" -> "Minha vila" (nome de exibição quando o usuário não digita um).
static func default_display_name(id: String) -> String:
	var s: String = id.replace("_", " ")
	return s.left(1).to_upper() + s.substr(1)

# --- células -----------------------------------------------------------------------------------

## O chão: toda a área com o tile base.
static func floor_cells(width: int, height: int, base: Vector2i) -> Dictionary[Vector2i, Vector2i]:
	var out: Dictionary[Vector2i, Vector2i] = {}
	for y: int in height:
		for x: int in width:
			out[Vector2i(x, y)] = base
	return out

## A borda fechada de `ring` células de espessura, com o tile `wall`.
static func wall_cells(width: int, height: int, wall: Vector2i, ring: int) -> Dictionary[Vector2i, Vector2i]:
	var out: Dictionary[Vector2i, Vector2i] = {}
	for y: int in height:
		for x: int in width:
			if x < ring or y < ring or x >= width - ring or y >= height - ring:
				out[Vector2i(x, y)] = wall
	return out

## Centro de uma célula em pixels.
static func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2, c.y * TILE + TILE / 2)

## A célula livre mais próxima de `target` (em anéis crescentes) cuja vizinhança 3x3 não tem parede e fica dentro do mapa.
## (Vector2i(-1, -1) se não houver.)
static func free_cell_near(target: Vector2i, solid: Dictionary, width: int, height: int) -> Vector2i:
	var max_r: int = maxi(width, height)
	for r: int in range(0, max_r + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c: Vector2i = target + Vector2i(dx, dy)
				if _area_free(c, solid, width, height):
					return c
	return Vector2i(-1, -1)

static func _area_free(c: Vector2i, solid: Dictionary, width: int, height: int) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var n: Vector2i = c + Vector2i(dx, dy)
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height or solid.has(n):
				return false
	return true

# --- plano -------------------------------------------------------------------------------------

## O plano completo do mapa novo. `p`: {id: String, name: String, kind: int, width: int, height: int, base: Vector2i}
## (`name` vazio = derivado do id; `base` ausente = o padrão do tipo). Devolve `{ok, errors, ...}`; com `ok` falso só
## `errors` é confiável. Sem efeitos: nenhuma cena é criada.
static func plan(p: Dictionary, registry: MapRegistry, scene_dir: String = SCENE_DIR, def_dir: String = DEF_DIR) -> Dictionary:
	var id: String = str(p.get("id", "")).strip_edges()
	var kind: int = int(p.get("kind", MapDef.Kind.CIDADE))
	var width: int = int(p.get("width", 0))
	var height: int = int(p.get("height", 0))
	var base: Vector2i = p.get("base", default_base(kind))
	var errors: Array[String] = []
	for e: String in [kind_error(kind), id_error(id, registry, scene_dir), size_error(width, height), base_error(base)]:
		if e != "":
			errors.append(e)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	var info: Dictionary = kind_info(kind)
	var ring: int = int(info["ring"])
	var floor_map: Dictionary[Vector2i, Vector2i] = floor_cells(width, height, base)
	var walls: Dictionary[Vector2i, Vector2i] = wall_cells(width, height, info["wall"], ring)
	var start_cell: Vector2i = free_cell_near(Vector2i(width / 2, height / 2), walls, width, height)
	var entry_cell: Vector2i = free_cell_near(Vector2i(width / 2, height - 1 - ring - 2), walls, width, height)
	if start_cell.x < 0 or entry_cell.x < 0:
		var no_room: Array[String] = ["Não há célula livre para o ponto de partida."]
		return {"ok": false, "errors": no_room}
	var px: Vector2i = size_px(width, height)
	var is_local: bool = bool(info["local"])
	var display: String = str(p.get("name", "")).strip_edges()
	return {
		"ok": true,
		"errors": [] as Array[String],
		"id": id,
		"name": display if display != "" else default_display_name(id),
		"kind": kind,
		"width": width,
		"height": height,
		"base": base,
		"size_px": px,
		"template": TEMPLATE_DIR.path_join(str(info["template"]) + ".tscn"),
		"root_name": root_name(id),
		"scene_path": scene_path(id, scene_dir),
		"def_path": def_path(id, def_dir),
		"floor": floor_map,
		"walls": walls,
		"start_cell": start_cell,
		"entry_cell": entry_cell,
		"start": cell_center(start_cell),
		"entry": cell_center(entry_cell),
		"bounds": Rect2(Vector2.ZERO, Vector2(px)),
		"has_arena": is_local,
		"arena_pos": Vector2(px) / 2.0,
	}

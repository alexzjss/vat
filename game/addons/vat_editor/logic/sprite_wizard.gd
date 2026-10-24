@tool
extends RefCounted

## Editor de arte (M17), a parte pura: sugere o tamanho do quadro e o número de linhas a partir do tamanho de uma imagem
## ("Criar a partir de uma imagem"), monta o `SpriteSet` novo e valida um `SpriteSet` lendo só as propriedades.
##
## A validação repete as regras de `SpriteSet.validate()` e do aviso de retratos do `ContentChecks.sprite_sets` (M16): no
## editor os `.tres` carregados são instâncias "de mentira" e os métodos do recurso não rodam, então o formulário não pode
## chamá-los. Um teste confere que as mensagens são as mesmas do jogo.

const NewEntry: GDScript = preload("res://addons/vat_editor/logic/vat_new_entry.gd")

const KIND_MAP: StringName = &"map"
const KIND_BATTLE: StringName = &"battle"
const KIND_PORTRAIT: StringName = &"portrait"
const KIND_LABELS: Dictionary[StringName, String] = {KIND_MAP: "Folha de mapa", KIND_BATTLE: "Folha de batalha", KIND_PORTRAIT: "Retrato"}

## Tamanhos predefinidos (os do M16).
const MAP_FRAME: Vector2i = Vector2i(32, 48)
const MAP_COLS: int = 3
const MAP_ROWS: int = 4
const BATTLE_FRAME: Vector2i = Vector2i(64, 64)
const BATTLE_MAX_ROWS: int = 6
const PORTRAIT_SIZE: Vector2i = Vector2i(96, 96)
## Quantas colunas tentar (nesta ordem) quando a largura da folha de mapa não bate com o tamanho predefinido.
const MAP_COLS_TRY: Array[int] = [3, 4, 2, 1, 5, 6, 8]
const NEUTRAL: StringName = &"neutro"

# --- sugestões -------------------------------------------------------------------------------------------------

static func _suggestion(kind: StringName, frame: Vector2i, cols: int, rows: int, exact: bool, note: String) -> Dictionary:
	return {"kind": kind, "frame": frame, "cols": cols, "rows": rows, "exact": exact, "note": note}

## As leituras possíveis de uma imagem de `size`, da melhor para a pior: primeiro as que batem com os tamanhos predefinidos
## (`exact`), depois as aproximadas. Cada uma: `{kind, frame: Vector2i, cols, rows, exact, note}`.
## Mapa: precisa de 4 linhas (baixo, esquerda, direita, cima). Batalha: até 6 linhas. Retrato: um quadro só, qualquer tamanho.
static func suggest(size: Vector2i) -> Array[Dictionary]:
	var exact: Array[Dictionary] = []
	var loose: Array[Dictionary] = []
	if size.x <= 0 or size.y <= 0:
		return exact
	var m: Dictionary = _suggest_map(size)
	if not m.is_empty():
		(exact if m["exact"] else loose).append(m)
	var b: Dictionary = _suggest_battle(size)
	if not b.is_empty():
		(exact if b["exact"] else loose).append(b)
	var p: Dictionary = _suggest_portrait(size)
	(exact if p["exact"] else loose).append(p)
	exact.append_array(loose)
	return exact

## A melhor leitura (a primeira de `suggest`), ou {} se a imagem é vazia.
static func best(size: Vector2i) -> Dictionary:
	var all: Array[Dictionary] = suggest(size)
	return {} if all.is_empty() else all[0]

## A leitura de `kind` para `size`, ou {} se não há.
static func suggestion_for(size: Vector2i, kind: StringName) -> Dictionary:
	for s: Dictionary in suggest(size):
		if s["kind"] == kind:
			return s
	return {}

static func _suggest_map(size: Vector2i) -> Dictionary:
	if size.y % MAP_ROWS != 0:
		return {}
	var frame_h: int = size.y / MAP_ROWS
	if size.x % MAP_FRAME.x == 0 and frame_h == MAP_FRAME.y:
		var cols: int = size.x / MAP_FRAME.x
		return _suggestion(KIND_MAP, MAP_FRAME, cols, MAP_ROWS, true, "quadros de %dx%d, %d por linha, 4 direções" % [MAP_FRAME.x, MAP_FRAME.y, cols])
	for c: int in MAP_COLS_TRY:
		if size.x % c == 0:
			var frame := Vector2i(size.x / c, frame_h)
			return _suggestion(KIND_MAP, frame, c, MAP_ROWS, false, "tamanho incomum: %d colunas de %dx%d, 4 direções" % [c, frame.x, frame.y])
	return {}

static func _suggest_battle(size: Vector2i) -> Dictionary:
	if size.x % BATTLE_FRAME.x == 0 and size.y % BATTLE_FRAME.y == 0 and size.y / BATTLE_FRAME.y <= BATTLE_MAX_ROWS:
		var rows: int = size.y / BATTLE_FRAME.y
		var cols: int = size.x / BATTLE_FRAME.x
		return _suggestion(KIND_BATTLE, BATTLE_FRAME, cols, rows, true, "quadros de %dx%d, %d por linha, %d animação(ões)" % [BATTLE_FRAME.x, BATTLE_FRAME.y, cols, rows])
	# tamanho incomum: quadros quadrados (até 6 linhas) cujo lado divide a altura e a largura; vence o lado mais perto de 64 px
	var best_rows: int = 0
	var best_gap: int = 1 << 30
	for rows: int in range(BATTLE_MAX_ROWS, 0, -1):
		if size.y % rows != 0:
			continue
		var side: int = size.y / rows
		if side > 0 and size.x % side == 0 and absi(side - BATTLE_FRAME.x) < best_gap:
			best_rows = rows
			best_gap = absi(side - BATTLE_FRAME.x)
	if best_rows == 0:
		return {}
	var best_side: int = size.y / best_rows
	return _suggestion(KIND_BATTLE, Vector2i(best_side, best_side), size.x / best_side, best_rows, false, "tamanho incomum: quadros de %dx%d, %d linha(s)" % [best_side, best_side, best_rows])

static func _suggest_portrait(size: Vector2i) -> Dictionary:
	if size == PORTRAIT_SIZE:
		return _suggestion(KIND_PORTRAIT, size, 1, 1, true, "retrato de %dx%d" % [size.x, size.y])
	return _suggestion(KIND_PORTRAIT, size, 1, 1, false, "retrato de %dx%d (o predefinido é %dx%d)" % [size.x, size.y, PORTRAIT_SIZE.x, PORTRAIT_SIZE.y])

# --- montar o SpriteSet ----------------------------------------------------------------------------------------

## As animações de batalha padrão ajustadas a uma folha de `cols` x `rows` quadros: as que cabem nas linhas, com os quadros
## limitados às colunas.
static func battle_anims_for(cols: int, rows: int) -> Dictionary[StringName, Vector3i]:
	var out: Dictionary[StringName, Vector3i] = {}
	var defaults: Dictionary[StringName, Vector3i] = SpriteSet.new().anims
	for key: StringName in defaults:
		var a: Vector3i = defaults[key]
		if a.x < rows:
			out[key] = Vector3i(a.x, clampi(a.y, 1, maxi(cols, 1)), a.z)
	return out

## Um `SpriteSet` novo com a imagem na função de `suggestion` (um item de `suggest`). Mapa: `walk_frames` = colunas. Batalha:
## animações padrão que cabem. Retrato: expressão `neutro`.
static func build(texture: Texture2D, suggestion: Dictionary) -> SpriteSet:
	var s := SpriteSet.new()
	var frame: Vector2i = suggestion["frame"]
	match suggestion["kind"]:
		KIND_MAP:
			s.map_sheet = texture
			s.map_frame = frame
			s.walk_frames = maxi(int(suggestion["cols"]), 1)
		KIND_BATTLE:
			s.battle_sheet = texture
			s.battle_frame = frame
			s.anims = battle_anims_for(int(suggestion["cols"]), int(suggestion["rows"]))
		KIND_PORTRAIT:
			s.portraits[NEUTRAL] = texture
			s.portrait_size = frame
	return s

## Prepara o `SpriteSet` novo de uma imagem do projeto: `{ok, error, resource, path}`. Não grava (quem chama salva).
## `image_path`: `res://...png` já importada; `suggestion`: um item de `suggest`; `folder` e `id` dizem onde fica o `.tres`.
static func create(image_path: String, suggestion: Dictionary, id: String, folder: String) -> Dictionary:
	var err: String = NewEntry.id_error(id)
	if err == "":
		err = NewEntry.folder_error(folder)
	if err != "":
		return _fail(err)
	var path: String = NewEntry.target_path(folder, id)
	if FileAccess.file_exists(path):
		return _fail("Já existe um arquivo em %s." % path)
	if suggestion.is_empty():
		return _fail("Escolha como ler a imagem.")
	var texture: Texture2D = null
	if ResourceLoader.exists(image_path):
		texture = ResourceLoader.load(image_path) as Texture2D
	if texture == null:
		return _fail("A imagem ainda não foi importada pelo Godot (%s). Espere o editor importar e tente de novo." % image_path)
	return {"ok": true, "error": "", "resource": build(texture, suggestion), "path": path}

static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "resource": null, "path": ""}

# --- validação -------------------------------------------------------------------------------------------------

## As mensagens de erro do `SpriteSet.validate()`, lidas das propriedades (vazio = tudo certo): quadro válido, folha múltipla
## do quadro, folha de mapa com 4 linhas e colunas suficientes, animações de batalha dentro da folha.
static func messages(sprites: Resource) -> Array[String]:
	var errors: Array[String] = []
	if sprites == null:
		return errors
	var map_frame: Vector2i = sprites.get(&"map_frame")
	var map_sheet: Texture2D = sprites.get(&"map_sheet") as Texture2D
	if map_frame.x <= 0 or map_frame.y <= 0:
		errors.append("map_frame inválido: %s" % map_frame)
	elif map_sheet != null:
		_check_sheet(errors, "map_sheet", map_sheet.get_size(), map_frame)
		var size: Vector2i = Vector2i(map_sheet.get_size())
		var walk: int = int(sprites.get(&"walk_frames"))
		if walk < 1 or walk * map_frame.x > size.x:
			errors.append("map_sheet: %d quadros por linha não cabem em %d px de largura" % [walk, size.x])
		if SpriteSet.Facing.size() * map_frame.y > size.y:
			errors.append("map_sheet: faltam linhas (precisa de %d, tem %d)" % [SpriteSet.Facing.size(), size.y / map_frame.y])
	var frame: Vector2i = sprites.get(&"battle_frame")
	var sheet: Texture2D = sprites.get(&"battle_sheet") as Texture2D
	if frame.x <= 0 or frame.y <= 0:
		errors.append("battle_frame inválido: %s" % frame)
	elif sheet != null:
		var bsize: Vector2i = Vector2i(sheet.get_size())
		_check_sheet(errors, "battle_sheet", sheet.get_size(), frame)
		var anims: Dictionary = sprites.get(&"anims")
		for anim: Variant in anims:
			var a: Vector3i = anims[anim]
			if a.x < 0 or a.y < 1 or a.z < 1:
				errors.append("anim '%s': (linha, quadros, fps) inválido %s" % [anim, a])
			elif (a.x + 1) * frame.y > bsize.y or a.y * frame.x > bsize.x:
				errors.append("anim '%s' fica fora da folha de batalha" % anim)
	return errors

static func _check_sheet(errors: Array[String], label: String, size: Vector2, frame: Vector2i) -> void:
	if int(size.x) % frame.x != 0 or int(size.y) % frame.y != 0:
		errors.append("%s: tamanho %dx%d não é múltiplo do quadro %dx%d" % [label, int(size.x), int(size.y), frame.x, frame.y])

## Os achados do `SpriteSet` aberto: os erros de `messages` e o aviso de retratos sem `neutro` (o do M16).
static func issues(sprites: Resource, path: String = "") -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	if sprites == null:
		return out
	for m: String in messages(sprites):
		out.append(ValidationIssue.error(m, path))
	var portraits: Dictionary = sprites.get(&"portraits")
	if not portraits.is_empty() and not portraits.has(NEUTRAL):
		out.append(ValidationIssue.warning("retratos sem a expressão 'neutro' (a que o diálogo usa quando falta a pedida)", path))
	for expression: Variant in portraits:
		if portraits[expression] == null:
			out.append(ValidationIssue.warning("o retrato '%s' não tem imagem" % expression, path))
	return out

class_name SpriteSet
extends Resource

## Arte de um personagem (M16). Tudo é opcional: o que faltar cai no desenho geométrico de hoje.
## Mapa: `map_sheet` tem uma linha por direção (baixo, esquerda, direita, cima, na ordem de [enum Facing])
## e `walk_frames` quadros por linha; o quadro do meio é o parado.
## Batalha: `battle_sheet` tem as animações de `anims` (nome -> Vector3i(linha, quadros, fps)).
## Retratos: um por expressão, em `portraits`.

## Valores = linha da folha de mapa. Novos valores sempre no fim.
enum Facing { DOWN, LEFT, RIGHT, UP }

## Animações de batalha que repetem em laço; as outras tocam uma vez e param no último quadro.
const LOOPING_ANIMS: Array[StringName] = [&"idle", &"victory"]

@export_group("Mapa")
@export var map_sheet: Texture2D
@export var map_frame: Vector2i = Vector2i(32, 48)
@export var walk_frames: int = 3
@export var walk_fps: float = 8.0

@export_group("Batalha")
@export var battle_sheet: Texture2D
@export var battle_frame: Vector2i = Vector2i(64, 64)
## A folha está desenhada virada para a direita? A batalha espelha o que ficar do lado errado
## (inimigos olham para a esquerda, heróis para a direita).
@export var battle_faces_right: bool = true
## nome -> (linha, quadros, fps).
@export var anims: Dictionary[StringName, Vector3i] = {
	&"idle": Vector3i(0, 4, 6),
	&"attack": Vector3i(1, 4, 12),
	&"cast": Vector3i(2, 4, 10),
	&"hit": Vector3i(3, 2, 10),
	&"down": Vector3i(4, 3, 6),
	&"victory": Vector3i(5, 4, 6),
}

@export_group("Retratos")
@export var portraits: Dictionary[StringName, Texture2D] = {}
@export var portrait_size: Vector2i = Vector2i(96, 96)

## Direção do movimento -> Facing. Eixo dominante vence (empate favorece o vertical); vetor nulo mantém `current`.
static func facing_from(dir: Vector2, current: Facing = Facing.DOWN) -> Facing:
	if dir.length_squared() < 0.0001:
		return current
	if absf(dir.x) > absf(dir.y):
		return Facing.RIGHT if dir.x > 0.0 else Facing.LEFT
	return Facing.DOWN if dir.y > 0.0 else Facing.UP

static func facing_name(facing: Facing) -> StringName:
	match facing:
		Facing.LEFT: return &"left"
		Facing.RIGHT: return &"right"
		Facing.UP: return &"up"
	return &"down"

static func loops(anim: StringName) -> bool:
	return LOOPING_ANIMS.has(anim)

func has_map_art() -> bool:
	return map_sheet != null

func has_battle_art() -> bool:
	return battle_sheet != null

## Quadros de caminhada da direção `facing`, na ordem da folha.
func map_frames(facing: Facing) -> Array[Rect2i]:
	return _row_frames(map_frame, int(facing), walk_frames)

## Índice do quadro parado (o do meio) dentro de [method map_frames].
func idle_index() -> int:
	return walk_frames / 2

## Quadros da animação de batalha `anim`; vazio se ela não existe.
func battle_frames(anim: StringName) -> Array[Rect2i]:
	if not anims.has(anim):
		return []
	var a: Vector3i = anims[anim]
	return _row_frames(battle_frame, a.x, a.y)

func battle_fps(anim: StringName) -> float:
	return float(anims[anim].z) if anims.has(anim) else 0.0

static func _row_frames(frame: Vector2i, row: int, count: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	for i: int in count:
		out.append(Rect2i(i * frame.x, row * frame.y, frame.x, frame.y))
	return out

## Mensagens de erro (vazio = tudo certo): folhas com tamanho múltiplo do quadro e quadros dentro da folha.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if map_frame.x <= 0 or map_frame.y <= 0:
		errors.append("map_frame inválido: %s" % map_frame)
	elif map_sheet != null:
		_check_sheet(errors, "map_sheet", map_sheet.get_size(), map_frame)
		var size: Vector2i = Vector2i(map_sheet.get_size())
		if walk_frames < 1 or walk_frames * map_frame.x > size.x:
			errors.append("map_sheet: %d quadros por linha não cabem em %d px de largura" % [walk_frames, size.x])
		if Facing.size() * map_frame.y > size.y:
			errors.append("map_sheet: faltam linhas (precisa de %d, tem %d)" % [Facing.size(), size.y / map_frame.y])
	if battle_frame.x <= 0 or battle_frame.y <= 0:
		errors.append("battle_frame inválido: %s" % battle_frame)
	elif battle_sheet != null:
		var bsize: Vector2i = Vector2i(battle_sheet.get_size())
		_check_sheet(errors, "battle_sheet", battle_sheet.get_size(), battle_frame)
		for anim: StringName in anims:
			var a: Vector3i = anims[anim]
			if a.x < 0 or a.y < 1 or a.z < 1:
				errors.append("anim '%s': (linha, quadros, fps) inválido %s" % [anim, a])
			elif (a.x + 1) * battle_frame.y > bsize.y or a.y * battle_frame.x > bsize.x:
				errors.append("anim '%s' fica fora da folha de batalha" % anim)
	return errors

static func _check_sheet(errors: Array[String], label: String, size: Vector2, frame: Vector2i) -> void:
	if int(size.x) % frame.x != 0 or int(size.y) % frame.y != 0:
		errors.append("%s: tamanho %dx%d não é múltiplo do quadro %dx%d" % [label, int(size.x), int(size.y), frame.x, frame.y])

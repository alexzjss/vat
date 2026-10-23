@tool
extends RefCounted

## Argumentos de "Testar daqui" (M16): monta os flags de desenvolvimento do Game (`--start-map`, `--spawn`, `--battle`,
## `--level`) e a lista de marcadores de um mapa. O painel roda o jogo com isso num processo à parte.

## Texto legível dos argumentos (barra de estado).
static func to_setting(args: PackedStringArray) -> String:
	return " ".join(args)

## Linha de comando do jogo em outro processo: `--path <projeto> -- <flags>` (o que vem depois de `--` chega ao jogo como
## `OS.get_cmdline_user_args()`). A cena principal é a do projeto (game_fatia.tscn).
static func process_args(project_dir: String, args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray(["--path", project_dir, "--"])
	out.append_array(args)
	return out

## `--start-map=<mapa>` e, se houver, `--spawn=<marcador>`.
static func play_map(map_id: StringName, spawn: StringName = &"") -> PackedStringArray:
	var out := PackedStringArray(["--start-map=%s" % map_id])
	if spawn != &"":
		out.append("--spawn=%s" % spawn)
	return out

## `--battle=<encontro>` e `--level=<n>`; com `map_id` a luta começa na arena desse mapa (senão, a do mapa inicial).
static func battle(encounter_id: StringName, level: int, map_id: StringName = &"", spawn: StringName = &"") -> PackedStringArray:
	var out := PackedStringArray()
	if map_id != &"":
		out.append_array(play_map(map_id, spawn))
	out.append("--battle=%s" % encounter_id)
	out.append("--level=%d" % maxi(level, 1))
	return out

## Caminhos dos `Marker2D` de uma cena de mapa, relativos à raiz (o que `--spawn` espera).
static func markers_of(scene: PackedScene) -> Array[StringName]:
	var out: Array[StringName] = []
	if scene == null:
		return out
	var root: Node = scene.instantiate()
	for n: Node in root.find_children("*", "Marker2D", true, false):
		out.append(StringName(String(root.get_path_to(n))))
	root.free()
	return out

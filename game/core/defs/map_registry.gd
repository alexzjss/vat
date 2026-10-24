@tool
class_name MapRegistry
extends Resource

## Lista dos mapas do jogo (M17), em `data/maps/registro.tres`. O `Game` monta o seu `maps` daqui; os validadores
## e a aba Testar leem a mesma lista.

@export var maps: Array[MapDef] = []

## O mapa com o id, ou null.
func find(id: StringName) -> MapDef:
	for d: MapDef in maps:
		if d != null and d.id == id:
			return d
	return null

func has(id: StringName) -> bool:
	return find(id) != null

## A cena do mapa, ou null se o id não existe.
func scene_of(id: StringName) -> PackedScene:
	var d: MapDef = find(id)
	return d.scene if d != null else null

## Os ids, na ordem da lista (sem repetir, sem vazios).
func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d: MapDef in maps:
		if d != null and d.id != &"" and not out.has(d.id):
			out.append(d.id)
	return out

## id -> cena, na ordem da lista (a primeira entrada vence num id repetido; entradas sem cena ficam de fora).
func scenes() -> Dictionary[StringName, PackedScene]:
	var out: Dictionary[StringName, PackedScene] = {}
	for d: MapDef in maps:
		if d != null and d.id != &"" and d.scene != null and not out.has(d.id):
			out[d.id] = d.scene
	return out

## id -> marcador de saída, só dos mapas que declaram `exit_spawn`.
func exit_spawns() -> Dictionary[StringName, StringName]:
	var out: Dictionary[StringName, StringName] = {}
	for d: MapDef in maps:
		if d != null and d.id != &"" and d.exit_spawn != &"" and not out.has(d.id):
			out[d.id] = d.exit_spawn
	return out

## Problemas do registro: entrada vazia, id vazio, id repetido, cena nula.
func errors() -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	for i: int in maps.size():
		var d: MapDef = maps[i]
		if d == null:
			out.append("mapa [%d]: entrada vazia" % i)
			continue
		if d.id == &"":
			out.append("mapa [%d]: sem id" % i)
		elif seen.has(d.id):
			out.append("mapa '%s': id repetido" % d.id)
		else:
			seen[d.id] = true
		if d.scene == null:
			out.append("mapa '%s': sem cena" % d.id)
	return out

@tool
class_name SoundBank
extends Resource

## Lista dos sons e das musicas do jogo (M19), em `data/audio/sons.tres`. O `Game` e o validador leem daqui.

@export var sounds: Array[SoundDef] = []
@export var musics: Array[MusicDef] = []

## O som com o id, ou null (id vazio nunca acha).
func find_sound(id: StringName) -> SoundDef:
	if id == &"":
		return null
	for d: SoundDef in sounds:
		if d != null and d.id == id:
			return d
	return null

## A musica com o id, ou null (id vazio nunca acha).
func find_music(id: StringName) -> MusicDef:
	if id == &"":
		return null
	for d: MusicDef in musics:
		if d != null and d.id == id:
			return d
	return null

## Problemas de dados: ids vazios e repetidos (sons e musicas tem listas separadas).
func errors() -> Array[String]:
	var out: Array[String] = []
	var seen_s: Dictionary[StringName, bool] = {}
	for i: int in sounds.size():
		var d: SoundDef = sounds[i]
		if d == null or d.id == &"":
			out.append("sons[%d]: id vazio" % i)
		elif seen_s.has(d.id):
			out.append("sons: id repetido '%s'" % d.id)
		else:
			seen_s[d.id] = true
	var seen_m: Dictionary[StringName, bool] = {}
	for i: int in musics.size():
		var d: MusicDef = musics[i]
		if d == null or d.id == &"":
			out.append("musicas[%d]: id vazio" % i)
		elif seen_m.has(d.id):
			out.append("musicas: id repetido '%s'" % d.id)
		else:
			seen_m[d.id] = true
	return out

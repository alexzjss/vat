@tool
extends RefCounted

## Fontes dos menus do editor de blocos (M17), puras: itens, equipamentos, heróis, encontros e habilidades vêm do
## `ContentIndex`; os falantes e as expressões, dos heróis e dos `SpeakerDef`; as flags, dos documentos do projeto;
## os rótulos, do evento. Sem Node e sem IO (quem chama entrega os índices, as listas e os documentos).

const OPS: Array[String] = ["==", "!=", ">=", "<=", ">", "<"]
const END_LABEL: String = "fim"

## Ids de um tipo do `ContentIndex` (`item`, `equip`, `hero`, `encounter`, `ability`), em ordem alfabética.
static func ids(index: ContentIndex, kind: StringName) -> Array[String]:
	var out: Array[String] = []
	if index == null:
		return out
	for id: StringName in index.ids(kind):
		out.append(String(id))
	return out

static func items(index: ContentIndex) -> Array[String]:
	return ids(index, &"item")

static func equipment(index: ContentIndex) -> Array[String]:
	return ids(index, &"equip")

static func heroes(index: ContentIndex) -> Array[String]:
	return ids(index, &"hero")

static func encounters(index: ContentIndex) -> Array[String]:
	return ids(index, &"encounter")

static func abilities(index: ContentIndex) -> Array[String]:
	return ids(index, &"ability")

## "id - Nome" para mostrar no menu; só o id quando o recurso não tem nome.
static func display(index: ContentIndex, kind: StringName, id: String) -> String:
	if index == null:
		return id
	var res: Resource = index.resolve(kind, StringName(id))
	var shown: String = "" if res == null else str(res.get(&"display_name"))
	return id if shown == "" else "%s - %s" % [id, shown]

## Os heróis (CharacterDef) do índice, para achar falantes e retratos.
static func hero_defs(index: ContentIndex) -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for id: String in heroes(index):
		var h: CharacterDef = index.resolve(&"hero", StringName(id)) as CharacterDef
		if h != null:
			out.append(h)
	return out

## Quem pode falar: o nome de cada herói e o de cada `SpeakerDef` (o nome, ou o id se não tem nome). Sem repetir.
static func speakers(hero_list: Array[CharacterDef], speaker_defs: Array[SpeakerDef]) -> Array[String]:
	var out: Array[String] = []
	for h: CharacterDef in hero_list:
		if h != null and h.display_name != "" and not out.has(h.display_name):
			out.append(h.display_name)
	for s: SpeakerDef in speaker_defs:
		if s == null:
			continue
		var n: String = s.display_name if s.display_name != "" else String(s.id)
		if n != "" and not out.has(n):
			out.append(n)
	return out

## As expressões (chaves de `portraits`) de quem fala, `neutro` primeiro; vazio se o falante não tem retratos.
static func expressions(speaker: String, hero_list: Array[CharacterDef], speaker_defs: Array[SpeakerDef]) -> Array[String]:
	var out: Array[String] = []
	var art: SpriteSet = SpeakerResolver.resolve(speaker, hero_list, speaker_defs)
	if art == null:
		return out
	for k: StringName in art.portraits:
		out.append(String(k))
	out.sort()
	var neutral: String = String(SpeakerResolver.DEFAULT_EXPRESSION)
	if out.has(neutral):
		out.erase(neutral)
		out.push_front(neutral)
	return out

## Flags declaradas (`@flag`) e usadas (condições, `@set`, `@add`) em todos os `docs`, sem repetir, em ordem alfabética.
static func flags(docs: Array) -> Array[String]:
	var out: Array[String] = []
	for d: Variant in docs:
		var doc: RoteiroDoc = d as RoteiroDoc
		if doc == null:
			continue
		for f: StringName in doc.flags_declared():
			if not out.has(String(f)):
				out.append(String(f))
		for f: StringName in doc.flags_used():
			if not out.has(String(f)):
				out.append(String(f))
	out.sort()
	return out

## Os rótulos de um evento (`== nome`) e, no fim, o `fim` implícito.
static func labels(event: RoteiroEvent) -> Array[String]:
	var out: Array[String] = []
	if event != null:
		for l: StringName in event.labels():
			out.append(String(l))
	out.append(END_LABEL)
	return out

static func ops() -> Array[String]:
	return OPS.duplicate()

@tool
extends RefCounted

## Aba Roteiros do painel (M16): para cada `.roteiro`, os eventos e os erros e avisos de compilação com a linha.

const _LINE_PATTERN: String = "^[^:]*:(\\d+): (.*)$"

## "arquivo:12: mensagem" -> `{line: 12, message: "mensagem"}` (sem linha: `{line: 0, message: texto}`).
static func parse_message(text: String) -> Dictionary:
	var re := RegEx.new()
	re.compile(_LINE_PATTERN)
	var m: RegExMatch = re.search(text)
	if m == null:
		return {"line": 0, "message": text}
	return {"line": m.get_string(1).to_int(), "message": m.get_string(2)}

## Relatório de um arquivo: `{path, events: Array[String], errors: Array[Dictionary], warnings: Array[Dictionary]}`,
## com os achados já separados em linha e mensagem.
static func report(path: String, index: ContentIndex) -> Dictionary:
	var r: Dictionary = RoteiroTools.compile_file(path, index)
	var events: Array[String] = []
	for k: Variant in (r["events"] as Dictionary).keys():
		events.append(str(k))
	events.sort()
	return {"path": path, "events": events,
			"errors": _parsed(r["errors"] as Array), "warnings": _parsed(r["warnings"] as Array)}

static func _parsed(messages: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m: Variant in messages:
		out.append(parse_message(str(m)))
	return out

## Relatório de todos os `.roteiro` do projeto.
static func scan(index: ContentIndex) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for path: String in RoteiroTools.find_roteiros("res://"):
		out.append(report(path, index))
	return out

## Texto de uma linha de achado: "linha 12: mensagem" (ou só a mensagem).
static func format_finding(f: Dictionary) -> String:
	return "linha %d: %s" % [f["line"], f["message"]] if int(f["line"]) > 0 else str(f["message"])

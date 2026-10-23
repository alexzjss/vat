class_name ValidationIssue
extends RefCounted

## Um achado dos validadores de conteúdo (M16). Puro: só dados.
## `path` é o recurso ou arquivo de origem (`res://...`); `line` é 0 quando não se aplica.

## Novos valores sempre no fim.
enum Severity { ERROR, WARNING }

var severity: Severity = Severity.ERROR
var message: String = ""
var path: String = ""
var line: int = 0

static func make(p_severity: Severity, p_message: String, p_path: String = "", p_line: int = 0) -> ValidationIssue:
	var i := ValidationIssue.new()
	i.severity = p_severity
	i.message = p_message
	i.path = p_path
	i.line = p_line
	return i

static func error(p_message: String, p_path: String = "", p_line: int = 0) -> ValidationIssue:
	return make(Severity.ERROR, p_message, p_path, p_line)

static func warning(p_message: String, p_path: String = "", p_line: int = 0) -> ValidationIssue:
	return make(Severity.WARNING, p_message, p_path, p_line)

func is_error() -> bool:
	return severity == Severity.ERROR

## "res://x.tres:12: mensagem" (sem a linha quando 0, sem o caminho quando vazio).
func location() -> String:
	if path == "":
		return ""
	return "%s:%d" % [path, line] if line > 0 else path

func to_text() -> String:
	var loc: String = location()
	return "%s: %s" % [loc, message] if loc != "" else message

## Uma linha de texto por achado, para um processo filho devolver o resultado (o painel VAT roda o validador à parte):
## `VATISSUE {"s":<gravidade>,"m":<mensagem>,"p":<caminho>,"l":<linha>}`.
const LINE_PREFIX: String = "VATISSUE "

func to_line() -> String:
	return LINE_PREFIX + JSON.stringify({"s": int(severity), "m": message, "p": path, "l": line})

## O achado de uma linha de [method to_line], ou null se a linha é outra coisa.
static func from_line(text: String) -> ValidationIssue:
	if not text.begins_with(LINE_PREFIX):
		return null
	var json := JSON.new()
	if json.parse(text.trim_prefix(LINE_PREFIX)) != OK or not json.data is Dictionary:
		return null
	var d: Dictionary = json.data
	return make(int(d.get("s", 0)) as Severity, str(d.get("m", "")), str(d.get("p", "")), int(d.get("l", 0)))

## Só os erros / só os avisos.
static func errors_of(issues: Array[ValidationIssue]) -> Array[ValidationIssue]:
	return _only(issues, Severity.ERROR)

static func warnings_of(issues: Array[ValidationIssue]) -> Array[ValidationIssue]:
	return _only(issues, Severity.WARNING)

static func _only(issues: Array[ValidationIssue], s: Severity) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for i: ValidationIssue in issues:
		if i.severity == s:
			out.append(i)
	return out

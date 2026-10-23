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

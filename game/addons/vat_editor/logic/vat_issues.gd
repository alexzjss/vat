@tool
extends RefCounted

## Resultado do "Validar tudo" no painel (M16): agrupa os achados por gravidade e formata cada linha.

## Argumentos do processo filho que roda os validadores e grava um `VATISSUE` por achado em `out_file`. O validador não roda dentro
## do editor porque os scripts do jogo não são `@tool` lá (os métodos dos recursos não executam), então o painel o chama
## num Godot headless à parte, com o mesmo executável do editor.
static func child_args(project_dir: String, out_file: String) -> PackedStringArray:
	return PackedStringArray(["--headless", "--path", project_dir, "-s", "res://tools/validate/check_all.gd", "--", "--json=" + out_file])

## Achados no texto gravado pelo processo filho (linhas que não são `VATISSUE` são ignoradas).
static func parse_output(output: String) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for l: String in output.split("\n"):
		var issue: ValidationIssue = ValidationIssue.from_line(l.strip_edges())
		if issue != null:
			out.append(issue)
	return out

## `{errors: Array[ValidationIssue], warnings: Array[ValidationIssue]}`.
static func group(issues: Array[ValidationIssue]) -> Dictionary:
	return {"errors": ValidationIssue.errors_of(issues), "warnings": ValidationIssue.warnings_of(issues)}

static func summary(issues: Array[ValidationIssue]) -> String:
	var g: Dictionary = group(issues)
	var e: int = (g["errors"] as Array).size()
	var w: int = (g["warnings"] as Array).size()
	if e == 0 and w == 0:
		return "Tudo certo: nenhum erro e nenhum aviso."
	return "%d erro(s), %d aviso(s)." % [e, w]

## Linha da árvore: `{text, path, line, error}`.
static func entry(i: ValidationIssue) -> Dictionary:
	return {"text": i.to_text(), "path": i.path, "line": i.line, "error": i.is_error()}

static func entries(issues: Array[ValidationIssue]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: ValidationIssue in issues:
		out.append(entry(i))
	return out

## O que fazer ao clicar num achado: `&"resource"` (Inspector), `&"roteiro"` (arquivo de texto), `&"scene"` ou `&"none"`.
static func target_kind(path: String) -> StringName:
	match path.get_extension():
		"tres", "res":
			return &"resource"
		"roteiro":
			return &"roteiro"
		"tscn", "scn":
			return &"scene"
	return &"none"

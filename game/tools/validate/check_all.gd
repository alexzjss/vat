extends SceneTree

## Roda todos os validadores de conteúdo e imprime os achados por gravidade (M16). Sai com código 1 se houver erro.
## Uso: godot --headless --path game -s tools/validate/check_all.gd

func _init() -> void:
	var issues: Array[ValidationIssue] = Validator.run_all()
	var errors: Array[ValidationIssue] = ValidationIssue.errors_of(issues)
	var warnings: Array[ValidationIssue] = ValidationIssue.warnings_of(issues)
	print("== AVISOS (%d) ==" % warnings.size())
	for w: ValidationIssue in warnings:
		print("aviso: ", w.to_text())
	print("== ERROS (%d) ==" % errors.size())
	for e: ValidationIssue in errors:
		printerr("erro: ", e.to_text())
	print("validação: %d erro(s), %d aviso(s)" % [errors.size(), warnings.size()])
	quit(1 if not errors.is_empty() else 0)

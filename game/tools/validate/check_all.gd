extends SceneTree

## Roda todos os validadores de conteúdo e imprime os achados por gravidade (M16). Sai com código 1 se houver erro.
## Uso: godot --headless --path game -s tools/validate/check_all.gd
## Com `-- --json=<arquivo>` grava (UTF-8) só uma linha `VATISSUE {...}` por achado (ValidationIssue.to_line) nesse arquivo,
## para o painel VAT do editor (um arquivo, e não a saída padrão, para não depender da codificação do console).

func _init() -> void:
	var issues: Array[ValidationIssue] = Validator.run_all()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--json="):
			var f: FileAccess = FileAccess.open(a.trim_prefix("--json="), FileAccess.WRITE)
			if f == null:
				printerr("não foi possível gravar ", a)
				quit(2)
				return
			for i: ValidationIssue in issues:
				f.store_line(i.to_line())
			f.close()
			quit(1 if not ValidationIssue.errors_of(issues).is_empty() else 0)
			return
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

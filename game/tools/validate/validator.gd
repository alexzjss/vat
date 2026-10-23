class_name Validator
extends RefCounted

## Ponto de entrada único dos validadores de conteúdo (M16): carrega `res://data`, `res://art`, os `.roteiro` e os mapas
## e roda todas as regras de [ContentChecks]. Usado por tools/validate/check_all.gd, pelos testes e pelo painel do editor.

static func run_all() -> Array[ValidationIssue]:
	return ContentChecks.run(ContentLoader.load_all())

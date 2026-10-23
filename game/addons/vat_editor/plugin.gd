@tool
extends EditorPlugin

## Plugin do editor do VAT (M16). Só do editor: o jogo exportado não carrega nada daqui.
## Registra o importador de `.roteiro`.

const RoteiroImporter: GDScript = preload("res://addons/vat_editor/roteiro_importer.gd")

var _roteiro_importer: EditorImportPlugin

func _enter_tree() -> void:
	_roteiro_importer = RoteiroImporter.new()
	add_import_plugin(_roteiro_importer)

func _exit_tree() -> void:
	if _roteiro_importer != null:
		remove_import_plugin(_roteiro_importer)
		_roteiro_importer = null

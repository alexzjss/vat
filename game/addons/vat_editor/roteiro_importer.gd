@tool
extends EditorImportPlugin

## Importa `.roteiro` como RoteiroBook (M16): compila o texto com os ids de `res://data` e salva o livro `.res`.
## Com erro de compilação, a importação falha e cada erro vai para o console do editor (`arquivo:linha: mensagem`).
## Em execução headless (testes, demo) o `godot --headless --path game --import` já carrega este plugin e gera os livros
## em `.godot/imported`; o jogo só faz `load()` deles, sem compilar nada nem depender deste addon.
## Os recursos de `res://data` que o roteiro cita não são rastreados: depois de mudar um id, reimporte o `.roteiro`.

func _get_importer_name() -> String:
	return "vat.roteiro"

func _get_visible_name() -> String:
	return "Roteiro VAT"

func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["roteiro"])

func _get_save_extension() -> String:
	return "res"

func _get_resource_type() -> String:
	return "Resource"

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 0

func _get_preset_count() -> int:
	return 1

func _get_preset_name(_preset_index: int) -> String:
	return "Padrão"

func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []

func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true

func _import(source_file: String, save_path: String, _options: Dictionary, _platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var r: Dictionary = RoteiroTools.compile_file(source_file, RoteiroTools.scan_content())
	for w: String in r["warnings"]:
		push_warning(w)
	var errors: Array[String] = r["errors"]
	if not errors.is_empty():
		for e: String in errors:
			push_error(e)
		return ERR_PARSE_ERROR
	var book := RoteiroBook.new()
	book.events = r["events"]
	return ResourceSaver.save(book, "%s.%s" % [save_path, _get_save_extension()])

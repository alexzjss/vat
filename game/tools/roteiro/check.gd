extends SceneTree

## Compila todo `.roteiro` de `res://` e imprime erros e avisos (M16). Sai com código 1 se houver erro.
## Uso: godot --headless --path game -s tools/roteiro/check.gd

func _init() -> void:
	var paths: Array[String] = RoteiroTools.find_roteiros("res://")
	var index: ContentIndex = RoteiroTools.scan_content()
	var res: Dictionary = RoteiroTools.check(paths, index)
	for w: String in res["warnings"]:
		print("aviso: ", w)
	for e: String in res["errors"]:
		printerr("erro: ", e)
	print("roteiros: %d arquivo(s), %d evento(s), %d erro(s), %d aviso(s)" % [
		res["files"], res["events"], (res["errors"] as Array).size(), (res["warnings"] as Array).size()])
	quit(1 if not (res["errors"] as Array).is_empty() else 0)

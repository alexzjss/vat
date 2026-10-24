extends SceneTree

## Roda um pedido de simulação de evento (M17) num processo à parte: o painel VAT não pode simular dentro do editor, porque
## os scripts do jogo não são `@tool` lá. Lê `--in=<json>` (`{text, source, event, setup}`) e grava `--out=<json>`
## (`{ok, errors, result}`). Uso: godot --headless --path game -s tools/roteiro/simulate.gd -- --in=a.json --out=b.json

func _init() -> void:
	var in_path: String = ""
	var out_path: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			in_path = a.trim_prefix("--in=")
		elif a.begins_with("--out="):
			out_path = a.trim_prefix("--out=")
	var job: Variant = JSON.parse_string(FileAccess.get_file_as_string(in_path))
	if not job is Dictionary or out_path == "":
		printerr("simulate: pedido ou saída inválidos")
		quit(2)
		return
	var res: Dictionary = RoteiroTools.simulate_job(job as Dictionary)
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		printerr("simulate: não foi possível gravar %s" % out_path)
		quit(2)
		return
	f.store_string(JSON.stringify(res))
	f.close()
	quit(0)

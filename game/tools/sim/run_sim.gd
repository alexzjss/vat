extends SceneTree

## Executa o relatorio comparativo: godot --headless --path game -s tools/sim/run_sim.gd -- [-runs N] [-out caminho.md]

const DEFAULT_RUNS: int = 30
const DEFAULT_OUT: String = "docs/balance/2026-10-19-relatorio-opcoes.md"

func _init() -> void:
	var runs: int = DEFAULT_RUNS
	var out: String = ProjectSettings.globalize_path("res://").path_join("..").path_join(DEFAULT_OUT).simplify_path()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		var a: String = args[i].lstrip("-").to_lower()
		if a == "runs" and i + 1 < args.size():
			runs = maxi(1, args[i + 1].to_int())
			i += 1
		elif a == "out" and i + 1 < args.size():
			out = args[i + 1]
			i += 1
		i += 1
	var t0: int = Time.get_ticks_msec()
	var result: Dictionary = SimReport.build(SimReport.formula_ids(), SimReport.default_cases(), runs, true)
	var ok: bool = SimReport.write_files(result, out)
	print("[sim] %s em %.1f s -> %s" % ["ok" if ok else "FALHA", float(Time.get_ticks_msec() - t0) / 1000.0, out])
	quit(0 if ok else 1)

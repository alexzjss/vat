extends SceneTree

## Executa o relatorio comparativo: godot --headless --path game -s tools/sim/run_sim.gd -- [-runs N] [-out caminho.md] [-hard fator] [-hardruns N] [-search]

const DEFAULT_RUNS: int = 30
const DEFAULT_OUT: String = "docs/balance/2026-10-19-relatorio-opcoes.md"

func _init() -> void:
	var runs: int = DEFAULT_RUNS
	var out: String = ProjectSettings.globalize_path("res://").path_join("..").path_join(DEFAULT_OUT).simplify_path()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var hard: float = SimReport.HARD_SCALE
	var hard_runs: int = SimReport.HARD_RUNS_DEFAULT
	var search: bool = false
	var i: int = 0
	while i < args.size():
		var a: String = args[i].lstrip("-").to_lower()
		if a == "runs" and i + 1 < args.size():
			runs = maxi(1, args[i + 1].to_int())
			i += 1
		elif a == "hard" and i + 1 < args.size():
			hard = args[i + 1].to_float()
			i += 1
		elif a == "hardruns" and i + 1 < args.size():
			hard_runs = maxi(1, args[i + 1].to_int())
			i += 1
		elif a == "search":
			search = true
		elif a == "out" and i + 1 < args.size():
			out = args[i + 1]
			i += 1
		i += 1
	if search:
		for f: float in [1.12, 1.125, 1.13, 1.135, 1.14]:
			var m: SimMetrics = SimRunner.run(SimReport.make_scenario(SimReport.hard_case(f, &"basic"), runs, "", 0, "hard"))
			var ms: SimMetrics = SimRunner.run(SimReport.make_scenario(SimReport.hard_case(f, &"smart"), runs, "", 0, "hard"))
			print("[search] x%.3f basic win %.0f%% (dur %.0f s) | smart win %.0f%% (dur %.0f s)" % [f, m.win_rate() * 100.0, m.mean_duration(), ms.win_rate() * 100.0, ms.mean_duration()])
		quit(0)
		return
	var t0: int = Time.get_ticks_msec()
	var result: Dictionary = SimReport.build(SimReport.formula_ids(), SimReport.default_cases(hard, hard_runs), runs, true)
	var ok: bool = SimReport.write_files(result, out)
	print("[sim] %s em %.1f s -> %s" % ["ok" if ok else "FALHA", float(Time.get_ticks_msec() - t0) / 1000.0, out])
	quit(0 if ok else 1)

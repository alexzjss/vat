extends SceneTree

## Executa o relatorio comparativo: godot --headless --path game -s tools/sim/run_sim.gd -- [-runs N] [-out caminho.md] [-hard fator] [-hardruns N] [-search] [-final] [-meta]

const DEFAULT_RUNS: int = 30
const DEFAULT_OUT: String = "docs/balance/2026-10-19-relatorio-opcoes.md"
const DEFAULT_FINAL: String = "docs/balance/2026-10-19-relatorio-final.md"

func _init() -> void:
	var runs: int = DEFAULT_RUNS
	var out: String = ProjectSettings.globalize_path("res://").path_join("..").path_join(DEFAULT_OUT).simplify_path()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var hard: float = SimReport.HARD_SCALE
	var hard_runs: int = SimReport.HARD_RUNS_DEFAULT
	var search: bool = false
	var final_report: bool = false
	var meta: bool = false
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
		elif a == "final":
			final_report = true
		elif a == "meta":
			meta = true
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
	if meta:
		# Varredura rapida: so imprime as metricas dos cenarios-meta com o padrao escolhido.
		var cs: Array[Dictionary] = SimReport.target_cases()
		var ms: Array[SimMetrics] = SimReport.run_targets(runs)
		for k: int in cs.size():
			var pol: StringName = cs[k]["policy"]
			print("[meta] N%d %-7s %-5s win %3.0f%% dur %5.1f s hp %3.0f%% %s" % [int(cs[k]["level"]), str(cs[k]["enc"]), str(pol), ms[k].win_rate() * 100.0, ms[k].mean_duration(), ms[k].mean_party_hp_pct() * 100.0, "ok" if SimReport.meets_target(pol, str(cs[k]["enc"]), ms[k]) else "FORA"])
		print("[meta] %.1f s" % (float(Time.get_ticks_msec() - t0) / 1000.0))
		quit(0)
		return
	if final_report:
		var fo: String = out
		if fo.ends_with(DEFAULT_OUT):
			fo = fo.replace(DEFAULT_OUT, DEFAULT_FINAL)
		var fr: Dictionary = SimReport.build_final(runs, true)
		var fok: bool = SimReport.write_files(fr, fo)
		print("[sim] final %s em %.1f s -> %s" % ["ok" if fok else "FALHA", float(Time.get_ticks_msec() - t0) / 1000.0, fo])
		quit(0 if fok else 1)
		return
	var result: Dictionary = SimReport.build(SimReport.formula_ids(), SimReport.default_cases(hard, hard_runs), runs, true)
	var ok: bool = SimReport.write_files(result, out)
	print("[sim] %s em %.1f s -> %s" % ["ok" if ok else "FALHA", float(Time.get_ticks_msec() - t0) / 1000.0, out])
	quit(0 if ok else 1)

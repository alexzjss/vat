extends GutTest

func test_report_has_header_and_one_row_per_option() -> void:
	var cases: Array[Dictionary] = [{"level": 1, "enc": "X+Y", "policy": &"basic"}]
	var ids: Array[String] = ["F12"]
	var r: Dictionary = SimReport.build(ids, cases, 2)
	var md: String = r["markdown"]
	assert_true(md.contains(SimMetrics.header()))
	assert_true(md.contains("## Metas"))
	assert_true(md.contains("F12-A - N1 X+Y basic"))
	assert_true(md.contains("F12-B - N1 X+Y basic"))
	assert_false(md.contains("F12-C"))
	# Cada opcao: uma linha no detalhe, com 2 execucoes.
	var rows: int = 0
	for line: String in md.split("\n"):
		if line.begins_with("| F12-") and line.contains(" - N1 X+Y basic | 2 |"):
			rows += 1
	assert_eq(rows, 2)
	var csv_lines: PackedStringArray = (r["csv"] as String).strip_edges().split("\n")
	assert_eq(csv_lines.size(), 4)
	assert_true(csv_lines[2].begins_with("F12,A,1,X+Y,basic,2,"))

func test_report_is_deterministic() -> void:
	var cases: Array[Dictionary] = [{"level": 1, "enc": "X+Y", "policy": &"smart"}]
	var ids: Array[String] = ["F6"]
	assert_eq(SimReport.build(ids, cases, 2)["csv"], SimReport.build(ids, cases, 2)["csv"])

extends GutTest

## A checagem de `.roteiro` (M16): a mesma lógica de `tools/roteiro/check.gd`, como função pura sobre os arquivos do
## repositório. O importador do editor entrega os livros ao jogo; aqui se confere que todos compilam limpos.

func test_the_repo_roteiros_compile_without_errors() -> void:
	var paths: Array[String] = RoteiroTools.find_roteiros("res://")
	assert_gte(paths.size(), 3, "cidade, casas e dungeon da fatia")
	var res: Dictionary = RoteiroTools.check(paths, RoteiroTools.scan_content())
	assert_eq(res["errors"], [] as Array[String], "nenhum erro")
	assert_eq(res["warnings"], [] as Array[String], "nenhum aviso")
	assert_gte(int(res["events"]), 14)

func test_find_roteiros_lists_the_slice_files_and_skips_addons_and_godot_cache() -> void:
	var paths: Array[String] = RoteiroTools.find_roteiros("res://")
	for f: String in ["cidade", "casas", "dungeon"]:
		assert_true(paths.has("res://data/fatia/roteiro/%s.roteiro" % f), f)
	for p: String in paths:
		assert_false(p.contains("/.godot/") or p.contains("/addons/"), p)

func test_check_reports_errors_with_file_and_line() -> void:
	var ix: ContentIndex = ContentIndex.from_resources([])
	var r: Dictionary = RoteiroTools.compile_text("=== e\nAna: oi\n-> sumiu\n", "x.roteiro", ix)
	assert_eq((r["errors"] as Array).size(), 1)
	assert_true(String((r["errors"] as Array)[0]).begins_with("x.roteiro:3:"), (r["errors"] as Array)[0])

func test_check_counts_errors_of_an_unreadable_file() -> void:
	var res: Dictionary = RoteiroTools.check(["res://nao/existe.roteiro"] as Array[String], ContentIndex.from_resources([]))
	assert_eq((res["errors"] as Array).size(), 1)
	assert_true(String((res["errors"] as Array)[0]).begins_with("existe.roteiro:"))

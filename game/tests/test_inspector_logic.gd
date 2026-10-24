extends GutTest

## Lógica das escolhas em lista do Inspector (M17): que propriedade ganha que menu, a lista de mapas, os marcadores de uma
## cena, os eventos de um livro, as opções de recursos e a marca de valor inválido.

const Picks: GDScript = preload("res://addons/vat_editor/logic/inspector_picks.gd")
const Palette: GDScript = preload("res://addons/vat_editor/logic/palette.gd")

func _chain(path: String) -> Array[String]:
	return Palette.script_chain(load(path) as Script)

# --- que propriedade ganha que menu ---

func test_map_link_gets_map_and_spawn_pickers() -> void:
	var chain: Array[String] = _chain("res://world/map_link.gd")
	assert_eq(Picks.pick_for(chain, &"target_map", false), {"kind": &"map"})
	assert_eq(Picks.pick_for(chain, &"target_spawn", false), {"kind": &"spawn"})
	assert_eq(Picks.pick_for(chain, &"label_text", false), {})

func test_zone_gets_map_and_spawn_pickers() -> void:
	var chain: Array[String] = _chain("res://world/zone.gd")
	assert_eq(Picks.pick_for(chain, &"zone_id", false), {"kind": &"map"})
	assert_eq(Picks.pick_for(chain, &"spawn", false), {"kind": &"spawn"})

func test_roteiro_pair_gets_book_and_event_pickers() -> void:
	var chain: Array[String] = _chain("res://world/npc.gd")
	assert_eq(Picks.pick_for(chain, &"roteiro", true), {"kind": &"book"})
	assert_eq(Picks.pick_for(chain, &"event_id", true), {"kind": &"event"})
	assert_eq(Picks.pick_for(chain, &"roteiro", false), {})

func test_resource_pickers() -> void:
	assert_eq(Picks.pick_for(_chain("res://world/map_enemy.gd"), &"encounter", false), {"kind": &"resource", "resource_class": "EncounterDef"})
	assert_eq(Picks.pick_for(_chain("res://world/shop_keeper.gd"), &"shop", false), {"kind": &"resource", "resource_class": "ShopDef"})
	assert_eq(Picks.pick_for(_chain("res://world/npc.gd"), &"speaker", false), {"kind": &"resource", "resource_class": "SpeakerDef"})
	assert_eq(Picks.pick_for(_chain("res://world/elemental_obstacle.gd"), &"element", false), {"kind": &"resource", "resource_class": "ElementDef"})

func test_other_properties_stay_untouched() -> void:
	assert_eq(Picks.pick_for(_chain("res://world/chest.gd"), &"opened_flag", false), {})
	assert_eq(Picks.pick_for(_chain("res://world/map_enemy.gd"), &"chases", false), {})

func test_has_roteiro_pair() -> void:
	assert_true(Picks.has_roteiro_pair(["prompt", "roteiro", "event_id"] as Array[String]))
	assert_false(Picks.has_roteiro_pair(["roteiro"] as Array[String]))

# --- mapas e marcadores ---

func test_map_ids_follow_the_registry() -> void:
	var reg: MapRegistry = Game.default_registry()
	var ids: Array[String] = Picks.map_ids(reg)
	assert_eq(ids.size(), reg.ids().size())
	assert_true(ids.has("dungeon_1"))
	assert_eq(Picks.map_ids(null), [] as Array[String])

func test_spawns_of_a_scene_are_the_root_markers_only() -> void:
	var spawns: Array[String] = Picks.spawns_of(load("res://world/fatia/dungeon_1.tscn") as PackedScene)
	for want: String in ["Entry", "Escada", "RestSpawn"]:
		assert_true(spawns.has(want), want)
	assert_false(spawns.has("HeroSpot1"), "marcadores da arena ficam de fora")

func test_spawns_of_the_overworld() -> void:
	var spawns: Array[String] = Picks.spawns_of(load("res://world/overworld.tscn") as PackedScene)
	assert_true(spawns.has("Start"))
	assert_true(spawns.has("DungeonReturn"))

func test_spawns_include_the_ones_inherited_from_the_template() -> void:
	var tpl: PackedScene = load("res://addons/vat_editor/templates/maps/masmorra.tscn") as PackedScene
	if tpl == null:
		pending("modelo de masmorra não encontrado")
		return
	var spawns: Array[String] = Picks.spawns_of(tpl)
	assert_true(spawns.has("Entry"))

func test_spawns_of_null_or_unknown_map_are_empty() -> void:
	assert_eq(Picks.spawns_of(null), [] as Array[String])
	assert_eq(Picks.spawns_for_map(Game.default_registry(), &"nao_existe"), [] as Array[String])
	assert_true(Picks.spawns_for_map(Game.default_registry(), &"dungeon_1").has("Entry"))

# --- livros e eventos ---

func test_event_ids_are_sorted() -> void:
	var book := RoteiroBook.new()
	book.events[&"b"] = EventScript.new()
	book.events[&"a"] = EventScript.new()
	assert_eq(Picks.event_ids(book), ["a", "b"] as Array[String])
	assert_eq(Picks.event_ids(null), [] as Array[String])

func test_real_book_lists_its_events() -> void:
	var paths: Array[String] = Picks.book_paths(RoteiroTools.find_roteiros("res://"))
	assert_gt(paths.size(), 0)
	var book: RoteiroBook = load(paths[0]) as RoteiroBook
	assert_not_null(book)
	assert_gt(Picks.event_ids(book).size(), 0)

# --- recursos ---

func test_resource_options_filter_by_class_and_sort_by_label() -> void:
	var s1 := ShopDef.new()
	s1.id = &"zeta"
	s1.display_name = "Loja Z"
	var s2 := ShopDef.new()
	s2.id = &"alfa"
	var e := ElementDef.new()
	e.id = &"fogo"
	var opts: Array[Dictionary] = Picks.resource_options([s1, e, s2, null], "ShopDef")
	assert_eq(opts.size(), 2)
	assert_eq(opts[0]["label"], "alfa")
	assert_eq(opts[1]["label"], "zeta - Loja Z")
	assert_eq(opts[0]["resource"], s2)

func test_resource_label_without_id_falls_back() -> void:
	assert_eq(Picks.resource_label(null), "(nenhum)")
	assert_eq(Picks.resource_label(ShopDef.new()), "(sem id)")

func test_real_encounters_come_from_the_content_index() -> void:
	var index: ContentIndex = RoteiroTools.scan_content()
	assert_gt(index.ids(&"encounter").size(), 0)

# --- valor atual e invalidez ---

func test_choices_for_a_valid_value() -> void:
	var c: Dictionary = Picks.choices(["a", "b"] as Array[String], "b")
	assert_eq(c["values"], ["", "a", "b"] as Array[String])
	assert_eq(c["index"], 2)
	assert_false(c["invalid"])

func test_choices_for_an_empty_value_select_none() -> void:
	var c: Dictionary = Picks.choices(["a"] as Array[String], "")
	assert_eq(c["index"], 0)
	assert_false(c["invalid"])

func test_choices_keep_an_invalid_value_visible_and_marked() -> void:
	var c: Dictionary = Picks.choices(["a", "b"] as Array[String], "velho")
	assert_true(c["invalid"])
	assert_eq(c["values"], ["", "velho", "a", "b"] as Array[String])
	assert_eq(c["index"], 1)
	assert_eq(Picks.choice_label("velho", true, true), "velho (inválido)")
	assert_eq(Picks.choice_label("a", true, false), "a")
	assert_eq(Picks.choice_label("", true, false), "(nenhum)")

func test_map_problems() -> void:
	var reg: MapRegistry = Game.default_registry()
	assert_eq(Picks.map_problem(reg, "dungeon_1"), "")
	assert_string_contains(Picks.map_problem(reg, "sumiu"), "registro")
	assert_eq(Picks.map_problem(reg, ""), "sem destino")

func test_spawn_problems() -> void:
	var reg: MapRegistry = Game.default_registry()
	assert_eq(Picks.spawn_problem(reg, "dungeon_1", "Entry"), "")
	assert_string_contains(Picks.spawn_problem(reg, "dungeon_1", "Nada"), "marcador")
	assert_eq(Picks.spawn_problem(reg, "dungeon_1", ""), "sem ponto de entrada")
	assert_eq(Picks.spawn_problem(reg, "", "Nada"), "", "sem mapa não há o que conferir")
	assert_eq(Picks.spawn_problem(reg, "sumiu", "Nada"), "")

func test_event_problems() -> void:
	var book := RoteiroBook.new()
	book.events[&"a"] = EventScript.new()
	assert_eq(Picks.event_problem(book, "a"), "")
	assert_string_contains(Picks.event_problem(book, "b"), "não tem")
	assert_string_contains(Picks.event_problem(null, "a"), "precisa")
	assert_eq(Picks.event_problem(null, ""), "")

func test_resource_for_key_ignores_anything_that_is_not_an_existing_res_path() -> void:
	assert_null(Picks.resource_for_key(""), "vazio limpa")
	assert_not_null(Picks.resource_for_key("res://data/maps/cidade.tres"))
	for bad: String in ["(embutido)", "res://nao/existe.tres", "user://x.tres", "cidade"]:
		assert_eq(Picks.resource_for_key(bad), Picks.NO_CHANGE, bad)

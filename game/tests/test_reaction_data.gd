extends GutTest
## M14 Task 3: a matriz das 28 reacoes em dados (data/reactions). Numeros de teste.

const TABLE_PATH := "res://data/reactions/tabela.tres"
const ELEMENT_DIR := "res://data/elements/"
const STATUS_DIR := "res://data/test/statuses/"

var table: ReactionTable
var elements: Array[ElementDef] = []

func before_all() -> void:
	table = load(TABLE_PATH) as ReactionTable
	for f: String in DirAccess.get_files_at(ELEMENT_DIR):
		if f.ends_with(".tres"):
			elements.append(load(ELEMENT_DIR + f) as ElementDef)

func _r(id: StringName) -> ReactionDef:
	for d: ReactionDef in table.reactions:
		if d.id == id:
			return d
	return null

func _ids(arr: Array[StatusDef]) -> Array:
	var out: Array = []
	for s: StatusDef in arr:
		out.append(s.id)
	return out

func _pair(d: ReactionDef, x: StringName, y: StringName) -> bool:
	return (d.a.id == x and d.b.id == y) or (d.a.id == y and d.b.id == x)

func test_table_loads_with_28() -> void:
	assert_not_null(table)
	assert_eq(table.reactions.size(), 28)

func test_validator_has_no_errors() -> void:
	assert_eq(elements.size(), 9)
	assert_eq(ReactionRules.errors(table, elements), [] as Array[String])

func test_every_pair_once_and_no_radioactive() -> void:
	var reacting: Array[ElementDef] = []
	for e: ElementDef in elements:
		if e.reacts:
			reacting.append(e)
	assert_eq(reacting.size(), 8)
	for i: int in reacting.size():
		for j: int in range(i + 1, reacting.size()):
			var n: int = 0
			for d: ReactionDef in table.reactions:
				if _pair(d, reacting[i].id, reacting[j].id):
					n += 1
			assert_eq(n, 1, "par %s + %s" % [reacting[i].id, reacting[j].id])
	for d: ReactionDef in table.reactions:
		assert_ne(d.a.id, &"radioativo")
		assert_ne(d.b.id, &"radioativo")

func test_ids_and_names_unique_and_files_exist() -> void:
	var ids: Dictionary = {}
	var names: Dictionary = {}
	for d: ReactionDef in table.reactions:
		assert_false(ids.has(d.id), "id repetido %s" % d.id)
		assert_false(names.has(d.display_name), "nome repetido %s" % d.display_name)
		ids[d.id] = true
		names[d.display_name] = true
		assert_ne(d.display_name, "")
		assert_true(ResourceLoader.exists("res://data/reactions/%s.tres" % d.id), "arquivo de %s" % d.id)

func test_referenced_statuses_exist() -> void:
	var known: Dictionary = {}
	for f: String in DirAccess.get_files_at(STATUS_DIR):
		if f.ends_with(".tres"):
			known[(load(STATUS_DIR + f) as StatusDef).id] = true
	for d: ReactionDef in table.reactions:
		for list: Array[StatusDef] in [d.target_statuses, d.area_statuses, d.attacker_statuses, d.remove_target_statuses]:
			for s: StatusDef in list:
				assert_true(s != null and known.has(s.id), "estado de %s existe" % d.id)
		if d.area_pct > 0.0:
			assert_gt(d.area_radius, 0.0, "area com raio em %s" % d.id)
		if not d.target_statuses.is_empty() or not d.area_statuses.is_empty():
			assert_gt(d.status_chance, 0.0)

func test_vapor() -> void:
	var d: ReactionDef = _r(&"vapor")
	assert_eq(d.display_name, "Vapor")
	assert_true(_pair(d, &"kagutsuchi", &"susanoo"))
	assert_null(d.keep)
	assert_almost_eq(d.bonus_pct, 0.5, 0.0001)
	assert_eq(_ids(d.target_statuses), [&"blind"])
	assert_almost_eq(d.status_chance, 0.5, 0.0001)
	assert_eq(d.area_pct, 0.0)
	assert_eq(d.target_atb, 0.0)
	assert_true(d.area_statuses.is_empty() and d.attacker_statuses.is_empty() and d.remove_target_statuses.is_empty())

func test_sobrecarga() -> void:
	var d: ReactionDef = _r(&"sobrecarga")
	assert_eq(d.display_name, "Sobrecarga")
	assert_true(_pair(d, &"kagutsuchi", &"indra"))
	assert_null(d.keep)
	assert_almost_eq(d.bonus_pct, 0.3, 0.0001)
	assert_almost_eq(d.area_pct, 0.5, 0.0001)
	assert_almost_eq(d.area_radius, 200.0, 0.0001)
	assert_almost_eq(d.target_atb, -0.25, 0.0001)
	assert_eq(d.attacker_atb, 0.0)
	assert_true(d.target_statuses.is_empty())

func test_tempestade() -> void:
	var d: ReactionDef = _r(&"tempestade")
	assert_eq(d.display_name, "Tempestade")
	assert_true(_pair(d, &"susanoo", &"fuhaku"))
	assert_null(d.keep)
	assert_eq(d.bonus_pct, 0.0)
	assert_almost_eq(d.area_pct, 0.3, 0.0001)
	assert_almost_eq(d.area_radius, 300.0, 0.0001)
	assert_almost_eq(d.target_atb, -0.15, 0.0001)
	assert_eq(d.attacker_atb, 0.0)

func test_fragmentar() -> void:
	var d: ReactionDef = _r(&"fragmentar")
	assert_eq(d.display_name, "Fragmentar")
	assert_true(_pair(d, &"atlas", &"indra"))
	assert_null(d.keep)
	assert_almost_eq(d.bonus_pct, 0.6, 0.0001)
	assert_eq(_ids(d.remove_target_statuses), [&"barrier"])
	assert_true(d.target_statuses.is_empty())

func test_transfusao() -> void:
	var d: ReactionDef = _r(&"transfusao")
	assert_eq(d.display_name, "Transfusão")
	assert_true(_pair(d, &"amaterasu", &"shukketsu"))
	assert_null(d.keep)
	assert_almost_eq(d.heal_attacker_pct, 0.5, 0.0001)
	assert_eq(d.heal_allies_pct, 0.0)
	assert_eq(d.bonus_pct, 0.0)

func test_keep_and_special_rows() -> void:
	assert_eq(_r(&"incendio").keep.id, &"kagutsuchi")
	assert_eq(_r(&"maldicao").keep.id, &"tsukuyomi")
	assert_eq(_ids(_r(&"maldicao").target_statuses), [&"poison", &"str_down"])
	assert_almost_eq(_r(&"maldicao").status_chance, 0.7, 0.0001)
	assert_eq(_ids(_r(&"tempestade_areia").area_statuses), [&"blind"])
	assert_eq(_ids(_r(&"bencao_do_vento").attacker_statuses), [&"haste"])
	assert_almost_eq(_r(&"bencao_do_vento").attacker_atb, 0.3, 0.0001)
	assert_eq(_ids(_r(&"cristalizar").attacker_statuses), [&"barrier"])
	assert_almost_eq(_r(&"arco_iris").heal_allies_pct, 0.2, 0.0001)
	assert_eq(_ids(_r(&"chama_negra").target_statuses), [&"burn"])
	assert_eq(_ids(_r(&"sepultura").target_statuses), [&"petrify"])

extends GutTest

## Página Equipar do menu de campo e bloco de equipamento no Status.

const SCENE: PackedScene = preload("res://ui/field_menu/field_menu.tscn")

var g: GameState
var menu: FieldMenu
var page: EquipPage
var sword: EquipmentDef
var big_sword: EquipmentDef
var staff: EquipmentDef
var vest: EquipmentDef
var amulet: EquipmentDef
var sleep: StatusDef

func _eq(id: StringName, label: String, slot: StringName, mods: Stats) -> EquipmentDef:
	var e := EquipmentDef.new()
	e.id = id
	e.display_name = label
	e.slot = slot
	e.modifiers = mods
	return e

func before_each() -> void:
	sleep = Fixtures.status_def(StatusDef.Kind.SLEEP, 2)
	sleep.id = &"sleep"
	sword = _eq(&"espada", "Espada", &"weapon", Stats.make(2, 0, 0, 0))
	sword.weapon_type = &"blade"
	big_sword = _eq(&"montante", "Montante", &"weapon", Stats.make(4, -1, 0, 0))
	big_sword.weapon_type = &"blade"
	staff = _eq(&"cajado", "Cajado", &"weapon", Stats.make(0, 0, 0, 3))
	staff.weapon_type = &"staff"
	vest = _eq(&"colete", "Colete", &"armor", Stats.make(0, 0, 2, 0))
	amulet = _eq(&"amuleto", "Amuleto", &"accessory", Stats.make(0, 0, 0, 0))
	var p := EquipmentPassive.new()
	p.kind = EquipmentPassive.Kind.IMMUNE
	p.status = sleep
	amulet.passives = [p]
	var defs: Array[CharacterDef] = []
	for id: StringName in [&"Alfa", &"Bravo"]:
		var d: CharacterDef = Fixtures.hero_def(id, Stats.make(3, 3, 3, 3))
		d.weapon_types = [&"blade"] as Array[StringName]
		defs.append(d)
	var bag: Array[EquipmentDef] = [sword, big_sword, staff, amulet]
	var counts: Array[int] = [2, 1, 1, 1]
	g = GameState.new_game(Fixtures.cfg(), defs, [] as Array[ItemDef], [] as Array[int], ScriptedDice.new(),
			&"overworld", &"Start", 4, bag, counts)
	menu = SCENE.instantiate() as FieldMenu
	add_child_autofree(menu)
	menu.open(g)
	page = menu.equip_page

func _open_for_first_hero() -> void:
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"equip")
	menu.accept()
	page.accept()

func _entries() -> Array[String]:
	var out: Array[String] = []
	for s: String in page.entries():
		out.append(s)
	return out

func test_equip_command_present_between_techniques_and_status() -> void:
	var labels: PackedStringArray = menu.command_labels()
	var i: int = labels.find("Equipar")
	assert_gt(i, -1)
	assert_eq(labels[i - 1], "Técnicas")
	assert_eq(labels[i + 1], "Status")
	assert_eq(FieldMenu.COMMAND_PAGES[i], &"equip")
	menu.cursor = i
	menu.accept()
	assert_eq(menu.page, &"equip")
	assert_eq(page.message(), "Equipar quem?")
	assert_true(menu.party_panel.picking)

func test_slot_list_shows_current_items() -> void:
	g.heroes[0].equipment[&"armor"] = vest
	_open_for_first_hero()
	assert_eq(page.hero, g.heroes[0])
	assert_false(menu.party_panel.picking)
	assert_eq(_entries(), ["Arma: —", "Armadura: Colete", "Capacete: —", "Acessório: —"] as Array[String])

func test_only_usable_items_listed() -> void:
	_open_for_first_hero()
	page.cursor = 0
	page.accept()
	assert_eq(page.slot, &"weapon")
	assert_eq(_entries(), ["Espada x2", "Montante x1"] as Array[String])
	# Capacete: nada na mochila e vazio → fica nos espaços com aviso.
	page.cancel()
	page.cursor = 2
	page.accept()
	assert_eq(page.slot, &"")
	assert_eq(page.message(), "Nada para equipar aqui.")
	assert_eq(_entries()[0], "Arma: —")

func test_preview_lines_show_before_after() -> void:
	_open_for_first_hero()
	page.cursor = 0
	page.accept()
	var p: Dictionary = EquipmentRules.preview(g.heroes[0], &"weapon", sword, g.cfg)
	var lines: PackedStringArray = page.preview_lines()
	assert_eq(lines[0], "Força %d → %d" % [p[&"strength"][0], p[&"strength"][1]])
	assert_eq(page.preview_color(0), EquipPage.UP_COLOR)
	assert_eq(lines[1], "Velocidade %d → %d" % [p[&"speed"][0], p[&"speed"][1]])
	assert_eq(page.preview_color(1), FieldPage.TEXT_COLOR)
	assert_true(lines.has("HP máx. %d → %d" % [p[&"hp_max"][0], p[&"hp_max"][1]]))
	assert_true(lines.has("AP máx. %d → %d" % [p[&"ap_max"][0], p[&"ap_max"][1]]))
	assert_true(lines.has("Tipo: Lâmina"))
	assert_eq(lines[lines.size() - 1], "Passivos: —")
	# Mover o cursor atualiza a prévia: Montante reduz Velocidade (vermelho).
	page.move(1)
	var p2: Dictionary = EquipmentRules.preview(g.heroes[0], &"weapon", big_sword, g.cfg)
	assert_eq(page.preview_lines()[1], "Velocidade %d → %d" % [p2[&"speed"][0], p2[&"speed"][1]])
	assert_eq(page.preview_color(1), EquipPage.DOWN_COLOR)
	# Acessório com passivo.
	page.cancel()
	page.cursor = 3
	page.accept()
	var l2: PackedStringArray = page.preview_lines()
	assert_eq(l2[l2.size() - 1], "Passivos: Imune a Sono")

func test_confirm_equips_and_returns_old_to_bag() -> void:
	_open_for_first_hero()
	page.cursor = 0
	page.accept()
	page.accept()
	assert_eq(g.heroes[0].equipment[&"weapon"], sword)
	assert_eq(g.bag.count(&"espada"), 1)
	assert_eq(page.slot, &"")
	assert_eq(page.cursor, 0)
	assert_eq(_entries()[0], "Arma: Espada")
	assert_eq(page.preview_lines().size(), 0)
	# Troca: Montante entra, Espada volta à mochila.
	page.accept()
	page.cursor = 1
	assert_eq(_entries()[1], "Montante x1")
	page.accept()
	assert_eq(g.heroes[0].equipment[&"weapon"], big_sword)
	assert_eq(g.bag.count(&"espada"), 2)
	assert_eq(g.bag.count(&"montante"), 0)
	assert_eq(_entries()[0], "Arma: Montante")

func test_remove_option_only_when_occupied() -> void:
	_open_for_first_hero()
	page.cursor = 0
	page.accept()
	assert_false(_entries().has(EquipPage.REMOVE_TEXT))
	page.accept()
	page.accept()
	assert_eq(_entries()[_entries().size() - 1], EquipPage.REMOVE_TEXT)
	page.cursor = _entries().size() - 1
	page.move(0)
	assert_true(page.preview_lines()[0].begins_with("Força"))
	page.accept()
	assert_false(g.heroes[0].equipment.has(&"weapon"))
	assert_eq(g.bag.count(&"espada"), 2)
	assert_eq(_entries()[0], "Arma: —")
	# Armadura ocupada e nada na mochila: só "Remover".
	g.heroes[0].equipment[&"armor"] = vest
	page.cancel()
	page.accept()
	page.cursor = 1
	page.accept()
	assert_eq(_entries(), [EquipPage.REMOVE_TEXT] as Array[String])

func test_cancel_goes_back_one_step_each_level() -> void:
	_open_for_first_hero()
	page.cursor = 3
	page.accept()
	assert_eq(page.slot, &"accessory")
	menu.cancel()
	assert_eq(menu.page, &"equip")
	assert_eq(page.slot, &"")
	assert_eq(page.cursor, 3)
	assert_eq(_entries()[3], "Acessório: —")
	menu.cancel()
	assert_eq(menu.page, &"equip")
	assert_null(page.hero)
	assert_true(menu.party_panel.picking)
	assert_eq(page.message(), "Equipar quem?")
	menu.cancel()
	assert_eq(menu.page, &"root")
	assert_false(menu.party_panel.picking)

func test_status_shows_equipment_and_passives() -> void:
	g.heroes[0].equipment[&"weapon"] = sword
	g.heroes[0].equipment[&"accessory"] = amulet
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"status")
	menu.accept()
	menu.status_page.accept()
	var t: String = menu.status_page.detail_text()
	assert_string_contains(t, "Equipamento:")
	assert_string_contains(t, "Arma: Espada")
	assert_string_contains(t, "Armadura: —")
	assert_string_contains(t, "Capacete: —")
	assert_string_contains(t, "Acessório: Amuleto")
	assert_string_contains(t, "Passivos: Imune a Sono")

func test_status_attribute_line_includes_equipment() -> void:
	g.heroes[0].equipment[&"weapon"] = sword
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"status")
	menu.accept()
	menu.status_page.accept()
	var c: Combatant = Combatant.from_hero(g.heroes[0], Vector2.ZERO)
	var eff: int = StatCalculator.effective(c, &"strength", g.cfg)
	var lines: PackedStringArray = menu.status_page.detail_text().split("
")
	var expected: String = "Força: 3 + 0 + 2 = %d" % eff
	if eff != 5:
		expected += " (retornos decrescentes)"
	assert_true(lines.has(expected), "%s em %s" % [expected, lines])
	assert_true(lines.has("Velocidade: 3 + 0 = %d" % StatCalculator.effective(c, &"speed", g.cfg)))

func test_passives_line_resist_and_start() -> void:
	var poison: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 2)
	poison.id = &"veneno"
	var haste: StatusDef = Fixtures.status_def(StatusDef.Kind.HASTE, 2)
	haste.id = &"haste"
	var r := EquipmentPassive.new()
	r.kind = EquipmentPassive.Kind.RESIST
	r.status = poison
	r.amount = 0.5
	var s := EquipmentPassive.new()
	s.kind = EquipmentPassive.Kind.START_WITH
	s.status = haste
	var e: EquipmentDef = _eq(&"x", "X", &"accessory", Stats.make(0, 0, 0, 0))
	e.passives = [r, s]
	var eq: Dictionary[StringName, EquipmentDef] = {&"accessory": e}
	assert_eq(EquipPage.passives_line(eq), "Passivos: Resiste a Veneno 50%, Começa com Pressa")

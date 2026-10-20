extends GutTest

## Aviso "aprendeu X!" na tela de resultado e a linha "Próxima" na página de técnicas.

func _ab(id: StringName, label: String) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(1.0)
	a.id = id
	a.display_name = label
	return a

func _hero(name: String, entries: Array) -> HeroState:
	var d: CharacterDef = Fixtures.hero_def(StringName(name), Stats.make(5, 5, 5, 5))
	d.display_name = name
	var ls: Array[LearnEntry] = []
	for e: Array in entries:
		var le := LearnEntry.new()
		le.ability = _ab(e[0], e[1])
		le.level = e[2]
		ls.append(le)
	d.learnset = ls
	return HeroState.create(d, Fixtures.cfg())

func test_result_announces_only_who_learned() -> void:
	var cfg := Fixtures.cfg()
	var a := _hero("Ana", [[&"x1", "Corte", 1], [&"x2", "Fogo", 2]])
	var b := _hero("Beto", [[&"y1", "Cura", 1], [&"y2", "Raio", 9]])
	XpCalculator.grant(a, XpCalculator.xp_for_level(2, cfg), cfg)
	XpCalculator.grant(b, 1, cfg)
	var r := ResultScreen.new()
	add_child_autofree(r)
	var xp: Dictionary[StringName, int] = {a.def.id: 10, b.def.id: 1}
	var hs: Array[HeroState] = [a, b]
	r.show_for(xp, {a.def.id: 1, b.def.id: 1}, hs)
	var lines: PackedStringArray = r.lines()
	assert_true("Ana aprendeu Fogo!" in lines)
	assert_false("Beto aprendeu Raio!" in lines)
	assert_eq(lines.size(), 4, "titulo + 2 XP + 1 aviso")

func test_technique_page_lists_next_gray_line() -> void:
	var h := _hero("Ana", [[&"c1", "Cura", 1], [&"c2", "Cura Maior", 6]])
	var ab: AbilityDef = h.abilities()[0]
	ab.side = AbilityDef.Side.ALLIES
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.HEAL
	e.scale = EffectDef.Scale.AURA
	e.potency = 1.0
	ab.effects = [e]
	var d2: CharacterDef = Fixtures.hero_def(&"o", Stats.make(5, 5, 5, 5))
	var defs: Array[CharacterDef] = [h.def, d2]
	var g := GameState.new_game(Fixtures.cfg(), defs, [] as Array[ItemDef], [] as Array[int], ScriptedDice.new(), &"overworld", &"Start")
	var menu: FieldMenu = (load("res://ui/field_menu/field_menu.tscn") as PackedScene).instantiate() as FieldMenu
	add_child_autofree(menu)
	menu.open(g)
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"techniques")
	menu.accept()
	var page: TechniquePage = menu.technique_page
	page.accept()
	assert_eq(page.entries(), PackedStringArray(["Cura — 0 AP", "Próxima: Nv 6"]))
	assert_false(page.entry_enabled(1))

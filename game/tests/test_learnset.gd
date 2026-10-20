extends GutTest

var cfg: BalanceConfig

func before_each() -> void:
	cfg = Fixtures.cfg()

func _ab(id: StringName) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(1.0)
	a.id = id
	a.display_name = String(id)
	return a

func _entry(id: StringName, lv: int) -> LearnEntry:
	var e := LearnEntry.new()
	e.ability = _ab(id)
	e.level = lv
	return e

func _def() -> CharacterDef:
	var d: CharacterDef = Fixtures.hero_def(&"h", Stats.make(5, 5, 5, 5))
	d.learnset = [_entry(&"a1", 1), _entry(&"a3", 3), _entry(&"a6", 6), _entry(&"ev", 0)]
	return d

func test_level_one_learns_only_level_one() -> void:
	var h := HeroState.create(_def(), cfg)
	assert_eq(h.learned, [&"a1"] as Array[StringName])
	assert_eq(h.abilities().size(), 1)
	assert_eq(Combatant.from_hero(h, Vector2.ZERO).abilities.size(), 1)

func test_multi_level_jump_learns_middle_in_order() -> void:
	var h := HeroState.create(_def(), cfg)
	XpCalculator.grant(h, XpCalculator.xp_for_level(7, cfg), cfg)
	assert_eq(h.level, 7)
	assert_eq(h.learned, [&"a1", &"a3", &"a6"] as Array[StringName])
	assert_eq(h.last_learned.size(), 2)
	assert_eq(h.last_learned[0].id, &"a3")
	assert_eq(h.last_learned[1].id, &"a6")

func test_grant_without_new_level_learns_nothing_twice() -> void:
	var h := HeroState.create(_def(), cfg)
	XpCalculator.grant(h, XpCalculator.xp_for_level(3, cfg), cfg)
	XpCalculator.grant(h, 1, cfg)
	assert_eq(h.learned.size(), 2)
	assert_true(h.last_learned.is_empty())

func test_event_entry_not_learned_by_level() -> void:
	var h := HeroState.create(_def(), cfg)
	XpCalculator.grant(h, XpCalculator.xp_for_level(20, cfg), cfg)
	assert_false(h.learned.has(&"ev"))

func test_learn_event_idempotent_and_rejects_foreign() -> void:
	var h := HeroState.create(_def(), cfg)
	assert_true(h.learn(&"ev"))
	assert_false(h.learn(&"ev"))
	assert_false(h.learn(&"nope"))
	assert_eq(h.learned, [&"a1", &"ev"] as Array[StringName])
	assert_false(h.learn(&"a1"))

func test_learn_keeps_learnset_order() -> void:
	var h := HeroState.create(_def(), cfg)
	h.learn(&"ev")
	XpCalculator.grant(h, XpCalculator.xp_for_level(3, cfg), cfg)
	assert_eq(h.learned, [&"a1", &"a3", &"ev"] as Array[StringName])

func test_next_learn() -> void:
	var h := HeroState.create(_def(), cfg)
	assert_eq(h.next_learn().level, 3)
	XpCalculator.grant(h, XpCalculator.xp_for_level(6, cfg), cfg)
	assert_null(h.next_learn())

func test_snapshot_restore_roundtrip() -> void:
	var h := HeroState.create(_def(), cfg)
	var snap: Dictionary = h.snapshot()
	XpCalculator.grant(h, XpCalculator.xp_for_level(6, cfg), cfg)
	h.learn(&"ev")
	h.restore(snap)
	assert_eq(h.learned, [&"a1"] as Array[StringName])
	assert_eq(h.level, 1)

func test_real_content_save_roundtrip_and_old_save() -> void:
	var cd: CharacterDef = load("res://data/test/heroes/teste_b.tres") as CharacterDef
	var reg := DefRegistry.create([cd] as Array[CharacterDef], [] as Array[ItemDef], cd.starting_equipment)
	var h := HeroState.create(cd, cfg)
	XpCalculator.grant(h, XpCalculator.xp_for_level(10, cfg), cfg)
	h.learn(&"tempestade")
	var d: Dictionary = h.to_dict()
	var back: HeroState = HeroState.from_dict(d, reg)
	assert_not_null(back)
	assert_eq(back.learned, h.learned)
	d.erase("learned")
	var old: HeroState = HeroState.from_dict(d, reg)
	assert_eq(old.learned, [&"cura", &"barreira", &"pressa", &"sono"] as Array[StringName])

func test_every_hero_starts_with_exactly_one() -> void:
	for id: String in ["a", "b", "c", "d", "e"]:
		var h := HeroState.create(load("res://data/test/heroes/teste_%s.tres" % id) as CharacterDef, cfg)
		assert_eq(h.learned.size(), 1, id)

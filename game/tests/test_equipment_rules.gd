extends GutTest

func _eq(id: StringName, slot: StringName, mods: Stats = null) -> EquipmentDef:
	var e := EquipmentDef.new()
	e.id = id
	e.display_name = String(id)
	e.slot = slot
	e.modifiers = mods if mods != null else Stats.make(0, 0, 0, 0)
	return e

func _weapon(id: StringName, type: StringName) -> EquipmentDef:
	var e: EquipmentDef = _eq(id, &"weapon")
	e.weapon_type = type
	return e

func _passive(kind: EquipmentPassive.Kind, st: StatusDef, amount: float = 0.0) -> EquipmentPassive:
	var p := EquipmentPassive.new()
	p.kind = kind
	p.status = st
	p.amount = amount
	return p

func _hero(id: StringName = &"h") -> HeroState:
	var d: CharacterDef = Fixtures.hero_def(id, Stats.make(5, 5, 5, 5))
	d.weapon_types = [&"blade"] as Array[StringName]
	return HeroState.create(d, Fixtures.cfg())

func test_weapon_type_restriction() -> void:
	var d: CharacterDef = _hero().def
	assert_true(EquipmentRules.can_equip(d, _weapon(&"s", &"blade"), &"weapon"))
	assert_false(EquipmentRules.can_equip(d, _weapon(&"t", &"staff"), &"weapon"))
	assert_true(EquipmentRules.can_equip(d, _weapon(&"u", &""), &"weapon"))
	assert_false(EquipmentRules.can_equip(d, _eq(&"a", &"armor"), &"weapon"))

func test_hero_without_weapon_types_uses_no_typed_weapon() -> void:
	var d: CharacterDef = Fixtures.hero_def(&"x", Stats.make(1, 1, 1, 1))
	assert_false(EquipmentRules.can_equip(d, _weapon(&"s", &"blade"), &"weapon"))

func test_allowed_ids_restriction() -> void:
	var d: CharacterDef = _hero(&"h").def
	var open: EquipmentDef = _eq(&"a", &"armor")
	assert_true(EquipmentRules.can_equip(d, open, &"armor"))
	var excl: EquipmentDef = _eq(&"c", &"helmet")
	excl.allowed_ids = [&"other"] as Array[StringName]
	assert_false(EquipmentRules.can_equip(d, excl, &"helmet"))
	excl.allowed_ids = [&"other", &"h"] as Array[StringName]
	assert_true(EquipmentRules.can_equip(d, excl, &"helmet"))
	assert_false(EquipmentRules.can_equip(d, excl, &"armor"), "slot diferente")

func test_accessory_always() -> void:
	var d: CharacterDef = Fixtures.hero_def(&"x", Stats.make(1, 1, 1, 1))
	assert_true(EquipmentRules.can_equip(d, _eq(&"r", &"accessory"), &"accessory"))

func test_null_and_slots() -> void:
	var d: CharacterDef = _hero().def
	assert_false(EquipmentRules.can_equip(d, null, &"armor"))
	for s: StringName in EquipmentRules.SLOTS:
		assert_true(EquipmentRules.SLOT_LABELS.has(s), String(s))

func test_passives_aggregate_and_cap() -> void:
	var poison: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 3, 2)
	var sleep: StatusDef = Fixtures.status_def(StatusDef.Kind.SLEEP, 2)
	var haste: StatusDef = Fixtures.status_def(StatusDef.Kind.HASTE, 3, 50)
	var a: EquipmentDef = _eq(&"a", &"armor")
	a.passives = [_passive(EquipmentPassive.Kind.RESIST, poison, 0.6)] as Array[EquipmentPassive]
	var b: EquipmentDef = _eq(&"b", &"helmet")
	b.passives = [_passive(EquipmentPassive.Kind.RESIST, poison, 0.6),
		_passive(EquipmentPassive.Kind.IMMUNE, sleep)] as Array[EquipmentPassive]
	var c: EquipmentDef = _eq(&"c", &"accessory")
	c.passives = [_passive(EquipmentPassive.Kind.START_WITH, haste)] as Array[EquipmentPassive]
	var eq: Dictionary[StringName, EquipmentDef] = {&"armor": a, &"helmet": b, &"accessory": c}
	assert_eq(EquipmentRules.resistances(eq).get(&"poison", 0.0), 1.0)
	assert_true(EquipmentRules.immunities(eq).has(&"poison"))
	assert_true(EquipmentRules.immunities(eq).has(&"sleep"))
	assert_eq(EquipmentRules.immunities(eq).size(), 2)
	assert_false(EquipmentRules.resistances(eq).has(&"sleep"), "imune nao e resistencia")
	assert_eq(EquipmentRules.start_statuses(eq).size(), 1)

func test_resist_below_one_is_not_immunity() -> void:
	var poison: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 3, 2)
	var a: EquipmentDef = _eq(&"a", &"armor")
	a.passives = [_passive(EquipmentPassive.Kind.RESIST, poison, 0.5)] as Array[EquipmentPassive]
	var eq: Dictionary[StringName, EquipmentDef] = {&"armor": a}
	assert_eq(EquipmentRules.resistances(eq).get(&"poison", 0.0), 0.5)
	assert_true(EquipmentRules.immunities(eq).is_empty())

func test_start_statuses_dedup() -> void:
	var haste: StatusDef = Fixtures.status_def(StatusDef.Kind.HASTE, 3, 50)
	var a: EquipmentDef = _eq(&"a", &"armor")
	a.passives = [_passive(EquipmentPassive.Kind.START_WITH, haste)] as Array[EquipmentPassive]
	var b: EquipmentDef = _eq(&"b", &"accessory")
	b.passives = [_passive(EquipmentPassive.Kind.START_WITH, haste)] as Array[EquipmentPassive]
	var eq: Dictionary[StringName, EquipmentDef] = {&"armor": a, &"accessory": b}
	assert_eq(EquipmentRules.start_statuses(eq).size(), 1)
	assert_true(EquipmentRules.immunities({} as Dictionary[StringName, EquipmentDef]).is_empty())

func test_preview_matches_battle_combatant() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: HeroState = _hero()
	var heavy: EquipmentDef = _eq(&"heavy", &"armor", Stats.make(0, -2, 4, 3))
	var p: Dictionary = EquipmentRules.preview(h, &"armor", heavy, cfg)
	var eq: Dictionary[StringName, EquipmentDef] = h.equipment.duplicate()
	eq[&"armor"] = heavy
	h.equipment = eq
	var c: Combatant = Combatant.from_hero(h, Vector2.ZERO)
	assert_eq(p[&"strength"][1], StatCalculator.effective(c, &"strength", cfg))
	assert_eq(p[&"speed"][1], StatCalculator.effective(c, &"speed", cfg))
	assert_eq(p[&"vitality"][1], StatCalculator.effective(c, &"vitality", cfg))
	assert_eq(p[&"aura"][1], StatCalculator.effective(c, &"aura", cfg))
	assert_eq(p[&"hp_max"][1], StatCalculator.hp_max(c, cfg))
	assert_eq(p[&"ap_max"][1], StatCalculator.ap_max(c, cfg))
	assert_eq(p[&"speed"][0], 5)
	assert_eq(p[&"vitality"][1], 9)

func test_preview_does_not_mutate_hero() -> void:
	var h: HeroState = _hero()
	var old: EquipmentDef = _eq(&"old", &"armor", Stats.make(1, 0, 0, 0))
	h.equipment[&"armor"] = old
	EquipmentRules.preview(h, &"armor", _eq(&"n", &"armor", Stats.make(9, 0, 0, 0)), Fixtures.cfg())
	EquipmentRules.preview(h, &"armor", null, Fixtures.cfg())
	assert_eq(h.equipment.size(), 1)
	assert_eq(h.equipment[&"armor"], old)

func test_preview_remove() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: HeroState = _hero()
	h.equipment[&"armor"] = _eq(&"a", &"armor", Stats.make(0, 0, 3, 0))
	var p: Dictionary = EquipmentRules.preview(h, &"armor", null, cfg)
	assert_eq(p[&"vitality"], [8, 5])
	assert_eq(p[&"hp_max"][0] - p[&"hp_max"][1], 3 * cfg.hp_per_vitality)

func test_preview_replace_same_slot_not_added() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: HeroState = _hero()
	h.equipment[&"armor"] = _eq(&"a", &"armor", Stats.make(0, 0, 3, 0))
	var p: Dictionary = EquipmentRules.preview(h, &"armor", _eq(&"b", &"armor", Stats.make(0, 0, 4, 0)), cfg)
	assert_eq(p[&"vitality"], [8, 9])

func test_bag_take_put_and_copy_independent() -> void:
	var bag := EquipmentBag.new()
	var a: EquipmentDef = _eq(&"a", &"armor")
	var b: EquipmentDef = _eq(&"b", &"helmet")
	bag.add(a, 2)
	bag.add(b)
	assert_eq(bag.count(&"a"), 2)
	assert_eq(bag.count(&"zzz"), 0)
	assert_eq(bag.listing(), [a, b] as Array[EquipmentDef])
	var cp: EquipmentBag = bag.copy()
	assert_eq(bag.take(&"a"), a)
	assert_eq(bag.count(&"a"), 1)
	assert_eq(cp.count(&"a"), 2, "copia independente")
	assert_eq(bag.take(&"b"), b)
	assert_null(bag.take(&"b"))
	assert_eq(bag.listing(), [a] as Array[EquipmentDef], "count 0 some da listagem")
	bag.put(b)
	assert_eq(bag.count(&"b"), 1)
	assert_eq(bag.listing(), [a, b] as Array[EquipmentDef], "ordem de insercao preservada")
	cp.put(a)
	assert_eq(cp.count(&"a"), 3)
	assert_eq(bag.count(&"a"), 1)

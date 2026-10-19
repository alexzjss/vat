extends GutTest

func _eq(id: StringName, slot: StringName, mods: Stats = null) -> EquipmentDef:
	var e := EquipmentDef.new()
	e.id = id
	e.display_name = String(id)
	e.slot = slot
	e.modifiers = mods if mods != null else Stats.make(0, 0, 0, 0)
	return e

func _def(id: StringName, start: Array[EquipmentDef] = []) -> CharacterDef:
	var d: CharacterDef = Fixtures.hero_def(id, Stats.make(1, 1, 5, 2))
	d.weapon_types = [&"blade"] as Array[StringName]
	d.starting_equipment = start
	return d

func _game(defs: Array[CharacterDef], bag: Array[EquipmentDef], counts: Array[int], max_active: int = 4) -> GameState:
	var items: Array[ItemDef] = []
	var ic: Array[int] = []
	return GameState.new_game(Fixtures.cfg(), defs, items, ic, ScriptedDice.new(), &"m", &"s", max_active, bag, counts)

func _hp_max(g: GameState, h: HeroState) -> int:
	return StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), g.cfg)

func test_starting_equipment_applied_and_full_hp() -> void:
	var armor: EquipmentDef = _eq(&"vest", &"armor", Stats.make(0, 0, 2, 0))
	var weapon: EquipmentDef = _eq(&"sword", &"weapon", Stats.make(1, 0, 0, 1))
	var d: CharacterDef = _def(&"a", [armor, weapon] as Array[EquipmentDef])
	var h: HeroState = HeroState.create(d, Fixtures.cfg())
	assert_eq(h.equipment[&"armor"], armor)
	assert_eq(h.equipment[&"weapon"], weapon)
	# Vit 7 * 10 + nivel 1 * 5 = 75; Aura 3 * 5 = 15.
	assert_eq(h.hp, 75)
	assert_eq(h.ap, 15)

func test_starting_equipment_invalid_is_ignored() -> void:
	var bad: EquipmentDef = _eq(&"staff", &"weapon")
	bad.weapon_type = &"staff"
	var d: CharacterDef = _def(&"a", [bad] as Array[EquipmentDef])
	var h: HeroState = HeroState.create(d, Fixtures.cfg())
	assert_true(h.equipment.is_empty())
	assert_push_error("equipamento inicial invalido")

func test_equip_swaps_old_back_to_bag() -> void:
	var s1: EquipmentDef = _eq(&"s1", &"weapon", Stats.make(1, 0, 0, 0))
	var s2: EquipmentDef = _eq(&"s2", &"weapon", Stats.make(2, 0, 0, 0))
	var g: GameState = _game([_def(&"a", [s1] as Array[EquipmentDef])], [s2] as Array[EquipmentDef], [1] as Array[int])
	var h: HeroState = g.heroes[0]
	assert_true(g.equip(h, &"weapon", s2))
	assert_eq(h.equipment[&"weapon"], s2)
	assert_eq(g.bag.count(&"s2"), 0)
	assert_eq(g.bag.count(&"s1"), 1)

func test_equip_refuses_and_changes_nothing() -> void:
	var ok: EquipmentDef = _eq(&"ok", &"armor", Stats.make(0, 0, 1, 0))
	var wrong_type: EquipmentDef = _eq(&"wt", &"weapon")
	wrong_type.weapon_type = &"staff"
	var excl: EquipmentDef = _eq(&"ex", &"armor")
	excl.allowed_ids = [&"zzz"] as Array[StringName]
	var stock: EquipmentDef = _eq(&"nostock", &"armor")
	var bag: Array[EquipmentDef] = [ok, wrong_type, excl]
	var g: GameState = _game([_def(&"a")], bag, [1, 1, 1] as Array[int])
	var h: HeroState = g.heroes[0]
	var outsider: HeroState = HeroState.create(_def(&"out"), g.cfg)
	var hp0: int = h.hp
	var ap0: int = h.ap
	assert_false(g.equip(h, &"weapon", wrong_type), "tipo errado")
	assert_false(g.equip(h, &"armor", excl), "allowed_ids")
	assert_false(g.equip(h, &"helmet", ok), "espaco errado")
	assert_false(g.equip(h, &"armor", stock), "sem estoque")
	assert_false(g.equip(outsider, &"armor", ok), "fora do roster")
	assert_true(h.equipment.is_empty())
	assert_true(outsider.equipment.is_empty())
	assert_eq([g.bag.count(&"ok"), g.bag.count(&"wt"), g.bag.count(&"ex"), g.bag.count(&"nostock")], [1, 1, 1, 0])
	assert_eq([h.hp, h.ap], [hp0, ap0])

func test_item_count_is_conserved() -> void:
	var a: EquipmentDef = _eq(&"ring", &"accessory", Stats.make(0, 0, 1, 0))
	var b: EquipmentDef = _eq(&"cape", &"armor", Stats.make(0, 0, 2, 0))
	var bag: Array[EquipmentDef] = [a, b]
	var g: GameState = _game([_def(&"h1"), _def(&"h2", [b] as Array[EquipmentDef])], bag, [2, 1] as Array[int])
	var total: Dictionary = {&"ring": 2, &"cape": 2}
	var h1: HeroState = g.heroes[0]
	var h2: HeroState = g.heroes[1]
	var steps: Array[Callable] = [
		func() -> void: g.equip(h1, &"accessory", a),
		func() -> void: g.equip(h2, &"accessory", a),
		func() -> void: g.equip(h1, &"armor", b),
		func() -> void: g.unequip(h2, &"armor"),
		func() -> void: g.equip(h1, &"armor", b),
		func() -> void: g.unequip(h1, &"accessory"),
		func() -> void: g.unequip(h1, &"accessory"),
		func() -> void: g.equip(h2, &"armor", b),
	]
	for step: Callable in steps:
		step.call()
		for id: StringName in total:
			var n: int = g.bag.count(id)
			for h: HeroState in g.roster():
				for e: EquipmentDef in h.equipment.values():
					if e.id == id:
						n += 1
			assert_eq(n, total[id], "conservacao de %s" % id)

func test_unequip_clamps_current_hp_ap() -> void:
	var armor: EquipmentDef = _eq(&"vest", &"armor", Stats.make(0, 0, 2, 1))
	var g: GameState = _game([_def(&"a", [armor] as Array[EquipmentDef])], [] as Array[EquipmentDef], [] as Array[int])
	var h: HeroState = g.heroes[0]
	assert_eq([h.hp, h.ap], [75, 15])
	assert_true(g.unequip(h, &"armor"))
	# Sem armadura: 55 / 10.
	assert_eq([h.hp, h.ap], [55, 10])
	assert_eq(g.bag.count(&"vest"), 1)
	# Aumentar o maximo nao cura.
	h.hp = 20
	h.ap = 3
	assert_true(g.equip(h, &"armor", armor))
	assert_eq([h.hp, h.ap], [20, 3])
	# Caido fica 0.
	h.hp = 0
	assert_true(g.unequip(h, &"armor"))
	assert_eq(h.hp, 0)
	assert_false(g.unequip(h, &"armor"), "vazio")

func test_reserve_can_be_equipped() -> void:
	var ring: EquipmentDef = _eq(&"ring", &"accessory")
	var g: GameState = _game([_def(&"a"), _def(&"b")], [ring] as Array[EquipmentDef], [1] as Array[int], 1)
	var r: HeroState = g.reserve[0]
	assert_true(g.equip(r, &"accessory", ring))
	assert_eq(r.equipment[&"accessory"], ring)

func test_restore_save_restores_equipment_and_bag() -> void:
	var s1: EquipmentDef = _eq(&"s1", &"weapon", Stats.make(1, 0, 0, 0))
	var s2: EquipmentDef = _eq(&"s2", &"weapon", Stats.make(2, 0, 0, 0))
	var g: GameState = _game([_def(&"a", [s1] as Array[EquipmentDef])], [s2] as Array[EquipmentDef], [1] as Array[int])
	var h: HeroState = g.heroes[0]
	assert_true(g.equip(h, &"weapon", s2))
	assert_true(g.unequip(h, &"weapon"))
	g.restore_save()
	assert_eq(h.equipment[&"weapon"], s1)
	assert_eq([g.bag.count(&"s1"), g.bag.count(&"s2")], [0, 1])
	# Independencia: mexer depois do restore nao corrompe o ponto salvo.
	assert_true(g.equip(h, &"weapon", s2))
	g.restore_save()
	assert_eq(h.equipment[&"weapon"], s1)
	assert_eq([g.bag.count(&"s1"), g.bag.count(&"s2")], [0, 1])

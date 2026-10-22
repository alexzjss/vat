extends GutTest
## M15 Task 3: resistencia a estados por heroi (base + equipamento), imunidade >= 1 e a linha da pagina de Status.

const SCENE: PackedScene = preload("res://ui/field_menu/field_menu.tscn")

var cfg: BalanceConfig
var poison: StatusDef
var sleep: StatusDef

func before_each() -> void:
	cfg = Fixtures.cfg()
	poison = Fixtures.status_def(StatusDef.Kind.POISON, 3, 2)
	poison.id = &"poison"
	sleep = Fixtures.status_def(StatusDef.Kind.SLEEP, 2)
	sleep.id = &"sleep"

func _passive(kind: EquipmentPassive.Kind, st: StatusDef, amount: float = 0.0) -> EquipmentPassive:
	var p := EquipmentPassive.new()
	p.kind = kind
	p.status = st
	p.amount = amount
	return p

func _ring(passives: Array[EquipmentPassive]) -> EquipmentDef:
	var e := EquipmentDef.new()
	e.id = &"ring"
	e.display_name = "Anel"
	e.slot = &"accessory"
	e.modifiers = Stats.make(0, 0, 0, 0)
	e.passives = passives
	return e

func _hero(base: Dictionary[StringName, float], ring: EquipmentDef = null) -> Combatant:
	var d: CharacterDef = Fixtures.hero_def(&"h", Stats.make(10, 10, 5, 1))
	d.status_resist = base
	var hs := HeroState.create(d, cfg)
	if ring != null:
		hs.equipment[&"accessory"] = ring
	return Combatant.from_hero(hs, Vector2.ZERO)

func _apply(c: Combatant, st: StatusDef, rolls: Array[float]) -> StatusSystem.ApplyResult:
	var foe: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(5, 5, 5, 5)), &"x", Vector2(50, 0), cfg)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(rolls), [c], [foe])
	return b.statuses.apply(c, st, foe, 1.0, [foe] as Array[Combatant])

func test_empty_base_changes_nothing() -> void:
	var c: Combatant = _hero({})
	assert_true(c.resistances.is_empty())
	assert_true(c.immunities.is_empty())
	assert_eq(_apply(c, poison, [0.99] as Array[float]), StatusSystem.ApplyResult.APPLIED)

func test_base_only_resists() -> void:
	var c: Combatant = _hero({&"poison": 0.5} as Dictionary[StringName, float])
	assert_almost_eq(float(c.resistances[&"poison"]), 0.5, 0.0001)
	assert_eq(_apply(c, poison, [0.6] as Array[float]), StatusSystem.ApplyResult.RESISTED)
	assert_eq(_apply(c, poison, [0.4] as Array[float]), StatusSystem.ApplyResult.APPLIED)

func test_base_plus_equipment_sum() -> void:
	var ring: EquipmentDef = _ring([_passive(EquipmentPassive.Kind.RESIST, poison, 0.25)] as Array[EquipmentPassive])
	var c: Combatant = _hero({&"poison": 0.5} as Dictionary[StringName, float], ring)
	assert_almost_eq(float(c.resistances[&"poison"]), 0.75, 0.0001)
	assert_eq(_apply(c, poison, [0.2] as Array[float]), StatusSystem.ApplyResult.APPLIED, "0.2 < 0.25")
	assert_false(c.immunities.has(&"poison"))

func test_total_at_least_one_is_immune() -> void:
	var ring: EquipmentDef = _ring([_passive(EquipmentPassive.Kind.RESIST, poison, 0.5)] as Array[EquipmentPassive])
	var c: Combatant = _hero({&"poison": 0.5} as Dictionary[StringName, float], ring)
	assert_true(c.immunities.has(&"poison"))
	assert_eq(_apply(c, poison, [0.0] as Array[float]), StatusSystem.ApplyResult.IMMUNE)
	var only_base: Combatant = _hero({&"sleep": 1.0} as Dictionary[StringName, float])
	assert_true(only_base.immunities.has(&"sleep"))
	assert_eq(_apply(only_base, sleep, [0.0] as Array[float]), StatusSystem.ApplyResult.IMMUNE)

func test_negative_resistance_raises_chance() -> void:
	var c: Combatant = _hero({&"poison": -0.5} as Dictionary[StringName, float])
	assert_almost_eq(float(c.resistances[&"poison"]), -0.5, 0.0001)
	# Chance 0.6 base * 1.5 = 0.9: 0.8 passa, que passaria so com resistencia negativa.
	assert_eq(_apply(c, poison, [0.8] as Array[float]), StatusSystem.ApplyResult.APPLIED)
	var plain: Combatant = _hero({})
	var foe: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(5, 5, 5, 5)), &"x", Vector2(50, 0), cfg)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new([0.8] as Array[float]), [plain], [foe])
	assert_eq(b.statuses.apply(plain, poison, foe, 0.6, [foe] as Array[Combatant]), StatusSystem.ApplyResult.RESISTED)
	var vuln: Combatant = _hero({&"poison": -0.5} as Dictionary[StringName, float])
	var b2: BattleState = BattleState.create(cfg, ScriptedDice.new([0.8] as Array[float]), [vuln], [foe])
	assert_eq(b2.statuses.apply(vuln, poison, foe, 0.6, [foe] as Array[Combatant]), StatusSystem.ApplyResult.APPLIED)

func test_negative_base_is_cancelled_by_equipment() -> void:
	var ring: EquipmentDef = _ring([_passive(EquipmentPassive.Kind.RESIST, poison, 0.5)] as Array[EquipmentPassive])
	var c: Combatant = _hero({&"poison": -0.5} as Dictionary[StringName, float], ring)
	assert_almost_eq(float(c.resistances[&"poison"]), 0.0, 0.0001)

func test_immune_passive_still_works() -> void:
	var ring: EquipmentDef = _ring([_passive(EquipmentPassive.Kind.IMMUNE, sleep)] as Array[EquipmentPassive])
	var c: Combatant = _hero({&"poison": 0.3} as Dictionary[StringName, float], ring)
	assert_true(c.immunities.has(&"sleep"))
	assert_eq(_apply(c, sleep, [0.0] as Array[float]), StatusSystem.ApplyResult.IMMUNE)

func test_enemies_are_unchanged() -> void:
	var d: EnemyDef = Fixtures.enemy_def(&"x", Stats.make(5, 5, 5, 5))
	d.resistances = {&"poison": 0.4} as Dictionary[StringName, float]
	d.immunities = [&"sleep"] as Array[StringName]
	var e: Combatant = Combatant.from_enemy(d, &"x", Vector2.ZERO, cfg)
	assert_almost_eq(float(e.resistances[&"poison"]), 0.4, 0.0001)
	assert_true(e.immunities.has(&"sleep"))

func test_final_chance_is_clamped_to_one() -> void:
	var c: Combatant = _hero({&"poison": -3.0} as Dictionary[StringName, float])
	assert_eq(_apply(c, poison, [0.999] as Array[float]), StatusSystem.ApplyResult.APPLIED)

# --- Pagina de Status ---

func _status_text(base: Dictionary[StringName, float]) -> String:
	var d: CharacterDef = Fixtures.hero_def(&"Alfa", Stats.make(3, 3, 3, 3))
	d.status_resist = base
	var defs: Array[CharacterDef] = [d]
	var g: GameState = GameState.new_game(cfg, defs, [] as Array[ItemDef], [] as Array[int], ScriptedDice.new(),
			&"overworld", &"Start", 4, [] as Array[EquipmentDef], [] as Array[int])
	var menu: FieldMenu = SCENE.instantiate() as FieldMenu
	add_child_autofree(menu)
	menu.open(g)
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"status")
	menu.accept()
	menu.status_page.accept()
	return menu.status_page.detail_text()

func test_status_page_lists_nonzero_entries() -> void:
	var t: String = _status_text({&"poison": 0.3, &"sleep": 1.0, &"slow": 0.0, &"burn": -0.5} as Dictionary[StringName, float])
	assert_string_contains(t, "Resistência a estados: Veneno 30%, Sono imune, Queimadura -50%")
	assert_false(t.contains("Lentidão"), "entrada zero nao aparece")

func test_status_page_has_no_line_when_all_zero() -> void:
	assert_false(_status_text({&"poison": 0.0} as Dictionary[StringName, float]).contains("Resistência a estados"))
	assert_false(_status_text({}).contains("Resistência a estados"))

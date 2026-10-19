extends GutTest

func _passive(kind: EquipmentPassive.Kind, st: StatusDef, amount: float = 0.0) -> EquipmentPassive:
	var p := EquipmentPassive.new()
	p.kind = kind
	p.status = st
	p.amount = amount
	return p

func _accessory(id: StringName, passives: Array[EquipmentPassive], mods: Stats = null) -> EquipmentDef:
	var e := EquipmentDef.new()
	e.id = id
	e.display_name = String(id)
	e.slot = &"accessory"
	e.modifiers = mods if mods != null else Stats.make(0, 0, 0, 0)
	e.passives = passives
	return e

func _hero(acc: EquipmentDef, hp: int = -1) -> HeroState:
	var cfg := Fixtures.cfg()
	var hs := HeroState.create(Fixtures.hero_def(&"h", Stats.make(10, 10, 5, 1)), cfg)
	if acc != null:
		hs.equipment[&"accessory"] = acc
		hs.rest(cfg)
	if hp >= 0:
		hs.hp = hp
	return hs

func _battle(hs: HeroState, dice: Dice = null) -> BattleController:
	var cfg := Fixtures.cfg()
	var heroes: Array[Combatant] = [Combatant.from_hero(hs, Vector2.ZERO)]
	var d := Fixtures.enemy_def(&"x", Stats.make(10, 10, 5, 5))
	var enemies: Array[Combatant] = [Combatant.from_enemy(d, &"x", Vector2.ZERO, cfg)]
	var b := BattleState.create(cfg, dice if dice != null else ScriptedDice.new(), heroes, enemies)
	return BattleController.new(b)

func _src(b: BattleState) -> Combatant:
	return b.enemies[0]

func test_hero_immunity_from_equipment() -> void:
	var poison: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 3, 2)
	var acc: EquipmentDef = _accessory(&"ring", [_passive(EquipmentPassive.Kind.IMMUNE, poison)] as Array[EquipmentPassive])
	var ctrl: BattleController = _battle(_hero(acc), ScriptedDice.new([0.0] as Array[float]))
	var h: Combatant = ctrl.b.heroes[0]
	assert_eq(ctrl.b.statuses.apply(h, poison, _src(ctrl.b), 1.0, ctrl.b.living(ctrl.b.enemies)), StatusSystem.ApplyResult.IMMUNE)
	assert_true(h.statuses.is_empty())

func test_hero_resistance_reduces_chance() -> void:
	var poison: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 3, 2)
	var acc: EquipmentDef = _accessory(&"ring", [_passive(EquipmentPassive.Kind.RESIST, poison, 0.5)] as Array[EquipmentPassive])
	var ctrl: BattleController = _battle(_hero(acc), ScriptedDice.new([0.6, 0.4] as Array[float]))
	var h: Combatant = ctrl.b.heroes[0]
	var living: Array[Combatant] = ctrl.b.living(ctrl.b.enemies)
	assert_eq(ctrl.b.statuses.apply(h, poison, _src(ctrl.b), 1.0, living), StatusSystem.ApplyResult.RESISTED)
	assert_eq(ctrl.b.statuses.apply(h, poison, _src(ctrl.b), 1.0, living), StatusSystem.ApplyResult.APPLIED)

func test_start_status_applied_before_first_tick_without_credit() -> void:
	var haste: StatusDef = Fixtures.status_def(StatusDef.Kind.HASTE, 3)
	haste.apply_contribution = 50
	var acc: EquipmentDef = _accessory(&"ring", [_passive(EquipmentPassive.Kind.START_WITH, haste)] as Array[EquipmentPassive])
	var ctrl: BattleController = _battle(_hero(acc))
	var h: Combatant = ctrl.b.heroes[0]
	assert_eq(h.statuses.size(), 1)
	assert_eq(h.statuses[0].def.id, haste.id)
	assert_eq(h.statuses[0].source_id, h.id)
	assert_eq(h.statuses[0].remaining, 3)
	assert_true(ctrl.b.ledger.entries().is_empty())
	assert_eq(ctrl.b.tick, 0)

func test_start_status_respects_immunity() -> void:
	var haste: StatusDef = Fixtures.status_def(StatusDef.Kind.HASTE, 3)
	var acc: EquipmentDef = _accessory(&"ring", [
		_passive(EquipmentPassive.Kind.START_WITH, haste),
		_passive(EquipmentPassive.Kind.IMMUNE, haste),
	] as Array[EquipmentPassive])
	var ctrl: BattleController = _battle(_hero(acc))
	assert_true(ctrl.b.heroes[0].statuses.is_empty())

func test_start_status_skips_downed_hero() -> void:
	var haste: StatusDef = Fixtures.status_def(StatusDef.Kind.HASTE, 3)
	var acc: EquipmentDef = _accessory(&"ring", [_passive(EquipmentPassive.Kind.START_WITH, haste)] as Array[EquipmentPassive])
	var ctrl: BattleController = _battle(_hero(acc, 0))
	assert_true(ctrl.b.heroes[0].statuses.is_empty())

func test_apply_forced_renews_without_roll() -> void:
	var haste: StatusDef = Fixtures.status_def(StatusDef.Kind.HASTE, 3)
	var ctrl: BattleController = _battle(_hero(null), ScriptedDice.new([0.99] as Array[float]))
	var h: Combatant = ctrl.b.heroes[0]
	assert_eq(ctrl.b.statuses.apply_forced(h, haste), StatusSystem.ApplyResult.APPLIED)
	h.statuses[0].remaining = 1
	assert_eq(ctrl.b.statuses.apply_forced(h, haste), StatusSystem.ApplyResult.RENEWED)
	assert_eq(h.statuses.size(), 1)
	assert_eq(h.statuses[0].remaining, 3)

func test_enemy_immunities_unchanged() -> void:
	var poison: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 3, 2)
	var cfg := Fixtures.cfg()
	var d := Fixtures.enemy_def(&"x", Stats.make(10, 10, 5, 5))
	d.immunities = [poison.id] as Array[StringName]
	d.resistances = {&"sleep": 0.25} as Dictionary[StringName, float]
	var e: Combatant = Combatant.from_enemy(d, &"x", Vector2.ZERO, cfg)
	assert_eq(e.immunities, [poison.id] as Array[StringName])
	assert_eq(e.resistances.get(&"sleep"), 0.25)
	assert_true(e.start_statuses.is_empty())
	var heroes: Array[Combatant] = [Combatant.from_hero(_hero(null), Vector2.ZERO)]
	var enemies: Array[Combatant] = [e]
	var b := BattleState.create(cfg, ScriptedDice.new([0.0] as Array[float]), heroes, enemies)
	assert_eq(b.statuses.apply(e, poison, heroes[0], 1.0, enemies), StatusSystem.ApplyResult.IMMUNE)

func test_equipment_modifiers_in_battle_stats() -> void:
	var cfg := Fixtures.cfg()
	var acc: EquipmentDef = _accessory(&"ring", [] as Array[EquipmentPassive], Stats.make(3, 0, 2, 0))
	var hs: HeroState = _hero(acc)
	var c: Combatant = Combatant.from_hero(hs, Vector2.ZERO)
	assert_eq(StatCalculator.effective(c, &"strength", cfg), 13)
	assert_eq(StatCalculator.effective(c, &"vitality", cfg), 7)
	assert_eq(c.hp, StatCalculator.hp_max(c, cfg))

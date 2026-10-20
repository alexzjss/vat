extends GutTest

## Conteúdo genérico de teste em res://data/test/ (VALORES DE TESTE — NÃO CANÔNICOS).

const ROOT: String = "res://data/test"
const HEROES: Array[String] = ["teste_a", "teste_b", "teste_c", "teste_d", "teste_e"]
const ENEMIES: Array[String] = ["inimigo_x", "inimigo_y", "inimigo_z"]
const STATUSES: Array[String] = ["poison", "sleep", "paralysis", "haste", "slow", "barrier", "str_up"]
const ITEMS: Array[String] = ["pocao", "eter", "reviver"]

func _list_tres(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub: String in dir.get_directories():
		out.append_array(_list_tres(dir_path + "/" + sub))
	for f: String in dir.get_files():
		if f.ends_with(".tres"):
			out.append(dir_path + "/" + f)
	return out

func _hero(id: String) -> CharacterDef:
	return load("%s/heroes/%s.tres" % [ROOT, id]) as CharacterDef

func _enemy(id: String) -> EnemyDef:
	return load("%s/enemies/%s.tres" % [ROOT, id]) as EnemyDef

func _status(id: String) -> StatusDef:
	return load("%s/statuses/%s.tres" % [ROOT, id]) as StatusDef

func test_every_tres_loads() -> void:
	var files: Array[String] = _list_tres(ROOT)
	assert_gt(files.size(), 20, "conteudo de teste presente")
	for f: String in files:
		var r: Resource = load(f)
		assert_not_null(r, f)
		assert_not_null(r.get_script() if r != null else null, "%s tem script de def" % f)

func test_balance_is_config() -> void:
	assert_true(load(ROOT + "/balance.tres") is BalanceConfig)

func test_statuses() -> void:
	for id: String in STATUSES:
		var s: StatusDef = _status(id)
		assert_not_null(s, id)
		assert_eq(s.id, StringName(id))
		assert_gt(s.duration, 0, id)
	assert_eq(_status("haste").cancels, [&"slow"] as Array[StringName])
	assert_eq(_status("slow").cancels, [&"haste"] as Array[StringName])
	assert_eq(_status("str_up").kind, StatusDef.Kind.ATTR_MOD)
	assert_eq(_status("str_up").attr, &"strength")

func test_heroes() -> void:
	for id: String in HEROES:
		var h: CharacterDef = _hero(id)
		assert_not_null(h, id)
		assert_not_null(h.base, id)
		assert_not_null(h.basic_attack, "%s basic_attack" % id)
		assert_eq(h.basic_attack.ap_cost, 0)
		assert_false(h.learnset.is_empty(), "%s learnset" % id)
	assert_eq(_hero("teste_a").display_name, "Teste A")
	assert_eq(_hero("teste_a").learnset.size(), 5)
	assert_eq(_hero("teste_b").learnset.size(), 6)
	assert_eq(_hero("teste_c").learnset.size(), 6)
	assert_eq(_hero("teste_d").learnset.size(), 6)
	assert_eq(_hero("teste_e").learnset.size(), 6)

func test_abilities_have_timings_and_effects() -> void:
	for f: String in _list_tres(ROOT + "/abilities"):
		var a: AbilityDef = load(f) as AbilityDef
		assert_not_null(a, f)
		assert_false(a.effects.is_empty(), "%s effects" % f)
		assert_gt(a.cast_time, 0.0, f)
		assert_gt(a.impact_time, 0.0, f)
		assert_lt(a.impact_time, a.cast_time, f)
		if a.shape == AbilityDef.Shape.CIRCLE_TARGET or a.shape == AbilityDef.Shape.CIRCLE_SELF:
			assert_gt(a.radius, 0.0, "%s radius" % f)
		if a.shape == AbilityDef.Shape.LINE:
			assert_gt(a.width, 0.0, "%s width" % f)
		for e: EffectDef in a.effects:
			if e.kind == EffectDef.Kind.APPLY_STATUS:
				assert_not_null(e.status, "%s status" % f)

func test_enemies() -> void:
	for id: String in ENEMIES:
		var d: EnemyDef = _enemy(id)
		assert_not_null(d, id)
		var has_free: bool = false
		for a: AbilityDef in d.abilities:
			if a.ap_cost == 0:
				has_free = true
		assert_true(has_free, "%s tem habilidade de custo 0" % id)
		assert_false(d.ai_rules.is_empty(), "%s ai_rules" % id)
		for rule: AiRule in d.ai_rules:
			assert_not_null(rule.ability, id)
	assert_true(_enemy("inimigo_y").immunities.has(&"sleep"))
	assert_eq(_enemy("inimigo_z").resistances.get(&"poison", 0.0), 0.5)
	assert_eq(_enemy("inimigo_y").ai_rules[0].condition, AiRule.Condition.ALLY_HP_BELOW)

func test_items() -> void:
	var kinds: Array[EffectDef.Kind] = [EffectDef.Kind.HEAL, EffectDef.Kind.RESTORE_AP, EffectDef.Kind.REVIVE]
	for i: int in ITEMS.size():
		var it: ItemDef = load("%s/items/%s.tres" % [ROOT, ITEMS[i]]) as ItemDef
		assert_not_null(it, ITEMS[i])
		assert_eq(it.effects[0].kind, kinds[i])
	var rev: ItemDef = load(ROOT + "/items/reviver.tres") as ItemDef
	assert_eq(rev.effects[0].potency, 0.25)

func test_builds_battle_state() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var heroes: Array[Combatant] = []
	for id: String in HEROES:
		heroes.append(Combatant.from_hero(HeroState.create(_hero(id), cfg), Vector2.ZERO))
	var enemies: Array[Combatant] = []
	for id: String in ENEMIES:
		var d: EnemyDef = _enemy(id)
		enemies.append(Combatant.from_enemy(d, d.id, Vector2.ZERO, cfg))
	var b: BattleState = BattleState.create(cfg, Dice.new(1), heroes, enemies)
	assert_eq(b.living(b.heroes).size(), HEROES.size())
	assert_eq(b.living(b.enemies).size(), 3)
	for c: Combatant in b.all():
		assert_gt(c.hp, 0, String(c.id))
		assert_not_null(c.basic_attack, String(c.id))
		assert_gt(StatCalculator.atb_rate(c, cfg), 0.0)

func test_encounter() -> void:
	var e: EncounterDef = load(ROOT + "/encounters/encontro_xy.tres") as EncounterDef
	assert_not_null(e)
	assert_eq(e.id, &"encontro_xy")
	assert_eq(e.enemies.size(), 2)
	assert_eq(e.enemies[0].id, &"inimigo_x")
	assert_eq(e.enemies[1].id, &"inimigo_y")

func test_equipment_content() -> void:
	var files: Array[String] = _list_tres(ROOT + "/equipment")
	assert_gt(files.size(), 10, "equipamentos de teste presentes")
	var weapon_types: Array[StringName] = [&"blade", &"staff", &"bow"]
	var ids: Array[StringName] = []
	for f: String in files:
		var e: EquipmentDef = load(f) as EquipmentDef
		assert_not_null(e, f)
		assert_true(EquipmentRules.SLOTS.has(e.slot), "%s slot" % f)
		assert_ne(String(e.id), "", f)
		assert_eq(String(e.id), String(e.id).to_lower(), "%s id minusculo" % f)
		assert_eq(f.get_file().get_basename(), String(e.id), "id = nome do arquivo")
		assert_false(ids.has(e.id), "id repetido %s" % e.id)
		ids.append(e.id)
		assert_ne(e.display_name, "", f)
		assert_not_null(e.modifiers, f)
		if e.slot == &"weapon":
			assert_true(weapon_types.has(e.weapon_type), "%s tipo conhecido" % f)
		for p: EquipmentPassive in e.passives:
			assert_not_null(p.status, f)
	var c: EquipmentDef = load(ROOT + "/equipment/capacete_teste_b.tres") as EquipmentDef
	assert_eq(c.allowed_ids, [&"teste_b"] as Array[StringName])
	var veneno: EquipmentDef = load(ROOT + "/equipment/amuleto_veneno.tres") as EquipmentDef
	assert_eq(veneno.passives[0].kind, EquipmentPassive.Kind.RESIST)
	assert_eq(veneno.passives[0].amount, 0.5)

func test_heroes_can_use_starting_equipment() -> void:
	var types: Dictionary[String, Array] = {
		"teste_a": [&"blade"], "teste_b": [&"staff"], "teste_c": [&"bow"],
		"teste_d": [&"blade", &"staff"], "teste_e": [&"bow"],
	}
	for id: String in HEROES:
		var d: CharacterDef = _hero(id)
		assert_eq(d.weapon_types.size(), types[id].size(), id)
		for t: StringName in types[id]:
			assert_true(d.weapon_types.has(t), "%s %s" % [id, t])
		assert_eq(d.starting_equipment.size(), 2, id)
		for e: EquipmentDef in d.starting_equipment:
			assert_true(EquipmentRules.can_equip(d, e, e.slot), "%s equipa %s" % [id, e.id])


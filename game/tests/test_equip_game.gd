extends GutTest

## Jogo raiz com equipamento: equipamento inicial, mochila, Game Over e passivos na batalha do mapa.

const SCENE: String = "res://world/game.tscn"

var game: Game

func before_each() -> void:
	game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.skip_title = true
	add_child_autofree(game)

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	assert_false(game.busy, "transição terminou")

func _enter_area() -> LocalMap:
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	await _wait_idle()
	return game.current as LocalMap

func _bag_def(id: StringName) -> EquipmentDef:
	for e: EquipmentDef in game.test_profile.equipment:
		if e.id == id:
			return e
	return null

func test_new_game_has_starting_equipment_and_bag() -> void:
	assert_gt(game.test_profile.equipment.size(), 0, "mochila inicial preenchida")
	assert_eq(game.test_profile.equipment.size(), game.test_profile.equipment_counts.size())
	for i: int in game.test_profile.equipment.size():
		assert_eq(game.state.bag.count(game.test_profile.equipment[i].id), game.test_profile.equipment_counts[i],
				"mochila: %s" % game.test_profile.equipment[i].id)
	for id: StringName in [&"lamina_aco", &"bastao_carvalho", &"arco_longo", &"armadura_pesada",
			&"capacete_leve", &"capacete_teste_b", &"amuleto_sono", &"amuleto_veneno", &"amuleto_pressa"]:
		assert_not_null(_bag_def(id), "mochila tem %s" % id)
	for h: HeroState in game.state.roster():
		assert_true(h.equipment.has(&"weapon"), "%s começa com arma" % h.def.id)
		assert_true(h.equipment.has(&"armor"), "%s começa com armadura" % h.def.id)

func test_game_over_restores_equipment_and_bag() -> void:
	var hero: HeroState = game.state.heroes[0]
	var start_armor: EquipmentDef = hero.equipment[&"armor"]
	var heavy: EquipmentDef = _bag_def(&"armadura_pesada")
	var map: LocalMap = await _enter_area()
	assert_true(game.state.equip(hero, &"armor", heavy))
	assert_eq(game.state.bag.count(&"armadura_pesada"), 0)
	map.game_over.emit()
	await _wait_idle()
	assert_same(hero.equipment[&"armor"], start_armor, "armadura do salvamento")
	assert_eq(game.state.bag.count(&"armadura_pesada"), 1, "mochila do salvamento")
	assert_eq(game.state.bag.count(start_armor.id), 0)
	assert_not_null(game.game_over_screen, "tela de Game Over")

func test_equipped_passive_holds_in_map_battle() -> void:
	var hero: HeroState = game.state.heroes[0]
	assert_true(game.state.equip(hero, &"accessory", _bag_def(&"amuleto_pressa")))
	var map: LocalMap = await _enter_area()
	map.auto_battle = true
	map.dice_seed = 7
	var e := EncounterDef.new()
	e.id = &"fraco"
	var list: Array[EnemyDef] = [Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 0), 100)]
	e.enemies = list
	var enemy: MapEnemy = map.enemies()[0]
	enemy.encounter = e
	enemy.touched.emit(enemy)
	var s: BattleScene = map.battle
	assert_not_null(s, "batalha começou")
	s.set_process(false)
	var ids: Array[StringName] = []
	for c: Combatant in s.ctrl.b.heroes:
		if c.hero_state == hero:
			for st: ActiveStatus in c.statuses:
				ids.append(st.def.id)
	assert_has(ids, &"haste", "Teste A começa com Pressa")
	var other: Combatant = s.ctrl.b.heroes[1]
	assert_eq(other.statuses.size(), 0, "os outros não")

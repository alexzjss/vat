extends GutTest

## Conteúdo da fatia vertical (M12, Task 4): cidade, casas, mapa-múndi, estrada, dungeon de dois andares.
## Tudo é placeholder / valor de teste. Os eventos rodam no EventRunner (puro) e os mapas num Game real.

const FATIA_SCENE: String = "res://world/game_fatia.tscn"
const TMP: String = "user://test_saves/"
const DATA: String = "res://data/fatia"
const NEW_MAPS: Array[StringName] = [&"cidade", &"casa_1", &"casa_2", &"overworld_fatia", &"estrada", &"dungeon_1", &"dungeon_2"]

var game: Game

func before_each() -> void:
	game = (load(FATIA_SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = (load("res://data/test/balance.tres") as BalanceConfig).duplicate() as BalanceConfig
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.skip_title = true
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	add_child_autofree(game)

func after_each() -> void:
	Input.flush_buffered_events()
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	assert_false(game.busy, "transição terminou")

func _enter(map_id: StringName, spawn: StringName = &"Entry") -> LocalMap:
	game.go_to(map_id, spawn, false)
	await _wait_idle()
	return game.current as LocalMap

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

## Roda um evento no EventRunner puro; `answers` responde às escolhas em ordem. Devolve as falas e o runner.
func _drive(path: String, answers: Array[int] = []) -> Dictionary:
	var ev: EventScript = load(path) as EventScript
	assert_not_null(ev, path)
	var r := EventRunner.new(ev, game.state)
	r.start()
	var texts: Array[String] = []
	var kinds: Array[int] = []
	var queue: Array[int] = answers.duplicate()
	var guard: int = 0
	while not r.finished and guard < 100:
		guard += 1
		var req: EventRequest = r.current()
		texts.append(req.text)
		kinds.append(req.kind)
		var ans: int = 0
		if req.kind == EventRequest.Kind.CHOICE and not queue.is_empty():
			ans = queue.pop_front()
		r.resume(ans)
	return {"texts": texts, "kinds": kinds, "runner": r}

func _has_text(res: Dictionary, part: String) -> bool:
	for t: String in res["texts"]:
		if t.contains(part):
			return true
	return false

func _start_game() -> void:
	game.use_test_profile = false
	game.start_new_game()
	await _wait_idle()

# --- dados ----------------------------------------------------------------------------

func test_every_fatia_tres_loads() -> void:
	var files: Array[String] = _list_tres(DATA)
	assert_gt(files.size(), 30, "conteúdo da fatia presente")
	for f: String in files:
		var r: Resource = load(f)
		assert_not_null(r, f)
		assert_not_null(r.get_script() if r != null else null, "%s tem script de def" % f)

func test_every_event_runs_to_the_end_without_aborting() -> void:
	await _start_game()
	var events: Array[String] = _list_tres(DATA + "/events")
	assert_gt(events.size(), 8)
	for f: String in events:
		var res: Dictionary = _drive(f)
		var r: EventRunner = res["runner"]
		assert_true(r.finished, f)
		assert_false(r.aborted, f)

func test_new_maps_are_registered() -> void:
	for id: StringName in NEW_MAPS:
		assert_true(Game.MAPS.has(id), "MAPS tem %s" % id)

func test_start_profile_map_and_spawn_exist() -> void:
	var p: StartProfile = load(DATA + "/start.tres") as StartProfile
	assert_true(Game.MAPS.has(p.map))
	var scene: Node = (Game.MAPS[p.map] as PackedScene).instantiate()
	assert_true(scene.get_node_or_null(NodePath(String(p.spawn))) is Marker2D, "spawn de início existe")
	scene.free()

func test_every_new_map_has_the_basics() -> void:
	for id: StringName in NEW_MAPS:
		var scene: Node = (Game.MAPS[id] as PackedScene).instantiate()
		assert_not_null(scene.get_node_or_null(^"Player"), "%s: Player" % id)
		assert_not_null(scene.get_node_or_null(^"MapCamera"), "%s: MapCamera" % id)
		if scene is LocalMap:
			assert_not_null(scene.get_node_or_null(^"Arena"), "%s: Arena" % id)
			assert_not_null(scene.get_node_or_null(^"Entry"), "%s: Entry" % id)
		else:
			assert_not_null(scene.get_node_or_null(^"Start"), "%s: Start" % id)
		scene.free()

func test_shops_and_inn_are_wired() -> void:
	var city: Node = (Game.MAPS[&"cidade"] as PackedScene).instantiate()
	var keepers: Array[Node] = city.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool: return n is ShopKeeper)
	assert_eq(keepers.size(), 1)
	var shop: ShopDef = (keepers[0] as ShopKeeper).shop
	assert_not_null(shop)
	assert_eq((keepers[0] as ShopKeeper).greeting, PackedStringArray(["Texto de teste"]), "o lojista cumprimenta antes da loja")
	assert_gt(shop.items.size(), 3)
	assert_gt(shop.equipment.size(), 3)
	for it: ItemDef in shop.items:
		assert_gt(it.price, 0, it.display_name)
	for e: EquipmentDef in shop.equipment:
		assert_gt(e.price, 0, e.display_name)
	var inns: Array[Node] = city.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool: return n is Inn)
	assert_eq(inns.size(), 1)
	assert_true(city.get_node_or_null(NodePath(String((inns[0] as Inn).spawn_name))) is Marker2D)
	city.free()

func test_town_has_residents_and_houses() -> void:
	var city: Node = (Game.MAPS[&"cidade"] as PackedScene).instantiate()
	var npcs: int = 0
	var with_choice: int = 0
	for n: Node in city.find_children("*", "Area2D", true, false):
		var npc: Npc = n as Npc
		if npc == null or npc is ShopKeeper or npc.name == &"Pousadeiro":
			continue
		npcs += 1
		assert_not_null(npc.event, "%s fala" % npc.name)
		for s: EventStep in npc.event.steps:
			if s is ChoiceStep:
				with_choice += 1
				break
	assert_between(npcs, 4, 6, "4 a 6 moradores")
	assert_gte(with_choice, 1, "um deles com escolha")
	assert_not_null(city.get_node_or_null(^"Pousadeiro"))
	assert_not_null(city.get_node_or_null(^"PlacaSaida"), "placa na saída")
	assert_true(city.get_node_or_null(^"Casa1Porta") is MapLink)
	assert_true(city.get_node_or_null(^"Casa2Porta") is MapLink)
	city.free()

func test_common_enemies_have_money_and_drops() -> void:
	var with_drops: int = 0
	for f: String in _list_tres(DATA + "/enemies"):
		var e: EnemyDef = load(f) as EnemyDef
		assert_not_null(e, f)
		assert_gt(e.money, 0, f)
		if not e.drops.is_empty():
			with_drops += 1
	assert_gte(with_drops, 3)

func test_shop_items_exist_in_the_registry() -> void:
	var shop: ShopDef = load(DATA + "/shops/loja_cidade.tres") as ShopDef
	for it: ItemDef in shop.items:
		assert_eq(game.registry.item(it.id), it, it.id)
	for e: EquipmentDef in shop.equipment:
		assert_eq(game.registry.equipment(e.id), e, e.id)
	assert_not_null(game.registry.item(&"erva_teste"))

func test_herb_is_a_key_item_and_not_sellable() -> void:
	var herb: ItemDef = load(DATA + "/items/erva_teste.tres") as ItemDef
	assert_true(herb.key_item)
	assert_eq(herb.price, 0)

# --- Novo jogo e rota -----------------------------------------------------------------

func test_new_game_loads_the_town_at_start() -> void:
	await _start_game()
	assert_eq(game.current_map, &"cidade")
	assert_eq(game.state.money, 50)
	assert_eq(game.state.heroes.size(), 3)
	var town: LocalMap = game.current as LocalMap
	assert_eq(town.player.global_position, town.get_node("Start").global_position)

func test_route_town_to_dungeon_floor_two_and_back() -> void:
	await _start_game()
	var town: LocalMap = game.current as LocalMap
	var exit_link: MapLink = town.get_node("SaidaLink") as MapLink
	exit_link.activated.emit(exit_link.target_map, exit_link.target_spawn)
	await _wait_idle()
	assert_eq(game.current_map, &"overworld_fatia")
	var world: Overworld = game.current as Overworld
	assert_eq(world.player.global_position, world.get_node("CidadeReturn").global_position)
	world.location_entered.emit(&"estrada", &"Entry")
	await _wait_idle()
	assert_eq(game.current_map, &"estrada")
	var road: LocalMap = game.current as LocalMap
	assert_gt(road.enemies().size(), 2, "encontros no caminho")
	var east: MapLink = road.get_node("LinkLeste") as MapLink
	east.activated.emit(east.target_map, east.target_spawn)
	await _wait_idle()
	assert_eq(game.current_map, &"overworld_fatia")
	(game.current as Overworld).location_entered.emit(&"dungeon_1", &"Entry")
	await _wait_idle()
	assert_eq(game.current_map, &"dungeon_1")
	var d1: LocalMap = game.current as LocalMap
	var stairs: MapLink = d1.get_node("EscadaLink") as MapLink
	stairs.activated.emit(stairs.target_map, stairs.target_spawn)
	await _wait_idle()
	assert_eq(game.current_map, &"dungeon_2")
	var d2: LocalMap = game.current as LocalMap
	var back: MapLink = d2.get_node("VoltaLink") as MapLink
	back.activated.emit(back.target_map, back.target_spawn)
	await _wait_idle()
	assert_eq(game.current_map, &"dungeon_1")
	assert_eq((game.current as LocalMap).player.global_position, game.current.get_node("Escada").global_position)

func test_enemy_huds_do_not_overlap_in_the_slice_arenas() -> void:
	for map_id: StringName in [&"estrada", &"dungeon_1", &"dungeon_2"]:
		var scene: Node = (Game.MAPS[map_id] as PackedScene).instantiate()
		var arena: Node2D = scene.get_node("Arena") as Node2D
		var rects: Array[Rect2] = []
		for i: int in range(1, 5):
			var spot: Node2D = arena.get_node("EnemySpot%d" % i) as Node2D
			rects.append(Rect2(CombatantView.HUD_RECT.position + spot.position, CombatantView.HUD_RECT.size))
		for a: int in rects.size():
			for b: int in range(a + 1, rects.size()):
				assert_false(rects[a].intersects(rects[b]), "%s: HUD do inimigo %d sobrepõe o %d" % [map_id, a + 1, b + 1])
		scene.free()

func test_overworld_pass_is_blocked_except_through_the_road() -> void:
	var world: Node = (Game.MAPS[&"overworld_fatia"] as PackedScene).instantiate()
	var ids: Array[StringName] = []
	for z: Node in world.find_children("*", "Area2D", true, false):
		ids.append((z as Zone).zone_id)
	for id: StringName in [&"cidade", &"estrada", &"dungeon_1"]:
		assert_true(ids.has(id), "zona %s" % id)
	world.free()

func test_coming_back_from_the_dungeon_enters_the_road_by_its_east_end() -> void:
	await _start_game()
	game.go_to(&"overworld_fatia", &"DungeonReturn", false)
	await _wait_idle()
	var world: Overworld = game.current as Overworld
	var player: Player = world.player
	player.override_dir = Vector2.LEFT
	var guard: int = 0
	while game.current_map == &"overworld_fatia" and guard < 900:
		await get_tree().physics_frame
		guard += 1
	await _wait_idle()
	assert_eq(game.current_map, &"estrada", "andando para oeste a partir do retorno da dungeon")
	var road: LocalMap = game.current as LocalMap
	assert_eq(road.player.global_position, road.get_node("EntryLeste").global_position, "chega pelo lado leste da estrada")

func test_going_out_from_the_town_still_enters_the_road_by_its_west_end() -> void:
	await _start_game()
	game.go_to(&"overworld_fatia", &"CidadeReturn", false)
	await _wait_idle()
	var world: Overworld = game.current as Overworld
	world.player.override_dir = Vector2.RIGHT
	var guard: int = 0
	while game.current_map == &"overworld_fatia" and guard < 900:
		await get_tree().physics_frame
		guard += 1
	await _wait_idle()
	assert_eq(game.current_map, &"estrada")
	var road: LocalMap = game.current as LocalMap
	assert_eq(road.player.global_position, road.get_node("Entry").global_position)

# --- missão secundária ----------------------------------------------------------------

const QUEST: String = DATA + "/events/morador_c.tres"

func test_quest_before_asks_and_accepting_starts_it() -> void:
	await _start_game()
	assert_eq(game.state.get_flag(&"missao_estado"), 0)
	var res: Dictionary = _drive(QUEST, [0])
	assert_true(res["kinds"].has(EventRequest.Kind.CHOICE), "pergunta se aceita")
	assert_eq(game.state.get_flag(&"missao_estado"), 1, "aceitou")

func test_quest_refusing_keeps_it_closed() -> void:
	await _start_game()
	_drive(QUEST, [1])
	assert_eq(game.state.get_flag(&"missao_estado"), 0)
	var again: Dictionary = _drive(QUEST, [0])
	assert_eq(game.state.get_flag(&"missao_estado"), 1, "pode aceitar depois")
	assert_true(again["kinds"].has(EventRequest.Kind.CHOICE))

func test_quest_during_without_herb_only_reminds() -> void:
	await _start_game()
	game.state.set_flag(&"missao_estado", 1)
	var money: int = game.state.money
	var res: Dictionary = _drive(QUEST)
	assert_false(res["kinds"].has(EventRequest.Kind.CHOICE))
	assert_eq(game.state.get_flag(&"missao_estado"), 1, "segue em andamento")
	assert_eq(game.state.money, money, "sem entrega, sem pagamento")

func test_quest_checks_the_herb_item_not_the_chest_flag() -> void:
	await _start_game()
	game.state.set_flag(&"missao_estado", 1)
	game.state.set_flag(&"bau_erva", 1)
	var money: int = game.state.money
	_drive(QUEST)
	assert_eq(game.state.get_flag(&"missao_estado"), 1, "o baú aberto não basta: a erva tem de estar com o grupo")
	assert_eq(game.state.money, money)

func _give_herb() -> void:
	game.state.grant_item(game.registry.item(&"erva_teste"), 1)

func test_quest_delivery_pays_money_equipment_and_xp_once() -> void:
	await _start_game()
	game.state.set_flag(&"missao_estado", 1)
	_give_herb()
	var money: int = game.state.money
	var xp: int = game.state.heroes[0].xp
	var level: int = game.state.heroes[0].level
	var bag_before: int = game.state.bag.listing().size()
	var res: Dictionary = _drive(QUEST)
	assert_eq(game.state.get_flag(&"missao_estado"), 2, "concluída")
	assert_eq(game.state.inventory.count(&"erva_teste"), 0, "a erva foi entregue")
	assert_true(_has_text(res, "Entregou Erva de Teste"), "linha de sistema")
	assert_gt(game.state.money, money, "Moedas")
	assert_gt(game.state.bag.listing().size(), bag_before, "equipamento")
	assert_true(game.state.heroes[0].xp > xp or game.state.heroes[0].level > level, "XP narrativa ACTIVE")
	assert_not_null(res)
	var paid: int = game.state.money
	_drive(QUEST)
	assert_eq(game.state.money, paid, "depois: não paga de novo")
	assert_eq(game.state.get_flag(&"missao_estado"), 2)

func test_quest_after_has_its_own_line() -> void:
	await _start_game()
	game.state.set_flag(&"missao_estado", 2)
	var res: Dictionary = _drive(QUEST)
	assert_false(res["kinds"].has(EventRequest.Kind.CHOICE))
	assert_eq(res["texts"].size(), 1)

func test_herb_chest_is_optional_in_floor_one_and_gives_the_herb() -> void:
	await _start_game()
	var d1: LocalMap = await _enter(&"dungeon_1")
	var chest: Chest = d1.get_node("BauErva") as Chest
	assert_not_null(chest)
	assert_eq(chest.item.id, &"erva_teste")
	assert_eq(chest.opened_flag, &"bau_erva")
	var d1_door: Door = d1.get_node("Door") as Door
	assert_not_null(d1_door.key_item)
	assert_ne(d1_door.key_item, chest.item, "a erva não é a chave")

# --- recrutas -------------------------------------------------------------------------

func test_recruit_d_joins_the_active_party_at_party_avg_level() -> void:
	await _start_game()
	for h: HeroState in game.state.heroes:
		XpCalculator.grant(h, XpCalculator.xp_for_level(3, game.state.cfg), game.state.cfg)
	var avg: int = game.state.party_avg_level()
	assert_eq(game.state.heroes.size(), 3)
	var res: Dictionary = _drive(DATA + "/events/recruta_d.tres")
	assert_eq(game.state.heroes.size(), 4, "vaga nos ativos")
	var d: HeroState = game.state.heroes[3]
	assert_eq(d.def.id, &"teste_d_f")
	assert_eq(d.level, avg)
	assert_true(_has_text(res, "entrou no grupo"))

func test_recruit_d_is_idempotent() -> void:
	await _start_game()
	_drive(DATA + "/events/recruta_d.tres")
	_drive(DATA + "/events/recruta_d.tres")
	assert_eq(game.state.roster().size(), 4)

func test_recruit_e_goes_to_reserve_when_active_is_full() -> void:
	await _start_game()
	_drive(DATA + "/events/recruta_d.tres")
	var res: Dictionary = _drive(DATA + "/events/recruta_e.tres")
	assert_eq(game.state.heroes.size(), 4)
	assert_eq(game.state.reserve.size(), 1, "E vai para a reserva")
	assert_eq(game.state.reserve[0].def.id, &"teste_e_f")
	assert_true(_has_text(res, "entrou no grupo"))
	_drive(DATA + "/events/recruta_e.tres")
	assert_eq(game.state.roster().size(), 5, "só uma vez")

func test_recruit_d_npc_is_in_house_two_and_e_in_the_dungeon() -> void:
	var casa2: Node = (Game.MAPS[&"casa_2"] as PackedScene).instantiate()
	var has_recruit: bool = false
	for n: Node in casa2.find_children("*", "Area2D", true, false):
		var npc: Npc = n as Npc
		if npc != null and npc.event != null:
			for s: EventStep in npc.event.steps:
				if s is RecruitStep and (s as RecruitStep).hero.id == &"teste_d_f":
					has_recruit = true
	assert_true(has_recruit, "evento de recrutamento do D na casa 2")
	casa2.free()
	var d1: Node = (Game.MAPS[&"dungeon_1"] as PackedScene).instantiate()
	var trig: EventTrigger = d1.get_node("CenaETrigger") as EventTrigger
	var found: bool = false
	for s: EventStep in trig.event.steps:
		if s is RecruitStep and (s as RecruitStep).hero.id == &"teste_e_f":
			found = true
	assert_true(found, "evento de recrutamento do E no fim do andar 1")
	assert_gt(trig.global_position.x, (d1.get_node("Entry") as Node2D).global_position.x + 1500.0, "sala final")
	d1.free()

func test_house_chest_is_in_one_house() -> void:
	var casa1: Node = (Game.MAPS[&"casa_1"] as PackedScene).instantiate()
	var chests: int = casa1.find_children("*", "Area2D", true, false).filter(func(n: Node) -> bool: return n is Chest).size()
	assert_eq(chests, 1)
	casa1.free()

# --- dungeon, andar 1 -----------------------------------------------------------------

func test_floor_one_has_all_the_objects() -> void:
	await _start_game()
	var d1: LocalMap = await _enter(&"dungeon_1")
	for n: String in ["RestPoint", "BauPocao", "BauChave", "BauErva", "BauEter", "Door", "Switch", "Gate", "TrapDano", "TrapBatalha", "CenaETrigger", "NpcE", "EscadaLink", "SaidaLink"]:
		assert_not_null(d1.get_node_or_null(NodePath(n)), n)
	var kinds: Dictionary = {"patrol": false, "chase": false, "group": false}
	for e: MapEnemy in d1.enemies():
		kinds["patrol"] = kinds["patrol"] or e.behavior == MapEnemy.Behavior.PATROL
		kinds["chase"] = kinds["chase"] or e.chases
		kinds["group"] = kinds["group"] or e.group != &""
	assert_true(kinds["patrol"], "patrulha")
	assert_true(kinds["chase"], "perseguição")
	assert_true(kinds["group"], "grupo")
	var rest: RestPoint = d1.get_node("RestPoint") as RestPoint
	assert_lt(rest.global_position.distance_to((d1.get_node("Entry") as Node2D).global_position), 400.0, "descanso na entrada")

func test_floor_one_switch_opens_its_gate() -> void:
	await _start_game()
	var d1: LocalMap = await _enter(&"dungeon_1")
	var gate: FlagGate = d1.get_node("Gate") as FlagGate
	var sw: Switch = d1.get_node("Switch") as Switch
	assert_eq(gate.flag, sw.flag)
	assert_true(gate.blocking())
	game.state.set_flag(sw.flag, 1)
	assert_false(gate.blocking())

# --- dungeon, andar 2: puzzle e chefe -------------------------------------------------

func test_two_switch_puzzle_opens_only_with_both_flags() -> void:
	await _start_game()
	var d2: LocalMap = await _enter(&"dungeon_2")
	var sa: Switch = d2.get_node("SwitchA") as Switch
	var sb: Switch = d2.get_node("SwitchB") as Switch
	assert_ne(sa.flag, sb.flag)
	var gates: Array[FlagGate] = []
	for n: Node in d2.get_children():
		if n is FlagGate:
			gates.append(n)
	assert_gte(gates.size(), 2)
	var pass_open: Callable = func() -> bool:
		for g: FlagGate in gates:
			if g.blocking():
				return false
		return true
	assert_false(pass_open.call(), "fechado")
	game.state.set_flag(sa.flag, 1)
	assert_false(pass_open.call(), "só A: fechado")
	game.state.set_flag(sa.flag, 0)
	game.state.set_flag(sb.flag, 1)
	assert_false(pass_open.call(), "só B: fechado")
	game.state.set_flag(sa.flag, 1)
	assert_true(pass_open.call(), "A e B: aberto")

func test_floor_two_rest_point_comes_before_the_boss() -> void:
	var d2: Node = (Game.MAPS[&"dungeon_2"] as PackedScene).instantiate()
	var rest: Node2D = d2.get_node("RestPoint") as Node2D
	var boss: Node2D = d2.get_node("Boss") as Node2D
	var gate: Node2D = d2.get_node("CenaChefeTrigger") as Node2D
	assert_lt(rest.position.x, gate.position.x)
	assert_lt(gate.position.x, boss.position.x)
	assert_true(d2.get_node("RestSpawn") is Marker2D)
	d2.free()

func test_boss_only_appears_after_the_entry_scene() -> void:
	await _start_game()
	var d2: LocalMap = await _enter(&"dungeon_2")
	var boss: MapEnemy = d2.get_node("Boss") as MapEnemy
	assert_eq(boss.encounter.unique_id, &"chefe_fatia")
	assert_false(boss.encounter.can_flee, "sem fuga")
	assert_false(boss.gate_open(), "escondido antes da cena")
	assert_false(boss.visible)
	var trig: EventTrigger = d2.get_node("CenaChefeTrigger") as EventTrigger
	assert_true(trig.trigger(), "a cena de entrada roda")
	assert_eq(game.state.get_flag(&"f2_cena_chefe"), 1)
	boss.sync_flag_gate()
	assert_true(boss.gate_open(), "aparece depois da cena")
	assert_true(boss.visible)
	assert_false(trig.trigger(), "a cena só roda uma vez")
	game.event_player.cancel()

func test_defeated_boss_does_not_come_back() -> void:
	await _start_game()
	game.state.set_flag(&"f2_cena_chefe", 1)
	game.state.mark_defeated(&"chefe_fatia")
	var d2: LocalMap = await _enter(&"dungeon_2")
	assert_null(d2.get_node_or_null(^"Boss"), "o chefe derrotado não volta")

func test_final_scene_only_after_the_boss_is_defeated_and_ends_the_demo() -> void:
	await _start_game()
	var d2: LocalMap = await _enter(&"dungeon_2")
	var fin: EventTrigger = d2.get_node("FinalTrigger") as EventTrigger
	assert_false(fin.trigger(), "com o chefe vivo, nada")
	game.state.mark_defeated(&"chefe_fatia")
	assert_true(fin.trigger(), "chefe derrotado: cena final")
	var guard: int = 0
	while game.event_player.active and guard < 80:
		guard += 1
		var box: DialogueBox = game.event_player.dialogue
		box._shown = 9999.0
		box.accept()
		await get_tree().process_frame
	assert_not_null(game.end_screen, "EndDemoStep abre a tela de fim")
	assert_false(fin.trigger(), "só uma vez")

func test_final_scene_has_an_end_demo_step() -> void:
	var ev: EventScript = load(DATA + "/events/cena_final.tres") as EventScript
	var ends: bool = false
	for s: EventStep in ev.steps:
		ends = ends or s is EndDemoStep
	assert_true(ends)

# --- save e load em interiores e andares ---------------------------------------------

func test_inn_save_and_load_return_to_the_inn() -> void:
	await _start_game()
	var town: LocalMap = game.current as LocalMap
	var inn: Inn = town.get_node("Pousada") as Inn
	town.player.global_position = inn.global_position
	assert_true(game.can_save())
	assert_true(game.save_to_slot(1))
	assert_eq(game.state.save_map, &"cidade")
	assert_eq(game.state.save_spawn, inn.spawn_name)
	assert_true(game.continue_from_slot(1))
	await _wait_idle()
	assert_eq(game.current_map, &"cidade")

func test_dungeon_rest_point_saves_on_each_floor() -> void:
	await _start_game()
	for id: StringName in [&"dungeon_1", &"dungeon_2"]:
		var m: LocalMap = await _enter(id)
		var rp: RestPoint = m.get_node("RestPoint") as RestPoint
		m.player.global_position = rp.global_position
		assert_eq(game.save_spawn_here(), rp.spawn_name, String(id))
		assert_true(game.save_to_slot(2))
		assert_eq(game.state.save_map, id)
		assert_true(game.continue_from_slot(2))
		await _wait_idle()
		assert_eq(game.current_map, id)

# --- elementos no conteudo (M13, Task 5) ---------------------------------------------------

const SLICE_HEROES: Array[String] = ["teste_a_f", "teste_b_f", "teste_c_f", "teste_d_f", "teste_e_f"]
const SLICE_ENEMIES: Array[String] = ["inimigo_f1", "inimigo_f2", "inimigo_f3", "inimigo_f4", "braco_fatia", "guardiao_fatia"]

func _elemental_techniques(h: CharacterDef) -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	for le: LearnEntry in h.learnset:
		if le.ability != null and le.ability.element != null:
			out.append(le.ability)
	return out

func test_slice_heroes_have_one_native_and_one_elemental_technique() -> void:
	for id: String in SLICE_HEROES:
		var h: CharacterDef = load("%s/heroes/%s.tres" % [DATA, id]) as CharacterDef
		assert_not_null(h, id)
		assert_eq(h.elements.size(), 1, "%s: 1 nativo" % id)
		assert_eq(ElementMath.native_errors(h.id, h.elements).size(), 0, "%s: nativos validos" % id)
		var techs: Array[AbilityDef] = _elemental_techniques(h)
		assert_eq(techs.size(), 1, "%s: 1 tecnica elemental" % id)
		assert_eq(techs[0].element, h.elements[0], "%s: tecnica do elemento nativo" % id)

func test_slice_heroes_are_used_by_the_start_profile_and_recruits() -> void:
	var p: StartProfile = load(DATA + "/start.tres") as StartProfile
	for d: CharacterDef in p.party:
		assert_true(d.resource_path.begins_with(DATA + "/heroes/"), d.id)
	for ev: String in ["recruta_d", "recruta_e"]:
		var s: EventScript = load("%s/events/%s.tres" % [DATA, ev]) as EventScript
		for st: EventStep in s.steps:
			if st is RecruitStep:
				assert_true((st as RecruitStep).hero.resource_path.begins_with(DATA + "/heroes/"), ev)

func test_test_heroes_stay_neutral() -> void:
	for id: String in ["teste_a", "teste_b", "teste_c", "teste_d", "teste_e"]:
		var h: CharacterDef = load("res://data/test/heroes/%s.tres" % id) as CharacterDef
		assert_true(h.elements.is_empty(), id)
		assert_true(_elemental_techniques(h).is_empty(), id)

func test_slice_enemies_have_weaknesses_and_a_resistance_and_the_guardian_absorbs() -> void:
	for id: String in SLICE_ENEMIES:
		var e: EnemyDef = load("%s/enemies/%s.tres" % [DATA, id]) as EnemyDef
		var weak: int = 0
		var resist: int = 0
		var absorb: int = 0
		for k: StringName in e.element_resist:
			var v: float = e.element_resist[k]
			if v < 0.0:
				weak += 1
			elif v > 1.0:
				absorb += 1
			elif v > 0.0:
				resist += 1
		assert_between(weak, 1, 2, "%s: 1-2 fraquezas" % id)
		assert_eq(resist, 1, "%s: 1 resistencia" % id)
		assert_eq(absorb, 1 if id == "guardiao_fatia" else 0, "%s: absorcao so no Guardiao" % id)
		assert_eq(ElementMath.native_errors(e.id, e.elements).size(), 0, id)

func test_slice_has_blood_and_radioactive_abilities_on_enemies() -> void:
	var rules: Array[ElementDef.Rule] = []
	var has_bleed: bool = false
	for id: String in SLICE_ENEMIES:
		var e: EnemyDef = load("%s/enemies/%s.tres" % [DATA, id]) as EnemyDef
		for ab: AbilityDef in e.abilities:
			if ab.element == null:
				continue
			rules.append(ab.element.rule)
			for fx: EffectDef in ab.effects:
				if fx.kind == EffectDef.Kind.APPLY_STATUS and fx.status != null and fx.status.kind == StatusDef.Kind.BLEED:
					has_bleed = true
	assert_true(rules.has(ElementDef.Rule.BLOOD), "habilidade de Sangue")
	assert_true(rules.has(ElementDef.Rule.RADIOACTIVE), "habilidade radioativa")
	assert_true(has_bleed, "a de Sangue aplica Sangramento")

func test_shop_has_an_elemental_weapon_and_a_resistant_piece() -> void:
	var shop: ShopDef = load(DATA + "/shops/loja_cidade.tres") as ShopDef
	var weapon: bool = false
	var resist: bool = false
	for e: EquipmentDef in shop.equipment:
		weapon = weapon or (e.slot == &"weapon" and e.element != null)
		resist = resist or not e.element_resist.is_empty()
	assert_true(weapon, "arma elemental na loja")
	assert_true(resist, "peca com resistencia na loja")

# --- IA de combo (M14, Task 4) -------------------------------------------------------------

func _combo_rules(rules: Array[AiRule]) -> Array[AiRule]:
	var out: Array[AiRule] = []
	for r: AiRule in rules:
		if r.condition == AiRule.Condition.CAN_REACT:
			out.append(r)
	return out

func test_slice_guardian_has_a_combo_rule_in_every_phase() -> void:
	var g: EnemyDef = load(DATA + "/enemies/guardiao_fatia.tres") as EnemyDef
	var sets: Array = [g.ai_rules]
	for p: BossPhase in g.phases:
		sets.append(p.ai_rules)
	for rules: Array in sets:
		var combos: Array[AiRule] = _combo_rules(rules)
		assert_eq(combos.size(), 1)
		assert_eq(combos[0].pick, AiRule.TargetPick.REACTION_TARGET)
		assert_not_null(combos[0].ability.element)
		assert_true(g.abilities.has(combos[0].ability))

func test_slice_has_a_common_enemy_that_closes_combos() -> void:
	var e: EnemyDef = load(DATA + "/enemies/inimigo_f4.tres") as EnemyDef
	var combos: Array[AiRule] = _combo_rules(e.ai_rules)
	assert_eq(combos.size(), 1)
	assert_eq(combos[0].pick, AiRule.TargetPick.REACTION_TARGET)
	assert_not_null(combos[0].ability.element)
	assert_true(e.abilities.has(combos[0].ability))
	assert_true(combos[0].ability.ap_cost > 0, "a regra nao vira o ataque basico")

func test_slice_has_an_enemy_that_marks_heroes_before_the_combo() -> void:
	# inimigo_f3 (Sangue) marca; inimigo_f4 fecha o combo no encontro enc_f34.
	var f3: EnemyDef = load(DATA + "/enemies/inimigo_f3.tres") as EnemyDef
	var marker: AbilityDef = null
	for a: AbilityDef in f3.abilities:
		if a.ap_cost == 0 and a.element != null and a.element.reacts:
			marker = a
	assert_not_null(marker, "ataque basico elemental que reage")
	var enc: EncounterDef = load(DATA + "/encounters/enc_f34.tres") as EncounterDef
	assert_true(enc.enemies.has(f3))

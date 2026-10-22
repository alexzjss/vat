extends GutTest

## Loja, pousada e moeda na interface (M12): comprar e vender pelo menu sem vazar entrada para o mapa,
## comparação de equipamento, pousada paga, moeda no menu de campo e no resultado da batalha.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

var game: Game
var map: LocalMap
var shop: ShopDef
var potion: ItemDef
var herb: ItemDef
var armor: EquipmentDef
var bow: EquipmentDef

func before_each() -> void:
	game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.skip_title = true
	add_child_autofree(game)
	potion = ItemDef.new()
	potion.id = &"loja_pocao"
	potion.display_name = "Poção de Loja"
	potion.price = 10
	herb = ItemDef.new()
	herb.id = &"loja_erva"
	herb.display_name = "Erva"
	herb.price = 40
	herb.key_item = true
	armor = EquipmentDef.new()
	armor.id = &"loja_armadura"
	armor.display_name = "Armadura de Loja"
	armor.slot = &"armor"
	armor.modifiers = Stats.make(0, 0, 4, 0)
	armor.price = 80
	bow = EquipmentDef.new()
	bow.id = &"loja_arco"
	bow.display_name = "Arco de Loja"
	bow.slot = &"weapon"
	bow.weapon_type = &"bow"
	bow.modifiers = Stats.make(3, 0, 0, 0)
	bow.price = 60
	shop = ShopDef.new()
	shop.id = &"loja_teste"
	shop.display_name = "Loja Teste"
	shop.items = [potion] as Array[ItemDef]
	shop.equipment = [armor, bow] as Array[EquipmentDef]

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

func _enter_area() -> void:
	await _wait_idle()
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	await _wait_idle()
	map = game.current as LocalMap

func _press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func _keeper() -> ShopKeeper:
	var k := ShopKeeper.new()
	k.shop = shop
	k.position = map.player.position + Vector2(30, 0)
	map.add_interactable(k)
	return k

func _open_shop() -> ShopMenu:
	await _enter_area()
	_keeper()
	assert_true(map.try_interact(), "interagir com o lojista")
	assert_true(game.shop_menu.is_open)
	return game.shop_menu

# --- abrir e congelar -------------------------------------------------------------

func test_keeper_opens_shop_and_freezes_map() -> void:
	var m: ShopMenu = await _open_shop()
	assert_eq(m.title_text(), "Loja Teste")
	assert_eq(m.entries(), PackedStringArray(["Comprar", "Vender", "Sair"]))
	assert_eq(map.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(game.can_open_menu(), "menu de campo não abre sobre a loja")
	assert_false(game.can_play_event())
	m.accept()
	m.cancel()
	m.cancel()
	assert_false(m.is_open)
	assert_eq(map.process_mode, Node.PROCESS_MODE_INHERIT, "mapa descongelado")

func test_keeper_without_shop_does_nothing() -> void:
	await _enter_area()
	var k := ShopKeeper.new()
	k.position = map.player.position + Vector2(30, 0)
	map.add_interactable(k)
	assert_true(map.try_interact())
	assert_false(game.shop_menu.is_open)

# --- comprar ------------------------------------------------------------------------

func test_buy_through_the_menu_with_quantity() -> void:
	var m: ShopMenu = await _open_shop()
	game.state.money = 100
	m.accept()
	assert_eq(m.stage, ShopMenu.Stage.BUY)
	assert_string_contains(m.entries()[0], "Poção de Loja — 10 Moedas")
	m.adjust(1)
	m.adjust(1)
	assert_eq(m.quantity, 3)
	m.accept()
	assert_eq(game.state.money, 70)
	assert_eq(game.state.inventory.count(&"loja_pocao"), 3)
	assert_string_contains(m.message(), "Comprou")
	assert_eq(m.quantity, 1)
	assert_eq(m.money_text(), "Moedas: 70")

func test_quantity_is_clamped_to_what_money_allows() -> void:
	var m: ShopMenu = await _open_shop()
	game.state.money = 25
	m.accept()
	for _i: int in 10:
		m.adjust(1)
	assert_eq(m.quantity, 2)
	m.adjust(-5)
	assert_eq(m.quantity, 1)

func test_buy_without_money_refuses_and_keeps_everything() -> void:
	var m: ShopMenu = await _open_shop()
	game.state.money = 5
	m.accept()
	assert_false(m.entry_enabled(0))
	m.accept()
	assert_string_contains(m.message(), "Moedas suficientes")
	assert_eq(game.state.money, 5)
	assert_eq(game.state.inventory.count(&"loja_pocao"), 0)

func test_buy_equipment_goes_to_the_bag() -> void:
	var m: ShopMenu = await _open_shop()
	game.state.money = 100
	m.accept()
	m.move(1)
	assert_eq(m.current_good(), armor)
	m.accept()
	assert_eq(game.state.money, 20)
	assert_eq(game.state.bag.count(&"loja_armadura"), 1)

func test_compare_lines_list_only_heroes_who_can_equip() -> void:
	var m: ShopMenu = await _open_shop()
	game.state.money = 500
	m.accept()
	m.move(1)
	var armor_lines: PackedStringArray = m.compare_lines()
	assert_eq(armor_lines.size(), game.state.roster().size(), "armadura livre: todos")
	assert_string_contains(armor_lines[0], "Vitalidade")
	assert_string_contains(armor_lines[0], "HP máx.")
	m.move(1)
	assert_eq(m.current_good(), bow)
	var bow_lines: PackedStringArray = m.compare_lines()
	var expected: int = 0
	for h: HeroState in game.state.roster():
		if EquipmentRules.can_equip(h.def, bow, &"weapon"):
			expected += 1
	assert_gt(expected, 0)
	assert_lt(expected, game.state.roster().size())
	assert_eq(bow_lines.size(), expected)
	for line: String in bow_lines:
		assert_string_contains(line, "Força")
	m.move(-2)
	assert_eq(m.compare_lines().size(), 0, "item comum não compara")

func test_compare_shows_no_change_marker() -> void:
	var flat := EquipmentDef.new()
	flat.id = &"loja_nada"
	flat.display_name = "Nada"
	flat.slot = &"accessory"
	flat.modifiers = Stats.make(0, 0, 0, 0)
	flat.price = 5
	shop.equipment = [flat] as Array[EquipmentDef]
	var m: ShopMenu = await _open_shop()
	m.accept()
	m.move(1)
	assert_eq(m.current_good(), flat)
	assert_string_contains(m.compare_lines()[0], "sem mudança")

# --- vender -------------------------------------------------------------------------

func test_sell_through_the_menu_and_key_item_is_hidden() -> void:
	var m: ShopMenu = await _open_shop()
	game.state.inventory.add(potion, 4)
	game.state.inventory.add(herb, 1)
	game.state.money = 0
	m.move(1)
	m.accept()
	assert_eq(m.stage, ShopMenu.Stage.SELL)
	assert_eq(m.entries().size(), 1, "só a poção; a erva é item-chave")
	assert_string_contains(m.entries()[0], "Poção de Loja x4 — vende 5 Moedas cada")
	m.adjust(1)
	m.adjust(1)
	m.accept()
	assert_eq(game.state.money, 15)
	assert_eq(game.state.inventory.count(&"loja_pocao"), 1)
	assert_eq(game.state.inventory.count(&"loja_erva"), 1)
	assert_string_contains(m.message(), "Vendeu")

func test_selling_everything_empties_list_and_clamps_cursor() -> void:
	var m: ShopMenu = await _open_shop()
	game.state.inventory.add(potion, 1)
	game.state.bag.add(armor, 1)
	m.move(1)
	m.accept()
	assert_eq(m.entries().size(), 2)
	m.move(1)
	m.accept()
	assert_eq(m.entries().size(), 1)
	assert_eq(m.cursor, 0)
	m.accept()
	assert_eq(m.entries().size(), 0)
	m.accept()
	assert_string_contains(m.message(), "Nada para vender")
	assert_eq(game.state.money, 5 + 40)

func test_worn_equipment_is_not_offered_for_sale() -> void:
	var m: ShopMenu = await _open_shop()
	var worn := EquipmentDef.new()
	worn.id = &"vestido_teste"
	worn.display_name = "Vestido"
	worn.slot = &"accessory"
	worn.modifiers = Stats.make(0, 0, 0, 0)
	worn.price = 50
	game.state.heroes[0].equipment[&"accessory"] = worn
	assert_eq(game.state.bag.count(worn.id), 0)
	m.move(1)
	m.accept()
	assert_eq(m.entries().size(), 0, "o que está vestido não é vendável")
	assert_eq(ShopRules.max_sell(game.state, worn), 0)
	assert_false(ShopRules.sell(game.state, worn, 1))
	assert_eq(game.state.heroes[0].equipment[&"accessory"], worn)

func test_nothing_to_sell_message() -> void:
	var m: ShopMenu = await _open_shop()
	m.move(1)
	m.accept()
	assert_eq(m.stage, ShopMenu.Stage.SELL)
	assert_string_contains(m.message(), "Nada para vender")

# --- entrada não vaza ---------------------------------------------------------------

func test_keys_drive_the_shop_without_leaking_to_the_map() -> void:
	var m: ShopMenu = await _open_shop()
	game.state.money = 100
	var p0: Vector2 = map.player.global_position
	var started: Array[int] = [0]
	map.event_requested.connect(func(_e: EventScript) -> void: started[0] += 1)
	await _press(KEY_ENTER)
	assert_eq(m.stage, ShopMenu.Stage.BUY, "Enter abre Comprar")
	await _press(KEY_RIGHT)
	assert_eq(m.quantity, 2)
	await _press(KEY_ENTER)
	assert_eq(game.state.inventory.count(&"loja_pocao"), 2)
	await _press(KEY_DOWN)
	assert_eq(m.cursor, 1)
	await _press(KEY_ESCAPE)
	assert_eq(m.stage, ShopMenu.Stage.MAIN, "Esc volta à raiz")
	assert_true(m.is_open)
	assert_false(game.menu.is_open, "Esc não abre o menu de campo")
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	assert_false(m.is_open, "Sair fecha")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(m.is_open, "o mesmo Enter não reabriu a loja")
	assert_false(game.menu.is_open)
	assert_false(game.event_player.active)
	assert_eq(started[0], 0)
	assert_eq(map.player.global_position, p0, "jogador não se mexeu")

func test_escape_on_root_closes_without_opening_field_menu() -> void:
	var m: ShopMenu = await _open_shop()
	await _press(KEY_ESCAPE)
	assert_false(m.is_open)
	assert_false(game.menu.is_open)

func test_shop_ignores_second_request_while_open() -> void:
	var m: ShopMenu = await _open_shop()
	m.accept()
	assert_eq(m.stage, ShopMenu.Stage.BUY)
	map.shop_requested.emit(shop)
	assert_eq(m.stage, ShopMenu.Stage.BUY, "pedido repetido é ignorado e não reinicia a loja")

# --- pousada ------------------------------------------------------------------------

func _inn() -> Inn:
	var inn := Inn.new()
	inn.spawn_name = &"RestSpawn"
	inn.position = map.player.position
	map.add_interactable(inn)
	return inn

func test_inn_without_money_refuses() -> void:
	await _enter_area()
	_inn()
	game.state.money = 5
	game.state.heroes[0].hp = 1
	assert_true(map.try_interact())
	var rm: RestMenu = game.rest_menu
	assert_true(rm.is_open)
	assert_eq(rm.price, game.state.cfg.inn_price)
	assert_false(rm.entry_enabled(RestMenu.REST_INDEX))
	rm.accept()
	assert_string_contains(rm.message(), "Moedas suficientes")
	assert_eq(rm.stage, RestMenu.Stage.MAIN)
	assert_eq(game.state.money, 5)
	assert_eq(game.state.heroes[0].hp, 1, "não curou")

func test_inn_with_money_charges_heals_and_opens_slots() -> void:
	await _enter_area()
	_inn()
	game.state.money = 50
	game.state.heroes[0].hp = 1
	assert_true(map.try_interact())
	var rm: RestMenu = game.rest_menu
	assert_true(rm.entry_enabled(RestMenu.REST_INDEX))
	assert_string_contains(rm.entries()[0], "Descansar")
	rm.accept()
	assert_eq(game.state.money, 30)
	assert_gt(game.state.heroes[0].hp, 1)
	assert_eq(rm.stage, RestMenu.Stage.SLOTS)
	assert_eq(game.state.save_map, &"area_teste")
	assert_eq(game.state.save_spawn, &"RestSpawn")
	assert_eq(game.state.money, 30, "o save do descanso guarda a moeda já cobrada")
	rm.accept()
	assert_eq(game.store.summary(1)["status"], SaveStore.Status.OK)
	rm.cancel()
	rm.cancel()
	assert_false(rm.is_open)

func test_inn_money_after_game_over_restore() -> void:
	await _enter_area()
	_inn()
	game.state.money = 50
	assert_true(map.try_interact())
	game.rest_menu.accept()
	assert_eq(game.state.money, 30)
	game.state.add_money(100)
	game.state.restore_save()
	assert_eq(game.state.money, 30)

func test_rest_point_stays_free() -> void:
	await _enter_area()
	game.state.money = 0
	map.player.global_position = map.rest_point.global_position
	await get_tree().process_frame
	assert_true(map.rest_point.request())
	assert_eq(game.rest_menu.price, 0)
	assert_true(game.rest_menu.entry_enabled(RestMenu.REST_INDEX))
	game.rest_menu.accept()
	assert_eq(game.state.money, 0)
	assert_eq(game.rest_menu.stage, RestMenu.Stage.SLOTS)

# --- moeda no menu de campo e no resultado ------------------------------------------

func test_field_menu_shows_money() -> void:
	await _wait_idle()
	game.state.money = 35
	assert_true(game.open_menu())
	assert_eq(game.menu.party_panel.money_text(), "Moedas: 35")
	game.menu.close()
	game.state.money = 7
	assert_true(game.open_menu())
	assert_eq(game.menu.party_panel.money_text(), "Moedas: 7")
	game.menu.close()

func test_result_screen_shows_money_and_drops() -> void:
	var r := ResultScreen.new()
	add_child_autofree(r)
	var rewards := BattleRewards.new()
	rewards.money = 18
	rewards.add_item(potion, 2)
	rewards.add_equipment(armor, 1)
	var hs: Array[HeroState] = [HeroState.create(Fixtures.hero_def(&"a", Stats.make(1, 1, 3, 2)), Fixtures.cfg())]
	r.show_for({&"a": 5} as Dictionary[StringName, int], {&"a": 1}, hs, rewards, "Moedas")
	var lines: PackedStringArray = r.lines()
	assert_true("+18 Moedas" in lines)
	assert_true("Obteve Poção de Loja x2!" in lines)
	assert_true("Obteve Armadura de Loja!" in lines)

func test_result_screen_without_rewards_has_no_extra_lines() -> void:
	var r := ResultScreen.new()
	add_child_autofree(r)
	var hs: Array[HeroState] = [HeroState.create(Fixtures.hero_def(&"a", Stats.make(1, 1, 3, 2)), Fixtures.cfg())]
	r.show_for({&"a": 5} as Dictionary[StringName, int], {&"a": 1}, hs, BattleRewards.new(), "Moedas")
	assert_eq(r.lines().size(), 2)

extends GutTest

## Economia (M12): moeda no GameState (save e restore), recompensas da batalha (drops pelo Dice) e regras de loja.

const SCENE: String = "res://battle/battle_scene.tscn"

var _potion: ItemDef
var _key: ItemDef
var _sword: EquipmentDef
var _vest: EquipmentDef
var _reg: DefRegistry

func _item(id: StringName, price: int, key: bool = false) -> ItemDef:
	var it := ItemDef.new()
	it.id = id
	it.display_name = String(id)
	it.price = price
	it.key_item = key
	return it

func _eq(id: StringName, slot: StringName, price: int) -> EquipmentDef:
	var e := EquipmentDef.new()
	e.id = id
	e.display_name = String(id)
	e.slot = slot
	e.modifiers = Stats.make(1, 0, 0, 0)
	e.price = price
	return e

func _drop(item: ItemDef, eq: EquipmentDef, chance: float, count: int = 1) -> DropEntry:
	var d := DropEntry.new()
	d.item = item
	d.equipment = eq
	d.chance = chance
	d.count = count
	return d

func _enemy(id: StringName, money: int, drops: Array[DropEntry] = [], role: EnemyDef.Role = EnemyDef.Role.NORMAL) -> Combatant:
	var d: EnemyDef = Fixtures.enemy_def(id, Stats.make(1, 1, 1, 1), 10)
	d.money = money
	d.drops = drops
	d.role = role
	return Combatant.from_enemy(d, id, Vector2.ZERO, Fixtures.cfg())

func _down(c: Combatant) -> Combatant:
	c.hp = 0
	return c

func before_each() -> void:
	_potion = _item(&"potion", 10)
	_key = _item(&"herb", 50, true)
	_sword = _eq(&"sword", &"weapon", 100)
	_vest = _eq(&"vest", &"armor", 61)
	var defs: Array[CharacterDef] = [Fixtures.hero_def(&"a", Stats.make(1, 1, 5, 2))]
	_reg = DefRegistry.create(defs, [_potion, _key] as Array[ItemDef], [_sword, _vest] as Array[EquipmentDef])

func _game(money: int = 0) -> GameState:
	var defs: Array[CharacterDef] = [Fixtures.hero_def(&"a", Stats.make(1, 1, 5, 2))]
	return GameState.new_game(Fixtures.cfg(), defs, [_potion, _key] as Array[ItemDef], [2, 1] as Array[int],
			ScriptedDice.new(), &"overworld", &"Start", 4, [_sword] as Array[EquipmentDef], [1] as Array[int], money)

func _dice(values: Array[float]) -> Dice:
	return ScriptedDice.new(values)

# --- recompensas -----------------------------------------------------------------

func test_rewards_sum_money_of_defeated_enemies_only() -> void:
	var enemies: Array[Combatant] = [_down(_enemy(&"x", 7)), _enemy(&"alive", 100), _down(_enemy(&"y", 5))]
	var r: BattleRewards = BattleRewards.roll(enemies, _dice([]))
	assert_eq(r.money, 12)
	assert_true(r.items.is_empty())

func test_drop_roll_is_deterministic_with_dice() -> void:
	var drops: Array[DropEntry] = [_drop(_potion, null, 0.5), _drop(null, _sword, 0.3)]
	var enemies: Array[Combatant] = [_down(_enemy(&"x", 0, drops))]
	var r: BattleRewards = BattleRewards.roll(enemies, _dice([0.2, 0.9]))
	assert_eq(r.items, [_potion] as Array[ItemDef])
	assert_eq(r.item_counts, [1] as Array[int])
	assert_true(r.equipment.is_empty(), "0.9 >= 0.3: não cai")
	var r2: BattleRewards = BattleRewards.roll(enemies, _dice([0.7, 0.1]))
	assert_true(r2.items.is_empty(), "0.7 >= 0.5: não cai")
	assert_eq(r2.equipment, [_sword] as Array[EquipmentDef])

func test_drops_roll_per_defeated_enemy_and_merge_counts() -> void:
	var drops: Array[DropEntry] = [_drop(_potion, null, 1.0, 2)]
	var enemies: Array[Combatant] = [_down(_enemy(&"x", 0, drops)), _down(_enemy(&"y", 0, drops))]
	var r: BattleRewards = BattleRewards.roll(enemies, _dice([0.0, 0.0]))
	assert_eq(r.items.size(), 1)
	assert_eq(r.item_counts, [4] as Array[int])

func test_same_seed_same_drops() -> void:
	var drops: Array[DropEntry] = [_drop(_potion, null, 0.5)]
	var enemies: Array[Combatant] = []
	for i: int in 8:
		enemies.append(_down(_enemy(StringName("e%d" % i), 1, drops)))
	var a: BattleRewards = BattleRewards.roll(enemies, Dice.new(42))
	var b: BattleRewards = BattleRewards.roll(enemies, Dice.new(42))
	assert_eq(a.item_counts, b.item_counts)
	assert_eq(a.money, 8)

func test_flee_gives_nothing() -> void:
	var drops: Array[DropEntry] = [_drop(_potion, null, 1.0)]
	var enemies: Array[Combatant] = [_down(_enemy(&"x", 9, drops))]
	var r: BattleRewards = BattleRewards.roll(enemies, _dice([0.0]), true)
	assert_true(r.is_empty())

func test_parts_that_fall_with_core_give_rewards() -> void:
	var drops: Array[DropEntry] = [_drop(_potion, null, 1.0)]
	var enemies: Array[Combatant] = [
		_down(_enemy(&"core", 20, [] as Array[DropEntry], EnemyDef.Role.CORE)),
		_down(_enemy(&"arm", 5, drops, EnemyDef.Role.PART)),
	]
	var r: BattleRewards = BattleRewards.roll(enemies, _dice([0.0]))
	assert_eq(r.money, 25)
	assert_eq(r.item_counts, [1] as Array[int])

func test_invalid_drop_entries_are_ignored_without_consuming_dice() -> void:
	var empty := DropEntry.new()
	var zero: DropEntry = _drop(_potion, null, 1.0, 0)
	var ok: DropEntry = _drop(_potion, null, 1.0)
	var enemies: Array[Combatant] = [_down(_enemy(&"x", 0, [empty, zero, ok] as Array[DropEntry]))]
	var r: BattleRewards = BattleRewards.roll(enemies, _dice([0.0]))
	assert_eq(r.item_counts, [1] as Array[int])

func test_apply_adds_to_state_and_lines_text() -> void:
	var g: GameState = _game(5)
	var r := BattleRewards.new()
	r.money = 12
	r.add_item(_potion, 2)
	r.add_equipment(_vest, 1)
	r.apply(g)
	assert_eq(g.money, 17)
	assert_eq(g.inventory.count(&"potion"), 4)
	assert_eq(g.bag.count(&"vest"), 1)
	assert_eq(r.lines("Moedas"), PackedStringArray(["+12 Moedas", "Obteve potion x2!", "Obteve vest!"]))

func test_empty_rewards_have_no_lines() -> void:
	var r := BattleRewards.new()
	assert_true(r.is_empty())
	assert_eq(r.lines("Moedas").size(), 0)

# --- loja ------------------------------------------------------------------------

func test_sell_value_floors_and_respects_ratio() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	assert_eq(cfg.sell_ratio, 0.5)
	assert_eq(ShopRules.sell_value(_vest, cfg), 30, "floor(61 x 0.5)")
	assert_eq(ShopRules.sell_value(_potion, cfg), 5)

func test_buy_item_spends_money_and_adds_stack() -> void:
	var g: GameState = _game(35)
	assert_eq(ShopRules.max_buy(g, _potion), 3)
	assert_true(ShopRules.buy(g, _potion, 3))
	assert_eq(g.money, 5)
	assert_eq(g.inventory.count(&"potion"), 5)
	assert_false(ShopRules.buy(g, _potion, 1), "sem moeda")
	assert_eq(g.money, 5)

func test_buy_equipment_goes_to_bag() -> void:
	var g: GameState = _game(250)
	assert_true(ShopRules.buy(g, _vest, 2))
	assert_eq(g.money, 128)
	assert_eq(g.bag.count(&"vest"), 2)

func test_buy_invalid_amounts_change_nothing() -> void:
	var g: GameState = _game(100)
	assert_false(ShopRules.buy(g, _potion, 0))
	assert_false(ShopRules.buy(g, _potion, -1))
	assert_false(ShopRules.buy(g, _potion, 11), "mais do que a moeda paga")
	assert_eq(g.money, 100)
	assert_eq(g.inventory.count(&"potion"), 2)

func test_buy_is_capped_by_stack_limit() -> void:
	var g: GameState = _game(100000)
	assert_eq(ShopRules.max_buy(g, _potion), 97, "99 - 2 já possuídas")
	assert_false(ShopRules.buy(g, _potion, 98))
	assert_true(ShopRules.buy(g, _potion, 97))
	assert_eq(g.inventory.count(&"potion"), 99)
	assert_eq(ShopRules.max_buy(g, _potion), 0)
	assert_eq(ShopRules.max_buy(g, _sword), 98, "mochila já tem 1 espada")

func test_item_with_zero_price_cannot_be_bought_or_sold() -> void:
	var free: ItemDef = _item(&"free", 0)
	var g: GameState = _game(100)
	g.inventory.add(free, 1)
	assert_eq(ShopRules.max_buy(g, free), 0)
	assert_false(ShopRules.buy(g, free, 1))
	assert_false(ShopRules.can_sell(free, g.cfg))
	assert_false(ShopRules.sell(g, free, 1))
	assert_eq(g.inventory.count(&"free"), 1)

func test_sell_item_adds_floor_value() -> void:
	var g: GameState = _game(0)
	assert_eq(ShopRules.max_sell(g, _potion), 2)
	assert_true(ShopRules.sell(g, _potion, 2))
	assert_eq(g.money, 10)
	assert_eq(g.inventory.count(&"potion"), 0)
	assert_false(ShopRules.sell(g, _potion, 1), "acabou")
	assert_eq(g.money, 10)

func test_key_item_is_not_sellable() -> void:
	var g: GameState = _game(0)
	assert_false(ShopRules.can_sell(_key, g.cfg))
	assert_eq(ShopRules.max_sell(g, _key), 0)
	assert_false(ShopRules.sell(g, _key, 1))
	assert_eq(g.inventory.count(&"herb"), 1)
	assert_eq(g.money, 0)

func test_sell_equipment_from_bag_only_not_worn() -> void:
	var worn: EquipmentDef = _eq(&"worn", &"weapon", 40)
	var d: CharacterDef = Fixtures.hero_def(&"a", Stats.make(1, 1, 5, 2))
	d.starting_equipment = [worn] as Array[EquipmentDef]
	var g: GameState = GameState.new_game(Fixtures.cfg(), [d] as Array[CharacterDef], [] as Array[ItemDef], [] as Array[int],
			ScriptedDice.new(), &"overworld", &"Start", 4, [_sword] as Array[EquipmentDef], [1] as Array[int])
	assert_eq(g.heroes[0].equipment.get(&"weapon"), worn)
	assert_eq(ShopRules.max_sell(g, worn), 0, "vestido não está na mochila")
	assert_false(ShopRules.sell(g, worn, 1))
	assert_eq(g.heroes[0].equipment.get(&"weapon"), worn)
	var sellable: Array[Resource] = ShopRules.sellable(g)
	assert_eq(sellable, [_sword] as Array[Resource])
	assert_true(ShopRules.sell(g, _sword, 1))
	assert_eq(g.money, 50)
	assert_eq(g.bag.count(&"sword"), 0)

func test_sell_ignores_reserved_items() -> void:
	var g: GameState = _game(0)
	assert_true(g.inventory.reserve(&"potion"))
	assert_eq(ShopRules.max_sell(g, _potion), 1)
	assert_false(ShopRules.sell(g, _potion, 2))
	assert_eq(g.inventory.count(&"potion"), 2)

func test_buy_then_sell_conserves_items() -> void:
	var g: GameState = _game(100)
	assert_true(ShopRules.buy(g, _sword, 1))
	assert_eq(g.money, 0)
	assert_true(ShopRules.sell(g, _sword, 2))
	assert_eq(g.bag.count(&"sword"), 0)
	assert_eq(g.money, 100)

func test_spend_money_rejects_overdraft() -> void:
	var g: GameState = _game(10)
	assert_false(g.spend_money(11))
	assert_false(g.spend_money(-1))
	assert_eq(g.money, 10)
	assert_true(g.spend_money(10))
	assert_eq(g.money, 0)

# --- save e restore --------------------------------------------------------------

func test_money_round_trips_through_dict() -> void:
	var g: GameState = _game(73)
	var d: Dictionary = g.to_dict()
	assert_eq(d["money"], 73)
	var back: GameState = GameState.from_dict(JSON.parse_string(JSON.stringify(d)), _reg, Fixtures.cfg(), ScriptedDice.new())
	assert_not_null(back)
	assert_eq(back.money, 73)

func test_zero_money_is_omitted_and_old_saves_load_with_zero() -> void:
	var g: GameState = _game(0)
	var d: Dictionary = g.to_dict()
	assert_false(d.has("money"))
	var back: GameState = GameState.from_dict(d, _reg, Fixtures.cfg(), ScriptedDice.new())
	assert_eq(back.money, 0)

func test_invalid_money_field_is_ignored() -> void:
	var d: Dictionary = _game(5).to_dict()
	d["money"] = "muito"
	var back: GameState = GameState.from_dict(d, _reg, Fixtures.cfg(), ScriptedDice.new())
	assert_not_null(back)
	assert_eq(back.money, 0)
	d["money"] = -40
	assert_eq(GameState.from_dict(d, _reg, Fixtures.cfg(), ScriptedDice.new()).money, 0)

func test_restore_returns_money_to_saved_value() -> void:
	var g: GameState = _game(50)
	g.add_money(30)
	assert_eq(g.money, 80)
	g.restore_save()
	assert_eq(g.money, 50, "voltou ao valor do último save")
	g.add_money(5)
	g.save(&"overworld", &"Start")
	g.spend_money(55)
	g.restore_save()
	assert_eq(g.money, 55)

func test_new_game_without_money_starts_at_zero() -> void:
	var defs: Array[CharacterDef] = [Fixtures.hero_def(&"a", Stats.make(1, 1, 5, 2))]
	var g: GameState = GameState.new_game(Fixtures.cfg(), defs, [] as Array[ItemDef], [] as Array[int], ScriptedDice.new(), &"overworld", &"Start")
	assert_eq(g.money, 0)

# --- cena de batalha -------------------------------------------------------------

func _scene(enemies: Array[EnemyDef], g: GameState) -> BattleScene:
	var s: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	s.balance = Fixtures.cfg()
	s.auto_battle = true
	s.dice_seed = 7
	s.enemy_defs = enemies
	s.game_state = g
	add_child_autofree(s)
	s.set_process(false)
	return s

func _hero_states() -> Array[HeroState]:
	var out: Array[HeroState] = []
	for id: String in ["teste_a", "teste_b", "teste_c"]:
		out.append(HeroState.create(load("res://data/test/heroes/%s.tres" % id) as CharacterDef, Fixtures.cfg()))
	return out

func _run_to_end(s: BattleScene) -> void:
	var steps: int = 0
	while s.ctrl.outcome == BattleController.Outcome.ONGOING and steps < 20000:
		s.ctrl.tick(0.1)
		steps += 1

func _weak_enemies(money: int) -> Array[EnemyDef]:
	var d: EnemyDef = Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 0), 100)
	d.money = money
	d.drops = [_drop(_potion, null, 1.0, 2)] as Array[DropEntry]
	return [d] as Array[EnemyDef]

func test_victory_applies_money_and_drops_and_shows_them() -> void:
	var g: GameState = _game(10)
	var s: BattleScene = _scene(_weak_enemies(15), g)
	s.start(_hero_states())
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.VICTORY)
	assert_eq(g.money, 25)
	assert_eq(g.inventory.count(&"potion"), 4)
	var text: String = "\n".join((s.get_node("UI/ResultScreen") as ResultScreen).lines())
	assert_string_contains(text, "+15 Moedas")
	assert_string_contains(text, "Obteve potion x2!")

func test_game_over_restore_discards_battle_money() -> void:
	var g: GameState = _game(10)
	var s: BattleScene = _scene(_weak_enemies(15), g)
	s.start(_hero_states())
	_run_to_end(s)
	assert_eq(g.money, 25)
	g.restore_save()
	assert_eq(g.money, 10)
	assert_eq(g.inventory.count(&"potion"), 2)

func test_defeat_gives_no_money() -> void:
	var g: GameState = _game(10)
	var d: EnemyDef = Fixtures.enemy_def(&"x", Stats.make(80, 40, 60, 0), 100)
	d.money = 99
	var s: BattleScene = _scene([d] as Array[EnemyDef], g)
	s.start(_hero_states())
	_run_to_end(s)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.DEFEAT)
	assert_eq(g.money, 10)

extends GutTest

## Iniciativa por contato (M7): classify, ATB inicial de cada tipo e aplicação pelo mapa.

const LOCAL_SCENE: String = "res://world/local_map.tscn"
const HEROES: Array[String] = ["teste_a", "teste_b", "teste_c"]
const ANGLE: float = 120.0

func _classify(facing: Vector2, chasing: bool, player: Vector2) -> Initiative.Kind:
	return Initiative.classify(Vector2.ZERO, facing, chasing, player, ANGLE)

func test_classify_front_is_normal() -> void:
	assert_eq(_classify(Vector2.RIGHT, false, Vector2(100, 0)), Initiative.Kind.NORMAL)

func test_classify_behind_is_preemptive() -> void:
	assert_eq(_classify(Vector2.RIGHT, false, Vector2(-100, 0)), Initiative.Kind.PREEMPTIVE)

func test_classify_angle_limits() -> void:
	var past: Vector2 = Vector2.from_angle(deg_to_rad(121.0)) * 100.0
	var before: Vector2 = Vector2.from_angle(deg_to_rad(119.0)) * 100.0
	assert_eq(_classify(Vector2.RIGHT, false, before), Initiative.Kind.NORMAL)
	assert_eq(_classify(Vector2.RIGHT, false, past), Initiative.Kind.PREEMPTIVE)
	assert_eq(_classify(Vector2.RIGHT, false, Vector2(past.x, -past.y)), Initiative.Kind.PREEMPTIVE, "simetrico")

func test_classify_chasing_is_ambush_even_from_behind() -> void:
	assert_eq(_classify(Vector2.RIGHT, true, Vector2(-100, 0)), Initiative.Kind.AMBUSH)
	assert_eq(_classify(Vector2.ZERO, true, Vector2(50, 0)), Initiative.Kind.AMBUSH)

func test_classify_no_facing_is_normal() -> void:
	assert_eq(_classify(Vector2.ZERO, false, Vector2(-100, 0)), Initiative.Kind.NORMAL)

func _state() -> BattleState:
	var cfg := Fixtures.cfg()
	var h := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1)), cfg), Vector2.ZERO)
	var e := Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(10, 5, 5, 5)), &"x", Vector2.ZERO, cfg)
	h.atb = 0.4
	e.atb = 0.3
	var hs: Array[Combatant] = [h]
	var es: Array[Combatant] = [e]
	return BattleState.create(cfg, ScriptedDice.new(), hs, es)

func test_preemptive_heroes_full_enemies_zero() -> void:
	var b := _state()
	b.apply_initiative(Initiative.Kind.PREEMPTIVE)
	assert_eq(b.heroes[0].atb, 1.0)
	assert_eq(b.enemies[0].atb, 0.0)
	assert_true(b.queue.has(b.heroes[0]))
	assert_false(b.queue.has(b.enemies[0]))

func test_ambush_enemies_full_heroes_zero() -> void:
	var b := _state()
	b.apply_initiative(Initiative.Kind.AMBUSH)
	assert_eq(b.enemies[0].atb, 1.0)
	assert_eq(b.heroes[0].atb, 0.0)
	assert_true(b.queue.has(b.enemies[0]))

func test_normal_changes_nothing() -> void:
	var b := _state()
	b.apply_initiative(Initiative.Kind.NORMAL)
	assert_eq(b.heroes[0].atb, 0.4)
	assert_eq(b.enemies[0].atb, 0.3)
	assert_false(b.queue.has(b.heroes[0]))

func test_preemptive_hero_acts_on_first_tick() -> void:
	var b := _state()
	b.apply_initiative(Initiative.Kind.PREEMPTIVE)
	var ctrl := BattleController.new(b)
	var turns: Array[int] = []
	ctrl.hero_turn.connect(func(_s: SelectionSession) -> void: turns.append(1))
	ctrl.tick(0.05)
	assert_eq(turns.size(), 1)

func test_banner_texts() -> void:
	assert_eq(BattleScene.banner_text(Initiative.Kind.PREEMPTIVE), "Ataque surpresa!")
	assert_eq(BattleScene.banner_text(Initiative.Kind.AMBUSH), "Emboscada!")
	assert_eq(BattleScene.banner_text(Initiative.Kind.NORMAL), "")

# --- No mapa --------------------------------------------------------------------------

func _map() -> LocalMap:
	var cfg: BalanceConfig = load("res://data/test/balance.tres") as BalanceConfig
	var defs: Array[CharacterDef] = []
	for id: String in HEROES:
		defs.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	var st := GameState.new_game(cfg, defs, items, counts, Dice.new(7), &"local", &"Entry")
	var m: LocalMap = (load(LOCAL_SCENE) as PackedScene).instantiate() as LocalMap
	m.dice_seed = 7
	add_child_autofree(m)
	m.setup(st, &"Entry")
	return m

func _touch(m: LocalMap, facing: Vector2, player_pos: Vector2) -> BattleScene:
	var enemy: MapEnemy = m.get_node("Enemy") as MapEnemy
	enemy.facing = facing
	m.player.global_position = player_pos
	enemy.touched.emit(enemy)
	m.battle.set_process(false)
	return m.battle

func test_map_touch_from_behind_is_preemptive() -> void:
	var m := _map()
	var e: MapEnemy = m.get_node("Enemy") as MapEnemy
	var s := _touch(m, Vector2.RIGHT, e.global_position + Vector2(-30, 0))
	for h: Combatant in s.ctrl.b.heroes:
		assert_eq(h.atb, 1.0)
	for en: Combatant in s.ctrl.b.enemies:
		assert_eq(en.atb, 0.0)
	assert_true(s.banner_visible())

func test_map_touch_front_is_normal() -> void:
	var m := _map()
	var e: MapEnemy = m.get_node("Enemy") as MapEnemy
	var s := _touch(m, Vector2.RIGHT, e.global_position + Vector2(30, 0))
	assert_false(s.banner_visible())
	for h: Combatant in s.ctrl.b.heroes:
		assert_lt(h.atb, 1.0)

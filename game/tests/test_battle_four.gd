extends GutTest

## Batalhas com até 4 heróis: cena isolada (4 primeiros test_heroes) e mapa (formação ativa em ordem).

const BATTLE: String = "res://battle/battle_scene.tscn"
const MAP: String = "res://world/local_map.tscn"
const FIVE: Array[String] = ["teste_a", "teste_b", "teste_c", "teste_d", "teste_e"]

func _defs(ids: Array[String]) -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for id: String in ids:
		out.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	return out

func _map(state: GameState) -> LocalMap:
	var map: LocalMap = (load(MAP) as PackedScene).instantiate() as LocalMap
	map.auto_battle = true
	map.dice_seed = 7
	add_child_autofree(map)
	map.setup(state, &"Entry")
	return map

func _touch(map: LocalMap) -> BattleScene:
	var e := EncounterDef.new()
	e.id = &"teste"
	var list: Array[EnemyDef] = [Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 0), 100)]
	e.enemies = list
	var enemy: MapEnemy = map.get_node("Enemy") as MapEnemy
	enemy.encounter = e
	enemy.touched.emit(enemy)
	assert_not_null(map.battle, "batalha começou")
	map.battle.set_process(false)
	return map.battle

func _ids(b: BattleState) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Combatant in b.heroes:
		out.append(c.hero_state.def.id)
	return out

func test_standalone_battle_has_four_heroes_at_spots() -> void:
	var s: BattleScene = (load(BATTLE) as PackedScene).instantiate() as BattleScene
	add_child_autofree(s)
	s.set_process(false)
	await wait_process_frames(2)
	assert_eq(s.test_heroes.size(), 4, "teste_e fica fora da batalha isolada")
	var b: BattleState = s.ctrl.b
	assert_eq(b.heroes.size(), 4)
	for i: int in 4:
		assert_eq(b.heroes[i].hero_state.def.id, s.test_heroes[i].id)
		assert_eq(b.heroes[i].position, (s.get_node("HeroSpot%d" % (i + 1)) as Marker2D).position)

func test_battle_uses_formation_order() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var state: GameState = GameState.new_game(cfg, _defs(FIVE), [] as Array[ItemDef], [] as Array[int],
			Dice.new(7), &"local", &"Entry")
	assert_eq(state.heroes.size(), 4)
	assert_eq(state.reserve.size(), 1)
	assert_true(state.swap(state.heroes[0], state.heroes[3]))
	var expected: Array[StringName] = []
	for h: HeroState in state.heroes:
		expected.append(h.def.id)
	var map: LocalMap = _map(state)
	var s: BattleScene = _touch(map)
	var b: BattleState = s.ctrl.b
	assert_eq(_ids(b), expected, "ordem da formação")
	assert_eq(expected[0], &"teste_d")
	var spots: Array[Vector2] = (map.get_node("Arena") as BattleArena).hero_positions()
	assert_eq(spots.size(), 4)
	for i: int in 4:
		assert_eq(b.heroes[i].position, spots[i])
	var reserve_h: HeroState = state.reserve[0]
	for c: Combatant in b.all():
		assert_ne(c.hero_state, reserve_h, "reserva não luta")
	# Vitória: reserva não ganha XP.
	var xp_before: int = reserve_h.xp
	var steps: int = 0
	while s.ctrl.outcome == BattleController.Outcome.ONGOING and steps < 20000:
		s.ctrl.tick(0.1)
		steps += 1
	assert_eq(s.ctrl.outcome, BattleController.Outcome.VICTORY)
	assert_false(s.last_xp.has(reserve_h.def.id), "reserva fora do XP")
	assert_eq(reserve_h.xp, xp_before)
	assert_true(s.last_xp.size() > 0)

func test_battle_with_two_actives_uses_first_two_spots() -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var state: GameState = GameState.new_game(cfg, _defs(["teste_a", "teste_b"] as Array[String]),
			[] as Array[ItemDef], [] as Array[int], Dice.new(7), &"local", &"Entry")
	var map: LocalMap = _map(state)
	var s: BattleScene = _touch(map)
	var b: BattleState = s.ctrl.b
	assert_eq(b.heroes.size(), 2)
	var spots: Array[Vector2] = (map.get_node("Arena") as BattleArena).hero_positions()
	assert_eq(b.heroes[0].position, spots[0])
	assert_eq(b.heroes[1].position, spots[1])

func _assert_fit(spots: Array[Vector2], center_y: float, label: String) -> void:
	assert_eq(spots.size(), 4, label)
	for i: int in spots.size():
		assert_between(spots[i].y, center_y - 360.0, center_y + 360.0, "%s %d na tela" % [label, i])
		for j: int in range(i + 1, spots.size()):
			assert_gte(absf(spots[i].y - spots[j].y), 150.0, "%s %d/%d separados" % [label, i, j])

func test_four_heroes_fit_on_screen_without_overlap() -> void:
	var s: BattleScene = (load(BATTLE) as PackedScene).instantiate() as BattleScene
	s.auto_battle = true
	add_child_autofree(s)
	s.set_process(false)
	var bs: Array[Vector2] = []
	for i: int in 4:
		var n: String = "HeroSpot%d" % (i + 1)
		assert_true(s.has_node(n), n)
		if s.has_node(n):
			bs.append((s.get_node(n) as Marker2D).position)
	_assert_fit(bs, 360.0, "batalha")
	var map: LocalMap = (load(MAP) as PackedScene).instantiate() as LocalMap
	add_child_autofree(map)
	var arena: BattleArena = map.get_node("Arena") as BattleArena
	_assert_fit(arena.hero_positions(), arena.center().y, "arena")

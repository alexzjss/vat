extends GutTest

## Terreno/clima (M15): TerrainDef multiplica o dano elemental dos dois lados, depois da afinidade e antes do escudo.
## Absorção, golpe neutro e Radioativo não são afetados; terreno nulo não muda nada.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

var _fire: ElementDef
var _water: ElementDef
var _rad: ElementDef

func before_each() -> void:
	_fire = _el(&"fire")
	_water = _el(&"water")
	_rad = _el(&"rad", ElementDef.Rule.RADIOACTIVE)

func after_each() -> void:
	Input.flush_buffered_events()
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _el(id: StringName, rule: ElementDef.Rule = ElementDef.Rule.NORMAL) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	e.display_name = String(id)
	e.rule = rule
	return e

func _terrain(mults: Dictionary[StringName, float], name: String = "Chuva") -> TerrainDef:
	var t := TerrainDef.new()
	t.id = &"rain"
	t.display_name = name
	t.element_mult = mults
	return t

func _rain() -> TerrainDef:
	var m: Dictionary[StringName, float] = {&"fire": 0.5, &"water": 1.5, &"rad": 2.0}
	return _terrain(m)

## Um herói e um inimigo com muita vida (os golpes nunca matam); o inimigo pode ter resistência de elemento.
func _battle(terrain: TerrainDef, resist_fire: float = 0.0) -> BattleState:
	var cfg: BalanceConfig = Fixtures.cfg()
	var h: Combatant = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(120, 0, 5, 4)), cfg), Vector2(0, 0))
	var x: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(120, 0, 5, 1)), &"x", Vector2(100, 0), cfg)
	if resist_fire != 0.0:
		h.element_resist[&"fire"] = resist_fire
		x.element_resist[&"fire"] = resist_fire
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	b.terrain = terrain
	return b

func _ability(element: ElementDef, potency: float = 3.0) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(potency)
	a.element = element
	return a

## Dano (HP perdido) de `actor` em `target` com o elemento; quem ataca e quem apanha escolhidos pelo time.
func _loss(b: BattleState, from_hero: bool, element: ElementDef) -> int:
	var actor: Combatant = b.heroes[0] if from_hero else b.enemies[0]
	var target: Combatant = b.enemies[0] if from_hero else b.heroes[0]
	target.hp = 100000
	var before: int = target.hp
	var a := PendingAction.new()
	a.actor = actor
	a.ability = _ability(element)
	a.center = target
	a.center_pos = target.position
	ActionExecutor.apply(a, b)
	return before - target.hp

func test_multiplier_applies_to_the_hero_side() -> void:
	var base: int = _loss(_battle(null), true, _fire)
	var low: int = _loss(_battle(_rain()), true, _fire)
	assert_gt(base, 4, "dano base grande o bastante para o teste")
	assert_eq(low, maxi(1, floori(float(base) * 0.5)), "Fogo na chuva: x0.5")
	var water_base: int = _loss(_battle(null), true, _water)
	assert_eq(_loss(_battle(_rain()), true, _water), maxi(1, floori(float(water_base) * 1.5)), "Água na chuva: x1.5")

func test_multiplier_applies_to_the_enemy_side_too() -> void:
	var base: int = _loss(_battle(null), false, _water)
	assert_eq(_loss(_battle(_rain()), false, _water), maxi(1, floori(float(base) * 1.5)))
	var fire_base: int = _loss(_battle(null), false, _fire)
	assert_eq(_loss(_battle(_rain()), false, _fire), maxi(1, floori(float(fire_base) * 0.5)))

func test_element_without_an_entry_is_unchanged() -> void:
	var other: ElementDef = _el(&"earth")
	assert_eq(_loss(_battle(_rain()), true, other), _loss(_battle(null), true, other))

func test_null_terrain_changes_nothing() -> void:
	assert_eq(_loss(_battle(null), true, _water), _loss(_battle(_terrain({} as Dictionary[StringName, float])), true, _water), "terreno sem entradas = sem terreno")
	var b: BattleState = _battle(null)
	assert_null(b.terrain)
	assert_eq(ElementMath.apply_terrain(10, _water, null), 10)

func test_neutral_hit_is_unchanged() -> void:
	assert_eq(_loss(_battle(_rain()), true, null), _loss(_battle(null), true, null), "sem elemento")

func test_radioactive_ignores_terrain() -> void:
	assert_eq(_loss(_battle(_rain()), true, _rad), _loss(_battle(null), true, _rad), "Radioativo ignora o terreno, como a afinidade")

func test_terrain_comes_after_affinity() -> void:
	# O alvo é fraco a Fogo (-0.5): afinidade primeiro (x1.5), depois o terreno (x0.5), cada um arredondado para baixo.
	var weak: int = _loss(_battle(null, -0.5), true, _fire)
	var weak_rain: int = _loss(_battle(_rain(), -0.5), true, _fire)
	assert_eq(weak_rain, maxi(1, floori(float(weak) * 0.5)))

func test_absorb_heal_is_not_multiplied() -> void:
	var plain: BattleState = _battle(null, 1.5)
	var rainy: BattleState = _battle(_rain(), 1.5)
	var gains: Array[int] = []
	for b: BattleState in [plain, rainy] as Array[BattleState]:
		var target: Combatant = b.enemies[0]
		target.hp = 10
		var a := PendingAction.new()
		a.actor = b.heroes[0]
		a.ability = _ability(_fire, 0.2)
		a.center = target
		a.center_pos = target.position
		ActionExecutor.apply(a, b)
		gains.append(target.hp - 10)
	assert_gt(gains[0], 0, "absorveu")
	assert_lt(gains[0], StatCalculator.hp_max(plain.enemies[0], plain.cfg) - 10, "abaixo do teto de HP (o teste enxerga a diferença)")
	assert_eq(gains[1], gains[0], "a cura da absorção não muda com o terreno")

func test_immune_stays_zero() -> void:
	var b: BattleState = _battle(_terrain({&"fire": 2.0} as Dictionary[StringName, float]), 1.0)
	assert_eq(_loss(b, true, _fire), 0)

func test_zero_multiplier_zeroes_the_hit() -> void:
	var b: BattleState = _battle(_terrain({&"fire": 0.0} as Dictionary[StringName, float]))
	assert_eq(_loss(b, true, _fire), 0)

func test_terrain_def_mult_for() -> void:
	var t: TerrainDef = _rain()
	assert_eq(t.mult_for(_fire), 0.5)
	assert_eq(t.mult_for(null), 1.0)
	assert_eq(t.mult_for(_el(&"earth")), 1.0)

# --- mapa e batalha -------------------------------------------------------------

func _weak_encounter() -> EncounterDef:
	var e := EncounterDef.new()
	e.id = &"fraco"
	var list: Array[EnemyDef] = []
	list.append(Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 0), 100))
	e.enemies = list
	return e

func _map_in_game() -> LocalMap:
	var game: Game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.skip_title = true
	add_child_autofree(game)
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	guard = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1
	return game.current as LocalMap

func test_map_terrain_reaches_the_battle_and_its_corner_label() -> void:
	var map: LocalMap = await _map_in_game()
	var t: TerrainDef = _rain()
	map.terrain = t
	map.start_event_battle(_weak_encounter())
	assert_not_null(map.battle)
	assert_eq(map.battle.ctrl.b.terrain, t, "o BattleState recebe o terreno")
	assert_eq(map.battle.terrain_text_shown(), "Terreno: Chuva")

func test_map_without_terrain_shows_no_label() -> void:
	var map: LocalMap = await _map_in_game()
	assert_null(map.terrain, "o mapa de teste não tem terreno")
	map.start_event_battle(_weak_encounter())
	assert_not_null(map.battle)
	assert_null(map.battle.ctrl.b.terrain)
	assert_eq(map.battle.terrain_text_shown(), "")

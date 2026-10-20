extends GutTest

## Chefe de teste da dungeon (M11): definição, aparece só depois da flag da cena final, não volta depois de derrotado,
## sobrevive ao save e não deixa fugir. Também a batalha completa pelos sinais do controlador.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves_boss/"
const ENCOUNTER: String = "res://data/test/encounters/chefe_dungeon.tres"

var game: Game
var map: LocalMap

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

func _enter_dungeon() -> void:
	await _wait_idle()
	(game.current as Overworld).location_entered.emit(&"dungeon_teste")
	await _wait_idle()
	map = game.current as LocalMap

func _boss() -> MapEnemy:
	return map.get_node_or_null("Boss") as MapEnemy

func _touch_boss() -> BattleScene:
	var boss: MapEnemy = _boss()
	boss.touched.emit(boss)
	assert_not_null(map.battle)
	map.battle.set_process(false)
	return map.battle

func _accept_all(s: BattleScene) -> void:
	var result: ResultScreen = s.get_node("UI/ResultScreen") as ResultScreen
	var level_up: LevelUpScreen = s.get_node("UI/LevelUpScreen") as LevelUpScreen
	result.accept()
	var guard: int = 0
	while level_up.visible and guard < 10:
		level_up.leave()
		guard += 1
	result.accept()

func _enc() -> EncounterDef:
	return load(ENCOUNTER) as EncounterDef

func test_encounter_has_a_core_two_shielding_arms_and_no_escape() -> void:
	var e: EncounterDef = _enc()
	assert_false(e.can_flee)
	assert_eq(e.unique_id, &"chefe_dungeon")
	assert_eq(e.enemies.size(), 3)
	var roles: Array[int] = []
	for d: EnemyDef in e.enemies:
		roles.append(d.role)
	roles.sort()
	assert_eq(roles, [1, 2, 2], "um nucleo e duas partes")
	for d: EnemyDef in e.enemies:
		if d.role == EnemyDef.Role.PART:
			assert_true(d.shields_core)

func test_core_has_phases_telegraph_counter_and_revive() -> void:
	var core: EnemyDef = null
	for d: EnemyDef in _enc().enemies:
		if d.role == EnemyDef.Role.CORE:
			core = d
	assert_eq(core.phases.size(), 2)
	assert_eq(core.phases[0].hp_below, 0.66)
	assert_eq(core.phases[1].hp_below, 0.33)
	assert_not_null(core.counter)
	assert_true(core.counter_only_basic)
	var tele: bool = false
	for r: AiRule in core.phases[1].ai_rules:
		tele = tele or (r.telegraph and r.ability.id == &"golpe_sismico" and r.ability.shape == AbilityDef.Shape.ALL)
	assert_true(tele, "fase 3: Golpe Sismico anunciado em area")
	var revives: bool = false
	for r: AiRule in core.phases[0].ai_rules:
		revives = revives or r.condition == AiRule.Condition.PART_DOWN
	assert_true(revives, "fase 2 reergue os bracos")
	var applied: Array[StringName] = []
	for r: AiRule in core.phases[0].ai_rules:
		applied.append(r.ability.id)
	for id: StringName in [&"silencio", &"cegueira", &"confusao"]:
		assert_true(applied.has(id), String(id))
	var stops: bool = false
	for r: AiRule in core.phases[1].ai_rules:
		stops = stops or r.ability.id == &"pare"
	assert_true(stops)

func test_boss_is_hidden_until_the_final_scene_flag() -> void:
	await _enter_dungeon()
	var boss: MapEnemy = _boss()
	assert_not_null(boss)
	await get_tree().physics_frame
	assert_false(boss.visible)
	assert_false(boss.gate_open())
	boss._touch_armed = true
	boss._emit_touch()
	assert_null(map.battle, "escondido: o toque nao conta")
	game.state.set_flag(&"cena_final", 1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(boss.visible)
	assert_true(boss.gate_open())
	assert_eq(boss.global_position, (map.get_node("BossSpot") as Node2D).global_position, "no BossSpot")

func test_boss_battle_cannot_be_fled() -> void:
	await _enter_dungeon()
	game.state.set_flag(&"cena_final", 1)
	await get_tree().physics_frame
	var s: BattleScene = _touch_boss()
	assert_false(s.ctrl.can_flee)
	s.ctrl.update_flee(5.0, true)
	assert_eq(s.ctrl.flee_gauge, 0.0)
	assert_eq(s.ctrl.b.enemies.size(), 3)

func test_victory_by_the_core_credits_the_parts_xp_and_marks_the_boss() -> void:
	await _enter_dungeon()
	game.state.set_flag(&"cena_final", 1)
	await get_tree().physics_frame
	var s: BattleScene = _touch_boss()
	var b: BattleState = s.ctrl.b
	# Os herois machucam todos (a contribuicao define o XP); o nucleo cai por ultimo e leva as partes.
	var hero: Combatant = b.heroes[0]
	var total_xp_base: int = 0
	for e: Combatant in b.enemies:
		b.ledger.add(hero.id, e.id, 10.0)
		total_xp_base += e.enemy_def.xp_base
	for e: Combatant in b.enemies:
		if e.enemy_def.role == EnemyDef.Role.CORE:
			e.hp = 0
	b.collapse_parts()
	for i: int in 5:
		s.ctrl.tick(0.1)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.VICTORY)
	for e: Combatant in b.enemies:
		assert_true(e.is_down())
	assert_eq(s.last_xp[hero.id], total_xp_base, "nucleo e as duas partes dao XP")
	_accept_all(s)
	assert_true(game.state.is_defeated(&"chefe_dungeon"))
	await get_tree().process_frame
	assert_null(_boss(), "o chefe some do mapa")

func test_defeated_boss_does_not_come_back() -> void:
	await _enter_dungeon()
	game.state.mark_defeated(&"chefe_dungeon")
	map.exit_requested.emit()
	await _wait_idle()
	(game.current as Overworld).location_entered.emit(&"dungeon_teste")
	await _wait_idle()
	map = game.current as LocalMap
	assert_null(_boss())

func test_defeated_boss_survives_save_and_load() -> void:
	await _enter_dungeon()
	game.state.mark_defeated(&"chefe_dungeon")
	map.player.global_position = (map.get_node("RestPoint") as Node2D).global_position
	assert_true(game.can_save())
	assert_true(game.save_to_slot(1))
	assert_true(game.continue_from_slot(1))
	await _wait_idle()
	map = game.current as LocalMap
	assert_eq(game.current_map, &"dungeon_teste")
	assert_true(game.state.is_defeated(&"chefe_dungeon"))
	assert_null(_boss())

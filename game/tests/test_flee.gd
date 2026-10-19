extends GutTest

## Fuga (M7): barra em tempo real, FLED só entre ações, reembolso, sem XP e consequências no mapa.

const HERO_IDS: Array[StringName] = [&"a", &"b"]
const ENEMY_IDS: Array[StringName] = [&"x", &"y"]
const HEROES: Array[String] = ["teste_a", "teste_b", "teste_c"]
const LOCAL_SCENE: String = "res://world/local_map.tscn"

var _log: Array[String] = []
var _ended: Array[BattleController.Outcome] = []

func before_each() -> void:
	_log = []
	_ended = []

func _battle(hero_speeds: Array[int], enemy_speeds: Array[int], active: bool = true) -> BattleController:
	var cfg := Fixtures.cfg()
	var heroes: Array[Combatant] = []
	for i: int in hero_speeds.size():
		var hs := HeroState.create(Fixtures.hero_def(HERO_IDS[i], Stats.make(10, hero_speeds[i], 5, 1)), cfg)
		heroes.append(Combatant.from_hero(hs, Vector2.ZERO))
	var enemies: Array[Combatant] = []
	for i: int in enemy_speeds.size():
		var d := Fixtures.enemy_def(ENEMY_IDS[i], Stats.make(10, enemy_speeds[i], 5, 5))
		enemies.append(Combatant.from_enemy(d, ENEMY_IDS[i], Vector2.ZERO, cfg))
	var b := BattleState.create(cfg, ScriptedDice.new(), heroes, enemies)
	var ctrl := BattleController.new(b)
	ctrl.active_mode = active
	ctrl.action_finished.connect(func(a: PendingAction) -> void: _log.append("finished:%s" % a.actor.id))
	ctrl.battle_ended.connect(func(o: BattleController.Outcome) -> void: _ended.append(o))
	return ctrl

func _until(ctrl: BattleController, cond: Callable, max_ticks: int = 600) -> bool:
	for i: int in max_ticks:
		if cond.call():
			return true
		ctrl.tick(0.05)
	return cond.call()

# --- Controlador ----------------------------------------------------------------------

func test_gauge_fills_by_speed_ratio() -> void:
	var ctrl := _battle([10, 10], [5])
	var cfg: BalanceConfig = ctrl.b.cfg
	var hs: float = StatCalculator.effective(ctrl.b.heroes[0], &"speed", cfg)
	var es: float = StatCalculator.effective(ctrl.b.enemies[0], &"speed", cfg)
	var expected: float = cfg.flee_base_rate * (hs + 1.0) / (es + 1.0)
	ctrl.update_flee(1.0, true)
	assert_almost_eq(ctrl.flee_gauge, minf(1.0, expected), 0.0001)
	assert_gt(expected, cfg.flee_base_rate, "herois mais rapidos fogem mais depressa")

func test_gauge_is_slower_against_faster_enemies() -> void:
	var fast := _battle([5], [10])
	var slow := _battle([10], [5])
	fast.update_flee(1.0, true)
	slow.update_flee(1.0, true)
	assert_lt(fast.flee_gauge, slow.flee_gauge)

func test_gauge_drains_on_release() -> void:
	var ctrl := _battle([10], [5])
	ctrl.update_flee(1.0, true)
	var g: float = ctrl.flee_gauge
	assert_gt(g, 0.0)
	ctrl.update_flee(0.4, false)
	assert_almost_eq(ctrl.flee_gauge, g - ctrl.b.cfg.flee_decay * 0.4, 0.0001)
	ctrl.update_flee(10.0, false)
	assert_eq(ctrl.flee_gauge, 0.0)

func test_blocked_when_cannot_flee() -> void:
	var ctrl := _battle([10], [5])
	ctrl.can_flee = false
	ctrl.update_flee(100.0, true)
	assert_eq(ctrl.flee_gauge, 0.0)
	assert_eq(ctrl.outcome, BattleController.Outcome.ONGOING)

func test_full_gauge_flees_when_idle_and_closes_session() -> void:
	var ctrl := _battle([20], [10], false)
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_not_null(ctrl.session)
	# Modo Espera: o tempo da batalha está parado, mas a barra corre em tempo real.
	ctrl.update_flee(100.0, true)
	assert_eq(ctrl.outcome, BattleController.Outcome.FLED)
	assert_null(ctrl.session)
	assert_eq(_ended.size(), 1)
	assert_eq(_ended[0], BattleController.Outcome.FLED)

func test_flee_waits_for_running_action_then_refunds_queued() -> void:
	var ctrl := _battle([20], [10])
	var a: Combatant = ctrl.b.heroes[0]
	assert_true(_until(ctrl, func() -> bool: return ctrl.session != null))
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing != null))
	var foe_action: PendingAction = ctrl.executing
	var potion := ItemDef.new()
	potion.id = &"potion"
	potion.display_name = "Pocao"
	var fx := EffectDef.new()
	fx.kind = EffectDef.Kind.HEAL
	fx.scale = EffectDef.Scale.FIXED
	fx.potency = 10.0
	potion.effects = [fx]
	ctrl.b.inventory.add(potion, 2)
	var s: SelectionSession = ctrl.session
	assert_true(s.choose_item(potion))
	s.set_center(a)
	ctrl.submit(s.confirm())
	assert_eq(ctrl.b.inventory.available(&"potion"), 1)
	ctrl.update_flee(100.0, true)
	assert_eq(ctrl.outcome, BattleController.Outcome.ONGOING, "ação em execução termina primeiro")
	assert_eq(ctrl.executing, foe_action)
	assert_true(_until(ctrl, func() -> bool: return ctrl.outcome == BattleController.Outcome.FLED))
	assert_true(_log.has("finished:x"), "a ação em curso foi até o fim")
	assert_eq(ctrl.b.inventory.available(&"potion"), 2, "ação enfileirada reembolsada")
	assert_null(ctrl._queued)

func test_flee_keeps_hp() -> void:
	var ctrl := _battle([20], [10])
	var hp: int = ctrl.b.heroes[0].hp
	ctrl.update_flee(100.0, true)
	assert_eq(ctrl.outcome, BattleController.Outcome.FLED)
	assert_eq(ctrl.b.heroes[0].hp, hp)

# --- Mapa -----------------------------------------------------------------------------

func _map() -> LocalMap:
	var cfg: BalanceConfig = Fixtures.cfg()
	var defs: Array[CharacterDef] = []
	for id: String in HEROES:
		defs.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	var st := GameState.new_game(cfg, defs, items, counts, Dice.new(7), &"local", &"Entry")
	var m: LocalMap = (load(LOCAL_SCENE) as PackedScene).instantiate() as LocalMap
	m.auto_battle = true
	m.dice_seed = 7
	add_child_autofree(m)
	m.setup(st, &"Entry")
	return m

func _encounter(can_flee: bool) -> EncounterDef:
	var e := EncounterDef.new()
	e.id = &"teste"
	e.can_flee = can_flee
	var list: Array[EnemyDef] = [Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 0), 100)]
	e.enemies = list
	return e

func _touch(m: LocalMap, enc: EncounterDef) -> BattleScene:
	var enemy: MapEnemy = m.get_node("Enemy") as MapEnemy
	enemy.encounter = enc
	enemy.touched.emit(enemy)
	m.battle.set_process(false)
	return m.battle

func test_map_flee_returns_player_keeps_enemy_with_cooldown_and_no_xp() -> void:
	var m := _map()
	var player: Player = m.get_node("Player") as Player
	var enemy: MapEnemy = m.get_node("Enemy") as MapEnemy
	player.global_position = Vector2(1500, 300)
	var xp0: int = m.state.heroes[0].xp
	var s := _touch(m, _encounter(true))
	assert_true(s.ctrl.can_flee)
	s.flee_input_override = 1
	s.update_flee(100.0)
	assert_null(m.battle, "a batalha acabou")
	assert_eq(player.global_position, Vector2(1500, 300), "volta para onde estava")
	assert_true(player.visible)
	assert_true(player.enabled)
	assert_true(is_instance_valid(enemy) and not enemy.is_queued_for_deletion(), "o inimigo continua no mapa")
	assert_true(enemy.visible)
	assert_true(enemy.in_cooldown())
	assert_eq(m.state.heroes[0].xp, xp0, "sem XP")
	assert_false(m.locked, "fuga não é Game Over")

func test_enemy_cannot_retouch_during_cooldown_then_can() -> void:
	var m := _map()
	var player: Player = m.get_node("Player") as Player
	var enemy: MapEnemy = m.get_node("Enemy") as MapEnemy
	enemy.frozen = true
	player.global_position = enemy.global_position
	var s := _touch(m, _encounter(true))
	s.flee_input_override = 1
	s.update_flee(100.0)
	assert_null(m.battle)
	# O jogador volta para onde estava (sobre o inimigo): rearm() durante o cooldown não reencosta.
	enemy.rearm()
	await wait_physics_frames(5)
	assert_null(m.battle, "sem toque durante o cooldown")
	enemy._tick_cooldown(m.state.cfg.flee_cooldown + 0.1)
	assert_false(enemy.in_cooldown())
	assert_not_null(m.battle, "depois do cooldown o contato volta a valer")

func test_boss_cannot_be_fled_and_shows_message() -> void:
	var m := _map()
	var s := _touch(m, _encounter(false))
	assert_false(s.ctrl.can_flee)
	s.flee_input_override = 1
	s.update_flee(100.0)
	assert_not_null(m.battle)
	assert_eq(s.ctrl.outcome, BattleController.Outcome.ONGOING)
	assert_eq(s.ctrl.flee_gauge, 0.0)
	assert_eq(s.flee_message(), "Não dá para fugir!")
	s.flee_input_override = 0
	s.update_flee(0.1)
	assert_eq(s.flee_message(), "")

func test_gauge_message_while_filling() -> void:
	var m := _map()
	var s := _touch(m, _encounter(true))
	s.flee_input_override = 1
	s.update_flee(0.1)
	assert_eq(s.flee_message(), "Fugindo...")

extends GutTest

## Veneno no mapa (M15): persiste da batalha para o campo, tira HP andando sem nunca derrubar, volta à força na
## batalha seguinte, cura por item/técnica/descanso/pousada/batalha e vai no save (campo opcional).

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

var _poison: StatusDef
var _cfg: BalanceConfig

func before_each() -> void:
	_poison = Fixtures.status_def(StatusDef.Kind.POISON, 3, 1)
	_poison.persists = true
	_poison.negative = true
	_cfg = Fixtures.cfg()
	_cfg.persistent_statuses = [_poison] as Array[StatusDef]

func after_each() -> void:
	Input.flush_buffered_events()
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _defs(n: int) -> Array[CharacterDef]:
	var out: Array[CharacterDef] = []
	for i: int in n:
		out.append(Fixtures.hero_def(StringName("h%d" % i), Stats.make(1, 1, 5, 6)))
	return out

func _state(n: int = 2) -> GameState:
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	return GameState.new_game(_cfg, _defs(n), items, counts, ScriptedDice.new(), &"m", &"s", 4)

func _hp_max(h: HeroState) -> int:
	return StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), _cfg)

func _poisoned_state(n: int = 2) -> GameState:
	var s: GameState = _state(n)
	s.heroes[0].field_statuses = [&"poison"] as Array[StringName]
	return s

func _remove_effect(listed: Array[StatusDef]) -> EffectDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.REMOVE_STATUS
	e.statuses = listed
	return e

func _item(effect: EffectDef) -> ItemDef:
	var it := ItemDef.new()
	it.id = &"cura"
	it.display_name = "Cura"
	it.effects = [effect] as Array[EffectDef]
	return it

func _game() -> Game:
	var game: Game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	cfg.persistent_statuses = [_poison] as Array[StatusDef]
	game.balance = cfg
	game.world_seed = 7
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.skip_title = true
	add_child_autofree(game)
	return game

func _wait_idle(game: Game) -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1

# --- batalha -> campo -----------------------------------------------------------

func _battle_with(hs: Array[HeroState]) -> BattleController:
	var hcs: Array[Combatant] = []
	for i: int in hs.size():
		hcs.append(Combatant.from_hero(hs[i], Vector2(10, 10 * i)))
	var en: Combatant = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 0, 2, 1)), &"x", Vector2(100, 0), _cfg)
	return BattleController.new(BattleState.create(_cfg, ScriptedDice.new(), hcs, [en] as Array[Combatant]))

func test_persisting_status_goes_to_the_field_without_duration() -> void:
	var s: GameState = _state(2)
	var ctrl: BattleController = _battle_with(s.heroes)
	var c: Combatant = ctrl.b.heroes[0]
	ctrl.b.statuses.apply_forced(c, _poison)
	ctrl.b.statuses.apply_forced(c, Fixtures.status_def(StatusDef.Kind.SLEEP, 2))
	s.heroes[0].store_field_statuses(c)
	s.heroes[1].store_field_statuses(ctrl.b.heroes[1])
	assert_eq(s.heroes[0].field_statuses, [&"poison"] as Array[StringName], "só o que persiste, sem o sono")
	assert_eq(s.heroes[1].field_statuses.size(), 0)

func test_downed_hero_leaves_without_the_status() -> void:
	var s: GameState = _state(1)
	var ctrl: BattleController = _battle_with(s.heroes)
	var c: Combatant = ctrl.b.heroes[0]
	ctrl.b.statuses.apply_forced(c, _poison)
	c.hp = 0
	s.heroes[0].store_field_statuses(c)
	assert_eq(s.heroes[0].field_statuses.size(), 0)

func test_cured_in_battle_leaves_without_it() -> void:
	var s: GameState = _poisoned_state(1)
	var ctrl: BattleController = _battle_with(s.heroes)
	var c: Combatant = ctrl.b.heroes[0]
	assert_true(c.has_kind(StatusDef.Kind.POISON), "voltou à força no começo")
	ctrl.b.statuses.remove_negative(c)
	s.heroes[0].store_field_statuses(c)
	assert_eq(s.heroes[0].field_statuses.size(), 0, "curado em batalha sai sem")

func test_status_is_reapplied_in_battle_with_normal_duration() -> void:
	var s: GameState = _poisoned_state(2)
	var ctrl: BattleController = _battle_with(s.heroes)
	var c: Combatant = ctrl.b.heroes[0]
	assert_true(c.has_kind(StatusDef.Kind.POISON))
	assert_eq(c.statuses[0].remaining, _poison.duration, "duração normal")
	assert_false(ctrl.b.heroes[1].has_kind(StatusDef.Kind.POISON), "só quem estava envenenado")

func test_downed_hero_is_not_poisoned_at_battle_start() -> void:
	var s: GameState = _poisoned_state(1)
	s.heroes[0].hp = 0
	var ctrl: BattleController = _battle_with(s.heroes)
	assert_false(ctrl.b.heroes[0].has_kind(StatusDef.Kind.POISON))

func test_scene_writes_the_status_back_at_battle_end() -> void:
	var packed: PackedScene = load("res://battle/battle_scene.tscn") as PackedScene
	var sc: BattleScene = packed.instantiate() as BattleScene
	sc.balance = _cfg
	sc.auto_battle = true
	sc.dice_seed = 7
	add_child_autofree(sc)
	sc.set_process(false)
	sc.mode = BattleScene.Mode.MAP
	var hs: Array[HeroState] = []
	hs.append(HeroState.create(load("res://data/test/heroes/teste_a.tres") as CharacterDef, _cfg))
	hs.append(HeroState.create(load("res://data/test/heroes/teste_b.tres") as CharacterDef, _cfg))
	var foes: Array[EnemyDef] = [Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 0), 100)]
	var hp: Array[Vector2] = [Vector2(100, 100), Vector2(100, 200)]
	var ep: Array[Vector2] = [Vector2(500, 150)]
	sc.start_with(hs, foes, hp, ep, Inventory.new())
	sc.ctrl.b.statuses.apply_forced(sc.ctrl.b.heroes[0], _poison)
	var steps: int = 0
	while sc.ctrl.outcome == BattleController.Outcome.ONGOING and steps < 20000:
		sc.ctrl.tick(0.1)
		steps += 1
	assert_eq(sc.ctrl.outcome, BattleController.Outcome.VICTORY)
	assert_eq(hs[0].field_statuses, [&"poison"] as Array[StringName], "o envenenado leva o estado")
	assert_eq(hs[1].field_statuses.size(), 0)

# --- andando --------------------------------------------------------------------

func test_walking_ticks_every_step_and_only_the_poisoned_lose_hp() -> void:
	var s: GameState = _poisoned_state(2)
	var full: int = s.heroes[0].hp
	var tick: int = maxi(1, floori(float(_hp_max(s.heroes[0])) * _cfg.poison_field_pct))
	assert_eq(FieldPoison.walk(s, _cfg.poison_step_px - 1.0), 0, "ainda não completou o passo")
	assert_eq(s.heroes[0].hp, full)
	assert_eq(FieldPoison.walk(s, 1.0), tick, "completou o passo")
	assert_eq(s.heroes[0].hp, full - tick)
	assert_eq(s.heroes[1].hp, _hp_max(s.heroes[1]), "o saudável não perde")
	FieldPoison.walk(s, _cfg.poison_step_px * 2.0)
	assert_eq(s.heroes[0].hp, full - tick * 3, "dois passos em uma andada")

func test_field_poison_never_downs() -> void:
	var s: GameState = _poisoned_state(1)
	FieldPoison.walk(s, _cfg.poison_step_px * 500.0)
	assert_eq(s.heroes[0].hp, 1, "para em 1 HP")
	assert_true(s.heroes[0].has_field_status(&"poison"), "continua envenenado")
	assert_eq(FieldPoison.walk(s, _cfg.poison_step_px), 0, "com 1 HP não tira mais")
	s.heroes[0].hp = 0
	assert_eq(FieldPoison.walk(s, _cfg.poison_step_px), 0, "caído não leva")
	assert_eq(s.heroes[0].hp, 0)

func test_tiny_max_hp_still_loses_at_least_one() -> void:
	var s: GameState = _poisoned_state(1)
	_cfg.poison_field_pct = 0.0001
	s.heroes[0].hp = 5
	FieldPoison.walk(s, _cfg.poison_step_px)
	assert_eq(s.heroes[0].hp, 4, "mínimo de 1 de dano")

func test_reserve_hero_does_not_lose_hp() -> void:
	var s: GameState = _state(5)
	var res: HeroState = s.reserve[0]
	res.field_statuses = [&"poison"] as Array[StringName]
	var full: int = res.hp
	FieldPoison.walk(s, _cfg.poison_step_px * 3.0)
	assert_eq(res.hp, full, "a reserva não anda")

func test_map_walk_ticks_and_ignores_teleports() -> void:
	var game: Game = _game()
	await _wait_idle(game)
	(game.current as Overworld).location_entered.emit(&"area_teste", &"Entry")
	await _wait_idle(game)
	var map: LocalMap = game.current as LocalMap
	var h: HeroState = game.state.heroes[0]
	h.field_statuses = [&"poison"] as Array[StringName]
	var full: int = h.hp
	await get_tree().physics_frame
	map.player.global_position += Vector2(5000, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(h.hp, full, "o teleporte não conta")
	map.player.override_dir = Vector2.RIGHT
	map.player.override_run = 1
	var guard: int = 0
	while h.hp == full and guard < 900:
		await get_tree().physics_frame
		guard += 1
	map.player.override_dir = Vector2.ZERO
	assert_lt(h.hp, full, "andar tira HP")

# --- cura -----------------------------------------------------------------------

func test_item_that_removes_poison_cures_it() -> void:
	var s: GameState = _poisoned_state(2)
	var it: ItemDef = _item(_remove_effect([_poison] as Array[StatusDef]))
	assert_true(FieldActions.is_field_usable(it.effects))
	s.inventory.add(it, 2)
	assert_false(FieldActions.use_item(s, it, s.heroes[1]), "não envenenado: não gasta")
	assert_eq(s.inventory.available(it.id), 2)
	assert_true(FieldActions.use_item(s, it, s.heroes[0]))
	assert_eq(s.heroes[0].field_statuses.size(), 0)
	assert_eq(s.inventory.available(it.id), 1)

func test_cure_all_negatives_item_cures_poison() -> void:
	var s: GameState = _poisoned_state(1)
	var it: ItemDef = _item(_remove_effect([] as Array[StatusDef]))
	assert_true(FieldActions.is_field_usable(it.effects))
	s.inventory.add(it, 1)
	assert_true(FieldActions.use_item(s, it, s.heroes[0]))
	assert_eq(s.heroes[0].field_statuses.size(), 0)

func test_item_that_cures_other_statuses_stays_battle_only() -> void:
	var blind: StatusDef = Fixtures.status_def(StatusDef.Kind.BLIND, 3)
	var it: ItemDef = _item(_remove_effect([blind] as Array[StatusDef]))
	assert_false(FieldActions.is_field_usable(it.effects))

func test_technique_that_cures_poison_works_in_the_field() -> void:
	var s: GameState = _poisoned_state(2)
	var ab := AbilityDef.new()
	ab.id = &"purify"
	ab.ap_cost = 2
	ab.side = AbilityDef.Side.ALLIES
	ab.shape = AbilityDef.Shape.SINGLE
	ab.effects = [_remove_effect([_poison] as Array[StatusDef])] as Array[EffectDef]
	var user: HeroState = s.heroes[1]
	var ap_before: int = user.ap
	assert_true(FieldActions.can_use_technique(user, ab, s.heroes[0], _cfg, s))
	assert_false(FieldActions.can_use_technique(user, ab, s.heroes[1], _cfg, s), "alvo sem veneno")
	assert_true(FieldActions.use_technique(s, user, ab, s.heroes[0]))
	assert_eq(user.ap, ap_before - 2)
	assert_eq(s.heroes[0].field_statuses.size(), 0)

func test_rest_all_cures_the_whole_roster() -> void:
	var s: GameState = _state(5)
	for h: HeroState in s.roster():
		h.field_statuses = [&"poison"] as Array[StringName]
	s.rest_all()
	for h: HeroState in s.roster():
		assert_eq(h.field_statuses.size(), 0, h.def.id)

func test_inn_cures_poison() -> void:
	var game: Game = _game()
	await _wait_idle(game)
	game.state.heroes[0].field_statuses = [&"poison"] as Array[StringName]
	game.state.add_money(500)
	game.rest_menu.open(game, game.balance.inn_price)
	game.rest_menu.accept()
	assert_eq(game.state.heroes[0].field_statuses.size(), 0, "pousada cura")
	game.rest_menu.close()

# --- save -----------------------------------------------------------------------

func _registry(n: int) -> DefRegistry:
	return DefRegistry.create(_defs(n), [] as Array[ItemDef], [] as Array[EquipmentDef])

func test_save_round_trip_keeps_the_status() -> void:
	var s: GameState = _poisoned_state(2)
	var d: Dictionary = s.to_dict()
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var back: GameState = GameState.from_dict(parsed, _registry(2), _cfg, ScriptedDice.new())
	assert_not_null(back)
	assert_eq(back.heroes[0].field_statuses, [&"poison"] as Array[StringName])
	assert_eq(back.heroes[1].field_statuses.size(), 0)

func test_save_writes_the_field_only_when_not_empty() -> void:
	var s: GameState = _poisoned_state(2)
	var d: Dictionary = s.to_dict()
	assert_true((d["heroes"][0] as Dictionary).has("field_statuses"))
	assert_false((d["heroes"][1] as Dictionary).has("field_statuses"), "vazio não grava")

func test_old_save_loads_without_statuses() -> void:
	var s: GameState = _state(2)
	var d: Dictionary = s.to_dict()
	for hd: Dictionary in d["heroes"]:
		hd.erase("field_statuses")
	var back: GameState = GameState.from_dict(d, _registry(2), _cfg, ScriptedDice.new())
	assert_not_null(back)
	assert_eq(back.heroes[0].field_statuses.size(), 0)

func test_checkpoint_restore_brings_the_status_back() -> void:
	var s: GameState = _poisoned_state(1)
	s.save(&"m", &"s")
	s.heroes[0].field_statuses = []
	s.restore_save()
	assert_eq(s.heroes[0].field_statuses, [&"poison"] as Array[StringName])

# --- HUD ------------------------------------------------------------------------

func test_party_panel_shows_ven_on_the_poisoned_hero() -> void:
	var s: GameState = _poisoned_state(2)
	var panel := PartyPanel.new()
	add_child_autofree(panel)
	panel.refresh(s)
	assert_string_contains(panel.card_text(0), "VEN")
	assert_false(panel.card_text(1).contains("VEN"))

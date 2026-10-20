extends GutTest

## Barra de Limite (M8): enchimento, persistencia, escolha, zerar ao comecar e devolver ao perder.

func _def(id: StringName = &"a") -> CharacterDef:
	var d: CharacterDef = Fixtures.hero_def(id, Stats.make(10, 10, 5, 1))
	d.limit_ability = Fixtures.hit(3.0)
	return d

func _battle(hero_limit: float = 0.0, enemies_n: int = 1) -> BattleController:
	var cfg := Fixtures.cfg()
	var hs := HeroState.create(_def(), cfg)
	hs.limit = hero_limit
	var heroes: Array[Combatant] = [Combatant.from_hero(hs, Vector2.ZERO)]
	var enemies: Array[Combatant] = []
	for i: int in enemies_n:
		var ed := Fixtures.enemy_def(StringName("x%d" % i), Stats.make(10, 1, 5, 5))
		enemies.append(Combatant.from_enemy(ed, ed.id, Vector2(100 + i, 0), cfg))
	var b := BattleState.create(cfg, ScriptedDice.new(), heroes, enemies)
	return BattleController.new(b)

func _hit_hero(b: BattleState, amount_potency: float) -> void:
	var a := PendingAction.new()
	a.actor = b.enemies[0]
	a.ability = Fixtures.hit(amount_potency)
	a.center = b.heroes[0]
	a.center_pos = b.heroes[0].position
	ActionExecutor.apply(a, b)

func test_fill_is_proportional_to_damage_taken() -> void:
	var ctrl := _battle()
	var h: Combatant = ctrl.b.heroes[0]
	var before: int = h.hp
	# Forca 10 x 3.0 = 30; defesa (vit 5 x 0.5 = 2) => 28 de dano; hp_max 55.
	_hit_hero(ctrl.b, 3.0)
	var dmg: int = before - h.hp
	assert_gt(dmg, 0)
	assert_almost_eq(h.limit, float(dmg) / 55.0 * ctrl.b.cfg.limit_fill_mult, 0.0001)

func test_fill_clamps_at_one() -> void:
	var ctrl := _battle(0.9)
	_hit_hero(ctrl.b, 3.0)
	assert_eq(ctrl.b.heroes[0].limit, 1.0)

func test_downed_hero_does_not_fill_and_keeps_bar() -> void:
	var ctrl := _battle(0.4)
	var h: Combatant = ctrl.b.heroes[0]
	h.hp = 0
	_hit_hero(ctrl.b, 3.0)
	assert_eq(h.limit, 0.4)

func test_enemies_have_no_bar() -> void:
	var ctrl := _battle()
	var e: Combatant = ctrl.b.enemies[0]
	var a := PendingAction.new()
	a.actor = ctrl.b.heroes[0]
	a.ability = Fixtures.hit(1.0)
	a.center = e
	a.center_pos = e.position
	ActionExecutor.apply(a, ctrl.b)
	assert_eq(e.limit, 0.0)

func test_poison_fills() -> void:
	var ctrl := _battle()
	var h: Combatant = ctrl.b.heroes[0]
	var st: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 3, 11)
	ctrl.b.statuses.apply_forced(h, st)
	ctrl.b.statuses.on_atb_full(h, ctrl.b.enemies)
	assert_almost_eq(h.limit, 11.0 / 55.0 * ctrl.b.cfg.limit_fill_mult, 0.0001)

func test_persists_to_hero_state_and_snapshot_save() -> void:
	var cfg := Fixtures.cfg()
	var d := _def()
	var hs := HeroState.create(d, cfg)
	hs.limit = 0.6
	var snap: Dictionary = hs.snapshot()
	hs.limit = 0.1
	hs.restore(snap)
	assert_eq(hs.limit, 0.6)
	var reg := DefRegistry.create([d] as Array[CharacterDef], [] as Array[ItemDef], [] as Array[EquipmentDef])
	var loaded: HeroState = HeroState.from_dict(hs.to_dict(), reg)
	assert_eq(loaded.limit, 0.6)
	var old: Dictionary = hs.to_dict()
	old.erase("limit")
	assert_eq(HeroState.from_dict(old, reg).limit, 0.0)

func test_combatant_mirrors_hero_state() -> void:
	var cfg := Fixtures.cfg()
	var hs := HeroState.create(_def(), cfg)
	hs.limit = 0.7
	var c := Combatant.from_hero(hs, Vector2.ZERO)
	assert_eq(c.limit, 0.7)
	assert_not_null(c.limit_ability)

func _session(limit: float) -> SelectionSession:
	var ctrl := _battle(limit)
	return SelectionSession.new(ctrl.b.heroes[0], ctrl.b)

func test_choose_limit_only_when_full() -> void:
	assert_false(_session(0.99).choose_limit())
	var s := _session(1.0)
	assert_true(s.choose_limit())
	assert_eq(s.step, SelectionSession.Step.TARGET)

func test_choose_limit_needs_ability() -> void:
	var s := _session(1.0)
	s.actor.limit_ability = null
	assert_false(s.choose_limit())

func _confirmed(ctrl: BattleController) -> PendingAction:
	var s := SelectionSession.new(ctrl.b.heroes[0], ctrl.b)
	assert_true(s.choose_limit())
	s.set_center(s.target_candidates()[0])
	return s.confirm()

func test_bar_zeroes_when_action_begins() -> void:
	var ctrl := _battle(1.0)
	var a := _confirmed(ctrl)
	assert_eq(ctrl.b.heroes[0].limit, 1.0)
	ctrl.session = SelectionSession.new(ctrl.b.heroes[0], ctrl.b)
	ctrl.submit(a)
	assert_eq(ctrl.b.heroes[0].limit, 0.0)
	assert_eq(ctrl.executing, a)

func test_lost_action_returns_bar() -> void:
	var ctrl := _battle(1.0)
	var a := _confirmed(ctrl)
	ctrl.b.enemies[0].hp = 0
	ctrl.session = SelectionSession.new(ctrl.b.heroes[0], ctrl.b)
	ctrl.submit(a)
	assert_null(ctrl.executing)
	assert_eq(ctrl.b.heroes[0].limit, 1.0)

func test_back_keeps_bar() -> void:
	var s := _session(1.0)
	s.choose_limit()
	s.back()
	assert_eq(s.actor.limit, 1.0)
	assert_eq(s.step, SelectionSession.Step.COMMAND)

extends GutTest

## Suporte (M8.5): heroi da reserva vira Combatant temporario; custos, ATB, XP, reembolso e menu.

var _cfg: BalanceConfig
var _reserve_state: HeroState

func _def(id: StringName) -> CharacterDef:
	var d: CharacterDef = Fixtures.hero_def(id, Stats.make(10, 10, 5, 4))
	var ab: AbilityDef = Fixtures.hit(2.0)
	ab.ap_cost = 3
	ab.display_name = "Forte"
	d.abilities = [ab]
	return d

## Um heroi ativo (Limite `limit`) + uma reserva em pe + um inimigo resistente.
func _battle(limit: float = 0.5, reserve_hp_ok: bool = true, with_reserve: bool = true) -> BattleController:
	_cfg = Fixtures.cfg()
	var hs := HeroState.create(_def(&"a"), _cfg)
	hs.limit = limit
	var heroes: Array[Combatant] = [Combatant.from_hero(hs, Vector2(0, 0))]
	_reserve_state = HeroState.create(_def(&"r"), _cfg)
	if not reserve_hp_ok:
		_reserve_state.hp = 0
	var ed := Fixtures.enemy_def(&"x", Stats.make(1, 1, 50, 5), 100)
	var enemies: Array[Combatant] = [Combatant.from_enemy(ed, ed.id, Vector2(300, 0), _cfg)]
	var b := BattleState.create(_cfg, ScriptedDice.new(), heroes, enemies)
	if with_reserve:
		b.reserve = [_reserve_state]
	return BattleController.new(b)

func _session(ctrl: BattleController) -> SelectionSession:
	return SelectionSession.new(ctrl.b.heroes[0], ctrl.b)

func _support_action(ctrl: BattleController, ab_index: int = 0) -> PendingAction:
	var s := _session(ctrl)
	assert_true(s.choose_support(_reserve_state))
	assert_true(s.choose_ability(s.support_abilities()[ab_index]))
	s.set_center(s.target_candidates()[0])
	var a: PendingAction = s.confirm()
	ctrl.session = SelectionSession.new(ctrl.b.heroes[0], ctrl.b)
	return a

func test_can_support_needs_limit_and_standing_reserve() -> void:
	assert_true(_session(_battle(0.5)).can_support())
	assert_false(_session(_battle(0.49)).can_support())
	assert_false(_session(_battle(1.0, true, false)).can_support())
	assert_false(_session(_battle(1.0, false)).can_support())

func test_choose_support_refused_when_unavailable() -> void:
	var s := _session(_battle(0.2))
	assert_false(s.choose_support(_reserve_state))
	assert_null(s.support)

func test_support_actions_use_reserve_ap() -> void:
	var s := _session(_battle())
	s.actor.ap = 0
	assert_true(s.choose_support(_reserve_state))
	var abs: Array[AbilityDef] = s.support_abilities()
	assert_eq(abs.size(), 2)
	assert_eq(abs[0], s.support.basic_attack)
	assert_true(s.can_use(abs[1]))
	assert_true(s.choose_ability(abs[1]))
	assert_eq(s.support.ap, _reserve_state.ap)
	assert_eq(_reserve_state.ap, 20 - 3)
	assert_eq(s.actor.ap, 0)

func test_back_returns_reserve_ap_and_cancel_support_clears() -> void:
	var s := _session(_battle())
	s.choose_support(_reserve_state)
	var before: int = _reserve_state.ap
	s.choose_ability(s.support_abilities()[1])
	s.back()
	assert_eq(_reserve_state.ap, before)
	assert_eq(s.support.ap, before)
	s.cancel_support()
	assert_null(s.support)

func test_costs_limit_of_caller_at_begin_and_ap_persists() -> void:
	var ctrl := _battle(0.8)
	var a := _support_action(ctrl, 1)
	assert_eq(ctrl.b.heroes[0].limit, 0.8)
	ctrl.submit(a)
	assert_almost_eq(ctrl.b.heroes[0].limit, 0.3, 0.0001)
	assert_eq(ctrl.executing, a)
	assert_eq(_reserve_state.ap, 17)

func test_caller_atb_zeroes_not_support() -> void:
	var ctrl := _battle()
	var a := _support_action(ctrl)
	ctrl.b.heroes[0].atb = 1.0
	a.actor.atb = 0.7
	ctrl.submit(a)
	while ctrl.executing != null:
		ctrl.tick(0.1)
	assert_eq(ctrl.b.heroes[0].atb, 0.0)
	assert_eq(a.actor.atb, 0.7)

func test_support_is_not_a_target_nor_in_queue_nor_in_heroes() -> void:
	var ctrl := _battle()
	var a := _support_action(ctrl)
	ctrl.submit(a)
	assert_false(ctrl.b.heroes.has(a.actor))
	assert_false(ctrl.b.all().has(a.actor))
	assert_false(ctrl.b.allies_of(ctrl.b.enemies[0]).has(a.actor))
	for i: int in 200:
		ctrl.tick(0.1)
		assert_false(ctrl.b.queue.ordered().has(a.actor))

func test_support_damage_credits_caller_and_gives_reserve_no_xp() -> void:
	var ctrl := _battle()
	var a := _support_action(ctrl)
	ctrl.submit(a)
	while ctrl.executing != null:
		ctrl.tick(0.1)
	var ex: StringName = ctrl.b.enemies[0].id
	assert_gt(ctrl.b.ledger.get_points(&"a", ex), 0.0)
	assert_eq(ctrl.b.ledger.get_points(&"r", ex), 0.0)
	var xp: Dictionary = XpCalculator.combat_xp(ctrl.b.ledger, ctrl.b.enemies, ctrl.b.heroes, false)
	assert_eq(xp.size(), 1)
	assert_gt(int(xp[&"a"]), 0)

func test_lone_hero_down_is_defeat_even_with_reserve_standing() -> void:
	var ctrl := _battle()
	ctrl.b.heroes[0].hp = 0
	ctrl.tick(0.1)
	assert_eq(ctrl.outcome, BattleController.Outcome.DEFEAT)

func test_lost_action_refunds_reserve_ap_and_keeps_limit() -> void:
	var ctrl := _battle(0.8)
	var a := _support_action(ctrl, 1)
	assert_eq(_reserve_state.ap, 17)
	ctrl.b.enemies[0].hp = 0
	ctrl.submit(a)
	assert_null(ctrl.executing)
	assert_eq(_reserve_state.ap, 20)
	assert_eq(ctrl.b.heroes[0].limit, 0.8)
	assert_eq(ctrl.b.heroes[0].atb, 0.0)

func test_active_mode_queued_support_refunds_on_end() -> void:
	var ctrl := _battle(0.8)
	ctrl.active_mode = true
	var first := PendingAction.new()
	first.actor = ctrl.b.heroes[0]
	first.ability = Fixtures.hit(0.1)
	first.center = ctrl.b.enemies[0]
	first.center_pos = first.center.position
	ctrl.session = SelectionSession.new(ctrl.b.heroes[0], ctrl.b)
	ctrl.submit(first)
	var a := _support_action(ctrl, 1)
	ctrl.submit(a)
	assert_eq(_reserve_state.ap, 17)
	assert_eq(ctrl.b.heroes[0].limit, 0.8)
	ctrl.b.heroes[0].hp = 0
	for i: int in 30:
		ctrl.tick(0.1)
	assert_eq(_reserve_state.ap, 20)
	assert_eq(ctrl.b.heroes[0].limit, 0.8)

func test_snapshot_restore_returns_reserve_ap() -> void:
	var ctrl := _battle()
	var snap: Dictionary = _reserve_state.snapshot()
	var a := _support_action(ctrl, 1)
	ctrl.submit(a)
	assert_eq(_reserve_state.ap, 17)
	_reserve_state.restore(snap)
	assert_eq(_reserve_state.ap, 20)

# --- menu ----------------------------------------------------------------------

func _menu(ctrl: BattleController) -> CommandMenu:
	var menu := CommandMenu.new()
	add_child_autofree(menu)
	menu.ctrl = ctrl
	ctrl.hero_turn.connect(menu.open)
	for i: int in 400:
		ctrl.tick(0.05)
		if ctrl.is_paused():
			break
	return menu

func test_menu_support_flow_and_back() -> void:
	var ctrl := _battle(0.5)
	var menu := _menu(ctrl)
	assert_eq(menu.entry_labels()[3], "Suporte")
	assert_true(menu.entry_enabled(3))
	menu.move(3)
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.SUPPORT_HEROES)
	assert_eq(menu.entry_labels().size(), 1)
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.SUPPORT_ACTIONS)
	assert_eq(menu.entry_labels()[0], "Atacar")
	menu.move(1)
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.SUPPORT_ACTIONS)
	assert_eq(menu.cursor, 1)
	assert_eq(_reserve_state.ap, 20)
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.SUPPORT_HEROES)
	assert_null(menu.session.support)
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)
	assert_eq(menu.cursor, 3)

func test_menu_support_disabled_without_limit() -> void:
	var ctrl := _battle(0.2)
	var menu := _menu(ctrl)
	assert_false(menu.entry_enabled(3))
	menu.move(3)
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)

func test_menu_confirm_submits_support_action() -> void:
	var ctrl := _battle(0.9)
	var menu := _menu(ctrl)
	menu.move(3)
	menu.accept()
	menu.accept()
	menu.accept()
	menu.accept()
	assert_not_null(ctrl.executing)
	assert_eq(ctrl.executing.caller, ctrl.b.heroes[0])
	assert_almost_eq(ctrl.b.heroes[0].limit, 0.4, 0.0001)

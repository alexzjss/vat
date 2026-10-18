extends GutTest

func _battle(hero_speeds: Array[int], enemy_speeds: Array[int]) -> BattleController:
	var cfg := Fixtures.cfg()
	var heroes: Array[Combatant] = []
	var ids: Array[StringName] = [&"a", &"b", &"c"]
	for i: int in hero_speeds.size():
		var hs := HeroState.create(Fixtures.hero_def(ids[i], Stats.make(10, hero_speeds[i], 5, 1)), cfg)
		heroes.append(Combatant.from_hero(hs, Vector2.ZERO))
	var enemies: Array[Combatant] = []
	var eids: Array[StringName] = [&"x", &"y", &"z"]
	for i: int in enemy_speeds.size():
		var d := Fixtures.enemy_def(eids[i], Stats.make(10, enemy_speeds[i], 5, 5))
		enemies.append(Combatant.from_enemy(d, eids[i], Vector2.ZERO, cfg))
	return BattleController.new(BattleState.create(cfg, ScriptedDice.new(), heroes, enemies))

func _panel() -> DebugPanel:
	var p := DebugPanel.new()
	add_child_autofree(p)
	return p

func test_hidden_by_default_and_toggle() -> void:
	var p: DebugPanel = _panel()
	assert_false(p.visible)
	p.toggle()
	assert_true(p.visible)
	p.toggle()
	assert_false(p.visible)

func test_text_lists_queue_in_order_with_effective_speed() -> void:
	var ctrl := _battle([10, 30], [20])
	var b: BattleState = ctrl.b
	b.queue.push(b.heroes[0], 1)
	b.queue.push(b.heroes[1], 1)
	b.queue.push(b.enemies[0], 1)
	var t: String = _panel().build_text(b, ctrl)
	assert_string_contains(t, "Fila ATB")
	var ib: int = t.find("b (Vel 25)")
	var ix: int = t.find("x (Vel 20)")
	var ia: int = t.find("a (Vel 10)")
	assert_true(ib >= 0 and ix > ib and ia > ix, "ordem b, x, a: %s" % t)

func test_text_shows_executing_elapsed_and_cast() -> void:
	var ctrl := _battle([10], [10])
	var a := PendingAction.new()
	a.actor = ctrl.b.heroes[0]
	a.ability = Fixtures.hit(1.0)
	a.center = ctrl.b.enemies[0]
	ctrl.session = SelectionSession.new(a.actor, ctrl.b)
	ctrl.submit(a)
	ctrl.tick(0.25)
	var p: DebugPanel = _panel()
	var t: String = p.build_text(ctrl.b, ctrl)
	assert_string_contains(t, "Executando: a -> Golpe 0.25/1.00")
	ctrl.executing = null
	assert_string_contains(p.build_text(ctrl.b, ctrl), "Executando: -")

func test_text_shows_status_with_remaining_and_source() -> void:
	var ctrl := _battle([10], [10])
	var b: BattleState = ctrl.b
	var sleep := Fixtures.status_def(StatusDef.Kind.SLEEP, 2)
	b.statuses.apply(b.enemies[0], sleep, b.heroes[0], 1.0, b.living(b.enemies))
	var bar := Fixtures.status_def(StatusDef.Kind.BARRIER, 3, 12)
	b.statuses.apply(b.heroes[0], bar, b.heroes[0], 1.0, b.living(b.enemies))
	var t: String = _panel().build_text(b, ctrl)
	assert_string_contains(t, "sleep (2) ← a")
	assert_string_contains(t, "barrier (3) ← a [12]")

func test_text_shows_ledger_table_and_total() -> void:
	var ctrl := _battle([10, 10], [10, 10])
	var l: ContributionLedger = ctrl.b.ledger
	l.add(&"a", &"x", 12.5)
	l.add(&"b", &"x", 7.0)
	var t: String = _panel().build_text(ctrl.b, ctrl)
	assert_string_contains(t, "Contribuição")
	assert_string_contains(t, "  x:")
	assert_string_contains(t, "    a: 12.5")
	assert_string_contains(t, "    b: 7.0")
	assert_string_contains(t, "total: 19.5")

func test_wait_flag_follows_open_session() -> void:
	var ctrl := _battle([10], [10])
	var p: DebugPanel = _panel()
	assert_string_contains(p.build_text(ctrl.b, ctrl), "Wait: não")
	ctrl.session = SelectionSession.new(ctrl.b.heroes[0], ctrl.b)
	assert_string_contains(p.build_text(ctrl.b, ctrl), "Wait: sim")

func test_refresh_only_updates_when_visible() -> void:
	var ctrl := _battle([10], [10])
	var p: DebugPanel = _panel()
	p.refresh(ctrl.b, ctrl)
	assert_eq(p.text(), "")
	p.toggle()
	p.refresh(ctrl.b, ctrl)
	assert_string_contains(p.text(), "Fila ATB")

func test_f1_key_toggles() -> void:
	var p: DebugPanel = _panel()
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F1
	ev.pressed = true
	p._unhandled_input(ev)
	assert_true(p.visible)

## Verificação manual do plano: Sono em X conta a cada turno perdido; Y é imune.
func test_real_content_sleep_on_x_counts_and_y_immune() -> void:
	var cfg := Fixtures.cfg()
	var sono: AbilityDef = load("res://data/test/abilities/sono.tres") as AbilityDef
	var sleep: StatusDef = (sono.effects[0] as EffectDef).status
	var hb := Combatant.from_hero(HeroState.create(load("res://data/test/heroes/teste_b.tres") as CharacterDef, cfg), Vector2.ZERO)
	var x := Combatant.from_enemy(load("res://data/test/enemies/inimigo_x.tres") as EnemyDef, &"inimigo_x", Vector2.ZERO, cfg)
	var y := Combatant.from_enemy(load("res://data/test/enemies/inimigo_y.tres") as EnemyDef, &"inimigo_y", Vector2.ZERO, cfg)
	var b := BattleState.create(cfg, Dice.new(), [hb], [x, y])
	var ctrl := BattleController.new(b)
	var p: DebugPanel = _panel()
	assert_eq(b.statuses.apply(x, sleep, hb, 1.0, b.living(b.enemies)), StatusSystem.ApplyResult.APPLIED)
	assert_eq(b.statuses.apply(y, sleep, hb, 1.0, b.living(b.enemies)), StatusSystem.ApplyResult.IMMUNE)
	var base: float = b.ledger.get_points(&"teste_b", &"inimigo_x")
	var t: String = p.build_text(b, ctrl)
	assert_string_contains(t, "inimigo_x: sleep (2) ← teste_b")
	assert_eq(b.ledger.total_against(&"inimigo_y"), 0.0, "Y imune: sem contribuição")
	assert_false(t.contains("inimigo_y: sleep"))
	x.atb = 0.999
	ctrl.tick(0.05)
	t = p.build_text(b, ctrl)
	assert_string_contains(t, "inimigo_x: sleep (1) ← teste_b")
	assert_eq(b.ledger.get_points(&"teste_b", &"inimigo_x"), base + float(cfg.control_value_per_turn))
	assert_string_contains(t, "teste_b: %.1f" % (base + float(cfg.control_value_per_turn)))

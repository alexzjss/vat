extends GutTest

## CommandMenu dirigido programaticamente (move/accept/cancel), sem Input real.

var ctrl: BattleController
var menu: CommandMenu
var preview: TargetPreview
var h: Combatant
var x: Combatant
var y: Combatant
var potion: ItemDef
var costly: AbilityDef
var area: AbilityDef

func _potion() -> ItemDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.HEAL
	e.scale = EffectDef.Scale.FIXED
	e.potency = 30.0
	var it := ItemDef.new()
	it.id = &"pocao"
	it.display_name = "Poção"
	it.shape = AbilityDef.Shape.SINGLE
	it.side = AbilityDef.Side.ALLIES
	it.effects = [e]
	return it

func _setup(potions: int, ability_cost: int) -> void:
	var cfg: BalanceConfig = Fixtures.cfg()
	var d: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 2))
	d.display_name = "Teste A"
	costly = Fixtures.hit(1.3, AbilityDef.Shape.LINE)
	costly.id = &"investida"
	costly.display_name = "Investida"
	costly.ap_cost = ability_cost
	costly.width = 100.0
	area = Fixtures.hit(0.8, AbilityDef.Shape.CIRCLE_TARGET)
	area.id = &"golpe_area"
	area.display_name = "Golpe em área"
	area.ap_cost = 1
	area.radius = 100.0
	d.abilities = [costly, area]
	h = Combatant.from_hero(HeroState.create(d, cfg), Vector2(100, 100))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 1)), &"x", Vector2(500, 100), cfg)
	y = Combatant.from_enemy(Fixtures.enemy_def(&"y", Stats.make(1, 1, 1, 1)), &"y", Vector2(550, 150), cfg)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x, y])
	b.inventory = Inventory.new()
	potion = _potion()
	if potions > 0:
		b.inventory.add(potion, potions)
	ctrl = BattleController.new(b)
	menu = CommandMenu.new()
	add_child_autofree(menu)
	preview = TargetPreview.new()
	add_child_autofree(preview)
	menu.ctrl = ctrl
	menu.preview = preview
	ctrl.hero_turn.connect(menu.open)
	watch_signals(ctrl)
	for i: int in 400:
		ctrl.tick(0.05)
		if ctrl.is_paused():
			break

func _select(label_prefix: String) -> void:
	var labels: PackedStringArray = menu.entry_labels()
	for i: int in labels.size():
		if labels[i].begins_with(label_prefix):
			menu.move(i - menu.cursor)
			menu.accept()
			return
	fail_test("entrada '%s' nao encontrada em %s" % [label_prefix, labels])

func test_opens_on_hero_turn_with_root_entries() -> void:
	_setup(3, 4)
	assert_true(ctrl.is_paused())
	assert_true(menu.visible)
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)
	assert_eq(menu.actor_name(), "Teste A")
	assert_eq(menu.entry_labels(), PackedStringArray(["Atacar", "Habilidade", "Item"]))
	assert_true(menu.entry_enabled(2), "Item habilitado com Poção x3")
	assert_false(preview.visible, "previa oculta fora da etapa de alvo")

func test_ability_submenu_lists_cost_and_disables_without_ap() -> void:
	_setup(0, 999)
	_select("Habilidade")
	assert_eq(menu.mode, CommandMenu.Mode.ABILITIES)
	assert_eq(menu.entry_labels(), PackedStringArray(["Investida — 999 AP", "Golpe em área — 1 AP"]))
	assert_false(menu.entry_enabled(0))
	assert_true(menu.entry_enabled(1))
	var ap0: int = h.ap
	menu.move(-menu.cursor)
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.ABILITIES, "entrada desabilitada nao seleciona")
	assert_eq(h.ap, ap0)
	assert_eq(ctrl.session.step, SelectionSession.Step.COMMAND)

func test_submenu_cancel_returns_to_root() -> void:
	_setup(1, 4)
	_select("Habilidade")
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)
	assert_eq(ctrl.session.step, SelectionSession.Step.COMMAND)

func test_cancel_in_target_refunds_ap() -> void:
	_setup(0, 4)
	var ap0: int = h.ap
	_select("Habilidade")
	_select("Investida")
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	assert_eq(h.ap, ap0 - 4, "AP desconta ao escolher")
	assert_true(preview.visible)
	menu.cancel()
	assert_eq(h.ap, ap0, "Cancelar devolve o AP")
	assert_eq(menu.mode, CommandMenu.Mode.ABILITIES, "volta um nível (spec §4.4)")
	assert_eq(ctrl.session.step, SelectionSession.Step.COMMAND)
	assert_false(preview.visible)

func test_item_listing_and_disabled_at_zero() -> void:
	_setup(1, 4)
	assert_true(menu.entry_enabled(2))
	_select("Item")
	assert_eq(menu.entry_labels(), PackedStringArray(["Poção x1"]))
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	assert_eq(menu.current_target(), h)
	menu.accept()
	assert_signal_emitted(ctrl, "action_started")
	assert_false(menu.visible)
	assert_eq(ctrl.b.inventory.available(&"pocao"), 0)
	# próximo turno: Poção acabou -> Item desabilitado
	ctrl.executing = null
	ctrl.session = SelectionSession.new(h, ctrl.b)
	menu.open(ctrl.session)
	assert_false(menu.entry_enabled(2), "Item desabilitado sem itens disponiveis")
	menu.move(2 - menu.cursor)
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)

func test_item_root_disabled_without_items() -> void:
	_setup(0, 4)
	assert_false(menu.entry_enabled(2))

func test_basic_attack_flow_submits() -> void:
	_setup(0, 4)
	_select("Atacar")
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	assert_eq(menu.current_target(), x)
	menu.move(1)
	assert_eq(menu.current_target(), y, "ciclo de candidatos")
	menu.move(1)
	assert_eq(menu.current_target(), x, "ciclo da a volta")
	menu.move(-1)
	assert_eq(menu.current_target(), y)
	assert_eq(ctrl.session.center, y, "centro da previa acompanha o cursor")
	menu.accept()
	assert_signal_emitted(ctrl, "action_started")
	var a: PendingAction = get_signal_parameters(ctrl, "action_started")[0]
	assert_eq(a.center, y)
	assert_eq(a.ability, h.basic_attack)
	assert_false(ctrl.is_paused())
	assert_false(menu.visible)
	assert_false(preview.visible)

func test_area_preview_tracks_center() -> void:
	_setup(0, 4)
	_select("Habilidade")
	_select("Golpe em área")
	assert_eq(menu.current_target(), x)
	assert_eq(preview.area().size(), 2, "x e y dentro do raio 100 de x")
	assert_eq(preview.session, ctrl.session)

func test_cancel_in_root_does_nothing() -> void:
	_setup(0, 4)
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)
	assert_true(menu.visible)

func _reviver() -> ItemDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.REVIVE
	e.scale = EffectDef.Scale.FIXED
	e.potency = 0.25
	var it := ItemDef.new()
	it.id = &"reviver"
	it.display_name = "Reviver"
	it.shape = AbilityDef.Shape.SINGLE
	it.side = AbilityDef.Side.ALLIES
	it.effects = [e]
	return it

func test_cancel_from_ability_target_returns_to_list_with_cursor() -> void:
	_setup(0, 4)
	var ap0: int = h.ap
	_select("Habilidade")
	_select("Golpe em área")
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.ABILITIES)
	assert_eq(menu.cursor, 1, "cursor na habilidade de origem")
	assert_eq(h.ap, ap0)
	assert_eq(ctrl.session.step, SelectionSession.Step.COMMAND)
	assert_false(preview.visible)
	assert_true(menu.entry_enabled(0), "entradas recalculadas com o AP devolvido")
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)
	assert_eq(menu.cursor, 1)

func test_cancel_from_attack_target_returns_to_root() -> void:
	_setup(0, 4)
	_select("Atacar")
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)
	assert_eq(menu.cursor, 0)
	assert_eq(ctrl.session.step, SelectionSession.Step.COMMAND)

func test_cancel_from_item_target_returns_to_items() -> void:
	_setup(2, 4)
	ctrl.b.inventory.add(_reviver(), 1)
	var fallen: Combatant = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"b", Stats.make(1, 1, 1, 1)), ctrl.b.cfg), Vector2.ZERO)
	fallen.hp = 0
	ctrl.b.heroes.append(fallen)
	_select("Item")
	_select("Reviver")
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	assert_eq(ctrl.b.inventory.available(&"reviver"), 0, "reservado")
	menu.cancel()
	assert_eq(menu.mode, CommandMenu.Mode.ITEMS)
	assert_eq(menu.cursor, 1)
	assert_eq(ctrl.b.inventory.available(&"reviver"), 1, "reserva desfeita")

func test_no_valid_targets_item_returns_to_items_and_refunds() -> void:
	_setup(1, 4)
	ctrl.b.inventory.add(_reviver(), 1)
	_select("Item")
	_select("Reviver")
	assert_eq(menu.mode, CommandMenu.Mode.ITEMS)
	assert_eq(menu.cursor, 1, "cursor no item de origem")
	assert_eq(menu.header_text(), "Sem alvos válidos")
	assert_eq(ctrl.b.inventory.available(&"reviver"), 1, "reserva devolvida")
	assert_eq(ctrl.session.step, SelectionSession.Step.COMMAND)
	assert_true(ctrl.is_paused())

func test_no_valid_targets_attack_returns_to_root() -> void:
	_setup(0, 4)
	x.hp = 0
	y.hp = 0
	_select("Atacar")
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)
	assert_eq(menu.cursor, 0)
	assert_eq(menu.header_text(), "Sem alvos válidos")
	assert_eq(ctrl.session.step, SelectionSession.Step.COMMAND)

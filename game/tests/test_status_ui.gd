extends GutTest

## Estados na interface e nos itens (M11): abreviações no HUD, menu com Silêncio, herói confuso sem menu,
## "Errou" e os itens remedio/panaceia.

const SCENE: String = "res://battle/battle_scene.tscn"

var cfg: BalanceConfig
var ctrl: BattleController
var menu: CommandMenu
var h: Combatant
var x: Combatant

func before_each() -> void:
	cfg = Fixtures.cfg()

func _status(kind: StatusDef.Kind, id: StringName, attr: StringName = &"", potency: int = 0) -> StatusDef:
	var s: StatusDef = Fixtures.status_def(kind, 3, potency)
	s.id = id
	s.attr = attr
	return s

func _load_status(id: String) -> StatusDef:
	return load("res://data/test/statuses/%s.tres" % id) as StatusDef

func _view() -> CombatantView:
	var v: CombatantView = (load("res://battle/combatant_view.tscn") as PackedScene).instantiate() as CombatantView
	add_child_autofree(v)
	return v

## Herói rápido com uma técnica e um inimigo lento; menu ligado ao controlador (modo Ativo opcional).
func _setup(active: bool = false) -> void:
	var tech: AbilityDef = Fixtures.hit(1.0)
	tech.id = &"tech"
	tech.display_name = "Técnica"
	tech.ap_cost = 1
	var d: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 40, 5, 2))
	d.display_name = "Teste A"
	Fixtures.set_abilities(d, [tech])
	h = Combatant.from_hero(HeroState.create(d, cfg), Vector2(100, 100))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 1)), &"x", Vector2(500, 100), cfg)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	ctrl = BattleController.new(b)
	ctrl.active_mode = active
	menu = CommandMenu.new()
	add_child_autofree(menu)
	menu.ctrl = ctrl
	ctrl.hero_turn.connect(menu.open)
	ctrl.session_cancelled.connect(func(_s: SelectionSession) -> void: menu.close())
	ctrl.session_reset.connect(func(_s: SelectionSession) -> void: menu.reset_to_root())

func _run_until_menu(max_ticks: int = 600) -> void:
	for i: int in max_ticks:
		if menu.visible:
			return
		ctrl.tick(0.05)

# --- Abreviações no HUD ---

func test_labels_for_new_kinds_and_attr_mods() -> void:
	var cases: Array = [
		[_load_status("stop"), "PARE"],
		[_load_status("confusion"), "CNF"],
		[_load_status("silence"), "SIL"],
		[_load_status("blind"), "CEG"],
		[_load_status("regen"), "REG"],
		[_load_status("barrier"), "BAR"],
		[_load_status("str_up"), "FOR+"],
		[_load_status("str_down"), "FOR-"],
		[_load_status("vit_up"), "VIT+"],
		[_load_status("vit_down"), "VIT-"],
		[_load_status("spd_up"), "VEL+"],
		[_load_status("spd_down"), "VEL-"],
	]
	for c: Array in cases:
		var st := ActiveStatus.create(c[0], &"x", 1)
		assert_eq(CombatantView.status_label(st), c[1], String(c[0].id))

func test_view_status_text_appears_and_disappears() -> void:
	_setup()
	var v: CombatantView = _view()
	v.bind(h, cfg)
	assert_eq(v.status_text(), "")
	ctrl.b.statuses.apply_forced(h, _load_status("confusion"))
	ctrl.b.statuses.apply_forced(h, _load_status("spd_down"))
	assert_eq(v.status_text(), "CNF VEL-")
	ctrl.b.statuses.remove(h, &"confusion")
	assert_eq(v.status_text(), "VEL-")
	ctrl.b.statuses.remove(h, &"spd_down")
	assert_eq(v.status_text(), "")

func test_missed_hit_shows_errou() -> void:
	var v: CombatantView = _view()
	v.show_hit({"target_id": &"x", "kind": EffectDef.Kind.DAMAGE, "amount": 0, "dodged": false, "status_result": -1, "missed": true})
	var last: Label = null
	for child: Node in v.get_children():
		if child is Label:
			last = child as Label
	assert_not_null(last)
	assert_eq(last.text, "Errou")

# --- Menu ---

func test_menu_disables_abilities_under_silence() -> void:
	_setup()
	_run_until_menu()
	assert_true(menu.entry_enabled(1), "Habilidade habilitada sem Silêncio")
	menu.close()
	ctrl.session.back()
	ctrl.b.statuses.apply_forced(h, _load_status("silence"))
	menu.open(ctrl.session)
	assert_eq(menu.entry_labels(), PackedStringArray(["Atacar", "Habilidade", "Item", "Suporte"]))
	assert_false(menu.entry_enabled(1), "Habilidade desabilitada com Silêncio")
	assert_true(menu.entry_enabled(0), "Atacar continua")
	menu.move(1 - menu.cursor)
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.ROOT, "entrada desabilitada não abre o submenu")

func test_silence_while_in_ability_list_returns_to_root() -> void:
	_setup(true)
	_run_until_menu()
	menu.move(1 - menu.cursor)
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.ABILITIES)
	ctrl.b.statuses.apply_forced(h, _load_status("silence"))
	ctrl.tick(0.05)
	assert_eq(menu.mode, CommandMenu.Mode.ROOT)
	assert_false(menu.entry_enabled(1))
	assert_eq(ctrl.session.step, SelectionSession.Step.COMMAND)

func test_stop_closes_open_menu_in_active_mode() -> void:
	_setup(true)
	_run_until_menu()
	assert_true(menu.visible)
	ctrl.b.statuses.apply_forced(h, _load_status("stop"))
	ctrl.tick(0.05)
	assert_false(menu.visible)
	assert_null(ctrl.session)

func test_confused_hero_does_not_open_menu() -> void:
	_setup()
	ctrl.b.statuses.apply_forced(h, _load_status("confusion"))
	var started: Array[String] = []
	ctrl.action_started.connect(func(a: PendingAction) -> void: started.append(String(a.actor.id)))
	for i: int in 200:
		ctrl.tick(0.05)
		if not started.is_empty():
			break
	assert_eq(started, ["a"] as Array[String], "agiu sozinho")
	assert_false(menu.visible)
	assert_eq(menu.mode, CommandMenu.Mode.CLOSED)

func test_scene_confused_heroes_act_without_menu() -> void:
	var packed: PackedScene = load(SCENE) as PackedScene
	var s: BattleScene = packed.instantiate() as BattleScene
	s.balance = Fixtures.cfg()
	add_child_autofree(s)
	s.set_process(false)
	var heroes: Array[HeroState] = []
	for id: String in ["teste_a", "teste_b", "teste_c"]:
		heroes.append(HeroState.create(load("res://data/test/heroes/%s.tres" % id) as CharacterDef, s.balance))
	s.start(heroes)
	var long_confusion: StatusDef = _status(StatusDef.Kind.CONFUSION, &"confusion")
	long_confusion.duration = 99
	for c: Combatant in s.ctrl.b.heroes:
		s.ctrl.b.statuses.apply_forced(c, long_confusion)
	# Inimigos parados: o dano não tira a Confusão dos heróis (e eles se atacam, então só o primeiro golpe importa).
	var long_stop: StatusDef = _status(StatusDef.Kind.STOP, &"stop")
	long_stop.seconds = 999.0
	for c: Combatant in s.ctrl.b.enemies:
		s.ctrl.b.statuses.apply_forced(c, long_stop)
	var started: Array[String] = []
	s.ctrl.action_started.connect(func(a: PendingAction) -> void: started.append(String(a.actor.id)))
	for i: int in 300:
		s.ctrl.tick(0.1)
		if s.ctrl.session != null:
			break
	# O golpe da Confusão tira a Confusão de quem o recebe; o menu só abre para quem já está curado.
	assert_gte(started.size(), 1, "heróis confusos agiram sozinhos")
	if s.ctrl.session != null:
		assert_false(s.ctrl.session.actor.is_confused(), "nenhum herói confuso abre menu")

# --- Itens ---

func _use_item(it: ItemDef, target: Combatant, user: Combatant, b: BattleState) -> ActionResult:
	var a := PendingAction.new()
	a.actor = user
	a.item = it
	a.center = target
	a.center_pos = target.position
	return ActionExecutor.apply(a, b)

func _battle_pair() -> BattleState:
	var d: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 10, 5, 2))
	h = Combatant.from_hero(HeroState.create(d, cfg), Vector2.ZERO)
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 1, 1, 1)), &"x", Vector2(100, 0), cfg)
	return BattleState.create(cfg, ScriptedDice.new(), [h], [x])

func test_remedio_removes_only_confusion_silence_blind() -> void:
	var it: ItemDef = load("res://data/test/items/remedio.tres") as ItemDef
	assert_eq(it.display_name, "Remédio")
	var b: BattleState = _battle_pair()
	for id: String in ["confusion", "silence", "blind", "poison", "stop"]:
		b.statuses.apply_forced(h, _load_status(id))
	var r: ActionResult = _use_item(it, h, h, b)
	assert_eq(r.hits[0]["amount"], 3)
	var left: Array[StringName] = []
	for s: ActiveStatus in h.statuses:
		left.append(s.def.id)
	assert_eq(left, [&"poison", &"stop"] as Array[StringName])

func test_panaceia_removes_all_negatives_and_keeps_buffs() -> void:
	var it: ItemDef = load("res://data/test/items/panaceia.tres") as ItemDef
	var b: BattleState = _battle_pair()
	for id: String in ["confusion", "poison", "stop", "spd_down", "regen", "str_up"]:
		b.statuses.apply_forced(h, _load_status(id))
	var r: ActionResult = _use_item(it, h, h, b)
	assert_eq(r.hits[0]["amount"], 4)
	var left: Array[StringName] = []
	for s: ActiveStatus in h.statuses:
		left.append(s.def.id)
	assert_eq(left, [&"regen", &"str_up"] as Array[StringName])

func test_items_are_usable_in_battle_menu_and_consumed() -> void:
	_setup()
	var it: ItemDef = load("res://data/test/items/panaceia.tres") as ItemDef
	ctrl.b.inventory.add(it, 1)
	ctrl.b.statuses.apply_forced(h, _load_status("silence"))
	_run_until_menu()
	var labels: PackedStringArray = menu.entry_labels()
	assert_true(menu.entry_enabled(2), "Item habilitado com Panaceia")
	menu.move(2 - menu.cursor)
	menu.accept()
	assert_eq(menu.entry_labels(), PackedStringArray(["Panaceia x1"]))
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	menu.accept()
	assert_eq(ctrl.b.inventory.available(&"panaceia"), 0)
	for i: int in 40:
		ctrl.tick(0.05)
	assert_false(h.is_silenced(), "Panaceia curou o Silêncio")
	assert_eq(labels.size(), 4)

func test_status_items_in_the_field() -> void:
	# Só o Veneno persiste no mapa (M15): a Panaceia (todos os negativos) serve; o Remédio de teste (CNF/SIL/CEG) não.
	var remedio: ItemDef = load("res://data/test/items/remedio.tres") as ItemDef
	assert_false(FieldActions.is_field_usable(remedio.effects), "remedio só em batalha")
	var panaceia: ItemDef = load("res://data/test/items/panaceia.tres") as ItemDef
	assert_true(FieldActions.is_field_usable(panaceia.effects), "panaceia cura o veneno no campo")

func test_enemy_appliers_exist() -> void:
	var pairs: Dictionary = {"pare": "stop", "confusao": "confusion", "silencio": "silence", "cegueira": "blind", "fraqueza": "str_down", "fragilidade": "vit_down", "atraso": "spd_down", "regeneracao": "regen"}
	for file: String in pairs:
		var ab: AbilityDef = load("res://data/test/abilities/%s.tres" % file) as AbilityDef
		assert_not_null(ab, file)
		assert_eq(ab.effects[0].kind, EffectDef.Kind.APPLY_STATUS)
		assert_eq(ab.effects[0].status.id, StringName(pairs[file]), file)

# --- Fim da batalha: HP gravado nunca passa do maximo real ---

func test_battle_end_clamps_hero_hp_after_vitality_debuff() -> void:
	var packed: PackedScene = load(SCENE) as PackedScene
	var s: BattleScene = packed.instantiate() as BattleScene
	s.balance = Fixtures.cfg()
	add_child_autofree(s)
	s.set_process(false)
	var heroes: Array[HeroState] = []
	for id: String in ["teste_a", "teste_b", "teste_c"]:
		heroes.append(HeroState.create(load("res://data/test/heroes/%s.tres" % id) as CharacterDef, s.balance))
	s.start(heroes)
	var real_max: int = StatCalculator.hp_max(Combatant.from_hero(heroes[0], Vector2.ZERO), s.balance)
	var debuff: StatusDef = _status(StatusDef.Kind.ATTR_MOD, &"vit_down", &"vitality", -5)
	debuff.duration = 99
	var hero: Combatant = s.ctrl.b.heroes[0]
	s.ctrl.b.statuses.apply_forced(hero, debuff)
	assert_lt(StatCalculator.hp_max(hero, s.balance), real_max, "debuff baixou o maximo na batalha")
	hero.hp = real_max + 50
	s.ctrl.outcome = BattleController.Outcome.FLED
	s._on_battle_ended(BattleController.Outcome.FLED)
	assert_lte(heroes[0].hp, real_max, "HP gravado no HeroState respeita o maximo real")

# --- nome no HUD: cabe na largura (M12.5) -----------------------------------------------

func _width(text: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func test_short_name_keeps_the_base_size_and_text() -> void:
	var fit: Dictionary = CombatantView.fit_name(ThemeDB.fallback_font, "Ana", CombatantView.BAR_W)
	assert_eq(fit["text"], "Ana")
	assert_eq(fit["size"], CombatantView.NAME_SIZE)

func test_long_name_shrinks_before_it_is_cut() -> void:
	var name: String = "Guardião (fatia)"
	assert_gt(_width(name, CombatantView.NAME_SIZE), CombatantView.BAR_W, "no tamanho base não cabe")
	var fit: Dictionary = CombatantView.fit_name(ThemeDB.fallback_font, name, CombatantView.BAR_W)
	assert_eq(fit["text"], name, "encolhendo, o nome inteiro cabe")
	assert_lt(fit["size"], CombatantView.NAME_SIZE)
	assert_gte(fit["size"], CombatantView.NAME_MIN_SIZE)
	assert_lte(_width(fit["text"], fit["size"]), CombatantView.BAR_W)

func test_very_long_name_ends_with_an_ellipsis_at_the_minimum_size() -> void:
	var name: String = "Nome de teste absurdamente comprido para a barra"
	var fit: Dictionary = CombatantView.fit_name(ThemeDB.fallback_font, name, CombatantView.BAR_W)
	assert_eq(fit["size"], CombatantView.NAME_MIN_SIZE)
	assert_true(String(fit["text"]).ends_with("…"))
	assert_lt(String(fit["text"]).length(), name.length())
	assert_lte(_width(fit["text"], fit["size"]), CombatantView.BAR_W)
	assert_true(name.begins_with(String(fit["text"]).trim_suffix("…")), "o início do nome é preservado")

func test_fit_name_handles_empty_and_degenerate_widths() -> void:
	assert_eq(CombatantView.fit_name(ThemeDB.fallback_font, "", CombatantView.BAR_W)["text"], "")
	var tiny: Dictionary = CombatantView.fit_name(ThemeDB.fallback_font, "Abc", 1.0)
	assert_eq(tiny["text"], "…", "nem uma letra cabe: só as reticências")

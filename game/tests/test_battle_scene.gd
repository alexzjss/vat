extends GutTest

const SCENE: String = "res://battle/battle_scene.tscn"
const HEROES: Array[String] = ["teste_a", "teste_b", "teste_c"]

var _outcomes: Array[BattleController.Outcome] = []

func before_each() -> void:
	_outcomes = []

func _heroes(cfg: BalanceConfig) -> Array[HeroState]:
	var out: Array[HeroState] = []
	for id: String in HEROES:
		out.append(HeroState.create(load("res://data/test/heroes/%s.tres" % id) as CharacterDef, cfg))
	return out

func _scene(auto: bool) -> BattleScene:
	var packed: PackedScene = load(SCENE) as PackedScene
	assert_not_null(packed)
	var s: BattleScene = packed.instantiate() as BattleScene
	s.balance = Fixtures.cfg()
	s.auto_battle = auto
	add_child_autofree(s)
	s.set_process(false)
	return s

func _on_ended(o: BattleController.Outcome) -> void:
	_outcomes.append(o)

func test_start_places_combatants_at_markers() -> void:
	var s: BattleScene = _scene(false)
	var hs: Array[HeroState] = _heroes(s.balance)
	hs[0].hp = 7
	s.start(hs)
	var b: BattleState = s.ctrl.b
	assert_eq(b.heroes.size(), 3)
	assert_eq(b.enemies.size(), 3)
	assert_eq(b.heroes[0].hp, 7, "preserva HP do HeroState")
	assert_eq(b.heroes[0].position, (s.get_node("HeroSpot1") as Marker2D).position)
	assert_eq(b.enemies[2].position, (s.get_node("EnemySpot3") as Marker2D).position)
	assert_eq(b.inventory.available(&"pocao"), 3)
	assert_eq(b.inventory.available(&"eter"), 2)
	assert_eq(b.inventory.available(&"reviver"), 1)
	assert_eq(s.views.size(), 6)

func test_hero_turn_without_auto_leaves_session_open() -> void:
	var s: BattleScene = _scene(false)
	s.start(_heroes(s.balance))
	for i: int in 300:
		s.ctrl.tick(0.1)
		if s.ctrl.is_paused():
			break
	assert_true(s.ctrl.is_paused(), "tempo para no turno do heroi")
	assert_eq(s.ctrl.session.actor.team, Combatant.Team.HERO)
	var menu: CommandMenu = s.get_node("UI/CommandMenu") as CommandMenu
	assert_true(menu.visible, "menu abre sozinho no turno do heroi")
	assert_eq(menu.session, s.ctrl.session)
	assert_eq(menu.ctrl, s.ctrl)

func test_menu_submit_resumes_battle() -> void:
	var s: BattleScene = _scene(false)
	s.start(_heroes(s.balance))
	for i: int in 300:
		s.ctrl.tick(0.1)
		if s.ctrl.is_paused():
			break
	var menu: CommandMenu = s.get_node("UI/CommandMenu") as CommandMenu
	menu.accept()
	assert_eq(menu.mode, CommandMenu.Mode.TARGET)
	assert_true((s.get_node("TargetPreview") as TargetPreview).visible)
	menu.accept()
	assert_false(s.ctrl.is_paused())
	assert_not_null(s.ctrl.executing)
	assert_false(menu.visible)
	for v: CombatantView in s.views.values():
		assert_false(v.highlighted)

func test_auto_battle_runs_to_end() -> void:
	var s: BattleScene = _scene(true)
	s.dice_seed = 7
	s.start(_heroes(s.balance))
	s.ctrl.battle_ended.connect(_on_ended)
	var menu: CommandMenu = s.get_node("UI/CommandMenu") as CommandMenu
	s.ctrl.hero_turn.connect(func(_ss: SelectionSession) -> void: assert_false(menu.visible, "auto_battle ignora o menu"))
	var steps: int = 0
	while _outcomes.is_empty() and steps < 20000:
		s.ctrl.tick(0.1)
		steps += 1
	assert_eq(_outcomes.size(), 1, "batalha terminou em %d passos" % steps)
	assert_ne(s.ctrl.outcome, BattleController.Outcome.ONGOING)
	gut.p("auto battle: %s em %d passos (%.1f s de jogo)" % [BattleController.Outcome.keys()[s.ctrl.outcome], steps, steps * 0.1])

func test_auto_start_on_ready() -> void:
	var packed: PackedScene = load(SCENE) as PackedScene
	var s: BattleScene = packed.instantiate() as BattleScene
	add_child_autofree(s)
	s.set_process(false)
	await wait_process_frames(2)
	assert_not_null(s.ctrl, "cena inicia sozinha (F5)")
	assert_eq(s.ctrl.b.heroes.size(), 4)

func _view_hit(amount: int, dodged: bool) -> String:
	var v: CombatantView = (load("res://battle/combatant_view.tscn") as PackedScene).instantiate() as CombatantView
	add_child_autofree(v)
	v.show_hit({"target_id": &"x", "kind": EffectDef.Kind.DAMAGE, "amount": amount, "dodged": dodged, "status_result": -1})
	var last: Label = null
	for child: Node in v.get_children():
		if child is Label:
			last = child as Label
	assert_not_null(last, "texto flutuante criado")
	return last.text if last != null else ""

func test_zero_damage_hit_shows_blocked() -> void:
	assert_eq(_view_hit(0, false), "Bloqueado")

func test_damage_hit_shows_amount_and_dodge() -> void:
	assert_eq(_view_hit(7, false), "-7")
	assert_eq(_view_hit(0, true), "Esquiva")

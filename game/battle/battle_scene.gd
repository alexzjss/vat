class_name BattleScene
extends Node2D

## Cena de batalha: monta combatentes nos marcadores, avança o BattleController,
## atualiza as views e abre o CommandMenu no turno de herói.
## Debug: `-- --demo-menu` roteiriza entradas no menu; `-- --demo-debug` abre o painel F1 com auto_battle
## (verificação com --write-movie).

const VIEW_SCENE: PackedScene = preload("res://battle/combatant_view.tscn")

@export var balance: BalanceConfig
@export var test_heroes: Array[CharacterDef] = []
@export var enemy_defs: Array[EnemyDef] = []
@export var start_items: Array[ItemDef] = []
@export var start_item_counts: Array[int] = []
## Só testes/debug: confirma o ataque básico no primeiro candidato em cada turno de herói.
@export var auto_battle: bool = false

var ctrl: BattleController
var views: Dictionary[StringName, CombatantView] = {}

var _demo: bool = false
var _demo_area_done: bool = false

@onready var _outcome_label: Label = $OutcomeLabel
@onready var _menu: CommandMenu = $UI/CommandMenu
@onready var _preview: TargetPreview = $TargetPreview
@onready var _debug: DebugPanel = $UI/DebugPanel

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_demo = args.has("--demo-menu")
	if args.has("--demo-debug"):
		auto_battle = true
		_debug.visible = true
	_menu.submitted.connect(_on_menu_submitted)
	_auto_start.call_deferred()

func _auto_start() -> void:
	if ctrl != null:
		return
	var heroes: Array[HeroState] = []
	for d: CharacterDef in test_heroes:
		heroes.append(HeroState.create(d, balance))
	start(heroes)

func start(heroes: Array[HeroState]) -> void:
	_clear()
	var hero_cs: Array[Combatant] = []
	for i: int in heroes.size():
		hero_cs.append(Combatant.from_hero(heroes[i], _spot("HeroSpot%d" % (i + 1))))
	var enemy_cs: Array[Combatant] = []
	for i: int in enemy_defs.size():
		var d: EnemyDef = enemy_defs[i]
		enemy_cs.append(Combatant.from_enemy(d, d.id, _spot("EnemySpot%d" % (i + 1)), balance))
	var b: BattleState = BattleState.create(balance, Dice.new(), hero_cs, enemy_cs)
	for i: int in start_items.size():
		b.inventory.add(start_items[i], start_item_counts[i])
	ctrl = BattleController.new(b)
	_menu.close()
	_menu.ctrl = ctrl
	_menu.preview = _preview
	for c: Combatant in b.all():
		var v: CombatantView = VIEW_SCENE.instantiate() as CombatantView
		add_child(v)
		v.bind(c, balance)
		views[c.id] = v
	ctrl.hero_turn.connect(_on_hero_turn)
	ctrl.action_impact.connect(_on_action_impact)
	ctrl.status_tick.connect(_on_status_tick)
	ctrl.turn_lost.connect(_on_turn_lost)
	ctrl.battle_ended.connect(_on_battle_ended)

func _process(delta: float) -> void:
	if ctrl != null:
		ctrl.tick(delta)
		_debug.refresh(ctrl.b, ctrl)

func _spot(node_name: String) -> Vector2:
	return (get_node(node_name) as Marker2D).position

func _clear() -> void:
	for v: CombatantView in views.values():
		v.queue_free()
	views.clear()
	if _outcome_label != null:
		_outcome_label.text = ""

func _on_hero_turn(session: SelectionSession) -> void:
	for v: CombatantView in views.values():
		v.highlighted = v.combatant == session.actor
	if auto_battle:
		_auto_confirm(session)
		return
	_menu.open(session)
	if _demo:
		_run_demo(session)

func _on_menu_submitted(_a: PendingAction) -> void:
	_set_highlight_off()

func _auto_confirm(session: SelectionSession) -> void:
	session.choose_ability(session.actor.basic_attack)
	session.set_center(session.target_candidates()[0])
	_set_highlight_off()
	ctrl.submit(session.confirm())

func _set_highlight_off() -> void:
	for v: CombatantView in views.values():
		v.highlighted = false

func _on_action_impact(_a: PendingAction, r: ActionResult) -> void:
	for hit: Dictionary in r.hits:
		var v: CombatantView = views.get(hit["target_id"])
		if v != null:
			v.show_hit(hit)

func _on_status_tick(c: Combatant, out: StatusSystem.AtbFullOutcome) -> void:
	if out.poison_damage > 0 and views.has(c.id):
		views[c.id].float_text("-%d" % out.poison_damage, Color(0.7, 0.3, 0.9))

func _on_turn_lost(c: Combatant) -> void:
	if views.has(c.id):
		views[c.id].float_text("Perdeu o turno", Color.WHITE)

func _on_battle_ended(outcome: BattleController.Outcome) -> void:
	_set_highlight_off()
	_outcome_label.text = "Vitória!" if outcome == BattleController.Outcome.VICTORY else "Derrota..."

# --- Roteiro de debug (--demo-menu) -------------------------------------------------

func _run_demo(s: SelectionSession) -> void:
	var area: AbilityDef = null
	var line: AbilityDef = null
	for ab: AbilityDef in s.actor.abilities:
		if ab.shape == AbilityDef.Shape.CIRCLE_TARGET and area == null:
			area = ab
		elif ab.shape == AbilityDef.Shape.LINE and line == null:
			line = ab
	await _demo_wait(0.6)
	if area != null and not _demo_area_done:
		_demo_area_done = true
		_demo_pick("Habilidade")
		await _demo_wait(0.6)
		_demo_pick(area.display_name)
		await _demo_wait(0.8)
		_menu.move(1)
		await _demo_wait(0.8)
		_menu.cancel()
		await _demo_wait(0.5)
		if line != null:
			_demo_pick("Habilidade")
			await _demo_wait(0.4)
			_demo_pick(line.display_name)
			await _demo_wait(0.8)
			_menu.move(1)
			await _demo_wait(0.8)
			_menu.accept()
			return
	_demo_pick("Atacar")
	await _demo_wait(0.4)
	_menu.accept()

func _demo_wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _demo_pick(prefix: String) -> void:
	var labels: PackedStringArray = _menu.entry_labels()
	for i: int in labels.size():
		if labels[i].begins_with(prefix):
			_menu.move(i - _menu.cursor)
			_menu.accept()
			return

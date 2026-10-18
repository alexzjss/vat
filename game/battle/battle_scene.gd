class_name BattleScene
extends Node2D

## Cena de batalha somente leitura (o menu entra na Task 13).
## Monta combatentes nos marcadores, avança o BattleController e atualiza as views.

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

@onready var _outcome_label: Label = $OutcomeLabel

func _ready() -> void:
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

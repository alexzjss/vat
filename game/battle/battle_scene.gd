class_name BattleScene
extends Node2D

## Cena de batalha: monta combatentes nos marcadores, avança o BattleController,
## atualiza as views e abre o CommandMenu no turno de herói.
## Debug: `-- --demo-menu` roteiriza entradas no menu; `-- --demo-debug` abre o painel F1 com auto_battle
## `-- --demo-result` roda auto_battle (inimigos com 1/4 do HP) até o fim e roteiriza as telas de resultado/nível
## (verificação com --write-movie).

const VIEW_SCENE: PackedScene = preload("res://battle/combatant_view.tscn")

@export var balance: BalanceConfig
@export var test_heroes: Array[CharacterDef] = []
@export var enemy_defs: Array[EnemyDef] = []
@export var start_items: Array[ItemDef] = []
@export var start_item_counts: Array[int] = []
## Só testes/debug: confirma o ataque básico no primeiro candidato em cada turno de herói.
@export var auto_battle: bool = false
## Semente do Dice da batalha (-1 = aleatório). Testes usam valor fixo para desfecho determinístico.
@export var dice_seed: int = -1

var ctrl: BattleController
var views: Dictionary[StringName, CombatantView] = {}
## Os HeroState da batalha atual (os mesmos objetos passam para a próxima).
var hero_states: Array[HeroState] = []
## XP concedida na última vitória, por id de herói.
var last_xp: Dictionary[StringName, int] = {}

enum Phase { BATTLE, RESULT, LEVEL_UP, FIGHT_AGAIN, DEFEAT }

var phase: Phase = Phase.BATTLE
var _snapshots: Array[Dictionary] = []
var _level_queue: Array[HeroState] = []
var _demo_result: bool = false

var _demo: bool = false
var _demo_area_done: bool = false

@onready var _outcome_label: Label = $OutcomeLabel
@onready var _menu: CommandMenu = $UI/CommandMenu
@onready var _preview: TargetPreview = $TargetPreview
@onready var _debug: DebugPanel = $UI/DebugPanel
@onready var _result: ResultScreen = $UI/ResultScreen
@onready var _level_up: LevelUpScreen = $UI/LevelUpScreen

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_demo = args.has("--demo-menu")
	if args.has("--demo-debug"):
		auto_battle = true
		_debug.visible = true
	if args.has("--demo-result"):
		auto_battle = true
		_demo_result = true
	_menu.submitted.connect(_on_menu_submitted)
	_result.accepted.connect(_on_result_accepted)
	_level_up.closed.connect(_on_level_up_closed)
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
	hero_states = heroes
	_snapshots = []
	for h: HeroState in heroes:
		_snapshots.append(_snapshot(h))
	last_xp = {}
	_level_queue = []
	phase = Phase.BATTLE
	_result.close()
	if _level_up.visible:
		_level_up.leave()
	var hero_cs: Array[Combatant] = []
	for i: int in heroes.size():
		hero_cs.append(Combatant.from_hero(heroes[i], _spot("HeroSpot%d" % (i + 1))))
	var enemy_cs: Array[Combatant] = []
	for i: int in enemy_defs.size():
		var d: EnemyDef = enemy_defs[i]
		enemy_cs.append(Combatant.from_enemy(d, d.id, _spot("EnemySpot%d" % (i + 1)), balance))
	var b: BattleState = BattleState.create(balance, Dice.new(dice_seed), hero_cs, enemy_cs)
	for i: int in start_items.size():
		b.inventory.add(start_items[i], start_item_counts[i])
	if _demo_result:
		# Só debug: o auto_battle (ataque básico no primeiro alvo) perde com o conteúdo de teste;
		# enfraquece os inimigos para o roteiro chegar à vitória e às telas de nível.
		for e: Combatant in enemy_cs:
			e.hp = maxi(1, e.hp / 4)
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
	_menu.close()
	_outcome_label.text = "Vitória!" if outcome == BattleController.Outcome.VICTORY else "Derrota..."
	var b: BattleState = ctrl.b
	# HP/AP persistem entre batalhas (spec §7); caídos ficam com HP 0, sem recuperação automática.
	for c: Combatant in b.heroes:
		c.hero_state.hp = c.hp
		c.hero_state.ap = c.ap
	if outcome == BattleController.Outcome.VICTORY:
		_grant_victory(b)
	else:
		phase = Phase.DEFEAT
		_result.show_defeat()
	if _demo_result:
		_run_demo_result()

func _grant_victory(b: BattleState) -> void:
	last_xp = XpCalculator.combat_xp(b.ledger, b.enemies, b.heroes, false)
	var before: Dictionary = {}
	for c: Combatant in b.heroes:
		var h: HeroState = c.hero_state
		before[h.def.id] = h.level
		XpCalculator.grant(h, last_xp.get(h.def.id, 0), balance)
	phase = Phase.RESULT
	_result.show_for(last_xp, before, hero_states)

func _on_result_accepted() -> void:
	match phase:
		Phase.RESULT:
			_result.visible = false
			_level_queue = []
			for h: HeroState in hero_states:
				if h.pending_points > 0:
					_level_queue.append(h)
			phase = Phase.LEVEL_UP
			_next_level_up()
		Phase.FIGHT_AGAIN:
			fight_again()
		Phase.DEFEAT:
			retry()

func _next_level_up() -> void:
	if _level_queue.is_empty():
		phase = Phase.FIGHT_AGAIN
		_result.set_action("Lutar de novo")
		return
	_level_up.open(_level_queue.pop_front())

func _on_level_up_closed(_h: HeroState) -> void:
	if phase == Phase.LEVEL_UP:
		_next_level_up()

## Nova batalha com os mesmos HeroState (HP/AP como terminaram); inimigos e inventário novos.
func fight_again() -> void:
	start(hero_states)

## Restaura o estado do início da batalha perdida e recomeça.
func retry() -> void:
	var heroes: Array[HeroState] = hero_states
	for i: int in heroes.size():
		_restore(heroes[i], _snapshots[i])
	start(heroes)

func _snapshot(h: HeroState) -> Dictionary:
	return {
		"hp": h.hp, "ap": h.ap, "xp": h.xp, "level": h.level, "pending": h.pending_points,
		"allocated": Stats.make(h.allocated.strength, h.allocated.speed, h.allocated.vitality, h.allocated.aura),
	}

func _restore(h: HeroState, snap: Dictionary) -> void:
	h.hp = snap["hp"]
	h.ap = snap["ap"]
	h.xp = snap["xp"]
	h.level = snap["level"]
	h.pending_points = snap["pending"]
	var a: Stats = snap["allocated"]
	h.allocated = Stats.make(a.strength, a.speed, a.vitality, a.aura)

# --- Roteiro de debug (--demo-result) -----------------------------------------------

func _run_demo_result() -> void:
	await _demo_wait(1.5)
	if phase == Phase.DEFEAT:
		return
	_result.accept()
	while phase == Phase.LEVEL_UP and _level_up.visible:
		await _demo_wait(0.8)
		_level_up.adjust(1)
		await _demo_wait(0.4)
		_level_up.move(2)
		_level_up.adjust(1)
		await _demo_wait(1.0)
		_level_up.move(LevelUpScreen.ROW_CONFIRM - _level_up.cursor)
		await _demo_wait(0.5)
		_level_up.accept()

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

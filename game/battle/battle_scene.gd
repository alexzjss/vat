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
## Só debug (`--demo-fatia`): no auto_battle, devolve a ação do herói no lugar do ataque básico (nulo = o padrão).
## Recebe a SelectionSession; ao devolver nulo deve deixá-la em estado limpo.
var auto_hook: Callable = Callable()
## Semente do Dice da batalha (-1 = aleatório). Testes usam valor fixo para desfecho determinístico.
@export var dice_seed: int = -1
## Configurações do jogador (velocidade, memória do cursor, modo ATB). Nulo = padrões (Espera, x1.0, sem memória).
var settings: GameSettings
## Terreno do mapa (M15), repassado ao BattleState e mostrado num canto; nulo = sem efeito (e sem rótulo).
var terrain: TerrainDef
## Só no modo MAP: o encontro permite fugir (EncounterDef.can_flee). Aplicado ao controlador em start_with.
var can_flee: bool = true
## Só testes/demo: -1 lê a ação `flee`; 0/1 força solta/segurada.
var flee_input_override: int = -1

## STANDALONE: cena do M1 (F5), com "Descansar…/Lutar de novo/Tentar de novo".
## MAP: roda dentro do mapa; sem fundo, aceitar o resultado emite `finished` (sem reiniciar).
enum Mode { STANDALONE, MAP }

## Só no modo MAP: o jogador escolheu "Continuar" (após as telas de nível ou no Game Over).
signal finished(outcome: BattleController.Outcome)

var mode: Mode = Mode.STANDALONE
var ctrl: BattleController
var views: Dictionary[StringName, CombatantView] = {}
## Os HeroState da batalha atual (os mesmos objetos passam para a próxima).
var hero_states: Array[HeroState] = []
## XP concedida na última vitória, por id de herói.
var last_xp: Dictionary[StringName, int] = {}
## Moeda e drops da última vitória (M12); null antes de vencer.
var last_rewards: BattleRewards
## Só no modo MAP: o estado do jogo que recebe a moeda e os drops da vitória (null = só mostra, não aplica).
var game_state: GameState

enum Phase { BATTLE, RESULT, LEVEL_UP, FIGHT_AGAIN, DEFEAT, CONTINUE, DONE }

## Índices das ações da tela de resultado (ordem de set_actions/show_defeat).
const ACTION_REST: int = 0
const ACTION_REST_RETRY: int = 1

var phase: Phase = Phase.BATTLE
var _snapshots: Array[Dictionary] = []
## Reserva da batalha atual (Suporte, M8.5): os HeroState e seus snapshots (o AP gasto volta no retry).
var reserve_states: Array[HeroState] = []
var _reserve_snapshots: Array[Dictionary] = []
## View do reserva enquanto o Suporte executa (fora de `views`: nao e um combatente da batalha).
var _support_view: CombatantView
var _level_queue: Array[HeroState] = []
## Só debug (`--demo-result`, `--demo-m2`): inimigos com 1/4 do HP e roteiro das telas de resultado/nível.
var demo_result: bool = false
## Deslize de entrada (modo mapa): views vão de _slide_from até a posição; sem tick enquanto dura.
var _slide_from: Vector2 = Vector2.INF
var _slide_left: float = 0.0

var _flee_held: bool = false
var _flee_bar: ProgressBar
var _flee_label: Label
var _banner: Label
var _banner_left: float = 0.0
## Aviso menor (M11: "X prepara Y!"), abaixo da faixa.
var _notice: Label
var _terrain_label: Label
var _notice_left: float = 0.0

var _demo: bool = false
var _demo_area_done: bool = false

@onready var _background: CanvasItem = $Background
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
		demo_result = true
	_build_flee_ui()
	_menu.submitted.connect(_on_menu_submitted)
	_result.accepted.connect(_on_result_accepted)
	_level_up.closed.connect(_on_level_up_closed)
	_auto_start.call_deferred()

func _auto_start() -> void:
	if ctrl != null:
		return
	var heroes: Array[HeroState] = []
	# Só os 4 primeiros (máximo de ativos); HeroSpot1..4.
	for d: CharacterDef in test_heroes.slice(0, GameState.MAX_ACTIVE):
		heroes.append(HeroState.create(d, balance))
	start(heroes)

## Standalone (M1): posições dos marcadores, inimigos de enemy_defs e inventário novo de start_items.
func start(heroes: Array[HeroState], reserve: Array[HeroState] = []) -> void:
	var hero_pos: Array[Vector2] = []
	for i: int in heroes.size():
		hero_pos.append(_spot("HeroSpot%d" % (i + 1)))
	var enemy_pos: Array[Vector2] = []
	for i: int in enemy_defs.size():
		enemy_pos.append(_spot("EnemySpot%d" % (i + 1)))
	var inv := Inventory.new()
	for i: int in start_items.size():
		inv.add(start_items[i], start_item_counts[i])
	start_with(heroes, enemy_defs, hero_pos, enemy_pos, inv, Vector2.INF, Initiative.Kind.NORMAL, reserve, _spot("SupportSpot") if has_node("SupportSpot") else Vector2.INF)

## Monta a batalha com essas posições e esse objeto de inventário (não copia).
## from_pos finito: as views começam lá e deslizam até a posição em cfg.battle_slide_time;
## o ctrl só avança depois do deslize.
func start_with(heroes: Array[HeroState], enemies: Array[EnemyDef], hero_pos: Array[Vector2],
		enemy_pos: Array[Vector2], inventory: Inventory, from_pos: Vector2 = Vector2.INF,
		initiative: Initiative.Kind = Initiative.Kind.NORMAL, reserve: Array[HeroState] = [],
		support_pos: Vector2 = Vector2.INF) -> void:
	_clear()
	_background.visible = mode == Mode.STANDALONE
	_outcome_label.visible = mode == Mode.STANDALONE
	hero_states = heroes
	_snapshots = []
	for h: HeroState in heroes:
		_snapshots.append(h.snapshot())
	reserve_states = reserve
	_reserve_snapshots = []
	for h: HeroState in reserve:
		_reserve_snapshots.append(h.snapshot())
	last_xp = {}
	last_rewards = null
	_level_queue = []
	phase = Phase.BATTLE
	_result.close()
	if _level_up.visible:
		_level_up.leave()
	var hero_cs: Array[Combatant] = []
	for i: int in heroes.size():
		hero_cs.append(Combatant.from_hero(heroes[i], hero_pos[i]))
	var enemy_cs: Array[Combatant] = []
	for i: int in enemies.size():
		var d: EnemyDef = enemies[i]
		# No mapa o encontro pode repetir um inimigo: id indexado. Standalone mantém def.id (testes do M1).
		var id: StringName = d.id if mode == Mode.STANDALONE else StringName("%s_%d" % [d.id, i])
		enemy_cs.append(Combatant.from_enemy(d, id, enemy_pos[i], balance))
	# Bestiario (M15): todo inimigo presente fica visto.
	if game_state != null:
		game_state.record_seen(enemy_cs)
	var b: BattleState = BattleState.create(balance, Dice.new(dice_seed), hero_cs, enemy_cs)
	b.inventory = inventory
	b.terrain = terrain
	_refresh_terrain_label()
	b.reserve = reserve
	b.support_pos = support_pos
	if demo_result:
		# Só debug: o auto_battle (ataque básico no primeiro alvo) perde com o conteúdo de teste;
		# enfraquece os inimigos para o roteiro chegar à vitória e às telas de nível.
		for e: Combatant in enemy_cs:
			e.hp = maxi(1, e.hp / 4)
	b.apply_initiative(initiative)
	ctrl = BattleController.new(b)
	ctrl.speed_mult = settings.speed_mult() if settings != null else 1.0
	ctrl.can_flee = can_flee and mode == Mode.MAP
	ctrl.active_mode = settings != null and settings.atb_mode == GameSettings.AtbMode.ACTIVE
	_menu.remember_cursor = settings != null and settings.cursor_memory
	_menu.reset_memory()
	_menu.close()
	_menu.ctrl = ctrl
	_menu.preview = _preview
	for c: Combatant in b.all():
		var v: CombatantView = VIEW_SCENE.instantiate() as CombatantView
		add_child(v)
		v.bind(c, balance)
		views[c.id] = v
	_show_banner(initiative)
	_slide_from = from_pos
	_slide_left = 0.0
	if from_pos.is_finite() and balance.battle_slide_time > 0.0:
		_slide_left = balance.battle_slide_time
		for v: CombatantView in views.values():
			v.position = from_pos
	ctrl.hero_turn.connect(_on_hero_turn)
	ctrl.session_cancelled.connect(_on_session_cancelled)
	ctrl.session_reset.connect(_on_session_reset)
	ctrl.confused_act.connect(_on_confused_act)
	ctrl.action_started.connect(_on_action_started)
	ctrl.action_finished.connect(_on_action_finished)
	ctrl.action_impact.connect(_on_action_impact)
	ctrl.status_tick.connect(_on_status_tick)
	ctrl.bleed_tick.connect(_on_bleed_tick)
	ctrl.phase_changed.connect(_on_phase_changed)
	ctrl.charge_started.connect(_on_charge_started)
	ctrl.counter_fired.connect(_on_counter_fired)
	ctrl.turn_lost.connect(_on_turn_lost)
	ctrl.petrified.connect(_on_petrified)
	ctrl.doom_fired.connect(_on_doom_fired)
	ctrl.battle_ended.connect(_on_battle_ended)

func _process(delta: float) -> void:
	if ctrl == null:
		return
	_tick_banner(delta)
	for v: CombatantView in views.values():
		v.shielded = ctrl.b.core_shielded(v.combatant)
	if _slide_left > 0.0:
		_advance_slide(delta)
	else:
		update_flee(delta)
		ctrl.tick(delta)
	_debug.refresh(ctrl.b, ctrl)

## Fuga em tempo real (delta sem o multiplicador de velocidade da batalha e sem a pausa do modo Espera).
func update_flee(real_delta: float) -> void:
	_flee_held = flee_input_override == 1 if flee_input_override >= 0 else Input.is_action_pressed("flee")
	ctrl.update_flee(real_delta, _flee_held)
	_refresh_flee_ui()

## Mensagem de fuga: "Não dá para fugir!" se está segurando e o encontro não permite.
func flee_message() -> String:
	if mode != Mode.MAP or ctrl == null or ctrl.outcome != BattleController.Outcome.ONGOING:
		return ""
	if _flee_held and not ctrl.can_flee:
		return "Não dá para fugir!"
	if ctrl.flee_gauge > 0.0:
		return "Fugindo..."
	return ""

func _build_flee_ui() -> void:
	var ui: Node = get_node_or_null(^"UI")
	if ui == null:
		return
	_banner = Label.new()
	_banner.position = Vector2(340, 60)
	_banner.size = Vector2(600, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	ui.add_child(_banner)
	_notice = Label.new()
	_notice.position = Vector2(240, 124)
	_notice.size = Vector2(800, 40)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_font_size_override("font_size", 28)
	_notice.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	_notice.add_theme_color_override("font_outline_color", Color.BLACK)
	_notice.add_theme_constant_override("outline_size", 6)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	ui.add_child(_notice)
	_terrain_label = Label.new()
	_terrain_label.position = Vector2(980, 8)
	_terrain_label.size = Vector2(290, 28)
	_terrain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_terrain_label.add_theme_font_size_override("font_size", 18)
	_terrain_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_terrain_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_terrain_label.add_theme_constant_override("outline_size", 4)
	_terrain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain_label.visible = false
	ui.add_child(_terrain_label)
	_flee_bar = ProgressBar.new()
	_flee_bar.min_value = 0.0
	_flee_bar.max_value = 1.0
	_flee_bar.show_percentage = false
	_flee_bar.position = Vector2(490, 668)
	_flee_bar.size = Vector2(300, 14)
	_flee_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flee_bar.visible = false
	ui.add_child(_flee_bar)
	_flee_label = Label.new()
	_flee_label.position = Vector2(490, 636)
	_flee_label.size = Vector2(300, 28)
	_flee_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flee_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flee_label.visible = false
	ui.add_child(_flee_label)

## Texto do canto: "Terreno: Chuva"; vazio sem terreno.
func terrain_text_shown() -> String:
	return _terrain_label.text if _terrain_label != null and _terrain_label.visible else ""

func _refresh_terrain_label() -> void:
	if _terrain_label == null:
		return
	var shown: bool = terrain != null and terrain.display_name != ""
	_terrain_label.text = "Terreno: %s" % terrain.display_name if shown else ""
	_terrain_label.visible = shown

func _refresh_flee_ui() -> void:
	if _flee_bar == null:
		return
	var msg: String = flee_message()
	_flee_label.text = msg
	_flee_label.visible = msg != ""
	_flee_bar.value = ctrl.flee_gauge
	_flee_bar.visible = ctrl.flee_gauge > 0.0

## Texto da faixa de iniciativa ("" para NORMAL).
static func banner_text(kind: Initiative.Kind) -> String:
	match kind:
		Initiative.Kind.PREEMPTIVE:
			return "Ataque surpresa!"
		Initiative.Kind.AMBUSH:
			return "Emboscada!"
	return ""

func banner_text_shown() -> String:
	return _banner.text if banner_visible() else ""

func banner_visible() -> bool:
	return _banner != null and _banner.visible

func _show_banner(kind: Initiative.Kind) -> void:
	_show_message(banner_text(kind))

## Faixa grande no alto (iniciativa, fase de chefe) por `banner_time`; texto vazio apaga.
func _show_message(t: String) -> void:
	if _banner == null:
		return
	_banner.text = t
	_banner.visible = t != ""
	_banner_left = balance.banner_time if t != "" else 0.0

func _tick_banner(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left = maxf(0.0, _notice_left - delta)
		if _notice_left <= 0.0:
			_notice.visible = false
	if _banner_left <= 0.0:
		return
	_banner_left = maxf(0.0, _banner_left - delta)
	if _banner_left <= 0.0:
		_banner.visible = false

func notice_text_shown() -> String:
	return _notice.text if _notice != null and _notice.visible else ""

## Aviso menor por `banner_time`: "X prepara Y!".
func _show_notice(t: String) -> void:
	if _notice == null:
		return
	_notice.text = t
	_notice.visible = t != ""
	_notice_left = balance.banner_time if t != "" else 0.0

## Chefe: entrou numa nova fase de HP.
func _on_phase_changed(_c: Combatant, banner: String) -> void:
	_show_message(banner)

## Chefe: gastou o turno preparando um ataque anunciado.
func _on_charge_started(c: Combatant, a: PendingAction) -> void:
	_show_notice("%s prepara %s!" % [c.display_name, a.ability.display_name])

## Chefe: contra-ataque logo depois da acao do heroi.
func _on_counter_fired(c: Combatant, _target: Combatant) -> void:
	if views.has(c.id):
		views[c.id].float_text("Contra-ataque!", Color(1.0, 0.8, 0.3))

func _advance_slide(delta: float) -> void:
	_slide_left = maxf(0.0, _slide_left - delta)
	var t: float = 1.0 - _slide_left / balance.battle_slide_time
	for v: CombatantView in views.values():
		v.position = _slide_from.lerp(v.combatant.position, t) if _slide_left > 0.0 else v.combatant.position

func _spot(node_name: String) -> Vector2:
	return (get_node(node_name) as Marker2D).position

func _clear() -> void:
	for v: CombatantView in views.values():
		v.queue_free()
	views.clear()
	_remove_support_view()
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

## ATB Ativo: o herói do menu aberto caiu; fecha o menu (a sessão já foi desfeita pelo controlador).
func _on_session_cancelled(_s: SelectionSession) -> void:
	_menu.close()
	_set_highlight_off()

## Silêncio no meio da escolha (modo Ativo): o menu volta ao comando raiz, com "Habilidade" desabilitado.
func _on_session_reset(_s: SelectionSession) -> void:
	_menu.reset_to_root()

## Confusão ou Berserk (M15): o combatente age sozinho; sem menu e sem IA.
func _on_confused_act(c: Combatant) -> void:
	if views.has(c.id):
		if c.is_confused():
			views[c.id].float_text("Confuso", Color(0.95, 0.6, 0.9))
		else:
			views[c.id].float_text("Berserk", Color(1.0, 0.35, 0.3))

func _on_menu_submitted(_a: PendingAction) -> void:
	_set_highlight_off()

func _auto_confirm(session: SelectionSession) -> void:
	if auto_hook.is_valid():
		var custom: PendingAction = auto_hook.call(session) as PendingAction
		if custom != null:
			_set_highlight_off()
			ctrl.submit(custom)
			return
	session.choose_ability(session.actor.basic_attack)
	session.set_center(session.target_candidates()[0])
	_set_highlight_off()
	ctrl.submit(session.confirm())

func _set_highlight_off() -> void:
	for v: CombatantView in views.values():
		v.highlighted = false

## Suporte: o reserva aparece (fade-in) na posicao dele enquanto a acao executa.
func _on_action_started(a: PendingAction) -> void:
	if a.caller == null:
		return
	_remove_support_view()
	_support_view = VIEW_SCENE.instantiate() as CombatantView
	add_child(_support_view)
	_support_view.bind(a.actor, balance)
	_support_view.modulate.a = 0.0
	_support_view.create_tween().tween_property(_support_view, "modulate:a", 1.0, balance.support_fade_time)

func _on_action_finished(a: PendingAction) -> void:
	if a.caller != null:
		_remove_support_view()

func _remove_support_view() -> void:
	if _support_view != null:
		_support_view.queue_free()
		_support_view = null

## True enquanto o reserva do Suporte esta na tela.
func support_view_visible() -> bool:
	return _support_view != null

func _on_action_impact(a: PendingAction, r: ActionResult) -> void:
	var lifesteal: int = 0
	var self_damage: int = 0
	var reflectors: Array[StringName] = []
	# Bestiario (M15): reacoes vistas e inimigos escaneados.
	if game_state != null:
		game_state.record_result(r)
	for hit: Dictionary in r.hits:
		var v: CombatantView = views.get(hit["target_id"])
		if v != null:
			v.show_hit(hit)
		# Reflexo (M15): "Refletiu" em quem devolveu o golpe, uma vez por refletor.
		var rid: StringName = hit.get("reflected_from", &"")
		if rid != &"" and not reflectors.has(rid):
			reflectors.append(rid)
			var rv: CombatantView = views.get(rid)
			if rv != null:
				rv.float_text("Refletiu", Color(0.6, 0.85, 1.0))
		lifesteal += int(hit.get("lifesteal", 0))
		self_damage += int(hit.get("self_damage", 0))
	_debug.record_impact(r, ctrl.b)
	_show_reactions(a, r, (1 if lifesteal > 0 else 0) + (1 if self_damage > 0 else 0))
	if lifesteal > 0 or self_damage > 0:
		# O reserva do Suporte nao esta em `views`: usa a vista dele.
		var av: CombatantView = views.get(a.actor.id, _support_view)
		if av != null:
			av.show_attacker_effects(lifesteal, self_damage)

## Popups das reacoes (M14): nome acima do numero, dano extra, area, estados, ATB, curas e remocoes.
func _show_reactions(a: PendingAction, r: ActionResult, attacker_slot: int) -> void:
	# Um so mapa de andares para a acao inteira: alvos dos golpes e atacante ja comecam ocupados.
	var slots: Dictionary = {}
	for hit: Dictionary in r.hits:
		var tid: StringName = hit["target_id"]
		slots[tid] = maxi(int(slots.get(tid, 0)), CombatantView.popup_slots(hit))
	slots[a.actor.id] = maxi(int(slots.get(a.actor.id, 0)), attacker_slot)
	for hit: Dictionary in r.hits:
		var def: ReactionDef = ReactionText.find_by_id(ctrl.b.reactions, hit.get("reaction", &""))
		if def == null:
			continue
		for p: Dictionary in ReactionText.plan(hit, def, a.actor.id, CombatantView.popup_slots(hit), attacker_slot, slots):
			var pv: CombatantView = views.get(p["id"], _support_view if p["id"] == a.actor.id else null)
			if pv != null:
				pv.float_text(p["text"], p["color"], p["lift"], p["size"])

func _on_bleed_tick(c: Combatant, amount: int) -> void:
	if views.has(c.id):
		views[c.id].show_bleed(amount)

func _on_status_tick(c: Combatant, out: StatusSystem.AtbFullOutcome) -> void:
	if out.poison_damage > 0 and views.has(c.id):
		views[c.id].float_text("-%d" % out.poison_damage, Color(0.7, 0.3, 0.9))
	if out.burn_damage > 0 and views.has(c.id):
		views[c.id].float_text("-%d" % out.burn_damage, Color(1.0, 0.5, 0.2))
	if out.regen_heal > 0 and views.has(c.id):
		views[c.id].float_text("+%d" % out.regen_heal, Color(0.4, 1.0, 0.5))

func _on_petrified(c: Combatant) -> void:
	if views.has(c.id):
		views[c.id].float_text("Pedra", Color.WHITE)

func _on_doom_fired(c: Combatant) -> void:
	if views.has(c.id):
		views[c.id].float_text("Contagem", Color(0.6, 0.2, 0.6))

func _on_turn_lost(c: Combatant) -> void:
	if views.has(c.id):
		views[c.id].float_text("Perdeu o turno", Color.WHITE)

func _on_battle_ended(outcome: BattleController.Outcome) -> void:
	_set_highlight_off()
	_menu.close()
	_outcome_label.text = _outcome_text(outcome)
	var b: BattleState = ctrl.b
	# HP/AP persistem entre batalhas (spec §7); caídos ficam com HP 0, sem recuperação automática
	# (só as ações "Descansar..." da tela de resultado recuperam).
	for c: Combatant in b.heroes:
		c.hero_state.hp = c.hp
		# Debuff de Vitalidade pode deixar o HP acima do maximo real: o estado do heroi nunca passa dele.
		c.hero_state.clamp_to_max(b.cfg)
		c.hero_state.ap = c.ap
		c.hero_state.limit = c.limit
		# Veneno no mapa (M15): quem sai vivo com um estado persistente o leva; quem foi curado sai sem ele.
		c.hero_state.store_field_statuses(c)
	if outcome == BattleController.Outcome.VICTORY:
		_grant_victory(b)
	elif outcome == BattleController.Outcome.FLED:
		# Sem XP; HP/AP já foram gravados acima e os itens gastos continuam gastos.
		_refresh_flee_ui()
		_finish(BattleController.Outcome.FLED)
	else:
		phase = Phase.DEFEAT
		if mode == Mode.MAP:
			# O Game dono do mapa mostra a única tela de Game Over; aqui só devolve o desfecho.
			_finish(BattleController.Outcome.DEFEAT)
		else:
			_result.show_defeat()
	if demo_result:
		_run_demo_result()

func _outcome_text(outcome: BattleController.Outcome) -> String:
	match outcome:
		BattleController.Outcome.VICTORY:
			return "Vitória!"
		BattleController.Outcome.FLED:
			return "Fugiu!"
	return "Derrota..."

func _grant_victory(b: BattleState) -> void:
	last_xp = XpCalculator.combat_xp(b.ledger, b.enemies, b.heroes, false)
	var before: Dictionary = {}
	for hs: HeroState in hero_states:
		hs.last_learned = []
	for c: Combatant in b.heroes:
		var h: HeroState = c.hero_state
		before[h.def.id] = h.level
		XpCalculator.grant(h, last_xp.get(h.def.id, 0), balance)
	last_rewards = BattleRewards.roll(b.enemies, b.dice)
	if game_state != null:
		last_rewards.apply(game_state)
		game_state.record_victory(b.enemies)
	phase = Phase.RESULT
	_result.show_for(last_xp, before, hero_states, last_rewards, balance.currency_name)

func _on_result_accepted(index: int) -> void:
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
			fight_again(index == ACTION_REST)
		Phase.CONTINUE:
			_finish(BattleController.Outcome.VICTORY)
		Phase.DEFEAT:
			if mode == Mode.MAP:
				_finish(BattleController.Outcome.DEFEAT)
			else:
				retry(index == ACTION_REST_RETRY)

## Modo MAP: fecha o resultado e devolve o desfecho a quem hospeda a cena (uma única vez).
func _finish(outcome: BattleController.Outcome) -> void:
	phase = Phase.DONE
	_result.close()
	finished.emit(outcome)

func _next_level_up() -> void:
	if _level_queue.is_empty():
		if mode == Mode.MAP:
			phase = Phase.CONTINUE
			_result.set_actions(PackedStringArray(["Continuar"]))
		else:
			phase = Phase.FIGHT_AGAIN
			_result.set_actions(PackedStringArray(["Descansar e lutar", "Lutar de novo"]))
		return
	_level_up.open(_level_queue.pop_front())

func _on_level_up_closed(_h: HeroState) -> void:
	if phase == Phase.LEVEL_UP:
		_next_level_up()

## Nova batalha com os mesmos HeroState; inimigos e inventário novos.
## rest = true: stand-in do ponto de descanso no M1 ([P-plano] 15), HP/AP cheios e caídos revividos;
## senão HP/AP como terminaram.
func fight_again(rest: bool = false) -> void:
	if rest:
		_rest_all(hero_states)
	start(hero_states, reserve_states)

## Restaura o estado do início da batalha perdida e recomeça; rest = true descansa depois do snapshot.
func retry(rest: bool = false) -> void:
	var heroes: Array[HeroState] = hero_states
	for i: int in heroes.size():
		heroes[i].restore(_snapshots[i])
	for i: int in reserve_states.size():
		reserve_states[i].restore(_reserve_snapshots[i])
	if rest:
		_rest_all(heroes)
	start(heroes, reserve_states)

func _rest_all(heroes: Array[HeroState]) -> void:
	for h: HeroState in heroes:
		h.rest(balance)

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
	if mode == Mode.MAP and phase == Phase.CONTINUE:
		await _demo_wait(1.0)
		_result.accept()

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
		_menu.cancel()  # volta à lista de habilidades (um nível)
		await _demo_wait(0.5)
		if line != null:
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

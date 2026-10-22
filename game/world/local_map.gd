class_name LocalMap
extends Node2D

## Área local: jogador, inimigos de mapa, saída e encontro com batalha no próprio mapa.
## Ao tocar um inimigo, a BattleScene (modo MAP) roda sobre o mapa nas posições da arena.
## Debug: `-- --demo-local` roda a cena sozinha com auto_battle e leva o jogador até o inimigo
## (verificação visual com --write-movie).

signal exit_requested
signal game_over
## O jogador pediu o menu do ponto de descanso (tecla interact dentro da área).
signal rest_requested
## Um objeto do mapa (NPC, placa...) pede um evento; quem hospeda o jogo (Game) o executa com o EventPlayer.
signal event_requested(event: EventScript)
## Um lojista pede a loja `shop` (M12); o Game abre o menu de loja.
signal shop_requested(shop: ShopDef)
## A pousada pede o descanso pago (M12); o Game abre o menu com o preço da pousada.
signal inn_requested
## O jogador entrou numa ligação de mapa (MapLink): o Game troca de mapa (M12).
signal link_requested(target_map: StringName, target_spawn: StringName)
## Fim da batalha iniciada por um evento (StartBattle) com vitória ou fuga; derrota vira `game_over`.
signal event_battle_finished(outcome: int)
## Um evento terminou (ou foi cancelado) e o mapa foi descongelado; usado, por exemplo, pelo lojista para abrir a loja depois da fala.
signal event_finished

const BATTLE_SCENE: PackedScene = preload("res://battle/battle_scene.tscn")
const MAP_RECT: Rect2 = Rect2(0, 0, 2400, 720)

## Batalha em andamento (null fora de batalha).
var battle: BattleScene
## Repassado à batalha (testes/demo).
var auto_battle: bool = false
## Repassado à batalha: inimigos enfraquecidos e telas roteirizadas (só debug, `--demo-m2`).
var demo_result: bool = false
## Semente do Dice da batalha; -1 = derivada de state.dice.
var dice_seed: int = -1
## Bloqueia encontros e saída (ex.: depois do Game Over, até o Game trocar de cena).
var locked: bool = false
## Um evento está em andamento: jogador e inimigos parados, sem saída, interação nem novos encontros.
var event_active: bool = false
## Quem executa os eventos diz se aceita um agora (Game: sem transição, menu nem Game Over); vazio = aceita.
var event_gate: Callable

var state: GameState
var _battle_enemy: MapEnemy
## Todos os inimigos de mapa na batalha atual (o tocado primeiro, depois o grupo).
var _battle_group: Array[MapEnemy] = []
## Membros do grupo perto o bastante que não couberam na arena (ficam no mapa; levam cooldown ao fim da batalha).
var _battle_left_out: Array[MapEnemy] = []
## Posição do jogador ao tocar o inimigo (para onde ele volta se fugir).
var _battle_from: Vector2 = Vector2.ZERO
## A batalha em andamento veio de um evento (StartBattle), não do toque de um inimigo.
var _scripted_battle: EncounterDef
## Um CameraTo soltou a câmera do jogador; ela volta a seguir ao fim do evento.
var _camera_detached: bool = false
## Quadro em que o último evento terminou (a tecla desse quadro não interage).
var _event_end_frame: int = -1

@onready var player: Player = $Player
@onready var camera: MapCamera = $MapCamera
@onready var exit_zone: Zone = get_node_or_null(^"Exit") as Zone
@onready var default_arena: BattleArena = $Arena
@onready var followers: PartyFollowers = get_node_or_null(^"Followers") as PartyFollowers
@onready var rest_point: RestPoint = get_node_or_null(^"RestPoint") as RestPoint

func _ready() -> void:
	if exit_zone != null:
		exit_zone.entered.connect(_on_exit_entered)
	for link: MapLink in map_links():
		link.activated.connect(_on_link_activated)
	if rest_point != null:
		rest_point.player = player
		rest_point.interacted.connect(_on_rest_interacted)
	for e: MapEnemy in enemies():
		e.touched.connect(_on_enemy_touched)
	for i: Interactable in interactables():
		_wire(i)
	if OS.get_cmdline_user_args().has("--demo-local") and get_parent() == get_tree().root:
		_run_demo.call_deferred()

## O LocalMap que contém `node` (null fora de um mapa).
static func map_of(node: Node) -> LocalMap:
	var n: Node = node
	while n != null:
		var m: LocalMap = n as LocalMap
		if m != null:
			return m
		n = n.get_parent()
	return null

## Estado do jogo do mapa que contém `node` (null enquanto o mapa não foi configurado).
static func state_of(node: Node) -> GameState:
	var m: LocalMap = map_of(node)
	return m.state if m != null else null

## Posiciona o jogador no marcador `spawn`, liga a câmera e configura os inimigos.
func setup(game_state: GameState, spawn: StringName) -> void:
	state = game_state
	player.cfg = state.cfg
	var marker: Node2D = get_node_or_null(NodePath(String(spawn))) as Node2D
	if marker == null:
		push_error("LocalMap: marcador '%s' não existe" % spawn)
	else:
		player.global_position = marker.global_position
	if followers != null:
		followers.setup(state, player)
	camera.follow = player
	camera.set_bounds(MAP_RECT)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	for e: MapEnemy in enemies():
		if e.encounter != null and state.is_defeated(e.encounter.unique_id):
			remove_child(e)
			e.free()
			continue
		e.player = player
		e.setup(state.cfg, state.dice)

## Marcador de spawn do ponto de descanso (ou da pousada, M12) se o jogador está dentro dele; vazio fora.
func rest_spawn() -> StringName:
	if rest_point != null and rest_point.player_inside:
		return rest_point.spawn_name
	for i: Interactable in interactables():
		var inn: Inn = i as Inn
		if inn != null and inn.player_inside:
			return inn.spawn_name
	return &""

## Pede ao Game a loja `shop`. False se o mapa está ocupado (batalha, evento, travado).
func request_shop(shop: ShopDef) -> bool:
	if shop == null or is_busy():
		return false
	shop_requested.emit(shop)
	return true

## Pede ao Game o descanso pago da pousada. False se o mapa está ocupado.
func request_inn() -> bool:
	if is_busy():
		return false
	inn_requested.emit()
	return true

func _on_rest_interacted() -> void:
	if is_busy():
		return
	rest_requested.emit()

## Adiciona um interagível ao mapa já ligado ao jogador e ao pedido de eventos (objetos criados em código/testes).
func add_interactable(i: Interactable) -> void:
	add_child(i)
	_wire(i)

func _wire(i: Interactable) -> void:
	i.player = player
	i.event_requested.connect(run_event)

func interactables() -> Array[Interactable]:
	var out: Array[Interactable] = []
	for child: Node in get_children():
		var i: Interactable = child as Interactable
		if i != null and not i.is_queued_for_deletion():
			out.append(i)
	return out

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and try_interact():
		get_viewport().set_input_as_handled()

## Mapa ocupado (batalha, mapa travado, evento em andamento) ou ainda sem estado: sem interação, loja, descanso nem avisos.
func is_busy() -> bool:
	return battle != null or locked or event_active or state == null

## Aciona o interagível ao alcance mais próximo do jogador. False se nenhum (ou mapa ocupado).
func try_interact() -> bool:
	if is_busy():
		return false
	if Engine.get_process_frames() <= _event_end_frame:
		return false
	var found: Array[Interactable] = []
	var positions: Array[Vector2] = []
	for i: Interactable in interactables():
		if i.can_interact():
			found.append(i)
			positions.append(i.global_position)
	var idx: int = InteractPicker.nearest(player.global_position, positions)
	return idx >= 0 and found[idx].interact()

## Pede ao Game que execute `event`. False se o mapa está ocupado (batalha, evento, travado).
func run_event(event: EventScript) -> bool:
	if event == null or is_busy():
		return false
	if event_gate.is_valid() and not bool(event_gate.call()):
		return false
	event_requested.emit(event)
	return true

## Congela/descongela o mapa para um evento (EventPlayer): jogador e inimigos parados, saída desarmada.
## Ao terminar, rearma tudo (a menos que haja batalha ou Game Over).
func set_event_frozen(on: bool) -> void:
	event_active = on
	if on:
		player.enabled = false
		for e: MapEnemy in enemies():
			e.frozen = true
		_arm_exits(false)
		return
	if _camera_detached:
		_camera_detached = false
		camera.resume_follow(state.cfg.camera_slide_time)
	_event_end_frame = Engine.get_process_frames()
	if battle == null and not locked:
		_resume_world()
	event_finished.emit()

## Desliza a câmera para `pos` durante um evento (volta ao jogador no fim).
func event_camera_to(pos: Vector2, time: float) -> void:
	_camera_detached = true
	camera.slide_to(pos, time)

## Jogador, inimigos e saída voltam a funcionar (fora de batalha); durante um evento seguem parados.
func _resume_world() -> void:
	player.enabled = not event_active
	for e: MapEnemy in enemies():
		e.frozen = event_active
	_arm_exits(not event_active)
	if not event_active:
		for e: MapEnemy in enemies():
			e.rearm()

## Liga/desliga a saída e as ligações de mapa (desligadas em batalha e evento).
func _arm_exits(armed: bool) -> void:
	if exit_zone != null:
		exit_zone.armed = armed
	for link: MapLink in map_links():
		link.armed = armed

## Ligações de mapa (MapLink) filhas diretas do mapa.
func map_links() -> Array[MapLink]:
	var out: Array[MapLink] = []
	for child: Node in get_children():
		var l: MapLink = child as MapLink
		if l != null:
			out.append(l)
	return out

func _on_link_activated(target_map: StringName, target_spawn: StringName) -> void:
	if battle != null or locked:
		return
	link_requested.emit(target_map, target_spawn)

func enemies() -> Array[MapEnemy]:
	var out: Array[MapEnemy] = []
	for child: Node in get_children():
		var e: MapEnemy = child as MapEnemy
		if e != null and not e.is_queued_for_deletion():
			out.append(e)
	return out

func _arena_for(enemy: MapEnemy) -> BattleArena:
	var a: BattleArena = enemy.arena()
	return a if a != null else default_arena

func _on_enemy_touched(enemy: MapEnemy) -> void:
	if is_busy():
		return
	if enemy.encounter == null:
		push_error("LocalMap: inimigo '%s' sem encontro" % enemy.name)
		return
	_battle_enemy = enemy
	var arena: BattleArena = _arena_for(enemy)
	var group: Array[MapEnemy] = group_for(enemy, arena)
	_battle_group = group
	_battle_left_out = []
	if enemy.group != &"":
		for e: MapEnemy in enemies():
			if e != enemy and not group.has(e) and e.group == enemy.group and not e.lurking and e.encounter != null 					and e.global_position.distance_to(enemy.global_position) <= state.cfg.group_join_dist:
				_battle_left_out.append(e)
	player.enabled = false
	for e: MapEnemy in enemies():
		e.frozen = true
	_arm_exits(false)
	camera.slide_to(arena.center(), state.cfg.camera_slide_time)
	var from_pos: Vector2 = player.global_position
	var kind: Initiative.Kind = Initiative.classify(enemy.global_position, enemy.facing, enemy.is_chasing(),
			from_pos, state.cfg.backstab_angle)
	_battle_from = from_pos
	var defs: Array[EnemyDef] = []
	var flee_ok: bool = true
	for g: MapEnemy in group:
		g.visible = false
		g.frozen = true
		defs.append_array(g.encounter.enemies)
		flee_ok = flee_ok and g.encounter.can_flee
	_begin_battle(arena, defs, flee_ok, from_pos, kind)

## Batalha iniciada por um evento (StartBattle): na arena padrão, sem inimigo de mapa. Ao fim com vitória ou
## fuga emite `event_battle_finished`; a derrota segue o caminho normal (`game_over`).
func start_event_battle(encounter: EncounterDef) -> void:
	if battle != null or locked or state == null or encounter == null:
		return
	_scripted_battle = encounter
	_battle_enemy = null
	_battle_group = []
	_battle_left_out = []
	player.enabled = false
	for e: MapEnemy in enemies():
		e.frozen = true
	_arm_exits(false)
	var from_pos: Vector2 = player.global_position
	_battle_from = from_pos
	camera.slide_to(default_arena.center(), state.cfg.camera_slide_time)
	var defs: Array[EnemyDef] = []
	defs.append_array(encounter.enemies)
	_begin_battle(default_arena, defs, encounter.can_flee, from_pos, Initiative.Kind.NORMAL)

func _begin_battle(arena: BattleArena, defs: Array[EnemyDef], flee_ok: bool, from_pos: Vector2, kind: Initiative.Kind) -> void:
	player.visible = false
	if followers != null:
		followers.hide_all()
	var max_enemies: int = arena.enemy_count()
	if max_enemies > 0 and defs.size() > max_enemies:
		defs.resize(max_enemies)
	battle = BATTLE_SCENE.instantiate() as BattleScene
	battle.balance = state.cfg
	battle.auto_battle = auto_battle
	battle.demo_result = demo_result
	battle.dice_seed = dice_seed if dice_seed >= 0 else state.dice.pick_index(1 << 30)
	battle.settings = state.settings
	battle.game_state = state
	battle.mode = BattleScene.Mode.MAP
	battle.can_flee = flee_ok
	battle.position = Vector2.ZERO
	battle.finished.connect(_on_battle_finished)
	add_child(battle)
	# Síncrono logo após add_child: o _auto_start adiado da cena só é pulado se ctrl já existir.
	battle.start_with(state.heroes, defs, arena.hero_positions().slice(0, state.heroes.size()), arena.enemy_positions(defs.size()),
			state.inventory, from_pos, kind, state.reserve, arena.support_position())

## Quem entra na batalha: o tocado e, se tem grupo, os do mesmo grupo a até group_join_dist dele,
## na ordem da cena, enquanto couberem inimigos nas posições da arena (os que não cabem ficam no mapa).
func group_for(enemy: MapEnemy, arena: BattleArena) -> Array[MapEnemy]:
	var out: Array[MapEnemy] = [enemy]
	if enemy.group == &"":
		return out
	var used: int = enemy.encounter.enemies.size()
	var cap: int = arena.enemy_count()
	for e: MapEnemy in enemies():
		if e == enemy or e.group != enemy.group or e.lurking or e.encounter == null:
			continue
		if cap > 0 and used >= cap:
			break
		if e.global_position.distance_to(enemy.global_position) > state.cfg.group_join_dist:
			continue
		out.append(e)
		used += e.encounter.enemies.size()
	return out

func _on_battle_finished(outcome: BattleController.Outcome) -> void:
	var arena: BattleArena = _arena_for(_battle_enemy) if is_instance_valid(_battle_enemy) else default_arena
	battle.queue_free()
	battle = null
	for e: MapEnemy in _battle_left_out:
		if is_instance_valid(e):
			e.begin_cooldown(state.cfg.flee_cooldown)
	_battle_left_out = []
	var scripted: EncounterDef = _scripted_battle
	_scripted_battle = null
	if outcome == BattleController.Outcome.FLED:
		_after_flee()
		if scripted != null:
			event_battle_finished.emit(int(outcome))
		return
	if outcome != BattleController.Outcome.VICTORY:
		locked = true
		game_over.emit()
		return
	for g: MapEnemy in _battle_group:
		if is_instance_valid(g):
			if g.encounter != null:
				state.mark_defeated(g.encounter.unique_id)
			g.queue_free()
	_battle_group = []
	_battle_enemy = null
	if scripted != null:
		state.mark_defeated(scripted.unique_id)
		player.global_position = _battle_from
	else:
		player.global_position = arena.hero_positions()[0]
	player.visible = true
	if followers != null:
		followers.restart()
	camera.resume_follow(state.cfg.camera_slide_time)
	# Toques ignorados durante a batalha desarmaram os outros inimigos; rearma por último
	# (se um deles ainda encosta no líder, o novo encontro começa agora, com o mapa já restaurado).
	# Durante um evento o mundo segue parado até o fim dele.
	_resume_world()
	if scripted != null:
		event_battle_finished.emit(int(outcome))

## Fuga: o jogador volta para onde estava; o inimigo fica no mapa, piscando e sem tocar por flee_cooldown.
func _after_flee() -> void:
	for g: MapEnemy in _battle_group:
		if is_instance_valid(g):
			g.visible = true
			g.begin_cooldown(state.cfg.flee_cooldown)
	_battle_group = []
	_battle_enemy = null
	player.global_position = _battle_from
	player.visible = true
	if followers != null:
		followers.restart()
	camera.resume_follow(state.cfg.camera_slide_time)
	_resume_world()

func _on_exit_entered(_zone_id: StringName) -> void:
	if battle != null or locked:
		return
	exit_requested.emit()

# --- Roteiro de debug (--demo-local) ------------------------------------------------

func _run_demo() -> void:
	var defs: Array[CharacterDef] = []
	for id: String in ["teste_a", "teste_b", "teste_c"]:
		defs.append(load("res://data/test/heroes/%s.tres" % id) as CharacterDef)
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	var cfg: BalanceConfig = load("res://data/test/balance.tres") as BalanceConfig
	auto_battle = true
	setup(GameState.new_game(cfg, defs, items, counts, Dice.new(7), &"local", &"Entry"), &"Entry")
	# Leva o jogador para perto do inimigo e encosta nele.
	var enemy: MapEnemy = enemies()[0]
	enemy.frozen = true
	player.global_position = enemy.global_position + Vector2(-120, 0)
	camera.global_position = player.global_position
	player.override_dir = Vector2.RIGHT
	while battle == null:
		await get_tree().physics_frame
	player.override_dir = Vector2.ZERO

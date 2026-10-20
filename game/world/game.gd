class_name Game
extends Node

## Jogo raiz: abre na tela de título, guarda o GameState, troca o mapa atual com fade e trata o Game Over
## (tela de Game Over e volta ao título). Salvar em disco: `save_to_slot` (mapa-múndi ou ponto de descanso). Reentrar numa área a instancia de novo (inimigos reaparecem).
## Menu de campo (`open_menu`, Tab/Esc): só abre fora de transição, de batalha e de Game Over; enquanto aberto
## o mapa atual fica congelado (process_mode DISABLED, o mesmo mecanismo do fade). Ao fechar, o marcador do
## jogador passa a mostrar o líder atual.
## Debug: `-- --demo-field-menu` (DemoFieldMenu) percorre as páginas do menu; `-- --demo-m2` (DemoM2) e
## `-- --demo-m3` (DemoM3) / `-- --demo-m4` (DemoM4) / `-- --demo-m6` (DemoM6, descanso e save) / `-- --demo-m7` (DemoM7, corrida, iniciativa, fuga e chefe) percorrem os ciclos dos marcos sozinhos (verificação com --write-movie).

## Saves das demos (`--demo-*`) vão para cá, nunca para os slots reais.
const DEMO_SAVE_DIR: String = "user://demo_saves/"

const MAPS: Dictionary[StringName, PackedScene] = {
	&"overworld": preload("res://world/overworld.tscn"),
	&"area_teste": preload("res://world/local_map.tscn"),
}

@export var balance: BalanceConfig
@export var party: Array[CharacterDef] = []
@export var start_items: Array[ItemDef] = []
@export var start_item_counts: Array[int] = []
## Mochila inicial de equipamento (o equipamento vestido vem de CharacterDef.starting_equipment).
@export var start_equipment: Array[EquipmentDef] = []
@export var start_equipment_counts: Array[int] = []
## Semente do Dice do jogo (-1 = aleatório).
@export var world_seed: int = -1

## Arquivo das configurações do jogador (testes apontam para um caminho temporário).
var settings_path: String = SettingsStore.DEFAULT_PATH
## Diretório dos slots de save (testes apontam para um diretório temporário, nunca os slots reais).
var save_dir: String = "user://"
## Pula a tela de título e começa em Novo jogo (testes; qualquer flag --demo-* também pula).
var skip_title: bool = false
var state: GameState
var settings: GameSettings
var registry: DefRegistry
var store: SaveStore
var current: Node2D
var current_map: StringName = &""
## Verdadeiro durante uma transição; sinais dos mapas são ignorados.
var busy: bool = false
## Verdadeiro na tela de título (sem estado de jogo ativo, o tempo de jogo não corre).
var in_title: bool = false
var title: TitleScreen
var rest_menu: RestMenu
var game_over_screen: GameOverScreen

static var _registry_cache: DefRegistry

@onready var fade: Fade = $Fade
@onready var menu: FieldMenu = $FieldMenu

func _ready() -> void:
	if _registry_cache == null:
		_registry_cache = SaveStore.build_registry()
	registry = _registry_cache
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if _has_demo_flag(args):
		save_dir = DEMO_SAVE_DIR
	store = SaveStore.new(save_dir, registry, balance)
	settings = GameSettings.new(balance)
	SettingsStore.load_into(settings, settings_path)
	apply_settings()
	menu.closed.connect(_on_menu_closed)
	menu.settings_changed.connect(_on_settings_changed)
	menu.store = store
	rest_menu = RestMenu.new()
	rest_menu.closed.connect(_on_rest_closed)
	add_child(rest_menu)
	menu.save_handler = save_to_slot
	if skip_title or _has_demo_flag(args):
		start_new_game()
	else:
		_show_title()
	if args.has("--demo-m2"):
		_add_demo(DemoM2.new(), "DemoM2")
	if args.has("--demo-m3"):
		_add_demo(DemoM3.new(), "DemoM3")
	if args.has("--demo-m4"):
		_add_demo(DemoM4.new(), "DemoM4")
	if args.has("--demo-m6"):
		_add_demo(DemoM6.new(), "DemoM6")
	if args.has("--demo-m7"):
		_add_demo(DemoM7.new(), "DemoM7")
	if args.has("--demo-field-menu"):
		_add_demo(DemoFieldMenu.new(), "DemoFieldMenu")

static func _has_demo_flag(args: PackedStringArray) -> bool:
	for a: String in args:
		if a.begins_with("--demo-"):
			return true
	return false

func _process(delta: float) -> void:
	if state != null and not in_title and game_over_screen == null:
		state.play_time += delta

## Começa um jogo novo no mapa-múndi (sai do título, se estiver nele).
func start_new_game() -> void:
	_close_title()
	state = GameState.new_game(balance, party, start_items, start_item_counts, Dice.new(world_seed),
			&"overworld", &"Start", GameState.MAX_ACTIVE, start_equipment, start_equipment_counts)
	state.settings = settings
	in_title = false
	go_to(&"overworld", &"Start", false)

## Continua do slot `slot` do disco. False se o slot não carregar.
func continue_from_slot(slot: int) -> bool:
	var loaded: GameState = store.read(slot, Dice.new(world_seed))
	if loaded == null or not MAPS.has(loaded.save_map):
		return false
	_close_title()
	loaded.settings = settings
	state = loaded
	in_title = false
	go_to(loaded.save_map, loaded.save_spawn, false)
	var world: Overworld = current as Overworld
	if world != null and loaded.has_save_pos():
		world.place_player(loaded.save_pos)
	return true

func _show_title() -> void:
	in_title = true
	title = TitleScreen.new()
	title.setup(store)
	title.new_game_requested.connect(start_new_game)
	title.continue_requested.connect(continue_from_slot)
	title.quit_requested.connect(func() -> void: get_tree().quit())
	add_child(title)

func _close_title() -> void:
	if title != null:
		title.queue_free()
		title = null

## Spawn gravado no save feito aqui: o mapa-múndi usa `Start`; numa área, o ponto de descanso (vazio fora dele).
func save_spawn_here() -> StringName:
	if current is Overworld:
		return &"Start"
	var local: LocalMap = current as LocalMap
	return local.rest_spawn() if local != null else &""

## Salvar em disco só vale no mapa-múndi ou dentro de um ponto de descanso.
func can_save() -> bool:
	return state != null and not in_title and not busy and save_spawn_here() != &""

## Descanso: cura todo o roster (reserva inclusa) e grava o ponto de descanso em memória.
func rest_here() -> void:
	state.rest_all()
	var spawn: StringName = save_spawn_here()
	if spawn != &"":
		state.save(current_map, spawn)

## Grava o ponto de salvamento atual (memória e disco) no slot. False se não puder salvar ou se a escrita falhar.
func save_to_slot(slot: int) -> bool:
	if not can_save():
		return false
	var pos: Vector2 = GameState.NO_POS
	var world: Overworld = current as Overworld
	if world != null:
		pos = world.player.global_position
	state.save(current_map, save_spawn_here(), pos)
	return store.write(slot, state)

## Aplica as configurações que não dependem de uma cena (volume do bus Master).
func apply_settings() -> void:
	var v: float = float(settings.volume) / float(maxi(1, balance.volume_max))
	AudioServer.set_bus_volume_db(0, linear_to_db(v) if v > 0.0 else -80.0)

func _on_settings_changed() -> void:
	apply_settings()
	SettingsStore.save(settings, settings_path)

func _add_demo(demo: Node, demo_name: String) -> void:
	demo.name = demo_name
	add_child(demo)

func _unhandled_input(event: InputEvent) -> void:
	# Com o menu aberto, o FieldMenu (filho, recebe antes) trata e consome open_menu como "voltar".
	if event.is_action_pressed("open_menu") and open_menu():
		get_viewport().set_input_as_handled()

## Verdadeiro se o menu de campo pode abrir agora: sem transição, menu fechado, sem batalha
## (o que inclui as telas de resultado) e mapa não travado (Game Over).
func can_open_menu() -> bool:
	if busy or menu.is_open or rest_menu.is_open or current == null:
		return false
	var local: LocalMap = current as LocalMap
	if local != null and (local.battle != null or local.locked):
		return false
	return true

## Abre o menu sobre o mapa atual, congelando-o. Devolve false se não puder abrir.
func open_menu() -> bool:
	if not can_open_menu():
		return false
	current.process_mode = Node.PROCESS_MODE_DISABLED
	menu.save_allowed = can_save()
	menu.open(state)
	return true

func _on_menu_closed() -> void:
	if current != null and not busy:
		current.process_mode = Node.PROCESS_MODE_INHERIT
	_refresh_leader()

## Mostra o líder atual no marcador do jogador do mapa.
func _refresh_leader() -> void:
	var player: Player = current.get_node_or_null(^"Player") as Player if current != null else null
	if player != null:
		player.set_leader(state.leader())

## Troca o mapa atual por `map`, com o jogador no marcador `spawn`.
## Os dois mapas ficam congelados durante a transição (sem física, sem sinais de Area2D):
## nada toca o jogador num mapa que vai ser liberado, e nenhuma zona dispara antes do fim do fade.
func go_to(map: StringName, spawn: StringName, with_fade: bool = true) -> void:
	if busy:
		return
	if not MAPS.has(map):
		push_error("Game: mapa desconhecido '%s'" % map)
		return
	busy = true
	if current != null:
		_freeze_outgoing(current)
	if with_fade:
		await fade.fade_out(state.cfg.fade_time)
	if current != null:
		remove_child(current)
		current.queue_free()
		current = null
	current = MAPS[map].instantiate() as Node2D
	current_map = map
	current.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(current)
	move_child(current, 0)
	_connect_and_setup(current, spawn)
	_refresh_leader()
	if with_fade:
		await fade.fade_in(state.cfg.fade_time)
	current.process_mode = Node.PROCESS_MODE_INHERIT
	busy = false

## Congela o mapa que sai. Adiado: go_to costuma vir de um callback de física (zona),
## onde desligar CollisionObjects não é permitido. Até lá, LocalMap.locked já barra encontros e saída.
func _freeze_outgoing(node: Node2D) -> void:
	var local: LocalMap = node as LocalMap
	if local != null:
		local.locked = true
	node.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)

func _connect_and_setup(node: Node2D, spawn: StringName) -> void:
	var world: Overworld = node as Overworld
	if world != null:
		world.location_entered.connect(_on_location_entered)
		world.setup(state, spawn)
		return
	var local: LocalMap = node as LocalMap
	if local != null:
		local.exit_requested.connect(_on_exit_requested)
		local.game_over.connect(_on_game_over)
		local.rest_requested.connect(_on_rest_requested)
		local.setup(state, spawn)
		return
	push_error("Game: cena de mapa sem tipo conhecido '%s'" % node.name)

func _on_location_entered(zone_id: StringName) -> void:
	if busy:
		return
	if not MAPS.has(zone_id):
		push_error("Game: local desconhecido '%s'" % zone_id)
		return
	go_to(zone_id, &"Entry")

func _on_rest_requested() -> void:
	if busy or in_title or menu.is_open or rest_menu.is_open or game_over_screen != null:
		return
	current.process_mode = Node.PROCESS_MODE_DISABLED
	rest_menu.open(self)

func _on_rest_closed() -> void:
	if current != null and not busy:
		current.process_mode = Node.PROCESS_MODE_INHERIT
	_refresh_leader()

func _on_exit_requested() -> void:
	if busy:
		return
	go_to(&"overworld", &"AreaTesteReturn")

func _on_game_over() -> void:
	if busy or in_title or game_over_screen != null:
		return
	state.restore_save()
	game_over_screen = GameOverScreen.new()
	game_over_screen.dismissed.connect(_on_game_over_dismissed)
	add_child(game_over_screen)

## Do Game Over de volta ao título: o progresso desde o último save em disco se perde.
func _on_game_over_dismissed() -> void:
	game_over_screen.queue_free()
	game_over_screen = null
	if current != null:
		remove_child(current)
		current.queue_free()
		current = null
	_show_title()

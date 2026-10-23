class_name Game
extends Node

## Jogo raiz: abre na tela de título, guarda o GameState, troca o mapa atual com fade e trata o Game Over
## (tela de Game Over e volta ao título). Salvar em disco: `save_to_slot` (mapa-múndi ou ponto de descanso). Reentrar numa área a instancia de novo (inimigos reaparecem).
## Menu de campo (`open_menu`, Tab/Esc): só abre fora de transição, de batalha e de Game Over; enquanto aberto
## o mapa atual fica congelado (process_mode DISABLED, o mesmo mecanismo do fade). Ao fechar, o marcador do
## jogador passa a mostrar o líder atual.
## Eventos (M10): `play_event(script)` roda um roteiro no mapa atual com o EventPlayer; enquanto dura, o mapa fica
## parado e o menu de campo não abre. Troca de mapa e Game Over cancelam o evento.
## Debug: `-- --demo-fatia` (DemoFatia, M12) percorre a fatia vertical inteira no perfil da fatia (precisa de game_fatia.tscn,
## a cena principal); `-- --demo-field-menu` (DemoFieldMenu) percorre as páginas do menu; `-- --demo-m2` (DemoM2) e
## `-- --demo-m3` (DemoM3) / `-- --demo-m4` (DemoM4) / `-- --demo-m6` (DemoM6, descanso e save) / `-- --demo-m7` (DemoM7, corrida, iniciativa, fuga e chefe) / `-- --demo-m8` (DemoM8, Limite e Suporte) / `-- --demo-m11` (DemoM11, chefe de teste da dungeon) percorrem os ciclos dos marcos sozinhos (verificação com --write-movie).

## Perfil de início (M12): `start_profile` é o do Novo jogo (a fatia vertical em game_fatia.tscn); as demos (`--demo-*`)
## e os testes usam `test_profile` (data/test/start_teste.tres, o equivalente ao jogo de teste do M1-M11).
## Tela de fim (M12): um EndDemoStep abre o EndScreen; antes disso a flag `fatia_concluida` é gravada no save já existente do
## último slot usado (`last_slot`; 0 ou slot vazio = nada é gravado), sem mexer no resto: Continuar volta ao ponto de antes do chefe. Enter volta ao título.

## Saves das demos (`--demo-*`) e dos flags de desenvolvimento (`--start-map`, `--battle`) vão para cá, nunca para os slots reais.
const DEMO_SAVE_DIR: String = "user://demo_saves/"

## Flags de desenvolvimento (M16; só para testar daqui, o painel do editor os usa). Rodam no perfil da fatia, sem título,
## e gravam em DEMO_SAVE_DIR:
## `--start-map=<mapa> [--spawn=<marcador>]` abre o jogo direto nesse mapa (sem --spawn: o do perfil, ou `Entry`/`Start`);
## `--battle=<encontro> [--level=N]` leva o grupo ao nível N (padrão DEV_BATTLE_LEVEL) e começa o encontro na arena do mapa
## inicial (ou do --start-map); ao fim, o jogo segue no mapa. Mapa, marcador ou encontro desconhecido: erro e volta ao título.
## Ignorados junto de qualquer `--demo-*`.
const FLAG_START_MAP: String = "--start-map="
const FLAG_SPAWN: String = "--spawn="
const FLAG_BATTLE: String = "--battle="
const FLAG_LEVEL: String = "--level="
## Nível médio da fatia, usado por `--battle` sem `--level`.
const DEV_BATTLE_LEVEL: int = 5

## Única demo que NÃO usa o perfil de teste: percorre a fatia, do título ao fim (usa o `start_profile` e o título).
const FATIA_DEMO_FLAG: String = "--demo-fatia"

## Flag gravada no "clear save" ao chegar à tela de fim.
const FLAG_CONCLUDED: StringName = &"fatia_concluida"

const MAPS: Dictionary[StringName, PackedScene] = {
	&"overworld": preload("res://world/overworld.tscn"),
	&"area_teste": preload("res://world/local_map.tscn"),
	&"dungeon_teste": preload("res://world/dungeon_teste.tscn"),
	# Fatia vertical (M12). Saem do mapa por MapLink (sem $Exit), então não há entradas em EXIT_SPAWNS.
	&"cidade": preload("res://world/fatia/cidade.tscn"),
	&"casa_1": preload("res://world/fatia/casa_1.tscn"),
	&"casa_2": preload("res://world/fatia/casa_2.tscn"),
	&"overworld_fatia": preload("res://world/fatia/overworld_fatia.tscn"),
	&"estrada": preload("res://world/fatia/estrada.tscn"),
	&"dungeon_1": preload("res://world/fatia/dungeon_1.tscn"),
	&"dungeon_2": preload("res://world/fatia/dungeon_2.tscn"),
}

## Marcador do mapa-múndi onde o jogador reaparece ao sair de cada área.
const EXIT_SPAWNS: Dictionary[StringName, StringName] = {&"area_teste": &"AreaTesteReturn", &"dungeon_teste": &"DungeonReturn"}

@export var balance: BalanceConfig
## Perfil do Novo jogo (grupo, itens, moeda, mapa e spawn iniciais).
@export var start_profile: StartProfile
## Perfil das demos e dos testes (equivale ao jogo de teste de antes da fatia).
@export var test_profile: StartProfile
## Semente do Dice do jogo (-1 = aleatório).
@export var world_seed: int = -1

## Argumentos do usuário da linha de comando (depois de `--`); os testes trocam antes de entrar na árvore.
var user_args: PackedStringArray = OS.get_cmdline_user_args()
## Arquivo das configurações do jogador (testes apontam para um caminho temporário).
var settings_path: String = SettingsStore.DEFAULT_PATH
## Diretório dos slots de save (testes apontam para um diretório temporário, nunca os slots reais).
var save_dir: String = "user://"
## Pula a tela de título e começa em Novo jogo (testes; qualquer flag --demo-* também pula).
var skip_title: bool = false
## Usar `test_profile` no Novo jogo (ligado por qualquer flag --demo-*, exceto --demo-fatia).
var use_test_profile: bool = false
## Mapas conhecidos (cópia de MAPS; testes podem acrescentar mapas).
var maps: Dictionary[StringName, PackedScene] = MAPS.duplicate()
## Último slot de save usado (salvar ou continuar); 0 = nenhum.
var last_slot: int = 0
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
## Menu da loja (M12), aberto pelos lojistas do mapa.
var shop_menu: ShopMenu
## Escolha do herói que desfaz um obstáculo elemental (M15), aberta pelos ElementalObstacle do mapa.
var obstacle_menu: ObstacleMenu
## Executa os eventos roteirizados do mapa atual (M10); a caixa de diálogo é filha dele.
var event_player: EventPlayer
var game_over_screen: GameOverScreen
## Tela de fim da demo (null fora dela).
var end_screen: EndScreen

static var _registry_cache: DefRegistry

@onready var fade: Fade = $Fade
@onready var menu: FieldMenu = $FieldMenu

func _ready() -> void:
	if _registry_cache == null:
		_registry_cache = SaveStore.build_registry()
	registry = _registry_cache
	var args: PackedStringArray = user_args
	use_test_profile = uses_test_profile(args)
	var dev: Dictionary = {} if is_demo(args) else parse_dev_flags(args)
	if is_demo(args) or not dev.is_empty():
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
	shop_menu = ShopMenu.new()
	shop_menu.closed.connect(_on_shop_closed)
	add_child(shop_menu)
	obstacle_menu = ObstacleMenu.new()
	obstacle_menu.closed.connect(_on_obstacle_closed)
	add_child(obstacle_menu)
	menu.save_handler = save_to_slot
	event_player = EventPlayer.new()
	event_player.end_demo_requested.connect(_on_end_demo_requested)
	add_child(event_player)
	if not dev.is_empty():
		if not _start_dev(dev):
			_show_title()
	elif skip_title or use_test_profile:
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
	if args.has("--demo-m8"):
		_add_demo(DemoM8.new(), "DemoM8")
	if args.has("--demo-m10"):
		_add_demo(DemoM10.new(), "DemoM10")
	if args.has("--demo-m11"):
		_add_demo(DemoM11.new(), "DemoM11")
	if args.has("--demo-field-menu"):
		_add_demo(DemoFieldMenu.new(), "DemoFieldMenu")
	if args.has(FATIA_DEMO_FLAG):
		_add_demo(DemoFatia.new(), "DemoFatia")

## As demos (qualquer flag --demo-*, menos --demo-fatia) rodam no perfil de teste.
static func uses_test_profile(args: PackedStringArray) -> bool:
	return is_demo(args) and not args.has(FATIA_DEMO_FLAG)

## Qualquer flag --demo-* (as demos gravam em DEMO_SAVE_DIR).
static func is_demo(args: PackedStringArray) -> bool:
	for a: String in args:
		if a.begins_with("--demo-"):
			return true
	return false

## Flags de desenvolvimento dos argumentos: {start_map, spawn, battle: StringName, level: String}, só as chaves presentes.
## Vazio se não há `--start-map` nem `--battle` (sozinhos, `--spawn` e `--level` não fazem nada).
static func parse_dev_flags(args: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for a: String in args:
		if a.begins_with(FLAG_START_MAP):
			out["start_map"] = StringName(a.trim_prefix(FLAG_START_MAP))
		elif a.begins_with(FLAG_SPAWN):
			out["spawn"] = StringName(a.trim_prefix(FLAG_SPAWN))
		elif a.begins_with(FLAG_BATTLE):
			out["battle"] = StringName(a.trim_prefix(FLAG_BATTLE))
		elif a.begins_with(FLAG_LEVEL):
			out["level"] = a.trim_prefix(FLAG_LEVEL)
	if not (out.has("start_map") or out.has("battle")):
		return {}
	return out

## Novo jogo no perfil da fatia pelos flags de desenvolvimento. False (com erro no log) se algo não existe;
## nesse caso nada foi iniciado e o chamador cai no título.
func _start_dev(dev: Dictionary) -> bool:
	var p: StartProfile = start_profile
	if p == null:
		push_error("Game: flags de desenvolvimento precisam do perfil da fatia")
		return false
	var map: StringName = dev.get("start_map", p.map)
	if not maps.has(map):
		push_error("Game: --start-map: mapa desconhecido '%s' (mapas: %s)" % [map, ", ".join(maps.keys())])
		return false
	var probe: Node = maps[map].instantiate()
	var spawn: StringName = _dev_spawn(dev, p, map, probe)
	var is_local: bool = probe is LocalMap
	probe.free()
	if spawn == &"":
		return false
	var encounter: EncounterDef = null
	var level: int = DEV_BATTLE_LEVEL
	if dev.has("battle"):
		encounter = SaveStore.find_encounter(dev["battle"])
		if encounter == null:
			push_error("Game: --battle: encontro desconhecido '%s'" % dev["battle"])
			return false
		if not is_local:
			push_error("Game: --battle: o mapa '%s' não tem arena (use um mapa local)" % map)
			return false
		if dev.has("level"):
			var text: String = dev["level"]
			if not text.is_valid_int() or text.to_int() < 1:
				push_error("Game: --level: nível inválido '%s'" % text)
				return false
			level = text.to_int()
	start_new_game(map, spawn)
	if encounter != null:
		state.set_party_level(level)
		(current as LocalMap).start_event_battle(encounter)
	return true

## Marcador de entrada do `--start-map`: o de `--spawn`; sem ele, o do perfil (se o mapa é o dele) ou `Entry` / `Start`.
## Vazio (com erro no log) se o marcador não existe em `probe`.
func _dev_spawn(dev: Dictionary, p: StartProfile, map: StringName, probe: Node) -> StringName:
	var candidates: Array[StringName] = []
	if dev.has("spawn"):
		candidates.append(dev["spawn"])
	elif map == p.map:
		candidates.append(p.spawn)
	else:
		candidates.append_array([&"Entry", &"Start"] as Array[StringName])
	for c: StringName in candidates:
		if probe.get_node_or_null(NodePath(String(c))) is Marker2D:
			return c
	var names: PackedStringArray = []
	for m: Node in probe.find_children("*", "Marker2D", true, false):
		names.append(String(probe.get_path_to(m)))
	push_error("Game: marcador '%s' não existe em '%s' (marcadores: %s)" % [candidates[0], map, ", ".join(names)])
	return &""

func _process(delta: float) -> void:
	if state != null and not in_title and game_over_screen == null and end_screen == null:
		state.play_time += delta

## Perfil do Novo jogo: o de teste nas demos e nos testes, senão `start_profile`.
func active_profile() -> StartProfile:
	return test_profile if use_test_profile or start_profile == null else start_profile

## Começa um jogo novo no local do perfil de início (sai do título, se estiver nele).
## `map` e `spawn` (flags de desenvolvimento) trocam o local; vazio = o do perfil.
func start_new_game(map: StringName = &"", spawn: StringName = &"") -> void:
	var p: StartProfile = active_profile()
	if p == null:
		push_error("Game: sem perfil de início")
		return
	_close_title()
	var start_map: StringName = map if map != &"" else p.map
	var start_spawn: StringName = spawn if map != &"" else p.spawn
	state = GameState.new_game(balance, p.party, p.items, p.item_counts, Dice.new(world_seed),
			start_map, start_spawn, GameState.MAX_ACTIVE, p.equipment, p.equipment_counts, p.money)
	state.settings = settings
	in_title = false
	last_slot = 0
	go_to(start_map, start_spawn, false)

## Continua do slot `slot` do disco. False se o slot não carregar.
func continue_from_slot(slot: int) -> bool:
	var loaded: GameState = store.read(slot, Dice.new(world_seed))
	if loaded == null or not maps.has(loaded.save_map):
		return false
	_close_title()
	loaded.settings = settings
	state = loaded
	in_title = false
	last_slot = slot
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
	var ok: bool = store.write(slot, state)
	if ok:
		last_slot = slot
	return ok

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
	if busy or menu.is_open or rest_menu.is_open or shop_menu.is_open or obstacle_menu.is_open or current == null or event_player.active or end_screen != null:
		return false
	var local: LocalMap = current as LocalMap
	if local != null and (local.battle != null or local.locked or local.event_active):
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
	if not maps.has(map):
		push_error("Game: mapa desconhecido '%s'" % map)
		return
	busy = true
	if current != null:
		_freeze_outgoing(current)
	# Um evento em andamento pertence ao mapa que sai (o mapa já está travado: nada é religado).
	event_player.cancel()
	if with_fade:
		await fade.fade_out(state.cfg.fade_time)
	if current != null:
		remove_child(current)
		current.queue_free()
		current = null
	current = maps[map].instantiate() as Node2D
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
		local.link_requested.connect(_on_link_requested)
		local.game_over.connect(_on_game_over)
		local.rest_requested.connect(_on_rest_requested)
		local.shop_requested.connect(_on_shop_requested)
		local.inn_requested.connect(_on_inn_requested)
		local.obstacle_requested.connect(_on_obstacle_requested)
		local.event_requested.connect(play_event)
		local.event_gate = can_play_event
		local.setup(state, spawn)
		return
	push_error("Game: cena de mapa sem tipo conhecido '%s'" % node.name)

func _on_location_entered(zone_id: StringName, spawn: StringName) -> void:
	if busy:
		return
	if not maps.has(zone_id):
		push_error("Game: local desconhecido '%s'" % zone_id)
		return
	go_to(zone_id, spawn)

## O Game aceita um evento agora? (mapa local, sem transição, título, menu, Game Over nem outro evento)
func can_play_event() -> bool:
	return current is LocalMap and not (busy or in_title or menu.is_open or rest_menu.is_open or shop_menu.is_open or obstacle_menu.is_open or game_over_screen != null or end_screen != null or event_player.active)

## Executa `event` no mapa atual (pedido por NPCs, placas e demais objetos). Ignorado se já houver evento,
## transição, menu ou Game Over.
func play_event(event: EventScript) -> void:
	if not can_play_event():
		return
	var local: LocalMap = current as LocalMap
	await event_player.play(event, local, state)

func _on_rest_requested() -> void:
	if not _can_open_overlay():
		return
	current.process_mode = Node.PROCESS_MODE_DISABLED
	rest_menu.open(self)

## Pousada (M12): o mesmo menu do descanso, cobrando BalanceConfig.inn_price.
func _on_inn_requested() -> void:
	if not _can_open_overlay():
		return
	current.process_mode = Node.PROCESS_MODE_DISABLED
	rest_menu.open(self, state.cfg.inn_price)

func _on_shop_requested(shop: ShopDef) -> void:
	if not _can_open_overlay():
		return
	current.process_mode = Node.PROCESS_MODE_DISABLED
	shop_menu.open(self, shop)

func _on_obstacle_requested(o: ElementalObstacle) -> void:
	if not _can_open_overlay():
		return
	current.process_mode = Node.PROCESS_MODE_DISABLED
	obstacle_menu.open(o)

func _on_obstacle_closed() -> void:
	if current != null and not busy:
		current.process_mode = Node.PROCESS_MODE_INHERIT
	_refresh_leader()

func _on_shop_closed() -> void:
	if current != null and not busy:
		current.process_mode = Node.PROCESS_MODE_INHERIT
	_refresh_leader()

## Os menus sobre o mapa (descanso, pousada, loja) só abrem fora de transição, título, outro menu, Game Over e evento.
func _can_open_overlay() -> bool:
	return not (busy or in_title or menu.is_open or rest_menu.is_open or shop_menu.is_open or obstacle_menu.is_open or game_over_screen != null or end_screen != null or event_player.active)

func _on_rest_closed() -> void:
	if current != null and not busy:
		current.process_mode = Node.PROCESS_MODE_INHERIT
	_refresh_leader()

func _on_exit_requested() -> void:
	if busy:
		return
	go_to(&"overworld", EXIT_SPAWNS.get(current_map, &"Start"))

## Uma ligação de mapa (MapLink) do mapa atual foi pisada.
func _on_link_requested(target_map: StringName, target_spawn: StringName) -> void:
	if busy or end_screen != null:
		return
	go_to(target_map, target_spawn)

## EndDemoStep: grava o "clear save" e mostra a tela de fim (uma só; o mapa fica parado sob ela).
func _on_end_demo_requested() -> void:
	if end_screen != null or in_title or state == null:
		return
	# Clear save: só a flag entra no que já estava gravado (o ponto de antes do chefe, com o chefe vivo); o estado vivo não é gravado.
	if last_slot > 0 and store.has_slot(last_slot):
		if not store.set_flag(last_slot, FLAG_CONCLUDED, 1):
			push_error("Game: falha ao gravar o clear save no slot %d" % last_slot)
	if current != null:
		current.process_mode = Node.PROCESS_MODE_DISABLED
	end_screen = EndScreen.new()
	end_screen.setup(state.play_time, state.party_avg_level())
	end_screen.dismissed.connect(_on_end_dismissed)
	add_child(end_screen)

## Da tela de fim de volta ao título.
func _on_end_dismissed() -> void:
	end_screen.queue_free()
	end_screen = null
	event_player.cancel()
	if current != null:
		remove_child(current)
		current.queue_free()
		current = null
	_show_title()

func _on_game_over() -> void:
	if busy or in_title or game_over_screen != null or end_screen != null:
		return
	event_player.cancel()
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

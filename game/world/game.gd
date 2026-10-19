class_name Game
extends Node

## Jogo raiz: guarda o GameState, troca o mapa atual com fade e trata o Game Over
## (volta ao ponto de salvamento). Reentrar numa área a instancia de novo (inimigos reaparecem).
## Menu de campo (`open_menu`, Tab/Esc): só abre fora de transição, de batalha e de Game Over; enquanto aberto
## o mapa atual fica congelado (process_mode DISABLED, o mesmo mecanismo do fade). Ao fechar, o marcador do
## jogador passa a mostrar o líder atual.
## Debug: `-- --demo-field-menu` (DemoFieldMenu) percorre as páginas do menu; `-- --demo-m2` (DemoM2) e
## `-- --demo-m3` (DemoM3) / `-- --demo-m4` (DemoM4) percorrem os ciclos dos marcos sozinhos (verificação com --write-movie).

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

var state: GameState
var current: Node2D
## Verdadeiro durante uma transição; sinais dos mapas são ignorados.
var busy: bool = false

@onready var fade: Fade = $Fade
@onready var menu: FieldMenu = $FieldMenu

func _ready() -> void:
	state = GameState.new_game(balance, party, start_items, start_item_counts, Dice.new(world_seed),
			&"overworld", &"Start", GameState.MAX_ACTIVE, start_equipment, start_equipment_counts)
	menu.closed.connect(_on_menu_closed)
	go_to(&"overworld", &"Start", false)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--demo-m2"):
		_add_demo(DemoM2.new(), "DemoM2")
	if args.has("--demo-m3"):
		_add_demo(DemoM3.new(), "DemoM3")
	if args.has("--demo-m4"):
		_add_demo(DemoM4.new(), "DemoM4")
	if args.has("--demo-field-menu"):
		_add_demo(DemoFieldMenu.new(), "DemoFieldMenu")

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
	if busy or menu.is_open or current == null:
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

func _on_exit_requested() -> void:
	if busy:
		return
	go_to(&"overworld", &"AreaTesteReturn")

func _on_game_over() -> void:
	if busy:
		return
	state.restore_save()
	go_to(state.save_map, state.save_spawn)

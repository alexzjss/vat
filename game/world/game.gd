class_name Game
extends Node

## Jogo raiz: guarda o GameState, troca o mapa atual com fade e trata o Game Over
## (volta ao ponto de salvamento). Reentrar numa área a instancia de novo (inimigos reaparecem).
## Debug: `-- --demo-field-menu` abre o menu de campo (um caído, pontos pendentes) e percorre as páginas.
## Debug: `-- --demo-m2` adiciona o DemoM2, que percorre o ciclo do M2 sozinho (verificação com --write-movie).

const MAPS: Dictionary[StringName, PackedScene] = {
	&"overworld": preload("res://world/overworld.tscn"),
	&"area_teste": preload("res://world/local_map.tscn"),
}

@export var balance: BalanceConfig
@export var party: Array[CharacterDef] = []
@export var start_items: Array[ItemDef] = []
@export var start_item_counts: Array[int] = []
## Semente do Dice do jogo (-1 = aleatório).
@export var world_seed: int = -1

var state: GameState
var current: Node2D
## Verdadeiro durante uma transição; sinais dos mapas são ignorados.
var busy: bool = false

@onready var fade: Fade = $Fade

func _ready() -> void:
	state = GameState.new_game(balance, party, start_items, start_item_counts, Dice.new(world_seed),
			&"overworld", &"Start")
	go_to(&"overworld", &"Start", false)
	if OS.get_cmdline_user_args().has("--demo-m2"):
		var demo := DemoM2.new()
		demo.name = "DemoM2"
		add_child(demo)
	if OS.get_cmdline_user_args().has("--demo-field-menu"):
		_demo_field_menu()

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

## Só debug (`--demo-field-menu`): abre o FieldMenu sobre o mapa para verificação com --write-movie.
func _demo_field_menu() -> void:
	state.heroes[1].hp = 0
	state.heroes[2].pending_points = 2
	state.reserve[0].hp = maxi(1, state.reserve[0].hp / 2)
	var menu: FieldMenu = (load("res://ui/field_menu/field_menu.tscn") as PackedScene).instantiate() as FieldMenu
	add_child(menu)
	menu.open(state)
	# Roteiro (1,5 s por tela): raiz → Itens com alvo → Status → Formação com um herói escolhido.
	await get_tree().create_timer(1.5, true).timeout
	menu.cursor = 0
	menu.accept()
	menu.item_page.accept()
	await get_tree().create_timer(1.5, true).timeout
	menu.cancel()
	menu.cancel()
	menu.cursor = 2
	menu.accept()
	menu.status_page.move(2)
	menu.status_page.accept()
	await get_tree().create_timer(1.5, true).timeout
	menu.cancel()
	menu.cancel()
	menu.cursor = 4
	menu.accept()
	menu.formation_page.accept()
	menu.formation_page.move(4)

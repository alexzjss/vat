class_name DemoM4
extends Node

## Roteiro de debug (`-- --demo-m4`): percorre o M4 sozinho, para verificação visual com --write-movie.
## Abre o menu de campo, em Equipar escolhe o Teste A, equipa a Armadura Pesada (mostrando a prévia)
## e o Amuleto Anti-Sono, abre o Status dele e fecha; depois entrega o resto ao DemoM2 (entra na área,
## batalha com inimigos enfraquecidos, vence, volta ao mapa-múndi e termina).

## Tempo de cada tela do menu.
const SCREEN_TIME: float = 1.2

var game: Game

func _ready() -> void:
	game = get_parent() as Game
	if game == null:
		push_error("DemoM4: precisa ser filho do Game")
		queue_free()
		return
	_run.call_deferred()

func _wait() -> void:
	await get_tree().create_timer(SCREEN_TIME, true).timeout

func _run() -> void:
	var state: GameState = game.state
	await _wait()
	while not game.open_menu():
		await get_tree().process_frame
	var menu: FieldMenu = game.menu
	print("DemoM4: menu aberto")
	# Equipar → Teste A (primeiro do grupo) → espaços.
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"equip")
	menu.accept()
	var page: EquipPage = menu.equip_page
	page.accept()
	var hero: HeroState = page.hero
	await _wait()
	await _equip(page, hero, &"armor", &"armadura_pesada")
	await _equip(page, hero, &"accessory", &"amuleto_sono")
	menu.cancel()
	menu.cancel()
	# Status do Teste A.
	menu.cursor = FieldMenu.COMMAND_PAGES.find(&"status")
	menu.accept()
	menu.status_page.accept()
	await _wait()
	await _wait()
	menu.cancel()
	menu.cancel()
	menu.cancel()
	assert(not menu.is_open, "DemoM4: menu devia fechar")
	print("DemoM4: menu fechado; %s = %s" % [hero.def.display_name, ", ".join(EquipmentRules.SLOTS.map(
			func(s: StringName) -> String: return EquipPage.slot_line(hero, s)))])
	var walk := DemoM2.new()
	walk.name = "DemoM2"
	game.add_child(walk)
	queue_free()

## Abre o espaço `slot`, leva o cursor até o item `id` (a prévia acompanha), espera e confirma.
func _equip(page: EquipPage, hero: HeroState, slot: StringName, id: StringName) -> void:
	page.cursor = EquipmentRules.SLOTS.find(slot)
	page.accept()
	var idx: int = 0
	for e: EquipmentDef in game.state.bag.listing():
		if EquipmentRules.can_equip(hero.def, e, slot):
			if e.id == id:
				break
			idx += 1
	page.move(idx)
	print("DemoM4: prévia %s" % " | ".join(page.preview_lines()))
	await _wait()
	await _wait()
	page.accept()
	print("DemoM4: %s" % page.message())
	await _wait()

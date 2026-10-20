class_name DemoM8
extends Node

## Roteiro de debug (`-- --demo-m8`): percorre o M8/M8.5 sozinho, para verificacao visual com --write-movie.
## Na area de teste toca o inimigo; o Teste A leva dano ate encher a barra de Limite, usa "Limite", enche de novo
## e chama o Suporte (Teste E, da reserva) com a habilidade dele.

const ARRIVE_TIME: float = 1.0
## Limite de quadros de cada espera (evita travar o roteiro).
const MAX_FRAMES: int = 3600

var game: Game

func _ready() -> void:
	game = get_parent() as Game
	if game == null:
		push_error("DemoM8: precisa ser filho do Game")
		queue_free()
		return
	_run.call_deferred()

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout

func _log(text: String) -> void:
	print("DemoM8 [quadro %d]: %s" % [Engine.get_process_frames(), text])

func _run() -> void:
	await _wait(0.5)
	game.go_to(&"area_teste", &"Entry")
	while game.busy or not game.current is LocalMap:
		await get_tree().process_frame
	var map: LocalMap = game.current as LocalMap
	var enemy: MapEnemy = map.get_node("Enemy") as MapEnemy
	enemy.frozen = true
	map.player.global_position = enemy.global_position + Vector2(-120, 0)
	map.camera.global_position = map.player.global_position
	map.player.override_dir = Vector2.RIGHT
	var guard: int = 0
	while map.battle == null and guard < MAX_FRAMES:
		guard += 1
		await get_tree().physics_frame
	map.player.override_dir = Vector2.ZERO
	var battle: BattleScene = map.battle
	if battle == null:
		_log("FALHA: a batalha nao comecou")
		return
	var menu: CommandMenu = battle.get_node("UI/CommandMenu") as CommandMenu
	var ctrl: BattleController = battle.ctrl
	var hero: Combatant = ctrl.b.heroes[0]
	# Inimigo duradouro: o roteiro termina por conta propria, nao pela vitoria.
	ctrl.b.enemies[0].hp = 99999
	for h: Combatant in ctrl.b.heroes:
		h.hp = 9999
	await _wait(1.5)
	_log("%s leva dano ate encher o Limite" % hero.display_name)
	await _hurt_until(ctrl, hero, 1.0)
	_log("Limite cheio: %.2f" % hero.limit)
	await _until_turn(ctrl, menu, hero)
	_pick(menu, "Limite")
	await _wait(1.0)
	menu.accept()
	_log("golpe de Limite usado")
	while ctrl.executing != null:
		await get_tree().process_frame
	await _wait(0.5)
	_log("%s leva dano de novo (Limite %.2f)" % [hero.display_name, hero.limit])
	await _hurt_until(ctrl, hero, 0.5)
	await _until_turn(ctrl, menu, hero)
	_pick(menu, "Suporte")
	await _wait(0.8)
	menu.accept()
	await _wait(0.8)
	_pick(menu, "Pulso")
	await _wait(0.8)
	menu.accept()
	await _wait(0.4)
	var seen: bool = false
	guard = 0
	while ctrl.executing == null and guard < MAX_FRAMES:
		guard += 1
		await get_tree().process_frame
	_log("Suporte chamado; Limite de %s = %.2f" % [hero.display_name, hero.limit])
	await _wait(0.35)
	seen = battle.support_view_visible()
	_log("reserva na tela durante a acao: %s" % seen)
	while ctrl.executing != null:
		await get_tree().process_frame
	_log("reserva some no fim: %s" % (not battle.support_view_visible()))
	await _wait(1.5)
	_log("ciclo concluido")

## Faz o inimigo acertar `hero` ate a barra chegar a `target` (ou o heroi quase cair).
func _hurt_until(ctrl: BattleController, hero: Combatant, target: float) -> void:
	var foe: Combatant = ctrl.b.enemies[0]
	var guard: int = 0
	while hero.limit < target and guard < 60 and hero.hp > 1:
		guard += 1
		var a := PendingAction.new()
		a.actor = foe
		a.ability = foe.basic_attack
		a.center = hero
		a.center_pos = hero.position
		var r: ActionResult = ActionExecutor.apply(a, ctrl.b)
		for hit: Dictionary in r.hits:
			(game.current as LocalMap).battle.views[hit["target_id"]].show_hit(hit)
		await _wait(0.4)
	if hero.limit < target:
		hero.limit = target

## Espera o menu de `hero`; turnos de outros herois passam com "Atacar".
func _until_turn(ctrl: BattleController, menu: CommandMenu, hero: Combatant) -> void:
	var guard: int = 0
	while guard < MAX_FRAMES:
		guard += 1
		await get_tree().process_frame
		if guard % 120 == 0:
			_log("espera turno: sessao=%s modo=%s exec=%s out=%s el=%s" % [ctrl.session.actor.display_name if ctrl.session != null else "-", menu.mode, ctrl.executing.actor.id if ctrl.executing != null else "-", ctrl.outcome, ctrl.executing.elapsed if ctrl.executing != null else -1.0])
		if ctrl.session == null or menu.mode != CommandMenu.Mode.ROOT:
			continue
		if ctrl.session.actor == hero:
			await _wait(0.6)
			return
		_pick(menu, "Atacar")
		await _wait(0.3)
		menu.accept()

func _pick(menu: CommandMenu, prefix: String) -> void:
	var labels: PackedStringArray = menu.entry_labels()
	for i: int in labels.size():
		if labels[i].begins_with(prefix):
			menu.move(i - menu.cursor)
			menu.accept()
			return

class_name AudioHooks
extends RefCounted

## Ganchos de audio (M19) para quem esta na arvore do jogo: acham o `Game` subindo pelos pais e pedem o som. Cada gancho
## e uma linha no chamador. Sem `Game` acima (cena montada sozinha nos testes), sem banco ou sem diretor, nao faz nada:
## nunca ha erro por falta de audio.

## O `Game` que contem `node` (null se nao ha).
static func game_of(node: Node) -> Game:
	var n: Node = node
	while n != null:
		var g: Game = n as Game
		if g != null:
			return g
		n = n.get_parent()
	return null

## Toca o efeito `id` do banco; vazio, desconhecido ou sem `Game` = nada.
static func play(node: Node, id: StringName) -> void:
	if id == &"":
		return
	var g: Game = game_of(node)
	if g != null:
		g.play_sound(id)

## Toca o som que `SoundEvents.sound_for` escolhe para `event` (o `cfg` do jogo entra sozinho no contexto).
static func event(node: Node, event_kind: SoundEvents.Event, ctx: Dictionary = {}) -> void:
	var g: Game = game_of(node)
	if g == null:
		return
	if not ctx.has("cfg"):
		ctx["cfg"] = g.balance
	g.play_sound(SoundEvents.sound_for(event_kind, ctx))

## Comecou uma batalha neste jogo (`music`: a do encontro; vazio = a padrao).
static func battle_start(node: Node, music: StringName, boss: bool) -> void:
	var g: Game = game_of(node)
	if g != null:
		g.audio_battle_start(music, boss)

## A batalha acabou com `outcome` (BattleController.Outcome).
static func battle_end(node: Node, outcome: BattleController.Outcome) -> void:
	var g: Game = game_of(node)
	if g != null:
		g.audio_battle_end(outcome)

## Um passo de evento trocou a musica (`@musica`).
static func event_music(node: Node, id: StringName, fade: float, stop: bool) -> void:
	var g: Game = game_of(node)
	if g != null:
		g.audio_event_music(id, fade, stop)

## O som de um evento de teclado nos menus: cursor (cima, baixo, esquerda, direita), confirmar ou voltar. Quem trata o
## evento chama isto depois de consumi-lo; evento que nao e de menu nao toca nada.
static func menu_input(node: Node, e: InputEvent) -> void:
	if e.is_action_pressed("ui_up") or e.is_action_pressed("ui_down") or e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right"):
		event(node, SoundEvents.Event.MENU_MOVE)
	elif e.is_action_pressed("ui_accept"):
		event(node, SoundEvents.Event.MENU_CONFIRM)
	elif e.is_action_pressed("ui_cancel") or e.is_action_pressed("open_menu"):
		event(node, SoundEvents.Event.MENU_CANCEL)

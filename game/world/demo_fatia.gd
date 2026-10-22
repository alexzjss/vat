class_name DemoFatia
extends Node

## Roteiro de debug (`-- --demo-fatia`, M12): percorre a fatia vertical inteira sozinho, do título à tela de fim, e é o teste de
## integração dela. Roda na cena principal (game_fatia.tscn) com o perfil da fatia; os saves vão para user://demo_saves/.
## Rota: título → Novo jogo → cidade (moradores, loja: compra e venda, casa 2: recruta D, pousada: salva no slot 1) → carrega o
## save e continua → mapa-múndi → estrada (lutas) → andar 1 (chaves, porta, baú da erva) → volta à cidade (entrega da missão,
## compra e equipa) → andar 1 (interruptor, armadilhas, lutas, recruta E) → andar 2 (puzzle dos dois interruptores, lutas,
## descanso) → cena de entrada → chefe (auto_battle) → cena final → tela de fim → título.
## O jogador é posto (teletransportado) junto de cada objeto e usa a tecla de interação de verdade (LocalMap.try_interact);
## diálogos, menus e telas de resultado/nível são conduzidos pela API pública das telas. As lutas são auto_battle (ataque básico).
## Cada marco imprime uma linha com o quadro (verificação com --write-movie). Termina com `quit(0)`, ou `quit(1)` e "FALHA: ..."
## na primeira etapa que não bater. `--seed=N` troca a semente do jogo; `--speed=N` o fator de tempo (padrão 6 sem janela, 1 com).

const DEFAULT_SEED: int = 12
const HEADLESS_TIME_SCALE: float = 6.0
const SAVE_SLOT: int = 1
## Tempo de jogo que cada fala, resultado e marco ficam na tela antes de avançar (para o filme).
const DIALOGUE_HOLD: float = 0.25
const RESULT_HOLD: float = 0.7
const MILESTONE_HOLD: float = 1.0
## Limite de quadros de cada espera (evita travar o roteiro).
const MAX_FRAMES: int = 60000
const WEAK_BELOW: float = 0.5

var game: Game
## Verdadeiro se alguma verificação falhou (a demo imprime "FALHA: ..." e sai com 1; os testes olham isto).
var failed: bool = false
## Multiplica as pausas da demo (1 = filme; os testes usam um valor pequeno).
var pace: float = 1.0
## Falso nos testes: eles põem `game` na mão e chamam as etapas (_stage_*) uma a uma, em vez de rodar o roteiro inteiro.
var auto_run: bool = true
var _answers: Array[int] = []
var _idle: float = 0.0
var _battles: int = 0

func _ready() -> void:
	if not auto_run:
		return
	game = get_parent() as Game
	if game == null:
		push_error("DemoFatia: precisa ser filho do Game")
		queue_free()
		return
	_run.call_deferred()

# --- utilitários -----------------------------------------------------------------------

func _wait(t: float) -> void:
	await get_tree().create_timer(t * pace, true).timeout

func _frames(n: int = 1) -> void:
	for i: int in n:
		await get_tree().process_frame

func _physics(n: int = 3) -> void:
	for i: int in n:
		await get_tree().physics_frame

func _log(text: String) -> void:
	print("DemoFatia [quadro %d]: %s" % [Engine.get_process_frames(), text])

func _check(cond: bool, what: String) -> bool:
	if cond:
		return true
	_log("FALHA: %s" % what)
	failed = true
	return false

func _arg(name: String, default: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return a.trim_prefix(name + "=")
	return default

## Marco da rota: registra o quadro e segura a tela um instante.
func _milestone(text: String) -> void:
	_log(text)
	await _wait(MILESTONE_HOLD)

func _map() -> LocalMap:
	return game.current as LocalMap

func _node(path: String) -> Node2D:
	return game.current.get_node_or_null(NodePath(path)) as Node2D

## Espera o fim de uma troca de mapa e liga o auto_battle no mapa novo.
func _settle() -> void:
	var guard: int = 0
	while (game.busy or game.current == null) and guard < MAX_FRAMES:
		guard += 1
		await get_tree().process_frame
	await _physics(2)
	var m: LocalMap = _map()
	if m != null:
		m.auto_battle = true

func _expect_map(id: StringName) -> bool:
	await _settle()
	return _check(game.current_map == id, "esperava o mapa '%s' e estou em '%s'" % [id, game.current_map])

## Posta o jogador junto de `n` (um pouco abaixo, fora do bloqueio sólido) e espera a física assentar.
func _stand_by(n: Node2D, offset: Vector2 = Vector2(0, 36)) -> void:
	var p: Node2D = (game.current as Node).get_node("Player") as Node2D
	p.global_position = n.global_position + offset
	await _physics(3)

## Usa a tecla de interação junto de `name` (objeto do mapa atual) e conduz o que ela abrir.
func _use(name: String, answers: Array[int] = []) -> bool:
	var n: Node2D = _node(name)
	if not _check(n != null, "objeto '%s' no mapa '%s'" % [name, game.current_map]):
		return false
	await _stand_by(n)
	_answers = answers.duplicate()
	if not _check(_map().try_interact(), "interagir com '%s'" % name):
		return false
	await _drive()
	return not failed

## Entra numa MapLink pisando nela e espera o mapa novo.
func _go_link(name: String, target: StringName) -> bool:
	var link: Node2D = _node(name)
	if not _check(link != null, "ligação '%s'" % name):
		return false
	await _stand_by(link, Vector2.ZERO)
	return await _expect_map(target)

## Entra numa zona do mapa-múndi pisando nela.
func _go_zone(name: String, target: StringName) -> bool:
	var zone: Node2D = _node(name)
	if not _check(zone != null, "zona '%s'" % name):
		return false
	await _stand_by(zone, Vector2.ZERO)
	return await _expect_map(target)

# --- condução de diálogos, menus e batalhas --------------------------------------------

## Um quadro de condução: avança a caixa de diálogo e as telas de resultado/nível da batalha em curso.
func _step_ui() -> void:
	var delta: float = get_process_delta_time()
	var box: DialogueBox = game.event_player.dialogue
	if box.is_open:
		if box.is_revealing():
			box.accept()
			_idle = 0.0
			return
		_idle += delta
		if _idle >= DIALOGUE_HOLD * pace:
			_idle = 0.0
			if not box.options.is_empty() and not _answers.is_empty():
				var pick: int = _answers.pop_front()
				for i: int in pick:
					box.move(1)
			box.accept()
		return
	var m: LocalMap = _map()
	if m != null and m.battle != null:
		_step_battle(m.battle, delta)

func _step_battle(b: BattleScene, delta: float) -> void:
	var result: ResultScreen = b.get_node("UI/ResultScreen") as ResultScreen
	var level_up: LevelUpScreen = b.get_node("UI/LevelUpScreen") as LevelUpScreen
	match b.phase:
		BattleScene.Phase.RESULT, BattleScene.Phase.CONTINUE:
			_idle += delta
			if _idle >= RESULT_HOLD * pace:
				_idle = 0.0
				result.accept()
		BattleScene.Phase.LEVEL_UP:
			_idle += delta
			if level_up.visible and level_up.hero != null and _idle >= DIALOGUE_HOLD * pace:
				_idle = 0.0
				# Pontos em Vitalidade e Força, metade e metade (o ataque básico do auto_battle não usa o resto).
				var half: int = level_up.remaining() / 2
				for i: int in half:
					level_up.increment(&"vitality")
				while level_up.remaining() > 0:
					level_up.increment(&"strength")
				level_up.confirm()

## Conduz até não haver evento nem batalha em curso (nem Game Over).
func _drive() -> void:
	var guard: int = 0
	await _frames(2)
	while guard < MAX_FRAMES:
		var m: LocalMap = _map()
		var busy_now: bool = game.event_player.active or game.busy or (m != null and m.battle != null)
		if not busy_now or game.game_over_screen != null:
			break
		guard += 1
		if guard % 1200 == 0:
			_log("aguardando (%d quadros): evento=%s batalha=%s caixa=%s mapa=%s" % [guard, game.event_player.active, m != null and m.battle != null,
					game.event_player.dialogue.is_open, game.current_map])
		_step_ui()
		await get_tree().process_frame
	await _frames(2)

## Toca o inimigo `name` (posta o jogador nele) e conduz a batalha até o fim. False se perder ou não começar.
func _fight(name: String) -> bool:
	var m: LocalMap = _map()
	var e: MapEnemy = m.get_node_or_null(NodePath(name)) as MapEnemy
	if not _check(e != null, "inimigo '%s' em '%s'" % [name, game.current_map]):
		return false
	var before: int = game.state.party_avg_level()
	var money: int = game.state.money
	var guard: int = 0
	while m.battle == null and guard < 240 and is_instance_valid(e):
		guard += 1
		var p: Node2D = m.get_node("Player") as Node2D
		p.global_position = e.global_position
		await get_tree().physics_frame
	if not _check(m.battle != null, "a luta com '%s' começou" % name):
		return false
	_answers = []
	await _drive()
	if not _check(game.game_over_screen == null, "venceu '%s' (Game Over)" % name):
		return false
	_battles += 1
	_log("luta %d (%s) vencida: Nv %d -> %d, Moedas %d -> %d" % [_battles, name, before, game.state.party_avg_level(), money, game.state.money])
	return true

## Fração de HP do herói mais machucado entre os ativos.
func _weakest_hp() -> float:
	var worst: float = 1.0
	for h: HeroState in game.state.heroes:
		var mx: int = StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), game.state.cfg)
		worst = minf(worst, float(h.hp) / float(maxi(1, mx)))
	return worst

## Descansa no ponto de descanso do mapa (cura, grava o ponto e salva no slot).
func _rest_here() -> bool:
	var m: LocalMap = _map()
	if not _check(m.rest_point != null, "ponto de descanso em '%s'" % game.current_map):
		return false
	await _stand_by(m.rest_point, Vector2(0, -8))
	if not _check(m.try_interact() and game.rest_menu.is_open, "abrir o descanso"):
		return false
	await _wait(0.4)
	game.rest_menu.accept()
	if not _check(game.rest_menu.stage == RestMenu.Stage.SLOTS, "seletor de slots do descanso"):
		return false
	await _wait(0.4)
	await _pick_slot()
	game.rest_menu.cancel()
	game.rest_menu.cancel()
	await _frames(2)
	return _check(not game.rest_menu.is_open and game.state.save_map == game.current_map, "descanso salvo em '%s'" % game.current_map)

## Escolhe o slot do cursor no seletor do descanso, confirmando o "Sobrescrever?" se o slot já tem save.
func _pick_slot() -> void:
	var picker: SaveSlotPicker = game.rest_menu.picker
	picker.accept()
	if picker.confirming:
		await _wait(0.4)
		picker.accept()
	await _wait(0.6)

## Antes de uma luta: se o grupo está fraco, descansa no ponto do mapa (ou, onde não há, no atalho da demo).
func _recover() -> bool:
	if _weakest_hp() >= WEAK_BELOW:
		return true
	var m: LocalMap = _map()
	if m.rest_point != null:
		_log("grupo fraco (%.0f%%): descansando" % (_weakest_hp() * 100.0))
		return await _rest_here()
	_log("grupo fraco (%.0f%%) sem ponto de descanso: atalho da demo (rest_all)" % (_weakest_hp() * 100.0))
	game.state.rest_all()
	return true

func _fights(names: Array[String]) -> bool:
	for n: String in names:
		if not await _recover():
			return false
		if not await _fight(n):
			return false
	return true

# --- loja ------------------------------------------------------------------------------

func _shop_stage(index: int) -> void:
	var sm: ShopMenu = game.shop_menu
	while sm.stage != ShopMenu.Stage.MAIN:
		sm.cancel()
	sm.move(index - sm.cursor)
	sm.accept()

## Põe o cursor da lista atual sobre `id`.
func _shop_pick(id: StringName) -> bool:
	var sm: ShopMenu = game.shop_menu
	for i: int in 40:
		var g: Resource = sm.current_good()
		if g != null and StringName(g.get("id")) == id:
			return true
		sm.move(1)
	return false

func _shop_buy(id: StringName, qty: int) -> bool:
	var sm: ShopMenu = game.shop_menu
	_shop_stage(ShopMenu.BUY_INDEX)
	if not _check(_shop_pick(id), "'%s' à venda" % id):
		return false
	sm.adjust(qty - 1)
	await _wait(0.5)
	var money: int = game.state.money
	sm.accept()
	await _wait(0.5)
	return _check(game.state.money < money, "comprou '%s' x%d (%s)" % [id, qty, sm.message()])

func _shop_sell(id: StringName, qty: int) -> bool:
	var sm: ShopMenu = game.shop_menu
	_shop_stage(ShopMenu.SELL_INDEX)
	if not _check(_shop_pick(id), "'%s' vendável" % id):
		return false
	sm.adjust(qty - 1)
	await _wait(0.5)
	var money: int = game.state.money
	sm.accept()
	await _wait(0.5)
	return _check(game.state.money > money, "vendeu '%s' x%d (%s)" % [id, qty, sm.message()])

## Abre a loja do lojista da cidade, roda `work` e fecha.
func _at_shop(work: Callable) -> bool:
	var keeper: Node2D = _node("Lojista")
	if not _check(keeper != null, "lojista"):
		return false
	await _stand_by(keeper)
	# O lojista cumprimenta antes (fala na caixa de diálogo); a loja abre quando o evento termina.
	if not _check(_map().try_interact() and not game.shop_menu.is_open and game.event_player.active, "lojista cumprimenta antes da loja"):
		return false
	await _drive()
	if not _check(game.shop_menu.is_open, "abrir a loja"):
		return false
	await _milestone("loja aberta: %s" % game.shop_menu.title_text())
	var ok: bool = await work.call()
	game.shop_menu.close()
	await _frames(2)
	return ok and _check(not game.shop_menu.is_open, "fechar a loja")

func _buy_ether_sell_potion() -> bool:
	return await _shop_buy(&"eter_f", 1) and await _shop_sell(&"pocao_f", 1)

## Gasta o que dá (até 5) em Poções.
func _buy_potions() -> bool:
	var qty: int = mini(game.state.money / 10, 5)
	if qty < 1:
		return true
	return await _shop_buy(&"pocao_f", qty)

## Equipa o equipamento `id` da mochila em quem pode vesti-lo.
func _equip_from_bag(id: StringName) -> bool:
	var def: EquipmentDef = game.registry.equipment(id)
	if not _check(def != null and game.state.bag.count(id) > 0, "'%s' na mochila" % id):
		return false
	for h: HeroState in game.state.roster():
		if game.state.equip(h, def.slot, def):
			_log("%s equipou %s" % [h.def.display_name, def.display_name])
			return true
	return _check(false, "alguém pode vestir '%s'" % id)

# --- etapas ----------------------------------------------------------------------------

func _run() -> void:
	await _wait(0.5)
	if DisplayServer.get_name() == "headless":
		Engine.time_scale = float(_arg("--speed", str(HEADLESS_TIME_SCALE)))
	elif _arg("--speed", "") != "":
		Engine.time_scale = float(_arg("--speed", "1"))
	var ok: bool = await _route()
	Engine.time_scale = 1.0
	if not ok or failed:
		_log("ROTEIRO INTERROMPIDO")
		get_tree().quit(1)
		return
	_log("roteiro concluído: %d lutas" % _battles)
	await _wait(0.5)
	get_tree().quit(0)

func _route() -> bool:
	return await _stage_title() and await _stage_town() and await _stage_save_and_load() and await _stage_road() \
			and await _stage_floor_one_herb() and await _stage_quest_delivery() and await _stage_floor_one_rest() \
			and await _stage_floor_two() and await _stage_boss() and await _stage_end()

## Título → Novo jogo, no perfil da fatia (só vale na cena principal game_fatia.tscn).
func _stage_title() -> bool:
	# Saves de uma execução anterior da demo não contam: começa de slots vazios.
	if DirAccess.dir_exists_absolute(Game.DEMO_SAVE_DIR):
		for f: String in DirAccess.get_files_at(Game.DEMO_SAVE_DIR):
			DirAccess.remove_absolute(Game.DEMO_SAVE_DIR.path_join(f))
	game.world_seed = int(_arg("--seed", str(DEFAULT_SEED)))
	if not _check(game.active_profile().map == &"cidade", "perfil da fatia ativo (rode na cena principal game_fatia.tscn)"):
		return false
	if not _check(game.in_title and game.title != null, "título aberto"):
		return false
	await _milestone("título")
	game.title.accept()
	if not await _expect_map(&"cidade"):
		return false
	var s: GameState = game.state
	if not _check(s.money == 50 and s.heroes.size() == 3, "Novo jogo: 3 heróis e 50 Moedas"):
		return false
	await _milestone("Novo jogo na cidade: %d heróis, %d %s" % [s.heroes.size(), s.money, s.cfg.currency_name])
	return true

func _stage_town() -> bool:
	var s: GameState = game.state
	# Moradores (um deles com escolha) e a placa.
	for n: String in ["MoradorA", "MoradorB", "MoradorE", "PlacaSaida"]:
		if not await _use(n, [0]):
			return false
	if not await _use("MoradorD", [0]):
		return false
	# Missão secundária: aceita.
	if not await _use("MoradorC", [0]):
		return false
	if not _check(s.get_flag(&"missao_estado") == 1, "missão aceita"):
		return false
	_log("missão aceita")
	# Loja: compra um Éter e vende uma Poção.
	var money_before: int = s.money
	if not await _at_shop(_buy_ether_sell_potion):
		return false
	_log("loja: %d -> %d Moedas (comprou Éter, vendeu Poção)" % [money_before, s.money])
	# Casa 1: baú e morador.
	await _stand_by(_node("Casa1Porta"), Vector2.ZERO)
	if not await _expect_map(&"casa_1"):
		return false
	if not await _use("Bau") or not await _use("MoradorF", [0]):
		return false
	if not await _go_link("Saida", &"cidade"):
		return false
	# Casa 2: o recruta D.
	await _stand_by(_node("Casa2Porta"), Vector2.ZERO)
	if not await _expect_map(&"casa_2"):
		return false
	if not await _use("NpcD", [0]):
		return false
	if not _check(s.roster().size() == 4 and s.heroes.size() == 4, "recruta D nos ativos"):
		return false
	await _milestone("recruta D: %s Nv %d" % [s.heroes[3].def.display_name, s.heroes[3].level])
	return await _go_link("Saida", &"cidade")

## Pousada (paga, salva no slot 1) e carregar o save no meio do caminho.
func _stage_save_and_load() -> bool:
	var s: GameState = game.state
	var money: int = s.money
	var price: int = s.cfg.inn_price
	if not _check(money >= price, "Moedas para a pousada"):
		return false
	var inn: Inn = _node("Pousada") as Inn
	await _stand_by(inn, Vector2(0, 12))
	if not _check(_map().try_interact() and game.rest_menu.is_open, "abrir a pousada"):
		return false
	await _milestone("pousada: %s" % game.rest_menu.entries()[0])
	game.rest_menu.accept()
	if not _check(game.rest_menu.stage == RestMenu.Stage.SLOTS and s.money == money - price, "pousada cobra %d" % price):
		return false
	await _wait(0.5)
	await _pick_slot()
	if not _check(game.last_slot == SAVE_SLOT and game.store.read(SAVE_SLOT, Dice.new(1)) != null, "salvo no slot %d" % SAVE_SLOT):
		return false
	game.rest_menu.cancel()
	game.rest_menu.cancel()
	await _frames(2)
	if not _check(s.save_map == &"cidade" and s.save_spawn == inn.spawn_name, "save grava a pousada"):
		return false
	_log("pousada: salvo no slot %d (%d Moedas)" % [SAVE_SLOT, s.money])
	# Carrega o save e continua dali.
	var money_saved: int = s.money
	if not _check(game.continue_from_slot(SAVE_SLOT), "carregar o slot %d" % SAVE_SLOT):
		return false
	if not await _expect_map(&"cidade"):
		return false
	s = game.state
	if not _check(s.money == money_saved and s.roster().size() == 4 and s.get_flag(&"missao_estado") == 1, "o save volta inteiro (Moedas, grupo, missão)"):
		return false
	await _milestone("save carregado: %d heróis, %d Moedas, missão em andamento" % [s.roster().size(), s.money])
	return true

## Cidade → mapa-múndi → estrada (lutas no caminho) → mapa-múndi → dungeon.
func _stage_road() -> bool:
	if not await _go_link("SaidaLink", &"overworld_fatia"):
		return false
	await _milestone("mapa-múndi da fatia")
	if not await _go_zone("Estrada", &"estrada"):
		return false
	await _milestone("estrada")
	if not await _fights(["Errante", "Patrulheiro"]):
		return false
	if not await _go_link("LinkLeste", &"overworld_fatia"):
		return false
	return await _go_zone("Dungeon", &"dungeon_1")

## Andar 1: descanso na entrada, baús, chave e porta, e o baú opcional da erva.
func _stage_floor_one_herb() -> bool:
	var s: GameState = game.state
	await _milestone("dungeon, andar 1")
	if not await _rest_here():
		return false
	for n: String in ["BauPocao", "BauChave"]:
		if not await _use(n):
			return false
	if not await _use("Door"):
		return false
	if not _check((_node("Door") as Door).is_open(), "porta aberta com a chave"):
		return false
	if not await _use("BauErva"):
		return false
	if not _check(s.get_flag(&"bau_erva") == 1 and s.inventory.count(&"erva_teste") == 1, "baú da erva aberto, erva na mochila"):
		return false
	_log("erva obtida; volta à cidade para entregar a missão")
	if not await _go_link("SaidaLink", &"overworld_fatia"):
		return false
	return await _go_zone("Cidade", &"cidade")

## Entrega da missão: Moedas, equipamento e XP; compra mais e equipa.
func _stage_quest_delivery() -> bool:
	var s: GameState = game.state
	var money: int = s.money
	var bag: int = s.bag.listing().size()
	if not await _use("MoradorC"):
		return false
	if not _check(s.get_flag(&"missao_estado") == 2 and s.money > money and s.bag.listing().size() > bag, "missão entregue (Moedas e equipamento)"):
		return false
	if not _check(s.inventory.count(&"erva_teste") == 0, "a missão consumiu a erva"):
		return false
	await _milestone("missão entregue: %d Moedas" % s.money)
	if not await _equip_from_bag(&"capacete_teste_b_f"):
		return false
	# Gasta o que dá em Poções (cura para as lutas do andar).
	if not await _at_shop(_buy_potions):
		return false
	if not await _go_link("SaidaLink", &"overworld_fatia"):
		return false
	return await _go_zone("Dungeon", &"dungeon_1")

## Andar 1 (volta): interruptor e portão, armadilhas, lutas, o recruta E e a escada.
func _stage_floor_one_rest() -> bool:
	var s: GameState = game.state
	if not _check(s.get_flag(&"bau_erva") == 1, "o baú da erva continua aberto na volta"):
		return false
	if not await _use("Switch"):
		return false
	if not _check(not (_node("Gate") as FlagGate).blocking(), "portão aberto pelo interruptor"):
		return false
	# Armadilha de dano e armadilha de batalha.
	await _stand_by(_node("TrapDano"), Vector2.ZERO)
	await _drive()
	if not _check(s.get_flag(&"f1_trap_dano") == 1, "armadilha de dano disparou"):
		return false
	if not await _recover():
		return false
	await _stand_by(_node("TrapBatalha"), Vector2.ZERO)
	_answers = []
	await _drive()
	if not _check(s.get_flag(&"f1_trap_batalha") == 1 and game.game_over_screen == null, "armadilha de batalha vencida"):
		return false
	_battles += 1
	if not await _fights(["Patrulheiro", "Errante", "Perseguidor", "DuplaA"]):
		return false
	if not await _use("BauEter"):
		return false
	# Recruta E, no fim do andar: com 4 ativos, vai para a reserva.
	await _stand_by(_node("CenaETrigger"), Vector2.ZERO)
	await _drive()
	if not _check(s.roster().size() == 5 and s.reserve.size() == 1, "recruta E na reserva"):
		return false
	await _milestone("recruta E: %s (reserva)" % s.reserve[0].def.display_name)
	if not await _go_link("EscadaLink", &"dungeon_2"):
		return false
	return true

## Andar 2: puzzle dos dois interruptores, lutas e descanso antes do chefe.
func _stage_floor_two() -> bool:
	await _milestone("dungeon, andar 2")
	if not await _fights(["Patrulheiro", "DuplaA", "Errante"]):
		return false
	if not await _use("BauA"):
		return false
	var gates: Array[FlagGate] = []
	for c: Node in game.current.get_children():
		if c is FlagGate:
			gates.append(c)
	if not await _use("SwitchA"):
		return false
	if not _check(_any_blocking(gates), "um interruptor só não abre"):
		return false
	if not await _use("SwitchB"):
		return false
	if not _check(not _any_blocking(gates), "os dois interruptores abrem a passagem"):
		return false
	await _milestone("puzzle resolvido")
	if not await _fights(["Perseguidor"]):
		return false
	if not await _use("BauC"):
		return false
	return await _rest_here()

func _any_blocking(gates: Array[FlagGate]) -> bool:
	for g: FlagGate in gates:
		if g.blocking():
			return true
	return false

## Cena de entrada, o chefe (auto_battle) e a vitória.
func _stage_boss() -> bool:
	var s: GameState = game.state
	var boss: MapEnemy = _node("Boss") as MapEnemy
	if not _check(boss != null and not boss.visible, "o chefe fica escondido antes da cena de entrada"):
		return false
	await _stand_by(_node("CenaChefeTrigger"), Vector2.ZERO)
	_answers = []
	await _drive()
	if not _check(s.get_flag(&"f2_cena_chefe") == 1 and boss.visible, "cena de entrada e chefe visível"):
		return false
	_log("grupo para o chefe: Nv médio %d" % s.party_avg_level())
	await _milestone("sala do chefe")
	if not await _recover():
		return false
	if not await _fight("Boss"):
		return false
	return _check(s.is_defeated(&"chefe_fatia"), "chefe derrotado")

## Cena final → tela de fim → título.
func _stage_end() -> bool:
	var s: GameState = game.state
	await _stand_by(_node("FinalTrigger"), Vector2.ZERO)
	_answers = []
	await _drive()
	if not _check(game.end_screen != null, "tela de fim aberta"):
		return false
	await _milestone("tela de fim: %s" % game.end_screen.body_text().replace("\n", " | "))
	var clear: GameState = game.store.read(game.last_slot, Dice.new(1))
	if not _check(clear != null and clear.get_flag(Game.FLAG_CONCLUDED) == 1, "clear save gravado no slot %d" % game.last_slot):
		return false
	_log("clear save gravado; Nv médio %d, Moedas %d" % [s.party_avg_level(), s.money])
	game.end_screen.accept()
	await _frames(3)
	if not _check(game.in_title and game.title != null and game.end_screen == null, "de volta ao título"):
		return false
	await _milestone("de volta ao título")
	return true

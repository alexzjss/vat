extends GutTest

## Rota da fatia vertical (M12, Task 6), etapa por etapa, num Game real (game_fatia.tscn). As etapas são as mesmas do roteiro
## `--demo-fatia` (DemoFatia): os testes chamam os `_stage_*` e os ajudantes dele (que põem o jogador junto dos objetos e usam a
## tecla de interação de verdade, conduzem diálogos, menus e telas de resultado) em vez de rodar o roteiro inteiro, que é a
## própria demo (headless, ~3000 quadros). Tudo é placeholder / valor de teste.

const FATIA_SCENE: String = "res://world/game_fatia.tscn"
const TMP: String = "user://test_saves/"
## Fator de tempo das lutas de verdade (o ATB anda mais rápido; só estes testes).
const FIGHT_SPEED: float = 8.0
const PACE: float = 0.02

var game: Game
var demo: DemoFatia

func after_each() -> void:
	Engine.time_scale = 1.0
	Input.flush_buffered_events()
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

## Monta o Game da fatia e a demo (sem rodar o roteiro). Sem `skip_title`, o jogo abre no título.
func _boot(skip_title: bool) -> void:
	game = (load(FATIA_SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = (load("res://data/test/balance.tres") as BalanceConfig).duplicate() as BalanceConfig
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.skip_title = skip_title
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	add_child_autofree(game)
	demo = DemoFatia.new()
	demo.auto_run = false
	demo.pace = PACE
	demo.game = game
	add_child_autofree(demo)

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1

## Novo jogo no perfil da fatia, sem passar pelo título.
func _new_game() -> void:
	_boot(true)
	game.use_test_profile = false
	game.start_new_game()
	await _wait_idle()
	await demo._settle()

## Vai direto para `map_id` (o spawn `Entry`).
func _enter(map_id: StringName) -> void:
	game.go_to(map_id, &"Entry", false)
	await demo._settle()

## Grupo no nível `n`, com os pontos em Vitalidade e Força, HP/AP cheios.
func _level_party(n: int) -> void:
	var cfg: BalanceConfig = game.state.cfg
	for h: HeroState in game.state.roster():
		XpCalculator.grant(h, XpCalculator.xp_for_level(n, cfg), cfg)
		XpCalculator.allocate(h, &"vitality", h.pending_points / 2)
		XpCalculator.allocate(h, &"strength", h.pending_points)
		h.rest(cfg)

# --- título e cidade -----------------------------------------------------------------------

func test_title_new_game_lands_in_the_town_with_the_fatia_profile() -> void:
	_boot(false)
	assert_true(game.in_title, "abre no título")
	assert_true(await demo._stage_title())
	assert_false(demo.failed)
	assert_eq(game.current_map, &"cidade")
	assert_eq(game.state.money, 50)
	assert_eq(game.state.heroes.size(), 3)
	assert_false(game.in_title)

func test_town_residents_shop_quest_accept_and_recruit_d() -> void:
	_boot(false)
	assert_true(await demo._stage_title())
	assert_true(await demo._stage_town())
	assert_false(demo.failed)
	var s: GameState = game.state
	assert_eq(s.get_flag(&"missao_estado"), 1, "missão aceita")
	assert_eq(s.money, 30, "50 - Éter (25) + Poção vendida (5)")
	assert_eq(s.inventory.available(&"eter_f"), 2, "comprou um Éter e achou outro no baú da casa 1")
	assert_eq(s.inventory.available(&"pocao_f"), 2, "vendeu uma das 3 Poções")
	assert_eq(s.roster().size(), 4, "recruta D")
	assert_eq(s.heroes[3].def.id, &"teste_d")
	assert_eq(game.current_map, &"cidade", "voltou da casa 2")
	assert_false(game.shop_menu.is_open)

func test_inn_charges_saves_in_the_slot_and_continue_restores_it() -> void:
	_boot(false)
	assert_true(await demo._stage_title())
	assert_true(await demo._stage_town())
	assert_true(await demo._stage_save_and_load())
	assert_false(demo.failed)
	assert_eq(game.last_slot, DemoFatia.SAVE_SLOT)
	assert_eq(game.state.money, 10, "30 - pousada (20)")
	assert_eq(game.state.save_spawn, &"InnSpawn")
	assert_eq(game.current_map, &"cidade")
	assert_eq(game.state.roster().size(), 4, "o recruta D veio no save")
	assert_eq(game.state.get_flag(&"missao_estado"), 1)

# --- estrada, andar 1 ----------------------------------------------------------------------

func test_road_fight_pays_money_and_xp() -> void:
	await _new_game()
	_level_party(4)
	await _enter(&"estrada")
	var money: int = game.state.money
	var xp: int = game.state.heroes[0].xp
	Engine.time_scale = FIGHT_SPEED
	var won: bool = await demo._fight("Errante")
	Engine.time_scale = 1.0
	assert_true(won)
	assert_false(demo.failed)
	assert_gt(game.state.money, money, "moeda da luta")
	assert_gt(game.state.heroes[0].xp, xp, "XP da luta")
	assert_null(game.current.get_node_or_null(^"Errante"), "o inimigo derrotado sai do mapa")

func test_floor_one_herb_then_back_to_town_for_the_quest_and_return() -> void:
	await _new_game()
	game.state.set_flag(&"missao_estado", 1)
	await _enter(&"dungeon_1")
	assert_true(await demo._stage_floor_one_herb())
	assert_eq(game.state.get_flag(&"bau_erva"), 1, "erva coletada")
	assert_eq(game.current_map, &"cidade", "voltou para entregar")
	assert_true(await demo._stage_quest_delivery())
	assert_false(demo.failed)
	assert_eq(game.state.get_flag(&"missao_estado"), 2, "missão entregue")
	assert_eq(game.state.bag.count(&"capacete_teste_b_f"), 0, "o capacete da missão foi equipado")
	assert_eq(game.current_map, &"dungeon_1", "de volta ao andar 1")

func test_floor_one_key_door_switch_traps_and_recruit_e() -> void:
	await _new_game()
	var s: GameState = game.state
	await _enter(&"dungeon_1")
	assert_true(await demo._use("BauChave"))
	assert_true(await demo._use("Door"))
	assert_true((game.current.get_node("Door") as Door).is_open(), "a chave abre a porta")
	assert_true(await demo._use("Switch"))
	assert_false((game.current.get_node("Gate") as FlagGate).blocking(), "o interruptor abre o portão")
	await demo._stand_by(game.current.get_node("TrapDano") as Node2D, Vector2.ZERO)
	await demo._drive()
	assert_eq(s.get_flag(&"f1_trap_dano"), 1, "armadilha de dano")
	var hp_max: int = StatCalculator.hp_max(Combatant.from_hero(s.heroes[0], Vector2.ZERO), s.cfg)
	assert_lt(s.heroes[0].hp, hp_max, "tirou HP")
	_level_party(6)
	s.set_flag(&"f1_trap_batalha", 0)
	Engine.time_scale = FIGHT_SPEED
	await demo._stand_by(game.current.get_node("TrapBatalha") as Node2D, Vector2.ZERO)
	await demo._drive()
	Engine.time_scale = 1.0
	assert_eq(s.get_flag(&"f1_trap_batalha"), 1, "armadilha de batalha")
	assert_null(game.game_over_screen, "venceu a batalha da armadilha com o aviso fechado")
	assert_true(await demo._use("BauEter"))
	await demo._stand_by(game.current.get_node("CenaETrigger") as Node2D, Vector2.ZERO)
	await demo._drive()
	assert_eq(s.roster().size(), 4, "A, B, C e o E")
	assert_eq(s.heroes.size(), 4, "E entra nos ativos: havia vaga")
	assert_eq(s.heroes[3].def.id, &"teste_e")
	assert_true(await demo._go_link("EscadaLink", &"dungeon_2"))

# --- andar 2, chefe e fim -----------------------------------------------------------------

func test_floor_two_puzzle_needs_both_switches() -> void:
	await _new_game()
	await _enter(&"dungeon_2")
	var gates: Array[FlagGate] = []
	for c: Node in game.current.get_children():
		if c is FlagGate:
			gates.append(c)
	assert_true(demo._any_blocking(gates), "fechado")
	assert_true(await demo._use("SwitchA"))
	assert_true(demo._any_blocking(gates), "só A: fechado")
	assert_true(await demo._use("SwitchB"))
	assert_false(demo._any_blocking(gates), "A e B: aberto")
	assert_false(demo.failed)

func test_boss_fight_final_scene_end_screen_and_back_to_the_title() -> void:
	await _new_game()
	var s: GameState = game.state
	_level_party(7)
	await _enter(&"dungeon_2")
	assert_true(await demo._rest_here(), "descansa e salva antes do chefe")
	assert_eq(game.last_slot, DemoFatia.SAVE_SLOT)
	Engine.time_scale = FIGHT_SPEED
	var won: bool = await demo._stage_boss()
	Engine.time_scale = 1.0
	assert_true(won, "cena de entrada, chefe e vitória")
	assert_true(s.is_defeated(&"chefe_fatia"))
	assert_true(await demo._stage_end(), "cena final, tela de fim, clear save e título")
	assert_false(demo.failed)
	assert_true(game.in_title)
	assert_null(game.end_screen)
	var clear: GameState = game.store.read(DemoFatia.SAVE_SLOT, Dice.new(1))
	assert_eq(clear.get_flag(Game.FLAG_CONCLUDED), 1, "clear save no último slot usado")

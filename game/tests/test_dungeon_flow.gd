extends GutTest

## Fluxo da dungeon de teste (M10): entrar e sair, NPC -> Teach, e save/carregamento mantendo baús, porta e portão.

const SCENE: String = "res://world/game.tscn"
const TMP: String = "user://test_saves/"

var game: Game
var map: LocalMap

func before_each() -> void:
	game = (load(SCENE) as PackedScene).instantiate() as Game
	var cfg: BalanceConfig = Fixtures.cfg()
	cfg.fade_time = 0.01
	game.balance = cfg
	game.world_seed = 7
	game.save_dir = TMP
	game.settings_path = TMP.path_join("settings.cfg")
	game.skip_title = true
	add_child_autofree(game)

func after_each() -> void:
	Input.flush_buffered_events()
	if DirAccess.dir_exists_absolute(TMP):
		for f: String in DirAccess.get_files_at(TMP):
			DirAccess.remove_absolute(TMP.path_join(f))
		DirAccess.remove_absolute(TMP)

func _wait_idle() -> void:
	var guard: int = 0
	while game.busy and guard < 600:
		await get_tree().process_frame
		guard += 1

func _enter_dungeon() -> void:
	await _wait_idle()
	(game.current as Overworld).location_entered.emit(&"dungeon_teste", &"Entry")
	await _wait_idle()
	map = game.current as LocalMap

func _accept_all() -> void:
	var guard: int = 0
	while game.event_player.active and guard < 80:
		guard += 1
		var box: DialogueBox = game.event_player.dialogue
		box._shown = 9999.0
		box.accept()
		await get_tree().process_frame

func test_enter_and_leave_the_dungeon() -> void:
	await _enter_dungeon()
	assert_eq(game.current_map, &"dungeon_teste")
	assert_eq(map.player.global_position, map.get_node("Entry").global_position)
	map.exit_requested.emit()
	await _wait_idle()
	assert_eq(game.current_map, &"overworld")
	var world: Overworld = game.current as Overworld
	assert_eq(world.player.global_position, world.get_node("DungeonReturn").global_position)

func test_dungeon_has_all_the_objects() -> void:
	await _enter_dungeon()
	for n: String in ["Sign", "NpcGuia", "ChestPocao", "ChestChave", "Door", "TrapDano", "Switch", "Gate", "TrapBatalha", "CenaTrigger", "NpcFinal", "BossSpot"]:
		assert_not_null(map.get_node_or_null(NodePath(n)), n)

func test_sign_at_the_entrance_speaks() -> void:
	await _enter_dungeon()
	map.player.global_position = (map.get_node("Sign") as Node2D).global_position + Vector2(0, 40)
	assert_true(map.try_interact())
	assert_true(game.event_player.dialogue._body.text.begins_with("Dungeon de teste"))
	game.event_player.cancel()

func test_npc_yes_teaches_the_technique_and_gives_xp() -> void:
	await _enter_dungeon()
	var hero: HeroState = game.state.heroes[0]
	assert_eq(hero.def.id, &"teste_a")
	assert_false(hero.learned.has(&"rajada"))
	var xp_before: int = hero.xp
	var level_before: int = hero.level
	var npc: Node2D = map.get_node("NpcGuia") as Node2D
	map.player.global_position = npc.global_position + Vector2(0, 40)
	assert_true(map.try_interact())
	await _accept_all()
	assert_eq(game.state.get_flag(&"guia_escolha"), 0, "Sim é a primeira opção")
	assert_true(hero.learned.has(&"rajada"))
	assert_true(hero.xp > xp_before or hero.level > level_before, "XP narrativa concedida")
	assert_eq(game.state.get_flag(&"guia_ensinou"), 1)

func test_npc_no_teaches_nothing() -> void:
	await _enter_dungeon()
	var hero: HeroState = game.state.heroes[0]
	var npc: Node2D = map.get_node("NpcGuia") as Node2D
	map.player.global_position = npc.global_position + Vector2(0, 40)
	assert_true(map.try_interact())
	var box: DialogueBox = game.event_player.dialogue
	var guard: int = 0
	while box.options.is_empty() and guard < 20:
		guard += 1
		box._shown = 9999.0
		box.accept()
		await get_tree().process_frame
	box._shown = 9999.0
	box.move(1)
	await _accept_all()
	assert_eq(game.state.get_flag(&"guia_escolha"), 1)
	assert_false(hero.learned.has(&"rajada"))
	assert_eq(game.state.get_flag(&"guia_ensinou"), 0)

func test_npc_remembers_after_teaching() -> void:
	await _enter_dungeon()
	game.state.set_flag(&"guia_ensinou", 1)
	var npc: Node2D = map.get_node("NpcGuia") as Node2D
	map.player.global_position = npc.global_position + Vector2(0, 40)
	assert_true(map.try_interact())
	assert_eq(game.event_player.dialogue._body.text, "Você já aprendeu comigo.")
	game.event_player.cancel()

func test_save_and_continue_keep_chests_door_and_gate() -> void:
	await _enter_dungeon()
	for f: StringName in [&"bau_pocao", &"bau_chave", &"porta_aberta", &"portao_aberto"]:
		game.state.set_flag(f, 1)
	map.player.global_position = (map.get_node("RestPoint") as Node2D).global_position
	assert_true(game.can_save())
	assert_true(game.save_to_slot(1))
	assert_true(game.continue_from_slot(1))
	await _wait_idle()
	map = game.current as LocalMap
	assert_eq(game.current_map, &"dungeon_teste")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true((map.get_node("ChestPocao") as Chest).is_open())
	assert_true((map.get_node("ChestChave") as Chest).is_open())
	assert_false((map.get_node("Door") as Door).blocking())
	assert_false((map.get_node("Gate") as FlagGate).blocking())

func test_game_over_restore_closes_everything_again() -> void:
	await _enter_dungeon()
	game.state.save(&"dungeon_teste", &"Entry")
	for f: StringName in [&"bau_pocao", &"porta_aberta", &"portao_aberto"]:
		game.state.set_flag(f, 1)
	game.state.restore_save()
	assert_true((map.get_node("Door") as Door).blocking())
	assert_true((map.get_node("Gate") as FlagGate).blocking())
	assert_false((map.get_node("ChestPocao") as Chest).is_open())

func test_key_chest_gives_a_key_that_opens_the_door() -> void:
	await _enter_dungeon()
	var chest: Chest = map.get_node("ChestChave") as Chest
	map.player.global_position = chest.global_position + Vector2(0, 40)
	assert_true(map.try_interact())
	await _accept_all()
	assert_eq(game.state.inventory.available(&"chave_teste"), 1)
	var door: Door = map.get_node("Door") as Door
	map.player.global_position = door.global_position + Vector2(-40, 0)
	assert_true(map.try_interact())
	await _accept_all()
	assert_true(door.is_open())
	assert_eq(game.state.inventory.available(&"chave_teste"), 1, "chave não consumida")

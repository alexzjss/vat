extends GutTest

const SCENE: PackedScene = preload("res://ui/field_menu/field_menu.tscn")

var g: GameState
var menu: FieldMenu
var page: ConfigPage

func before_each() -> void:
	var defs: Array[CharacterDef] = [Fixtures.hero_def(&"a", Stats.make(1, 1, 3, 2))]
	g = GameState.new_game(Fixtures.cfg(), defs, [], [], ScriptedDice.new(), &"overworld", &"Start")
	menu = SCENE.instantiate() as FieldMenu
	add_child_autofree(menu)
	menu.open(g)
	menu.move(FieldMenu.COMMAND_PAGES.find(&"config"))
	menu.accept()
	page = menu.config_page

func test_command_opens_config_page() -> void:
	assert_eq(menu.page, &"config")
	assert_eq(page.entries(), PackedStringArray([
		"ATB: Espera", "Velocidade da batalha: 3", "Memória do cursor: Ligada",
		"Velocidade do texto: 2", "Volume: 10",
	]))

func test_left_right_change_values() -> void:
	watch_signals(menu)
	page.adjust(1)
	assert_eq(g.settings.atb_mode, GameSettings.AtbMode.ACTIVE)
	assert_eq(page.entries()[0], "ATB: Ativo")
	page.move(1)
	page.adjust(1)
	assert_eq(g.settings.battle_speed, 4)
	page.adjust(-1)
	page.adjust(-1)
	assert_eq(g.settings.battle_speed, 2)
	page.move(1)
	page.adjust(-1)
	assert_false(g.settings.cursor_memory)
	assert_eq(page.entries()[2], "Memória do cursor: Desligada")
	page.move(1)
	page.adjust(1)
	assert_eq(g.settings.text_speed, 3)
	page.adjust(1)
	assert_eq(g.settings.text_speed, 3, "clamp no maximo")
	page.move(1)
	page.adjust(-1)
	assert_eq(g.settings.volume, 9)
	assert_signal_emit_count(menu, "settings_changed", 8)

func test_cancel_returns_to_root() -> void:
	menu.cancel()
	assert_eq(menu.page, &"root")
	assert_eq(menu.cursor, 7)

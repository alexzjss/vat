extends GutTest

## Preferências das seções recolhíveis dos formulários do Banco (M18): padrões, gravação e arquivo ausente ou ilegível.
## O arquivo fica em user://, nunca na pasta de configuração do editor.

const FormPrefs: GDScript = preload("res://addons/vat_editor/logic/form_prefs.gd")
const Forms: GDScript = preload("res://addons/vat_editor/logic/forms.gd")

const TMP: String = "user://test_form_prefs/"
const CFG: String = "user://test_form_prefs/vat_editor.cfg"

func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)

func after_each() -> void:
	for f: String in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP.path_join(f))
	DirAccess.remove_absolute(TMP)

func test_defaults_hero_and_enemy() -> void:
	for kind: StringName in [&"heroes", &"enemies"]:
		assert_false(FormPrefs.default_open(kind, "Afinidades"), "%s: Afinidades recolhida" % kind)
		assert_false(FormPrefs.default_open(kind, "Arte"), "%s: Arte recolhida" % kind)
	for title: String in ["Identidade", "Atributos", "Técnicas"]:
		assert_true(FormPrefs.default_open(&"heroes", title), title)
	for title: String in ["Identidade e atributos", "Habilidades e IA", "Drops", "Fases e contra-ataque"]:
		assert_true(FormPrefs.default_open(&"enemies", title), title)
	assert_true(FormPrefs.default_open(&"speakers", "Arte"), "só herói e inimigo recolhem a arte")

func test_default_sections_match_descriptors() -> void:
	var hero: Array[String] = []
	for s: Dictionary in Forms.sections(&"heroes"):
		hero.append(s["title"])
	assert_eq(hero, ["Identidade", "Atributos", "Afinidades", "Técnicas", "Arte"] as Array[String])
	var enemy: Array[String] = []
	for s: Dictionary in Forms.sections(&"enemies"):
		enemy.append(s["title"])
	assert_eq(enemy, ["Identidade e atributos", "Afinidades", "Habilidades e IA", "Drops", "Fases e contra-ataque", "Arte"] as Array[String])

func test_missing_file_gives_defaults() -> void:
	assert_false(FileAccess.file_exists(CFG))
	assert_true(FormPrefs.is_open(CFG, &"heroes", "Atributos"))
	assert_false(FormPrefs.is_open(CFG, &"heroes", "Arte"))

func test_set_and_read_back_per_kind_and_title() -> void:
	assert_eq(FormPrefs.set_open(CFG, &"heroes", "Arte", true), OK)
	assert_eq(FormPrefs.set_open(CFG, &"heroes", "Atributos", false), OK)
	assert_true(FormPrefs.is_open(CFG, &"heroes", "Arte"))
	assert_false(FormPrefs.is_open(CFG, &"heroes", "Atributos"))
	assert_false(FormPrefs.is_open(CFG, &"enemies", "Arte"), "outro tipo não é afetado")
	assert_true(FormPrefs.is_open(CFG, &"enemies", "Drops"))

func test_garbled_file_falls_back_and_is_rewritten() -> void:
	var f: FileAccess = FileAccess.open(CFG, FileAccess.WRITE)
	f.store_string("[[ isto = não é { um cfg\n=== \u0001")
	f.close()
	assert_true(FormPrefs.is_open(CFG, &"heroes", "Identidade"))
	assert_false(FormPrefs.is_open(CFG, &"heroes", "Afinidades"))
	assert_eq(FormPrefs.set_open(CFG, &"heroes", "Afinidades", true), OK)
	assert_true(FormPrefs.is_open(CFG, &"heroes", "Afinidades"))

func test_non_bool_value_falls_back() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(FormPrefs.SECTION, "heroes/Arte", "talvez")
	cfg.set_value(FormPrefs.SECTION, "heroes/Atributos", 0)
	cfg.save(CFG)
	assert_false(FormPrefs.is_open(CFG, &"heroes", "Arte"))
	assert_true(FormPrefs.is_open(CFG, &"heroes", "Atributos"))

func test_set_keeps_other_keys_of_the_file() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("outra", "chave", 7)
	cfg.save(CFG)
	FormPrefs.set_open(CFG, &"enemies", "Drops", false)
	var back := ConfigFile.new()
	assert_eq(back.load(CFG), OK)
	assert_eq(back.get_value("outra", "chave"), 7)

func test_default_path_outside_editor_is_user() -> void:
	assert_eq(FormPrefs.default_path(), "user://vat_editor.cfg")

func test_issue_prop_and_section() -> void:
	assert_eq(Forms.issue_prop(&"heroes", "herói 'x': sem ataque básico"), &"basic_attack")
	assert_eq(Forms.section_of(&"heroes", &"basic_attack"), "Técnicas")
	assert_eq(Forms.section_of(&"enemies", &"drops"), "Drops")
	assert_eq(Forms.issue_prop(&"enemies", "inimigo 'x': drop [0] vazio"), &"drops")
	assert_eq(Forms.issue_prop(&"enemies", "chefe 'x' não é imune a 'sono'"), &"immunities")
	assert_eq(Forms.section_of(&"enemies", &"immunities"), "Afinidades")
	assert_eq(Forms.issue_prop(&"heroes", "mensagem desconhecida"), &"")
	assert_eq(Forms.section_of(&"heroes", &"nada"), "")

extends GutTest

## Os formulários do Banco (M17, Task 7) montados de verdade: editar marca "não salvo", Salvar grava no arquivo, Reverter relê o
## disco na mesma instância, a validação ao vivo reage e os widgets editam o recurso aberto. Cópias em user://, nunca `res://data/`.

const Forms: GDScript = preload("res://addons/vat_editor/logic/forms.gd")
const HeroForm: GDScript = preload("res://addons/vat_editor/ui/forms/hero_form.gd")
const EnemyForm: GDScript = preload("res://addons/vat_editor/ui/forms/enemy_form.gd")
const EncounterForm: GDScript = preload("res://addons/vat_editor/ui/forms/encounter_form.gd")
const ListEditor: GDScript = preload("res://addons/vat_editor/ui/widgets/list_editor.gd")
const PctDictEditor: GDScript = preload("res://addons/vat_editor/ui/widgets/element_dict_editor.gd")
const ResourcePicker: GDScript = preload("res://addons/vat_editor/ui/widgets/resource_picker.gd")
const SpritePreview: GDScript = preload("res://addons/vat_editor/ui/widgets/sprite_preview.gd")

const TMP: String = "user://test_forms_ui/"

func after_each() -> void:
	if not DirAccess.dir_exists_absolute(TMP):
		return
	for f: String in DirAccess.get_files_at(TMP):
		DirAccess.remove_absolute(TMP.path_join(f))
	DirAccess.remove_absolute(TMP)

func _open(src: String) -> Resource:
	DirAccess.make_dir_recursive_absolute(TMP)
	var dst: String = TMP.path_join(src.get_file())
	var f: FileAccess = FileAccess.open(dst, FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(src))
	f.close()
	return ResourceLoader.load(dst, "", ResourceLoader.CACHE_MODE_REPLACE)

func _fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)

func _first(root: Node, cls: String) -> Node:
	var found: Array[Node] = root.find_children("*", cls, true, false)
	return found[0] if not found.is_empty() else null

func _issue_text(form: Control) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for l: Node in form.get("_issues").get_children():
		parts.append((l as Label).text)
	return "\n".join(parts)

func test_hero_form_edit_save_and_revert() -> void:
	var hero: CharacterDef = _open("res://data/fatia/heroes/teste_a_f.tres") as CharacterDef
	var form: Control = HeroForm.new()
	add_child_autofree(form)
	form.call(&"edit", hero, [])
	assert_false(form.call(&"is_dirty"))
	assert_true(_issue_text(form).contains("sem problemas"))
	var strength: SpinBox = _first(_first(form, "ScrollContainer"), "SpinBox") as SpinBox
	assert_not_null(strength)
	assert_eq(int(strength.value), 12)
	strength.value = 20
	assert_true(form.call(&"is_dirty"))
	assert_eq(hero.base.strength, 20, "edita a mesma instância")
	assert_eq((_fresh(hero.resource_path) as CharacterDef).base.strength, 12, "nada gravado ainda")
	assert_true(form.call(&"save"))
	assert_false(form.call(&"is_dirty"))
	assert_eq((_fresh(hero.resource_path) as CharacterDef).base.strength, 20)
	hero.base.strength = 7
	strength.value = 8
	assert_true(form.call(&"is_dirty"))
	form.call(&"revert")
	assert_false(form.call(&"is_dirty"))
	assert_eq(form.get("res"), hero, "mesma instância")
	assert_eq(hero.base.strength, 20, "volta ao que está no disco")

func test_revert_restores_fields_missing_from_the_file() -> void:
	var hero: CharacterDef = _open("res://data/fatia/heroes/teste_a_f.tres") as CharacterDef
	var form: Control = HeroForm.new()
	add_child_autofree(form)
	form.call(&"edit", hero, [])
	Forms.dict_set_percent(hero.element_resist, &"atlas", 50.0)
	form.call(&"touch")
	assert_true(form.call(&"is_dirty"))
	form.call(&"revert")
	assert_true(hero.element_resist.is_empty(), "o arquivo não tem afinidades")

func test_adding_rows_through_the_widgets_marks_dirty_and_keeps_types() -> void:
	var enemy: EnemyDef = _open("res://data/fatia/enemies/guardiao_fatia.tres") as EnemyDef
	var form: Control = EnemyForm.new()
	add_child_autofree(form)
	form.call(&"edit", enemy, [])
	var lists: Array[Node] = form.find_children("*", "VBoxContainer", true, false).filter(func(n: Node) -> bool: return n.get_script() == ListEditor)
	assert_gt(lists.size(), 3)
	var before: int = enemy.ai_rules.size()
	var drops_before: int = enemy.drops.size()
	var phases_before: int = enemy.phases.size()
	var wanted: Array = [AiRule, DropEntry, BossPhase]
	for le: Node in lists:
		var script: Variant = (le.get("items") as Array).get_typed_script()
		if wanted.has(script):
			wanted.erase(script)
			le.call(&"_on_add")
	assert_true(wanted.is_empty(), "achou as três listas")
	assert_eq(enemy.ai_rules.size(), before + 1)
	assert_eq(enemy.drops.size(), drops_before + 1)
	assert_eq(enemy.phases.size(), phases_before + 1)
	assert_true(form.call(&"is_dirty"))
	assert_eq(enemy.ai_rules.get_typed_script(), AiRule)
	# regra sem habilidade e drop sem item: a validação ao vivo reclama
	var text: String = _issue_text(form)
	assert_true(text.contains("sem habilidade"), text)
	assert_true(text.contains("sem item nem equipamento"), text)
	assert_true(form.call(&"save"))
	var back: EnemyDef = _fresh(enemy.resource_path) as EnemyDef
	assert_eq(back.ai_rules.size(), before + 1)
	assert_eq(back.phases.size(), phases_before + 1)

func test_element_dict_editor_edits_the_dictionary_in_place() -> void:
	var dict: Dictionary[StringName, float] = {}
	var ed: Control = PctDictEditor.new()
	add_child_autofree(ed)
	ed.call(&"bind", dict, Forms.choices(Forms.SRC_ELEMENT))
	var changes: Array[int] = [0]
	ed.connect(&"changed", func() -> void: changes[0] += 1)
	ed.call(&"_on_add")
	assert_eq(dict.size(), 1)
	var key: StringName = dict.keys()[0]
	var spin: SpinBox = _first(ed, "SpinBox") as SpinBox
	spin.value = 150
	assert_eq(dict[key], 1.5)
	spin.value = -50
	assert_eq(dict[key], -0.5)
	assert_eq(changes[0], 3)
	assert_eq(dict.get_typed_key_builtin(), TYPE_STRING_NAME)

func test_resource_picker_filters_and_reports_the_pick() -> void:
	var picker: Control = ResourcePicker.new()
	add_child_autofree(picker)
	var options: Array[Dictionary] = Forms.choices(Forms.SRC_ENEMY)
	var current: Resource = options[0]["value"]
	picker.call(&"setup", options, current)
	var got: Array = []
	picker.connect(&"picked", func(v: Variant) -> void: got.append(v))
	var menu: OptionButton = _first(picker, "OptionButton") as OptionButton
	assert_eq(menu.item_count, options.size() + 1, "(nenhum) + as opções")
	assert_eq(menu.selected, 1)
	menu.item_selected.emit(0)
	assert_eq(got, [null])
	var filter: LineEdit = _first(picker, "LineEdit") as LineEdit
	filter.text = "inimigo_f1"
	filter.text_changed.emit("inimigo_f1")
	assert_lt(menu.item_count, options.size() + 1)

func test_encounter_form_summary_validation_and_play_request() -> void:
	var enc: EncounterDef = _open("res://data/fatia/encounters/chefe_fatia.tres") as EncounterDef
	var form: Control = EncounterForm.new()
	add_child_autofree(form)
	form.call(&"edit", enc, [])
	var requested: Array = []
	form.connect(&"play_requested", func(id: StringName) -> void: requested.append(id))
	var play: Button = null
	for b: Node in form.find_children("*", "Button", true, false):
		if (b as Button).text == "Testar encontro":
			play = b as Button
	assert_not_null(play)
	play.pressed.emit()
	assert_eq(requested, [&"chefe_fatia"])
	Forms.list_add(enc.enemies, null)
	form.call(&"touch")
	assert_true(_issue_text(form).contains("inimigo [3] vazio"))
	assert_true((form.get("_summary") as Label).text.contains("vaga"))
	play.pressed.emit()
	assert_eq(requested.size(), 1, "sujo: o jogo lê do disco, então não testa")
	form.call(&"revert")
	assert_eq(enc.enemies.size(), 3)
	assert_false(form.call(&"is_dirty"))

func test_sprite_preview_plays_the_slice_art() -> void:
	var preview: Control = SpritePreview.new()
	add_child_autofree(preview)
	preview.call(&"show_sprites", load("res://art/_exemplo/teste_a.tres"))
	assert_eq(preview.call(&"current_animation"), &"idle")
	preview.call(&"show_sprites", null)
	assert_eq(preview.call(&"current_animation"), &"")

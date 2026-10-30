extends GutTest

## Caminhos de UI do editor (M18) que dá para exercitar sem o editor de verdade: o encaminhamento da soltura nos
## cartões de bloco (`BlockCard`) e o marcador da pousada na paleta de objetos. O mouse real, o arrastar da vista e o
## `EditorUndoRedoManager` ficam de fora (só o editor tem), então `add_prefab` inteiro não é testado aqui.

const BlockCard: GDScript = preload("res://addons/vat_editor/ui/block_card.gd")
const ObjectPalette: GDScript = preload("res://addons/vat_editor/ui/object_palette.gd")
const Logic: GDScript = preload("res://addons/vat_editor/logic/roteiro_editor_logic.gd")

func _card(kind: int, idx: int) -> PanelContainer:
	var card: PanelContainer = BlockCard.new()
	var ctx: Dictionary = {}
	card.setup(Logic.new_block(kind), ctx)
	card.index = idx
	add_child_autofree(card)
	card.size = Vector2(300.0, 100.0)
	return card

func test_card_drop_uses_the_half_of_the_card_under_the_mouse() -> void:
	var card: PanelContainer = _card(RoteiroBlock.Kind.SISTEMA, 1)
	var drag: Dictionary = {BlockCard.DRAG_KEY: 0}
	assert_true(card._can_drop(Vector2(10.0, 20.0), drag))
	assert_eq(card.drop_mark(), -1, "metade de cima: linha em cima")
	assert_true(card._can_drop(Vector2(10.0, 80.0), drag))
	assert_eq(card.drop_mark(), 1, "metade de baixo: linha embaixo")
	assert_false(card._can_drop(Vector2(10.0, 20.0), {"outra": 1}), "outro tipo de arrastar")
	assert_eq(card.drop_mark(), 1, "recusar por tipo não mexe na linha")

func test_card_drop_filter_can_refuse_and_clears_the_mark() -> void:
	var card: PanelContainer = _card(RoteiroBlock.Kind.SISTEMA, 1)
	card.drop_filter = func(_from: int, _after: bool) -> bool: return false
	assert_false(card._can_drop(Vector2(10.0, 20.0), {BlockCard.DRAG_KEY: 0}))
	assert_eq(card.drop_mark(), 0)

func test_card_drop_requests_with_index_and_side() -> void:
	var card: PanelContainer = _card(RoteiroBlock.Kind.SISTEMA, 1)
	watch_signals(card)
	card._drop(Vector2(10.0, 80.0), {BlockCard.DRAG_KEY: 3})
	assert_signal_emitted_with_parameters(card, "drop_requested", [3, true])
	assert_eq(card.drop_mark(), 0)
	card._drop(Vector2(10.0, 10.0), {"outra": 1})
	assert_signal_emit_count(card, "drop_requested", 1)

func test_forwarded_handlers_convert_the_child_position_into_card_coordinates() -> void:
	var card: PanelContainer = _card(RoteiroBlock.Kind.FALA, 0)
	card.position = Vector2(50.0, 200.0)
	var child := Control.new()
	child.position = Vector2(7.0, 30.0)
	card.add_child(child)
	assert_eq(card._to_card(Vector2(1.0, 2.0), child), Vector2(8.0, 32.0))
	assert_eq(card._to_card(Vector2(1.0, 2.0), card), Vector2(1.0, 2.0))
	var drag: Dictionary = {BlockCard.DRAG_KEY: 0}
	# Em cima de um filho que está na metade de baixo do cartão (y 30 + 60 = 90 de 100): a linha vai embaixo.
	assert_true(card._can_drop_from(Vector2(1.0, 60.0), drag, child))
	assert_eq(card.drop_mark(), 1)
	assert_true(card._can_drop_from(Vector2(1.0, 5.0), drag, child))
	assert_eq(card.drop_mark(), -1)
	watch_signals(card)
	card._drop_from(Vector2(1.0, 60.0), {BlockCard.DRAG_KEY: 4}, child)
	assert_signal_emitted_with_parameters(card, "drop_requested", [4, true])

func test_card_title_tooltip_warns_about_moving() -> void:
	var card: PanelContainer = _card(RoteiroBlock.Kind.ROTULO, 0)
	var found: bool = false
	for c: Node in card.find_children("*", "Label", true, false):
		if (c as Label).tooltip_text.begins_with("Arraste para reordenar"):
			found = true
	assert_true(found)

# --- paleta de objetos (a parte que não precisa do editor) ---

func _palette_with_root(markers: Array[String]) -> Array:
	var pal: VBoxContainer = ObjectPalette.new()
	add_child_autofree(pal)
	var root := Node2D.new()
	add_child_autofree(root)
	for m: String in markers:
		var mk := Marker2D.new()
		mk.name = m
		root.add_child(mk)
	return [pal, root]

func _inn() -> Node:
	var inn: Node = (load("res://world/prefabs/pousada.tscn") as PackedScene).instantiate()
	add_child_autofree(inn)
	return inn

func test_marker_for_creates_the_inn_marker_below_the_prefab() -> void:
	var made: Array = _palette_with_root([])
	var inn: Node = _inn()
	(inn as Node2D).position = Vector2(96.0, 96.0)
	var marker: Marker2D = made[0]._marker_for(made[1], &"pousada", inn)
	assert_not_null(marker)
	assert_eq(String(marker.name), "InnSpawn")
	assert_eq(marker.position, Vector2(96.0, 160.0))
	assert_eq(inn.get(&"spawn_name"), &"InnSpawn")
	marker.free()

func test_marker_for_reuses_an_existing_marker_with_the_exact_name() -> void:
	var made: Array = _palette_with_root(["InnSpawn"])
	var inn: Node = _inn()
	assert_null(made[0]._marker_for(made[1], &"pousada", inn), "já existe: nada novo")
	assert_eq(inn.get(&"spawn_name"), &"InnSpawn")

func test_marker_for_rewrites_spawn_name_when_the_name_is_taken_by_another_node() -> void:
	var made: Array = _palette_with_root([])
	var other := Node2D.new()
	other.name = "InnSpawn"
	made[1].add_child(other)
	var inn: Node = _inn()
	var marker: Marker2D = made[0]._marker_for(made[1], &"pousada", inn)
	assert_not_null(marker)
	assert_eq(String(marker.name), "InnSpawn2")
	assert_eq(inn.get(&"spawn_name"), &"InnSpawn2", "o spawn_name do prefab segue o marcador")
	marker.free()

func test_marker_for_ignores_prefabs_without_marker() -> void:
	var made: Array = _palette_with_root([])
	var chest: Node = (load("res://world/prefabs/bau.tscn") as PackedScene).instantiate()
	add_child_autofree(chest)
	assert_null(made[0]._marker_for(made[1], &"bau", chest))

# --- áudio (M19): cartões de música e som ---

func _audio_card(kind: int, ref: String) -> PanelContainer:
	var card: PanelContainer = BlockCard.new()
	var ctx: Dictionary = {
		&"ids": func(k: StringName) -> Array[String]: return ["cidade", "masmorra"] as Array[String] if k == &"music" else ["golpe"] as Array[String],
		&"display": func(_k: StringName, id: String) -> String: return id,
	}
	var b: RoteiroBlock = Logic.new_block(kind)
	b.ref = StringName(ref)
	card.setup(b, ctx)
	add_child_autofree(card)
	return card

func _options_of(card: PanelContainer) -> Array[String]:
	var ob: OptionButton = card.find_children("*", "OptionButton", true, false)[0] as OptionButton
	var out: Array[String] = []
	for i: int in ob.item_count:
		out.append(ob.get_item_text(i))
	return out

func test_music_card_lists_the_bank_ids_with_a_stop_entry() -> void:
	var card: PanelContainer = _audio_card(RoteiroBlock.Kind.MUSICA, "masmorra")
	assert_eq(_options_of(card), ["(nenhum)", "(parar a música)", "cidade", "masmorra"] as Array[String])
	var ob: OptionButton = card.find_children("*", "OptionButton", true, false)[0] as OptionButton
	assert_eq(ob.get_item_text(ob.selected), "masmorra")
	ob.item_selected.emit(1)
	assert_eq(card.block.ref, &"parar", "a entrada de parar grava a palavra")
	ob.item_selected.emit(2)
	assert_eq(card.block.ref, &"cidade")

func test_sound_card_lists_the_bank_sounds_and_flags_a_missing_one() -> void:
	var card: PanelContainer = _audio_card(RoteiroBlock.Kind.SOM, "sumiu")
	assert_eq(_options_of(card), ["(nenhum)", "golpe", "sumiu (não existe)"] as Array[String])

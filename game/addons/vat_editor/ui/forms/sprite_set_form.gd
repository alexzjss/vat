@tool
extends "res://addons/vat_editor/ui/forms/form_base.gd"

## Formulário de arte (M17), o editor de `SpriteSet`: folha de mapa (quadro, quadros por direção, fps) com a prévia das 4
## direções tocando; folha de batalha (quadro, virada, tabela de animações com a prévia de cada uma); a grade de retratos
## (expressão → imagem) com miniaturas. A faixa de validação repete as regras de `SpriteSet.validate()` e o aviso de retratos
## sem `neutro` (`logic/sprite_wizard.gd`, lendo só as propriedades, porque no editor os métodos do recurso não rodam).
##
## Onde mora: aba Banco, categoria "Arte" (todos os `SpriteSet` de `res://art/**`). Os formulários de herói, inimigo e falante
## abrem este com o botão "Editar arte…" do campo de arte.

const AnimPreview: GDScript = preload("res://addons/vat_editor/ui/widgets/anim_preview.gd")
const Wizard: GDScript = preload("res://addons/vat_editor/logic/sprite_wizard.gd")

const MAP_BOX: int = 112
const ANIM_BOX: int = 96
const THUMB: int = 72
const FACING_LABELS: Array[String] = ["Baixo", "Esquerda", "Direita", "Cima"]

var _map_previews: Array[Control] = []
var _map_info: Label
var _battle_info: Label
## Uma entrada por linha da tabela de animações: `{cell: [nome atual], preview: AnimPreview}`.
var _anim_rows: Array[Dictionary] = []

func _init() -> void:
	super._init()
	kind = &"sprites"
	kind_label = "Arte"

func _res_name() -> String:
	return res.resource_path.get_file().get_basename()

func _find_issues() -> Array[ValidationIssue]:
	return Wizard.issues(res, res.resource_path)

func rebuild() -> void:
	_map_previews.clear()
	_anim_rows.clear()
	_map_info = null
	_battle_info = null
	super.rebuild()
	_refresh_previews()

func _after_touch() -> void:
	_refresh_previews()

# --- campos próprios -------------------------------------------------------------------------------------------

func control_for(target: Resource, d: Dictionary) -> Control:
	match d["type"]:
		Forms.T_ANIMS:
			return _anims_control(target, d["prop"])
		Forms.T_PORTRAITS:
			return _portraits_control(target, d["prop"])
	return super.control_for(target, d)

## A prévia e o resumo vão logo depois do último campo de cada folha.
func _after_field(box: VBoxContainer, d: Dictionary) -> void:
	match d["prop"]:
		&"walk_fps":
			_map_info = _note("", COLOR_MUTED)
			box.add_child(_map_info)
			var row := HBoxContainer.new()
			for _i: int in FACING_LABELS.size():
				var p: Control = AnimPreview.new(MAP_BOX)
				_map_previews.append(p)
				row.add_child(p)
			box.add_child(row)
		&"battle_faces_right":
			_battle_info = _note("", COLOR_MUTED)
			box.add_child(_battle_info)

# --- prévias ---------------------------------------------------------------------------------------------------

func _refresh_previews() -> void:
	if res == null:
		return
	var map_sheet: Texture2D = res.get(&"map_sheet") as Texture2D
	var map_frame: Vector2i = res.get(&"map_frame")
	if _map_info != null:
		_map_info.text = _sheet_info(map_sheet, map_frame, "Sem folha de mapa: o jogo desenha a forma geométrica.")
	for i: int in _map_previews.size():
		_map_previews[i].call(&"show_row", map_sheet, map_frame, i, int(res.get(&"walk_frames")), float(res.get(&"walk_fps")), FACING_LABELS[i])
	var sheet: Texture2D = res.get(&"battle_sheet") as Texture2D
	var frame: Vector2i = res.get(&"battle_frame")
	if _battle_info != null:
		_battle_info.text = _sheet_info(sheet, frame, "Sem folha de batalha: o jogo desenha a forma geométrica.")
	var anims: Dictionary = res.get(&"anims")
	for r: Dictionary in _anim_rows:
		var key: StringName = (r["cell"] as Array)[0]
		if anims.has(key):
			var a: Vector3i = anims[key]
			(r["preview"] as Control).call(&"show_row", sheet, frame, a.x, a.y, float(a.z), String(key))

func _sheet_info(sheet: Texture2D, frame: Vector2i, none_text: String) -> String:
	if sheet == null:
		return none_text
	var size := Vector2i(sheet.get_size())
	if frame.x <= 0 or frame.y <= 0:
		return "Folha de %d×%d px." % [size.x, size.y]
	return "Folha de %d×%d px: %d coluna(s) × %d linha(s) de %d×%d px." % [size.x, size.y, size.x / frame.x, size.y / frame.y, frame.x, frame.y]

# --- animações de batalha --------------------------------------------------------------------------------------

func _anims_control(target: Resource, prop: StringName) -> Control:
	var anims: Dictionary = target.get(prop)
	var holder := VBoxContainer.new()
	_fill_anims(holder, target, anims)
	return holder

func _fill_anims(holder: VBoxContainer, target: Resource, anims: Dictionary) -> void:
	for c: Node in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	_anim_rows.clear()
	if anims.is_empty():
		holder.add_child(_note("(nenhuma animação)", COLOR_MUTED))
	for key: Variant in anims.keys():
		holder.add_child(_anim_row(holder, target, anims, key as StringName))
	var add := Button.new()
	add.text = "+ Adicionar animação"
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add.pressed.connect(func() -> void:
		var rows: int = Forms.sheet_rows(target.get(&"battle_sheet") as Texture2D, target.get(&"battle_frame"))
		var entry: Array = Forms.next_anim(anims, rows)
		anims[entry[0]] = entry[1]
		_fill_anims(holder, target, anims)
		touch())
	holder.add_child(add)

func _anim_row(holder: VBoxContainer, target: Resource, anims: Dictionary, key: StringName) -> Control:
	var cell: Array[StringName] = [key]
	var value: Vector3i = anims[key]
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_edit := LineEdit.new()
	name_edit.text = String(key)
	name_edit.custom_minimum_size.x = 110
	name_edit.tooltip_text = "Nome da animação (idle, attack, cast, hit, down e victory são as que o jogo usa)"
	flow.add_child(_captioned("Nome", name_edit))
	var specs: Array[Dictionary] = [
		{"cap": "Linha", "min": 0, "max": 64, "step": 1.0, "v": value.x},
		{"cap": "Quadros", "min": 1, "max": 64, "step": 1.0, "v": value.y},
		{"cap": "fps", "min": 1, "max": 60, "step": 1.0, "v": value.z},
	]
	var spins: Array[SpinBox] = []
	for s: Dictionary in specs:
		var spin := SpinBox.new()
		spin.min_value = s["min"]
		spin.max_value = s["max"]
		spin.step = s["step"]
		spin.value = s["v"]
		spin.custom_minimum_size.x = 76
		spins.append(spin)
		flow.add_child(_captioned(s["cap"], spin))
	var loops := Label.new()
	loops.text = "em laço" if SpriteSet.loops(key) else "toca uma vez"
	loops.custom_minimum_size.x = 90
	loops.add_theme_color_override("font_color", COLOR_MUTED)
	flow.add_child(_captioned(" ", loops))
	var preview: Control = AnimPreview.new(ANIM_BOX)
	flow.add_child(preview)
	var remove := Button.new()
	remove.text = "✕"
	remove.tooltip_text = "Remover a animação"
	flow.add_child(_captioned(" ", remove))
	_anim_rows.append({"cell": cell, "preview": preview})
	var apply_values: Callable = func(_v: float) -> void:
		anims[cell[0]] = Vector3i(int(spins[0].value), int(spins[1].value), int(spins[2].value))
		touch()
	for s: SpinBox in spins:
		s.value_changed.connect(apply_values)
	var rename: Callable = func(_t: Variant = "") -> void:
		var to := StringName(name_edit.text.strip_edges())
		if to == cell[0]:
			return
		if to != &"" and Forms.dict_rename(anims, cell[0], to):
			cell[0] = to
			loops.text = "em laço" if SpriteSet.loops(to) else "toca uma vez"
			touch()
		else:
			name_edit.text = String(cell[0])
	name_edit.text_submitted.connect(rename)
	name_edit.focus_exited.connect(rename)
	remove.pressed.connect(func() -> void:
		anims.erase(cell[0])
		_fill_anims(holder, target, anims)
		touch())
	return flow

func _captioned(caption: String, control: Control) -> Control:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = caption
	l.add_theme_color_override("font_color", COLOR_MUTED)
	box.add_child(l)
	box.add_child(control)
	return box

# --- retratos --------------------------------------------------------------------------------------------------

func _portraits_control(target: Resource, prop: StringName) -> Control:
	var portraits: Dictionary = target.get(prop)
	var holder := VBoxContainer.new()
	_fill_portraits(holder, portraits)
	return holder

func _fill_portraits(holder: VBoxContainer, portraits: Dictionary) -> void:
	for c: Node in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	if portraits.is_empty():
		holder.add_child(_note("(nenhum retrato; o diálogo usa a expressão 'neutro' quando a pedida falta)", COLOR_MUTED))
	var options: Array[Dictionary] = _choices(Forms.SRC_TEXTURE)
	for key: Variant in portraits.keys():
		holder.add_child(_portrait_row(holder, portraits, key as StringName, options))
	var add := Button.new()
	add.text = "+ Adicionar retrato"
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add.pressed.connect(func() -> void:
		portraits[Forms.next_expression(portraits)] = null
		_fill_portraits(holder, portraits)
		touch())
	holder.add_child(add)

func _portrait_row(holder: VBoxContainer, portraits: Dictionary, key: StringName, options: Array[Dictionary]) -> Control:
	var cell: Array[StringName] = [key]
	var row := HBoxContainer.new()
	var name_edit := LineEdit.new()
	name_edit.text = String(key)
	name_edit.custom_minimum_size.x = 110
	name_edit.tooltip_text = "Expressão (neutro é a que o diálogo usa quando falta a pedida)"
	row.add_child(name_edit)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(THUMB, THUMB)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	thumb.texture = portraits[key] as Texture2D
	var picker: Control = ResourcePicker.new()
	picker.call(&"setup", options, portraits[key])
	picker.connect(&"picked", func(v: Variant) -> void:
		portraits[cell[0]] = v
		thumb.texture = v as Texture2D
		touch())
	row.add_child(picker)
	row.add_child(thumb)
	var remove := Button.new()
	remove.text = "✕"
	remove.tooltip_text = "Remover o retrato"
	row.add_child(remove)
	var rename: Callable = func(_t: Variant = "") -> void:
		var to := StringName(name_edit.text.strip_edges())
		if to == cell[0]:
			return
		if to != &"" and Forms.dict_rename(portraits, cell[0], to):
			cell[0] = to
			touch()
		else:
			name_edit.text = String(cell[0])
	name_edit.text_submitted.connect(rename)
	name_edit.focus_exited.connect(rename)
	remove.pressed.connect(func() -> void:
		portraits.erase(cell[0])
		_fill_portraits(holder, portraits)
		touch())
	return row

## Conferência visual: quantas prévias de mapa estão tocando e quantas animações de batalha têm quadros.
func preview_report() -> String:
	var playing: int = 0
	for p: Control in _map_previews:
		if p.call(&"is_playing"):
			playing += 1
	var battle: int = 0
	for r: Dictionary in _anim_rows:
		if int((r["preview"] as Control).call(&"frame_count")) > 0:
			battle += 1
	return "mapa tocando %d/%d, batalha com quadros %d/%d" % [playing, _map_previews.size(), battle, _anim_rows.size()]

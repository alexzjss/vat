@tool
extends ConfirmationDialog

## "Criar a partir de uma imagem…" (M17), aba Banco > Arte: o usuário escolhe um PNG do projeto, `logic/sprite_wizard.gd` sugere
## como lê-lo (folha de mapa 32×48 com 3×4, folha de batalha 64×64 com até 6 linhas, retrato 96×96) e o tamanho do quadro
## pode ser ajustado à mão. **Criar** grava o `SpriteSet` novo (`<id>.tres`) na pasta escolhida e avisa quem abriu, que o mostra
## no formulário de arte. Nada é gravado antes de Criar.

const Wizard: GDScript = preload("res://addons/vat_editor/logic/sprite_wizard.gd")
const COLOR_ERROR: Color = Color(1.0, 0.45, 0.4)
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)
const THUMB: int = 128

signal created(path: String)

var _image_path: LineEdit
var _pick_button: Button
var _thumb: TextureRect
var _size_label: Label
var _kind: OptionButton
var _frame_x: SpinBox
var _frame_y: SpinBox
var _grid_label: Label
var _id: LineEdit
var _folder: LineEdit
var _error: Label
var _file_dialog: EditorFileDialog
var _size: Vector2i = Vector2i.ZERO
var _suggestions: Array[Dictionary] = []
var _updating: bool = false

func _init() -> void:
	title = "Criar arte a partir de uma imagem"
	ok_button_text = "Criar"
	cancel_button_text = "Cancelar"
	dialog_hide_on_ok = false
	min_size = Vector2i(560, 0)
	var box := VBoxContainer.new()
	add_child(box)
	box.add_child(_caption("Imagem (PNG dentro do projeto):"))
	var pick_row := HBoxContainer.new()
	box.add_child(pick_row)
	_image_path = LineEdit.new()
	_image_path.placeholder_text = "res://art/..."
	_image_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_image_path.text_submitted.connect(func(t: String) -> void: set_image(t.strip_edges()))
	pick_row.add_child(_image_path)
	_pick_button = Button.new()
	_pick_button.text = "Escolher…"
	_pick_button.pressed.connect(_on_pick)
	pick_row.add_child(_pick_button)
	var info := HBoxContainer.new()
	box.add_child(info)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(THUMB, THUMB)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	info.add_child(_thumb)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(side)
	_size_label = _caption("Nenhuma imagem escolhida.")
	side.add_child(_size_label)
	side.add_child(_caption("Ler como:"))
	_kind = OptionButton.new()
	_kind.item_selected.connect(func(_i: int) -> void: _apply_suggestion())
	side.add_child(_kind)
	var frame_row := HBoxContainer.new()
	side.add_child(frame_row)
	frame_row.add_child(_caption("Quadro:"))
	_frame_x = _spin()
	frame_row.add_child(_frame_x)
	frame_row.add_child(_caption("×"))
	_frame_y = _spin()
	frame_row.add_child(_frame_y)
	_grid_label = _caption("")
	_grid_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_grid_label)
	box.add_child(_caption("Id do SpriteSet novo (letras minúsculas, números e _):"))
	_id = LineEdit.new()
	box.add_child(_id)
	box.add_child(_caption("Pasta:"))
	_folder = LineEdit.new()
	box.add_child(_folder)
	_error = _caption("")
	_error.add_theme_color_override("font_color", COLOR_ERROR)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_error)
	confirmed.connect(_on_create)

func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _spin() -> SpinBox:
	var s := SpinBox.new()
	s.min_value = 1
	s.max_value = 4096
	s.step = 1
	s.value = 1
	s.custom_minimum_size.x = 80
	s.value_changed.connect(func(_v: float) -> void: _on_frame_edited())
	return s

## Abre limpo (sem imagem).
func open_fresh() -> void:
	_image_path.text = ""
	_size = Vector2i.ZERO
	_suggestions.clear()
	_kind.clear()
	_thumb.texture = null
	_size_label.text = "Nenhuma imagem escolhida."
	_grid_label.text = ""
	_id.text = ""
	_folder.text = "res://art"
	_error.text = ""
	popup_centered()

func _on_pick() -> void:
	if _file_dialog == null:
		var fd := EditorFileDialog.new()
		fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		fd.access = EditorFileDialog.ACCESS_RESOURCES
		fd.add_filter("*.png ; PNG")
		fd.file_selected.connect(func(path: String) -> void: set_image(path))
		add_child(fd)
		_file_dialog = fd
	_file_dialog.popup_centered_ratio(0.6)

## Escolhe a imagem: lê o tamanho, sugere como ler, e prepara id e pasta (o nome e a pasta da própria imagem).
func set_image(path: String) -> void:
	_error.text = ""
	if not path.begins_with("res://") or path.get_extension().to_lower() != "png":
		_error.text = "Escolha um PNG dentro do projeto (res://...)."
		return
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		_error.text = "Não foi possível ler %s." % path
		return
	_image_path.text = path
	_size = image.get_size()
	_thumb.texture = ImageTexture.create_from_image(image)
	_size_label.text = "Imagem de %d×%d px." % [_size.x, _size.y]
	_suggestions = Wizard.suggest(_size)
	_kind.clear()
	for i: int in _suggestions.size():
		var s: Dictionary = _suggestions[i]
		_kind.add_item("%s%s" % [Wizard.KIND_LABELS[s["kind"]], " (sugerido)" if i == 0 else ""])
	_kind.select(0)
	if _id.text == "":
		_id.text = path.get_file().get_basename().to_lower().replace(" ", "_").replace("-", "_")
	_folder.text = path.get_base_dir()
	_apply_suggestion()

func _apply_suggestion() -> void:
	if _suggestions.is_empty() or _kind.selected < 0:
		return
	var s: Dictionary = _suggestions[_kind.selected]
	_updating = true
	_frame_x.value = (s["frame"] as Vector2i).x
	_frame_y.value = (s["frame"] as Vector2i).y
	_updating = false
	_grid_label.text = str(s["note"])

## O quadro mudou à mão: refaz colunas e linhas da leitura escolhida.
func _on_frame_edited() -> void:
	if _updating or _suggestions.is_empty() or _kind.selected < 0:
		return
	var s: Dictionary = _suggestions[_kind.selected]
	var frame := Vector2i(int(_frame_x.value), int(_frame_y.value))
	s["frame"] = frame
	if s["kind"] != Wizard.KIND_PORTRAIT:
		s["cols"] = maxi(_size.x / frame.x, 1)
		s["rows"] = maxi(_size.y / frame.y, 1)
		s["exact"] = false
		s["note"] = "quadros de %d×%d: %d coluna(s) × %d linha(s)" % [frame.x, frame.y, s["cols"], s["rows"]]
		if _size.x % frame.x != 0 or _size.y % frame.y != 0:
			s["note"] += " (a imagem não é múltiplo deste quadro)"
	else:
		s["note"] = "retrato de %d×%d" % [frame.x, frame.y]
	_grid_label.text = str(s["note"])

func _on_create() -> void:
	if _suggestions.is_empty() or _kind.selected < 0:
		_error.text = "Escolha uma imagem primeiro."
		return
	var made: Dictionary = Wizard.create(_image_path.text, _suggestions[_kind.selected], _id.text.strip_edges(), _folder.text.strip_edges())
	if not made["ok"]:
		_error.text = made["error"]
		return
	var path: String = made["path"]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err: Error = ResourceSaver.save(made["resource"], path)
	if err != OK:
		_error.text = "Não foi possível salvar %s (erro %d)." % [path, err]
		return
	hide()
	created.emit(path)

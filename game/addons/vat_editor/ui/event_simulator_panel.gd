@tool
extends HSplitContainer

## Simulador de eventos (M17), sub-vista "Simular" da aba Roteiros. Escolhe-se o arquivo e o evento, as flags, os
## itens e o dinheiro de partida e as respostas das escolhas; "Rodar" executa o evento com o `EventRunner` real
## (`EventSimulator`) e mostra a transcrição e o estado final. Compila o texto do documento aberto no editor, se for o
## mesmo arquivo (mesmo sem salvar), senão o do disco. Nada vai para o jogo nem para o disco.

const Logic: GDScript = preload("res://addons/vat_editor/logic/roteiro_editor_logic.gd")
const Options: GDScript = preload("res://addons/vat_editor/logic/roteiro_options.gd")

signal status(text: String)

const COLOR_ERROR: Color = Color(1.0, 0.45, 0.4)
const COLOR_MUTED: Color = Color(0.65, 0.65, 0.7)
const COLOR_NOTE: Color = Color(0.55, 0.8, 1.0)
const COLOR_STATE: Color = Color(0.7, 1.0, 0.7)

## `Callable() -> ContentIndex` e `Callable(path: String) -> String` (o texto do arquivo), dados pelo painel.
var content: Callable
var text_provider: Callable

var file_option: OptionButton
var event_option: OptionButton
var flag_rows: VBoxContainer
var item_rows: VBoxContainer
var money_spin: SpinBox
var answers_edit: LineEdit
var result: Tree
var summary: Label
var _paths: Array[String] = []
var _loaded: bool = false

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(330, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	left.add_child(_label("Evento:"))
	file_option = OptionButton.new()
	file_option.item_selected.connect(func(_i: int) -> void: _fill_events())
	left.add_child(file_option)
	event_option = OptionButton.new()
	left.add_child(event_option)
	left.add_child(HSeparator.new())
	left.add_child(_label("Flags de partida (flag = valor):"))
	flag_rows = VBoxContainer.new()
	left.add_child(flag_rows)
	_button(left, "+ Flag", func() -> void: add_flag_row("", 1))
	left.add_child(HSeparator.new())
	left.add_child(_label("Itens de partida (substituem a mochila da fatia):"))
	item_rows = VBoxContainer.new()
	left.add_child(item_rows)
	_button(left, "+ Item", func() -> void: add_item_row("", 1))
	left.add_child(HSeparator.new())
	var money_row := HBoxContainer.new()
	left.add_child(money_row)
	money_row.add_child(_label("Moedas de partida:"))
	money_spin = SpinBox.new()
	money_spin.max_value = 999999
	money_spin.value = 0
	money_row.add_child(money_spin)
	left.add_child(_label("Respostas das escolhas (0, 1, 0... ou auto):"))
	answers_edit = LineEdit.new()
	answers_edit.text = "auto"
	answers_edit.placeholder_text = "auto"
	left.add_child(answers_edit)
	var run := _button(left, "Rodar", run_simulation)
	run.custom_minimum_size = Vector2(0, 32)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	summary = Label.new()
	summary.text = "Escolha um evento e use Rodar."
	right.add_child(summary)
	result = Tree.new()
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.hide_root = true
	result.select_mode = Tree.SELECT_ROW
	right.add_child(result)

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l

func _button(parent: Node, text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(handler)
	parent.add_child(b)
	return b

func _index() -> ContentIndex:
	return content.call() as ContentIndex if content.is_valid() else ContentIndex.from_resources([])

func _text_of(path: String) -> String:
	return str(text_provider.call(path)) if text_provider.is_valid() else FileAccess.get_file_as_string(path)

func ensure_loaded() -> void:
	if not _loaded:
		reload()

## Relê a lista de arquivos e eventos (mantém a escolha atual quando ainda existe).
func reload() -> void:
	_loaded = true
	var keep_file: String = _selected_path()
	var keep_event: String = _selected_event()
	_paths = RoteiroTools.find_roteiros("res://")
	file_option.clear()
	for p: String in _paths:
		file_option.add_item(p.get_file())
	if keep_file != "" and _paths.has(keep_file):
		file_option.selected = _paths.find(keep_file)
	_fill_events(keep_event)

func _fill_events(keep: String = "") -> void:
	event_option.clear()
	var path: String = _selected_path()
	if path == "":
		return
	var doc: RoteiroDoc = RoteiroDoc.parse(_text_of(path))["doc"]
	for e: RoteiroEvent in doc.events:
		event_option.add_item(e.id)
		if e.id == keep:
			event_option.selected = event_option.item_count - 1

func _selected_path() -> String:
	var i: int = file_option.selected if file_option != null else -1
	return _paths[i] if i >= 0 and i < _paths.size() else ""

func _selected_event() -> String:
	if event_option == null or event_option.selected < 0 or event_option.item_count == 0:
		return ""
	return event_option.get_item_text(event_option.selected)

## Escolhe o arquivo e o evento (para o painel e para a captura de tela). False se não existem.
func select(path: String, event_id: String) -> bool:
	ensure_loaded()
	var fi: int = _paths.find(path)
	if fi < 0:
		return false
	file_option.selected = fi
	_fill_events(event_id)
	return _selected_event() == event_id

func set_answers(text: String) -> void:
	answers_edit.text = text

# --- linhas das tabelas de partida ---

func add_flag_row(flag: String, value: int) -> void:
	var row := HBoxContainer.new()
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "flag"
	name_edit.text = flag
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_edit)
	row.add_child(_label("="))
	var spin := SpinBox.new()
	spin.min_value = -999999
	spin.max_value = 999999
	spin.value = value
	row.add_child(spin)
	_button(row, "✕", func() -> void:
		flag_rows.remove_child(row)
		row.queue_free())
	flag_rows.add_child(row)

func add_item_row(item_id: String, count: int) -> void:
	var row := HBoxContainer.new()
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array[String] = Options.items(_index())
	for id: String in ids:
		picker.add_item(Options.display(_index(), &"item", id))
		picker.set_item_metadata(picker.item_count - 1, id)
	if item_id != "" and ids.has(item_id):
		picker.selected = ids.find(item_id)
	row.add_child(picker)
	row.add_child(_label("x"))
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 999
	spin.value = count
	row.add_child(spin)
	_button(row, "✕", func() -> void:
		item_rows.remove_child(row)
		row.queue_free())
	item_rows.add_child(row)

## `{flag: valor}` das linhas de flags (sem nome = ignora).
func collect_flags() -> Dictionary:
	var out: Dictionary = {}
	for row: Node in flag_rows.get_children():
		var n: String = ((row.get_child(0) as LineEdit).text).strip_edges()
		if n != "":
			out[n] = int((row.get_child(2) as SpinBox).value)
	return out

func collect_items() -> Dictionary:
	var out: Dictionary = {}
	for row: Node in item_rows.get_children():
		var picker: OptionButton = row.get_child(0) as OptionButton
		if picker.selected >= 0:
			var id: String = str(picker.get_item_metadata(picker.selected))
			out[id] = int(out.get(id, 0)) + int((row.get_child(2) as SpinBox).value)
	return out

## "auto" (ou vazio) -> "auto"; "0, 1,0" -> [0, 1, 0]. Texto que não é número vira 0.
static func parse_answers(text: String) -> Variant:
	var t: String = text.strip_edges().to_lower()
	if t == "" or t == "auto":
		return "auto"
	var out: Array = []
	for part: String in t.replace(";", ",").replace(" ", ",").split(",", false):
		out.append(int(part) if part.is_valid_int() else 0)
	return out

# --- rodar ---

## Roda a simulação num Godot headless à parte (os scripts do jogo não são `@tool`, então o `EventRunner` não executa
## dentro do editor; o mesmo motivo do "Validar tudo") e mostra o resultado. Público para a captura de tela.
func run_simulation() -> void:
	var path: String = _selected_path()
	var event_id: String = _selected_event()
	result.clear()
	var root: TreeItem = result.create_item()
	if path == "" or event_id == "":
		summary.text = "Escolha um arquivo e um evento."
		return
	summary.text = "Simulando (pode levar alguns segundos)..."
	var in_file: String = ProjectSettings.globalize_path("user://vat_sim_in.json")
	var out_file: String = ProjectSettings.globalize_path("user://vat_sim_out.json")
	DirAccess.make_dir_recursive_absolute("user://")
	DirAccess.remove_absolute(out_file)
	var job: Dictionary = {"text": _text_of(path), "source": path.get_file(), "event": event_id, "setup": {
		"flags": collect_flags(), "items": collect_items(), "money": int(money_spin.value),
		"answers": parse_answers(answers_edit.text)}}
	var f: FileAccess = FileAccess.open(in_file, FileAccess.WRITE)
	if f == null:
		summary.text = "Não foi possível gravar o pedido de simulação."
		return
	f.store_string(JSON.stringify(job))
	f.close()
	var args: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"-s", "res://tools/roteiro/simulate.gd", "--", "--in=" + in_file, "--out=" + out_file])
	var worker := Thread.new()
	worker.start(func() -> int: return OS.execute(OS.get_executable_path(), args))
	while worker.is_alive():
		await get_tree().process_frame
	var code: int = int(worker.wait_to_finish())
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(out_file)) if FileAccess.file_exists(out_file) else null
	if code != 0 or not parsed is Dictionary:
		summary.text = "Falha ao rodar a simulação (código %d)." % code
		_row(root, summary.text, COLOR_ERROR)
		return
	var res: Dictionary = parsed
	if not bool(res["ok"]):
		var errors: Array = res["errors"]
		summary.text = "O roteiro tem %d erro(s): corrija no Editor antes de simular." % errors.size()
		for e: Variant in errors:
			_row(root, str(e), COLOR_ERROR)
		return
	_show(root, res["result"] as Dictionary, "%s > %s" % [path.get_file(), event_id])

func _show(root: TreeItem, sim: Dictionary, title: String) -> void:
	summary.text = "%s: terminou (%s)." % [title, sim["ended_reason"]]
	for line: String in sim["transcript"]:
		var is_note: bool = line.begins_with("batalha:") or line.begins_with("mover:") or line.begins_with("câmera:") \
				or line.begins_with("esperar:") or line.begins_with("escolha ") or line.begins_with("(") or line == "fim da demo"
		_row(root, line, COLOR_NOTE if is_note else Color.WHITE)
	_row(root, "", COLOR_MUTED)
	_row(root, "--- Estado final ---", COLOR_MUTED)
	var flags: Dictionary = sim["flags"]
	var visible_flags: PackedStringArray = PackedStringArray()
	var keys: Array = flags.keys()
	keys.sort()
	for k: Variant in keys:
		if not str(k).begins_with("_"):
			visible_flags.append("%s=%d" % [k, flags[k]])
	_row(root, "flags: %s" % (", ".join(visible_flags) if not visible_flags.is_empty() else "(nenhuma)"), COLOR_STATE)
	var items: Dictionary = sim["items"]
	var item_text: PackedStringArray = PackedStringArray()
	for k: Variant in items:
		item_text.append("%s x%d" % [k, items[k]])
	_row(root, "itens: %s" % (", ".join(item_text) if not item_text.is_empty() else "(nenhum)"), COLOR_STATE)
	_row(root, "moedas: %d" % int(sim["money"]), COLOR_STATE)
	_row(root, "grupo: %s" % ", ".join(PackedStringArray(sim["heroes"])), COLOR_STATE)
	status.emit(summary.text)

func _row(root: TreeItem, text: String, color: Color) -> void:
	var item: TreeItem = result.create_item(root)
	item.set_text(0, text)
	item.set_custom_color(0, color)

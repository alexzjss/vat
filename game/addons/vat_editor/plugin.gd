@tool
extends EditorPlugin

## Plugin do editor do VAT (M16). Só do editor: o jogo exportado não carrega nada daqui.
## Registra o importador de `.roteiro` e a aba "VAT" da tela principal (vat_panel.gd).
##
## Captura de tela para conferência: `godot --path game --editor -- --vat-capture=<arquivo.png> [--vat-tab=<aba>]`
## abre o editor, mostra a aba VAT (e a sub-aba pedida: Banco, Roteiros, Validar ou Testar), salva a imagem e sai.
## Na aba Roteiros: `--vat-sub=Lista|Editor|Simular` escolhe a sub-vista, `--vat-event=<id>` abre esse evento (no primeiro
## arquivo que o tem) e `--vat-answers=<0,1,..>` roda a simulação com essas respostas (no Simular).

const RoteiroImporter: GDScript = preload("res://addons/vat_editor/roteiro_importer.gd")
const VatPanel: GDScript = preload("res://addons/vat_editor/vat_panel.gd")
const CAPTURE_FLAG: String = "--vat-capture="
const TAB_FLAG: String = "--vat-tab="
const SUB_FLAG: String = "--vat-sub="
const EVENT_FLAG: String = "--vat-event="
const ANSWERS_FLAG: String = "--vat-answers="

var _roteiro_importer: EditorImportPlugin
var _panel: Control

func _enter_tree() -> void:
	_roteiro_importer = RoteiroImporter.new()
	add_import_plugin(_roteiro_importer)
	_panel = VatPanel.new()
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_panel.hide()
	_capture_if_asked.call_deferred()

func _exit_tree() -> void:
	if _roteiro_importer != null:
		remove_import_plugin(_roteiro_importer)
		_roteiro_importer = null
	if _panel != null:
		_panel.queue_free()
		_panel = null

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if _panel != null:
		_panel.visible = visible

func _get_plugin_name() -> String:
	return "VAT"

func _get_plugin_icon() -> Texture2D:
	var base: Control = EditorInterface.get_base_control()
	for icon: StringName in [&"Database", &"ResourcePreloader", &"Object"]:
		if base.has_theme_icon(icon, &"EditorIcons"):
			return base.get_theme_icon(icon, &"EditorIcons")
	return null

func _capture_if_asked() -> void:
	var out: String = ""
	var tab: String = "Banco"
	var sub: String = ""
	var event_id: String = ""
	var answers: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(CAPTURE_FLAG):
			out = a.trim_prefix(CAPTURE_FLAG)
		elif a.begins_with(TAB_FLAG):
			tab = a.trim_prefix(TAB_FLAG)
		elif a.begins_with(SUB_FLAG):
			sub = a.trim_prefix(SUB_FLAG)
		elif a.begins_with(EVENT_FLAG):
			event_id = a.trim_prefix(EVENT_FLAG)
		elif a.begins_with(ANSWERS_FLAG):
			answers = a.trim_prefix(ANSWERS_FLAG)
	if sub != "":
		tab = "Roteiros"
	if out == "":
		return
	EditorInterface.set_main_screen_editor("VAT")
	for i: int in 10:
		await get_tree().process_frame
	var tabs: TabContainer = _panel.tabs
	for i: int in tabs.get_tab_count():
		if tabs.get_tab_title(i) == tab:
			tabs.current_tab = i
	if tab == "Validar":
		await _panel.run_validation()
	if sub != "":
		await _panel.show_roteiro(sub, event_id, answers)
	for i: int in 90:
		await get_tree().process_frame
	var img: Image = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	var err: Error = img.save_png(out)
	print("vat-capture: %s (%d)" % [out, err])
	get_tree().quit(0 if err == OK else 1)

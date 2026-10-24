@tool
extends "res://addons/vat_editor/ui/forms/form_base.gd"

## Formulário de encontro (M17): a lista de inimigos (cada um escolhido no seletor), as flags (pode fugir, id único), a
## prévia em texto da formação e "Testar encontro", que pede ao painel para rodar o jogo com este encontro (os argumentos
## do Testar). O jogo lê do disco, então só testa com o encontro salvo.

signal play_requested(encounter_id: StringName)

var _summary: Label
var _play: Button

func _init() -> void:
	super._init()
	kind = &"encounters"
	kind_label = "Encontro"

func _build_extra(body: VBoxContainer) -> void:
	body.add_child(_section("Prévia da formação"))
	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_summary)
	_play = Button.new()
	_play.text = "Testar encontro"
	_play.tooltip_text = "Roda o jogo numa luta com este encontro (nível e arena da aba Testar)"
	_play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_play.pressed.connect(_on_play)
	body.add_child(_play)
	_refresh_summary()

func _after_touch() -> void:
	_refresh_summary()

func _refresh_summary() -> void:
	if _summary == null or res == null:
		return
	_summary.text = "\n".join(Forms.encounter_summary(res))

func _on_play() -> void:
	if res == null:
		return
	if is_dirty():
		status.emit("Salve o encontro antes de testar: o jogo lê do disco.")
		return
	play_requested.emit(res.get(&"id"))

@tool
extends "res://addons/vat_editor/ui/widgets/pct_dict_editor.gd"

## Resistência a estados (M17): estado -> % (+ resiste, − vulnerável, 100% ou mais imune). O nome vem do jogo.

func _init() -> void:
	super._init()
	absorbs = false
	help = Forms.STATUS_HELP

func choice_label(c: Dictionary) -> String:
	return "%s (%s)" % [EquipPage.status_name(c["id"]), c["id"]]

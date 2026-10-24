@tool
extends "res://addons/vat_editor/ui/widgets/pct_dict_editor.gd"

## Afinidades elementais (M17): elemento -> % (+ resiste, − fraqueza, 100% imune, acima de 100% absorve), com a cor do elemento.

func _init() -> void:
	super._init()
	absorbs = true
	help = Forms.AFFINITY_HELP

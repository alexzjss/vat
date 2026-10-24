@tool
extends "res://addons/vat_editor/ui/forms/form_base.gd"

## Formulário de falante (M17): id, nome e a arte (SpriteSet), com a prévia e o botão "Editar arte…". Os campos vêm de
## `Forms.fields(&"speakers")`.

func _init() -> void:
	super._init()
	kind = &"speakers"
	kind_label = "Falante"

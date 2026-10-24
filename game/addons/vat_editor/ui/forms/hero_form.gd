@tool
extends "res://addons/vat_editor/ui/forms/form_base.gd"

## Formulário de herói (M17): id, nome e atributos; elementos nativos (até 2), afinidades e resistência a estados; ataque
## básico, Limite, tipos de arma e equipamento inicial; a tabela de técnicas (nível × habilidade, nível 0 = só por evento);
## a arte com a prévia. Os campos vêm de `Forms.fields(&"heroes")`.

func _init() -> void:
	super._init()
	kind = &"heroes"
	kind_label = "Herói"

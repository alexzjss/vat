@tool
extends "res://addons/vat_editor/ui/forms/form_base.gd"

## Formulário de inimigo (M17): atributos, nível, XP, moedas e elementos nativos; afinidades, resistência e imunidade a
## estados; habilidades; a lista ORDENADA de regras de IA (condição, limiar, habilidade, alvo, chance, anúncio); a tabela de
## drops; as fases de chefe (cada uma com as suas regras), o contra-ataque, o papel e "protege o núcleo"; a arte com prévia.
## Os campos vêm de `Forms.fields(&"enemies")`.

func _init() -> void:
	super._init()
	kind = &"enemies"
	kind_label = "Inimigo"

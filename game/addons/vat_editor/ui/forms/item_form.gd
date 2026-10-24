@tool
extends "res://addons/vat_editor/ui/forms/form_base.gd"

## Formulário de item (M17): id e nome, alcance e alvo, item-chave, preço (vale em todas as lojas) e a lista de efeitos. Cada
## efeito mostra só as colunas que o jogo usa para o tipo escolhido (dano, cura, estado...). Os campos vêm de `Forms.fields(&"items")`.

func _init() -> void:
	super._init()
	kind = &"items"
	kind_label = "Item"

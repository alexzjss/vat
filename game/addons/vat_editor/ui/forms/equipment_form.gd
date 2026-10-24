@tool
extends "res://addons/vat_editor/ui/forms/form_base.gd"

## Formulário de equipamento (M17): id e nome, espaço, tipo de arma, quem veste (armadura e capacete), atributos somados,
## elemento e afinidades, a lista de passivos (imune, resiste, começa com) e o preço. Os campos vêm de `Forms.fields(&"equipment")`.

func _init() -> void:
	super._init()
	kind = &"equipment"
	kind_label = "Equipamento"

## Quem veste: só os heróis da mesma árvore de dados do equipamento (fatia ou teste).
func _choices(source: StringName) -> Array[Dictionary]:
	var all: Array[Dictionary] = super._choices(source)
	if source == Forms.SRC_HERO and res != null:
		return Forms.heroes_near(all, res.resource_path)
	return all

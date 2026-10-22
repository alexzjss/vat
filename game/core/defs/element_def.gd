class_name ElementDef
extends Resource

## Novos valores sempre no fim (os .tres guardam o indice).
enum Rule { NORMAL, BLOOD, RADIOACTIVE }

@export var id: StringName
## Nome proprio do elemento (ex.: "Kagutsuchi").
@export var display_name: String = ""
## Rotulo curto da UI (ex.: "Fogo").
@export var short_name: String = ""
@export var color: Color = Color.WHITE
## Falso so no Radioativo: nao participa de reacoes (M14).
@export var reacts: bool = true
## Regra especial; o codigo nunca compara ids de elemento, so `rule`.
@export var rule: Rule = Rule.NORMAL

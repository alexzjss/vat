class_name IfItemStep
extends EventStep

## Condição verdadeira (o grupo tem pelo menos `count` de `item` livres no inventário): segue para o próximo passo.
## Falsa (ou sem `item`): salta para o Label `else_label` (vazio = termina o evento).
@export var item: ItemDef
@export var count: int = 1
@export var else_label: StringName = &""

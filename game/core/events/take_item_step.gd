class_name TakeItemStep
extends EventStep

## Tira `count` de `item` do inventário (pode ser item-chave) e avisa com uma linha de sistema ("Entregou X!").
## Sem o bastante, não tira nada e não avisa (use IfItemStep antes).
@export var item: ItemDef
@export var count: int = 1

class_name TerrainDef
extends Resource

## Terreno ou clima de um mapa (M15). `element_mult` multiplica o dano elemental dos dois lados pelo id do elemento do golpe
## (ex.: chuva: Susanoo 1.2, Kagutsuchi 0.8); elemento ausente = 1.0. Aplicado depois da afinidade e antes do escudo do nucleo;
## absorcao, golpe neutro (sem elemento) e Radioativo (ignora afinidade) nao sao afetados.

@export var id: StringName
@export var display_name: String = ""
@export var element_mult: Dictionary[StringName, float] = {}

## Multiplicador do elemento (1.0 sem elemento ou sem entrada).
func mult_for(element: ElementDef) -> float:
	if element == null:
		return 1.0
	return float(element_mult.get(element.id, 1.0))

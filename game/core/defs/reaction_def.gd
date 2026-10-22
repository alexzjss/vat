class_name ReactionDef
extends Resource
## Reacao elemental (M14): um elemento sobre a marca de outro. O par (a, b) nao tem ordem.
## Campo vazio ou 0 nao faz nada; efeitos novos entram como campos novos. Todo numero e "valor de teste".

@export var id: StringName
@export var display_name: String = ""
@export var a: ElementDef
@export var b: ElementDef
## Nulo = consome as duas marcas; senao fica a marca desse elemento (precisa ser `a` ou `b`).
@export var keep: ElementDef
## Dano extra no golpe que disparou, em fracao do dano final dele (0.5 = +50%).
@export var bonus_pct: float = 0.0
@export var target_statuses: Array[StatusDef] = []
## Chance dos estados do alvo e da area (mesmo caminho de chance de estado de hoje).
@export var status_chance: float = 1.0
## Dano em area para os outros aliados do alvo dentro do raio, em fracao do dano final; neutro, sem marca.
@export var area_radius: float = 0.0
@export var area_pct: float = 0.0
@export var area_statuses: Array[StatusDef] = []
## Somados a barra de ATB, em fracao dela (-0.25 atrasa um quarto).
@export var target_atb: float = 0.0
@export var attacker_atb: float = 0.0
## Aplicados no atacante sem sorteio.
@export var attacker_statuses: Array[StatusDef] = []
## O atacante cura esta fracao do dano final; o grupo do atacante (ele incluido) cura esta fracao.
@export var heal_attacker_pct: float = 0.0
@export var heal_allies_pct: float = 0.0
## Estados removidos do alvo (ex.: quebrar Barreira).
@export var remove_target_statuses: Array[StatusDef] = []

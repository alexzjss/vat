class_name StatusDef
extends Resource

## Novos tipos sempre no fim: os .tres guardam o indice do enum.
enum Kind { POISON, SLEEP, PARALYSIS, HASTE, SLOW, BARRIER, ATTR_MOD, STOP, CONFUSION, SILENCE, BLIND, REGEN, BLEED, BURN, FREEZE, WET, PETRIFY, DOOM, TAUNT, BERSERK, REFLECT }

@export var id: StringName
@export var kind: Kind = Kind.POISON
## Turnos do afetado (ATB cheio). STOP nao usa: conta em `seconds`.
@export var duration: int = 1
## Queimadura: % do HP maximo por ATB cheio do afetado (pode derrubar). Sangramento: % do HP maximo por acao do afetado (nunca derruba); Veneno: dano por turno; Barreira: pontos; HASTE/SLOW: % de taxa; ATTR_MOD: soma no atributo (pode ser negativa).
@export var potency: int = 0
## Só ATTR_MOD.
@export var attr: StringName
@export var apply_contribution: int = 0
## Ids de status removidos ao aplicar este.
@export var cancels: Array[StringName] = []
## Estado negativo: removido por "remover todos os estados negativos" (Panaceia).
@export var negative: bool = false
## STOP, FREEZE, PETRIFY e DOOM: duracao em segundos de batalha (STOP/FREEZE: o ATB do afetado esta parado, entao turnos nunca contariam; PETRIFY/DOOM: contagem ate petrificar/cair).
@export var seconds: float = 0.0
## Veneno no mapa (M15): ativo num heroi vivo no fim da batalha, o estado segue com ele (HeroState.field_statuses) ate ser curado.
@export var persists: bool = false

class_name MoveActorStep
extends EventStep

## Anda em linha reta até um marcador. Os caminhos são relativos à raiz do mapa ("Player", "Npc", "Marker").
## `speed` 0 usa BalanceConfig.event_actor_speed.
@export var actor: NodePath = NodePath("")
@export var to_marker: NodePath = NodePath("")
@export var speed: float = 0.0

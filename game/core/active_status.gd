class_name ActiveStatus
extends RefCounted

var def: StatusDef
var remaining: int = 0
var source_id: StringName
var source_team: Combatant.Team = Combatant.Team.HERO
var barrier_left: int = 0
var applied_order: int = 0
## Só STOP: segundos de batalha restantes.
var time_left: float = 0.0

static func create(d: StatusDef, source: StringName, order: int) -> ActiveStatus:
	var s := ActiveStatus.new()
	s.def = d
	s.remaining = d.duration
	s.source_id = source
	s.applied_order = order
	if d.kind == StatusDef.Kind.BARRIER:
		s.barrier_left = d.potency
	if d.kind == StatusDef.Kind.STOP:
		s.time_left = d.seconds
	return s

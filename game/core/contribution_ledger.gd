class_name ContributionLedger
extends RefCounted

# { enemy_id: { actor_id: float } }
var _data: Dictionary = {}

func add(actor_id: StringName, enemy_id: StringName, points: float) -> void:
	if points <= 0.0:
		return
	if not _data.has(enemy_id):
		_data[enemy_id] = {}
	var per_actor: Dictionary = _data[enemy_id]
	per_actor[actor_id] = float(per_actor.get(actor_id, 0.0)) + points

func get_points(actor_id: StringName, enemy_id: StringName) -> float:
	if not _data.has(enemy_id):
		return 0.0
	var per_actor: Dictionary = _data[enemy_id]
	return float(per_actor.get(actor_id, 0.0))

func total_against(enemy_id: StringName) -> float:
	if not _data.has(enemy_id):
		return 0.0
	var per_actor: Dictionary = _data[enemy_id]
	var total: float = 0.0
	for v: float in per_actor.values():
		total += v
	return total

func entries() -> Dictionary:
	return _data

func add_ally_benefit(actor_id: StringName, ally: Combatant, points: float, living_enemies: Array[Combatant]) -> void:
	if points <= 0.0 or living_enemies.is_empty():
		return
	var weights: Dictionary = {}
	var weight_sum: float = 0.0
	for e: Combatant in living_enemies:
		var w: float = float(ally.damage_taken_from.get(e.id, 0))
		weights[e.id] = w
		weight_sum += w
	for e: Combatant in living_enemies:
		if weight_sum > 0.0:
			add(actor_id, e.id, points * float(weights[e.id]) / weight_sum)
		else:
			add(actor_id, e.id, points / float(living_enemies.size()))

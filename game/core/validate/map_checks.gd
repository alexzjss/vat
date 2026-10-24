class_name MapChecks
extends RefCounted

## Validadores de mapas (M16). Puros: recebem o resumo dos mapas (ver [member ContentBundle.maps]) e devolvem achados.

## O registro de mapas (cada `MapRegistry` entre os recursos): sem id vazio ou repetido, sem cena nula.
static func registry(resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for v: Variant in resources:
		var reg: MapRegistry = v as MapRegistry
		if reg == null:
			continue
		for m: String in reg.errors():
			out.append(ValidationIssue.error("registro de mapas: %s" % m, reg.resource_path))
	return out

## Toda ligação (MapLink, zona do mapa-múndi, saída, pousada, descanso) aponta para um mapa de `maps`
## e para um marcador que existe nele.
static func links(maps: Dictionary[StringName, Dictionary]) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	var ids: Array = maps.keys()
	ids.sort()
	for map_id: Variant in ids:
		var info: Dictionary = maps[map_id]
		var refs: Array = info.get("refs", [])
		for r: Variant in refs:
			var issue: ValidationIssue = _check_target(map_id, r as Dictionary, maps, info.get("path", ""))
			if issue != null:
				out.append(issue)
	return out

static func _check_target(from_map: StringName, ref: Dictionary, maps: Dictionary[StringName, Dictionary], path: String) -> ValidationIssue:
	var target: StringName = ref.get("target_map", &"")
	var spawn: StringName = ref.get("target_spawn", &"")
	var what: String = ref.get("what", "ligação")
	if not maps.has(target):
		return ValidationIssue.error("%s: %s -> mapa '%s' não existe no registro de mapas" % [from_map, what, target], path)
	var markers: Array = maps[target].get("markers", [])
	if not markers.has(spawn):
		return ValidationIssue.error("%s: %s -> marcador '%s' não existe em '%s'" % [from_map, what, spawn, target], path)
	return null

## O mapa e o marcador de cada perfil de início existem.
static func profiles(resources: Array, maps: Dictionary[StringName, Dictionary]) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for v: Variant in resources:
		var p: StartProfile = v as StartProfile
		if p == null:
			continue
		var ref: Dictionary = ContentBundle.map_ref("perfil de início", p.map, p.spawn)
		var issue: ValidationIssue = _check_target(&"perfil", ref, maps, p.resource_path)
		if issue != null:
			out.append(issue)
	return out

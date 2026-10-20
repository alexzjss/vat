class_name HeroState
extends RefCounted

var def: CharacterDef
var level: int = 1
var xp: int = 0
var allocated: Stats = Stats.make(0, 0, 0, 0)
var pending_points: int = 0
var equipment: Dictionary[StringName, EquipmentDef] = {}
var hp: int = 0
var ap: int = 0
## Barra de Limite (M8), de 0 a 1; persiste entre batalhas e vai no save.
var limit: float = 0.0

static func create(d: CharacterDef, cfg: BalanceConfig) -> HeroState:
	var h := HeroState.new()
	h.def = d
	for e: EquipmentDef in d.starting_equipment:
		if e != null and EquipmentRules.can_equip(d, e, e.slot):
			h.equipment[e.slot] = e
		else:
			push_error("equipamento inicial invalido em %s" % d.id)
	h.rest(cfg)
	return h

## HP e AP cheios (máximos via StatCalculator com nível, alocação e equipamento atuais);
## revive caídos. Único lugar da recuperação total: criação e descanso ([P-plano] 15).
func rest(cfg: BalanceConfig) -> void:
	var c := Combatant.from_hero(self, Vector2.ZERO)
	hp = StatCalculator.hp_max(c, cfg)
	ap = StatCalculator.ap_max(c, cfg)

## Total de pontos distribuídos nos atributos.
func allocated_total() -> int:
	return allocated.strength + allocated.speed + allocated.vitality + allocated.aura

## Reinício de atributos: devolve toda a alocação para `pending_points` e limita HP/AP aos novos máximos.
func reset_allocation(cfg: BalanceConfig) -> void:
	pending_points += allocated_total()
	allocated = Stats.make(0, 0, 0, 0)
	clamp_to_max(cfg)

## Limita HP/AP atuais aos máximos atuais (nunca aumenta; caído continua 0).
func clamp_to_max(cfg: BalanceConfig) -> void:
	var c := Combatant.from_hero(self, Vector2.ZERO)
	hp = mini(hp, StatCalculator.hp_max(c, cfg))
	ap = mini(ap, StatCalculator.ap_max(c, cfg))

## Estado completo para o save: o herói e identificado por def.id; equipamento por id.
func to_dict() -> Dictionary:
	var eq: Dictionary = {}
	for slot: StringName in equipment:
		eq[String(slot)] = String(equipment[slot].id)
	return {
		"id": String(def.id), "level": level, "xp": xp, "pending": pending_points,
		"allocated": {
			"strength": allocated.strength, "speed": allocated.speed,
			"vitality": allocated.vitality, "aura": allocated.aura,
		},
		"equipment": eq, "hp": hp, "ap": ap, "limit": limit,
	}

## Null se o id do heroi ou de algum equipamento for desconhecido, ou se o formato for invalido.
static func from_dict(d: Dictionary, registry: DefRegistry) -> HeroState:
	var cd: CharacterDef = registry.character(StringName(str(d.get("id", ""))))
	var al: Variant = d.get("allocated")
	var eq: Variant = d.get("equipment")
	if cd == null or not al is Dictionary or not eq is Dictionary:
		return null
	for key: String in ["level", "xp", "pending", "hp", "ap"]:
		if not (d.get(key) is float or d.get(key) is int):
			return null
	var h := HeroState.new()
	h.def = cd
	h.level = int(d["level"])
	h.xp = int(d["xp"])
	h.pending_points = int(d["pending"])
	h.hp = int(d["hp"])
	h.ap = int(d["ap"])
	if d.get("limit") is float or d.get("limit") is int:
		h.limit = clampf(float(d["limit"]), 0.0, 1.0)
	var a: Dictionary = al
	for attr: StringName in Stats.ATTRS:
		if not (a.get(String(attr)) is float or a.get(String(attr)) is int):
			return null
	h.allocated = Stats.make(int(a["strength"]), int(a["speed"]), int(a["vitality"]), int(a["aura"]))
	for slot: Variant in (eq as Dictionary):
		var e: EquipmentDef = registry.equipment(StringName(str((eq as Dictionary)[slot])))
		if e == null:
			return null
		h.equipment[StringName(str(slot))] = e
	return h

## Cópia dos valores mutáveis do herói (usada por retry de batalha e ponto de salvamento).
func snapshot() -> Dictionary:
	return {
		"hp": hp, "ap": ap, "limit": limit, "xp": xp, "level": level, "pending": pending_points,
		"allocated": Stats.make(allocated.strength, allocated.speed, allocated.vitality, allocated.aura),
		"equipment": equipment.duplicate(),
	}

## Restaura os valores de [method snapshot]; `allocated` ganha uma cópia nova.
func restore(snap: Dictionary) -> void:
	hp = snap["hp"]
	ap = snap["ap"]
	limit = float(snap.get("limit", 0.0))
	xp = snap["xp"]
	level = snap["level"]
	pending_points = snap["pending"]
	var a: Stats = snap["allocated"]
	allocated = Stats.make(a.strength, a.speed, a.vitality, a.aura)
	var eq: Dictionary[StringName, EquipmentDef] = snap["equipment"]
	equipment = eq.duplicate()

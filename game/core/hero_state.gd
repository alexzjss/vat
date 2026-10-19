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

## Limita HP/AP atuais aos máximos atuais (nunca aumenta; caído continua 0).
func clamp_to_max(cfg: BalanceConfig) -> void:
	var c := Combatant.from_hero(self, Vector2.ZERO)
	hp = mini(hp, StatCalculator.hp_max(c, cfg))
	ap = mini(ap, StatCalculator.ap_max(c, cfg))

## Cópia dos valores mutáveis do herói (usada por retry de batalha e ponto de salvamento).
func snapshot() -> Dictionary:
	return {
		"hp": hp, "ap": ap, "xp": xp, "level": level, "pending": pending_points,
		"allocated": Stats.make(allocated.strength, allocated.speed, allocated.vitality, allocated.aura),
		"equipment": equipment.duplicate(),
	}

## Restaura os valores de [method snapshot]; `allocated` ganha uma cópia nova.
func restore(snap: Dictionary) -> void:
	hp = snap["hp"]
	ap = snap["ap"]
	xp = snap["xp"]
	level = snap["level"]
	pending_points = snap["pending"]
	var a: Stats = snap["allocated"]
	allocated = Stats.make(a.strength, a.speed, a.vitality, a.aura)
	var eq: Dictionary[StringName, EquipmentDef] = snap["equipment"]
	equipment = eq.duplicate()

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
	var c := Combatant.from_hero(h, Vector2.ZERO)
	h.hp = StatCalculator.hp_max(c, cfg)
	h.ap = StatCalculator.ap_max(c, cfg)
	return h

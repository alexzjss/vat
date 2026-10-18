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
	h.rest(cfg)
	return h

## HP e AP cheios (máximos via StatCalculator com nível, alocação e equipamento atuais);
## revive caídos. Único lugar da recuperação total: criação e descanso ([P-plano] 15).
func rest(cfg: BalanceConfig) -> void:
	var c := Combatant.from_hero(self, Vector2.ZERO)
	hp = StatCalculator.hp_max(c, cfg)
	ap = StatCalculator.ap_max(c, cfg)

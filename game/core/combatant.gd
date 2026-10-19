class_name Combatant
extends RefCounted

enum Team { HERO, ENEMY }

var id: StringName
var team: Team = Team.HERO
var display_name: String = ""
var level: int = 1
var base: Stats
var allocated: Stats
var equipment_mods: Stats
var hp: int = 0
var ap: int = 0
var atb: float = 0.0
var position: Vector2 = Vector2.ZERO
var statuses: Array[ActiveStatus] = []
var abilities: Array[AbilityDef] = []
var basic_attack: AbilityDef
var hero_state: HeroState
var enemy_def: EnemyDef
## Heróis: guardados aqui (do equipamento). Inimigos: leem o EnemyDef ao vivo, para que
## ajustes no def depois de criar o combatente continuem valendo.
var _immunities: Array[StringName] = []
var _resistances: Dictionary[StringName, float] = {}
## inimigo: leitura viva de enemy_def; o setter é ignorado
var immunities: Array[StringName]:
	get:
		return enemy_def.immunities if enemy_def != null else _immunities
	set(v):
		_immunities = v
## inimigo: leitura viva de enemy_def; o setter é ignorado
var resistances: Dictionary[StringName, float]:
	get:
		return enemy_def.resistances if enemy_def != null else _resistances
	set(v):
		_resistances = v
var start_statuses: Array[StatusDef] = []
var damage_taken_from: Dictionary[StringName, int] = {}

func is_down() -> bool:
	return hp <= 0

static func from_hero(h: HeroState, pos: Vector2) -> Combatant:
	var c := Combatant.new()
	c.id = h.def.id
	c.team = Team.HERO
	c.display_name = h.def.display_name
	c.level = h.level
	c.base = h.def.base
	c.allocated = h.allocated
	var mods := Stats.make(0, 0, 0, 0)
	for e: EquipmentDef in h.equipment.values():
		if e != null and e.modifiers != null:
			mods = mods.plus(e.modifiers)
	c.equipment_mods = mods
	c.hp = h.hp
	c.ap = h.ap
	c.position = pos
	c.abilities = h.def.abilities.duplicate()
	c.basic_attack = h.def.basic_attack
	c.hero_state = h
	c.immunities = EquipmentRules.immunities(h.equipment)
	c.resistances = EquipmentRules.resistances(h.equipment)
	c.start_statuses = EquipmentRules.start_statuses(h.equipment)
	return c

static func from_enemy(d: EnemyDef, enemy_id: StringName, pos: Vector2, cfg: BalanceConfig) -> Combatant:
	var c := Combatant.new()
	c.id = enemy_id
	c.team = Team.ENEMY
	c.display_name = d.display_name
	c.level = d.level
	c.base = d.base
	c.allocated = Stats.make(0, 0, 0, 0)
	c.equipment_mods = Stats.make(0, 0, 0, 0)
	c.position = pos
	c.abilities = d.abilities.duplicate()
	for a: AbilityDef in d.abilities:
		if a.ap_cost == 0:
			c.basic_attack = a
			break
	c.enemy_def = d
	c.hp = StatCalculator.hp_max(c, cfg)
	c.ap = StatCalculator.ap_max(c, cfg)
	return c

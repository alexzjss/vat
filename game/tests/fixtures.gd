class_name Fixtures
extends RefCounted

static func cfg() -> BalanceConfig:
	var c := BalanceConfig.new()
	c.hp_per_vitality = 10
	c.hp_per_level = 5
	c.ap_per_aura = 5
	c.atb_base_rate = 0.2
	c.atb_rate_per_speed = 0.02
	c.atb_min_rate = 0.05
	c.dodge_per_speed = 0.005
	c.dodge_cap = 0.15
	c.dr_soft_cap = 20
	c.dr_factor = 0.5
	c.defense_per_vitality = 0.5
	c.xp_coef = 10
	c.control_value_per_turn = 10
	c.item_cast_time = 0.6
	c.item_impact_time = 0.3
	return c

static func hit(potency: float, shape: AbilityDef.Shape = AbilityDef.Shape.SINGLE) -> AbilityDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.DAMAGE
	e.scale = EffectDef.Scale.STRENGTH
	e.potency = potency
	e.dodgeable = false
	var a := AbilityDef.new()
	a.id = &"hit"
	a.display_name = "Golpe"
	a.ap_cost = 0
	a.shape = shape
	a.side = AbilityDef.Side.ENEMIES
	a.cast_time = 1.0
	a.impact_time = 0.5
	a.effects = [e]
	return a

static func status_def(kind: StatusDef.Kind, duration: int, potency: int = 0) -> StatusDef:
	var s := StatusDef.new()
	s.kind = kind
	s.id = StringName(StatusDef.Kind.keys()[kind].to_lower())
	s.duration = duration
	s.potency = potency
	s.apply_contribution = 0
	return s

static func hero_def(id: StringName, stats: Stats) -> CharacterDef:
	var d := CharacterDef.new()
	d.id = id
	d.display_name = String(id)
	d.base = stats
	d.basic_attack = hit(1.0)
	return d

static func enemy_def(id: StringName, stats: Stats, xp_base: int = 100) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = id
	d.display_name = String(id)
	d.level = 1
	d.base = stats
	d.xp_base = xp_base
	d.abilities = [hit(1.0)]
	return d

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
	c.dr_mode = BalanceConfig.DrMode.A
	c.hp_mode = BalanceConfig.HpMode.A
	c.ap_mode = BalanceConfig.ApMode.A
	c.atb_mode = BalanceConfig.AtbMode.A
	c.damage_mode = BalanceConfig.DamageMode.A
	c.variance_mode = BalanceConfig.VarianceMode.A
	c.dodge_mode = BalanceConfig.DodgeMode.A
	c.xp_mode = BalanceConfig.XpMode.A
	c.max_level = 0
	c.revive_mode = BalanceConfig.ReviveMode.A
	c.poison_mode = BalanceConfig.PoisonMode.A
	c.duration_mode = BalanceConfig.DurationMode.A
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

## Learnset de nivel 1 com `abilities` (ids repetidos ganham sufixo para valerem como tecnicas distintas).
static func set_abilities(d: CharacterDef, abilities: Array[AbilityDef]) -> void:
	var seen: Array[StringName] = []
	var out: Array[LearnEntry] = []
	for a: AbilityDef in abilities:
		if seen.has(a.id):
			a.id = StringName("%s_%d" % [a.id, seen.size()])
		seen.append(a.id)
		var e := LearnEntry.new()
		e.ability = a
		e.level = 1
		out.append(e)
	d.learnset = out

## Troca o learnset de um HeroState ja criado (aprende as de nivel 1).
static func give_abilities(h: HeroState, abilities: Array[AbilityDef]) -> void:
	set_abilities(h.def, abilities)
	h.learned = []
	h.learn_up_to(1)

static func enemy_def(id: StringName, stats: Stats, xp_base: int = 100) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = id
	d.display_name = String(id)
	d.level = 1
	d.base = stats
	d.xp_base = xp_base
	d.abilities = [hit(1.0)]
	return d

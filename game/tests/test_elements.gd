extends GutTest
## M13 Task 1: elementos e afinidade no nucleo. Defs em memoria; os dados de teste continuam neutros.
const ELEMENT_DIR: String = "res://data/elements"
const IDS: Array[StringName] = [&"kagutsuchi", &"susanoo", &"fuhaku", &"atlas", &"indra", &"tsukuyomi", &"amaterasu", &"shukketsu", &"radioativo"]

var b: BattleState
var h: Combatant
var x: Combatant
var fire: ElementDef
var water: ElementDef

func before_each() -> void:
	fire = _el(&"fire")
	water = _el(&"water")
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 0, 2, 4)), cfg), Vector2(0, 0))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1, 0, 2, 1)), &"x", Vector2(100, 0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x])

func _el(id: StringName, rule: ElementDef.Rule = ElementDef.Rule.NORMAL) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	e.rule = rule
	return e

func _ability(potency: float, element: ElementDef) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(potency)
	a.element = element
	return a

func _act(actor: Combatant, ab: AbilityDef, center: Combatant) -> PendingAction:
	var a := PendingAction.new()
	a.actor = actor
	a.ability = ab
	a.center = center
	a.center_pos = center.position
	return a

func _hit(actor: Combatant, ab: AbilityDef, target: Combatant) -> Dictionary:
	var r: ActionResult = ActionExecutor.apply(_act(actor, ab, target), b)
	return r.hits[0]

func _hp_loss(target: Combatant, hp_before: int) -> int:
	return hp_before - target.hp

# --- dados -----------------------------------------------------------------

func test_nine_element_defs_load() -> void:
	var seen: Array[StringName] = []
	for id: StringName in IDS:
		var e: ElementDef = load("%s/%s.tres" % [ELEMENT_DIR, id]) as ElementDef
		assert_not_null(e, str(id))
		if e == null:
			continue
		assert_eq(e.id, id)
		assert_false(seen.has(e.id), "id unico")
		seen.append(e.id)
		assert_ne(e.display_name, "")
		assert_ne(e.short_name, "")
		assert_eq(e.reacts, id != &"radioativo", "so o Radioativo nao reage: %s" % id)
	assert_eq(seen.size(), 9)

func test_element_rules_and_names() -> void:
	assert_eq((load(ELEMENT_DIR + "/shukketsu.tres") as ElementDef).rule, ElementDef.Rule.BLOOD)
	assert_eq((load(ELEMENT_DIR + "/radioativo.tres") as ElementDef).rule, ElementDef.Rule.RADIOACTIVE)
	assert_eq((load(ELEMENT_DIR + "/kagutsuchi.tres") as ElementDef).rule, ElementDef.Rule.NORMAL)
	assert_eq((load(ELEMENT_DIR + "/kagutsuchi.tres") as ElementDef).short_name, "Fogo")
	assert_eq((load(ELEMENT_DIR + "/susanoo.tres") as ElementDef).display_name, "Susanoo")

func test_element_colors_are_distinct() -> void:
	var colors: Array[Color] = []
	for id: StringName in IDS:
		var c: Color = (load("%s/%s.tres" % [ELEMENT_DIR, id]) as ElementDef).color
		assert_false(colors.has(c), "cor repetida em %s" % id)
		colors.append(c)

func test_native_validator_flags_more_than_two() -> void:
	var three: Array[ElementDef] = [fire, water, _el(&"wind")]
	assert_eq(ElementMath.native_errors(&"boss", three).size(), 1)
	var two: Array[ElementDef] = [fire, water]
	assert_eq(ElementMath.native_errors(&"boss", two).size(), 0)
	var dup: Array[ElementDef] = [fire, fire]
	assert_eq(ElementMath.native_errors(&"boss", dup).size(), 1)
	var empty: Array[ElementDef] = []
	assert_eq(ElementMath.native_errors(&"boss", empty).size(), 0)

func test_shipped_content_has_valid_natives() -> void:
	for root: String in ["res://data/test", "res://data/fatia"]:
		for sub: String in ["heroes", "enemies"]:
			var dir: DirAccess = DirAccess.open("%s/%s" % [root, sub])
			if dir == null:
				continue
			for f: String in dir.get_files():
				if not f.ends_with(".tres"):
					continue
				var r: Resource = load("%s/%s/%s" % [root, sub, f])
				var natives: Array[ElementDef] = []
				if r is CharacterDef:
					natives = (r as CharacterDef).elements
				elif r is EnemyDef:
					natives = (r as EnemyDef).elements
				assert_eq(ElementMath.native_errors(&"x", natives).size(), 0, f)

# --- elemento efetivo --------------------------------------------------------

func test_effective_element_ability_wins() -> void:
	var weapon: EquipmentDef = _weapon(water)
	h = _hero_with(weapon)
	var ab: AbilityDef = _ability(1.0, fire)
	assert_eq(ElementMath.element_of(ab, h), fire)

func test_effective_element_basic_uses_weapon() -> void:
	h = _hero_with(_weapon(water))
	assert_eq(ElementMath.element_of(h.basic_attack, h), water)

func test_effective_element_non_basic_without_element_is_neutral() -> void:
	h = _hero_with(_weapon(water))
	var ab: AbilityDef = _ability(1.0, null)
	assert_null(ElementMath.element_of(ab, h), "tecnica sem elemento ignora a arma")

func test_effective_element_ability_ignores_weapon_on_basic() -> void:
	h = _hero_with(_weapon(water))
	h.basic_attack.element = fire
	assert_eq(ElementMath.element_of(h.basic_attack, h), fire)

func test_effective_element_neutral_without_weapon_or_item() -> void:
	assert_null(ElementMath.element_of(h.basic_attack, h))
	assert_null(ElementMath.element_of(null, h), "item = neutro")

func test_enemy_counter_follows_ability_only() -> void:
	var ab: AbilityDef = _ability(1.0, fire)
	assert_eq(ElementMath.element_of(ab, x), fire)
	assert_null(ElementMath.element_of(_ability(1.0, null), x))

func test_basic_attack_with_weapon_deals_elemental_damage() -> void:
	h = _hero_with(_weapon(fire))
	b = BattleState.create(Fixtures.cfg(), ScriptedDice.new(), [h], [x])
	x.enemy_def.element_resist = {&"fire": -0.5}
	var hit: Dictionary = _hit(h, h.basic_attack, x)
	assert_eq(hit["element"], &"fire")
	assert_eq(hit["affinity"], ElementMath.Affinity.WEAK)
	assert_eq(hit["amount"], 13)

func _weapon(el: ElementDef) -> EquipmentDef:
	var w := EquipmentDef.new()
	w.id = &"sword"
	w.slot = &"weapon"
	w.modifiers = Stats.make(0, 0, 0, 0)
	w.element = el
	return w

func _hero_with(w: EquipmentDef) -> Combatant:
	var def: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 0, 2, 4))
	def.starting_equipment = [w]
	return Combatant.from_hero(HeroState.create(def, Fixtures.cfg()), Vector2(0, 0))

# --- afinidade ---------------------------------------------------------------

func test_neutral_data_matches_plain_damage() -> void:
	var plain: int = EffectMath.damage(Fixtures.hit(1.0).effects[0], 10, 2, 0, b.cfg, b.dice)
	var hp0: int = x.hp
	var hit: Dictionary = _hit(h, Fixtures.hit(1.0), x)
	assert_eq(hit["amount"], plain)
	assert_eq(_hp_loss(x, hp0), plain)
	assert_eq(hit["element"], &"")
	assert_eq(hit["affinity"], ElementMath.Affinity.NEUTRAL)
	# Elemento sem nativos nem afinidade: o mesmo numero.
	var hp1: int = x.hp
	var el_hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(el_hit["amount"], plain)
	assert_eq(_hp_loss(x, hp1), plain)
	assert_eq(el_hit["element"], &"fire")
	assert_eq(el_hit["affinity"], ElementMath.Affinity.NEUTRAL)

func test_weakness() -> void:
	x.enemy_def.element_resist = {&"fire": -0.5}
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["amount"], 13, "9 x 1.5 = 13 (floor)")
	assert_eq(hit["affinity"], ElementMath.Affinity.WEAK)

func test_resist() -> void:
	x.enemy_def.element_resist = {&"fire": 0.5}
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["amount"], 4, "9 x 0.5 = 4 (floor)")
	assert_eq(hit["affinity"], ElementMath.Affinity.RESIST)

func test_resist_keeps_minimum_of_one() -> void:
	x.enemy_def.element_resist = {&"fire": 0.95}
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["amount"], 1)
	assert_eq(hit["affinity"], ElementMath.Affinity.RESIST)

func test_other_element_resist_does_not_apply() -> void:
	x.enemy_def.element_resist = {&"water": 0.9}
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["amount"], 9)
	assert_eq(hit["affinity"], ElementMath.Affinity.NEUTRAL)

func test_immune_deals_zero_without_side_effects() -> void:
	x.enemy_def.element_resist = {&"fire": 1.0}
	var hp0: int = x.hp
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["amount"], 0)
	assert_eq(hit["kind"], EffectDef.Kind.DAMAGE)
	assert_eq(hit["affinity"], ElementMath.Affinity.IMMUNE)
	assert_eq(x.hp, hp0)
	assert_eq(b.ledger.get_points(&"a", &"x"), 0.0)

func test_immune_hero_gains_no_limit() -> void:
	var e_ab: AbilityDef = _ability(5.0, fire)
	h.element_resist = {&"fire": 1.0}
	var hit: Dictionary = _hit(x, e_ab, h)
	assert_eq(hit["affinity"], ElementMath.Affinity.IMMUNE)
	assert_eq(h.limit, 0.0)

func test_absorb_heals_up_to_max() -> void:
	x.enemy_def.element_resist = {&"fire": 1.5}
	var hp_max: int = StatCalculator.hp_max(x, b.cfg)
	x.hp = 5
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["kind"], EffectDef.Kind.HEAL)
	assert_eq(hit["affinity"], ElementMath.Affinity.ABSORB)
	assert_eq(hit["amount"], 4, "floor(9 x 0.5)")
	assert_eq(x.hp, 9)
	x.hp = hp_max - 1
	hit = _hit(h, _ability(1.0, fire), x)
	assert_eq(x.hp, hp_max, "nao passa do maximo")
	assert_eq(hit["amount"], 1, "so o que de fato curou")

func test_absorb_has_no_contribution() -> void:
	x.enemy_def.element_resist = {&"fire": 2.0}
	x.hp = 5
	_hit(h, _ability(1.0, fire), x)
	assert_eq(b.ledger.get_points(&"a", &"x"), 0.0)
	assert_gt(x.hp, 5)

func test_absorb_skips_barrier_and_limit() -> void:
	var bar: StatusDef = Fixtures.status_def(StatusDef.Kind.BARRIER, 3, 100)
	bar.id = &"barrier"
	var enemies_alive: Array[Combatant] = [x]
	b.statuses.apply_forced(h, bar)
	h.element_resist = {&"fire": 1.5}
	h.hp = 5
	var before: int = h.statuses[0].barrier_left
	var hit: Dictionary = _hit(x, _ability(5.0, fire), h)
	assert_eq(hit["affinity"], ElementMath.Affinity.ABSORB)
	assert_eq(h.statuses[0].barrier_left, before, "barreira intacta")
	assert_gt(h.hp, 5)
	assert_eq(h.limit, 0.0)
	assert_false(enemies_alive.is_empty())

func test_absorb_does_not_trigger_counter_hurt_check() -> void:
	# O hit de absorcao e HEAL: quem conta "sofreu dano" (contra-ataque) nao o enxerga como dano.
	x.enemy_def.element_resist = {&"fire": 1.5}
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_ne(hit["kind"], EffectDef.Kind.DAMAGE)

func test_hero_total_is_base_plus_equipment_applied_once() -> void:
	var def: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 0, 2, 4))
	def.element_resist = {&"fire": 0.2}
	var armor := EquipmentDef.new()
	armor.id = &"robe"
	armor.slot = &"armor"
	armor.modifiers = Stats.make(0, 0, 0, 0)
	armor.element_resist = {&"fire": 0.3, &"water": -0.5}
	def.starting_equipment = [armor]
	var hero: Combatant = Combatant.from_hero(HeroState.create(def, Fixtures.cfg()), Vector2.ZERO)
	assert_almost_eq(float(hero.element_resist[&"fire"]), 0.5, 0.0001)
	assert_almost_eq(float(hero.element_resist[&"water"]), -0.5, 0.0001)
	b = BattleState.create(Fixtures.cfg(), ScriptedDice.new(), [hero], [x])
	# Inimigo com Forca 10 usando potencia 1 contra Vitalidade 2: 9 -> floor(9 x 0.5) = 4 (nao 9 x 0.8 x 0.7).
	x.base = Stats.make(10, 0, 2, 1)
	var hit: Dictionary = _hit(x, _ability(1.0, fire), hero)
	assert_eq(hit["amount"], 4)
	assert_eq(hit["affinity"], ElementMath.Affinity.RESIST)

func test_equipment_can_cancel_base_weakness() -> void:
	var def: CharacterDef = Fixtures.hero_def(&"a", Stats.make(10, 0, 2, 4))
	def.element_resist = {&"fire": -0.5}
	var ring := EquipmentDef.new()
	ring.id = &"ring"
	ring.slot = &"accessory"
	ring.modifiers = Stats.make(0, 0, 0, 0)
	ring.element_resist = {&"fire": 0.5}
	def.starting_equipment = [ring]
	var hero: Combatant = Combatant.from_hero(HeroState.create(def, Fixtures.cfg()), Vector2.ZERO)
	assert_almost_eq(float(hero.element_resist[&"fire"]), 0.0, 0.0001)
	assert_eq(ElementMath.affinity_of(float(hero.element_resist[&"fire"])), ElementMath.Affinity.NEUTRAL)

func test_enemy_resist_is_read_live() -> void:
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["amount"], 9)
	x.enemy_def.element_resist = {&"fire": 0.5}
	hit = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["amount"], 4)

# --- mesmo elemento ----------------------------------------------------------

func test_same_element_bonus_with_one_native() -> void:
	h.elements = [fire]
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["amount"], 10, "floor(9 x 1.2)")
	assert_eq(hit["affinity"], ElementMath.Affinity.NEUTRAL)

func test_same_element_bonus_with_two_natives() -> void:
	h.elements = [fire, water]
	x.hp = 1000
	assert_eq(_hit(h, _ability(1.0, fire), x)["amount"], 10)
	assert_eq(_hit(h, _ability(1.0, water), x)["amount"], 10)
	assert_eq(_hit(h, _ability(1.0, _el(&"wind")), x)["amount"], 9, "nao nativo")

func test_same_element_bonus_comes_before_affinity() -> void:
	h.elements = [fire]
	x.enemy_def.element_resist = {&"fire": 0.5}
	# 9 -> floor(9 x 1.2) = 10 -> floor(10 x 0.5) = 5
	assert_eq(_hit(h, _ability(1.0, fire), x)["amount"], 5)

func test_same_element_bonus_needs_an_element() -> void:
	h.elements = [fire]
	assert_eq(_hit(h, Fixtures.hit(1.0), x)["amount"], 9)

func test_same_element_bonus_is_configurable() -> void:
	h.elements = [fire]
	b.cfg.same_element_bonus = 2.0
	assert_eq(_hit(h, _ability(1.0, fire), x)["amount"], 18)

func test_enemy_natives_get_the_bonus_too() -> void:
	x.enemy_def.elements = [fire]
	x.base = Stats.make(10, 0, 2, 1)
	var hero_hp: int = h.hp
	var hit: Dictionary = _hit(x, _ability(1.0, fire), h)
	assert_eq(hit["amount"], 10)
	assert_eq(hero_hp - h.hp, 10)

func test_default_bonus_value() -> void:
	assert_eq(BalanceConfig.new().same_element_bonus, 1.2)

# --- pipeline ----------------------------------------------------------------

func test_affinity_runs_before_barrier_and_core_shield() -> void:
	var bar: StatusDef = Fixtures.status_def(StatusDef.Kind.BARRIER, 3, 100)
	bar.id = &"barrier"
	b.statuses.apply_forced(x, bar)
	x.enemy_def.element_resist = {&"fire": 0.5}
	var hp0: int = x.hp
	var hit: Dictionary = _hit(h, _ability(1.0, fire), x)
	assert_eq(hit["amount"], 0, "a barreira absorveu o dano ja resistido")
	assert_eq(x.hp, hp0)
	assert_eq(x.statuses[0].barrier_left, 100 - 4)

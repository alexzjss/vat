extends GutTest

## Chefes no núcleo (M11): fases por HP, ataque anunciado, contra-ataque, núcleo/partes, PART_DOWN e a mira por posição.

var cfg: BalanceConfig
var _log: Array[String] = []

func before_each() -> void:
	cfg = Fixtures.cfg()
	_log = []

# --- montagem ---

func _rule(ab: AbilityDef, cond: AiRule.Condition = AiRule.Condition.ALWAYS, pick: AiRule.TargetPick = AiRule.TargetPick.LOWEST_HP_ENEMY, tele: bool = false) -> AiRule:
	var r := AiRule.new()
	r.ability = ab
	r.condition = cond
	r.pick = pick
	r.telegraph = tele
	return r

func _phase(below: float, rules: Array[AiRule], banner: String) -> BossPhase:
	var p := BossPhase.new()
	p.hp_below = below
	p.ai_rules = rules
	p.banner = banner
	return p

## Habilidade de técnica (AP > 0) com formato e lado à escolha.
func _tech(id: StringName, potency: float, ap: int, shape: AbilityDef.Shape = AbilityDef.Shape.SINGLE) -> AbilityDef:
	var a: AbilityDef = Fixtures.hit(potency, shape)
	a.id = id
	a.ap_cost = ap
	return a

func _revive_ability() -> AbilityDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.REVIVE
	e.scale = EffectDef.Scale.FIXED
	e.potency = 0.5
	var a := AbilityDef.new()
	a.id = &"reerguer"
	a.ap_cost = 2
	a.side = AbilityDef.Side.ALLIES
	a.effects = [e]
	return a

func _def(id: StringName, stats: Stats, role: EnemyDef.Role = EnemyDef.Role.NORMAL, xp: int = 100) -> EnemyDef:
	var d: EnemyDef = Fixtures.enemy_def(id, stats, xp)
	d.role = role
	return d

func _hero(id: StringName, spd: int = 10, potency: float = 1.0, pos: Vector2 = Vector2.ZERO) -> Combatant:
	var d: CharacterDef = Fixtures.hero_def(id, Stats.make(10, spd, 10, 1))
	d.basic_attack = Fixtures.hit(potency)
	return Combatant.from_hero(HeroState.create(d, cfg), pos)

func _foe(d: EnemyDef, pos: Vector2 = Vector2.ZERO) -> Combatant:
	return Combatant.from_enemy(d, d.id, pos, cfg)

func _ctrl(heroes: Array[Combatant], enemies: Array[Combatant], active: bool = false) -> BattleController:
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), heroes, enemies)
	var c := BattleController.new(b)
	c.active_mode = active
	c.action_started.connect(func(a: PendingAction) -> void: _log.append("%s:%s>%s" % ["counter" if a.is_counter else "started", a.actor.id, a.center.id]))
	c.charge_started.connect(func(x: Combatant, _a: PendingAction) -> void: _log.append("charge:%s" % x.id))
	c.phase_changed.connect(func(x: Combatant, banner: String) -> void: _log.append("phase:%s:%s" % [x.id, banner]))
	return c

## Todo turno de herói vira um ataque básico no alvo `target_id` (ou no primeiro candidato).
func _auto_heroes(ctrl: BattleController, target_id: StringName = &"") -> void:
	ctrl.hero_turn.connect(func(s: SelectionSession) -> void:
		s.choose_ability(s.actor.basic_attack)
		var pick: Combatant = null
		for c: Combatant in s.target_candidates():
			if pick == null or c.id == target_id:
				pick = c
		s.set_center(pick)
		ctrl.submit(s.confirm()))

func _until(ctrl: BattleController, cond: Callable, max_ticks: int = 2000) -> bool:
	for i: int in max_ticks:
		if cond.call():
			return true
		ctrl.tick(0.05)
	return cond.call()

func _count(prefix: String) -> int:
	var n: int = 0
	for l: String in _log:
		if l.begins_with(prefix):
			n += 1
	return n

## Executa `ability` de `actor` em `target` direto no ActionExecutor (sem controlador).
func _act(b: BattleState, actor: Combatant, ability: AbilityDef, target: Combatant) -> ActionResult:
	var pa := PendingAction.new()
	pa.actor = actor
	pa.ability = ability
	pa.center = target
	pa.center_pos = target.position
	return ActionExecutor.apply(pa, b)

# --- fases ---

func _phased_boss() -> Combatant:
	var d: EnemyDef = _def(&"boss", Stats.make(5, 1, 10, 5))
	d.phases = [_phase(0.66, [_rule(d.abilities[0])], "f2"), _phase(0.33, [_rule(d.abilities[0])], "f3")]
	return _foe(d)

func test_phase_changes_once_and_in_order() -> void:
	var boss: Combatant = _phased_boss()
	var ctrl: BattleController = _ctrl([_hero(&"h")], [boss])
	assert_eq(StatCalculator.hp_max(boss, cfg), 105)
	boss.hp = 80
	ctrl.tick(0.05)
	assert_eq(boss.phase_index, 0, "76% ainda nao cruzou 0,66")
	boss.hp = 60
	ctrl.tick(0.05)
	ctrl.tick(0.05)
	assert_eq(boss.phase_index, 1)
	assert_eq(_count("phase:"), 1, "uma vez so")
	boss.hp = 30
	ctrl.tick(0.05)
	assert_eq(boss.phase_index, 2)
	assert_eq(_log.filter(func(l: String) -> bool: return l.begins_with("phase:")), ["phase:boss:f2", "phase:boss:f3"])
	boss.hp = 5
	ctrl.tick(0.05)
	assert_eq(_count("phase:"), 2, "nao repete nem passa do fim")

func test_one_blow_crossing_two_phases_applies_the_last() -> void:
	var boss: Combatant = _phased_boss()
	var hero: Combatant = _hero(&"h", 10, 8.0)
	var ctrl: BattleController = _ctrl([hero], [boss])
	_auto_heroes(ctrl)
	assert_true(_until(ctrl, func() -> bool: return boss.hp < 105))
	assert_eq(boss.hp, 30, "80 - defesa 5 = 75 de dano")
	assert_eq(_log.filter(func(l: String) -> bool: return l.begins_with("phase:")), ["phase:boss:f3"])
	assert_eq(boss.phase_index, 2)

func test_phase_rules_replace_the_base_rules() -> void:
	var d: EnemyDef = _def(&"boss", Stats.make(5, 1, 10, 5))
	var base: AbilityDef = _tech(&"base", 1.0, 0)
	var strong: AbilityDef = _tech(&"strong", 2.0, 0)
	d.ai_rules = [_rule(base)]
	d.phases = [_phase(0.5, [_rule(strong)], "f2")]
	var boss: Combatant = _foe(d)
	assert_eq(boss.ai_rules()[0].ability, base)
	boss.phase_index = 1
	assert_eq(boss.ai_rules()[0].ability, strong)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [_hero(&"h")], [boss])
	assert_eq(EnemyAI.decide(boss, b).ability, strong)

func test_phase_rules_respect_silence() -> void:
	var d: EnemyDef = _def(&"boss", Stats.make(5, 1, 10, 5))
	var tech: AbilityDef = _tech(&"tech", 2.0, 3)
	d.phases = [_phase(0.5, [_rule(tech)], "f2")]
	var boss: Combatant = _foe(d)
	boss.phase_index = 1
	boss.statuses.append(ActiveStatus.create(Fixtures.status_def(StatusDef.Kind.SILENCE, 3), &"x", 1))
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [_hero(&"h")], [boss])
	assert_eq(EnemyAI.decide(boss, b).ability, boss.basic_attack, "Silencio pula a regra de tecnica da fase")

# --- ataque anunciado ---

func _telegraph_boss(ap_cost: int = 6) -> Combatant:
	var d: EnemyDef = _def(&"boss", Stats.make(5, 5, 100, 5))
	var big: AbilityDef = _tech(&"sismico", 1.0, ap_cost)
	d.abilities.append(big)
	d.ai_rules = [_rule(big, AiRule.Condition.ALWAYS, AiRule.TargetPick.LOWEST_HP_ENEMY, true)]
	return _foe(d)

func test_telegraph_spends_a_turn_and_executes_on_the_next() -> void:
	var boss: Combatant = _telegraph_boss()
	var hero: Combatant = _hero(&"h", 10, 0.1)
	var ctrl: BattleController = _ctrl([hero], [boss])
	_auto_heroes(ctrl)
	assert_true(_until(ctrl, func() -> bool: return _count("charge:") == 1))
	assert_true(boss.is_charging())
	assert_eq(boss.ap, 25, "o AP so e gasto na execucao")
	assert_eq(boss.atb, 0.0, "anunciar gasta o turno")
	assert_eq(_count("started:boss"), 0)
	assert_true(_until(ctrl, func() -> bool: return _count("started:boss") == 1))
	assert_false(boss.is_charging())
	assert_eq(boss.ap, 19)
	assert_true(_log.find("charge:boss") < _log.find("started:boss>h"))

func test_telegraph_revalidates_the_target_at_execution() -> void:
	var boss: Combatant = _telegraph_boss()
	var h1: Combatant = _hero(&"h1", 10, 0.1)
	var h2: Combatant = _hero(&"h2", 9, 0.1)
	h1.hp = 5
	var ctrl: BattleController = _ctrl([h1, h2], [boss])
	_auto_heroes(ctrl)
	assert_true(_until(ctrl, func() -> bool: return _count("charge:") == 1))
	assert_eq(boss.charging.center, h1, "mirou no de menor HP")
	h1.hp = 0
	assert_true(_until(ctrl, func() -> bool: return _count("started:boss") == 1))
	assert_true(_log.has("started:boss>h2"), "o alvo caido foi trocado pela regra do Targeting")

func test_boss_death_clears_the_charge() -> void:
	var boss: Combatant = _telegraph_boss()
	var hero: Combatant = _hero(&"h", 10, 0.1)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [hero], [boss])
	boss.charging = PendingAction.new()
	var kill: AbilityDef = _tech(&"kill", 1000.0, 0)
	_act(b, hero, kill, boss)
	assert_true(boss.is_down())
	assert_false(boss.is_charging())

func test_poison_death_clears_the_charge() -> void:
	var boss: Combatant = _telegraph_boss()
	var hero: Combatant = _hero(&"h", 1, 0.1)
	var ctrl: BattleController = _ctrl([hero], [boss])
	_auto_heroes(ctrl)
	assert_true(_until(ctrl, func() -> bool: return _count("charge:") == 1))
	var poison: StatusDef = Fixtures.status_def(StatusDef.Kind.POISON, 5, 1000)
	boss.statuses.append(ActiveStatus.create(poison, &"h", 1))
	assert_true(_until(ctrl, func() -> bool: return boss.is_down()))
	assert_false(boss.is_charging())

func test_stop_does_not_cancel_the_charge_it_waits() -> void:
	var boss: Combatant = _telegraph_boss()
	var hero: Combatant = _hero(&"h", 10, 0.1)
	var ctrl: BattleController = _ctrl([hero], [boss])
	_auto_heroes(ctrl)
	assert_true(_until(ctrl, func() -> bool: return _count("charge:") == 1))
	var stop: StatusDef = Fixtures.status_def(StatusDef.Kind.STOP, 1)
	stop.seconds = 4.0
	boss.statuses.append(ActiveStatus.create(stop, &"h", 1))
	for i: int in 40:
		ctrl.tick(0.05)
	assert_true(boss.is_charging(), "parado: a preparacao espera")
	assert_eq(_count("started:boss"), 0)
	assert_true(_until(ctrl, func() -> bool: return _count("started:boss") == 1, 4000))

# --- contra-ataque ---

func _counter_boss(chance: float = 1.0, only_basic: bool = false, spd: int = 1) -> Combatant:
	var d: EnemyDef = _def(&"boss", Stats.make(5, spd, 100, 5))
	d.counter = _tech(&"contra", 1.0, 0)
	d.counter_chance = chance
	d.counter_only_basic = only_basic
	return _foe(d)

func test_counter_fires_after_the_hero_action_and_keeps_the_atb() -> void:
	var boss: Combatant = _counter_boss()
	var hero: Combatant = _hero(&"h")
	var ctrl: BattleController = _ctrl([hero], [boss])
	_auto_heroes(ctrl)
	assert_true(_until(ctrl, func() -> bool: return _count("counter:") == 1))
	assert_eq(_log[0], "started:h>boss")
	assert_eq(_log[1], "counter:boss>h")
	var atb_before: float = boss.atb
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing == null))
	assert_gt(boss.atb, 0.0, "nao zera o ATB")
	assert_gte(boss.atb, atb_before)

func test_counter_respects_the_chance() -> void:
	var boss: Combatant = _counter_boss(0.0)
	var ctrl: BattleController = _ctrl([_hero(&"h")], [boss])
	_auto_heroes(ctrl)
	assert_true(_until(ctrl, func() -> bool: return _count("started:h") >= 3))
	assert_eq(_count("counter:"), 0)

func test_counter_only_basic_ignores_techniques() -> void:
	var boss: Combatant = _counter_boss(1.0, true)
	var hero: Combatant = _hero(&"h")
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [hero], [boss])
	var ctrl := BattleController.new(b)
	var tech: AbilityDef = _tech(&"tec", 1.0, 0)
	var pa := PendingAction.new()
	pa.actor = hero
	pa.ability = tech
	pa.center = boss
	pa.center_pos = boss.position
	assert_true(ctrl._counter_ready(pa).is_empty(), "tecnica nao provoca")
	pa.ability = hero.basic_attack
	assert_eq(ctrl._counter_ready(pa).size(), 1, "o ataque basico provoca")
	boss.enemy_def.counter_only_basic = false
	pa.ability = tech
	assert_eq(ctrl._counter_ready(pa).size(), 1, "sem a restricao qualquer ataque provoca")

func test_counter_is_blocked_by_stop_sleep_paralysis_and_charge() -> void:
	for kind: StatusDef.Kind in [StatusDef.Kind.STOP, StatusDef.Kind.SLEEP, StatusDef.Kind.PARALYSIS]:
		var boss: Combatant = _counter_boss()
		var st: StatusDef = Fixtures.status_def(kind, 3)
		st.seconds = 5.0
		boss.statuses.append(ActiveStatus.create(st, &"x", 1))
		var ctrl: BattleController = _ctrl([_hero(&"h")], [boss])
		var pa := PendingAction.new()
		pa.actor = ctrl.b.heroes[0]
		pa.ability = pa.actor.basic_attack
		assert_true(ctrl._counter_ready(pa).is_empty(), "bloqueado por %d" % kind)
	var charging: Combatant = _counter_boss()
	charging.charging = PendingAction.new()
	var c2: BattleController = _ctrl([_hero(&"h")], [charging])
	var p2 := PendingAction.new()
	p2.actor = c2.b.heroes[0]
	p2.ability = p2.actor.basic_attack
	assert_true(c2._counter_ready(p2).is_empty(), "preparando nao contra-ataca")

func test_counter_does_not_cascade() -> void:
	var boss: Combatant = _counter_boss()
	var ctrl: BattleController = _ctrl([_hero(&"h", 10, 1.0)], [boss])
	_auto_heroes(ctrl)
	assert_true(_until(ctrl, func() -> bool: return _count("counter:") == 1))
	assert_true(_until(ctrl, func() -> bool: return ctrl.executing == null))
	for i: int in 20:
		ctrl.tick(0.05)
	assert_eq(_count("started:h"), 1, "o heroi ainda nao agiu de novo")
	assert_eq(_count("counter:"), 1, "o contra-ataque nao gera contra-ataque")

func test_area_attack_makes_each_hurt_enemy_counter_once() -> void:
	var boss1: Combatant = _counter_boss()
	var d2: EnemyDef = _def(&"boss2", Stats.make(5, 1, 100, 5))
	d2.counter = _tech(&"contra", 1.0, 0)
	d2.counter_chance = 1.0
	var boss2: Combatant = _foe(d2)
	var hero: Combatant = _hero(&"h")
	var area: AbilityDef = _tech(&"area", 1.0, 0, AbilityDef.Shape.ALL)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [hero], [boss1, boss2])
	var ctrl := BattleController.new(b)
	ctrl.action_started.connect(func(a: PendingAction) -> void: _log.append("counter:%s" % a.actor.id if a.is_counter else "started:%s" % a.actor.id))
	var pa := PendingAction.new()
	pa.actor = hero
	pa.ability = area
	pa.center = boss1
	pa.center_pos = boss1.position
	ctrl.session = SelectionSession.new(hero, b)
	ctrl.submit(pa)
	for i: int in 200:
		ctrl.tick(0.05)
		if _count("counter:") >= 2 and ctrl.executing == null:
			break
	assert_eq(_count("counter:"), 2)
	assert_eq(_count("started:h"), 1)

func test_no_counter_when_the_blow_ends_the_battle() -> void:
	var boss: Combatant = _counter_boss()
	var hero: Combatant = _hero(&"h", 10, 50.0)
	boss.hp = 5
	var ctrl: BattleController = _ctrl([hero], [boss])
	_auto_heroes(ctrl)
	var ended: Array[int] = []
	ctrl.battle_ended.connect(func(o: BattleController.Outcome) -> void: ended.append(o))
	assert_true(_until(ctrl, func() -> bool: return ctrl.outcome != BattleController.Outcome.ONGOING))
	assert_eq(ctrl.outcome, BattleController.Outcome.VICTORY)
	assert_eq(_count("counter:"), 0, "o chefe caiu: sem contra-ataque")
	for i: int in 40:
		ctrl.tick(0.05)
	assert_eq(_count("counter:"), 0, "nem depois do fim")

func test_no_counter_when_the_counter_target_party_is_already_down() -> void:
	var boss: Combatant = _counter_boss()
	var hero: Combatant = _hero(&"h")
	var ctrl: BattleController = _ctrl([hero], [boss])
	_auto_heroes(ctrl)
	hero.hp = 1
	assert_true(_until(ctrl, func() -> bool: return _count("counter:") == 1))
	assert_true(_until(ctrl, func() -> bool: return ctrl.outcome != BattleController.Outcome.ONGOING))
	assert_eq(ctrl.outcome, BattleController.Outcome.DEFEAT)
	assert_eq(_count("counter:"), 1, "um unico contra-ataque, sem cascata")

func test_support_counter_hits_the_caller() -> void:
	var boss: Combatant = _counter_boss()
	var caller: Combatant = _hero(&"caller")
	var reserve: Combatant = _hero(&"reserva")
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [caller], [boss])
	var ctrl := BattleController.new(b)
	var pa := PendingAction.new()
	pa.actor = reserve
	pa.caller = caller
	pa.ability = reserve.basic_attack
	pa.center = boss
	pa.center_pos = boss.position
	var ready: Array[Combatant] = ctrl._counter_ready(pa)
	ctrl._collect_counters(pa, _act(b, reserve, reserve.basic_attack, boss), ready)
	assert_eq(ctrl._counters.size(), 1)
	assert_eq(ctrl._counters[0].center, caller, "o reserva temporario nao e alvo valido: quem o chamou")

# --- nucleo e partes ---

func _boss_group() -> Array[Combatant]:
	var core: Combatant = _foe(_def(&"core", Stats.make(5, 1, 10, 5), EnemyDef.Role.CORE, 400))
	var armd: EnemyDef = _def(&"arm", Stats.make(5, 1, 10, 5), EnemyDef.Role.PART, 150)
	armd.shields_core = true
	var arm: Combatant = _foe(armd)
	return [core, arm]

func test_shielded_core_takes_reduced_damage() -> void:
	var g: Array[Combatant] = _boss_group()
	var hero: Combatant = _hero(&"h", 10, 8.0)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [hero], g)
	assert_true(b.core_shielded(g[0]))
	var r: ActionResult = _act(b, hero, hero.basic_attack, g[0])
	assert_eq(r.hits[0]["amount"], 18, "(80 - 5) * 0,25")
	assert_true(r.hits[0]["shielded"])
	g[1].hp = 0
	assert_false(b.core_shielded(g[0]))
	var r2: ActionResult = _act(b, hero, hero.basic_attack, g[0])
	assert_eq(r2.hits[0]["amount"], 75, "sem a parte de pe, dano cheio")
	assert_false(r2.hits[0]["shielded"])

func test_part_without_shield_does_not_protect() -> void:
	var g: Array[Combatant] = _boss_group()
	g[1].enemy_def.shields_core = false
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [_hero(&"h")], g)
	assert_false(b.core_shielded(g[0]))

func test_victory_is_the_fall_of_the_core_and_parts_fall_with_it() -> void:
	var g: Array[Combatant] = _boss_group()
	var hero: Combatant = _hero(&"h", 10, 8.0)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [hero], g)
	var ctrl := BattleController.new(b)
	g[1].atb = 0.0
	# So a parte cair nao encerra a batalha.
	_act(b, hero, _tech(&"kill", 1000.0, 0), g[1])
	ctrl.tick(0.05)
	assert_eq(ctrl.outcome, BattleController.Outcome.ONGOING)
	# Reviver a parte e derrubar o nucleo: a parte cai junto.
	g[1].hp = 10
	g[1].atb = 0.0
	var r: ActionResult = _act(b, hero, _tech(&"kill", 1000.0, 0), g[0])
	assert_true(g[1].is_down(), "a parte de pe cai com o nucleo")
	assert_true(r.downed.has(g[1]))
	ctrl.tick(0.05)
	assert_eq(ctrl.outcome, BattleController.Outcome.VICTORY)

func test_parts_that_fall_with_the_core_give_xp() -> void:
	var g: Array[Combatant] = _boss_group()
	var hero: Combatant = _hero(&"h", 10, 8.0)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [hero], g)
	g[1].hp = 50
	_act(b, hero, hero.basic_attack, g[1])
	_act(b, hero, _tech(&"kill", 1000.0, 0), g[0])
	assert_true(g[1].is_down())
	var xp: Dictionary[StringName, int] = XpCalculator.combat_xp(b.ledger, b.enemies, b.heroes, false)
	assert_eq(xp[&"h"], 550, "nucleo 400 + parte 150")

func test_untouched_part_that_falls_with_the_core_still_gives_xp() -> void:
	var g: Array[Combatant] = _boss_group()
	var hero: Combatant = _hero(&"h", 10, 8.0)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [hero], g)
	_act(b, hero, _tech(&"kill", 1000.0, 0), g[0])
	assert_true(g[1].is_down())
	var xp: Dictionary[StringName, int] = XpCalculator.combat_xp(b.ledger, b.enemies, b.heroes, false)
	assert_eq(xp[&"h"], 550)

func test_two_cores_need_both_to_fall() -> void:
	var c1: Combatant = _foe(_def(&"c1", Stats.make(5, 1, 10, 5), EnemyDef.Role.CORE))
	var c2: Combatant = _foe(_def(&"c2", Stats.make(5, 1, 10, 5), EnemyDef.Role.CORE))
	var hero: Combatant = _hero(&"h")
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [hero], [c1, c2])
	_act(b, hero, _tech(&"kill", 1000.0, 0), c1)
	assert_false(b.enemies_defeated())
	_act(b, hero, _tech(&"kill", 1000.0, 0), c2)
	assert_true(b.enemies_defeated())

func test_encounter_without_core_ends_when_all_fall() -> void:
	var e1: Combatant = _foe(_def(&"e1", Stats.make(5, 1, 10, 5)))
	var e2: Combatant = _foe(_def(&"e2", Stats.make(5, 1, 10, 5)))
	var hero: Combatant = _hero(&"h")
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [hero], [e1, e2])
	_act(b, hero, _tech(&"kill", 1000.0, 0), e1)
	assert_false(b.enemies_defeated())
	_act(b, hero, _tech(&"kill", 1000.0, 0), e2)
	assert_true(b.enemies_defeated())

func test_battle_with_core_ends_in_victory_through_the_controller() -> void:
	var g: Array[Combatant] = _boss_group()
	g[1].hp = 0
	var hero: Combatant = _hero(&"h", 10, 80.0)
	var ctrl: BattleController = _ctrl([hero], g)
	_auto_heroes(ctrl)
	assert_true(_until(ctrl, func() -> bool: return ctrl.outcome != BattleController.Outcome.ONGOING))
	assert_eq(ctrl.outcome, BattleController.Outcome.VICTORY)

# --- PART_DOWN ---

func test_part_down_condition_revives_a_part() -> void:
	var core_def: EnemyDef = _def(&"core", Stats.make(5, 1, 10, 5), EnemyDef.Role.CORE)
	var rev: AbilityDef = _revive_ability()
	core_def.abilities.append(rev)
	core_def.ai_rules = [_rule(rev, AiRule.Condition.PART_DOWN)]
	var core: Combatant = _foe(core_def)
	var armd: EnemyDef = _def(&"arm", Stats.make(5, 1, 10, 5), EnemyDef.Role.PART)
	var arm: Combatant = _foe(armd)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [_hero(&"h")], [core, arm])
	# Parte de pe: a regra nao vale e o chefe cai no ataque basico.
	assert_eq(EnemyAI.decide(core, b).ability, core.basic_attack)
	arm.hp = 0
	var pa: PendingAction = EnemyAI.decide(core, b)
	assert_eq(pa.ability, rev)
	assert_eq(pa.center, arm)
	var r: ActionResult = ActionExecutor.apply(pa, b)
	assert_false(arm.is_down(), "a parte voltou")
	assert_gt(arm.hp, 0)
	assert_eq(r.hits[0]["kind"], EffectDef.Kind.REVIVE)

func test_part_down_ignores_a_fallen_normal_enemy() -> void:
	var core_def: EnemyDef = _def(&"core", Stats.make(5, 1, 10, 5), EnemyDef.Role.CORE)
	var rev: AbilityDef = _revive_ability()
	core_def.ai_rules = [_rule(rev, AiRule.Condition.PART_DOWN)]
	var core: Combatant = _foe(core_def)
	var other: Combatant = _foe(_def(&"other", Stats.make(5, 1, 10, 5)))
	other.hp = 0
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [_hero(&"h")], [core, other])
	assert_eq(EnemyAI.decide(core, b).ability, core.basic_attack)

# --- mira por posicao ---

func _aim_setup(pick: AiRule.TargetPick, ability: AbilityDef) -> Dictionary:
	var d: EnemyDef = _def(&"boss", Stats.make(5, 1, 10, 5))
	d.ai_rules = [_rule(ability, AiRule.Condition.ALWAYS, pick)]
	var boss: Combatant = _foe(d, Vector2(500, 0))
	var near: Combatant = _hero(&"near", 10, 1.0, Vector2(300, 0))
	var mid: Combatant = _hero(&"mid", 10, 1.0, Vector2(100, 400))
	var far: Combatant = _hero(&"far", 10, 1.0, Vector2(100, 440))
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [near, mid, far], [boss])
	return {"boss": boss, "b": b, "near": near, "mid": mid, "far": far}

func test_nearest_and_farthest() -> void:
	var s: Dictionary = _aim_setup(AiRule.TargetPick.NEAREST, Fixtures.hit(1.0))
	assert_eq(EnemyAI.decide(s["boss"], s["b"]).center, s["near"])
	s = _aim_setup(AiRule.TargetPick.FARTHEST, Fixtures.hit(1.0))
	assert_eq(EnemyAI.decide(s["boss"], s["b"]).center, s["far"], "mais longe do chefe")

func test_cluster_picks_the_center_that_catches_most() -> void:
	var circle: AbilityDef = _tech(&"area", 1.0, 0, AbilityDef.Shape.CIRCLE_TARGET)
	circle.radius = 80.0
	var s: Dictionary = _aim_setup(AiRule.TargetPick.CLUSTER, circle)
	var pa: PendingAction = EnemyAI.decide(s["boss"], s["b"])
	assert_eq(pa.center, s["mid"], "mid e far estao juntos (40 px); empate entre eles fica com o primeiro")

func test_cluster_tie_keeps_the_first() -> void:
	var circle: AbilityDef = _tech(&"area", 1.0, 0, AbilityDef.Shape.CIRCLE_TARGET)
	circle.radius = 10.0
	var s: Dictionary = _aim_setup(AiRule.TargetPick.CLUSTER, circle)
	assert_eq(EnemyAI.decide(s["boss"], s["b"]).center, s["near"], "todos pegam 1: o primeiro")

func test_telegraph_action_does_not_spend_ap_in_decide() -> void:
	var boss: Combatant = _telegraph_boss()
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [_hero(&"h")], [boss])
	var pa: PendingAction = EnemyAI.decide(boss, b)
	assert_true(pa.telegraph)
	assert_eq(boss.ap, 25)

func test_rule_chance_uses_the_dice() -> void:
	var d: EnemyDef = _def(&"boss", Stats.make(5, 1, 10, 5))
	var tech: AbilityDef = _tech(&"tech", 2.0, 3)
	var r: AiRule = _rule(tech)
	r.chance = 0.5
	d.ai_rules = [r]
	var boss: Combatant = _foe(d)
	var skip: BattleState = BattleState.create(cfg, ScriptedDice.new([0.9] as Array[float]), [_hero(&"h")], [boss])
	assert_eq(EnemyAI.decide(boss, skip).ability, boss.basic_attack, "sorteio acima da chance: regra pulada")
	var take: BattleState = BattleState.create(cfg, ScriptedDice.new([0.1] as Array[float]), [_hero(&"h")], [boss])
	assert_eq(EnemyAI.decide(boss, take).ability, tech)
	assert_eq(boss.ap, 22, "AP gasto so quando a regra vale")

func test_rule_without_chance_does_not_touch_the_dice() -> void:
	var d: EnemyDef = _def(&"boss", Stats.make(5, 1, 10, 5))
	var tech: AbilityDef = _tech(&"tech", 2.0, 3)
	d.ai_rules = [_rule(tech)]
	var boss: Combatant = _foe(d)
	var dice := ScriptedDice.new([0.99] as Array[float])
	var b: BattleState = BattleState.create(cfg, dice, [_hero(&"h")], [boss])
	assert_eq(EnemyAI.decide(boss, b).ability, tech, "chance 1: sempre")

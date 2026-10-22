class_name SimRunner
extends RefCounted

## Executa um cenario sem Node/cena: heroes -> BattleState -> BattleController -> tick ate o fim.

const HERO_X: float = 300.0
const HERO_Y0: float = 135.0
const HERO_DY: float = 150.0
const ENEMY_X: float = 900.0
const ENEMY_Y0: float = 200.0
const ENEMY_DY: float = 160.0

## Estado de uma execucao (campos em objeto: lambdas nao escrevem em locais).
class RunState:
	extends RefCounted
	var m: SimMetrics
	var s: SimScenario
	var ctrl: BattleController
	var elapsed: float = 0.0
	var actions: int = 0
	var hero_damage: int = 0
	var defeated: Dictionary[StringName, bool] = {}

	func on_hero_turn(session: SelectionSession) -> void:
		var a: PendingAction = SimPolicy.decide(session, ctrl.b, s.policy)
		if a == null:
			push_error("SimPolicy.decide devolveu null")
			return
		var aid: StringName = a.actor.id
		m.hero_actions[aid] = int(m.hero_actions.get(aid, 0)) + 1
		actions += 1
		if a.ability != null:
			m.ap_spent += a.ability.ap_cost
		ctrl.submit(a)

	func on_impact(a: PendingAction, r: ActionResult) -> void:
		if a.actor.team != Combatant.Team.HERO:
			return
		var dmg: int = 0
		for h: Dictionary in r.hits:
			var kind: int = h["kind"]
			if kind == EffectDef.Kind.DAMAGE:
				dmg += int(h["amount"])
			elif kind == EffectDef.Kind.APPLY_STATUS:
				var res: int = h["status_result"]
				if res == StatusSystem.ApplyResult.APPLIED or res == StatusSystem.ApplyResult.RENEWED:
					m.statuses_applied += 1
				else:
					m.statuses_resisted += 1
		hero_damage += dmg
		# Dano de itens nao entra na divisao basico/habilidade das metricas.
		if a.item != null:
			return
		if a.ability == a.actor.basic_attack:
			m.basic_actions += 1
			m.basic_damage += dmg
		else:
			m.ability_actions += 1
			m.ability_damage += dmg

	func scan_defeats() -> void:
		for e: Combatant in ctrl.b.enemies:
			if e.is_out() and not defeated.has(e.id):
				defeated[e.id] = true
				var did: StringName = e.enemy_def.id
				if not m.ttk_actions.has(did):
					m.ttk_actions[did] = []
					m.ttk_seconds[did] = []
				m.ttk_actions[did].append(actions)
				m.ttk_seconds[did].append(elapsed)

static func run(s: SimScenario) -> SimMetrics:
	var m := SimMetrics.new()
	m.label = s.label
	for i: int in s.runs:
		_run_one(s, m, i)
	_finish_xp(s, m)
	return m

static func make_hero(def: CharacterDef, s: SimScenario) -> HeroState:
	var h: HeroState = HeroState.create(def, s.cfg)
	if s.hero_level > 1:
		XpCalculator.grant(h, XpCalculator.xp_for_level(s.hero_level, s.cfg), s.cfg)
		_allocate(h, s.alloc_rule)
	if not s.equipment:
		h.equipment.clear()
	h.rest(s.cfg)
	return h

## Gasta os pontos pendentes do heroi conforme a regra (usado tambem pela rota da fatia).
static func allocate(h: HeroState, rule: StringName) -> void:
	_allocate(h, rule)

static func _allocate(h: HeroState, rule: StringName) -> void:
	if rule == &"main":
		var best: StringName = Stats.ATTRS[0]
		for attr: StringName in Stats.ATTRS:
			if h.def.base.get_attr(attr) > h.def.base.get_attr(best):
				best = attr
		XpCalculator.allocate(h, best, h.pending_points)
		return
	var i: int = 0
	while h.pending_points > 0:
		XpCalculator.allocate(h, Stats.ATTRS[i % Stats.ATTRS.size()], 1)
		i += 1

static func _run_one(s: SimScenario, m: SimMetrics, index: int) -> void:
	var heroes: Array[Combatant] = []
	for i: int in s.heroes.size():
		var hs: HeroState = make_hero(s.heroes[i], s)
		heroes.append(Combatant.from_hero(hs, Vector2(HERO_X, HERO_Y0 + HERO_DY * i)))
	var enemies: Array[Combatant] = []
	for i: int in s.enemies.size():
		var d: EnemyDef = s.enemies[i]
		enemies.append(Combatant.from_enemy(d, StringName("%s_%d" % [d.id, i]), Vector2(ENEMY_X, ENEMY_Y0 + ENEMY_DY * i), s.cfg))
	var b: BattleState = BattleState.create(s.cfg, Dice.new(s.base_seed + index), heroes, enemies)
	if s.no_reactions:
		b.reactions = ReactionTable.new()
	b.terrain = s.terrain
	for i: int in s.items.size():
		var n: int = s.item_counts[i] if i < s.item_counts.size() else 0
		if n > 0:
			b.inventory.add(s.items[i], n)
	var ctrl := BattleController.new(b)
	var st := RunState.new()
	st.m = m
	st.s = s
	st.ctrl = ctrl
	ctrl.hero_turn.connect(st.on_hero_turn)
	ctrl.action_impact.connect(st.on_impact)
	var step: float = maxf(s.cfg.sim_tick, 0.001)
	while ctrl.outcome == BattleController.Outcome.ONGOING and st.elapsed < s.cfg.sim_max_seconds:
		ctrl.tick(step)
		st.elapsed += step
		st.scan_defeats()
	m.runs += 1
	m.durations.append(st.elapsed)
	m.run_hero_damage.append(st.hero_damage)
	match ctrl.outcome:
		BattleController.Outcome.VICTORY:
			m.wins += 1
			var xp: Dictionary[StringName, int] = XpCalculator.combat_xp(b.ledger, enemies, heroes, false)
			for id: StringName in xp:
				m.xp_total[id] = int(m.xp_total.get(id, 0)) + xp[id]
		BattleController.Outcome.DEFEAT:
			m.losses += 1
		_:
			m.timeouts += 1
	var hp: float = 0.0
	var hp_max: float = 0.0
	for h: Combatant in heroes:
		hp += float(maxi(0, h.hp))
		hp_max += float(StatCalculator.hp_max(h, s.cfg))
	m.party_hp_pct.append(hp / maxf(1.0, hp_max))
	for h: Combatant in heroes:
		if not m.xp_total.has(h.id):
			m.xp_total[h.id] = 0
		if not m.hero_actions.has(h.id):
			m.hero_actions[h.id] = 0

static func _finish_xp(s: SimScenario, m: SimMetrics) -> void:
	var need: int = XpCalculator.xp_for_level(s.hero_level + 1, s.cfg) - XpCalculator.xp_for_level(s.hero_level, s.cfg)
	for id: StringName in m.xp_total:
		var per_win: float = float(m.xp_total[id]) / float(maxi(1, m.wins))
		m.battles_to_level[id] = ceili(float(need) / per_win) if per_win > 0.0 and need > 0 else -1

class_name RouteFatia
extends RefCounted

## Simula a rota planejada da fatia vertical (M12, Task 5), sem Node/cena: as lutas do caminho, a missao, os recrutas,
## a loja e a chegada ao chefe, com o `GameState` de verdade (XP por contribuicao, moeda e drops sorteados pelo Dice,
## compras pelo `ShopRules`). Os heroes lutam com a politica `smart`; entre as lutas o jogador cura com itens e, se o
## grupo ficar fraco, volta ao ponto de descanso (conta como "volta"). Todos os numeros de rota sao de teste.
##
## Perfis (a rota e a mesma; muda o que o jogador enfrenta):
##  - MINIMUM: so o obrigatorio (perseguidores, armadilha de batalha, chefe); sem baus, missao nem recrutas opcionais.
##  - TYPICAL: obrigatorio + errantes e patrulheiros do caminho + baus + a missao entregue (volta a cidade e 2a compra).
##  - FULL: tudo isso + os grupos ("dupla") das tres mapas.

enum Profile { MINIMUM, TYPICAL, FULL }

const TAG_REQUIRED: StringName = &"obrig"
const TAG_TYPICAL: StringName = &"tipico"
const TAG_OPTIONAL: StringName = &"opcional"

const ENC_DIR: String = "res://data/fatia/encounters/%s.tres"
const START_PROFILE: String = "res://data/fatia/start.tres"
const QUEST_EVENT: String = "res://data/fatia/events/morador_c.tres"
const BOSS_ENC: String = "chefe_fatia"
const RECRUIT_D: String = "res://data/test/heroes/teste_d.tres"
const SHOP: String = "res://data/fatia/shops/loja_cidade.tres"

## Prioridade de compra de equipamento (armas primeiro) e estoque alvo de Pocoes (valores de teste do simulador).
const BUY_PRIORITY: Array[String] = ["lamina_aco_f", "bastao_carvalho_f", "arco_longo_f", "armadura_pesada_f", "capacete_leve_f"]
const POTION_TARGET: int = 6
## Cura de campo: usa Pocao em quem estiver abaixo disso; volta ao descanso se a media do grupo cair abaixo do segundo valor.
const FIELD_HEAL_BELOW: float = 0.5
const REST_BELOW_AVG: float = 0.4

## Conteudo dos baus da rota (itens da fatia, por id) e quantidade.
const CHEST_ITEMS_D1: Array[Array] = [["eter_f", 2]]
const CHEST_ITEMS_D2: Array[Array] = [["pocao_f", 2], ["reviver_f", 1]]

class Step:
	extends RefCounted
	var kind: StringName
	var label: String = ""
	var encs: Array[String] = []
	var tag: StringName = TAG_REQUIRED
	var items: Array[Array] = []

	func _init(p_kind: StringName, p_label: String, p_encs: Array[String] = [], p_tag: StringName = TAG_REQUIRED, p_items: Array[Array] = []) -> void:
		kind = p_kind
		label = p_label
		encs = p_encs
		tag = p_tag
		items = p_items

## Resultado agregado de varias execucoes da rota.
class Aggregate:
	extends RefCounted
	var profile: Profile
	var runs: int = 0
	var reached_boss: int = 0
	var boss_wins: int = 0
	var failures: Dictionary[String, int] = {}
	var avg_levels: Array[float] = []
	var hero_levels: Dictionary[StringName, Array] = {}
	var money_at_boss: Array[float] = []
	## Moeda ganha em lutas e na missao, e gasta (loja e pousada), ate a chegada ao chefe.
	var money_earned: Array[float] = []
	var money_spent: Array[float] = []
	## Lutas, tempo de luta e voltas ao descanso ate a chegada ao chefe (o chefe fica em `boss_seconds`).
	var fight_seconds: Array[float] = []
	var boss_seconds: Array[float] = []
	var fights: Array[float] = []
	var rests: Array[float] = []
	var shop_visits: Array[Dictionary] = []
	## Por etapa (indice da lista de passos): somas para as medias da tabela da rota.
	var step_log: Array[Dictionary] = []
	var steps: Array[Step] = []

	func mean(arr: Array[float]) -> float:
		if arr.is_empty():
			return 0.0
		var t: float = 0.0
		for v: float in arr:
			t += v
		return t / float(arr.size())

	func min_of(arr: Array[float]) -> float:
		var m: float = INF
		for v: float in arr:
			m = minf(m, v)
		return m if m != INF else 0.0

	func max_of(arr: Array[float]) -> float:
		var m: float = -INF
		for v: float in arr:
			m = maxf(m, v)
		return m if m != -INF else 0.0

static func profile_name(p: Profile) -> String:
	match p:
		Profile.MINIMUM:
			return "minimo"
		Profile.TYPICAL:
			return "tipico"
	return "completo"

## A rota planejada (mapas na ordem do roteiro: cidade, estrada, andar 1, volta a cidade, andar 2, chefe).
static func steps() -> Array[Step]:
	var s: Array[Step] = []
	s.append(Step.new(&"recruit", "Cidade: recruta D"))
	s.append(Step.new(&"shop", "Cidade: loja (1a visita)", [], TAG_REQUIRED))
	s.append(Step.new(&"fight", "Estrada: errante", ["enc_f1"], TAG_TYPICAL))
	s.append(Step.new(&"fight", "Estrada: patrulheiro", ["enc_f2"], TAG_TYPICAL))
	s.append(Step.new(&"fight", "Estrada: perseguidor", ["enc_f12"], TAG_REQUIRED))
	s.append(Step.new(&"fight", "Estrada: dupla", ["enc_f1", "enc_f2"], TAG_OPTIONAL))
	s.append(Step.new(&"rest", "Andar 1: ponto de descanso da entrada"))
	s.append(Step.new(&"fight", "Andar 1: patrulheiro", ["enc_f1"], TAG_TYPICAL))
	s.append(Step.new(&"fight", "Andar 1: errante", ["enc_f2"], TAG_TYPICAL))
	s.append(Step.new(&"fight", "Andar 1: armadilha de batalha", ["enc_f12"], TAG_REQUIRED))
	s.append(Step.new(&"fight", "Andar 1: perseguidor", ["enc_f2"], TAG_REQUIRED))
	s.append(Step.new(&"fight", "Andar 1: dupla", ["enc_f1", "enc_f3"], TAG_OPTIONAL))
	s.append(Step.new(&"chest", "Andar 1: baus (Eter x2 e a Erva)", [], TAG_TYPICAL, CHEST_ITEMS_D1))
	s.append(Step.new(&"recruit_e", "Andar 1: recruta E (vai para a reserva)"))
	s.append(Step.new(&"quest", "Cidade: entrega da missao", [], TAG_TYPICAL))
	s.append(Step.new(&"shop", "Cidade: loja (2a visita)", [], TAG_TYPICAL))
	s.append(Step.new(&"inn", "Cidade: pousada", [], TAG_TYPICAL))
	s.append(Step.new(&"fight", "Andar 2: patrulheiro", ["enc_f3"], TAG_TYPICAL))
	s.append(Step.new(&"fight", "Andar 2: dupla", ["enc_f3", "enc_f4"], TAG_OPTIONAL))
	s.append(Step.new(&"fight", "Andar 2: errante", ["enc_f4"], TAG_TYPICAL))
	s.append(Step.new(&"chest", "Andar 2: baus (Pocao x2, Reviver)", [], TAG_TYPICAL, CHEST_ITEMS_D2))
	s.append(Step.new(&"rest", "Andar 2: ponto de descanso antes do chefe"))
	s.append(Step.new(&"fight", "Andar 2: perseguidor", ["enc_f34"], TAG_REQUIRED))
	s.append(Step.new(&"rest", "Andar 2: descanso antes de entrar na sala do chefe"))
	s.append(Step.new(&"boss", "Chefe", [BOSS_ENC], TAG_REQUIRED))
	return s

static func included(step: Step, profile: Profile) -> bool:
	match step.kind:
		&"recruit", &"recruit_e", &"rest", &"boss":
			return true
		&"shop":
			# A 1a visita sempre acontece (50 Moedas iniciais); a 2a so existe se a missao foi entregue.
			return step.tag == TAG_REQUIRED or profile != Profile.MINIMUM
	match profile:
		Profile.MINIMUM:
			return step.tag == TAG_REQUIRED
		Profile.TYPICAL:
			return step.tag != TAG_OPTIONAL
	return true

static func run(profile: Profile, runs: int, base_seed: int = 1) -> Aggregate:
	var agg := Aggregate.new()
	agg.profile = profile
	agg.steps = steps()
	for i: int in agg.steps.size():
		agg.step_log.append({"n": 0, "pre": 0.0, "lvl": 0.0, "money": 0.0, "secs": 0.0, "wins": 0, "losses": 0, "xp": 0.0})
	var cfg: BalanceConfig = SimScenario.config_chosen()
	for i: int in runs:
		_run_one(agg, cfg, base_seed + i)
	return agg

static func _enc(id: String) -> EncounterDef:
	return load(ENC_DIR % id) as EncounterDef

static func _enemies(encs: Array[String]) -> Array[EnemyDef]:
	var out: Array[EnemyDef] = []
	for id: String in encs:
		out.append_array(_enc(id).enemies)
	return out

static func _avg_level(state: GameState) -> float:
	var t: float = 0.0
	for h: HeroState in state.heroes:
		t += float(h.level)
	return t / float(maxi(1, state.heroes.size()))

static func _run_one(agg: Aggregate, cfg: BalanceConfig, seed_value: int) -> void:
	var p: StartProfile = load(START_PROFILE) as StartProfile
	var state: GameState = GameState.new_game(cfg, p.party, p.items, p.item_counts, Dice.new(seed_value), p.map, p.spawn,
			GameState.MAX_ACTIVE, p.equipment, p.equipment_counts, p.money)
	var ctx := RunCtx.new()
	ctx.start_money = state.money
	agg.runs += 1
	var failed: String = ""
	for i: int in agg.steps.size():
		var st: Step = agg.steps[i]
		if not included(st, agg.profile):
			continue
		var ok: bool = true
		var pre_level: float = _avg_level(state)
		match st.kind:
			&"recruit":
				state.recruit(load(RECRUIT_D) as CharacterDef)
				_allocate_all(state)
			&"recruit_e":
				_recruit_reserve(state)
			&"shop":
				var rec: Dictionary = _shop(state, ctx)
				agg.shop_visits.append(rec)
			&"chest":
				for pair: Array in st.items:
					state.inventory.add(load("res://data/fatia/items/%s.tres" % str(pair[0])) as ItemDef, int(pair[1]))
			&"quest":
				_deliver_quest(state, ctx)
			&"inn":
				if state.spend_money(cfg.inn_price):
					ctx.spent += cfg.inn_price
					state.rest_all()
			&"rest":
				state.rest_all()
			&"fight":
				ok = _fight_step(state, ctx, _enemies(st.encs), i, agg)
			&"boss":
				agg.reached_boss += 1
				agg.avg_levels.append(_avg_level(state))
				for h: HeroState in state.heroes:
					if not agg.hero_levels.has(h.def.id):
						agg.hero_levels[h.def.id] = []
					agg.hero_levels[h.def.id].append(float(h.level))
				agg.money_at_boss.append(float(state.money))
				agg.money_earned.append(float(ctx.earned))
				agg.money_spent.append(float(ctx.spent))
				agg.fight_seconds.append(ctx.seconds)
				agg.fights.append(float(ctx.fights))
				agg.rests.append(float(ctx.rests))
				ok = _fight_step(state, ctx, _enemies(st.encs), i, agg)
				if ok:
					agg.boss_wins += 1
				agg.boss_seconds.append(ctx.last_seconds)
		var lg: Dictionary = agg.step_log[i]
		lg["n"] = int(lg["n"]) + 1
		lg["pre"] = float(lg["pre"]) + pre_level
		lg["lvl"] = float(lg["lvl"]) + _avg_level(state)
		lg["money"] = float(lg["money"]) + float(state.money)
		if not ok:
			failed = st.label
			break
	if failed != "":
		agg.failures[failed] = int(agg.failures.get(failed, 0)) + 1

## Estado de uma execucao da rota que nao mora no GameState.
class RunCtx:
	extends RefCounted
	var start_money: int = 0
	var earned: int = 0
	var spent: int = 0
	var seconds: float = 0.0
	var fights: int = 0
	var rests: int = 0
	var last_seconds: float = 0.0

static func _allocate_all(state: GameState) -> void:
	for h: HeroState in state.roster():
		SimRunner.allocate(h, &"main")

static func _recruit_reserve(state: GameState) -> void:
	var e: CharacterDef = load("res://data/test/heroes/teste_e.tres") as CharacterDef
	state.recruit(e)
	_allocate_all(state)

## Luta uma batalha (politica smart); aplica XP, pontos, moeda e drops. false = derrota.
static func _fight_step(state: GameState, ctx: RunCtx, defs: Array[EnemyDef], step_index: int, agg: Aggregate) -> bool:
	var cfg: BalanceConfig = state.cfg
	var heroes: Array[Combatant] = []
	for i: int in state.heroes.size():
		heroes.append(Combatant.from_hero(state.heroes[i], Vector2(SimRunner.HERO_X, SimRunner.HERO_Y0 + SimRunner.HERO_DY * i)))
	var enemies: Array[Combatant] = []
	for i: int in defs.size():
		var d: EnemyDef = defs[i]
		enemies.append(Combatant.from_enemy(d, StringName("%s_%d" % [d.id, i]), Vector2(SimRunner.ENEMY_X, SimRunner.ENEMY_Y0 + SimRunner.ENEMY_DY * i), cfg))
	var b: BattleState = BattleState.create(cfg, state.dice, heroes, enemies)
	b.inventory = state.inventory
	var sc := SimScenario.new()
	sc.cfg = cfg
	sc.policy = &"smart"
	var m := SimMetrics.new()
	var ctrl := BattleController.new(b)
	var rs := SimRunner.RunState.new()
	rs.m = m
	rs.s = sc
	rs.ctrl = ctrl
	ctrl.hero_turn.connect(rs.on_hero_turn)
	var step: float = maxf(cfg.sim_tick, 0.001)
	while ctrl.outcome == BattleController.Outcome.ONGOING and rs.elapsed < cfg.sim_max_seconds:
		ctrl.tick(step)
		rs.elapsed += step
	ctrl.hero_turn.disconnect(rs.on_hero_turn)
	ctx.fights += 1
	ctx.seconds += rs.elapsed
	ctx.last_seconds = rs.elapsed
	var lg: Dictionary = agg.step_log[step_index]
	lg["secs"] = float(lg["secs"]) + rs.elapsed
	for c: Combatant in heroes:
		c.hero_state.hp = c.hp
		c.hero_state.clamp_to_max(cfg)
		c.hero_state.ap = c.ap
		c.hero_state.limit = c.limit
	if ctrl.outcome != BattleController.Outcome.VICTORY:
		lg["losses"] = int(lg["losses"]) + 1
		return false
	lg["wins"] = int(lg["wins"]) + 1
	var xp: Dictionary[StringName, int] = XpCalculator.combat_xp(b.ledger, enemies, heroes, false)
	for c: Combatant in heroes:
		var gained: int = xp.get(c.id, 0)
		lg["xp"] = float(lg["xp"]) + float(gained)
		XpCalculator.grant(c.hero_state, gained, cfg)
	var rewards: BattleRewards = BattleRewards.roll(enemies, state.dice)
	rewards.apply(state)
	ctx.earned += rewards.money
	_allocate_all(state)
	_field_care(state, ctx)
	return true

## Cura de campo: Pocao em quem esta abaixo de 50%, Reviver nos caidos; sem recursos e com o grupo fraco, volta ao descanso.
static func _field_care(state: GameState, ctx: RunCtx) -> void:
	var heal: ItemDef = _field_item(state, EffectDef.Kind.HEAL)
	var revive: ItemDef = _field_item(state, EffectDef.Kind.REVIVE)
	for h: HeroState in state.heroes:
		if h.hp <= 0 and revive != null:
			FieldActions.use_item(state, revive, h)
			revive = _field_item(state, EffectDef.Kind.REVIVE)
	for h: HeroState in state.heroes:
		while heal != null and h.hp > 0 and _hp_pct(h, state.cfg) < FIELD_HEAL_BELOW:
			if not FieldActions.use_item(state, heal, h):
				break
			heal = _field_item(state, EffectDef.Kind.HEAL)
	var total: float = 0.0
	var downed: bool = false
	for h: HeroState in state.heroes:
		total += _hp_pct(h, state.cfg)
		downed = downed or h.hp <= 0
	if downed or total / float(maxi(1, state.heroes.size())) < REST_BELOW_AVG:
		state.rest_all()
		ctx.rests += 1

static func _hp_pct(h: HeroState, cfg: BalanceConfig) -> float:
	return float(h.hp) / float(maxi(1, StatCalculator.hp_max(Combatant.from_hero(h, Vector2.ZERO), cfg)))

static func _field_item(state: GameState, kind: EffectDef.Kind) -> ItemDef:
	for it: ItemDef in state.inventory.listing():
		if state.inventory.available(it.id) <= 0 or not FieldActions.is_field_usable(it.effects):
			continue
		for e: EffectDef in it.effects:
			if e.kind == kind:
				return it
	return null

## Compra por prioridade (equipamento que algum heroi ativo aproveita) e completa o estoque de Pocoes. Devolve o resumo.
static func _shop(state: GameState, ctx: RunCtx) -> Dictionary:
	var shop: ShopDef = load(SHOP) as ShopDef
	var before: int = state.money
	var bought: Array[String] = []
	for id: String in BUY_PRIORITY:
		var e: EquipmentDef = _shop_equipment(shop, id)
		if e == null or e.price > state.money or _best_taker(state, e) == null:
			continue
		if ShopRules.buy(state, e, 1):
			_equip_best(state, e)
			bought.append(e.display_name)
	for it: ItemDef in shop.items:
		if it.id != &"pocao_f":
			continue
		var want: int = POTION_TARGET - state.inventory.count(it.id)
		var n: int = mini(want, ShopRules.max_buy(state, it))
		if n > 0 and ShopRules.buy(state, it, n):
			bought.append("Poção x%d" % n)
	ctx.spent += before - state.money
	return {"money_before": before, "money_after": state.money, "bought": bought}

static func _shop_equipment(shop: ShopDef, id: String) -> EquipmentDef:
	for e: EquipmentDef in shop.equipment:
		if String(e.id) == id:
			return e
	return null

static func _mod_sum(e: EquipmentDef) -> int:
	if e == null or e.modifiers == null:
		return 0
	return e.modifiers.strength + e.modifiers.speed + e.modifiers.vitality + e.modifiers.aura

## Primeiro heroi ativo que pode vestir `e` e ganha com ela (soma dos modificadores maior que a da peca atual).
static func _best_taker(state: GameState, e: EquipmentDef) -> HeroState:
	for h: HeroState in state.heroes:
		if EquipmentRules.can_equip(h.def, e, e.slot) and _mod_sum(e) > _mod_sum(h.equipment.get(e.slot)):
			return h
	return null

static func _equip_best(state: GameState, e: EquipmentDef) -> void:
	var h: HeroState = _best_taker(state, e)
	if h == null:
		return
	var taken: EquipmentDef = state.bag.take(e.id)
	if taken == null:
		return
	var old: EquipmentDef = h.equipment.get(e.slot)
	h.equipment[e.slot] = taken
	if old != null:
		state.bag.put(old)
	h.clamp_to_max(state.cfg)

## Recompensa da missao lida do proprio evento (morador_c): Moedas, equipamento e XP narrativa ACTIVE.
static func quest_reward() -> Dictionary:
	var out: Dictionary = {"money": 0, "xp": 0, "equipment": null, "count": 0, "include_downed": false}
	var ev: EventScript = load(QUEST_EVENT) as EventScript
	for step: EventStep in ev.steps:
		if step is GiveMoneyStep:
			out["money"] = int(out["money"]) + (step as GiveMoneyStep).amount
		elif step is GiveEquipmentStep:
			out["equipment"] = (step as GiveEquipmentStep).equipment
			out["count"] = (step as GiveEquipmentStep).count
		elif step is GrantXpStep:
			out["xp"] = int(out["xp"]) + (step as GrantXpStep).amount
			out["include_downed"] = (step as GrantXpStep).include_downed
	return out

static func _deliver_quest(state: GameState, ctx: RunCtx) -> void:
	var r: Dictionary = quest_reward()
	state.add_money(int(r["money"]))
	ctx.earned += int(r["money"])
	var eq: EquipmentDef = r["equipment"]
	if eq != null:
		state.bag.add(eq, int(r["count"]))
		_equip_best(state, eq)
	for h: HeroState in state.heroes:
		if h.hp > 0 or bool(r["include_downed"]):
			XpCalculator.grant(h, int(r["xp"]), state.cfg)
	_allocate_all(state)

class_name SimPolicy
extends RefCounted

## Politicas dos herois. Sempre monta a acao via SelectionSession e nunca devolve null
## (se algum passo falhar, volta ao ataque basico).

static func decide(session: SelectionSession, b: BattleState, policy: StringName) -> PendingAction:
	if policy == &"smart":
		var a: PendingAction = _smart(session, b)
		if a != null:
			return a
	return _basic(session, b, policy == &"smart")

## Alvos da habilidade escolhida na sessao, ja com Provocar (M15): havendo um provocador entre eles (so do lado inimigo
## do ator), ele e o unico alvo. A politica e IA: o jogador nunca passa por aqui.
static func _cands(session: SelectionSession) -> Array[Combatant]:
	var cands: Array[Combatant] = session.target_candidates()
	var t: Combatant = Targeting.taunter(cands, session.actor)
	if t != null:
		return [t] as Array[Combatant]
	return cands

static func _reset(session: SelectionSession) -> void:
	if session.step == SelectionSession.Step.TARGET or session.step == SelectionSession.Step.CONFIRM:
		session.back()

## `avoid_shielded` (smart, M11): nao ataca o nucleo de chefe protegido por uma parte enquanto houver outro alvo.
static func _basic(session: SelectionSession, b: BattleState, avoid_shielded: bool = false) -> PendingAction:
	_reset(session)
	if not session.choose_ability(session.actor.basic_attack):
		return null
	var cands: Array[Combatant] = _cands(session)
	if avoid_shielded:
		var open: Array[Combatant] = []
		for c: Combatant in cands:
			if not b.core_shielded(c):
				open.append(c)
		if not open.is_empty():
			cands = open
	var target: Combatant = _best_element_target(session.actor, session.actor.basic_attack, cands) if avoid_shielded else _lowest_hp(cands)
	if target == null:
		session.back()
		return null
	session.set_center(target)
	return session.confirm()

static func _smart(session: SelectionSession, b: BattleState) -> PendingAction:
	var a: PendingAction = _limit(session)
	if a == null:
		a = _revive(session, b)
	if a == null:
		a = _cleanse(session, b)
	if a == null:
		a = _heal(session, b)
	if a == null:
		a = _ether(session, b)
	if a == null:
		a = _reaction(session, b)
	if a == null:
		a = _area(session, b)
	if a == null:
		a = _weakness(session)
	if a == null:
		a = _status(session, b)
	return a

## Multiplicador elemental (M13) do alvo para a habilidade: 1 - afinidade total (neutro = 1.0, fraqueza > 1.0,
## imune/absorve <= 0.0). Radioativo ignora afinidade. So a politica smart usa.
static func elem_mult(actor: Combatant, ab: AbilityDef, target: Combatant) -> float:
	var el: ElementDef = ElementMath.element_of(ab, actor)
	if el == null or el.rule == ElementDef.Rule.RADIOACTIVE:
		return 1.0
	return 1.0 - ElementMath.total_resist(el, target)

## Alvo de maior multiplicador (empate: menor HP). Nunca escolhe imune/absorve se houver outro alvo.
static func _best_element_target(actor: Combatant, ab: AbilityDef, cands: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	var best_m: float = 0.0
	for c: Combatant in cands:
		if c.is_down():
			continue
		var m: float = elem_mult(actor, ab, c)
		if m <= 0.0 and best != null:
			continue
		if best == null or (best_m <= 0.0 and m > 0.0) or m > best_m or (is_equal_approx(m, best_m) and c.hp < best.hp):
			best = c
			best_m = m
	return best

## Reacao (M14): tecnica elemental ofensiva num alvo cuja marca reage com o elemento dela (e o golpe marcaria).
## Prefere o maior multiplicador elemental (fraqueza), depois o menor HP; nunca com imune/absorve na area.
## Nao mira o nucleo de chefe protegido por uma parte. Fica antes da area (M14 Task 6: o combo vale mais que o golpe em area; sem marca reagente a area decide como antes) e antes da fraqueza.
## Sem marca reagente, tabela vazia ou dados neutros: nao faz nada (a fraqueza e as outras regras decidem).
static func _reaction(session: SelectionSession, b: BattleState) -> PendingAction:
	var best_ab: AbilityDef = null
	var best_c: Combatant = null
	var best_m: float = 0.0
	for ab: AbilityDef in session.actor.abilities:
		var el: ElementDef = ElementMath.element_of(ab, session.actor)
		if el == null or ab.side != AbilityDef.Side.ENEMIES or ab.ap_cost <= 0 or not _has_effect(ab.effects, EffectDef.Kind.DAMAGE):
			continue
		if not session.can_use(ab) or not session.choose_ability(ab):
			continue
		for c: Combatant in _cands(session):
			if c.is_down() or b.core_shielded(c) or not MarkRules.has_other(c, el) or ReactionRules.find(b.reactions, c.mark, el) == null:
				continue
			var m: float = elem_mult(session.actor, ab, c)
			if m <= 0.0 or not MarkRules.marks(el, ElementMath.affinity_of(ElementMath.total_resist(el, c))):
				continue
			session.set_center(c)
			var ok: bool = true
			for t: Combatant in session.preview_area():
				if elem_mult(session.actor, ab, t) <= 0.0:
					ok = false
			if ok and (best_c == null or m > best_m + 0.0001 or (is_equal_approx(m, best_m) and c.hp < best_c.hp)):
				best_ab = ab
				best_c = c
				best_m = m
		session.back()
	if best_ab == null or not session.choose_ability(best_ab):
		return null
	session.set_center(best_c)
	return session.confirm()

## Tecnica elemental ofensiva no alvo mais fraco ao elemento (M13): so quando ha fraqueza (multiplicador > 1),
## nunca com imune/absorve na area. Neutro/sem fraqueza: nao faz nada (as outras regras decidem).
static func _weakness(session: SelectionSession) -> PendingAction:
	var best_ab: AbilityDef = null
	var best_c: Combatant = null
	var best_m: float = 1.0
	for ab: AbilityDef in session.actor.abilities:
		if ab.side != AbilityDef.Side.ENEMIES or ab.ap_cost <= 0 or ElementMath.element_of(ab, session.actor) == null or not _has_effect(ab.effects, EffectDef.Kind.DAMAGE):
			continue
		if not session.can_use(ab) or not session.choose_ability(ab):
			continue
		for c: Combatant in _cands(session):
			if c.is_down():
				continue
			session.set_center(c)
			var ok: bool = true
			for t: Combatant in session.preview_area():
				if elem_mult(session.actor, ab, t) <= 0.0:
					ok = false
			var m: float = elem_mult(session.actor, ab, c)
			if ok and m > best_m + 0.0001:
				best_ab = ab
				best_c = c
				best_m = m
		session.back()
	if best_ab == null or not session.choose_ability(best_ab):
		return null
	session.set_center(best_c)
	return session.confirm()

## Golpe de Limite assim que a barra enche (so a politica smart usa).
static func _limit(session: SelectionSession) -> PendingAction:
	if not session.choose_limit():
		return null
	var best: Combatant = null
	var best_n: int = 0
	for c: Combatant in _cands(session):
		session.set_center(c)
		var n: int = session.preview_area().size()
		if best == null or n > best_n or (n == best_n and c.hp < best.hp):
			best = c
			best_n = n
	if best == null:
		session.back()
		return null
	session.set_center(best)
	return session.confirm()

static func _lowest_hp(arr: Array[Combatant]) -> Combatant:
	var best: Combatant = null
	for c: Combatant in arr:
		if c.is_down():
			continue
		if best == null or c.hp < best.hp:
			best = c
	return best

static func _hp_ratio(c: Combatant, b: BattleState) -> float:
	return float(c.hp) / float(maxi(1, StatCalculator.hp_max(c, b.cfg)))

static func _has_effect(effects: Array[EffectDef], kind: EffectDef.Kind) -> bool:
	for e: EffectDef in effects:
		if e.kind == kind:
			return true
	return false

static func _item_with(b: BattleState, kind: EffectDef.Kind) -> ItemDef:
	for it: ItemDef in b.inventory.listing():
		if b.inventory.available(it.id) > 0 and _has_effect(it.effects, kind):
			return it
	return null

static func _revive(session: SelectionSession, b: BattleState) -> PendingAction:
	var downed: Combatant = null
	for h: Combatant in b.heroes:
		if h.is_down():
			downed = h
			break
	if downed == null:
		return null
	var it: ItemDef = _item_with(b, EffectDef.Kind.REVIVE)
	if it == null or not session.choose_item(it):
		return null
	var cands: Array[Combatant] = _cands(session)
	if cands.is_empty():
		session.back()
		return null
	session.set_center(cands[0])
	return session.confirm()

## Cura estado negativo (M11) com um item que remova aquele estado, se houver.
static func _cleanse(session: SelectionSession, b: BattleState) -> PendingAction:
	for h: Combatant in b.living(b.heroes):
		for s: ActiveStatus in h.statuses:
			if not s.def.negative:
				continue
			var it: ItemDef = _cure_for(b, s.def)
			if it == null or not session.choose_item(it):
				continue
			if not _cands(session).has(h):
				session.back()
				continue
			session.set_center(h)
			return session.confirm()
	return null

static func _cure_for(b: BattleState, def: StatusDef) -> ItemDef:
	for it: ItemDef in b.inventory.listing():
		if b.inventory.available(it.id) <= 0:
			continue
		for e: EffectDef in it.effects:
			if e.kind != EffectDef.Kind.REMOVE_STATUS:
				continue
			if (e.status == null and e.statuses.is_empty()) or e.status == def or e.statuses.has(def):
				return it
	return null

static func _heal(session: SelectionSession, b: BattleState) -> PendingAction:
	var needy: Combatant = null
	for h: Combatant in b.living(b.heroes):
		if _hp_ratio(h, b) < 0.4 and (needy == null or _hp_ratio(h, b) < _hp_ratio(needy, b)):
			needy = h
	if needy == null:
		return null
	for ab: AbilityDef in session.actor.abilities:
		if ab.ap_cost <= 0 or not _has_effect(ab.effects, EffectDef.Kind.HEAL) or not session.can_use(ab):
			continue
		if not session.choose_ability(ab):
			continue
		var cands: Array[Combatant] = _cands(session)
		var target: Combatant = needy if cands.has(needy) else null
		if target == null:
			session.back()
			continue
		session.set_center(target)
		return session.confirm()
	return null

static func _cheapest_cost(actor: Combatant) -> int:
	var best: int = -1
	for ab: AbilityDef in actor.abilities:
		if ab.ap_cost > 0 and (best < 0 or ab.ap_cost < best):
			best = ab.ap_cost
	return best

static func _ether(session: SelectionSession, b: BattleState) -> PendingAction:
	var cheapest: int = _cheapest_cost(session.actor)
	if cheapest < 0 or session.actor.ap >= cheapest:
		return null
	var it: ItemDef = _item_with(b, EffectDef.Kind.RESTORE_AP)
	if it == null or not session.choose_item(it):
		return null
	var cands: Array[Combatant] = _cands(session)
	var target: Combatant = session.actor if cands.has(session.actor) else null
	if target == null:
		session.back()
		return null
	session.set_center(target)
	return session.confirm()

static func _area(session: SelectionSession, _b: BattleState) -> PendingAction:
	var best_ab: AbilityDef = null
	var best_c: Combatant = null
	var best_score: float = 0.0
	for ab: AbilityDef in session.actor.abilities:
		if ab.shape != AbilityDef.Shape.CIRCLE_TARGET and ab.shape != AbilityDef.Shape.LINE and ab.shape != AbilityDef.Shape.CIRCLE_SELF:
			continue
		if ab.side != AbilityDef.Side.ENEMIES or ab.ap_cost <= 0 or not session.can_use(ab):
			continue
		if not session.choose_ability(ab):
			continue
		var best: Combatant = null
		var best_n: int = 0
		var best_m: float = 0.0
		for c: Combatant in _cands(session):
			session.set_center(c)
			var area: Array[Combatant] = session.preview_area()
			var n: int = area.size()
			var m: float = 0.0
			var blocked: bool = false
			for t: Combatant in area:
				var tm: float = elem_mult(session.actor, ab, t)
				blocked = blocked or tm <= 0.0
				m += tm
			if blocked:
				continue
			m /= float(maxi(1, n))
			if n > best_n or (n == best_n and m > best_m + 0.0001):
				best_n = n
				best_m = m
				best = c
		session.back()
		# Neutro: todas as medias valem 1.0, entao vence a primeira habilidade que pega 2+ alvos (como antes).
		if best != null and best_n >= 2 and (best_ab == null or best_m > best_score + 0.0001):
			best_ab = ab
			best_c = best
			best_score = best_m
	if best_ab == null or not session.choose_ability(best_ab):
		return null
	session.set_center(best_c)
	return session.confirm()

static func _status(session: SelectionSession, _b: BattleState) -> PendingAction:
	for ab: AbilityDef in session.actor.abilities:
		if ab.side != AbilityDef.Side.ENEMIES or ab.ap_cost <= 0 or not session.can_use(ab):
			continue
		var st: StatusDef = _wanted_status(ab)
		if st == null or not session.choose_ability(ab):
			continue
		var target: Combatant = null
		for c: Combatant in _cands(session):
			if c.immunities.has(st.id) or _has_status(c, st.id):
				continue
			if target == null or c.hp > target.hp:
				target = c
		if target == null:
			session.back()
			continue
		session.set_center(target)
		return session.confirm()
	return null

static func _wanted_status(ab: AbilityDef) -> StatusDef:
	for e: EffectDef in ab.effects:
		if e.kind == EffectDef.Kind.APPLY_STATUS and e.status != null:
			match e.status.kind:
				StatusDef.Kind.POISON, StatusDef.Kind.SLEEP, StatusDef.Kind.SLOW:
					return e.status
	return null

static func _has_status(c: Combatant, id: StringName) -> bool:
	for s: ActiveStatus in c.statuses:
		if s.def.id == id:
			return true
	return false

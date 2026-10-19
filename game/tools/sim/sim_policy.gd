class_name SimPolicy
extends RefCounted

## Politicas dos herois. Sempre monta a acao via SelectionSession e nunca devolve null
## Dano de itens nao entra na divisao basico/habilidade das metricas.
## (se algum passo falhar, volta ao ataque basico).

static func decide(session: SelectionSession, b: BattleState, policy: StringName) -> PendingAction:
	if policy == &"smart":
		var a: PendingAction = _smart(session, b)
		if a != null:
			return a
	return _basic(session, b)

static func _reset(session: SelectionSession) -> void:
	if session.step == SelectionSession.Step.TARGET or session.step == SelectionSession.Step.CONFIRM:
		session.back()

static func _basic(session: SelectionSession, _b: BattleState) -> PendingAction:
	_reset(session)
	if not session.choose_ability(session.actor.basic_attack):
		return null
	var target: Combatant = _lowest_hp(session.target_candidates())
	if target == null:
		session.back()
		return null
	session.set_center(target)
	return session.confirm()

static func _smart(session: SelectionSession, b: BattleState) -> PendingAction:
	var a: PendingAction = _revive(session, b)
	if a == null:
		a = _heal(session, b)
	if a == null:
		a = _ether(session, b)
	if a == null:
		a = _area(session, b)
	if a == null:
		a = _status(session, b)
	return a

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
	var cands: Array[Combatant] = session.target_candidates()
	if cands.is_empty():
		session.back()
		return null
	session.set_center(cands[0])
	return session.confirm()

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
		var cands: Array[Combatant] = session.target_candidates()
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
	var cands: Array[Combatant] = session.target_candidates()
	var target: Combatant = session.actor if cands.has(session.actor) else null
	if target == null:
		session.back()
		return null
	session.set_center(target)
	return session.confirm()

static func _area(session: SelectionSession, _b: BattleState) -> PendingAction:
	for ab: AbilityDef in session.actor.abilities:
		if ab.shape != AbilityDef.Shape.CIRCLE_TARGET and ab.shape != AbilityDef.Shape.LINE and ab.shape != AbilityDef.Shape.CIRCLE_SELF:
			continue
		if ab.side != AbilityDef.Side.ENEMIES or ab.ap_cost <= 0 or not session.can_use(ab):
			continue
		if not session.choose_ability(ab):
			continue
		var best: Combatant = null
		var best_n: int = 0
		for c: Combatant in session.target_candidates():
			session.set_center(c)
			var n: int = session.preview_area().size()
			if n > best_n:
				best_n = n
				best = c
		if best != null and best_n >= 2:
			session.set_center(best)
			return session.confirm()
		session.back()
	return null

static func _status(session: SelectionSession, _b: BattleState) -> PendingAction:
	for ab: AbilityDef in session.actor.abilities:
		if ab.side != AbilityDef.Side.ENEMIES or ab.ap_cost <= 0 or not session.can_use(ab):
			continue
		var st: StatusDef = _wanted_status(ab)
		if st == null or not session.choose_ability(ab):
			continue
		var target: Combatant = null
		for c: Combatant in session.target_candidates():
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

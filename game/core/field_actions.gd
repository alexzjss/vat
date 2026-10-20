## Itens e tecnicas usados fora de combate (menu de grupo). Sem Node/Input.
class_name FieldActions
extends RefCounted

static func is_field_usable(effects: Array[EffectDef]) -> bool:
	if effects.is_empty():
		return false
	for e: EffectDef in effects:
		if e.kind != EffectDef.Kind.HEAL and e.kind != EffectDef.Kind.REVIVE and e.kind != EffectDef.Kind.RESTORE_AP:
			return false
	return true

static func would_affect(effects: Array[EffectDef], target: HeroState, cfg: BalanceConfig) -> bool:
	var c: Combatant = Combatant.from_hero(target, Vector2.ZERO)
	for e: EffectDef in effects:
		match e.kind:
			EffectDef.Kind.HEAL:
				if target.hp > 0 and target.hp < StatCalculator.hp_max(c, cfg):
					return true
			EffectDef.Kind.REVIVE:
				if target.hp <= 0:
					return true
			EffectDef.Kind.RESTORE_AP:
				if target.hp > 0 and target.ap < StatCalculator.ap_max(c, cfg):
					return true
	return false

static func field_techniques(user: HeroState) -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	for ab: AbilityDef in user.abilities():
		if ab.side == AbilityDef.Side.ALLIES and is_field_usable(ab.effects):
			out.append(ab)
	return out

static func can_use_technique(user: HeroState, ab: AbilityDef, target: HeroState, cfg: BalanceConfig, state: GameState = null) -> bool:
	if user.hp <= 0 or user.ap < ab.ap_cost or not is_field_usable(ab.effects):
		return false
	if _is_multi(ab):
		for h: HeroState in _group_pool(user, state):
			if would_affect(ab.effects, h, cfg):
				return true
		return false
	return would_affect(ab.effects, target, cfg)

static func use_item(state: GameState, item: ItemDef, target: HeroState) -> bool:
	if not is_field_usable(item.effects) or state.inventory.available(item.id) <= 0:
		return false
	if not would_affect(item.effects, target, state.cfg):
		return false
	if not state.inventory.reserve(item.id):
		return false
	# Itens com escala Aura (atipicos) usam a Aura do proprio alvo.
	_apply(item.effects, target, _aura(target, state.cfg), state.cfg)
	state.inventory.commit(item.id)
	return true

static func use_technique(state: GameState, user: HeroState, ab: AbilityDef, target: HeroState) -> bool:
	if not can_use_technique(user, ab, target, state.cfg, state):
		return false
	var aura: int = _aura(user, state.cfg)
	var targets: Array[HeroState] = []
	if _is_multi(ab):
		targets.append_array(state.heroes)
	else:
		targets.append(target)
	user.ap -= ab.ap_cost
	for h: HeroState in targets:
		_apply(ab.effects, h, aura, state.cfg)
	return true

static func _is_multi(ab: AbilityDef) -> bool:
	return ab.shape == AbilityDef.Shape.GROUP or ab.shape == AbilityDef.Shape.ALL

## Sem GameState (so a UI consultando), assume apenas o proprio usuario; com state, os ativos.
static func _group_pool(user: HeroState, state: GameState) -> Array[HeroState]:
	if state != null:
		return state.heroes
	var out: Array[HeroState] = [user]
	return out

static func _aura(h: HeroState, cfg: BalanceConfig) -> int:
	return StatCalculator.effective(Combatant.from_hero(h, Vector2.ZERO), &"aura", cfg)

static func _apply(effects: Array[EffectDef], t: HeroState, aura: int, cfg: BalanceConfig) -> void:
	var c: Combatant = Combatant.from_hero(t, Vector2.ZERO)
	for e: EffectDef in effects:
		match e.kind:
			EffectDef.Kind.HEAL:
				if t.hp > 0:
					t.hp += maxi(0, mini(EffectMath.heal_amount(e, aura), StatCalculator.hp_max(c, cfg) - t.hp))
			EffectDef.Kind.REVIVE:
				if t.hp <= 0:
					t.hp = EffectMath.revive_hp(e, StatCalculator.hp_max(c, cfg), cfg)
			EffectDef.Kind.RESTORE_AP:
				if t.hp > 0:
					t.ap = mini(StatCalculator.ap_max(c, cfg), t.ap + EffectMath.restore_ap_amount(e))

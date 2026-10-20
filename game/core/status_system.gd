# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name StatusSystem
extends RefCounted

enum ApplyResult { APPLIED, RENEWED, IMMUNE, RESISTED }

class AtbFullOutcome:
	extends RefCounted
	var poison_damage: int = 0
	var regen_heal: int = 0
	var lost_turn: bool = false
	var expired: Array[StringName] = []

var _cfg: BalanceConfig
var _ledger: ContributionLedger
var _dice: Dice
var _order_counter: int = 0

func _init(cfg: BalanceConfig, ledger: ContributionLedger, dice: Dice) -> void:
	_cfg = cfg
	_ledger = ledger
	_dice = dice

func apply(target: Combatant, def: StatusDef, source: Combatant, chance: float, living_enemies: Array[Combatant]) -> ApplyResult:
	if target.immunities.has(def.id):
		return ApplyResult.IMMUNE
	var resistance: float = float(target.resistances.get(def.id, 0.0))
	if _dice.roll() >= chance * (1.0 - resistance):
		return ApplyResult.RESISTED
	return _install(target, def, source, living_enemies, true)

## Aplica sem sortear e sem crédito de contribuição; a fonte é o próprio alvo (passivos de equipamento).
func apply_forced(target: Combatant, def: StatusDef) -> ApplyResult:
	if target.immunities.has(def.id):
		return ApplyResult.IMMUNE
	var none: Array[Combatant] = []
	return _install(target, def, target, none, false)

func _install(target: Combatant, def: StatusDef, source: Combatant, living_enemies: Array[Combatant], credit: bool) -> ApplyResult:
	var dur: int = _duration_for(def)
	for s: ActiveStatus in target.statuses:
		if s.def.id == def.id:
			var r: int = s.remaining
			s.remaining = dur
			s.source_id = source.id
			s.source_team = source.team
			if def.kind == StatusDef.Kind.BARRIER:
				s.barrier_left = def.potency
			if def.kind == StatusDef.Kind.STOP:
				s.time_left = def.seconds
			if credit and dur > 0:
				_credit_apply(target, source, float(def.apply_contribution) * float(dur - r) / float(dur), living_enemies)
			return ApplyResult.RENEWED
	for cid: StringName in def.cancels:
		remove(target, cid)
	_order_counter += 1
	var fresh: ActiveStatus = ActiveStatus.create(def, source.id, _order_counter)
	fresh.remaining = dur
	fresh.source_team = source.team
	target.statuses.append(fresh)
	if credit:
		_credit_apply(target, source, float(def.apply_contribution), living_enemies)
	return ApplyResult.APPLIED

func _duration_for(def: StatusDef) -> int:
	if _cfg.duration_mode == BalanceConfig.DurationMode.B and _cfg.duration_table.has(def.id):
		return _cfg.duration_table[def.id]
	return def.duration

func _poison_damage(s: ActiveStatus, c: Combatant) -> int:
	var hp_max: int = StatCalculator.hp_max(c, _cfg)
	match _cfg.poison_mode:
		BalanceConfig.PoisonMode.B:
			return maxi(1, floori(hp_max * _cfg.poison_pct))
		BalanceConfig.PoisonMode.C:
			return s.def.potency + floori(hp_max * _cfg.poison_pct)
		_:
			return s.def.potency

func _credit_apply(target: Combatant, source: Combatant, points: float, living_enemies: Array[Combatant]) -> void:
	if points <= 0.0 or source.team != Combatant.Team.HERO:
		return
	if target.team == Combatant.Team.ENEMY:
		_ledger.add(source.id, target.id, points)
	else:
		_ledger.add_ally_benefit(source.id, target, points, living_enemies)

func remove(target: Combatant, id: StringName) -> bool:
	for i: int in target.statuses.size():
		if target.statuses[i].def.id == id:
			target.statuses.remove_at(i)
			return true
	return false

## Remove os estados da lista (ids) e devolve quantos saíram.
func remove_many(target: Combatant, defs: Array[StatusDef]) -> int:
	var n: int = 0
	for d: StatusDef in defs:
		if remove(target, d.id):
			n += 1
	return n

## Remove todos os estados negativos (`StatusDef.negative`) e devolve quantos saíram.
func remove_negative(target: Combatant) -> int:
	var kept: Array[ActiveStatus] = []
	var n: int = 0
	for s: ActiveStatus in target.statuses:
		if s.def.negative:
			n += 1
		else:
			kept.append(s)
	target.statuses = kept
	return n

## Tempo de batalha (segundos, já com a velocidade da batalha): desconta o Pare de quem está parado.
## Devolve quem deixou de estar parado neste passo; o chamador devolve à fila quem tem o ATB cheio.
func tick_time(combatants: Array[Combatant], delta: float) -> Array[Combatant]:
	var freed: Array[Combatant] = []
	for c: Combatant in combatants:
		if c.is_down() or not c.is_stopped():
			continue
		var kept: Array[ActiveStatus] = []
		for s: ActiveStatus in c.statuses:
			if s.def.kind == StatusDef.Kind.STOP:
				s.time_left -= delta
				if s.time_left <= 0.0:
					continue
			kept.append(s)
		c.statuses = kept
		if not c.is_stopped():
			freed.append(c)
	return freed

func _first_blocker(c: Combatant) -> ActiveStatus:
	var best: ActiveStatus = null
	for s: ActiveStatus in c.statuses:
		if s.def.kind == StatusDef.Kind.SLEEP or s.def.kind == StatusDef.Kind.PARALYSIS:
			if best == null or s.applied_order < best.applied_order:
				best = s
	return best

func is_blocked(c: Combatant) -> bool:
	return _first_blocker(c) != null

func on_atb_full(c: Combatant, living_enemies: Array[Combatant]) -> AtbFullOutcome:
	var out := AtbFullOutcome.new()
	# (a) dano de veneno
	for s: ActiveStatus in c.statuses:
		if s.def.kind == StatusDef.Kind.POISON:
			var dmg: int = mini(_poison_damage(s, c), c.hp)
			c.hp -= dmg
			out.poison_damage += dmg
			c.gain_limit(dmg, StatCalculator.hp_max(c, _cfg), _cfg)
			if c.team == Combatant.Team.ENEMY and dmg > 0:
				_ledger.add(s.source_id, c.id, float(dmg))
	if c.hp <= 0:
		return out
	# (a2) regeneração: depois do veneno, nunca revive
	for s: ActiveStatus in c.statuses:
		if s.def.kind == StatusDef.Kind.REGEN:
			var hp_max: int = StatCalculator.hp_max(c, _cfg)
			var healed: int = maxi(0, mini(maxi(1, floori(hp_max * _cfg.regen_pct)), hp_max - c.hp))
			c.hp += healed
			out.regen_heal += healed
			if c.team == Combatant.Team.HERO and s.source_team == Combatant.Team.HERO:
				_ledger.add_ally_benefit(s.source_id, c, float(healed), living_enemies)
	# (b) bloqueio
	var blocker: ActiveStatus = _first_blocker(c)
	if blocker != null:
		out.lost_turn = true
		if c.team == Combatant.Team.ENEMY:
			_ledger.add(blocker.source_id, c.id, float(_cfg.control_value_per_turn))
	# (c) duração
	var kept: Array[ActiveStatus] = []
	for s: ActiveStatus in c.statuses:
		if s.def.kind == StatusDef.Kind.STOP:
			kept.append(s)
			continue
		s.remaining -= 1
		if s.remaining <= 0:
			out.expired.append(s.def.id)
		else:
			kept.append(s)
	c.statuses = kept
	return out

func absorb_with_barrier(target: Combatant, dmg: int, attacker: Combatant) -> int:
	var left: int = dmg
	var kept: Array[ActiveStatus] = []
	for s: ActiveStatus in target.statuses:
		if s.def.kind == StatusDef.Kind.BARRIER:
			var absorbed: int = mini(s.barrier_left, left)
			s.barrier_left -= absorbed
			left -= absorbed
			if attacker.team == Combatant.Team.ENEMY and absorbed > 0:
				_ledger.add(s.source_id, attacker.id, float(absorbed))
			if s.barrier_left <= 0:
				continue
		kept.append(s)
	target.statuses = kept
	return left

func on_hp_damage(target: Combatant) -> void:
	var kept: Array[ActiveStatus] = []
	for s: ActiveStatus in target.statuses:
		if s.def.kind != StatusDef.Kind.SLEEP and s.def.kind != StatusDef.Kind.CONFUSION:
			kept.append(s)
	target.statuses = kept

func clear_all(c: Combatant) -> void:
	c.statuses.clear()

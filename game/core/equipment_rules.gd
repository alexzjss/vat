class_name EquipmentRules
extends RefCounted

const SLOTS: Array[StringName] = [&"weapon", &"armor", &"helmet", &"accessory"]
const SLOT_LABELS: Dictionary[StringName, String] = {
	&"weapon": "Arma", &"armor": "Armadura", &"helmet": "Capacete", &"accessory": "Acessório",
}
const PREVIEW_KEYS: Array[StringName] = [&"strength", &"speed", &"vitality", &"aura", &"hp_max", &"ap_max"]

static func can_equip(d: CharacterDef, e: EquipmentDef, slot: StringName) -> bool:
	if e == null or e.slot != slot:
		return false
	match slot:
		&"weapon":
			return e.weapon_type == &"" or d.weapon_types.has(e.weapon_type)
		&"armor", &"helmet":
			return e.allowed_ids.is_empty() or e.allowed_ids.has(d.id)
		&"accessory":
			return true
	return false

static func _sum_resist(equipment: Dictionary[StringName, EquipmentDef]) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = {}
	for e: EquipmentDef in equipment.values():
		if e == null:
			continue
		for p: EquipmentPassive in e.passives:
			if p.kind == EquipmentPassive.Kind.RESIST and p.status != null:
				out[p.status.id] = out.get(p.status.id, 0.0) + p.amount
	return out

static func immunities(equipment: Dictionary[StringName, EquipmentDef]) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: EquipmentDef in equipment.values():
		if e == null:
			continue
		for p: EquipmentPassive in e.passives:
			if p.kind == EquipmentPassive.Kind.IMMUNE and p.status != null and not out.has(p.status.id):
				out.append(p.status.id)
	var sums: Dictionary[StringName, float] = _sum_resist(equipment)
	for id: StringName in sums:
		if sums[id] >= 1.0 and not out.has(id):
			out.append(id)
	return out

## Soma de RESIST por estado, limitada a 1.0 (imunidades IMMUNE não aparecem aqui).
static func resistances(equipment: Dictionary[StringName, EquipmentDef]) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = _sum_resist(equipment)
	for id: StringName in out:
		out[id] = minf(1.0, out[id])
	return out

## Afinidade elemental total do heroi: base do def + soma dos equipamentos, sem limite (acima de 1.0 absorve).
static func element_resist(d: CharacterDef, equipment: Dictionary[StringName, EquipmentDef]) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = d.element_resist.duplicate()
	for e: EquipmentDef in equipment.values():
		if e == null:
			continue
		for id: StringName in e.element_resist:
			out[id] = float(out.get(id, 0.0)) + float(e.element_resist[id])
	return out

static func start_statuses(equipment: Dictionary[StringName, EquipmentDef]) -> Array[StatusDef]:
	var out: Array[StatusDef] = []
	var seen: Array[StringName] = []
	for e: EquipmentDef in equipment.values():
		if e == null:
			continue
		for p: EquipmentPassive in e.passives:
			if p.kind == EquipmentPassive.Kind.START_WITH and p.status != null and not seen.has(p.status.id):
				seen.append(p.status.id)
				out.append(p.status)
	return out

static func _snapshot(c: Combatant, cfg: BalanceConfig) -> Dictionary[StringName, int]:
	return {
		&"strength": StatCalculator.effective(c, &"strength", cfg),
		&"speed": StatCalculator.effective(c, &"speed", cfg),
		&"vitality": StatCalculator.effective(c, &"vitality", cfg),
		&"aura": StatCalculator.effective(c, &"aura", cfg),
		&"hp_max": StatCalculator.hp_max(c, cfg),
		&"ap_max": StatCalculator.ap_max(c, cfg),
	}

## Para cada chave, [atual, novo] ao trocar `slot` por `e` (null = remover). Não altera o herói.
static func preview(h: HeroState, slot: StringName, e: EquipmentDef, cfg: BalanceConfig) -> Dictionary:
	var cur: Dictionary[StringName, int] = _snapshot(Combatant.from_hero(h, Vector2.ZERO), cfg)
	var eq: Dictionary[StringName, EquipmentDef] = h.equipment.duplicate()
	if e == null:
		eq.erase(slot)
	else:
		eq[slot] = e
	var clone := HeroState.new()
	clone.def = h.def
	clone.level = h.level
	clone.allocated = h.allocated
	clone.equipment = eq
	var nxt: Dictionary[StringName, int] = _snapshot(Combatant.from_hero(clone, Vector2.ZERO), cfg)
	var out: Dictionary = {}
	for k: StringName in PREVIEW_KEYS:
		out[k] = [cur[k], nxt[k]]
	return out

class_name HeroState
extends RefCounted

var def: CharacterDef
var level: int = 1
var xp: int = 0
var allocated: Stats = Stats.make(0, 0, 0, 0)
var pending_points: int = 0
var equipment: Dictionary[StringName, EquipmentDef] = {}
var hp: int = 0
var ap: int = 0
## Barra de Limite (M8), de 0 a 1; persiste entre batalhas e vai no save.
var limit: float = 0.0
## Ids das técnicas aprendidas, na ordem do learnset (M9).
var learned: Array[StringName] = []
## Técnicas aprendidas pela última XpCalculator.grant (para o aviso da tela de resultado); não vai no save.
var last_learned: Array[AbilityDef] = []
## Estados persistentes (M15: Veneno) que o heroi carrega para fora da batalha, sem duracao; ficam ate serem curados.
## Vao no save (campo opcional, so quando nao vazio).
var field_statuses: Array[StringName] = []

static func create(d: CharacterDef, cfg: BalanceConfig) -> HeroState:
	var h := HeroState.new()
	h.def = d
	for e: EquipmentDef in d.starting_equipment:
		if e != null and EquipmentRules.can_equip(d, e, e.slot):
			h.equipment[e.slot] = e
		else:
			push_error("equipamento inicial invalido em %s" % d.id)
	h.learn_up_to(1)
	h.rest(cfg)
	return h

## Aprende as técnicas do learnset com nível 1..`lv` ainda não aprendidas; devolve as novas, em ordem.
func learn_up_to(lv: int) -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	for e: LearnEntry in def.learnset:
		if e != null and e.ability != null and e.level > 0 and e.level <= lv and not learned.has(e.ability.id):
			learned.append(e.ability.id)
			out.append(e.ability)
	_sort_learned()
	return out

## Aprende uma técnica do próprio learnset (eventos). false se o id não é do herói ou já estava aprendida.
func learn(id: StringName) -> bool:
	if learned.has(id):
		return false
	for e: LearnEntry in def.learnset:
		if e != null and e.ability != null and e.ability.id == id:
			learned.append(id)
			_sort_learned()
			return true
	return false

func _sort_learned() -> void:
	var ordered: Array[StringName] = []
	for e: LearnEntry in def.learnset:
		if e != null and e.ability != null and learned.has(e.ability.id):
			ordered.append(e.ability.id)
	learned = ordered

## Técnicas aprendidas (na ordem do learnset).
func abilities() -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	for id: StringName in learned:
		for e: LearnEntry in def.learnset:
			if e != null and e.ability != null and e.ability.id == id:
				out.append(e.ability)
				break
	return out

## Próxima técnica por nível ainda não aprendida (menor nível); null se não há.
func next_learn() -> LearnEntry:
	var best: LearnEntry = null
	for e: LearnEntry in def.learnset:
		if e != null and e.ability != null and e.level > 0 and not learned.has(e.ability.id):
			if best == null or e.level < best.level:
				best = e
	return best

## HP e AP cheios (máximos via StatCalculator com nível, alocação e equipamento atuais);
## revive caídos. Único lugar da recuperação total: criação e descanso ([P-plano] 15).
func rest(cfg: BalanceConfig) -> void:
	var c := Combatant.from_hero(self, Vector2.ZERO)
	hp = StatCalculator.hp_max(c, cfg)
	ap = StatCalculator.ap_max(c, cfg)
	field_statuses = []

## Fim da batalha: os estados `persists` ativos num heroi vivo viram `field_statuses` (sem duracao); quem caiu
## ou foi curado em batalha sai sem eles. Substitui a lista inteira.
func store_field_statuses(c: Combatant) -> void:
	var out: Array[StringName] = []
	if c.hp > 0:
		for s: ActiveStatus in c.statuses:
			if s.def.persists and not out.has(s.def.id):
				out.append(s.def.id)
	field_statuses = out

func has_field_status(id: StringName) -> bool:
	return field_statuses.has(id)

## O estado persistente `id` sai numa cura de `ids` (ou de todos os negativos)?
static func field_cure_matches(id: StringName, ids: Array[StringName], all_negative: bool, cfg: BalanceConfig) -> bool:
	if ids.has(id):
		return true
	if not all_negative:
		return false
	var d: StatusDef = cfg.persistent_status(id)
	return d == null or d.negative

## Cura de campo: remove os estados persistentes citados (`ids`) ou, com `all_negative`, todos os negativos
## (`StatusDef.negative` do cfg; um id desconhecido sai junto). Devolve quantos sairam.
func cure_field_statuses(ids: Array[StringName], all_negative: bool, cfg: BalanceConfig) -> int:
	var kept: Array[StringName] = []
	var n: int = 0
	for id: StringName in field_statuses:
		if field_cure_matches(id, ids, all_negative, cfg):
			n += 1
		else:
			kept.append(id)
	field_statuses = kept
	return n

## Total de pontos distribuídos nos atributos.
func allocated_total() -> int:
	return allocated.strength + allocated.speed + allocated.vitality + allocated.aura

## Reinício de atributos: devolve toda a alocação para `pending_points` e limita HP/AP aos novos máximos.
func reset_allocation(cfg: BalanceConfig) -> void:
	pending_points += allocated_total()
	allocated = Stats.make(0, 0, 0, 0)
	clamp_to_max(cfg)

## Limita HP/AP atuais aos máximos atuais (nunca aumenta; caído continua 0).
func clamp_to_max(cfg: BalanceConfig) -> void:
	var c := Combatant.from_hero(self, Vector2.ZERO)
	hp = mini(hp, StatCalculator.hp_max(c, cfg))
	ap = mini(ap, StatCalculator.ap_max(c, cfg))

## Estado completo para o save: o herói e identificado por def.id; equipamento por id.
func to_dict() -> Dictionary:
	var eq: Dictionary = {}
	for slot: StringName in equipment:
		eq[String(slot)] = String(equipment[slot].id)
	var out: Dictionary = {
		"id": String(def.id), "level": level, "xp": xp, "pending": pending_points,
		"allocated": {
			"strength": allocated.strength, "speed": allocated.speed,
			"vitality": allocated.vitality, "aura": allocated.aura,
		},
		"equipment": eq, "hp": hp, "ap": ap, "limit": limit,
		"learned": learned.map(func(i: StringName) -> String: return String(i)),
	}
	if not field_statuses.is_empty():
		out["field_statuses"] = field_statuses.map(func(i: StringName) -> String: return String(i))
	return out

## Null se o id do heroi ou de algum equipamento for desconhecido, ou se o formato for invalido.
static func from_dict(d: Dictionary, registry: DefRegistry) -> HeroState:
	var cd: CharacterDef = registry.character(StringName(str(d.get("id", ""))))
	var al: Variant = d.get("allocated")
	var eq: Variant = d.get("equipment")
	if cd == null or not al is Dictionary or not eq is Dictionary:
		return null
	for key: String in ["level", "xp", "pending", "hp", "ap"]:
		if not (d.get(key) is float or d.get(key) is int):
			return null
	var h := HeroState.new()
	h.def = cd
	h.level = int(d["level"])
	h.xp = int(d["xp"])
	h.pending_points = int(d["pending"])
	h.hp = int(d["hp"])
	h.ap = int(d["ap"])
	if d.get("limit") is float or d.get("limit") is int:
		h.limit = clampf(float(d["limit"]), 0.0, 1.0)
	var raw: Variant = d.get("learned")
	if raw is Array:
		for v: Variant in (raw as Array):
			var lid := StringName(str(v))
			if not h.learned.has(lid):
				h.learned.append(lid)
		h._sort_learned()
	else:
		h.learn_up_to(h.level)
	var fs: Variant = d.get("field_statuses")
	if fs is Array:
		for v: Variant in (fs as Array):
			var sid := StringName(str(v))
			if sid != &"" and not h.field_statuses.has(sid):
				h.field_statuses.append(sid)
	var a: Dictionary = al
	for attr: StringName in Stats.ATTRS:
		if not (a.get(String(attr)) is float or a.get(String(attr)) is int):
			return null
	h.allocated = Stats.make(int(a["strength"]), int(a["speed"]), int(a["vitality"]), int(a["aura"]))
	for slot: Variant in (eq as Dictionary):
		var e: EquipmentDef = registry.equipment(StringName(str((eq as Dictionary)[slot])))
		if e == null:
			return null
		h.equipment[StringName(str(slot))] = e
	return h

## Cópia dos valores mutáveis do herói (usada por retry de batalha e ponto de salvamento).
func snapshot() -> Dictionary:
	return {
		"hp": hp, "ap": ap, "limit": limit, "xp": xp, "level": level, "pending": pending_points,
		"allocated": Stats.make(allocated.strength, allocated.speed, allocated.vitality, allocated.aura),
		"equipment": equipment.duplicate(), "learned": learned.duplicate(), "field_statuses": field_statuses.duplicate(),
	}

## Restaura os valores de [method snapshot]; `allocated` ganha uma cópia nova.
func restore(snap: Dictionary) -> void:
	hp = snap["hp"]
	ap = snap["ap"]
	limit = float(snap.get("limit", 0.0))
	xp = snap["xp"]
	level = snap["level"]
	pending_points = snap["pending"]
	var a: Stats = snap["allocated"]
	allocated = Stats.make(a.strength, a.speed, a.vitality, a.aura)
	var eq: Dictionary[StringName, EquipmentDef] = snap["equipment"]
	equipment = eq.duplicate()
	var lr: Array[StringName] = []
	lr.assign(snap.get("learned", learned))
	learned = lr
	var fs: Array[StringName] = []
	fs.assign(snap.get("field_statuses", []))
	field_statuses = fs

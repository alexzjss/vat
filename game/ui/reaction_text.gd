class_name ReactionText
extends RefCounted

## Popups e texto de reacao elemental (M14). Puro: planeja os textos a partir do hit e da ReactionDef; a cena os
## mostra nas vistas. Cada popup: {id, text, color, lift, size}; `lift` empilha os textos de uma mesma vista.

const SLOT: float = CombatantView.LABEL_LIFT
const NAME_SIZE: int = 20
const NAME_EXTRA_LIFT: float = 8.0
const DAMAGE_COLOR: Color = Color(1.0, 0.4, 0.4)
const HEAL_COLOR: Color = Color(0.4, 1.0, 0.5)
const ATB_COLOR: Color = Color(0.95, 0.8, 0.2)

## Cor do nome: mistura das cores dos dois elementos do par.
static func color_of(def: ReactionDef) -> Color:
	if def == null or def.a == null or def.b == null:
		return Color.WHITE
	return def.a.color.lerp(def.b.color, 0.5)

## "Fogo + Água", na ordem do par.
static func pair_text(def: ReactionDef) -> String:
	if def == null:
		return ""
	return "%s + %s" % [ElementText.tag(def.a), ElementText.tag(def.b)]

## "ATB −25%" / "ATB +30%"; vazio em 0.
static func atb_text(frac: float) -> String:
	var n: int = roundi(frac * 100.0)
	if n == 0:
		return ""
	return "ATB %s%d%%" % ["+" if n > 0 else ElementText.MINUS, absi(n)]

## Rotulo do estado removido do alvo.
static func removed_text(def: ReactionDef) -> String:
	for s: StatusDef in def.remove_target_statuses:
		if s != null and s.kind == StatusDef.Kind.BARRIER:
			return "Barreira quebrada"
	return "Estado removido"

## Lista de popups da reacao do `hit` (vazia sem reacao). `target_slot`: andares ja usados no alvo pelo proprio golpe
## (CombatantView.popup_slots); `attacker_slot`: andares ja usados no atacante (roubo de vida, dano proprio).
## `slots` (id -> andares usados) pode ser compartilhado entre os hits da mesma acao: o plano o atualiza, e os ids
## ja presentes mantem o valor. O nome da reacao fica no topo da pilha do alvo.
static func plan(hit: Dictionary, def: ReactionDef, attacker_id: StringName, target_slot: int, attacker_slot: int, slots: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fx: Dictionary = hit.get("reaction_effects", {})
	if def == null or fx.is_empty():
		return out
	var target_id: StringName = hit["target_id"]
	if not slots.has(target_id):
		slots[target_id] = target_slot
	if not slots.has(attacker_id):
		slots[attacker_id] = attacker_slot
	var push: Callable = func(id: StringName, text: String, color: Color) -> void:
		var n: int = int(slots.get(id, 0))
		slots[id] = n + 1
		out.append({"id": id, "text": text, "color": color, "lift": float(n) * SLOT, "size": 0})
	var extra: int = int(fx.get("extra_damage", 0))
	if extra > 0:
		push.call(target_id, "Extra -%d" % extra, DAMAGE_COLOR)
	for entry: Dictionary in fx.get("area", []):
		if int(entry["amount"]) > 0:
			push.call(entry["target_id"], "-%d" % int(entry["amount"]), DAMAGE_COLOR)
		elif bool(entry.get("blocked", false)):
			push.call(entry["target_id"], "Bloqueado", Color.WHITE)
	for entry: Dictionary in fx.get("statuses", []):
		push.call(entry["target_id"], _status_text(def, entry), Color.WHITE)
	var atb: Dictionary = fx.get("atb", {})
	if atb_text(float(atb.get("target", 0.0))) != "":
		push.call(target_id, atb_text(float(atb["target"])), ATB_COLOR)
	if atb_text(float(atb.get("attacker", 0.0))) != "":
		push.call(attacker_id, atb_text(float(atb["attacker"])), ATB_COLOR)
	var heal: int = int(fx.get("heal_attacker", 0))
	if heal > 0:
		push.call(attacker_id, "+%d" % heal, HEAL_COLOR)
	for entry: Dictionary in fx.get("heal_allies", []):
		if int(entry["amount"]) > 0:
			push.call(entry["target_id"], "+%d" % int(entry["amount"]), HEAL_COLOR)
	if int(fx.get("removed", 0)) > 0:
		push.call(target_id, removed_text(def), Color.WHITE)
	out.append({"id": target_id, "text": def.display_name, "color": color_of(def), "lift": float(slots[target_id]) * SLOT + NAME_EXTRA_LIFT, "size": NAME_SIZE})
	return out

static func _status_text(def: ReactionDef, entry: Dictionary) -> String:
	var res: int = int(entry.get("result", StatusSystem.ApplyResult.APPLIED))
	if res == StatusSystem.ApplyResult.IMMUNE:
		return "Imune"
	if res == StatusSystem.ApplyResult.RESISTED:
		return "Resistiu"
	var all: Array[StatusDef] = []
	all.append_array(def.target_statuses)
	all.append_array(def.area_statuses)
	all.append_array(def.attacker_statuses)
	for s: StatusDef in all:
		if s != null and s.id == entry["status_id"]:
			return CombatantView.def_label(s)
	return String(entry["status_id"])

## Reacao pelo id na tabela; null se nao ha.
static func find_by_id(table: ReactionTable, id: StringName) -> ReactionDef:
	if table == null or id == &"":
		return null
	for d: ReactionDef in table.reactions:
		if d != null and d.id == id:
			return d
	return null

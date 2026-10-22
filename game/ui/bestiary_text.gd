class_name BestiaryText
extends RefCounted

## Textos do Bestiario e das Reacoes (M15). Puro: so le defs e a entrada do GameState. A pagina do menu (Task 6)
## mostra estas linhas; nada aqui depende de Node.

const UNKNOWN: String = "???"
const NONE: String = "—"
## Baldes do raio da area da reacao: P ate `AREA_SMALL`, M ate `AREA_MEDIUM`, G acima (valores de teste, so exibicao).
const AREA_SMALL: float = 120.0
const AREA_MEDIUM: float = 280.0
const SEP: String = " · "

## Linhas do bestiario para um inimigo. `entry` = GameState.bestiary_entry(id); `revealed` = GameState.bestiary_revealed(id);
## `cfg` calcula o HP maximo como o jogo (Combatant.from_enemy + StatCalculator.hp_max). Nao visto: so "???".
## Sempre (visto): nome, nivel, HP maximo e derrotas. Revelado: elementos nativos, afinidades, imunidades e resistencias
## a estados e os drops. Nao revelado nao vaza nada alem das quatro linhas.
static func entry_lines(def: EnemyDef, entry: Dictionary, revealed: bool, cfg: BalanceConfig) -> Array[String]:
	var out: Array[String] = []
	if def == null or not bool(entry.get("seen", false)):
		out.append(UNKNOWN)
		return out
	out.append(def.display_name)
	out.append("Nv %d" % def.level)
	out.append("HP máx %d" % max_hp(def, cfg))
	out.append("Derrotado %dx" % int(entry.get("defeated", 0)))
	if not revealed:
		return out
	out.append("Elementos: %s" % _or_none(ElementText.natives_text(def.elements)))
	out.append("Afinidades: %s" % _or_none(affinities_text(def.element_resist)))
	out.append("Imune a: %s" % _or_none(status_list_text(def.immunities)))
	out.append("Resiste a: %s" % _or_none(status_resist_text(def.resistances, def.immunities)))
	out.append("Drops: %s" % _or_none(drops_text(def)))
	return out

## HP maximo de um EnemyDef como a batalha o calcula.
static func max_hp(def: EnemyDef, cfg: BalanceConfig) -> int:
	return StatCalculator.hp_max(Combatant.from_enemy(def, def.id, Vector2.ZERO, cfg), cfg)

## "Fogo −50%, Raio absorve, Gelo imune": fraco/resiste com sinal, 100% = imune, acima = absorve; nulos ficam de fora.
static func affinities_text(resist: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id: StringName in ElementText.nonzero_ids(resist):
		var v: float = float(resist[id])
		var label: String
		match ElementMath.affinity_of(v):
			ElementMath.Affinity.IMMUNE:
				label = "imune"
			ElementMath.Affinity.ABSORB:
				label = "absorve"
			_:
				label = ElementText.pct(v)
		parts.append("%s %s" % [ElementText.short_name_of(id), label])
	return ", ".join(parts)

## "Sono, Veneno" (nomes de EquipPage.status_name).
static func status_list_text(ids: Array[StringName]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id: StringName in ids:
		parts.append(EquipPage.status_name(id))
	return ", ".join(parts)

## "Veneno 50%"; imunes e valores nulos ficam de fora.
static func status_resist_text(res: Dictionary, immunities: Array[StringName]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id: StringName in res:
		if float(res[id]) > 0.0 and not immunities.has(id):
			parts.append("%s %d%%" % [EquipPage.status_name(id), roundi(float(res[id]) * 100.0)])
	return ", ".join(parts)

## "Poção 50%, Espada x2 100%": nome, quantidade (so se > 1) e a chance de cair.
static func drops_text(def: EnemyDef) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for d: DropEntry in def.drops:
		var name: String = ""
		if d.item != null:
			name = d.item.display_name
		elif d.equipment != null:
			name = d.equipment.display_name
		if name == "":
			continue
		var qty: String = " x%d" % d.count if d.count > 1 else ""
		parts.append("%s%s %d%%" % [name, qty, roundi(d.chance * 100.0)])
	return ", ".join(parts)

## Resumo curto dos efeitos da reacao, gerado do ReactionDef:
## "+50% dano · Cegueira 50% · área 40% (M) · ATB alvo −25% · fica Fogo". Campo vazio ou 0 nao aparece; sem nada, "—".
static func reaction_summary(def: ReactionDef) -> String:
	if def == null:
		return NONE
	var parts: PackedStringArray = PackedStringArray()
	if def.bonus_pct > 0.0:
		parts.append("+%d%% dano" % roundi(def.bonus_pct * 100.0))
	for s: StatusDef in def.target_statuses:
		if s == null:
			continue
		parts.append(_status_chance(s, def.status_chance))
	if def.area_pct > 0.0:
		parts.append("área %d%% (%s)" % [roundi(def.area_pct * 100.0), area_size(def.area_radius)])
	for s: StatusDef in def.area_statuses:
		if s == null:
			continue
		parts.append("área " + _status_chance(s, def.status_chance))
	var t_atb: String = ReactionText.atb_text(def.target_atb)
	if t_atb != "":
		parts.append(t_atb.replace("ATB ", "ATB alvo "))
	var a_atb: String = ReactionText.atb_text(def.attacker_atb)
	if a_atb != "":
		parts.append(a_atb.replace("ATB ", "ATB atacante "))
	for s: StatusDef in def.attacker_statuses:
		if s == null:
			continue
		parts.append("atacante " + EquipPage.status_name(s.id))
	if def.heal_attacker_pct > 0.0:
		parts.append("cura atacante %d%%" % roundi(def.heal_attacker_pct * 100.0))
	if def.heal_allies_pct > 0.0:
		parts.append("cura grupo %d%%" % roundi(def.heal_allies_pct * 100.0))
	if not def.remove_target_statuses.is_empty():
		parts.append(ReactionText.removed_text(def))
	if def.keep != null:
		parts.append("fica %s" % ElementText.tag(def.keep))
	return SEP.join(parts) if not parts.is_empty() else NONE

## "P", "M" ou "G" pelo raio da area.
static func area_size(radius: float) -> String:
	if radius <= AREA_SMALL:
		return "P"
	return "M" if radius <= AREA_MEDIUM else "G"

static func _status_chance(s: StatusDef, chance: float) -> String:
	var n: String = EquipPage.status_name(s.id)
	return n if chance >= 1.0 else "%s %d%%" % [n, roundi(chance * 100.0)]

static func _or_none(text: String) -> String:
	return text if text != "" else NONE

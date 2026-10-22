class_name ElementText
extends RefCounted

## Texto e cores de elemento para a UI (M13). Puro: so le defs. Dados neutros produzem texto vazio,
## para as telas antigas ficarem identicas.

const ELEMENT_DIR: String = "res://data/elements"
## Ordem de exibicao das afinidades (a dos elementos do usuario); ids fora da lista vao depois, por id.
const ORDER: Array[StringName] = [&"kagutsuchi", &"susanoo", &"fuhaku", &"atlas", &"indra", &"tsukuyomi", &"amaterasu", &"shukketsu", &"radioativo"]
const MINUS: String = "−"
const WEAK_COLOR: Color = Color(1.0, 0.85, 0.3)
const ABSORB_NUMBER_COLOR: Color = Color(0.4, 1.0, 0.5)

static var _cache: Dictionary[StringName, ElementDef] = {}

## Def do elemento pelo id (data/elements); null se nao existe ou id vazio.
static func def_of(id: StringName) -> ElementDef:
	if id == &"":
		return null
	if _cache.has(id):
		return _cache[id]
	var path: String = "%s/%s.tres" % [ELEMENT_DIR, id]
	var e: ElementDef = load(path) as ElementDef if ResourceLoader.exists(path) else null
	_cache[id] = e
	return e

static func short_name_of(id: StringName) -> String:
	var e: ElementDef = def_of(id)
	return e.short_name if e != null and e.short_name != "" else String(id).capitalize()

## Texto do icone da marca: `icon_text` do elemento ("At" de Atlas) ou, vazio, a inicial do nome curto ("F" de Fogo); vazio sem elemento.
static func initial_of(e: ElementDef) -> String:
	if e == null:
		return ""
	if e.icon_text != "":
		return e.icon_text
	var t: String = tag(e)
	return t.substr(0, 1) if t != "" else ""

static func color_of(id: StringName) -> Color:
	var e: ElementDef = def_of(id)
	return e.color if e != null else Color.WHITE

## Rotulo do popup de batalha por afinidade; vazio no neutro.
static func affinity_label(aff: int) -> String:
	match aff:
		ElementMath.Affinity.WEAK:
			return "Fraco!"
		ElementMath.Affinity.RESIST:
			return "Resistiu"
		ElementMath.Affinity.IMMUNE:
			return "Imune"
		ElementMath.Affinity.ABSORB:
			return "Absorveu"
	return ""

## Nome curto do elemento ("Fogo"), vazio se neutro.
static func tag(element: ElementDef) -> String:
	if element == null:
		return ""
	return element.short_name if element.short_name != "" else String(element.id).capitalize()

## "30%", "−50%" (sinal de menos tipografico).
static func pct(v: float) -> String:
	var n: int = roundi(v * 100.0)
	return ("%s%d%%" % [MINUS, absi(n)]) if n < 0 else "%d%%" % n

## "Fogo, Raio" dos nativos; vazio sem nativos.
static func natives_text(elements: Array[ElementDef]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for e: ElementDef in elements:
		if e != null:
			parts.append(tag(e))
	return ", ".join(parts)

## Ids com afinidade diferente de 0 (em %, arredondado), na ordem de exibicao.
static func nonzero_ids(resist: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for k: Variant in resist.keys():
		if roundi(float(resist[k]) * 100.0) != 0:
			ids.append(StringName(k))
	ids.sort_custom(_before)
	return ids

static func _before(a: StringName, b: StringName) -> bool:
	var ia: int = ORDER.find(a)
	var ib: int = ORDER.find(b)
	if ia == -1 and ib == -1:
		return String(a) < String(b)
	if ia == -1:
		return false
	if ib == -1:
		return true
	return ia < ib

## "Fogo 30%, Raio −50%" so com as entradas nao nulas; vazio se nao ha nenhuma.
static func resist_text(resist: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id: StringName in nonzero_ids(resist):
		parts.append("%s %s" % [short_name_of(id), pct(float(resist[id]))])
	return ", ".join(parts)

## Multiplicador de dano do elemento contra o alvo (1 - afinidade); Radioativo ignora afinidade.
static func multiplier(element: ElementDef, target: Combatant, cfg: BalanceConfig = null) -> float:
	if element == null or element.rule == ElementDef.Rule.RADIOACTIVE:
		return 1.0
	return 1.0 - ElementMath.total_resist(element, target, cfg)

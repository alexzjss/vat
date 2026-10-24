class_name ContentChecks
extends RefCounted

## Validadores de conteúdo (M16). Puros: recebem dados já carregados e devolvem `Array[ValidationIssue]`.
## Sem Node, sem IO. Quem lê o disco monta o [ContentBundle] (tools/validate/content_loader.gd).
## Cada regra é uma função estática; [method run] roda todas.

const BOSS_IMMUNITIES: Array[StringName] = [&"doom", &"petrify"]
## Erro do compilador: "arquivo:12: mensagem".
const _LINE_PATTERN: String = "^[^:]*:(\\d+): (.*)$"

## Roda todas as regras sobre o pacote.
static func run(b: ContentBundle) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	var res: Array = b.resources
	out.append_array(unique_ids(res))
	out.append_array(references(res))
	out.append_array(native_elements(res))
	out.append_array(reactions(res))
	out.append_array(bosses(res))
	out.append_array(event_scripts(res))
	out.append_array(roteiros(b.roteiros, res))
	out.append_array(sprite_sets(res))
	out.append_array(missing_battle_art(res))
	out.append_array(roteiro_refs(b.roteiro_refs))
	out.append_array(MapChecks.links(b.maps))
	out.append_array(MapChecks.profiles(res, b.maps))
	return out

# --- ids únicos ------------------------------------------------------------------------

## Nome do tipo para as mensagens; "" = tipo sem id verificado.
static func kind_label(r: Resource) -> String:
	if r is ItemDef: return "item"
	if r is EquipmentDef: return "equipamento"
	if r is CharacterDef: return "herói"
	if r is EnemyDef: return "inimigo"
	if r is EncounterDef: return "encontro"
	if r is AbilityDef: return "habilidade"
	if r is ShopDef: return "loja"
	if r is StatusDef: return "estado"
	if r is ElementDef: return "elemento"
	if r is ReactionDef: return "reação"
	if r is SpeakerDef: return "falante"
	if r is TerrainDef: return "terreno"
	return ""

## Ids únicos por tipo: o mesmo id em dois recursos do mesmo tipo é erro, e id vazio também.
static func unique_ids(resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	var seen: Dictionary = {}
	for v: Variant in resources:
		var r: Resource = v as Resource
		if r == null:
			continue
		var kind: String = kind_label(r)
		if kind == "":
			continue
		var id: StringName = r.get(&"id")
		if id == &"":
			out.append(ValidationIssue.error("%s sem id" % kind, r.resource_path))
			continue
		var key: String = "%s/%s" % [kind, id]
		if not seen.has(key):
			seen[key] = r
		elif seen[key] != r:
			out.append(ValidationIssue.error("id de %s repetido: '%s' (também em %s)" % [kind, id, (seen[key] as Resource).resource_path], r.resource_path))
	return out

# --- referências -----------------------------------------------------------------------

## Referências que precisam existir: campos nulos onde são obrigatórios e itens nulos em listas
## (aprendizado, loja, encontro, drops, regras de IA, perfil de início, efeitos, equipamentos).
static func references(resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for v: Variant in resources:
		var r: Resource = v as Resource
		if r == null:
			continue
		if r is CharacterDef:
			_hero_refs(r as CharacterDef, out)
		elif r is EnemyDef:
			_enemy_refs(r as EnemyDef, out)
		elif r is EncounterDef:
			_encounter_refs(r as EncounterDef, out)
		elif r is ShopDef:
			_shop_refs(r as ShopDef, out)
		elif r is StartProfile:
			_profile_refs(r as StartProfile, out)
		elif r is AbilityDef:
			_effects_refs((r as AbilityDef).effects, "habilidade '%s'" % (r as AbilityDef).id, r.resource_path, out)
		elif r is ItemDef:
			_effects_refs((r as ItemDef).effects, "item '%s'" % (r as ItemDef).id, r.resource_path, out)
		elif r is EquipmentDef:
			_equipment_refs(r as EquipmentDef, out)
	return out

static func _hero_refs(c: CharacterDef, out: Array[ValidationIssue]) -> void:
	var who: String = "herói '%s'" % c.id
	if c.base == null:
		out.append(ValidationIssue.error("%s: sem atributos base" % who, c.resource_path))
	if c.basic_attack == null:
		out.append(ValidationIssue.error("%s: sem ataque básico" % who, c.resource_path))
	for i: int in c.learnset.size():
		var e: LearnEntry = c.learnset[i]
		if e == null:
			out.append(ValidationIssue.error("%s: learnset[%d] vazio" % [who, i], c.resource_path))
		elif e.ability == null:
			out.append(ValidationIssue.error("%s: learnset[%d] sem habilidade" % [who, i], c.resource_path))
	for i: int in c.starting_equipment.size():
		if c.starting_equipment[i] == null:
			out.append(ValidationIssue.error("%s: equipamento inicial [%d] vazio" % [who, i], c.resource_path))

static func _enemy_refs(e: EnemyDef, out: Array[ValidationIssue]) -> void:
	var who: String = "inimigo '%s'" % e.id
	if e.base == null:
		out.append(ValidationIssue.error("%s: sem atributos base" % who, e.resource_path))
	for i: int in e.abilities.size():
		if e.abilities[i] == null:
			out.append(ValidationIssue.error("%s: habilidade [%d] vazia" % [who, i], e.resource_path))
	_ai_refs(e.ai_rules, who, e.resource_path, out)
	for i: int in e.phases.size():
		var p: BossPhase = e.phases[i]
		if p == null:
			out.append(ValidationIssue.error("%s: fase [%d] vazia" % [who, i], e.resource_path))
		else:
			_ai_refs(p.ai_rules, "%s, fase %d" % [who, i], e.resource_path, out)
	for i: int in e.drops.size():
		var d: DropEntry = e.drops[i]
		if d == null:
			out.append(ValidationIssue.error("%s: drop [%d] vazio" % [who, i], e.resource_path))
		elif d.item == null and d.equipment == null:
			out.append(ValidationIssue.error("%s: drop [%d] sem item nem equipamento" % [who, i], e.resource_path))

static func _ai_refs(rules: Array[AiRule], who: String, path: String, out: Array[ValidationIssue]) -> void:
	for i: int in rules.size():
		if rules[i] == null:
			out.append(ValidationIssue.error("%s: regra de IA [%d] vazia" % [who, i], path))
		elif rules[i].ability == null:
			out.append(ValidationIssue.error("%s: regra de IA [%d] sem habilidade" % [who, i], path))

static func _encounter_refs(e: EncounterDef, out: Array[ValidationIssue]) -> void:
	var who: String = "encontro '%s'" % e.id
	if e.enemies.is_empty():
		out.append(ValidationIssue.error("%s: sem inimigos" % who, e.resource_path))
	for i: int in e.enemies.size():
		if e.enemies[i] == null:
			out.append(ValidationIssue.error("%s: inimigo [%d] vazio" % [who, i], e.resource_path))

static func _shop_refs(s: ShopDef, out: Array[ValidationIssue]) -> void:
	var who: String = "loja '%s'" % s.id
	for i: int in s.items.size():
		if s.items[i] == null:
			out.append(ValidationIssue.error("%s: item [%d] vazio" % [who, i], s.resource_path))
	for i: int in s.equipment.size():
		if s.equipment[i] == null:
			out.append(ValidationIssue.error("%s: equipamento [%d] vazio" % [who, i], s.resource_path))
	if s.items.is_empty() and s.equipment.is_empty():
		out.append(ValidationIssue.warning("%s: sem nada à venda" % who, s.resource_path))

static func _profile_refs(p: StartProfile, out: Array[ValidationIssue]) -> void:
	var path: String = p.resource_path
	if p.party.is_empty():
		out.append(ValidationIssue.error("perfil de início: grupo vazio", path))
	for i: int in p.party.size():
		if p.party[i] == null:
			out.append(ValidationIssue.error("perfil de início: herói [%d] vazio" % i, path))
	for i: int in p.items.size():
		if p.items[i] == null:
			out.append(ValidationIssue.error("perfil de início: item [%d] vazio" % i, path))
	for i: int in p.equipment.size():
		if p.equipment[i] == null:
			out.append(ValidationIssue.error("perfil de início: equipamento [%d] vazio" % i, path))
	if p.item_counts.size() != p.items.size():
		out.append(ValidationIssue.error("perfil de início: %d item(ns) e %d quantidade(s)" % [p.items.size(), p.item_counts.size()], path))
	if p.equipment_counts.size() != p.equipment.size():
		out.append(ValidationIssue.error("perfil de início: %d equipamento(s) e %d quantidade(s)" % [p.equipment.size(), p.equipment_counts.size()], path))

static func _equipment_refs(e: EquipmentDef, out: Array[ValidationIssue]) -> void:
	var who: String = "equipamento '%s'" % e.id
	for i: int in e.passives.size():
		var p: EquipmentPassive = e.passives[i]
		if p == null:
			out.append(ValidationIssue.error("%s: passiva [%d] vazia" % [who, i], e.resource_path))
		elif p.status == null:
			out.append(ValidationIssue.error("%s: passiva [%d] sem estado" % [who, i], e.resource_path))

static func _effects_refs(effects: Array[EffectDef], who: String, path: String, out: Array[ValidationIssue]) -> void:
	for i: int in effects.size():
		var f: EffectDef = effects[i]
		if f == null:
			out.append(ValidationIssue.error("%s: efeito [%d] vazio" % [who, i], path))
			continue
		# REMOVE_STATUS sem estado remove todos os negativos (válido); APPLY_STATUS precisa de um estado.
		if f.kind == EffectDef.Kind.APPLY_STATUS and f.status == null and f.statuses.is_empty():
			out.append(ValidationIssue.error("%s: efeito [%d] aplica estado sem estado" % [who, i], path))
		for j: int in f.statuses.size():
			if f.statuses[j] == null:
				out.append(ValidationIssue.error("%s: efeito [%d] com estado [%d] vazio" % [who, i, j], path))

# --- elementos nativos e reações -------------------------------------------------------

## No máximo 2 elementos nativos, sem nulos nem repetidos (heróis e inimigos).
static func native_elements(resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for v: Variant in resources:
		var r: Resource = v as Resource
		var errs: Array[String] = []
		if r is CharacterDef:
			errs = ElementMath.native_errors((r as CharacterDef).id, (r as CharacterDef).elements)
		elif r is EnemyDef:
			errs = ElementMath.native_errors((r as EnemyDef).id, (r as EnemyDef).elements)
		for m: String in errs:
			out.append(ValidationIssue.error(m, r.resource_path))
	return out

## A tabela de reações contra os elementos que existem (par repetido, par faltando, keep fora do par...).
static func reactions(resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	var elements: Array[ElementDef] = []
	for v: Variant in resources:
		if v is ElementDef:
			elements.append(v)
	for v: Variant in resources:
		var table: ReactionTable = v as ReactionTable
		if table == null:
			continue
		for m: String in ReactionRules.errors(table, elements):
			out.append(ValidationIssue.error(m, table.resource_path))
		for d: ReactionDef in table.reactions:
			if d == null:
				continue
			for j: int in d.target_statuses.size():
				if d.target_statuses[j] == null:
					out.append(ValidationIssue.error("reação %s: estado do alvo [%d] vazio" % [d.id, j], table.resource_path))
	return out

# --- chefes ----------------------------------------------------------------------------

## Todo inimigo com papel de chefe (núcleo ou parte) é imune a Contagem e Petrificação.
static func bosses(resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for v: Variant in resources:
		var e: EnemyDef = v as EnemyDef
		if e == null or e.role == EnemyDef.Role.NORMAL:
			continue
		for imm: StringName in BOSS_IMMUNITIES:
			if not e.immunities.has(imm):
				out.append(ValidationIssue.error("chefe '%s' não é imune a '%s'" % [e.id, imm], e.resource_path))
	return out

# --- eventos e roteiros ----------------------------------------------------------------

## EventScripts soltos (`.tres`, ou embutidos em mapas): rótulos que existem e referências não nulas dos passos.
static func event_scripts(resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for v: Variant in resources:
		var s: EventScript = v as EventScript
		if s != null:
			out.append_array(event_script(s, s.resource_path))
	return out

static func event_script(script: EventScript, path: String) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	var labels: Dictionary = {}
	for step: EventStep in script.steps:
		var l: LabelStep = step as LabelStep
		if l != null:
			labels[l.label_name] = true
	for i: int in script.steps.size():
		var step: EventStep = script.steps[i]
		if step == null:
			out.append(ValidationIssue.error("passo [%d] vazio" % i, path))
			continue
		var jump: StringName = &""
		if step is GotoStep:
			jump = (step as GotoStep).label
		elif step is IfFlagStep:
			jump = (step as IfFlagStep).else_label
		elif step is IfItemStep:
			jump = (step as IfItemStep).else_label
		elif step is IfMoneyStep:
			jump = (step as IfMoneyStep).else_label
		if jump != &"" and not labels.has(jump):
			out.append(ValidationIssue.error("passo [%d]: rótulo '%s' não existe" % [i, jump], path))
		var missing: String = _step_missing_ref(step)
		if missing != "":
			out.append(ValidationIssue.error("passo [%d]: %s vazio" % [i, missing], path))
	return out

static func _step_missing_ref(step: EventStep) -> String:
	if step is GiveItemStep and (step as GiveItemStep).item == null: return "item"
	if step is TakeItemStep and (step as TakeItemStep).item == null: return "item"
	if step is IfItemStep and (step as IfItemStep).item == null: return "item"
	if step is GiveEquipmentStep and (step as GiveEquipmentStep).equipment == null: return "equipamento"
	if step is RecruitStep and (step as RecruitStep).hero == null: return "herói"
	if step is StartBattleStep and (step as StartBattleStep).encounter == null: return "encontro"
	return ""

## Compila cada `.roteiro` (caminho -> texto): erros viram ERROR com a linha, avisos viram WARNING.
## Cobre rótulos quebrados, ids inexistentes e o resto da gramática.
static func roteiros(sources: Dictionary[String, String], resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	var index: ContentIndex = ContentIndex.from_resources(resources)
	var re := RegEx.new()
	re.compile(_LINE_PATTERN)
	var paths: Array = sources.keys()
	paths.sort()
	for p: Variant in paths:
		var path: String = p
		var r: Dictionary = RoteiroCompiler.compile(sources[path], path.get_file(), index.resolver())
		for m: String in r["errors"]:
			out.append(_roteiro_issue(re, ValidationIssue.Severity.ERROR, m, path))
		for m: String in r["warnings"]:
			out.append(_roteiro_issue(re, ValidationIssue.Severity.WARNING, m, path))
	return out

static func _roteiro_issue(re: RegEx, severity: ValidationIssue.Severity, msg: String, path: String) -> ValidationIssue:
	var m: RegExMatch = re.search(msg)
	if m == null:
		return ValidationIssue.make(severity, msg, path)
	return ValidationIssue.make(severity, m.get_string(2), path, int(m.get_string(1)))

# --- arte ------------------------------------------------------------------------------

## SpriteSets com folha múltipla do quadro e animações dentro da folha (os soltos e os de heróis, inimigos e falantes).
static func sprite_sets(resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	var seen: Dictionary = {}
	for v: Variant in resources:
		var s: SpriteSet = v as SpriteSet
		var owner_path: String = ""
		if s == null:
			var holder: Resource = v as Resource
			if holder is CharacterDef:
				s = (holder as CharacterDef).sprites
			elif holder is EnemyDef:
				s = (holder as EnemyDef).sprites
			elif holder is SpeakerDef:
				s = (holder as SpeakerDef).sprites
			if s == null:
				continue
			owner_path = holder.resource_path
		if seen.has(s):
			continue
		seen[s] = true
		var path: String = s.resource_path if s.resource_path != "" else owner_path
		for m: String in s.validate():
			out.append(ValidationIssue.error(m, path))
		if not s.portraits.is_empty() and not s.portraits.has(&"neutro"):
			out.append(ValidationIssue.warning("retratos sem a expressão 'neutro' (a que o diálogo usa quando falta a pedida)", path))
	return out

## ERRO: nó de mapa com `roteiro` mas sem `event_id`, com `event_id` que o livro não tem, ou cujo `.roteiro` não carregou.
## `refs`: ver [method ContentBundle.roteiro_ref].
static func roteiro_refs(refs: Array[Dictionary]) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for r: Dictionary in refs:
		var where: String = "mapa %s, nó %s" % [r["map"], r["node"]]
		var book: RoteiroBook = r["book"] as RoteiroBook
		var id: StringName = r["event_id"]
		var path: String = String(r["book_path"])
		if book == null:
			out.append(ValidationIssue.error("%s: o roteiro não carregou (reimporte o .roteiro)" % where, path))
		elif id == &"":
			out.append(ValidationIssue.error("%s: tem roteiro mas o event_id está vazio" % where, path))
		elif not book.events.has(id):
			out.append(ValidationIssue.error("%s: o roteiro não tem o evento '%s'" % [where, id], path))
	return out

## AVISO: herói ou inimigo sem arte de batalha (o jogo usa o desenho geométrico). O conteúdo de `res://data/test/`
## não recebe arte e fica de fora.
const TEST_DATA_PREFIX: String = "res://data/test/"

static func missing_battle_art(resources: Array) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	for v: Variant in resources:
		var s: SpriteSet = null
		var label: String = ""
		var res: Resource = v as Resource
		if res is CharacterDef:
			s = (res as CharacterDef).sprites
			label = "herói '%s'" % (res as CharacterDef).id
		elif res is EnemyDef:
			s = (res as EnemyDef).sprites
			label = "inimigo '%s'" % (res as EnemyDef).id
		else:
			continue
		if res.resource_path.begins_with(TEST_DATA_PREFIX):
			continue
		if s == null or not s.has_battle_art():
			out.append(ValidationIssue.warning("%s sem arte de batalha" % label, res.resource_path))
	return out

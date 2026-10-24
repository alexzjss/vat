@tool
extends RefCounted

## Lógica pura dos formulários de herói, inimigo e encontro (M17). A UI (`ui/forms/`, `ui/widgets/`) só desenha; aqui estão:
## os descritores de campo de cada tipo, a leitura e a escrita de arrays e dicionários tipados (sempre no próprio objeto,
## para os tipos não se perderem), os sub-resources novos com valores padrão, a conversão fração <-> porcentagem,
## as listas de escolha, a validação e o salvar e reverter.
##
## No editor os `.tres` carregados são instâncias "de mentira" (os scripts do jogo não são `@tool`): só as propriedades
## funcionam, os métodos do recurso não. Por isso nada aqui chama método de recurso carregado; os `.new()` e os métodos
## estáticos de classes do jogo funcionam normalmente.

const Catalog: GDScript = preload("res://addons/vat_editor/logic/vat_catalog.gd")

## Tipos de campo (`type` do descritor).
const T_ID: StringName = &"id"
const T_TEXT: StringName = &"text"
const T_INT: StringName = &"int"
const T_PCT: StringName = &"pct"
const T_BOOL: StringName = &"bool"
const T_ENUM: StringName = &"enum"
const T_STATS: StringName = &"stats"
const T_REF: StringName = &"ref"
const T_REFS: StringName = &"refs"
const T_NAMES: StringName = &"names"
const T_PCT_DICT: StringName = &"pct_dict"
const T_ROWS: StringName = &"rows"
const T_SPRITES: StringName = &"sprites"

## Tipos de linha de `T_ROWS` (`row` do descritor).
const ROW_LEARN: StringName = &"learn"
const ROW_AI_RULE: StringName = &"ai_rule"
const ROW_DROP: StringName = &"drop"
const ROW_PHASE: StringName = &"phase"

## Fontes de escolha (`source` do descritor).
const SRC_ABILITY: StringName = &"ability"
const SRC_ITEM: StringName = &"item"
const SRC_EQUIP: StringName = &"equip"
const SRC_ENEMY: StringName = &"enemy"
const SRC_ELEMENT: StringName = &"element"
const SRC_STATUS: StringName = &"status"
const SRC_SPRITES: StringName = &"sprites"
const SRC_WEAPON: StringName = &"weapon"

## Fontes que vêm do `ContentIndex` (tipo do índice) e as que vêm de uma categoria do Banco.
const INDEX_KINDS: Dictionary[StringName, StringName] = {SRC_ABILITY: &"ability", SRC_ITEM: &"item", SRC_EQUIP: &"equip"}
const CATEGORY_OF: Dictionary[StringName, StringName] = {
	SRC_ABILITY: &"abilities", SRC_ITEM: &"items", SRC_EQUIP: &"equipment",
	SRC_ENEMY: &"enemies", SRC_ELEMENT: &"elements", SRC_STATUS: &"statuses",
}
const ART_FOLDER: String = "res://art"

const NONE_LABEL: String = "(nenhum)"
const MAX_NATIVES: int = 2

## Rótulos dos enums, na ordem dos valores (um teste confere o tamanho).
const CONDITION_LABELS: Array[String] = ["Sempre", "Aliado com HP abaixo de", "Parte caída", "Pode reagir (marca)"]
const PICK_LABELS: Array[String] = ["Inimigo de menor HP", "Inimigo aleatório", "Aliado de menor HP", "O próprio", "Mais próximo", "Mais distante", "Aglomerado", "Alvo com marca reagente"]
const ROLE_LABELS: Array[String] = ["Normal", "Núcleo (vence ao cair)", "Parte"]

# --- porcentagem -----------------------------------------------------------------------------------------------

## Fração do jogo (0.3) -> porcentagem do formulário (30.0). Arredonda a 2 casas, para o campo não mostrar ruído de ponto flutuante.
static func to_percent(fraction: float) -> float:
	return snappedf(fraction * 100.0, 0.01)

## Porcentagem do formulário (30.0) -> fração do jogo (0.3).
static func from_percent(percent: float) -> float:
	return percent / 100.0

## O que a porcentagem de uma afinidade significa. `absorbs`: elementos (> 100% absorve); estados só chegam a imune.
static func sign_hint(percent: float, absorbs: bool = true) -> String:
	var p: float = snappedf(percent, 0.01)
	if p > 100.0:
		return "absorve" if absorbs else "imune"
	if p == 100.0:
		return "imune"
	if p > 0.0:
		return "resiste"
	if p < 0.0:
		return "fraqueza"
	return "neutro"

const AFFINITY_HELP: String = "+ resiste / − fraqueza; 100% imune; > 100% absorve"
const STATUS_HELP: String = "+ resiste / − vulnerável; 100% imune"

# --- descritores -----------------------------------------------------------------------------------------------

static func _f(prop: StringName, label: String, type: StringName, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"prop": prop, "label": label, "type": type}
	d.merge(extra, true)
	return d

## Os campos do formulário de uma categoria do Banco (`heroes`, `enemies` ou `encounters`), na ordem de exibição.
## Cada descritor: `prop`, `label`, `type` e os extras do tipo (`source`, `row`, `options`, `min`, `max`, `max_count`, `help`).
## `group` abre uma seção nova quando muda.
static func fields(kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match kind:
		&"heroes":
			out.assign([
				_f(&"id", "Id", T_ID, {"group": "Identidade"}),
				_f(&"display_name", "Nome", T_TEXT),
				_f(&"base", "Atributos base", T_STATS, {"group": "Atributos"}),
				_f(&"elements", "Elementos nativos (até 2)", T_REFS, {"group": "Elementos e estados", "source": SRC_ELEMENT, "max_count": MAX_NATIVES}),
				_f(&"element_resist", "Afinidades elementais", T_PCT_DICT, {"source": SRC_ELEMENT, "help": AFFINITY_HELP}),
				_f(&"status_resist", "Resistência a estados", T_PCT_DICT, {"source": SRC_STATUS, "help": STATUS_HELP}),
				_f(&"basic_attack", "Ataque básico", T_REF, {"group": "Combate", "source": SRC_ABILITY}),
				_f(&"limit_ability", "Golpe de Limite", T_REF, {"source": SRC_ABILITY}),
				_f(&"weapon_types", "Tipos de arma", T_NAMES, {"source": SRC_WEAPON}),
				_f(&"starting_equipment", "Equipamento inicial", T_REFS, {"source": SRC_EQUIP}),
				_f(&"learnset", "Técnicas por nível (nível 0 = só por evento)", T_ROWS, {"group": "Técnicas", "row": ROW_LEARN}),
				_f(&"sprites", "Arte (SpriteSet)", T_SPRITES, {"group": "Arte", "source": SRC_SPRITES}),
			])
		&"enemies":
			out.assign([
				_f(&"id", "Id", T_ID, {"group": "Identidade"}),
				_f(&"display_name", "Nome", T_TEXT),
				_f(&"level", "Nível", T_INT, {"min": 1, "max": 99}),
				_f(&"xp_base", "XP base", T_INT, {"min": 0, "max": 999999}),
				_f(&"money", "Moedas", T_INT, {"min": 0, "max": 999999}),
				_f(&"base", "Atributos base", T_STATS, {"group": "Atributos"}),
				_f(&"elements", "Elementos nativos (até 2)", T_REFS, {"group": "Elementos e estados", "source": SRC_ELEMENT, "max_count": MAX_NATIVES}),
				_f(&"element_resist", "Afinidades elementais", T_PCT_DICT, {"source": SRC_ELEMENT, "help": AFFINITY_HELP}),
				_f(&"resistances", "Resistência a estados", T_PCT_DICT, {"source": SRC_STATUS, "help": STATUS_HELP}),
				_f(&"immunities", "Imunidades a estados", T_NAMES, {"source": SRC_STATUS}),
				_f(&"abilities", "Habilidades", T_REFS, {"group": "Combate", "source": SRC_ABILITY}),
				_f(&"ai_rules", "Regras de IA (a primeira que vale, de cima para baixo)", T_ROWS, {"row": ROW_AI_RULE}),
				_f(&"drops", "Drops", T_ROWS, {"group": "Recompensas", "row": ROW_DROP}),
				_f(&"phases", "Fases de chefe (HP em ordem decrescente)", T_ROWS, {"group": "Chefe", "row": ROW_PHASE}),
				_f(&"counter", "Contra-ataque", T_REF, {"source": SRC_ABILITY}),
				_f(&"counter_chance", "Chance do contra-ataque", T_PCT),
				_f(&"counter_only_basic", "Só o ataque básico provoca o contra-ataque", T_BOOL),
				_f(&"role", "Papel", T_ENUM, {"options": ROLE_LABELS}),
				_f(&"shields_core", "Protege o núcleo (parte)", T_BOOL),
				_f(&"sprites", "Arte (SpriteSet)", T_SPRITES, {"group": "Arte", "source": SRC_SPRITES}),
			])
		&"encounters":
			out.assign([
				_f(&"id", "Id", T_ID, {"group": "Identidade"}),
				_f(&"enemies", "Inimigos", T_REFS, {"group": "Formação", "source": SRC_ENEMY}),
				_f(&"can_flee", "Pode fugir", T_BOOL, {"group": "Regras"}),
				_f(&"unique_id", "Id único (chefes: gravado ao vencer)", T_ID),
			])
	return out

## O descritor de `prop`, ou {} se não existe.
static func field(kind: StringName, prop: StringName) -> Dictionary:
	for d: Dictionary in fields(kind):
		if d["prop"] == prop:
			return d
	return {}

## As colunas de uma linha de `T_ROWS`: `prop`, `label`, `type` (como nos campos) e extras.
static func columns(row: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match row:
		ROW_LEARN:
			out.assign([
				_f(&"level", "Nível", T_INT, {"min": 0, "max": 99}),
				_f(&"ability", "Habilidade", T_REF, {"source": SRC_ABILITY}),
			])
		ROW_AI_RULE:
			out.assign([
				_f(&"condition", "Condição", T_ENUM, {"options": CONDITION_LABELS}),
				_f(&"threshold", "Limiar de HP", T_PCT),
				_f(&"ability", "Habilidade", T_REF, {"source": SRC_ABILITY}),
				_f(&"pick", "Alvo", T_ENUM, {"options": PICK_LABELS}),
				_f(&"chance", "Chance", T_PCT),
				_f(&"telegraph", "Anuncia", T_BOOL),
			])
		ROW_DROP:
			out.assign([
				_f(&"item", "Item", T_REF, {"source": SRC_ITEM}),
				_f(&"equipment", "Equipamento", T_REF, {"source": SRC_EQUIP}),
				_f(&"chance", "Chance", T_PCT),
				_f(&"count", "Qtd.", T_INT, {"min": 1, "max": 99}),
			])
		ROW_PHASE:
			out.assign([
				_f(&"hp_below", "HP abaixo de", T_PCT),
				_f(&"banner", "Faixa na tela", T_TEXT),
				_f(&"ai_rules", "Regras de IA da fase", T_ROWS, {"row": ROW_AI_RULE}),
			])
	return out

## Cria uma linha nova de `row` com os valores padrão (o que "Adicionar" põe na lista).
static func new_row(row: StringName, existing: Array = []) -> Resource:
	match row:
		ROW_LEARN:
			return new_learn_entry()
		ROW_AI_RULE:
			return new_ai_rule()
		ROW_DROP:
			return new_drop()
		ROW_PHASE:
			return new_boss_phase(existing)
	return null

# --- sub-resources novos ---------------------------------------------------------------------------------------

static func new_stats(strength: int = 0, speed: int = 0, vitality: int = 0, aura: int = 0) -> Stats:
	var s := Stats.new()
	s.strength = strength
	s.speed = speed
	s.vitality = vitality
	s.aura = aura
	return s

static func new_learn_entry(ability: AbilityDef = null, level: int = 1) -> LearnEntry:
	var e := LearnEntry.new()
	e.ability = ability
	e.level = level
	return e

static func new_ai_rule(ability: AbilityDef = null) -> AiRule:
	var r := AiRule.new()
	r.ability = ability
	return r

static func new_drop(item: ItemDef = null, equipment: EquipmentDef = null) -> DropEntry:
	var d := DropEntry.new()
	d.item = item
	d.equipment = equipment
	return d

## Fase nova: abaixo da última (menos 25 pontos, no mínimo 5%), ou 50% se é a primeira.
static func new_boss_phase(existing: Array = []) -> BossPhase:
	var p := BossPhase.new()
	var last: float = 1.0
	var any: bool = false
	for v: Variant in existing:
		var q: BossPhase = v as BossPhase
		if q != null:
			last = q.hp_below
			any = true
	p.hp_below = maxf(last - 0.25, 0.05) if any else 0.5
	return p

## Os atributos de `res.<prop>`; cria (zerados) se faltam.
static func ensure_stats(res: Resource, prop: StringName = &"base") -> Stats:
	var s: Stats = res.get(prop) as Stats
	if s == null:
		s = new_stats()
		res.set(prop, s)
	return s

## Uma cópia independente de uma linha embutida (Stats, regra de IA, drop, aprendizado, fase). Os recursos de dentro, como
## habilidades e itens, continuam compartilhados; as regras de uma fase são copiadas uma a uma.
static func copy_row(item: Resource) -> Resource:
	if item == null:
		return null
	if item is BossPhase:
		var src: BossPhase = item as BossPhase
		var dst := BossPhase.new()
		dst.hp_below = src.hp_below
		dst.banner = src.banner
		for r: AiRule in src.ai_rules:
			dst.ai_rules.append(copy_row(r) as AiRule)
		return dst
	return item.duplicate(false)

## true se o recurso é embutido no arquivo dono (novo, sem caminho, ou `arquivo.tres::id`) e não uma referência externa.
static func is_embedded(r: Resource) -> bool:
	return r != null and (r.resource_path == "" or r.resource_path.contains("::"))

# --- listas (arrays tipados, alterados no próprio array) -------------------------------------------------------

## Acrescenta `item` ao fim. Devolve o índice. O array mantém o tipo.
static func list_add(arr: Array, item: Variant) -> int:
	arr.append(item)
	return arr.size() - 1

static func list_remove(arr: Array, index: int) -> bool:
	if index < 0 or index >= arr.size():
		return false
	arr.remove_at(index)
	return true

## Troca o item com o vizinho (`delta` -1 sobe, +1 desce). Devolve o novo índice (o mesmo se não deu).
static func list_move(arr: Array, index: int, delta: int) -> int:
	var to: int = index + delta
	if index < 0 or index >= arr.size() or to < 0 or to >= arr.size():
		return index
	var item: Variant = arr[index]
	arr[index] = arr[to]
	arr[to] = item
	return to

## Duplica o item logo abaixo dele (recursos viram cópias independentes). Devolve o índice da cópia, ou -1.
static func list_duplicate(arr: Array, index: int) -> int:
	if index < 0 or index >= arr.size():
		return -1
	var item: Variant = arr[index]
	var copy: Variant = copy_row(item as Resource) if item is Resource and is_embedded(item as Resource) else item
	arr.insert(index + 1, copy)
	return index + 1

## Liga ou desliga `value` numa lista de nomes (arma, imunidade), sem repetir e mantendo a ordem.
static func names_toggle(arr: Array, value: StringName, on: bool) -> void:
	var at: int = arr.find(value)
	if on and at == -1:
		arr.append(value)
	elif not on and at != -1:
		arr.remove_at(at)

# --- dicionários de porcentagem --------------------------------------------------------------------------------

## Coloca `key` com `percent` (porcentagem do formulário) no dicionário tipado.
static func dict_set_percent(d: Dictionary, key: StringName, percent: float) -> void:
	d[key] = from_percent(percent)

static func dict_percent(d: Dictionary, key: StringName) -> float:
	return to_percent(float(d.get(key, 0.0)))

## Troca a chave de uma linha mantendo o valor e a posição. Se `to` já existe, não faz nada e devolve false.
static func dict_rename(d: Dictionary, from: StringName, to: StringName) -> bool:
	if from == to:
		return true
	if not d.has(from) or d.has(to):
		return false
	var keys: Array = d.keys()
	var pairs: Array = []
	for k: Variant in keys:
		pairs.append([to if k == from else k, d[from] if k == from else d[k]])
	d.clear()
	for p: Array in pairs:
		d[p[0]] = p[1]
	return true

## A primeira das `candidates` que ainda não está no dicionário (&"" se todas já estão).
static func dict_next_free(d: Dictionary, candidates: Array) -> StringName:
	for c: Variant in candidates:
		if not d.has(c):
			return c as StringName
	return &""

# --- escolhas --------------------------------------------------------------------------------------------------

## "id — Nome" (ou só o id).
static func label_of(res: Resource) -> String:
	var id: String = str(res.get(&"id"))
	var shown: String = str(res.get(&"display_name"))
	if res is ElementDef:
		shown = str(res.get(&"short_name")) if str(res.get(&"short_name")) != "" else shown
	return id if shown == "" or shown == id else "%s — %s" % [id, shown]

## Os recursos que o seletor de `source` oferece: `[{value: Resource, id: StringName, label: String}]`, por id.
## Habilidades, itens e equipamentos vêm do `ContentIndex` dos recursos das pastas do Banco; inimigos, elementos e estados,
## da pasta da categoria; `sprites` varre `res://art`; `weapon` devolve os tipos de arma usados pelos equipamentos.
static func choices(source: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if source == SRC_SPRITES:
		var folders: Array[String] = [ART_FOLDER]
		for path: String in Catalog.list_paths(folders):
			var res: Resource = load(path)
			if res is SpriteSet:
				out.append({"value": res, "id": StringName(path.get_file().get_basename()), "label": path.trim_prefix("res://")})
		return out
	if source == SRC_WEAPON:
		for e: Resource in Catalog.load_category(&"equipment"):
			var w: StringName = e.get(&"weapon_type")
			if w != &"" and not _has_id(out, w):
				out.append({"value": w, "id": w, "label": String(w)})
		out.sort_custom(_by_id)
		return out
	if not CATEGORY_OF.has(source):
		return out
	var loaded: Array[Resource] = Catalog.load_category(CATEGORY_OF[source])
	if INDEX_KINDS.has(source):
		var index: ContentIndex = ContentIndex.from_resources(loaded)
		for id: StringName in index.ids(INDEX_KINDS[source]):
			var r: Resource = index.resolve(INDEX_KINDS[source], id)
			out.append({"value": r, "id": id, "label": label_of(r)})
		return out
	for r: Resource in loaded:
		out.append({"value": r, "id": r.get(&"id"), "label": label_of(r)})
	out.sort_custom(_by_id)
	return out

static func _has_id(list: Array[Dictionary], id: StringName) -> bool:
	for c: Dictionary in list:
		if c["id"] == id:
			return true
	return false

static func _by_id(a: Dictionary, b: Dictionary) -> bool:
	return String(a["id"]) < String(b["id"])

## Só os ids de `choices` (para os seletores de chave dos dicionários).
static func choice_ids(list: Array[Dictionary]) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Dictionary in list:
		out.append(c["id"])
	return out

# --- prévia em texto do encontro ------------------------------------------------------------------------------

## Linhas da formação: um grupo por inimigo ("2× Braço (fatia), nível 3, XP 100"), e o total.
static func encounter_summary(enc: Resource) -> PackedStringArray:
	var out := PackedStringArray()
	var enemies: Array = enc.get(&"enemies")
	if enemies.is_empty():
		out.append("Sem inimigos.")
		return out
	var order: Array[Resource] = []
	var counts: Dictionary = {}
	var xp: int = 0
	var money: int = 0
	var empty: int = 0
	for v: Variant in enemies:
		var e: Resource = v as Resource
		if e == null:
			empty += 1
			continue
		if not counts.has(e):
			order.append(e)
		counts[e] = int(counts.get(e, 0)) + 1
		xp += int(e.get(&"xp_base"))
		money += int(e.get(&"money"))
	for e: Resource in order:
		var name: String = str(e.get(&"display_name"))
		if name == "":
			name = str(e.get(&"id"))
		var role: int = int(e.get(&"role"))
		var tag: String = "" if role == 0 else ", %s" % ("núcleo" if role == 1 else "parte")
		out.append("%d× %s (%s), nível %d%s" % [counts[e], name, e.get(&"id"), int(e.get(&"level")), tag])
	if empty > 0:
		out.append("%d vaga(s) sem inimigo escolhido." % empty)
	out.append("Total: %d inimigo(s), XP base %d, moedas %d. %s" % [enemies.size() - empty, xp, money, "Pode fugir." if bool(enc.get(&"can_flee")) else "Sem fuga."])
	return out

# --- validação -------------------------------------------------------------------------------------------------

## Os achados do recurso aberto, com os checks puros do M16 (`ContentChecks`): referências nulas, elementos nativos,
## imunidades de chefe e id repetido. `siblings` são os outros recursos da categoria (para o id repetido).
## A arte (SpriteSet) não entra aqui: validar a folha chama métodos do recurso, que não rodam no editor.
static func validate(res: Resource, siblings: Array = []) -> Array[ValidationIssue]:
	var out: Array[ValidationIssue] = []
	if res == null:
		return out
	var others: Array = []
	for s: Variant in siblings:
		if s != res and (s as Resource).resource_path != res.resource_path:
			others.append(s)
	others.append(res)
	for i: ValidationIssue in ContentChecks.unique_ids(others):
		if i.path == res.resource_path:
			out.append(i)
	var alone: Array = [res]
	out.append_array(ContentChecks.references(alone))
	out.append_array(ContentChecks.native_elements(alone))
	out.append_array(ContentChecks.bosses(alone))
	return out

# --- salvar e reverter -----------------------------------------------------------------------------------------

## Grava o recurso no próprio arquivo. Os sub-resources (Stats, regras de IA...) seguem embutidos, as habilidades e outros
## `.tres` seguem como referências.
static func save(res: Resource) -> Error:
	if res == null or res.resource_path == "" or res.resource_path.contains("::"):
		return ERR_INVALID_PARAMETER
	return ResourceSaver.save(res, res.resource_path)

## Relê o arquivo trocando o cache (`CACHE_MODE_REPLACE`): a instância aberta, a mesma que o Inspector mostra, recebe os
## dados do disco. O Godot só reescreve as propriedades que o arquivo traz (um dicionário vazio não é gravado e ficaria com
## a edição), então cada propriedade que ainda difere de uma leitura limpa é copiada dela. Devolve o recurso, ou null.
static func reload_file(path: String) -> Resource:
	var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	var fresh: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null or fresh == null:
		return res
	for p: Dictionary in fresh.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or p["name"] == "script" or p["name"] == "resource_path":
			continue
		var value: Variant = fresh.get(p["name"])
		if _snap(res.get(p["name"])) != _snap(value):
			res.set(p["name"], value)
	return res

# --- prévia da arte --------------------------------------------------------------------------------------------

## As animações de um `SpriteSet`, lidas das propriedades (sem chamar métodos do recurso):
## `{nome: {sheet: Texture2D, rects: Array[Rect2i], fps: float, loop: bool, group: String}}`.
## Mapa: `walk_down`/`walk_left`/`walk_right`/`walk_up`. Batalha: as de `anims`. Quadros fora da folha ficam de fora.
static func sprite_animations(sprites: Resource) -> Dictionary:
	var out: Dictionary = {}
	if sprites == null:
		return out
	var map_sheet: Texture2D = sprites.get(&"map_sheet") as Texture2D
	if map_sheet != null:
		var frame: Vector2i = sprites.get(&"map_frame")
		var count: int = int(sprites.get(&"walk_frames"))
		for facing: int in SpriteSet.Facing.values():
			var rects: Array[Rect2i] = _row_rects(map_sheet, frame, facing, count)
			if not rects.is_empty():
				out[StringName("walk_%s" % SpriteSet.facing_name(facing as SpriteSet.Facing))] = {
					"sheet": map_sheet, "rects": rects, "fps": float(sprites.get(&"walk_fps")), "loop": true, "group": "Mapa"}
	var battle_sheet: Texture2D = sprites.get(&"battle_sheet") as Texture2D
	if battle_sheet != null:
		var bframe: Vector2i = sprites.get(&"battle_frame")
		var anims: Dictionary = sprites.get(&"anims")
		for key: Variant in anims:
			var a: Vector3i = anims[key]
			var rects: Array[Rect2i] = _row_rects(battle_sheet, bframe, a.x, a.y)
			if not rects.is_empty():
				out[key] = {"sheet": battle_sheet, "rects": rects, "fps": float(maxi(a.z, 1)), "loop": SpriteSet.loops(key), "group": "Batalha"}
	return out

static func _row_rects(sheet: Texture2D, frame: Vector2i, row: int, count: int) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if frame.x <= 0 or frame.y <= 0 or row < 0:
		return out
	var size: Vector2i = Vector2i(sheet.get_size())
	for i: int in count:
		var r := Rect2i(i * frame.x, row * frame.y, frame.x, frame.y)
		if r.end.x <= size.x and r.end.y <= size.y:
			out.append(r)
	return out

# --- instantâneo para comparar ---------------------------------------------------------------------------------

## Os valores gravados de um recurso como dados simples (recursos embutidos por dentro, externos pelo caminho; arrays e
## dicionários com a assinatura de tipo). Serve para conferir que salvar e recarregar não muda nada.
static func snapshot(res: Resource) -> Dictionary:
	var out: Dictionary = {}
	for p: Dictionary in res.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) == 0 or p["name"] == "script" or p["name"] == "resource_path":
			continue
		out[p["name"]] = _snap(res.get(p["name"]))
	return out

static func _snap(v: Variant) -> Variant:
	if v is Resource:
		var r: Resource = v
		if is_embedded(r):
			var d: Dictionary = snapshot(r)
			d["__script"] = r.get_script().resource_path if r.get_script() != null else ""
			return d
		return "ext:" + r.resource_path
	if v is Array:
		var arr: Array = v
		var items: Array = []
		for x: Variant in arr:
			items.append(_snap(x))
		var script_path: String = ""
		var ts: Variant = arr.get_typed_script()
		if ts is Script:
			script_path = (ts as Script).resource_path
		return {"__array": "%d|%s|%s" % [arr.get_typed_builtin(), arr.get_typed_class_name(), script_path], "items": items}
	if v is Dictionary:
		var dict: Dictionary = v
		var entries: Array = []
		for k: Variant in dict:
			entries.append([_snap(k), _snap(dict[k])])
		# o gravador do Godot ordena as chaves; a ordem de um dicionário não tem significado aqui
		entries.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
		return {"__dict": "%d|%d" % [dict.get_typed_key_builtin(), dict.get_typed_value_builtin()], "entries": entries}
	return v

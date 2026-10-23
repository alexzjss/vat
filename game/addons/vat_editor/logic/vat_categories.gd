@tool
extends RefCounted

## Categorias do Banco do painel VAT (M16): cada uma liga um script de recurso às pastas onde o painel procura,
## à pasta padrão de um recurso novo, ao modelo (`templates/<chave>.tres`) e às colunas-chave da lista.
## Lógica pura de editor: o jogo em execução não carrega nada daqui.

const TEMPLATE_DIR: String = "res://addons/vat_editor/templates/"
## Modos de coluna: "val" (o valor), "count" (tamanho de lista ou dicionário), "ids" (id do recurso ou dos recursos),
## "bool" (sim / não) e "kind" (nome do enum de StatusDef).
const MODES: Array[String] = ["val", "count", "ids", "bool", "kind"]

static func _cat(key: StringName, label: String, script_class: StringName, folders: Array[String], new_folder: String, columns: Array[Dictionary]) -> Dictionary:
	return {"key": key, "label": label, "script_class": script_class, "folders": folders, "new_folder": new_folder,
			"template": TEMPLATE_DIR + String(key) + ".tres", "columns": columns}

static func _col(title: String, prop: StringName, mode: String = "val") -> Dictionary:
	return {"title": title, "prop": prop, "mode": mode}

## Todas as categorias, na ordem das abas.
static func all() -> Array[Dictionary]:
	return [
		_cat(&"heroes", "Heróis", &"CharacterDef", ["res://data/fatia/heroes", "res://data/test/heroes"],
				"res://data/fatia/heroes", [_col("Elementos", &"elements", "ids"), _col("Técnicas", &"learnset", "count")]),
		_cat(&"enemies", "Inimigos", &"EnemyDef", ["res://data/fatia/enemies", "res://data/test/enemies"],
				"res://data/fatia/enemies", [_col("Nível", &"level"), _col("XP", &"xp_base")]),
		_cat(&"abilities", "Habilidades", &"AbilityDef", ["res://data/fatia/abilities", "res://data/test/abilities"],
				"res://data/fatia/abilities", [_col("PA", &"ap_cost"), _col("Elemento", &"element", "ids")]),
		_cat(&"items", "Itens", &"ItemDef", ["res://data/fatia/items", "res://data/test/items"],
				"res://data/fatia/items", [_col("Preço", &"price"), _col("Chave", &"key_item", "bool")]),
		_cat(&"equipment", "Equipamentos", &"EquipmentDef", ["res://data/fatia/equipment", "res://data/test/equipment"],
				"res://data/fatia/equipment", [_col("Espaço", &"slot"), _col("Preço", &"price"), _col("Elemento", &"element", "ids")]),
		_cat(&"encounters", "Encontros", &"EncounterDef", ["res://data/fatia/encounters", "res://data/test/encounters"],
				"res://data/fatia/encounters", [_col("Inimigos", &"enemies", "ids"), _col("Fuga", &"can_flee", "bool")]),
		_cat(&"shops", "Lojas", &"ShopDef", ["res://data/fatia/shops"],
				"res://data/fatia/shops", [_col("Itens", &"items", "count"), _col("Equip.", &"equipment", "count")]),
		_cat(&"statuses", "Estados", &"StatusDef", ["res://data/fatia/statuses", "res://data/test/statuses"],
				"res://data/fatia/statuses", [_col("Tipo", &"kind", "kind"), _col("Duração", &"duration")]),
		_cat(&"elements", "Elementos", &"ElementDef", ["res://data/elements"],
				"res://data/elements", [_col("Sigla", &"short_name"), _col("Reage", &"reacts", "bool")]),
		_cat(&"reactions", "Reações", &"ReactionDef", ["res://data/reactions"],
				"res://data/reactions", [_col("A", &"a", "ids"), _col("B", &"b", "ids"), _col("Bônus", &"bonus_pct")]),
		_cat(&"terrain", "Terrenos", &"TerrainDef", ["res://data/fatia/terrain"],
				"res://data/fatia/terrain", [_col("Elementos", &"element_mult", "count")]),
		_cat(&"speakers", "Falantes", &"SpeakerDef", ["res://art"],
				"res://art/falantes", [_col("Arte", &"sprites", "ids")]),
	]

static func keys() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Dictionary in all():
		out.append(c["key"])
	return out

## A categoria de `key`, ou `{}` se não existe.
static func get_category(key: StringName) -> Dictionary:
	for c: Dictionary in all():
		if c["key"] == key:
			return c
	return {}

## `res` é da categoria `key` (o script dele, ou um script base, tem o nome da classe da categoria).
static func matches(key: StringName, res: Resource) -> bool:
	var cat: Dictionary = get_category(key)
	if cat.is_empty() or res == null:
		return false
	var s: Script = res.get_script() as Script
	while s != null:
		if s.get_global_name() == cat["script_class"]:
			return true
		s = s.get_base_script()
	return false

## A categoria a que `res` pertence, ou `&""`.
static func key_of(res: Resource) -> StringName:
	for k: StringName in keys():
		if matches(k, res):
			return k
	return &""

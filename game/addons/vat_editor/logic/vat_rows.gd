@tool
extends RefCounted

## Linhas da lista do Banco (M16): cabeçalhos, formatação das células por categoria e filtro por busca.

const Categories: GDScript = preload("res://addons/vat_editor/logic/vat_categories.gd")

## Cabeçalhos: Id, Nome e as colunas-chave da categoria.
static func headers(key: StringName) -> PackedStringArray:
	var out := PackedStringArray(["Id", "Nome"])
	for c: Dictionary in Categories.get_category(key).get("columns", []):
		out.append(c["title"])
	return out

## Linha de `res`: `{path, id, name, cells}`; `cells` casa com [method headers].
static func row(key: StringName, res: Resource) -> Dictionary:
	var cells := PackedStringArray()
	var display: Variant = res.get(&"display_name")
	cells.append(id_of(res))
	cells.append(str(display) if display != null else "")
	for c: Dictionary in Categories.get_category(key).get("columns", []):
		cells.append(format_cell(res.get(c["prop"]), c["mode"]))
	return {"path": res.resource_path, "id": cells[0], "name": cells[1], "cells": cells}

## O id do recurso; quem não tem (a arte, `SpriteSet`) usa o nome do arquivo.
static func id_of(res: Resource) -> String:
	var raw: Variant = res.get(&"id")
	if raw != null:
		return str(raw)
	return res.resource_path.get_file().get_basename() if res.resource_path != "" else ""

static func rows(key: StringName, resources: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for v: Variant in resources:
		var r: Resource = v as Resource
		if r != null:
			out.append(row(key, r))
	return out

## Formata um valor de coluna conforme o modo (ver Categories.MODES).
static func format_cell(value: Variant, mode: String) -> String:
	match mode:
		"count":
			if value is Array or value is Dictionary:
				return str(value.size())
			return "0"
		"bool":
			return "sim" if value == true else "não"
		"kind":
			if value == null:
				return ""
			var kind_name: Variant = StatusDef.Kind.find_key(int(value))
			return str(kind_name).to_lower() if kind_name != null else str(value)
		"ids":
			if value is Array:
				var parts := PackedStringArray()
				for v: Variant in value:
					parts.append(_id_of(v))
				return ", ".join(parts)
			return _id_of(value)
	if value == null:
		return ""
	if value is float:
		return "%.2f" % value
	return str(value)

static func _id_of(v: Variant) -> String:
	if v == null:
		return "-"
	var r: Resource = v as Resource
	if r == null:
		return str(v)
	var id: Variant = r.get(&"id")
	if id != null and str(id) != "":
		return str(id)
	return r.resource_path.get_file().get_basename() if r.resource_path != "" else "(embutido)"

## Linhas em que o id, o nome ou alguma célula contém `query` (sem distinguir caixa; vazio = todas).
static func filter(all_rows: Array[Dictionary], query: String) -> Array[Dictionary]:
	var q: String = query.strip_edges().to_lower()
	if q == "":
		return all_rows
	var out: Array[Dictionary] = []
	for r: Dictionary in all_rows:
		for cell: String in (r["cells"] as PackedStringArray):
			if cell.to_lower().contains(q):
				out.append(r)
				break
	return out

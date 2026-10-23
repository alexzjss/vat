class_name ContentBundle
extends RefCounted

## O que os validadores recebem (M16): tudo já carregado, sem IO. Quem varre o disco monta o pacote
## (tools/validate/content_loader.gd); os testes montam um em memória.

## Recursos de conteúdo (defs, perfis, tabelas, SpriteSets, eventos embutidos), cada um com `resource_path`.
var resources: Array = []
## `.roteiro`: caminho -> texto.
var roteiros: Dictionary[String, String] = {}
## Mapas da fatia por id: {path: String, markers: Array[StringName], refs: Array[Dictionary]}.
## Cada ref: {what: String, target_map: StringName, target_spawn: StringName}.
var maps: Dictionary[StringName, Dictionary] = {}

## Resumo de um mapa para [member maps].
static func map_info(path: String, markers: Array[StringName], refs: Array[Dictionary]) -> Dictionary:
	return {"path": path, "markers": markers, "refs": refs}

## Referência de mapa para `refs`.
static func map_ref(what: String, target_map: StringName, target_spawn: StringName) -> Dictionary:
	return {"what": what, "target_map": target_map, "target_spawn": target_spawn}

## Os recursos que são de `type` (por is).
func of_type(type: Variant) -> Array:
	var out: Array = []
	for r: Variant in resources:
		if is_instance_of(r, type):
			out.append(r)
	return out

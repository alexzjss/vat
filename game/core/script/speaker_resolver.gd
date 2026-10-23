class_name SpeakerResolver
extends RefCounted

## Resolve o nome de quem fala (texto do roteiro) para a arte do retrato (M16). Puro: quem chama entrega as listas.
## Ordem: herói cujo `display_name` é igual ao nome -> `SpeakerDef` cujo `id` ou `display_name` é igual.
## Só conta o conjunto que tem retratos; sem retratos (ou nome vazio/desconhecido) devolve null e a caixa fica como sempre.

## Expressão usada quando a fala não pede uma (ou pede uma que o conjunto não tem).
const DEFAULT_EXPRESSION: StringName = &"neutro"

static func resolve(speaker: String, heroes: Array[CharacterDef], speakers: Array[SpeakerDef]) -> SpriteSet:
	if speaker == "":
		return null
	for h: CharacterDef in heroes:
		if h != null and h.display_name == speaker:
			return h.sprites if _has_portraits(h.sprites) else null
	for s: SpeakerDef in speakers:
		if s != null and (s.display_name == speaker or String(s.id) == speaker):
			return s.sprites if _has_portraits(s.sprites) else null
	return null

## O retrato da expressão `expression`; vazia ou ausente cai em `neutro`; null se nem `neutro` existe.
static func portrait_of(art: SpriteSet, expression: StringName) -> Texture2D:
	if art == null:
		return null
	if expression != &"" and art.portraits.has(expression):
		return art.portraits[expression]
	return art.portraits.get(DEFAULT_EXPRESSION)

static func _has_portraits(art: SpriteSet) -> bool:
	return art != null and not art.portraits.is_empty()

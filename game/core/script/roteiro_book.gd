class_name RoteiroBook
extends Resource

## Um arquivo `.roteiro` compilado (M16): vários eventos, cada um por id.
@export var events: Dictionary[StringName, EventScript] = {}

## O evento efetivo de um nó: o do roteiro (`book` + `id`) vale sobre o `.tres` (`fallback`) quando os dois existem.
## Sem roteiro, devolve `fallback`. Um `id` que o livro não tem registra erro e cai no `fallback` (pode ser null).
static func pick(book: RoteiroBook, id: StringName, fallback: EventScript, owner_name: String = "") -> EventScript:
	if book == null:
		return fallback
	var ev: EventScript = book.events.get(id) as EventScript
	if ev == null:
		push_error("%s: o roteiro '%s' não tem o evento '%s'" % [owner_name, book.resource_path.get_file(), id])
		return fallback
	return ev

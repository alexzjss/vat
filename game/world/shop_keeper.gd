class_name ShopKeeper
extends Npc

## Lojista (M12): NPC que, ao interagir, abre a loja `shop` (o mapa pede ao Game; o mapa fica congelado enquanto aberta).
## `greeting` (opcional): falas mostradas na caixa de diálogo antes da loja; a loja abre quando o evento termina
## (LocalMap.event_finished). Sem falas, abre direto. Com `roteiro` + `event_id` (M16), o evento do roteiro faz o papel
## do `greeting` (o roteiro vale sobre as falas).

@export var shop: ShopDef
@export var greeting: PackedStringArray = PackedStringArray()

func _activate() -> void:
	interacted.emit()
	var m: LocalMap = LocalMap.map_of(self)
	if m == null or shop == null:
		return
	var ev: EventScript = null
	if roteiro != null:
		ev = effective_event()
	elif not greeting.is_empty():
		var steps: Array[EventStep] = []
		for line: String in greeting:
			steps.append(EventScript.say(line, display_name))
		ev = EventScript.of(steps)
	if ev == null:
		m.request_shop(shop)
		return
	# Ligação de uma vez só, desfeita se o mapa recusar o evento. Evento cancelado (Game Over, troca de mapa): o mapa
	# está travado ou sai da árvore, e request_shop recusa.
	var after: Callable = _open_shop.bind(m)
	m.event_finished.connect(after, CONNECT_ONE_SHOT)
	if not m.run_event(ev):
		m.event_finished.disconnect(after)

func _open_shop(m: LocalMap) -> void:
	if is_instance_valid(m) and m.is_inside_tree():
		m.request_shop(shop)

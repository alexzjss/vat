class_name ShopKeeper
extends Npc

## Lojista (M12): NPC que, ao interagir, abre a loja `shop` (o mapa pede ao Game; o mapa fica congelado enquanto aberta).

@export var shop: ShopDef

func _activate() -> void:
	interacted.emit()
	var m: LocalMap = LocalMap.map_of(self)
	if m != null and shop != null:
		m.request_shop(shop)

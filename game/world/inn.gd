class_name Inn
extends Interactable

## Pousada (M12): balcão que, ao interagir, abre o descanso pago (BalanceConfig.inn_price): cura o grupo e abre os slots
## de save. `spawn_name` é o marcador do mapa gravado no save feito aqui (como no ponto de descanso).

@export var spawn_name: StringName = &"InnSpawn"

const COLOR: Color = Color(0.45, 0.3, 0.55)

func _init() -> void:
	solid = true
	prompt = "Pousada"

func _activate() -> void:
	interacted.emit()
	var m: LocalMap = LocalMap.map_of(self)
	if m != null:
		m.request_inn()

func _draw() -> void:
	draw_rect(Rect2(-24, -10, 48, 22), COLOR)
	draw_rect(Rect2(-24, -10, 48, 6), COLOR.lightened(0.2))

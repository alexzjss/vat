class_name EventTrigger
extends Area2D

## Gatilho de evento (M10): roda `event` quando o jogador entra na área; com `once_flag`, só uma vez
## (a flag fica gravada, então vale também para o mapa reinstanciado e o save).

@export var event: EventScript
## Alternativa ao `event` (M16): o evento `event_id` de um `.roteiro` importado. Se os dois estiverem definidos, vale o roteiro.
@export var roteiro: RoteiroBook
@export var event_id: StringName = &""
@export var once_flag: StringName = &""
## Cena de pós-batalha (M12): só roda depois que o encontro com esse `unique_id` foi derrotado (vazio = sem exigência).
@export var requires_defeated: StringName = &""
@export var size: Vector2 = Vector2(48, 120)

func _init() -> void:
	collision_layer = 0
	collision_mask = 2

func _ready() -> void:
	if get_children().is_empty():
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = size
		cs.shape = rect
		add_child(cs)
	body_entered.connect(_on_body_entered)

## O disparo foi recusado (mapa ocupado) com o jogador na área: tenta de novo enquanto ele ficar.
var _pending: bool = false

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not trigger():
		_pending = true

func _process(_delta: float) -> void:
	if not _pending:
		return
	var inside: bool = false
	for b: Node2D in get_overlapping_bodies():
		inside = inside or b is Player
	var map: LocalMap = LocalMap.map_of(self)
	var done: bool = once_flag != &"" and map != null and map.state != null and map.state.get_flag(once_flag) != 0
	if not inside or done or trigger():
		_pending = false

## O evento que roda: o do roteiro, se houver, senão o `event`.
func effective_event() -> EventScript:
	return RoteiroBook.pick(roteiro, event_id, event, String(name))

## Roda o evento agora. False se já rodou (once_flag) ou se o mapa está ocupado.
func trigger() -> bool:
	var map: LocalMap = LocalMap.map_of(self)
	if map == null or map.state == null:
		return false
	var ev: EventScript = effective_event()
	if ev == null:
		return false
	if once_flag != &"" and map.state.get_flag(once_flag) != 0:
		return false
	if requires_defeated != &"" and not map.state.is_defeated(requires_defeated):
		return false
	if not map.run_event(ev):
		return false
	if once_flag != &"":
		map.state.set_flag(once_flag, 1)
	return true

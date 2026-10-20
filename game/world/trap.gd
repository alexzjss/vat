class_name Trap
extends Area2D

## Armadilha de piso (M10): ao pisar, ou tira `damage_pct` do HP máximo dos ativos (sem matar: mínimo 1 HP) ou, com
## `encounter`, inicia essa batalha. `once_flag` (opcional) a desarma depois do primeiro disparo; fica gravada na
## flag, então o mapa reinstanciado, o save e o restore a refletem. Armada, pisca.

@export var encounter: EncounterDef
## Fração do HP máximo; negativo = BalanceConfig.trap_damage_pct.
@export var damage_pct: float = -1.0
@export var once_flag: StringName = &""
@export var size: Vector2 = Vector2(48, 48)
@export var message: String = "Uma armadilha disparou!"

var _time: float = 0.0
## O disparo foi recusado (mapa ocupado) com o jogador na área: tenta de novo enquanto ele ficar.
var _pending: bool = false

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

func _process(delta: float) -> void:
	_time += delta
	modulate.a = (0.5 + 0.5 * sin(_time * 6.0)) * 0.6 + 0.4 if armed() else 0.25
	queue_redraw()
	if _pending:
		_retry_pending()

func _retry_pending() -> void:
	if not armed() or not _player_inside():
		_pending = false
	elif trigger():
		_pending = false

func _player_inside() -> bool:
	for b: Node2D in get_overlapping_bodies():
		if b is Player:
			return true
	return false

## Ainda dispara? (desarmada depois do primeiro disparo, se tem once_flag)
func armed() -> bool:
	var s: GameState = LocalMap.state_of(self)
	return s == null or once_flag == &"" or s.get_flag(once_flag) == 0

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not trigger():
		_pending = true

## Dispara agora (também chamado pelos testes). False se desarmada ou se o mapa está ocupado.
func trigger() -> bool:
	var map: LocalMap = LocalMap.map_of(self)
	if map == null or map.state == null or not armed():
		return false
	var steps: Array[EventStep] = []
	steps.append(EventScript.say(message))
	if encounter != null:
		var sb := StartBattleStep.new()
		sb.encounter = encounter
		steps.append(sb)
	if not map.run_event(EventScript.of(steps)):
		return false
	if once_flag != &"":
		map.state.set_flag(once_flag, 1)
	if encounter == null:
		var pct: float = damage_pct if damage_pct >= 0.0 else map.state.cfg.trap_damage_pct
		TrapRules.apply(map.state, pct)
	return true

func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	draw_rect(r, Color(0.8, 0.15, 0.15, 0.5))
	var step: float = size.x / 4.0
	for i: int in 4:
		var x: float = r.position.x + step * (float(i) + 0.5)
		draw_colored_polygon(PackedVector2Array([Vector2(x - step * 0.4, r.end.y - 4.0), Vector2(x, r.position.y + 4.0), Vector2(x + step * 0.4, r.end.y - 4.0)]), Color(0.9, 0.9, 0.9))

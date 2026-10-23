class_name Interactable
extends Area2D

## Objeto do mapa que reage à tecla `interact` com o jogador dentro da sua área (M10).
## Quem roteia a tecla é a LocalMap: entre os interagíveis ao alcance, aciona o mais próximo do jogador
## ([method LocalMap.try_interact]). `event` (opcional) é pedido ao Game por [signal event_requested];
## [signal interacted] avisa quem quer reagir à interação (ex.: o ponto de descanso).
## Subclasses sobrescrevem [method _activate].

signal interacted
signal event_requested(event: EventScript)

## Texto curto exibido sobre o objeto quando o jogador pode interagir (vazio = sem aviso).
@export var prompt: String = ""
@export var event: EventScript
## Alternativa ao `event` (M16): o evento `event_id` de um `.roteiro` importado. Se os dois estiverem definidos, vale o roteiro.
@export var roteiro: RoteiroBook
@export var event_id: StringName = &""
## Bloqueia a passagem do jogador (NPCs, placas).
@export var solid: bool = false

## Quem pode usar o objeto (o LocalMap liga o jogador).
var player: Node2D
## Desligado durante batalha/transições (o mapa avisa).
var enabled: bool = true

var _prompt_label: Label

## Dentro da área? Medido pela posição do jogador (e não por sinais de física): um mapa congelado
## com o menu aberto não dispara body_exited, mas o estado também não depende disso.
var player_inside: bool:
	get:
		return player != null and _shape_rect().has_point(to_local(player.global_position))

func _init() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

func _ready() -> void:
	if solid:
		_add_blocker()
	if prompt != "":
		_prompt_label = Label.new()
		_prompt_label.text = prompt
		_prompt_label.position = Vector2(-40, -48)
		_prompt_label.visible = false
		_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_prompt_label)

func _process(_delta: float) -> void:
	if _prompt_label != null:
		_prompt_label.visible = can_interact() and not map_busy()

## O mapa está ocupado (batalha, evento ou travado)? Os avisos na tela somem; a mesma condição de LocalMap.try_interact.
func map_busy() -> bool:
	var m: LocalMap = LocalMap.map_of(self)
	return m != null and m.is_busy()

func can_interact() -> bool:
	return enabled and player_inside

## Aciona o objeto; false se não puder agora (desligado ou jogador fora da área).
func interact() -> bool:
	if not can_interact():
		return false
	_activate()
	return true

## Compatível com o ponto de descanso: os testes chamam direto.
func request() -> bool:
	return interact()

func _activate() -> void:
	interacted.emit()
	var ev: EventScript = effective_event()
	if ev != null:
		event_requested.emit(ev)

## O evento que roda: o do roteiro, se houver, senão o `event`.
func effective_event() -> EventScript:
	return RoteiroBook.pick(roteiro, event_id, event, String(name))

## Estado do jogo do mapa (null antes do setup). Objetos de dungeon guardam tudo em flags dele.
func game_state() -> GameState:
	return LocalMap.state_of(self)

## Pede um roteiro montado em código (e avisa `interacted`).
func _run_script(script: EventScript) -> void:
	interacted.emit()
	event_requested.emit(script)

func _add_blocker() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

func _shape_rect() -> Rect2:
	for child: Node in get_children():
		var cs := child as CollisionShape2D
		if cs != null and cs.shape is RectangleShape2D:
			var size: Vector2 = (cs.shape as RectangleShape2D).size
			return Rect2(cs.position - size / 2.0, size)
	return Rect2(-48, -48, 96, 96)

class_name PartyFollowers
extends Node2D

## Ativos 2..4 em fila atrás do líder (só nas áreas locais). Só visual, sem colisão.
## O número de quadrados acompanha state.heroes.size() a cada quadro (formação pode mudar no menu).

const SIZE: float = 28.0
const COLOR: Color = Color(0.25, 0.45, 0.95)

var state: GameState
var leader: Node2D
var trail: FollowTrail
var active: bool = true:
	set(v):
		active = v
		visible = v
		queue_redraw()

func setup(game_state: GameState, p_leader: Node2D) -> void:
	state = game_state
	leader = p_leader
	trail = FollowTrail.new(state.cfg.follow_spacing, state.cfg.follow_gap, leader.global_position)

## Esconde os seguidores (batalha, fade).
func hide_all() -> void:
	active = false

## Volta a mostrar; o rastro recomeça na posição do líder.
func restart() -> void:
	if trail != null and leader != null:
		trail.reset(leader.global_position)
	active = true

func count() -> int:
	return maxi(0, state.heroes.size() - 1) if state != null else 0

## Posição do seguidor k (1..3) em coordenadas globais.
func follower_position(k: int) -> Vector2:
	return trail.position_of(k)

func _physics_process(_delta: float) -> void:
	if not active or trail == null or leader == null:
		return
	trail.push(leader.global_position)
	trail.trim(GameState.MAX_ACTIVE - 1)
	queue_redraw()

func _draw() -> void:
	if not active or trail == null or state == null:
		return
	var font: Font = ThemeDB.fallback_font
	for k: int in range(1, count() + 1):
		var p: Vector2 = to_local(follower_position(k))
		draw_rect(Rect2(p - Vector2(SIZE, SIZE) / 2.0, Vector2(SIZE, SIZE)), COLOR)
		var letter: String = Player.leader_initial(state.heroes[k].def.display_name)
		var w: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, p + Vector2(-w / 2.0, 7), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

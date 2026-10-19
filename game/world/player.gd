class_name Player
extends CharacterBody2D

var cfg: BalanceConfig
var enabled: bool = true
## Se finito, substitui o input (testes e demo).
var override_dir: Vector2 = Vector2.INF
## Letra do líder desenhada no quadrado (vazia = sem rótulo).
var leader_letter: String = ""

static func velocity_for(dir: Vector2, speed: float) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	return dir.normalized() * speed

func input_dir() -> Vector2:
	if override_dir.is_finite():
		return override_dir
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _physics_process(_delta: float) -> void:
	if enabled and cfg != null:
		velocity = velocity_for(input_dir(), cfg.player_speed)
		move_and_slide()
	else:
		velocity = Vector2.ZERO

## O marcador representa o líder: inicial da última palavra do nome ("Teste D" → "D").
func set_leader(h: HeroState) -> void:
	leader_letter = Player.leader_initial(h.def.display_name) if h != null else ""
	queue_redraw()

static func leader_initial(display_name: String) -> String:
	var words: PackedStringArray = display_name.strip_edges().split(" ", false)
	return words[words.size() - 1].left(1).to_upper() if not words.is_empty() else ""

func _draw() -> void:
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.25, 0.5, 0.95))
	if leader_letter != "":
		var font: Font = ThemeDB.fallback_font
		var size: int = 22
		var w: float = font.get_string_size(leader_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, Vector2(-w / 2.0, 8), leader_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)

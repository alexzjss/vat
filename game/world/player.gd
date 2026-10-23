class_name Player
extends CharacterBody2D

var cfg: BalanceConfig
var enabled: bool = true
## Se finito, substitui o input (testes e demo).
var override_dir: Vector2 = Vector2.INF
## Letra do líder desenhada no quadrado (vazia = sem rótulo).
var leader_letter: String = ""
## 0/1 substitui o input de correr (testes e demo); -1 usa o input real.
var override_run: int = -1
## Sprite de mapa (M16) quando o líder tem `sprites` com folha de mapa; null = o quadrado de sempre.
var map_sprite: MapSprite

## Os pés do sprite ficam na borda de baixo do quadrado geométrico (y = +16); a colisão (28x28) não muda.
const FEET_Y: float = 16.0

static func velocity_for(dir: Vector2, speed: float) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	return dir.normalized() * speed

## Segurando correr (ação `run`) ou forçado por override_run.
func is_running() -> bool:
	if override_run >= 0:
		return override_run == 1
	return Input.is_action_pressed("run")

## Velocidade de caminhada ou de corrida (cfg.run_mult).
static func speed_for(cfg: BalanceConfig, running: bool) -> float:
	return cfg.player_speed * (cfg.run_mult if running else 1.0)

func input_dir() -> Vector2:
	if override_dir.is_finite():
		return override_dir
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _physics_process(_delta: float) -> void:
	if enabled and cfg != null:
		velocity = velocity_for(input_dir(), Player.speed_for(cfg, is_running()))
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	if map_sprite != null:
		map_sprite.apply_motion(get_real_velocity())

## O marcador representa o líder: inicial da última palavra do nome ("Teste D" → "D").
func set_leader(h: HeroState) -> void:
	leader_letter = Player.leader_initial(h.def.display_name) if h != null else ""
	set_sprites(h.def.sprites if h != null else null)
	queue_redraw()

## Troca a arte de mapa (null ou sem folha = volta ao quadrado). Mantém a direção que o jogador olhava.
func set_sprites(sprites: SpriteSet) -> void:
	var facing: SpriteSet.Facing = map_sprite.facing if map_sprite != null else SpriteSet.Facing.DOWN
	if map_sprite != null:
		map_sprite.queue_free()
		map_sprite = null
	map_sprite = MapSprite.create(sprites, FEET_Y)
	if map_sprite != null:
		map_sprite.facing = facing
		add_child(map_sprite)
		map_sprite.apply_motion(Vector2.ZERO)
	queue_redraw()

static func leader_initial(display_name: String) -> String:
	var words: PackedStringArray = display_name.strip_edges().split(" ", false)
	return words[words.size() - 1].left(1).to_upper() if not words.is_empty() else ""

func _draw() -> void:
	if map_sprite != null:
		return
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.25, 0.5, 0.95))
	if leader_letter != "":
		var font: Font = ThemeDB.fallback_font
		var size: int = 22
		var w: float = font.get_string_size(leader_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, Vector2(-w / 2.0, 8), leader_letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)

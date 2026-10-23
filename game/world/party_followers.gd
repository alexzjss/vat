class_name PartyFollowers
extends Node2D

## Ativos 2..4 em fila atrás do líder (só nas áreas locais). Só visual, sem colisão.
## O número de quadrados acompanha state.heroes.size() a cada quadro (formação pode mudar no menu).

const SIZE: float = 28.0
const COLOR: Color = Color(0.25, 0.45, 0.95)

## Com arte de mapa (M16) o seguidor k vira um Node2D com um MapSprite (os pés na borda de baixo do quadrado, y = +SIZE/2);
## sem arte continua o quadrado. Chave = k (1..3); `_set_of` guarda o SpriteSet de cada um para reconstruir se o herói mudar.
var _holders: Dictionary[int, Node2D] = {}
var _sprites: Dictionary[int, MapSprite] = {}
var _set_of: Dictionary[int, SpriteSet] = {}
var _last_pos: Dictionary[int, Vector2] = {}
## O rastro anda em saltos (uma amostra a cada `follow_spacing` px); o seguidor continua "andando" por este tempo
## depois de cada salto, para a animação não piscar entre andar e parar.
var _hold: Dictionary[int, float] = {}

const WALK_HOLD: float = 0.3

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

func _physics_process(delta: float) -> void:
	if not active or trail == null or leader == null:
		return
	trail.push(leader.global_position)
	trail.trim(GameState.MAX_ACTIVE - 1)
	_sync_sprites(delta)
	queue_redraw()

## O MapSprite do seguidor k (null = sem arte, desenha o quadrado).
func sprite_of(k: int) -> MapSprite:
	return _sprites.get(k) as MapSprite

func _sync_sprites(delta: float) -> void:
	if state == null:
		return
	for k: int in range(1, GameState.MAX_ACTIVE):
		var want: SpriteSet = null
		if k <= count():
			var s: SpriteSet = state.heroes[k].def.sprites
			want = s if s != null and s.has_map_art() else null
		if _set_of.get(k) != want:
			_drop_sprite(k)
			if want != null:
				var holder: Node2D = Node2D.new()
				var ms: MapSprite = MapSprite.create(want, SIZE / 2.0)
				holder.add_child(ms)
				add_child(holder)
				_holders[k] = holder
				_sprites[k] = ms
				_last_pos[k] = to_local(follower_position(k))
			_set_of[k] = want
		if want != null:
			var p: Vector2 = to_local(follower_position(k))
			_holders[k].position = p
			var jump: Vector2 = p - _last_pos[k]
			if jump != Vector2.ZERO:
				_hold[k] = WALK_HOLD
				_sprites[k].apply_motion(jump)
			else:
				_hold[k] = maxf(0.0, _hold.get(k, 0.0) - delta)
				if _hold[k] <= 0.0:
					_sprites[k].apply_motion(Vector2.ZERO)
			_last_pos[k] = p

func _drop_sprite(k: int) -> void:
	if _holders.has(k):
		_holders[k].queue_free()
	_holders.erase(k)
	_sprites.erase(k)
	_last_pos.erase(k)
	_hold.erase(k)
	_set_of.erase(k)

func _draw() -> void:
	if not active or trail == null or state == null:
		return
	var font: Font = ThemeDB.fallback_font
	for k: int in range(1, count() + 1):
		if _sprites.has(k):
			continue
		var p: Vector2 = to_local(follower_position(k))
		draw_rect(Rect2(p - Vector2(SIZE, SIZE) / 2.0, Vector2(SIZE, SIZE)), COLOR)
		var letter: String = Player.leader_initial(state.heroes[k].def.display_name)
		var w: float = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(font, p + Vector2(-w / 2.0, 7), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)

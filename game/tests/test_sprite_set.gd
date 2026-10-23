extends GutTest

var root: Node2D

func before_each() -> void:
	root = Node2D.new()
	add_child_autofree(root)

static func _tex(w: int, h: int) -> Texture2D:
	return ImageTexture.create_from_image(Image.create_empty(w, h, false, Image.FORMAT_RGBA8))

static func _set_with_map() -> SpriteSet:
	var s: SpriteSet = SpriteSet.new()
	s.map_sheet = _tex(96, 192)
	return s

func _make_player() -> Player:
	var player: Player = (load("res://world/player.tscn") as PackedScene).instantiate() as Player
	player.cfg = BalanceConfig.new()
	player.override_dir = Vector2.ZERO
	root.add_child(player)
	return player

func _anim_sprites(n: Node) -> Array[AnimatedSprite2D]:
	var out: Array[AnimatedSprite2D] = []
	for c: Node in n.get_children():
		if c is AnimatedSprite2D and not c.is_queued_for_deletion():
			out.append(c as AnimatedSprite2D)
	return out

# --- SpriteSet puro ---

func test_defaults() -> void:
	var s: SpriteSet = SpriteSet.new()
	assert_eq(s.map_frame, Vector2i(32, 48))
	assert_eq(s.battle_frame, Vector2i(64, 64))
	assert_eq(s.portrait_size, Vector2i(96, 96))
	assert_eq(s.walk_frames, 3)
	assert_eq(s.walk_fps, 8.0)
	for anim: StringName in [&"idle", &"attack", &"cast", &"hit", &"down", &"victory"]:
		assert_true(s.anims.has(anim), String(anim))
	assert_true(SpriteSet.loops(&"idle"))
	assert_true(SpriteSet.loops(&"victory"))
	assert_false(SpriteSet.loops(&"attack"))
	assert_eq(s.validate().size(), 0, "tudo opcional: sem folhas nao ha erro")

func test_map_frames_per_direction() -> void:
	var s: SpriteSet = SpriteSet.new()
	var down: Array[Rect2i] = s.map_frames(SpriteSet.Facing.DOWN)
	assert_eq(down.size(), 3)
	assert_eq(down[0], Rect2i(0, 0, 32, 48))
	assert_eq(down[2], Rect2i(64, 0, 32, 48))
	assert_eq(s.map_frames(SpriteSet.Facing.LEFT)[1], Rect2i(32, 48, 32, 48))
	assert_eq(s.map_frames(SpriteSet.Facing.RIGHT)[0], Rect2i(0, 96, 32, 48))
	assert_eq(s.map_frames(SpriteSet.Facing.UP)[2], Rect2i(64, 144, 32, 48))
	assert_eq(s.idle_index(), 1)

func test_map_frames_respects_custom_size() -> void:
	var s: SpriteSet = SpriteSet.new()
	s.map_frame = Vector2i(16, 24)
	s.walk_frames = 4
	var r: Array[Rect2i] = s.map_frames(SpriteSet.Facing.RIGHT)
	assert_eq(r.size(), 4)
	assert_eq(r[3], Rect2i(48, 48, 16, 24))

func test_battle_frames() -> void:
	var s: SpriteSet = SpriteSet.new()
	var idle: Array[Rect2i] = s.battle_frames(&"idle")
	assert_eq(idle.size(), 4)
	assert_eq(idle[0], Rect2i(0, 0, 64, 64))
	var hit: Array[Rect2i] = s.battle_frames(&"hit")
	assert_eq(hit.size(), 2)
	assert_eq(hit[1], Rect2i(64, 192, 64, 64))
	assert_eq(s.battle_frames(&"nao_existe").size(), 0)
	assert_eq(s.battle_fps(&"attack"), 12.0)

func test_facing_from_direction() -> void:
	assert_eq(SpriteSet.facing_from(Vector2(0, 1)), SpriteSet.Facing.DOWN)
	assert_eq(SpriteSet.facing_from(Vector2(0, -1)), SpriteSet.Facing.UP)
	assert_eq(SpriteSet.facing_from(Vector2(-1, 0.2)), SpriteSet.Facing.LEFT)
	assert_eq(SpriteSet.facing_from(Vector2(1, -0.2)), SpriteSet.Facing.RIGHT)
	assert_eq(SpriteSet.facing_from(Vector2.ZERO, SpriteSet.Facing.LEFT), SpriteSet.Facing.LEFT, "parado mantem")

func test_validate_ok_and_bad_sizes() -> void:
	var ok: SpriteSet = _set_with_map()
	assert_eq(ok.validate().size(), 0)
	var bad: SpriteSet = SpriteSet.new()
	bad.map_sheet = _tex(100, 192)
	assert_gt(bad.validate().size(), 0, "100 nao e multiplo de 32")
	var short: SpriteSet = SpriteSet.new()
	short.map_sheet = _tex(96, 96)
	assert_gt(short.validate().size(), 0, "faltam linhas")
	var narrow: SpriteSet = SpriteSet.new()
	narrow.map_sheet = _tex(64, 192)
	assert_gt(narrow.validate().size(), 0, "3 quadros nao cabem em 64")

func test_validate_anim_outside_sheet() -> void:
	var s: SpriteSet = SpriteSet.new()
	s.battle_sheet = _tex(256, 384)
	assert_eq(s.validate().size(), 0, "6 linhas de 4 quadros cabem")
	s.anims[&"super"] = Vector3i(6, 4, 8)
	var errs: Array[String] = s.validate()
	assert_eq(errs.size(), 1)
	assert_true(errs[0].contains("super"))
	s.anims.erase(&"super")
	s.anims[&"largo"] = Vector3i(0, 5, 8)
	assert_eq(s.validate().size(), 1, "5 quadros nao cabem em 256 px")

# --- Jogador ---

func test_player_with_sprites_builds_animated_sprite() -> void:
	var player: Player = _make_player()
	assert_eq(_anim_sprites(player).size(), 0)
	player.set_sprites(_set_with_map())
	assert_eq(_anim_sprites(player).size(), 1)
	assert_not_null(player.map_sprite)
	assert_eq(player.map_sprite.animation, &"idle_down")
	# Os pes na borda de baixo do quadrado geometrico (y = 16); quadro 32x48 centrado em x.
	var ms: MapSprite = player.map_sprite
	assert_eq(ms.position, Vector2(-16, 16 - 48))
	assert_false(ms.centered)
	assert_eq(ms.sprite_frames.get_frame_count(&"walk_down"), 3)
	assert_eq(ms.sprite_frames.get_frame_count(&"idle_down"), 1)
	var idle: AtlasTexture = ms.sprite_frames.get_frame_texture(&"idle_down", 0) as AtlasTexture
	assert_eq(idle.region, Rect2(32, 0, 32, 48), "o quadro do meio e o parado")

func test_player_animation_follows_direction_and_keeps_facing() -> void:
	var player: Player = _make_player()
	player.set_sprites(_set_with_map())
	player.override_dir = Vector2.RIGHT
	await wait_physics_frames(3)
	assert_eq(player.map_sprite.animation, &"walk_right")
	assert_true(player.map_sprite.is_playing())
	player.override_dir = Vector2.LEFT
	await wait_physics_frames(3)
	assert_eq(player.map_sprite.animation, &"walk_left")
	player.override_dir = Vector2.UP
	await wait_physics_frames(3)
	assert_eq(player.map_sprite.animation, &"walk_up")
	player.override_dir = Vector2.DOWN
	await wait_physics_frames(3)
	assert_eq(player.map_sprite.animation, &"walk_down")
	player.override_dir = Vector2.LEFT
	await wait_physics_frames(3)
	player.override_dir = Vector2.ZERO
	await wait_physics_frames(3)
	assert_eq(player.map_sprite.animation, &"idle_left", "parado mantem a ultima direcao")

func test_player_blocked_by_wall_goes_idle() -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = 1
	var cs: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(20, 200)
	cs.shape = shape
	wall.add_child(cs)
	wall.position = Vector2(60, 0)
	root.add_child(wall)
	var player: Player = _make_player()
	player.set_sprites(_set_with_map())
	player.override_dir = Vector2.RIGHT
	await wait_physics_frames(60)
	assert_eq(player.map_sprite.animation, &"idle_right")

func test_player_without_sprites_keeps_geometric_draw() -> void:
	var player: Player = _make_player()
	assert_null(player.map_sprite)
	assert_eq(_anim_sprites(player).size(), 0)
	var h: HeroState = HeroState.new()
	h.def = Fixtures.hero_def(&"sem_arte", Stats.new())
	player.set_leader(h)
	assert_eq(_anim_sprites(player).size(), 0)
	assert_eq(player.leader_letter, "S")
	# Sprites sem folha de mapa tambem cai no quadrado.
	player.set_sprites(SpriteSet.new())
	assert_null(player.map_sprite)
	assert_eq(_anim_sprites(player).size(), 0)

func test_player_set_leader_uses_hero_sprites_and_reverts() -> void:
	var player: Player = _make_player()
	var h: HeroState = HeroState.new()
	h.def = Fixtures.hero_def(&"com_arte", Stats.new())
	h.def.sprites = _set_with_map()
	player.set_leader(h)
	assert_not_null(player.map_sprite)
	var h2: HeroState = HeroState.new()
	h2.def = Fixtures.hero_def(&"sem_arte", Stats.new())
	player.set_leader(h2)
	assert_null(player.map_sprite)
	await wait_physics_frames(2)
	assert_eq(_anim_sprites(player).size(), 0, "o sprite antigo saiu")

func test_collision_shape_unchanged_with_sprites() -> void:
	var player: Player = _make_player()
	var before: Vector2 = ((player.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
	player.set_sprites(_set_with_map())
	var after: Vector2 = ((player.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
	assert_eq(before, Vector2(28, 28))
	assert_eq(after, before)

# --- Seguidores ---

func _followers_state(def_b: CharacterDef) -> GameState:
	var defs: Array[CharacterDef] = [Fixtures.hero_def(&"lider", Stats.new()), def_b]
	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	return GameState.new_game(Fixtures.cfg(), defs, items, counts, Dice.new(7), &"local", &"Entry")

func test_follower_with_sprites_has_animated_sprite() -> void:
	var b: CharacterDef = Fixtures.hero_def(&"seg", Stats.new())
	b.sprites = _set_with_map()
	var state: GameState = _followers_state(b)
	var leader: Node2D = Node2D.new()
	root.add_child(leader)
	var pf: PartyFollowers = PartyFollowers.new()
	root.add_child(pf)
	pf.setup(state, leader)
	await wait_physics_frames(2)
	var ms: MapSprite = pf.sprite_of(1)
	assert_not_null(ms)
	assert_eq(ms.position, Vector2(-16, PartyFollowers.SIZE / 2.0 - 48))
	# O lider anda para a direita; o seguidor vira para la.
	for i: int in 30:
		leader.global_position += Vector2(4, 0)
		pf._physics_process(1.0 / 60.0)
	assert_eq(ms.animation, &"walk_right")
	for i: int in 30:
		pf._physics_process(1.0 / 60.0)
	assert_eq(ms.animation, &"idle_right")

func test_follower_without_sprites_has_none() -> void:
	var state: GameState = _followers_state(Fixtures.hero_def(&"seg", Stats.new()))
	var leader: Node2D = Node2D.new()
	root.add_child(leader)
	var pf: PartyFollowers = PartyFollowers.new()
	root.add_child(pf)
	pf.setup(state, leader)
	await wait_physics_frames(2)
	assert_null(pf.sprite_of(1))
	assert_eq(pf.get_child_count(), 0)

# --- NPC e inimigo do mapa ---

func test_npc_with_speaker_sprites() -> void:
	var npc: Npc = Npc.new()
	var spk: SpeakerDef = SpeakerDef.new()
	spk.id = &"morador"
	spk.sprites = _set_with_map()
	npc.speaker = spk
	root.add_child(npc)
	assert_not_null(npc.map_sprite)
	assert_eq(_anim_sprites(npc).size(), 1)
	assert_eq(npc.map_sprite.position, Vector2(-16, Npc.FEET_Y - 48))
	# Movido por MoveActor: vira para onde anda.
	for i: int in 10:
		npc.global_position += Vector2(0, -3)
		npc._physics_process(1.0 / 60.0)
	assert_eq(npc.map_sprite.animation, &"walk_up")
	npc._physics_process(1.0 / 60.0)
	assert_eq(npc.map_sprite.animation, &"idle_up")

func test_npc_without_speaker_has_no_sprite() -> void:
	var npc: Npc = Npc.new()
	root.add_child(npc)
	assert_null(npc.map_sprite)
	assert_eq(_anim_sprites(npc).size(), 0)

func test_map_enemy_uses_first_enemy_sprites() -> void:
	var e1: EnemyDef = Fixtures.enemy_def(&"e1", Stats.new())
	var e2: EnemyDef = Fixtures.enemy_def(&"e2", Stats.new())
	e2.sprites = _set_with_map()
	var enc: EncounterDef = EncounterDef.new()
	enc.enemies = [e1, e2]
	var enemy: MapEnemy = (load("res://world/map_enemy.tscn") as PackedScene).instantiate() as MapEnemy
	enemy.encounter = enc
	enemy.region = Rect2(0, 0, 200, 120)
	enemy.setup(BalanceConfig.new(), Dice.new(5))
	root.add_child(enemy)
	assert_not_null(enemy.map_sprite)
	assert_eq(enemy.map_sprite.position, Vector2(-16, MapEnemy.FEET_Y - 48))
	var plain: MapEnemy = (load("res://world/map_enemy.tscn") as PackedScene).instantiate() as MapEnemy
	plain.encounter = EncounterDef.new()
	plain.region = Rect2(0, 0, 200, 120)
	plain.setup(BalanceConfig.new(), Dice.new(5))
	root.add_child(plain)
	assert_null(plain.map_sprite)

# --- Dados de exemplo ---

func test_example_art_is_wired_and_valid() -> void:
	var hero: CharacterDef = load("res://data/fatia/heroes/teste_a_f.tres") as CharacterDef
	assert_not_null(hero.sprites)
	assert_eq(hero.sprites.validate().size(), 0)
	assert_eq(hero.sprites.map_sheet.get_size(), Vector2(96, 192))
	var spk: SpeakerDef = load("res://art/_exemplo/morador_a_exemplo.tres") as SpeakerDef
	assert_eq(spk.display_name, "Morador A")
	assert_eq(spk.sprites.validate().size(), 0)
	var city: Node = (load("res://world/fatia/cidade.tscn") as PackedScene).instantiate()
	autofree(city)
	var npc: Npc = city.get_node("MoradorA") as Npc
	assert_eq(npc.speaker, spk)

# --- Configuracao de pixel art ---

func test_pixel_art_project_settings() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "Nearest")
	assert_true(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"))
	assert_true(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel"))
	var defaults: Dictionary = ProjectSettings.get_setting("importer_defaults/texture") as Dictionary
	assert_eq(defaults.get("mipmaps/generate"), false, "texturas novas nascem sem mipmaps")

func test_art_pngs_import_without_mipmaps() -> void:
	var found: int = 0
	for path: String in _pngs_under("res://art"):
		found += 1
		var f: FileAccess = FileAccess.open(path + ".import", FileAccess.READ)
		assert_not_null(f, path + ".import existe")
		if f != null:
			assert_true(f.get_as_text().contains("mipmaps/generate=false"), path)
	assert_gt(found, 0)

func _pngs_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".png"):
			out.append(dir.path_join(f))
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_pngs_under(dir.path_join(d)))
	return out

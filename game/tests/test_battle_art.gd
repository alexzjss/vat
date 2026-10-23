extends GutTest

## Arte de batalha (M16): BattleSprite e CombatantView com SpriteSet. Sem folha, nada muda.

var cfg: BalanceConfig

func before_each() -> void:
	cfg = Fixtures.cfg()

static func _sheet_set(faces_right: bool = true) -> SpriteSet:
	var s: SpriteSet = SpriteSet.new()
	s.battle_sheet = ImageTexture.create_from_image(Image.create_empty(192, 384, false, Image.FORMAT_RGBA8))
	s.battle_faces_right = faces_right
	s.anims = {
		&"idle": Vector3i(0, 2, 4),
		&"attack": Vector3i(1, 3, 10),
		&"cast": Vector3i(2, 3, 8),
		&"hit": Vector3i(3, 2, 8),
		&"down": Vector3i(4, 1, 1),
		&"victory": Vector3i(5, 2, 4),
	}
	return s

func _hero_view(art: SpriteSet) -> CombatantView:
	var d: CharacterDef = Fixtures.hero_def(&"h", Stats.make(10, 10, 10, 0))
	d.sprites = art
	return _bind(Combatant.from_hero(HeroState.create(d, cfg), Vector2(100.0, 100.0)))

func _enemy_view(art: SpriteSet) -> CombatantView:
	var d: EnemyDef = Fixtures.enemy_def(&"e", Stats.make(10, 10, 10, 0))
	d.sprites = art
	return _bind(Combatant.from_enemy(d, &"e", Vector2(400.0, 100.0), cfg))

func _bind(c: Combatant) -> CombatantView:
	var v: CombatantView = CombatantView.new()
	add_child_autofree(v)
	v.bind(c, cfg)
	return v

func _action(actor: Combatant, ability: AbilityDef, item: ItemDef = null) -> PendingAction:
	var a: PendingAction = PendingAction.new()
	a.actor = actor
	a.ability = ability
	a.item = item
	return a

func _status(c: Combatant, kind: StatusDef.Kind, time_left: float = 5.0) -> void:
	var st: ActiveStatus = ActiveStatus.create(Fixtures.status_def(kind, 3), &"x", 0)
	st.time_left = time_left
	c.statuses.append(st)

# --- sem arte / com arte ---

func test_no_sheet_means_no_sprite_and_the_body_is_drawn() -> void:
	var v: CombatantView = _hero_view(null)
	assert_null(v.sprite)
	assert_eq(v.get_child_count(), 0, "so a forma geometrica")
	var only_map: SpriteSet = SpriteSet.new()
	assert_null(_enemy_view(only_map).sprite, "conjunto sem folha de batalha")

func test_sheet_builds_a_battle_sprite_and_idles() -> void:
	var v: CombatantView = _hero_view(_sheet_set())
	assert_not_null(v.sprite)
	assert_eq(v.sprite.get_parent(), v)
	assert_eq(v.sprite.anim, BattleSprite.IDLE)
	assert_true(v.sprite.is_playing())
	assert_eq(v.sprite.sprite_frames.get_frame_count(&"attack"), 3)
	assert_eq(v.sprite.sprite_frames.get_animation_speed(&"attack"), 10.0)
	assert_true(v.sprite.sprite_frames.get_animation_loop(&"idle"))
	assert_false(v.sprite.sprite_frames.get_animation_loop(&"hit"))

func test_enemy_sprite_is_found_through_enemy_def() -> void:
	assert_not_null(_enemy_view(_sheet_set()).sprite)

# --- espelhamento ---

func test_enemy_flips_when_the_sheet_faces_right() -> void:
	assert_true(_enemy_view(_sheet_set(true)).sprite.flip_h)
	assert_false(_hero_view(_sheet_set(true)).sprite.flip_h)

func test_sheet_facing_left_flips_the_hero_instead() -> void:
	assert_false(_enemy_view(_sheet_set(false)).sprite.flip_h)
	assert_true(_hero_view(_sheet_set(false)).sprite.flip_h)

# --- animacao escolhida por gatilho ---

func test_basic_attack_and_strength_damage_play_attack() -> void:
	var v: CombatantView = _hero_view(_sheet_set())
	v.play_action(_action(v.combatant, v.combatant.basic_attack))
	assert_eq(v.sprite.anim, BattleSprite.ATTACK)
	v.sprite.show_anim(BattleSprite.IDLE)
	v.play_action(_action(v.combatant, Fixtures.hit(2.0)))
	assert_eq(v.sprite.anim, BattleSprite.ATTACK)

func test_other_abilities_and_items_play_cast() -> void:
	var v: CombatantView = _hero_view(_sheet_set())
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.DAMAGE
	e.scale = EffectDef.Scale.AURA
	var magic := AbilityDef.new()
	magic.effects = [e]
	v.play_action(_action(v.combatant, magic))
	assert_eq(v.sprite.anim, BattleSprite.CAST)
	v.sprite.show_anim(BattleSprite.IDLE)
	var heal := EffectDef.new()
	heal.kind = EffectDef.Kind.HEAL
	var spell := AbilityDef.new()
	spell.effects = [heal]
	v.play_action(_action(v.combatant, spell))
	assert_eq(v.sprite.anim, BattleSprite.CAST)
	v.sprite.show_anim(BattleSprite.IDLE)
	v.play_action(_action(v.combatant, null, ItemDef.new()))
	assert_eq(v.sprite.anim, BattleSprite.CAST)

func test_damage_plays_hit_but_zero_damage_does_not() -> void:
	var v: CombatantView = _enemy_view(_sheet_set())
	v.show_hit({"kind": EffectDef.Kind.DAMAGE, "amount": 0, "dodged": false})
	assert_eq(v.sprite.anim, BattleSprite.IDLE)
	v.show_hit({"kind": EffectDef.Kind.DAMAGE, "amount": 5, "dodged": false})
	assert_eq(v.sprite.anim, BattleSprite.HIT)

func test_heal_does_not_play_hit() -> void:
	var v: CombatantView = _hero_view(_sheet_set())
	v.show_hit({"kind": EffectDef.Kind.HEAL, "amount": 5, "dodged": false})
	assert_eq(v.sprite.anim, BattleSprite.IDLE)

# --- volta ao idle, down fica, vitoria ---

func test_non_looping_animation_returns_to_idle() -> void:
	var v: CombatantView = _hero_view(_sheet_set())
	v.play_action(_action(v.combatant, v.combatant.basic_attack))
	v.sprite.animation_finished.emit()
	assert_eq(v.sprite.anim, BattleSprite.IDLE)
	assert_true(v.sprite.is_playing())

func test_hit_then_finish_returns_to_idle() -> void:
	var v: CombatantView = _enemy_view(_sheet_set())
	v.play_hit()
	assert_eq(v.sprite.anim, BattleSprite.HIT)
	v.sprite.animation_finished.emit()
	assert_eq(v.sprite.anim, BattleSprite.IDLE)

func test_going_down_plays_down_and_stays() -> void:
	var v: CombatantView = _hero_view(_sheet_set())
	v.combatant.hp = 0
	v.sync_sprite()
	assert_eq(v.sprite.anim, BattleSprite.DOWN)
	v.sprite.animation_finished.emit()
	assert_eq(v.sprite.anim, BattleSprite.DOWN, "down nao volta ao idle")
	v.play_hit()
	v.play_action(_action(v.combatant, v.combatant.basic_attack))
	v.play_victory()
	assert_eq(v.sprite.anim, BattleSprite.DOWN, "caido nao reage")

func test_revived_unit_goes_back_to_idle() -> void:
	var v: CombatantView = _hero_view(_sheet_set())
	v.combatant.hp = 0
	v.sync_sprite()
	v.combatant.hp = 5
	v.sync_sprite()
	assert_eq(v.sprite.anim, BattleSprite.IDLE)

func test_petrified_plays_down_and_tints_grey() -> void:
	var v: CombatantView = _hero_view(_sheet_set())
	_status(v.combatant, StatusDef.Kind.PETRIFY, 0.0)
	v.sync_sprite()
	assert_eq(v.sprite.anim, BattleSprite.DOWN)
	assert_eq(v.sprite.modulate, CombatantView.PETRIFY_TINT)
	assert_false(v.sprite.is_playing(), "petrificado fica parado")

func test_victory_plays_for_living_heroes_only() -> void:
	var alive: CombatantView = _hero_view(_sheet_set())
	alive.play_victory()
	assert_eq(alive.sprite.anim, BattleSprite.VICTORY)
	assert_true(alive.sprite.sprite_frames.get_animation_loop(&"victory"))
	var dead: CombatantView = _hero_view(_sheet_set())
	dead.combatant.hp = 0
	dead.sync_sprite()
	dead.play_victory()
	assert_eq(dead.sprite.anim, BattleSprite.DOWN)

# --- fallback ---

func test_missing_animation_falls_back_to_idle() -> void:
	var art: SpriteSet = _sheet_set()
	art.anims = {&"idle": Vector3i(0, 2, 4)}
	var v: CombatantView = _hero_view(art)
	v.play_action(_action(v.combatant, v.combatant.basic_attack))
	assert_eq(v.sprite.anim, BattleSprite.IDLE)
	v.play_hit()
	assert_eq(v.sprite.anim, BattleSprite.IDLE)
	v.combatant.hp = 0
	v.sync_sprite()
	assert_eq(v.sprite.anim, BattleSprite.IDLE, "sem down, fica no idle")
	assert_true(v.sprite.sprite_frames.has_animation(&"idle"))
	assert_false(v.sprite.sprite_frames.has_animation(&"down"))

func test_animation_outside_the_sheet_is_skipped() -> void:
	var art: SpriteSet = _sheet_set()
	art.anims[&"cast"] = Vector3i(9, 3, 8)
	var v: CombatantView = _hero_view(art)
	assert_false(v.sprite.sprite_frames.has_animation(&"cast"))
	assert_eq(v.sprite.resolve(&"cast"), BattleSprite.IDLE)

func test_resolve_with_no_idle_is_empty() -> void:
	var art: SpriteSet = _sheet_set()
	art.anims = {&"attack": Vector3i(1, 3, 10)}
	var s: BattleSprite = BattleSprite.create(art, false)
	autofree(s)
	assert_eq(s.resolve(&"hit"), &"")

# --- parado ---

func test_stopped_unit_pauses_and_resumes() -> void:
	var v: CombatantView = _hero_view(_sheet_set())
	_status(v.combatant, StatusDef.Kind.STOP)
	v.sync_sprite()
	assert_false(v.sprite.is_playing(), "Pare congela a animacao")
	v.play_hit()
	assert_eq(v.sprite.anim, BattleSprite.IDLE, "congelado nao troca de animacao")
	v.combatant.statuses.clear()
	v.sync_sprite()
	assert_true(v.sprite.is_playing())
	assert_eq(v.sprite.anim, BattleSprite.IDLE)

func test_frozen_unit_pauses() -> void:
	var v: CombatantView = _enemy_view(_sheet_set())
	_status(v.combatant, StatusDef.Kind.FREEZE)
	v.sync_sprite()
	assert_false(v.sprite.is_playing())

# --- cena ---

func _scene() -> BattleScene:
	var s: BattleScene = (load("res://battle/battle_scene.tscn") as PackedScene).instantiate() as BattleScene
	s.balance = Fixtures.cfg()
	add_child_autofree(s)
	s.set_process(false)
	return s

func _start_slice(s: BattleScene) -> HeroState:
	var hero: HeroState = HeroState.create(load("res://data/fatia/heroes/teste_a_f.tres") as CharacterDef, s.balance)
	var enemy: EnemyDef = load("res://data/fatia/enemies/inimigo_f1.tres") as EnemyDef
	s.start_with([hero] as Array[HeroState], [enemy] as Array[EnemyDef], [Vector2(200.0, 300.0)] as Array[Vector2],
		[Vector2(800.0, 300.0)] as Array[Vector2], Inventory.new())
	return hero

func test_slice_example_art_is_wired_in_the_scene() -> void:
	var s: BattleScene = _scene()
	var hero: HeroState = _start_slice(s)
	var hv: CombatantView = s.views[hero.def.id]
	var ev: CombatantView = s.views[&"inimigo_f1"]
	assert_not_null(hv.sprite)
	assert_not_null(ev.sprite)
	assert_false(hv.sprite.flip_h)
	assert_true(ev.sprite.flip_h)
	s._on_action_started(_action(hv.combatant, hv.combatant.basic_attack))
	assert_eq(hv.sprite.anim, BattleSprite.ATTACK)
	ev.show_hit({"kind": EffectDef.Kind.DAMAGE, "amount": 3, "dodged": false})
	assert_eq(ev.sprite.anim, BattleSprite.HIT)

func test_scene_victory_makes_living_heroes_celebrate() -> void:
	var s: BattleScene = _scene()
	var hero: HeroState = _start_slice(s)
	s.ctrl.b.enemies[0].hp = 0
	s._on_battle_ended(BattleController.Outcome.VICTORY)
	assert_eq((s.views[hero.def.id] as CombatantView).sprite.anim, BattleSprite.VICTORY)

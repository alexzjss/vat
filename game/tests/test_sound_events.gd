extends GutTest

## SoundEvents (M19): qual id de som toca em cada evento, com as reservas, e o vazio-entra-vazio-sai.

func _cfg() -> BalanceConfig:
	var c := Fixtures.cfg()
	c.sfx_menu_move = &"m_move"
	c.sfx_menu_confirm = &"m_ok"
	c.sfx_menu_cancel = &"m_back"
	c.sfx_text_tick = &"tick"
	c.sfx_open_chest = &"bau"
	c.sfx_open_door = &"porta"
	c.sfx_step = &"passo"
	c.sfx_level_up = &"nivel"
	c.victory_jingle = &"vitoria"
	c.defeat_jingle = &"derrota"
	c.default_battle_music = &"batalha"
	c.boss_battle_music = &"chefe"
	return c

func _ability(cast: StringName = &"", impact: StringName = &"", element_hit: StringName = &"") -> AbilityDef:
	var a := AbilityDef.new()
	a.id = &"golpe"
	a.sfx_cast = cast
	a.sfx_impact = impact
	if element_hit != &"":
		var e := ElementDef.new()
		e.id = &"fogo"
		e.sfx_hit = element_hit
		a.element = e
	return a

# --- tecnica ---

func test_cast_is_the_ability_cast_sound() -> void:
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.CAST, {"ability": _ability(&"conj")}), &"conj")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.CAST, {"ability": _ability()}), &"")

func test_impact_prefers_the_ability_then_falls_back_to_the_element() -> void:
	var both: AbilityDef = _ability(&"", &"estouro", &"chama")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.IMPACT, {"ability": both}), &"estouro")
	var only_element: AbilityDef = _ability(&"", &"", &"chama")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.IMPACT, {"ability": only_element}), &"chama")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.IMPACT, {"ability": _ability()}), &"", "nem tecnica nem elemento")

func test_impact_context_element_replaces_the_missing_ability_element() -> void:
	var weapon := ElementDef.new()
	weapon.sfx_hit = &"lamina"
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.IMPACT, {"ability": _ability(), "element": weapon}), &"lamina")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.IMPACT, {"element": weapon}), &"lamina", "sem tecnica, so o elemento")

# --- combatentes ---

func test_hit_and_down_read_the_hero_or_enemy_def() -> void:
	var hero := CharacterDef.new()
	hero.sfx_hit = &"h_hit"
	hero.sfx_down = &"h_down"
	var foe := EnemyDef.new()
	foe.sfx_hit = &"e_hit"
	foe.sfx_down = &"e_down"
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.HIT, {"def": hero}), &"h_hit")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.HIT, {"def": foe}), &"e_hit")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.DOWN, {"def": hero}), &"h_down")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.DOWN, {"def": foe}), &"e_down")

func test_hit_is_silent_when_nothing_was_damaged() -> void:
	var foe := EnemyDef.new()
	foe.sfx_hit = &"e_hit"
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.HIT, {"def": foe, "damaged": false}), &"")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.HIT, {"def": foe, "damaged": true}), &"e_hit")

func test_reaction_status_and_item() -> void:
	var r := ReactionDef.new()
	r.sfx = &"reacao"
	var s := StatusDef.new()
	s.sfx_apply = &"veneno"
	var it := ItemDef.new()
	it.sfx_use = &"pocao"
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.REACTION, {"reaction": r}), &"reacao")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.STATUS_APPLIED, {"status": s}), &"veneno")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.ITEM_USE, {"item": it}), &"pocao")

# --- interface e mundo ---

func test_ui_and_world_sounds_come_from_the_balance_config() -> void:
	var ctx: Dictionary = {"cfg": _cfg()}
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.MENU_MOVE, ctx), &"m_move")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.MENU_CONFIRM, ctx), &"m_ok")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.MENU_CANCEL, ctx), &"m_back")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.TEXT_TICK, ctx), &"tick")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.CHEST, ctx), &"bau")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.DOOR, ctx), &"porta")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.STEP, ctx), &"passo")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.LEVEL_UP, ctx), &"nivel")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.VICTORY, ctx), &"vitoria")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.DEFEAT, ctx), &"derrota")

func test_empty_in_empty_out_never_an_error() -> void:
	for ev: int in SoundEvents.Event.values():
		assert_eq(SoundEvents.sound_for(ev as SoundEvents.Event), &"", "sem contexto: %d" % ev)
		assert_eq(SoundEvents.sound_for(ev as SoundEvents.Event, {"cfg": Fixtures.cfg()}), &"", "config vazia: %d" % ev)
		assert_eq(SoundEvents.sound_for(ev as SoundEvents.Event, {"ability": AbilityDef.new(), "def": EnemyDef.new(),
				"item": ItemDef.new(), "reaction": ReactionDef.new(), "status": StatusDef.new()}), &"", "defs vazios: %d" % ev)
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.HIT, {"def": "nao e um def"}), &"")
	assert_eq(SoundEvents.sound_for(SoundEvents.Event.CAST, {"ability": null}), &"")

# --- padroes do AudioRules, chefe, tiques ---

func test_audio_defaults_come_from_the_balance_config() -> void:
	var d: Dictionary = SoundEvents.audio_defaults(_cfg())
	assert_eq(d["battle_music"], &"batalha")
	assert_eq(d["boss_music"], &"chefe")
	assert_eq(d["victory_jingle"], &"vitoria")
	assert_eq(d["defeat_jingle"], &"derrota")
	assert_eq(SoundEvents.audio_defaults(null), AudioRules.make_defaults())
	assert_eq(SoundEvents.audio_defaults(Fixtures.cfg()), AudioRules.make_defaults())

func test_boss_is_an_encounter_with_a_unique_id() -> void:
	var e := EncounterDef.new()
	assert_false(SoundEvents.is_boss(e))
	e.unique_id = &"chefe_1"
	assert_true(SoundEvents.is_boss(e))
	assert_false(SoundEvents.is_boss(null))

func test_text_ticks_count_each_new_block_of_characters() -> void:
	assert_eq(SoundEvents.ticks_between(0, 1, 2), 0)
	assert_eq(SoundEvents.ticks_between(0, 2, 2), 1)
	assert_eq(SoundEvents.ticks_between(1, 2, 2), 1)
	assert_eq(SoundEvents.ticks_between(2, 3, 2), 0)
	assert_eq(SoundEvents.ticks_between(0, 10, 2), 5)
	assert_eq(SoundEvents.ticks_between(5, 5, 2), 0)
	assert_eq(SoundEvents.ticks_between(3, 1, 2), 0, "nunca negativo")
	assert_eq(SoundEvents.ticks_between(0, 3, 0), 3, "intervalo menor que 1 conta como 1")

# --- sons do impacto de uma acao ---

func _combatant(team: Combatant.Team, id: StringName, hit: StringName, down: StringName) -> Combatant:
	var cfg := Fixtures.cfg()
	if team == Combatant.Team.HERO:
		var def := Fixtures.hero_def(id, Stats.make(10, 10, 5, 1))
		def.sfx_hit = hit
		def.sfx_down = down
		return Combatant.from_hero(HeroState.create(def, cfg), Vector2.ZERO)
	var edef := Fixtures.enemy_def(id, Stats.make(10, 10, 5, 1))
	edef.sfx_hit = hit
	edef.sfx_down = down
	return Combatant.from_enemy(edef, id, Vector2.ZERO, cfg)

func _hit(target: Combatant, amount: int, extra: Dictionary = {}) -> Dictionary:
	var h: Dictionary = {"target_id": target.id, "kind": EffectDef.Kind.DAMAGE, "amount": amount, "dodged": false,
			"missed": false, "status_result": -1, "reaction": &""}
	h.merge(extra, true)
	return h

func test_impact_sounds_in_order_without_repeats() -> void:
	var hero: Combatant = _combatant(Combatant.Team.HERO, &"h", &"", &"")
	var e1: Combatant = _combatant(Combatant.Team.ENEMY, &"e1", &"e_hit", &"e_down")
	var e2: Combatant = _combatant(Combatant.Team.ENEMY, &"e2", &"e_hit", &"e_down")
	var reaction := ReactionDef.new()
	reaction.id = &"vapor"
	reaction.sfx = &"reacao"
	var table := ReactionTable.new()
	table.reactions = [reaction] as Array[ReactionDef]
	var a := PendingAction.new()
	a.actor = hero
	a.ability = _ability(&"conj", &"estouro")
	var r := ActionResult.new()
	r.targets = [e1, e2] as Array[Combatant]
	r.hits = [_hit(e1, 8, {"reaction": &"vapor"}), _hit(e2, 5)]
	r.downed = [e2] as Array[Combatant]
	assert_eq(SoundEvents.impact_sounds(a, r, table), [&"estouro", &"e_hit", &"e_down", &"reacao"] as Array[StringName])

func test_impact_sounds_skip_misses_dodges_and_zero_damage() -> void:
	var hero: Combatant = _combatant(Combatant.Team.HERO, &"h", &"", &"")
	var foe: Combatant = _combatant(Combatant.Team.ENEMY, &"e1", &"e_hit", &"")
	var a := PendingAction.new()
	a.actor = hero
	a.ability = _ability()
	var r := ActionResult.new()
	r.targets = [foe] as Array[Combatant]
	r.hits = [_hit(foe, 0), _hit(foe, 9, {"missed": true}), _hit(foe, 9, {"dodged": true})]
	assert_eq(SoundEvents.impact_sounds(a, r, null), [] as Array[StringName])

func test_impact_sounds_play_the_hero_hit_when_the_hero_is_the_target() -> void:
	var hero: Combatant = _combatant(Combatant.Team.HERO, &"h", &"h_hit", &"h_down")
	var foe: Combatant = _combatant(Combatant.Team.ENEMY, &"e1", &"", &"")
	var a := PendingAction.new()
	a.actor = foe
	a.ability = _ability()
	var r := ActionResult.new()
	r.targets = [hero] as Array[Combatant]
	r.hits = [_hit(hero, 4)]
	r.downed = [hero] as Array[Combatant]
	assert_eq(SoundEvents.impact_sounds(a, r, null), [&"h_hit", &"h_down"] as Array[StringName])

func test_impact_sounds_of_a_status_effect_and_the_basic_attack_weapon_element() -> void:
	var weapon := ElementDef.new()
	weapon.sfx_hit = &"lamina"
	var hero: Combatant = _combatant(Combatant.Team.HERO, &"h", &"", &"")
	hero.weapon_element = weapon
	var basic := AbilityDef.new()
	hero.basic_attack = basic
	var foe: Combatant = _combatant(Combatant.Team.ENEMY, &"e1", &"", &"")
	var poison := StatusDef.new()
	poison.id = &"veneno"
	poison.sfx_apply = &"veneno_sfx"
	var fx := EffectDef.new()
	fx.kind = EffectDef.Kind.APPLY_STATUS
	fx.status = poison
	var a := PendingAction.new()
	a.actor = hero
	a.ability = basic
	var r := ActionResult.new()
	r.targets = [foe] as Array[Combatant]
	assert_eq(SoundEvents.impact_sounds(a, r, null), [&"lamina"] as Array[StringName], "ataque basico usa o elemento da arma")
	var skill := AbilityDef.new()
	skill.effects = [fx] as Array[EffectDef]
	a.ability = skill
	r.hits = [_hit(foe, 0, {"kind": EffectDef.Kind.APPLY_STATUS, "status_result": StatusSystem.ApplyResult.APPLIED})]
	assert_eq(SoundEvents.impact_sounds(a, r, null), [&"veneno_sfx"] as Array[StringName])
	r.hits = [_hit(foe, 0, {"kind": EffectDef.Kind.APPLY_STATUS, "status_result": StatusSystem.ApplyResult.RESISTED})]
	assert_eq(SoundEvents.impact_sounds(a, r, null), [] as Array[StringName], "estado resistido nao soa")

func test_action_start_sound_is_the_item_use_or_the_cast() -> void:
	var a := PendingAction.new()
	a.ability = _ability(&"conj")
	assert_eq(SoundEvents.action_start_sound(a), &"conj")
	var it := ItemDef.new()
	it.sfx_use = &"pocao"
	a.item = it
	assert_eq(SoundEvents.action_start_sound(a), &"pocao")
	assert_eq(SoundEvents.action_start_sound(null), &"")

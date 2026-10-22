extends GutTest
## M15 Task 5: bestiario, reacoes vistas, o efeito Scan e os textos puros. Defs em memoria; numeros de teste.

class CountingDice extends Dice:
	var rolls: int = 0
	func _init() -> void:
		super._init(0)
	func roll() -> float:
		rolls += 1
		return 0.5

var cfg: BalanceConfig
var g: GameState
var hero_def: CharacterDef

func before_each() -> void:
	cfg = Fixtures.cfg()
	hero_def = Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 4))
	g = GameState.new_game(cfg, [hero_def] as Array[CharacterDef], [] as Array[ItemDef], [] as Array[int], ScriptedDice.new(), &"overworld", &"Start")

func _enemy(id: StringName) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(10, 5, 5, 4)), id, Vector2(100, 0), cfg)

func _twin(def: EnemyDef, n: int) -> Combatant:
	return Combatant.from_enemy(def, StringName("%s_%d" % [def.id, n]), Vector2(100, 0), cfg)

func _list(cs: Array) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c: Variant in cs:
		out.append(c as Combatant)
	return out

func _petrify(c: Combatant, b: BattleState) -> void:
	var s: StatusDef = Fixtures.status_def(StatusDef.Kind.PETRIFY, 3)
	s.negative = true
	b.statuses.apply(c, s, c, 1.0, [c])

func _el(id: StringName) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	e.short_name = String(id).capitalize()
	return e

# --- visto e derrotado -----------------------------------------------------------

func test_defaults_are_empty_and_unrevealed() -> void:
	assert_true(g.bestiary.is_empty())
	assert_true(g.seen_reactions.is_empty())
	assert_eq(g.bestiary_entry(&"slime"), {"seen": false, "defeated": 0, "scanned": false})
	assert_false(g.bestiary_revealed(&"slime"))

func test_record_seen_marks_every_enemy_once() -> void:
	var d: EnemyDef = Fixtures.enemy_def(&"slime", Stats.make(10, 5, 5, 4))
	g.record_seen(_list([_twin(d, 0), _twin(d, 1), _enemy(&"bat")]))
	assert_eq(g.bestiary.size(), 2)
	assert_true(g.bestiary_entry(&"slime")["seen"])
	assert_true(g.bestiary_entry(&"bat")["seen"])
	assert_eq(g.bestiary_entry(&"slime")["defeated"], 0)

func test_victory_counts_downed_enemies_and_twice_for_repeated_ids() -> void:
	var d: EnemyDef = Fixtures.enemy_def(&"slime", Stats.make(10, 5, 5, 4))
	var a: Combatant = _twin(d, 0)
	var b2: Combatant = _twin(d, 1)
	var alive: Combatant = _enemy(&"bat")
	var es: Array[Combatant] = _list([a, b2, alive])
	g.record_seen(es)
	a.hp = 0
	b2.hp = 0
	g.record_victory(es)
	assert_eq(g.bestiary_entry(&"slime")["defeated"], 2)
	assert_eq(g.bestiary_entry(&"bat")["defeated"], 0, "quem nao esta fora nao conta")
	g.record_seen(es)
	g.record_victory(es)
	assert_eq(g.bestiary_entry(&"slime")["defeated"], 4, "acumula entre batalhas")

func test_petrified_enemy_counts_as_defeated() -> void:
	var x: Combatant = _enemy(&"golem")
	var h: Combatant = Combatant.from_hero(HeroState.create(hero_def, cfg), Vector2.ZERO)
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	_petrify(x, b)
	assert_true(x.is_out())
	assert_false(x.is_down())
	g.record_seen(b.enemies)
	g.record_victory(b.enemies)
	assert_eq(g.bestiary_entry(&"golem")["defeated"], 1)

func test_flee_counts_only_seen() -> void:
	# A fuga so chama record_seen (a cena nao chama record_victory): visto, 0 derrotas.
	g.record_seen(_list([_enemy(&"golem")]))
	assert_eq(g.bestiary_entry(&"golem"), {"seen": true, "defeated": 0, "scanned": false})

# --- revelar -----------------------------------------------------------------------

func test_reveal_by_kills() -> void:
	var x: Combatant = _enemy(&"golem")
	g.record_seen(_list([x]))
	x.hp = 0
	assert_eq(cfg.bestiary_reveal_kills, 3)
	for i: int in 2:
		g.record_victory(_list([x]))
	assert_false(g.bestiary_revealed(&"golem"))
	g.record_victory(_list([x]))
	assert_true(g.bestiary_revealed(&"golem"))

func test_reveal_by_scan_and_scan_does_not_touch_kills() -> void:
	g.mark_scanned(&"golem")
	assert_true(g.bestiary_revealed(&"golem"))
	assert_true(g.bestiary_entry(&"golem")["seen"])
	assert_eq(g.bestiary_entry(&"golem")["defeated"], 0)

func test_reveal_kills_follows_the_config() -> void:
	cfg.bestiary_reveal_kills = 1
	var x: Combatant = _enemy(&"golem")
	x.hp = 0
	g.record_victory(_list([x]))
	assert_true(g.bestiary_revealed(&"golem"))

# --- save --------------------------------------------------------------------------

func _load(d: Dictionary) -> GameState:
	var r: DefRegistry = DefRegistry.create([hero_def] as Array[CharacterDef], [] as Array[ItemDef], [] as Array[EquipmentDef])
	return GameState.from_dict(d, r, cfg, ScriptedDice.new())

func test_empty_bestiary_is_not_written() -> void:
	var d: Dictionary = g.to_dict()
	assert_false(d.has("bestiary"))
	assert_false(d.has("seen_reactions"))

func test_save_round_trip() -> void:
	g.record_seen(_list([_enemy(&"slime"), _enemy(&"bat")]))
	var s: Combatant = _enemy(&"slime")
	s.hp = 0
	g.record_victory(_list([s]))
	g.mark_scanned(&"bat")
	g.record_reaction(&"vapor")
	g.record_reaction(&"sobrecarga")
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	assert_true(d.has("bestiary"))
	assert_eq(d["seen_reactions"], ["vapor", "sobrecarga"])
	var g2: GameState = _load(d)
	assert_not_null(g2)
	assert_eq(g2.bestiary_entry(&"slime"), {"seen": true, "defeated": 1, "scanned": false})
	assert_eq(g2.bestiary_entry(&"bat"), {"seen": true, "defeated": 0, "scanned": true})
	assert_eq(g2.seen_reactions, [&"vapor", &"sobrecarga"] as Array[StringName])
	assert_eq(g2.to_dict()["bestiary"], g.to_dict()["bestiary"])

func test_old_save_loads_with_empty_bestiary() -> void:
	var d: Dictionary = g.to_dict()
	d.erase("bestiary")
	d.erase("seen_reactions")
	var g2: GameState = _load(d)
	assert_not_null(g2)
	assert_true(g2.bestiary.is_empty())
	assert_true(g2.seen_reactions.is_empty())

func test_garbage_fields_are_ignored() -> void:
	var d: Dictionary = g.to_dict()
	d["bestiary"] = {"slime": {"seen": true, "defeated": -4}, "": {"seen": true}, "bat": 7}
	d["seen_reactions"] = ["vapor", "vapor", 3, ""]
	var g2: GameState = _load(d)
	assert_not_null(g2)
	assert_eq(g2.bestiary_entry(&"slime")["defeated"], 0)
	assert_false(g2.bestiary.has(&"bat"))
	assert_false(g2.bestiary.has(&""))
	assert_eq(g2.seen_reactions, [&"vapor"] as Array[StringName])

func test_snapshot_restore() -> void:
	g.record_seen(_list([_enemy(&"slime")]))
	g.record_reaction(&"vapor")
	g.save(&"overworld", &"Start")
	g.record_seen(_list([_enemy(&"bat")]))
	g.mark_scanned(&"slime")
	g.record_reaction(&"sobrecarga")
	g.restore_save()
	assert_false(g.bestiary.has(&"bat"))
	assert_false(g.bestiary_entry(&"slime")["scanned"])
	assert_eq(g.seen_reactions, [&"vapor"] as Array[StringName])
	# A copia gravada nao compartilha as entradas com o estado vivo.
	g.mark_scanned(&"slime")
	g.restore_save()
	assert_false(g.bestiary_entry(&"slime")["scanned"])

# --- reacoes vistas ------------------------------------------------------------------

func test_record_reaction_dedupes_and_ignores_empty() -> void:
	g.record_reaction(&"vapor")
	g.record_reaction(&"vapor")
	g.record_reaction(&"")
	assert_eq(g.seen_reactions, [&"vapor"] as Array[StringName])

func test_record_result_takes_reactions_from_hits_of_anyone() -> void:
	var r := ActionResult.new()
	r.hits.append({"target_id": &"x", "reaction": &"vapor"})
	r.hits.append({"target_id": &"h", "reaction": &""})
	r.hits.append({"target_id": &"y", "reaction": &"vapor"})
	r.hits.append({"target_id": &"z"})
	r.hits.append({"target_id": &"w", "reaction": &"lama"})
	g.record_result(r)
	assert_eq(g.seen_reactions, [&"vapor", &"lama"] as Array[StringName])

# --- SCAN ---------------------------------------------------------------------------

func _scan_ability(side: AbilityDef.Side = AbilityDef.Side.ENEMIES) -> AbilityDef:
	var e := EffectDef.new()
	e.kind = EffectDef.Kind.SCAN
	var a := AbilityDef.new()
	a.id = &"scan"
	a.shape = AbilityDef.Shape.SINGLE
	a.side = side
	a.cast_time = 1.0
	a.impact_time = 0.5
	a.effects = [e]
	return a

func _scan_setup(dice: Dice = null) -> Array:
	var h: Combatant = Combatant.from_hero(HeroState.create(hero_def, cfg), Vector2.ZERO)
	var d: EnemyDef = Fixtures.enemy_def(&"golem", Stats.make(10, 5, 5, 4))
	d.elements = [_el(&"kagutsuchi")]
	d.element_resist = {&"kagutsuchi": 1.5, &"susanoo": -0.5, &"atlas": 0.3, &"indra": 0.0, &"fuhaku": 1.0}
	d.immunities = [&"sleep"]
	d.resistances = {&"poison": 0.5, &"blind": 0.0}
	var x: Combatant = Combatant.from_enemy(d, &"golem", Vector2(100, 0), cfg)
	var b: BattleState = BattleState.create(cfg, dice if dice != null else ScriptedDice.new(), [h], [x])
	return [h, x, b]

func _cast(actor: Combatant, ab: AbilityDef, target: Combatant, b: BattleState) -> ActionResult:
	var a := PendingAction.new()
	a.actor = actor
	a.ability = ab
	a.center = target
	a.center_pos = target.position
	return ActionExecutor.apply(a, b)

func test_scan_marks_enemy_without_damage_dice_or_contribution() -> void:
	var dice := CountingDice.new()
	var s: Array = _scan_setup(dice)
	var h: Combatant = s[0]
	var x: Combatant = s[1]
	var b: BattleState = s[2]
	var hp: int = x.hp
	var r: ActionResult = _cast(h, _scan_ability(), x, b)
	assert_eq(x.hp, hp)
	assert_eq(dice.rolls, 0, "Scan nao consome Dice")
	assert_eq(r.hits.size(), 1)
	var hit: Dictionary = r.hits[0]
	assert_eq(hit["kind"], EffectDef.Kind.SCAN)
	assert_true(hit["scan"])
	assert_eq(hit["amount"], 0)
	assert_eq(r.scanned, [&"golem"] as Array[StringName])
	assert_eq(b.ledger.total_against(&"golem"), 0.0)
	assert_eq(x.statuses.size(), 0)
	assert_eq(h.limit, 0.0)

func test_scan_info_content() -> void:
	var s: Array = _scan_setup()
	var r: ActionResult = _cast(s[0], _scan_ability(), s[1], s[2])
	var info: Dictionary = r.hits[0]["scan_info"]
	assert_eq(info["natives"], [&"kagutsuchi"] as Array[StringName])
	assert_eq(info["absorbs"], [&"kagutsuchi"] as Array[StringName])
	var er: Dictionary = info["element_resist"]
	assert_eq(er.size(), 4, "o 0.0 fica de fora")
	assert_false(er.has(&"indra"))
	assert_eq(er[&"susanoo"], -0.5)
	assert_eq(info["immunities"], [&"sleep"] as Array[StringName])
	assert_eq(info["resistances"], {&"poison": 0.5}, "resistencia 0 fica de fora")

func test_scan_result_applies_to_game_state() -> void:
	var s: Array = _scan_setup()
	var r: ActionResult = _cast(s[0], _scan_ability(), s[1], s[2])
	g.record_result(r)
	assert_true(g.bestiary_entry(&"golem")["scanned"])
	assert_true(g.bestiary_revealed(&"golem"))
	assert_eq(g.bestiary_entry(&"golem")["defeated"], 0)

func test_scan_twice_lists_the_id_once_per_result() -> void:
	var s: Array = _scan_setup()
	var a: AbilityDef = _scan_ability()
	assert_eq(_cast(s[0], a, s[1], s[2]).scanned.size(), 1)
	assert_eq(_cast(s[0], a, s[1], s[2]).scanned.size(), 1)

func test_scan_on_hero_target_does_nothing() -> void:
	# Decisao: o bestiario e so de inimigos; Scan num heroi (side ALLIES) nao gera hit nem registro.
	var s: Array = _scan_setup()
	var r: ActionResult = _cast(s[0], _scan_ability(AbilityDef.Side.ALLIES), s[0], s[2])
	assert_true(r.hits.is_empty())
	assert_true(r.scanned.is_empty())

func test_scan_on_petrified_enemy_does_nothing() -> void:
	# Decisao: petrificado esta fora de combate e nao e alvo (nada o atinge); o Scan nao gera hit nem registro.
	var s: Array = _scan_setup()
	var x: Combatant = s[1]
	var b: BattleState = s[2]
	_petrify(x, b)
	var r: ActionResult = _cast(s[0], _scan_ability(), x, b)
	assert_true(r.scanned.is_empty())
	assert_true(r.hits.is_empty())

func test_scan_on_downed_enemy_does_nothing() -> void:
	var s: Array = _scan_setup()
	var x: Combatant = s[1]
	x.hp = 0
	var r: ActionResult = _cast(s[0], _scan_ability(), x, s[2])
	assert_true(r.scanned.is_empty())
	assert_true(r.hits.is_empty())

func test_normal_hits_have_no_scan_fields_set() -> void:
	var s: Array = _scan_setup()
	var r: ActionResult = _cast(s[0], Fixtures.hit(1.0), s[1], s[2])
	assert_false(r.hits[0]["scan"])
	assert_eq(r.hits[0]["scan_info"], {})
	assert_true(r.scanned.is_empty())

# --- textos --------------------------------------------------------------------------

func _golem_def() -> EnemyDef:
	var d: EnemyDef = Fixtures.enemy_def(&"golem", Stats.make(10, 5, 5, 4))
	d.display_name = "Golem"
	d.level = 3
	d.elements = [load("res://data/elements/kagutsuchi.tres") as ElementDef]
	d.element_resist = {&"kagutsuchi": 1.5, &"susanoo": -0.5, &"atlas": 0.3, &"indra": 1.0, &"fuhaku": 0.0}
	d.immunities = [&"sleep"]
	d.resistances = {&"poison": 0.5, &"sleep": 0.8}
	var pot := ItemDef.new()
	pot.id = &"pot"
	pot.display_name = "Poção"
	var drop := DropEntry.new()
	drop.item = pot
	drop.chance = 0.5
	drop.count = 2
	d.drops = [drop]
	return d

func test_entry_lines_unseen() -> void:
	assert_eq(BestiaryText.entry_lines(_golem_def(), {"seen": false, "defeated": 0, "scanned": false}, false, cfg), ["???"] as Array[String])
	assert_eq(BestiaryText.entry_lines(_golem_def(), {}, true, cfg), ["???"] as Array[String], "nao visto nao revela, mesmo marcado como revelado")
	assert_eq(BestiaryText.entry_lines(null, {"seen": true}, true, cfg), ["???"] as Array[String])

func test_entry_lines_seen_but_not_revealed_leaks_nothing() -> void:
	var d: EnemyDef = _golem_def()
	var lines: Array[String] = BestiaryText.entry_lines(d, {"seen": true, "defeated": 2, "scanned": false}, false, cfg)
	assert_eq(lines.size(), 4)
	assert_eq(lines[0], "Golem")
	assert_eq(lines[1], "Nv 3")
	var hp: int = StatCalculator.hp_max(Combatant.from_enemy(d, d.id, Vector2.ZERO, cfg), cfg)
	assert_eq(lines[2], "HP máx %d" % hp)
	assert_eq(lines[3], "Derrotado 2x")
	assert_eq(BestiaryText.max_hp(d, cfg), hp)

func test_entry_lines_revealed() -> void:
	var lines: Array[String] = BestiaryText.entry_lines(_golem_def(), {"seen": true, "defeated": 3, "scanned": false}, true, cfg)
	assert_eq(lines.size(), 9)
	assert_eq(lines[3], "Derrotado 3x")
	assert_eq(lines[4], "Elementos: Fogo")
	assert_eq(lines[5], "Afinidades: Fogo absorve, Água −50%, Terra 30%, Raio imune")
	assert_eq(lines[6], "Imune a: Sono")
	assert_eq(lines[7], "Resiste a: Veneno 50%")
	assert_eq(lines[8], "Drops: Poção x2 50%")

func test_revealed_empty_fields_show_dash() -> void:
	var d: EnemyDef = Fixtures.enemy_def(&"plain", Stats.make(10, 5, 5, 4))
	var lines: Array[String] = BestiaryText.entry_lines(d, {"seen": true, "defeated": 0, "scanned": true}, true, cfg)
	assert_eq(lines[4], "Elementos: —")
	assert_eq(lines[5], "Afinidades: —")
	assert_eq(lines[6], "Imune a: —")
	assert_eq(lines[7], "Resiste a: —")
	assert_eq(lines[8], "Drops: —")

func test_affinities_text_labels() -> void:
	assert_eq(BestiaryText.affinities_text({&"kagutsuchi": 0.3, &"indra": -0.5, &"atlas": 1.0, &"susanoo": 1.5, &"fuhaku": 0.0}), "Fogo 30%, Água absorve, Terra imune, Raio −50%")

func _reaction(id: StringName) -> ReactionDef:
	return load("res://data/reactions/%s.tres" % id) as ReactionDef

func test_reaction_summary_vapor() -> void:
	assert_eq(BestiaryText.reaction_summary(_reaction(&"vapor")), "+50% dano · Cegueira 50%")

func test_reaction_summary_sobrecarga() -> void:
	assert_eq(BestiaryText.reaction_summary(_reaction(&"sobrecarga")), "+30% dano · área 50% (M) · ATB alvo −25%")

func test_reaction_summary_transfusao() -> void:
	assert_eq(BestiaryText.reaction_summary(_reaction(&"transfusao")), "cura atacante 50%")

func test_reaction_summary_keep_and_empty_and_area_sizes() -> void:
	var d := ReactionDef.new()
	assert_eq(BestiaryText.reaction_summary(d), "—")
	assert_eq(BestiaryText.reaction_summary(null), "—")
	d.keep = load("res://data/elements/kagutsuchi.tres") as ElementDef
	d.attacker_atb = 0.3
	assert_eq(BestiaryText.reaction_summary(d), "ATB atacante +30% · fica Fogo")
	assert_eq(BestiaryText.area_size(100.0), "P")
	assert_eq(BestiaryText.area_size(200.0), "M")
	assert_eq(BestiaryText.area_size(400.0), "G")

extends GutTest
## M14 Task 5: interface das marcas e reacoes (icone, popups, painel de debug). Defs em memoria.

const VIEW_SCENE: PackedScene = preload("res://battle/combatant_view.tscn")
const SCENE: String = "res://battle/battle_scene.tscn"

var fire: ElementDef
var water: ElementDef
var cfg: BalanceConfig

func _el(id: StringName, short: String, color: Color) -> ElementDef:
	var e := ElementDef.new()
	e.id = id
	e.short_name = short
	e.color = color
	return e

func before_each() -> void:
	fire = _el(&"fire", "Fogo", Color(1.0, 0.0, 0.0))
	water = _el(&"water", "Água", Color(0.0, 0.0, 1.0))
	cfg = Fixtures.cfg()

func _enemy(id: StringName = &"x") -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1, 0, 2, 1)), id, Vector2.ZERO, cfg)

func _view(c: Combatant) -> CombatantView:
	var v: CombatantView = VIEW_SCENE.instantiate() as CombatantView
	add_child_autofree(v)
	v.bind(c, cfg)
	return v

func _def(name: String = "Vapor", fields: Dictionary = {}) -> ReactionDef:
	var d := ReactionDef.new()
	d.id = &"vapor"
	d.display_name = name
	d.a = fire
	d.b = water
	d.bonus_pct = 0.5
	for k: Variant in fields.keys():
		d.set(k, fields[k])
	return d

func _texts(v: CombatantView) -> Array[String]:
	var out: Array[String] = []
	for n: Node in v.get_children():
		if n is Label:
			out.append((n as Label).text)
	return out

func _hit(extra: Dictionary = {}) -> Dictionary:
	var h: Dictionary = {"target_id": &"x", "kind": EffectDef.Kind.DAMAGE, "amount": 20, "dodged": false, "status_result": -1,
			"missed": false, "shielded": false, "element": &"fire", "affinity": 0, "lifesteal": 0, "self_damage": 0,
			"contamination": 0, "burst": 0, "mark": &"", "reaction": &"vapor", "reaction_effects": {}}
	h.merge(extra, true)
	return h

func _fx(extra: Dictionary = {}) -> Dictionary:
	var fx: Dictionary = {"extra_damage": 0, "area": [], "statuses": [], "atb": {"target": 0.0, "attacker": 0.0}, "heal_attacker": 0, "heal_allies": [], "removed": 0}
	fx.merge(extra, true)
	return fx

func _plan_texts(plan: Array[Dictionary], id: StringName) -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in plan:
		if p["id"] == id:
			out.append(p["text"])
	return out

# --- icone da marca -------------------------------------------------------------

func test_mark_text_is_initial_and_turns() -> void:
	var c: Combatant = _enemy()
	var v: CombatantView = _view(c)
	assert_eq(v.mark_text(), "")
	MarkRules.set_mark(c, fire, 3)
	assert_eq(v.mark_text(), "F3")
	MarkRules.set_mark(c, water, 2)
	assert_eq(v.mark_text(), "Á2")

func test_mark_icon_uses_icon_text_and_falls_back_to_initial() -> void:
	var earth: ElementDef = _el(&"atlas", "Terra", Color(0.6, 0.4, 0.2))
	var dark: ElementDef = _el(&"tsukuyomi", "Trevas", Color(0.3, 0.1, 0.5))
	# Sem icon_text as duas viram "T"; com icon_text ficam distintas.
	assert_eq(ElementText.initial_of(earth), "T")
	assert_eq(ElementText.initial_of(dark), "T")
	earth.icon_text = "At"
	dark.icon_text = "Ts"
	var c: Combatant = _enemy()
	var v: CombatantView = _view(c)
	MarkRules.set_mark(c, earth, 3)
	assert_eq(v.mark_text(), "At3")
	MarkRules.set_mark(c, dark, 2)
	assert_eq(v.mark_text(), "Ts2")

func test_shipped_elements_have_distinct_icon_texts() -> void:
	var seen: Dictionary = {}
	for id: StringName in [&"amaterasu", &"atlas", &"fuhaku", &"indra", &"kagutsuchi", &"radioativo", &"shukketsu", &"susanoo", &"tsukuyomi"]:
		var e: ElementDef = ElementText.def_of(id)
		assert_not_null(e, String(id))
		var t: String = ElementText.initial_of(e)
		assert_true(t.length() >= 1 and t.length() <= 2, "%s: '%s'" % [id, t])
		assert_false(seen.has(t), "icone repetido: %s" % t)
		seen[t] = true
	assert_eq(ElementText.initial_of(ElementText.def_of(&"atlas")), "At")
	assert_eq(ElementText.initial_of(ElementText.def_of(&"tsukuyomi")), "Ts")

func test_mark_hidden_when_down() -> void:
	var c: Combatant = _enemy()
	var v: CombatantView = _view(c)
	MarkRules.set_mark(c, fire, 3)
	c.hp = 0
	assert_eq(v.mark_text(), "")

func test_mark_text_updates_when_turns_tick_and_expire() -> void:
	var b: BattleState = BattleState.create(cfg, ScriptedDice.new(), [] as Array[Combatant], [_enemy()] as Array[Combatant])
	var c: Combatant = b.enemies[0]
	var v: CombatantView = _view(c)
	MarkRules.set_mark(c, fire, 2)
	var out: StatusSystem.AtbFullOutcome = b.statuses.on_atb_full(c, b.living(b.enemies))
	assert_false(out.mark_expired)
	assert_eq(v.mark_text(), "F1")
	out = b.statuses.on_atb_full(c, b.living(b.enemies))
	assert_true(out.mark_expired)
	assert_eq(v.mark_text(), "")

func test_mark_icon_draws_without_error() -> void:
	var c: Combatant = _enemy()
	var v: CombatantView = _view(c)
	MarkRules.set_mark(c, fire, 3)
	v.queue_redraw()
	await wait_process_frames(2)
	assert_eq(v.mark_text(), "F3")

# --- popups da reacao -----------------------------------------------------------

func test_plan_empty_without_reaction() -> void:
	assert_eq(ReactionText.plan(_hit({"reaction": &""}), _def(), &"a", 1, 0).size(), 0)
	assert_eq(ReactionText.plan(_hit({"reaction_effects": _fx()}), null, &"a", 1, 0).size(), 0)

func test_name_with_accent_is_on_top_in_blended_color() -> void:
	var d: ReactionDef = _def("Arco-íris")
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": _fx({"extra_damage": 10})}), d, &"a", 1, 0)
	var last: Dictionary = plan[plan.size() - 1]
	assert_eq(last["text"], "Arco-íris")
	assert_eq(last["color"], Color(0.5, 0.0, 0.5))
	assert_eq(last["size"], ReactionText.NAME_SIZE)
	for p: Dictionary in plan:
		if p != last:
			assert_lt(p["lift"], last["lift"], "o nome fica acima de tudo")

func test_extra_damage_stacks_above_the_hit() -> void:
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": _fx({"extra_damage": 10})}), _def(), &"a", 1, 0)
	assert_eq(_plan_texts(plan, &"x"), ["Extra -10", "Vapor"] as Array[String])
	assert_eq(plan[0]["lift"], CombatantView.LABEL_LIFT, "um andar acima do numero")

func test_target_slot_offsets_the_stack() -> void:
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": _fx({"extra_damage": 10})}), _def(), &"a", 3, 0)
	assert_eq(plan[0]["lift"], 3.0 * CombatantView.LABEL_LIFT)

func test_area_damage_goes_to_each_area_target() -> void:
	var fx: Dictionary = _fx({"area": [{"target_id": &"y", "amount": 7}, {"target_id": &"z", "amount": 7}]})
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": fx}), _def("Sobrecarga"), &"a", 1, 0)
	assert_eq(_plan_texts(plan, &"y"), ["-7"] as Array[String])
	assert_eq(_plan_texts(plan, &"z"), ["-7"] as Array[String])
	assert_eq(_plan_texts(plan, &"x"), ["Sobrecarga"] as Array[String])

func test_area_entry_with_zero_damage_shows_no_popup() -> void:
	var fx: Dictionary = _fx({"area": [{"target_id": &"y", "amount": 0, "blocked": false}, {"target_id": &"z", "amount": 5, "blocked": false}]})
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": fx}), _def(), &"a", 1, 0)
	assert_eq(_plan_texts(plan, &"y"), [] as Array[String], "sem popup -0")
	assert_eq(_plan_texts(plan, &"z"), ["-5"] as Array[String])

func test_area_entry_absorbed_by_a_barrier_shows_blocked() -> void:
	var fx: Dictionary = _fx({"area": [{"target_id": &"y", "amount": 0, "blocked": true}]})
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": fx}), _def(), &"a", 1, 0)
	assert_eq(_plan_texts(plan, &"y"), ["Bloqueado"] as Array[String])

func test_shared_slots_keep_popups_of_several_hits_apart() -> void:
	# Dois golpes (x e y) e a area do primeiro tambem pega y: com um so mapa de andares, os lifts de y diferem.
	var slots: Dictionary = {&"x": 1, &"y": 1, &"a": 0}
	var h1: Dictionary = _hit({"target_id": &"x", "reaction_effects": _fx({"extra_damage": 10, "area": [{"target_id": &"y", "amount": 7, "blocked": false}]})})
	var h2: Dictionary = _hit({"target_id": &"y", "reaction_effects": _fx({"extra_damage": 9})})
	var p1: Array[Dictionary] = ReactionText.plan(h1, _def(), &"a", 1, 0, slots)
	var p2: Array[Dictionary] = ReactionText.plan(h2, _def(), &"a", 1, 0, slots)
	var lifts: Array[float] = []
	for p: Dictionary in p1 + p2:
		if p["id"] == &"y" and p["size"] == 0:
			lifts.append(p["lift"])
	assert_eq(lifts.size(), 2)
	assert_ne(lifts[0], lifts[1], "a area em y e o extra do segundo golpe nao se sobrepoem")
	assert_eq(lifts[0], 1.0 * CombatantView.LABEL_LIFT)
	assert_eq(lifts[1], 2.0 * CombatantView.LABEL_LIFT)

func test_scene_stacks_popups_across_hits_of_one_action() -> void:
	var s: BattleScene = _scene()
	var t1: Combatant = s.ctrl.b.enemies[0]
	var t2: Combatant = s.ctrl.b.enemies[1]
	var table := ReactionTable.new()
	table.reactions = [_def()] as Array[ReactionDef]
	s.ctrl.b.reactions = table
	var r := ActionResult.new()
	r.hits.append(_hit({"target_id": t1.id, "reaction_effects": _fx({"area": [{"target_id": t2.id, "amount": 4, "blocked": false}]})}))
	r.hits.append(_hit({"target_id": t2.id, "reaction_effects": _fx({"extra_damage": 9})}))
	var pa := PendingAction.new()
	pa.actor = s.ctrl.b.heroes[0]
	s._show_reactions(pa, r, 0)
	var ys: Array[float] = []
	for n: Node in s.views[t2.id].get_children():
		if n is Label and ((n as Label).text == "-4" or (n as Label).text == "Extra -9"):
			ys.append((n as Label).position.y)
	assert_eq(ys.size(), 2)
	assert_ne(ys[0], ys[1])

func test_status_results_use_the_status_popup_style() -> void:
	var slow := StatusDef.new()
	slow.id = &"slow"
	slow.kind = StatusDef.Kind.SLOW
	var d: ReactionDef = _def("Vapor", {"target_statuses": [slow] as Array[StatusDef]})
	var fx: Dictionary = _fx({"statuses": [
			{"target_id": &"x", "status_id": &"slow", "result": StatusSystem.ApplyResult.APPLIED},
			{"target_id": &"y", "status_id": &"slow", "result": StatusSystem.ApplyResult.IMMUNE},
			{"target_id": &"z", "status_id": &"slow", "result": StatusSystem.ApplyResult.RESISTED}]})
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": fx}), d, &"a", 1, 0)
	assert_eq(_plan_texts(plan, &"x"), ["LENTO", "Vapor"] as Array[String])
	assert_eq(_plan_texts(plan, &"y"), ["Imune"] as Array[String])
	assert_eq(_plan_texts(plan, &"z"), ["Resistiu"] as Array[String])

func test_atb_texts() -> void:
	assert_eq(ReactionText.atb_text(-0.25), "ATB −25%")
	assert_eq(ReactionText.atb_text(0.3), "ATB +30%")
	assert_eq(ReactionText.atb_text(0.0), "")
	var fx: Dictionary = _fx({"atb": {"target": -0.25, "attacker": 0.3}})
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": fx}), _def("Trovão Negro"), &"a", 1, 0)
	assert_eq(_plan_texts(plan, &"x"), ["ATB −25%", "Trovão Negro"] as Array[String])
	assert_eq(_plan_texts(plan, &"a"), ["ATB +30%"] as Array[String])

func test_heals_are_green_on_attacker_and_allies() -> void:
	var fx: Dictionary = _fx({"heal_attacker": 12, "heal_allies": [{"target_id": &"b", "amount": 5}, {"target_id": &"c", "amount": 0}]})
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": fx}), _def("Transfusão"), &"a", 1, 0)
	assert_eq(_plan_texts(plan, &"a"), ["+12"] as Array[String])
	assert_eq(_plan_texts(plan, &"b"), ["+5"] as Array[String])
	assert_eq(_plan_texts(plan, &"c"), [] as Array[String], "cura zero nao aparece")
	for p: Dictionary in plan:
		if p["text"] == "+12" or p["text"] == "+5":
			assert_eq(p["color"], ReactionText.HEAL_COLOR)

func test_attacker_slot_offsets_attacker_popups() -> void:
	var fx: Dictionary = _fx({"heal_attacker": 12})
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": fx}), _def(), &"a", 1, 2)
	assert_eq(plan[0]["lift"], 2.0 * CombatantView.LABEL_LIFT)

func test_removed_status_text() -> void:
	var bar := StatusDef.new()
	bar.id = &"barrier"
	bar.kind = StatusDef.Kind.BARRIER
	var d: ReactionDef = _def("Quebra", {"remove_target_statuses": [bar] as Array[StatusDef]})
	var plan: Array[Dictionary] = ReactionText.plan(_hit({"reaction_effects": _fx({"removed": 1})}), d, &"a", 1, 0)
	assert_eq(_plan_texts(plan, &"x"), ["Barreira quebrada", "Quebra"] as Array[String])

func test_popup_slots_counts_label_and_burst() -> void:
	assert_eq(CombatantView.popup_slots(_hit()), 1)
	assert_eq(CombatantView.popup_slots(_hit({"affinity": ElementMath.Affinity.WEAK})), 2)
	assert_eq(CombatantView.popup_slots(_hit({"affinity": ElementMath.Affinity.WEAK, "burst": 4})), 3)
	assert_eq(CombatantView.popup_slots(_hit({"dodged": true})), 1)

func test_float_text_font_size_override() -> void:
	var v: CombatantView = _view(_enemy())
	v.float_text("Vapor", Color.WHITE, 8.0, 20)
	var l: Label = v.get_child(v.get_child_count() - 1) as Label
	assert_eq(l.get_theme_font_size("font_size"), 20)

func test_pair_text() -> void:
	assert_eq(ReactionText.pair_text(_def()), "Fogo + Água")

# --- cena e painel --------------------------------------------------------------

func _scene() -> BattleScene:
	var s: BattleScene = (load(SCENE) as PackedScene).instantiate() as BattleScene
	s.balance = Fixtures.cfg()
	add_child_autofree(s)
	s.set_process(false)
	var heroes: Array[HeroState] = []
	for id: String in ["teste_a", "teste_b", "teste_c"]:
		heroes.append(HeroState.create(load("res://data/test/heroes/%s.tres" % id) as CharacterDef, s.balance))
	s.start(heroes)
	return s

func test_scene_shows_reaction_popups_on_views() -> void:
	var s: BattleScene = _scene()
	var target: Combatant = s.ctrl.b.enemies[0]
	var other: Combatant = s.ctrl.b.enemies[1]
	var actor: Combatant = s.ctrl.b.heroes[0]
	var d: ReactionDef = _def("Arco-íris")
	var table := ReactionTable.new()
	table.reactions = [d] as Array[ReactionDef]
	s.ctrl.b.reactions = table
	var fx: Dictionary = _fx({"extra_damage": 9, "area": [{"target_id": other.id, "amount": 4}], "heal_attacker": 6})
	var r := ActionResult.new()
	r.hits.append(_hit({"target_id": target.id, "reaction_effects": fx}))
	var pa := PendingAction.new()
	pa.actor = actor
	s._on_action_impact(pa, r)
	assert_has(_texts(s.views[target.id]), "Arco-íris")
	assert_has(_texts(s.views[target.id]), "Extra -9")
	assert_has(_texts(s.views[other.id]), "-4")
	assert_has(_texts(s.views[actor.id]), "+6")

func test_neutral_scene_hit_adds_no_reaction_text() -> void:
	var s: BattleScene = _scene()
	var target: Combatant = s.ctrl.b.enemies[0]
	var r := ActionResult.new()
	r.hits.append(_hit({"target_id": target.id, "reaction": &"", "element": &"", "amount": 5}))
	var pa := PendingAction.new()
	pa.actor = s.ctrl.b.heroes[0]
	s._on_action_impact(pa, r)
	assert_eq(_texts(s.views[target.id]), ["-5"] as Array[String])

func _battle_state() -> BattleState:
	var heroes: Array[Combatant] = [Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10, 5, 5, 1)), cfg), Vector2.ZERO)]
	var enemies: Array[Combatant] = [_enemy(), _enemy(&"y")]
	return BattleState.create(cfg, ScriptedDice.new(), heroes, enemies)

func test_debug_panel_lists_marks_and_last_reaction() -> void:
	var b: BattleState = _battle_state()
	var ctrl := BattleController.new(b)
	var p := DebugPanel.new()
	add_child_autofree(p)
	var neutral: String = p.build_text(b, ctrl)
	assert_false(neutral.contains("Marcas"))
	assert_false(neutral.contains("Última reação"))
	MarkRules.set_mark(b.enemies[0], fire, 3)
	var t: String = p.build_text(b, ctrl)
	assert_string_contains(t, "Marcas")
	assert_string_contains(t, "x: Fogo (3)")
	assert_false(t.contains("y: Fogo"))
	var d: ReactionDef = _def()
	var table := ReactionTable.new()
	table.reactions = [d] as Array[ReactionDef]
	b.reactions = table
	var r := ActionResult.new()
	r.hits.append(_hit({"reaction_effects": _fx({"extra_damage": 10})}))
	p.record_impact(r, b)
	t = p.build_text(b, ctrl)
	assert_string_contains(t, "Última reação")
	assert_string_contains(t, "Vapor (Fogo + Água) em x")
	assert_string_contains(t, "Dano extra: 10 (50% do golpe)")

func test_debug_panel_hides_marks_of_downed() -> void:
	var b: BattleState = _battle_state()
	MarkRules.set_mark(b.enemies[0], fire, 3)
	b.enemies[0].hp = 0
	var p := DebugPanel.new()
	add_child_autofree(p)
	assert_false(p.build_text(b, BattleController.new(b)).contains("Marcas"))

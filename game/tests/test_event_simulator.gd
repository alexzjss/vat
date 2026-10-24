extends GutTest

## Simulador de eventos (M17): roda o `EventRunner` real num GameState novo e transcreve. Cobre a missão do `morador_c`
## em cada estado, a escolha do `morador_b`, recrutamento, batalha anotada e o teto de passos.

const CIDADE: String = "res://data/fatia/roteiro/cidade.roteiro"

static var _index: ContentIndex
static var _events: Dictionary = {}

static func _content() -> ContentIndex:
	if _index == null:
		_index = RoteiroTools.scan_content()
	return _index

func _event(id: StringName) -> EventScript:
	if _events.is_empty():
		_events = RoteiroTools.compile_file(CIDADE, _content())["events"]
	return _events[id] as EventScript

func _from_text(text: String, id: StringName = &"t") -> EventScript:
	var r: Dictionary = RoteiroTools.compile_text(text, "t.roteiro", _content())
	assert_eq(r["errors"], [] as Array[String], "o texto de teste compila")
	return (r["events"] as Dictionary)[id] as EventScript

func _has_line(sim: Dictionary, part: String) -> bool:
	for l: String in sim["transcript"]:
		if l.contains(part):
			return true
	return false

# --- morador_c ---

func test_morador_c_before_the_mission_offers_it_and_accepting_activates_it() -> void:
	var sim: Dictionary = EventSimulator.simulate(_event(&"morador_c"), {"answers": [0], "index": _content()})
	assert_true(_has_line(sim, "preciso de uma Erva de Teste"))
	assert_true(_has_line(sim, "escolha 0: Sim"))
	assert_true(_has_line(sim, "combinado"))
	assert_eq(sim["flags"]["missao_estado"], 1)
	assert_eq(sim["ended_reason"], "fim")

func test_morador_c_before_the_mission_declining_leaves_it_closed() -> void:
	var sim: Dictionary = EventSimulator.simulate(_event(&"morador_c"), {"answers": [1], "index": _content()})
	assert_true(_has_line(sim, "escolha 1: Não"))
	assert_true(_has_line(sim, "volte se mudar de ideia"))
	assert_eq(sim["flags"].get("missao_estado", 0), 0)

func test_morador_c_active_without_the_herb_asks_for_it() -> void:
	var sim: Dictionary = EventSimulator.simulate(_event(&"morador_c"), {"flags": {"missao_estado": 1}, "index": _content()})
	assert_true(_has_line(sim, "ainda falta a Erva de Teste"))
	assert_eq(sim["flags"]["missao_estado"], 1)
	assert_eq(sim["money"], 50, "sem mudança no dinheiro do perfil")

func test_morador_c_active_with_the_herb_delivers_and_pays() -> void:
	var sim: Dictionary = EventSimulator.simulate(_event(&"morador_c"),
			{"flags": {"missao_estado": 1}, "items": {"erva_teste": 1}, "index": _content()})
	assert_true(_has_line(sim, "Entregou"))
	assert_true(_has_line(sim, "Missão de teste concluída"))
	assert_eq(sim["flags"]["missao_estado"], 2)
	assert_eq(sim["money"], 90, "50 do perfil + 40 da recompensa")
	assert_false(sim["items"].has("erva_teste"), "a erva saiu da mochila")

func test_morador_c_after_the_mission_only_thanks() -> void:
	var sim: Dictionary = EventSimulator.simulate(_event(&"morador_c"), {"flags": {"missao_estado": 2}, "index": _content()})
	assert_true(_has_line(sim, "obrigado de novo"))
	assert_eq(sim["transcript"].size(), 1)
	assert_eq(sim["flags"]["missao_estado"], 2)

# --- morador_b ---

func test_morador_b_answers_0_and_1_take_different_branches() -> void:
	var yes: Dictionary = EventSimulator.simulate(_event(&"morador_b"), {"answers": [0]})
	assert_true(_has_line(yes, "que bom! Aproveite a loja"))
	assert_false(_has_line(yes, "mentira mesmo"))
	var no: Dictionary = EventSimulator.simulate(_event(&"morador_b"), {"answers": [1]})
	assert_true(_has_line(no, "mentira mesmo"))
	assert_false(_has_line(no, "Aproveite a loja"))

func test_answers_run_out_or_auto_picks_the_first_option() -> void:
	var empty: Dictionary = EventSimulator.simulate(_event(&"morador_b"), {"answers": []})
	assert_true(_has_line(empty, "escolha 0: Sim"))
	var auto: Dictionary = EventSimulator.simulate(_event(&"morador_b"), {"answers": "auto"})
	assert_true(_has_line(auto, "escolha 0: Sim"))
	var wild: Dictionary = EventSimulator.simulate(_event(&"morador_b"), {"answers": [9]})
	assert_true(_has_line(wild, "escolha 1: Não"), "índice fora da faixa vira a última opção")

func test_transcript_lists_the_options_and_the_speaker() -> void:
	var sim: Dictionary = EventSimulator.simulate(_event(&"morador_b"))
	var t: Array = sim["transcript"]
	assert_eq(t[0], "Morador B: Texto de teste: o que acha da Cidade Teste?")
	assert_eq(t[1], "pergunta: Gostou da cidade?")
	assert_eq(t[2], "    0) Sim")
	assert_eq(t[3], "    1) Não")

# --- recrutas, batalha, notas e laços ---

func test_recruit_adds_the_hero_and_says_so() -> void:
	var script: EventScript = _from_text("=== t\n@recrutar teste_d_f nivel 3\n")
	var sim: Dictionary = EventSimulator.simulate(script)
	assert_true(sim["heroes"].has("teste_d_f"))
	assert_true(_has_line(sim, "entrou no grupo"))
	var base: Dictionary = EventSimulator.simulate(_from_text("=== t\nSistema: nada.\n".replace("Sistema", "Alguém")))
	assert_false(base["heroes"].has("teste_d_f"))

func test_battle_step_is_noted_and_treated_as_won() -> void:
	var script: EventScript = _from_text("=== t\nAlguém: Lá vamos nós.\n@batalha enc_f1\nAlguém: Venci.\n")
	var sim: Dictionary = EventSimulator.simulate(script)
	assert_true(_has_line(sim, "batalha: enc_f1 (iniciaria aqui)"))
	assert_true(_has_line(sim, "Venci."), "o evento segue depois da batalha")
	assert_eq(sim["ended_reason"], "fim")

func test_move_camera_and_wait_become_notes() -> void:
	var script: EventScript = _from_text("=== t\n@mover Player Spot 1.5\n@camera BossSpot\n@esperar 0.6\n")
	var sim: Dictionary = EventSimulator.simulate(script)
	assert_true(_has_line(sim, "mover: Player -> Spot (velocidade 1.5)"))
	assert_true(_has_line(sim, "câmera: BossSpot"))
	assert_true(_has_line(sim, "esperar: 0.6 s"))

func test_end_demo_stops_the_simulation() -> void:
	var script: EventScript = _from_text("=== t\nAlguém: Fim.\n@fim_demo\nAlguém: Não deveria aparecer.\n")
	var sim: Dictionary = EventSimulator.simulate(script)
	assert_eq(sim["ended_reason"], "fim_demo")
	assert_false(_has_line(sim, "Não deveria"))

func test_items_money_and_flag_effects_show_in_the_final_state() -> void:
	var script: EventScript = _from_text("=== t\n@give item erva_teste 2\n@give moedas 10\n@add x 3\n@flag x\n")
	var sim: Dictionary = EventSimulator.simulate(script, {"items": {}, "money": 5})
	assert_eq(sim["items"]["erva_teste"], 2)
	assert_eq(sim["money"], 15)
	assert_eq(sim["flags"]["x"], 3)

func test_unknown_starting_item_is_noted() -> void:
	var script: EventScript = _from_text("=== t\nAlguém: Oi.\n")
	var sim: Dictionary = EventSimulator.simulate(script, {"items": {"nao_existe": 1}, "index": _content()})
	assert_true(_has_line(sim, "item inicial desconhecido: nao_existe"))

func test_step_cap_stops_a_loop_that_always_presents() -> void:
	var script: EventScript = _from_text("=== t\n== volta\nAlguém: De novo.\n-> volta\n")
	var sim: Dictionary = EventSimulator.simulate(script, {"max_steps": 20})
	assert_eq(sim["ended_reason"], "limite de passos")
	assert_true(_has_line(sim, "limite de 20 passos"))
	assert_lt(sim["transcript"].size(), 30)

func test_default_step_cap_also_applies() -> void:
	var script: EventScript = _from_text("=== t\n== volta\nAlguém: De novo.\n-> volta\n")
	var sim: Dictionary = EventSimulator.simulate(script)
	assert_eq(sim["ended_reason"], "limite de passos")

func test_the_simulation_does_not_touch_other_states() -> void:
	# Duas rodadas seguidas começam do mesmo ponto (GameState novo a cada uma).
	var a: Dictionary = EventSimulator.simulate(_event(&"morador_c"), {"answers": [0]})
	var b: Dictionary = EventSimulator.simulate(_event(&"morador_c"), {"answers": [0]})
	assert_eq(a["transcript"], b["transcript"])
	assert_eq(a["flags"], b["flags"])

# --- o pedido do painel (processo filho): RoteiroTools.simulate_job ---

func test_simulate_job_runs_a_request_made_of_plain_data() -> void:
	var text: String = FileAccess.get_file_as_string(CIDADE)
	var job: Dictionary = {"text": text, "source": "cidade.roteiro", "event": "morador_c", "setup": {
		"flags": {"missao_estado": 1.0}, "items": {"erva_teste": 1.0}, "money": 0.0, "answers": "auto"}}
	var res: Dictionary = RoteiroTools.simulate_job(job)
	assert_true(res["ok"])
	assert_eq(res["result"]["flags"]["missao_estado"], 2)
	assert_eq(res["result"]["money"], 40)

func test_simulate_job_reports_compile_errors_and_unknown_events() -> void:
	var bad: Dictionary = RoteiroTools.simulate_job({"text": "=== t\n@give item nao_existe\n", "source": "t.roteiro", "event": "t"})
	assert_false(bad["ok"])
	assert_false((bad["errors"] as Array).is_empty())
	var none: Dictionary = RoteiroTools.simulate_job({"text": "=== t\nAlguém: oi.\n", "source": "t.roteiro", "event": "outro"})
	assert_false(none["ok"])
	assert_true(str(none["errors"][0]).contains("outro"))

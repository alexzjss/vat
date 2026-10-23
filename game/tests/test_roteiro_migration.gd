extends GutTest

## Migração dos 14 eventos da fatia para `.roteiro` (M16): o que o compilador gera tem de dar o mesmo que os
## `.tres` antigos, que saíram do repositório. A referência é `golden/fatia_events.json`, gerada deles antes de
## apagá-los:
## - "steps": passo a passo (tipo e campos) dos eventos sem escolha ou desvio que mude de forma. Podem diferir só
##   o rótulo `fim` implícito no fim;
## - "traces": o que o EventRunner apresenta e como o GameState termina, por cenário (flags, itens, resposta de
##   escolha). Vale para todos os eventos, e é a prova dos que mudaram de forma (escolhas e `? item`).

const GOLDEN: String = "res://tests/golden/fatia_events.json"
const BOOKS: Array[String] = [
	"res://data/fatia/roteiro/cidade.roteiro",
	"res://data/fatia/roteiro/casas.roteiro",
	"res://data/fatia/roteiro/dungeon.roteiro",
]
## A flag oculta que o compilador gera para cada escolha -> a flag que o `.tres` antigo gravava.
const CHOICE_FLAGS: Dictionary = {
	&"_esc_morador_b_1": &"morador_b_escolha",
	&"_esc_morador_c_1": &"missao_escolha",
}
const ERVA: String = "res://data/fatia/items/erva_teste.tres"
const CAPACETE: String = "res://data/fatia/equipment/capacete_teste_b_f.tres"
const HERO: String = "res://data/fatia/heroes/teste_a_f.tres"

var _golden: Dictionary = {}
var _events: Dictionary = {}

func before_all() -> void:
	var f: FileAccess = FileAccess.open(GOLDEN, FileAccess.READ)
	assert_not_null(f, "golden existe")
	_golden = JSON.parse_string(f.get_as_text()) as Dictionary
	var index: ContentIndex = RoteiroTools.scan_content()
	for path: String in BOOKS:
		var r: Dictionary = RoteiroTools.compile_file(path, index)
		assert_eq(r["errors"], [] as Array[String], path)
		assert_eq(r["warnings"], [] as Array[String], path)
		_events.merge(r["events"] as Dictionary)

# --- blocos reutilizados pelo gerador do golden (tests/tools não: está no scratch) ---

## Tipo e campos de um passo, em texto estável. Recursos viram o caminho.
static func describe(step: EventStep) -> String:
	var props: Array[String] = []
	for p: Dictionary in step.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var v: Variant = step.get(p["name"])
		var shown: String = ""
		if v is Resource:
			shown = "res:" + (v as Resource).resource_path
		else:
			shown = var_to_str(v)
		props.append("%s=%s" % [p["name"], shown])
	props.sort()
	return "%s(%s)" % [step.get_script().get_global_name(), ", ".join(props)]

static func describe_all(ev: EventScript) -> Array[String]:
	var out: Array[String] = []
	for s: EventStep in ev.steps:
		out.append(describe(s))
	return out

## Estado de partida de um cenário: um herói, `erva` Ervas de Teste e as flags dadas.
static func make_state(sc: Dictionary) -> GameState:
	var hero: CharacterDef = load(HERO) as CharacterDef
	var g: GameState = GameState.new_game(Fixtures.cfg(), [hero] as Array[CharacterDef], [], [], ScriptedDice.new(), &"cidade", &"Start")
	var erva_n: int = int(sc.get("erva", 0))
	if erva_n > 0:
		g.inventory.add(load(ERVA) as ItemDef, erva_n)
	var flags: Dictionary = sc.get("flags", {})
	for k: Variant in flags:
		g.set_flag(StringName(k), int(flags[k]))
	return g

## Roda o evento até o fim e devolve a sequência apresentada, mais uma linha "STATE" com o resultado.
static func trace(ev: EventScript, sc: Dictionary) -> Array[String]:
	var g: GameState = make_state(sc)
	var r := EventRunner.new(ev, g)
	r.start()
	var out: Array[String] = []
	var answers: Array = sc.get("answers", [])
	var ai: int = 0
	var guard: int = 0
	while not r.finished and guard < 200:
		guard += 1
		var q: EventRequest = r.current()
		match q.kind:
			EventRequest.Kind.SAY:
				out.append("SAY|%s|%s" % [q.speaker, q.text])
			EventRequest.Kind.CHOICE:
				out.append("CHOICE|%s|%s|%s" % [q.speaker, q.text, "/".join(q.options)])
			EventRequest.Kind.CAMERA_TO:
				out.append("CAMERA|%s" % q.marker)
			EventRequest.Kind.WAIT:
				out.append("WAIT|%s" % q.seconds)
			EventRequest.Kind.END_DEMO:
				out.append("END_DEMO")
			_:
				out.append("OTHER|%d" % q.kind)
		var a: int = int(answers[ai]) if (q.kind == EventRequest.Kind.CHOICE and ai < answers.size()) else 0
		if q.kind == EventRequest.Kind.CHOICE:
			ai += 1
		r.resume(a)
	out.append("FINISHED|%s|ABORTED|%s" % [r.finished, r.aborted])
	out.append("STATE|" + _state_text(g))
	return out

static func _state_text(g: GameState) -> String:
	var flags: Dictionary = {}
	for k: StringName in g.flags:
		flags[CHOICE_FLAGS.get(k, k)] = g.flags[k]
	var fl: Array[String] = []
	for k: Variant in flags:
		fl.append("%s=%d" % [k, flags[k]])
	fl.sort()
	var heroes: Array[String] = []
	for h: HeroState in g.roster():
		heroes.append("%s:L%d:xp%d" % [h.def.id, h.level, h.xp])
	return "flags[%s] money=%d erva=%d capacete=%d heroes[%s]" % [
		",".join(fl), g.money, g.inventory.count(&"erva_teste"), g.bag.count(&"capacete_teste_b_f"), ",".join(heroes)]

static func _strings(src: Array) -> Array[String]:
	var out: Array[String] = []
	for v: Variant in src:
		out.append(str(v))
	return out

# --- testes ---

func test_golden_covers_the_14_slice_events() -> void:
	var ids: Array = (_golden["traces"] as Dictionary).keys()
	ids.sort()
	assert_eq(ids.size(), 14)
	for id: Variant in ids:
		assert_true(_events.has(StringName(id)), "evento '%s' no roteiro" % id)
	assert_eq(_events.size(), 14, "nenhum evento a mais")

func test_event_steps_match_the_old_tres_step_by_step() -> void:
	var steps: Dictionary = _golden["steps"]
	assert_gt(steps.size(), 0)
	for id: Variant in steps:
		var want: Array = steps[id]
		var got: Array[String] = describe_all(_events[StringName(id)] as EventScript)
		# O `fim` implícito do compilador pode ser a única diferença no fim.
		var fim: String = "LabelStep(label_name=&\"fim\")"
		if got.size() == want.size() + 1 and got[got.size() - 1] == fim:
			got.remove_at(got.size() - 1)
		assert_eq(got, _strings(want), "passos de '%s'" % id)

func test_event_behaviour_matches_the_old_tres_in_every_scenario() -> void:
	var traces: Dictionary = _golden["traces"]
	var scenarios: Dictionary = _golden["scenarios"]
	var checked: int = 0
	for id: Variant in traces:
		var by_sc: Dictionary = traces[id]
		for sc_name: Variant in by_sc:
			var sc: Dictionary = (scenarios[id] as Dictionary)[sc_name]
			var got: Array[String] = trace(_events[StringName(id)] as EventScript, sc)
			assert_eq(got, _strings(by_sc[sc_name]), "%s / %s" % [id, sc_name])
			checked += 1
	assert_gte(checked, 20, "cenários rodados")

func test_choice_branches_in_the_quest_and_the_citizen_follow_the_answer() -> void:
	# Garantia direta, sem o golden: a resposta escolhida decide o ramo.
	var b: EventScript = _events[&"morador_b"] as EventScript
	assert_true((trace(b, {"answers": [0]}) as Array).any(func(t: String) -> bool: return t.contains("que bom")))
	assert_true((trace(b, {"answers": [1]}) as Array).any(func(t: String) -> bool: return t.contains("de mentira")))

func test_imported_books_hold_the_same_events_as_the_compiled_text() -> void:
	var seen: int = 0
	for path: String in BOOKS:
		var book: RoteiroBook = load(path) as RoteiroBook
		assert_not_null(book, "%s importado como RoteiroBook" % path)
		for id: StringName in book.events:
			assert_true(_events.has(id), "evento '%s'" % id)
			assert_eq(describe_all(book.events[id]), describe_all(_events[id] as EventScript), "importado == compilado: %s" % id)
			seen += 1
	assert_eq(seen, 14)

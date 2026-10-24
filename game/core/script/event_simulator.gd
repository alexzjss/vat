class_name EventSimulator
extends RefCounted

## Simulador de eventos (M17), puro: roda um `EventScript` com o `EventRunner` real num `GameState` novo (heróis do perfil
## da fatia) e devolve a transcrição. Sem Node, sem Input e sem escrita em disco. Serve para testar uma missão sem abrir o jogo.
##
## `setup` (tudo opcional):
## - `flags`: Dictionary id -> valor inicial.
## - `items`: Dictionary id -> quantidade; se vier, SUBSTITUI a mochila do perfil. Precisa de `index` para achar os itens.
## - `money`: dinheiro inicial; se vier, substitui o do perfil.
## - `answers`: Array de índices (0-based) das escolhas, na ordem em que aparecem, ou "auto". Acabou a lista, vale a
##   primeira opção. Índice fora da faixa é limitado às opções.
## - `index`: ContentIndex para achar os itens iniciais.
## - `profile` / `cfg`: StartProfile e BalanceConfig (padrão: o perfil da fatia e o balance de teste).
## - `max_steps`: teto de apresentações (padrão 500), contra laços que sempre apresentam algo.
##
## Resultado: `{transcript: Array[String], flags: Dictionary, items: Dictionary, money: int, heroes: Array[String],
## ended_reason: String}`. `ended_reason`: "fim" (o evento acabou), "fim_demo", "abortado" (o runner abortou: rótulo
## inexistente ou laço sem apresentação) ou "limite de passos".
## Uma batalha é anotada ("batalha: <id> (iniciaria aqui)") e tratada como vencida; mover, câmera e esperar viram notas.

const DEFAULT_PROFILE: String = "res://data/fatia/start.tres"
const DEFAULT_BALANCE: String = "res://data/test/balance.tres"
const DEFAULT_MAX_STEPS: int = 500

static func simulate(script: EventScript, setup: Dictionary = {}) -> Dictionary:
	var transcript: Array[String] = []
	var profile: StartProfile = setup.get("profile", null) as StartProfile
	if profile == null:
		profile = load(DEFAULT_PROFILE) as StartProfile
	var cfg: BalanceConfig = setup.get("cfg", null) as BalanceConfig
	if cfg == null:
		cfg = load(DEFAULT_BALANCE) as BalanceConfig
	var index: ContentIndex = setup.get("index", null) as ContentIndex

	var items: Array[ItemDef] = []
	var counts: Array[int] = []
	if setup.has("items"):
		var wanted: Dictionary = setup["items"]
		for k: Variant in wanted:
			var n: int = int(wanted[k])
			var def: ItemDef = null
			if index != null:
				def = index.resolve(&"item", StringName(str(k))) as ItemDef
			if def == null:
				transcript.append("(item inicial desconhecido: %s)" % str(k))
			elif n > 0:
				items.append(def)
				counts.append(n)
	else:
		items.assign(profile.items)
		counts.assign(profile.item_counts)
	var money: int = int(setup["money"]) if setup.has("money") else profile.money
	var state: GameState = GameState.new_game(cfg, profile.party, items, counts, Dice.new(1),
			profile.map, profile.spawn, GameState.MAX_ACTIVE, profile.equipment, profile.equipment_counts, money)
	var flags: Dictionary = setup.get("flags", {})
	for k: Variant in flags:
		state.set_flag(StringName(str(k)), int(flags[k]))

	var answers: Array = []
	var auto: bool = true
	var raw: Variant = setup.get("answers", "auto")
	if raw is Array:
		answers = raw
		auto = false
	var max_steps: int = int(setup.get("max_steps", DEFAULT_MAX_STEPS))

	var reason: String = "fim"
	var runner := EventRunner.new(script, state)
	runner.start()
	var steps: int = 0
	var answer_i: int = 0
	while not runner.finished:
		var req: EventRequest = runner.current()
		if req == null:
			break
		steps += 1
		if steps > max_steps:
			transcript.append("(limite de %d passos: o evento parece não terminar)" % max_steps)
			reason = "limite de passos"
			runner.cancel()
			break
		var answer: int = 0
		match req.kind:
			EventRequest.Kind.SAY:
				transcript.append(_say_line(req))
			EventRequest.Kind.CHOICE:
				transcript.append(_say_line(req))
				for i: int in req.options.size():
					transcript.append("    %d) %s" % [i, req.options[i]])
				if not auto and answer_i < answers.size():
					answer = int(answers[answer_i])
				answer_i += 1
				answer = clampi(answer, 0, maxi(0, req.options.size() - 1))
				if req.options.size() > 0:
					transcript.append("escolha %d: %s" % [answer, req.options[answer]])
			EventRequest.Kind.START_BATTLE:
				transcript.append("batalha: %s (iniciaria aqui)" % (req.encounter.id if req.encounter != null else &"?"))
			EventRequest.Kind.MOVE_ACTOR:
				transcript.append("mover: %s -> %s%s" % [req.actor, req.marker, "" if req.speed == 0.0 else " (velocidade %s)" % str(req.speed)])
			EventRequest.Kind.CAMERA_TO:
				transcript.append("câmera: %s" % req.marker)
			EventRequest.Kind.WAIT:
				transcript.append("esperar: %s s" % str(req.seconds))
			EventRequest.Kind.END_DEMO:
				transcript.append("fim da demo")
				reason = "fim_demo"
				runner.cancel()
				break
		runner.resume(answer)
	if reason == "fim" and runner.aborted:
		reason = "abortado"
		transcript.append("(o evento foi abortado: rótulo inexistente ou laço sem apresentação)")
	return {"transcript": transcript, "flags": _flags_of(state), "items": _items_of(state), "money": state.money,
			"heroes": _heroes_of(state), "ended_reason": reason}

static func _say_line(req: EventRequest) -> String:
	if req.kind == EventRequest.Kind.CHOICE:
		return "pergunta: %s" % req.text if req.speaker == "" else "%s pergunta: %s" % [req.speaker, req.text]
	if req.speaker == "":
		return "[sistema] %s" % req.text
	if req.portrait != &"":
		return "%s [%s]: %s" % [req.speaker, req.portrait, req.text]
	return "%s: %s" % [req.speaker, req.text]

static func _flags_of(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	for k: StringName in state.flags:
		out[String(k)] = state.flags[k]
	return out

static func _items_of(state: GameState) -> Dictionary:
	var out: Dictionary = {}
	for d: ItemDef in state.inventory.listing():
		out[String(d.id)] = state.inventory.count(d.id)
	return out

static func _heroes_of(state: GameState) -> Array[String]:
	var out: Array[String] = []
	for h: HeroState in state.roster():
		out.append(String(h.def.id))
	return out

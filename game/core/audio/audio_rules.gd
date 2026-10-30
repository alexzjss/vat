class_name AudioRules
extends RefCounted

## Regras puras de qual musica toca onde (M19). Recebem um retrato do estado (`snapshot`) e os ids padrao do banco
## e devolvem comandos para o AudioDirector executar. Sem Node, sem AudioServer: so decisao.
##
## Comando: `{op: Op, id: StringName, fade: float, resume: bool, next_id: StringName}`.
## Id vazio = silencio naquele espaco, nunca um erro.

enum Op { NOOP, PLAY_MUSIC, STOP_MUSIC, PLAY_JINGLE }
enum Outcome { NONE, VICTORY, DEFEAT, FLED }

## Valor de `event_music` para "@musica parar": silencio ate o evento trocar a musica.
const EVENT_STOP: StringName = &"@parar"

const MAP_FADE: float = 0.5
const BATTLE_FADE: float = 0.25
const RETURN_FADE: float = 0.5

## Retrato do estado de audio. `overrides` troca campos; chaves desconhecidas sao ignoradas.
static func make_snapshot(overrides: Dictionary = {}) -> Dictionary:
	var s: Dictionary = {
		"map_music": &"",
		"in_battle": false,
		"battle_music": &"",
		"boss": false,
		"outcome": Outcome.NONE,
		"event_music": &"",
		"current": &"",
	}
	for k: Variant in overrides:
		if s.has(k):
			s[k] = overrides[k]
	return s

## Ids padrao do banco: `battle_music`, `boss_music`, `victory_jingle`, `defeat_jingle` (todos opcionais).
static func make_defaults(overrides: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"battle_music": &"", "boss_music": &"", "victory_jingle": &"", "defeat_jingle": &""}
	for k: Variant in overrides:
		if d.has(k):
			d[k] = overrides[k]
	return d

static func noop() -> Dictionary:
	return {"op": Op.NOOP, "id": &"", "fade": 0.0, "resume": false, "next_id": &""}

static func play_music(id: StringName, fade: float) -> Dictionary:
	return {"op": Op.PLAY_MUSIC, "id": id, "fade": fade, "resume": false, "next_id": &""}

static func stop_music(fade: float) -> Dictionary:
	return {"op": Op.STOP_MUSIC, "id": &"", "fade": fade, "resume": false, "next_id": &""}

## Toca o jingle; se `resume`, o diretor volta a `next_id` (vazio = silencio) quando ele termina.
static func play_jingle(id: StringName, resume: bool, next_id: StringName = &"") -> Dictionary:
	return {"op": Op.PLAY_JINGLE, "id": id, "fade": 0.0, "resume": resume, "next_id": next_id}

## A musica de fundo fora de batalha: a do evento, se houver, senao a do mapa (EVENT_STOP = silencio).
static func field_track(snap: Dictionary) -> StringName:
	var ev: StringName = snap.get("event_music", &"")
	if ev == EVENT_STOP:
		return &""
	if ev != &"":
		return ev
	return snap.get("map_music", &"")

## A musica da batalha: a do encontro, senao a do chefe (se o padrao tiver uma), senao a padrao; vazio = nenhuma.
static func battle_track(snap: Dictionary, defaults: Dictionary) -> StringName:
	var own: StringName = snap.get("battle_music", &"")
	if own != &"":
		return own
	if snap.get("boss", false):
		var boss_track: StringName = defaults.get("boss_music", &"")
		if boss_track != &"":
			return boss_track
	return defaults.get("battle_music", &"")

## Troca para `target` sem reiniciar a mesma faixa; alvo vazio para a musica (ou nada, se ja e silencio).
static func _switch_to(target: StringName, current: StringName, fade: float) -> Dictionary:
	if target == current:
		return noop()
	if target == &"":
		return stop_music(fade)
	return play_music(target, fade)

## Entrou num mapa: toca a musica de fundo com fade, sem reiniciar se ja e a atual.
static func on_enter_map(snap: Dictionary) -> Array[Dictionary]:
	return [_switch_to(field_track(snap), snap.get("current", &""), MAP_FADE)]

## Comecou uma batalha: a faixa dela; sem faixa nenhuma a musica do mapa continua.
static func on_battle_start(snap: Dictionary, defaults: Dictionary) -> Array[Dictionary]:
	var track: StringName = battle_track(snap, defaults)
	if track == &"":
		return [noop()]
	return [_switch_to(track, snap.get("current", &""), BATTLE_FADE)]

## Terminou a batalha. Vitoria: jingle e volta ao fundo. Derrota: so o jingle (ou silencio). Fuga: volta direto.
static func on_battle_end(snap: Dictionary, defaults: Dictionary) -> Array[Dictionary]:
	var back: StringName = field_track(snap)
	var current: StringName = snap.get("current", &"")
	match int(snap.get("outcome", Outcome.NONE)):
		Outcome.VICTORY:
			var win: StringName = defaults.get("victory_jingle", &"")
			if win == &"":
				return [_switch_to(back, current, RETURN_FADE)]
			return [play_jingle(win, true, back)]
		Outcome.DEFEAT:
			var lose: StringName = defaults.get("defeat_jingle", &"")
			if lose == &"":
				return [stop_music(RETURN_FADE) if current != &"" else noop()]
			return [play_jingle(lose, false)]
		Outcome.FLED:
			return [_switch_to(back, current, RETURN_FADE)]
	return [noop()]

## Um evento mudou a musica (`event_music` ja atualizado no retrato): toca a nova, ou para.
## Durante uma batalha o retrato diz o que tocar: o evento so vale ao voltar ao campo.
static func on_event_music(snap: Dictionary) -> Array[Dictionary]:
	if snap.get("in_battle", false):
		return [noop()]
	return [_switch_to(field_track(snap), snap.get("current", &""), MAP_FADE)]

## Escala de tom para uma variacao (fracao) e um sorteio `roll` em [-1, 1]; nunca abaixo de 0.01.
static func pitch_scale(variation: float, roll: float) -> float:
	return maxf(0.01, 1.0 + clampf(variation, 0.0, 1.0) * clampf(roll, -1.0, 1.0))

class_name DemoM11
extends Node

## Roteiro de debug (`-- --demo-m11`): começa direto na batalha do chefe de teste da dungeon, com o grupo forte e
## auto_battle (ataque básico). Mostra a troca de fase, o anúncio, o contra-ataque, a parte revivida e os estados
## no HUD, e termina na vitória. Cada marco imprime uma linha com o quadro (verificação com --write-movie).

const DEFAULT_SEED: int = 8
const PARTY_LEVEL: int = 14
const HEADLESS_TIME_SCALE: float = 3.0
const BOSS_ENCOUNTER: String = "res://data/test/encounters/chefe_dungeon.tres"
## Limite de quadros de espera da batalha (evita travar o roteiro).
const MAX_FRAMES: int = 60000

var game: Game
var map: LocalMap

func _ready() -> void:
	game = get_parent() as Game
	if game == null:
		push_error("DemoM11: precisa ser filho do Game")
		queue_free()
		return
	_run.call_deferred()

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout

func _log(text: String) -> void:
	print("DemoM11 [quadro %d, %.1f s]: %s" % [Engine.get_process_frames(), Time.get_ticks_msec() / 1000.0, text])

## Grupo forte: nível PARTY_LEVEL, pontos em Força e Vitalidade, HP/AP cheios.
func _strengthen() -> void:
	var cfg: BalanceConfig = game.state.cfg
	for h: HeroState in game.state.heroes:
		XpCalculator.grant(h, XpCalculator.xp_for_level(PARTY_LEVEL, cfg), cfg)
		var half: int = h.pending_points / 2
		XpCalculator.allocate(h, &"vitality", half)
		XpCalculator.allocate(h, &"strength", h.pending_points)
		h.rest(cfg)

func _watch(ctrl: BattleController) -> void:
	ctrl.phase_changed.connect(func(c: Combatant, banner: String) -> void: _log("fase de %s: %s" % [c.display_name, banner]))
	ctrl.charge_started.connect(func(c: Combatant, a: PendingAction) -> void: _log("%s prepara %s!" % [c.display_name, a.ability.display_name]))
	ctrl.counter_fired.connect(func(c: Combatant, t: Combatant) -> void: _log("%s contra-ataca %s" % [c.display_name, t.display_name]))
	ctrl.action_impact.connect(func(a: PendingAction, r: ActionResult) -> void:
		for hit: Dictionary in r.hits:
			if hit["kind"] == EffectDef.Kind.REVIVE:
				_log("%s reergueu uma parte (%s)" % [a.actor.display_name, hit["target_id"]])
			elif hit["kind"] == EffectDef.Kind.APPLY_STATUS and int(hit["status_result"]) == StatusSystem.ApplyResult.APPLIED:
				_log("%s aplicou %s em %s" % [a.actor.display_name, a.ability.display_name, hit["target_id"]])
			elif hit["kind"] == EffectDef.Kind.DAMAGE and hit.get("shielded", false):
				_log("nucleo protegido recebeu %d" % int(hit["amount"])))

## Semente do Dice da batalha: `-- --demo-m11 --seed=N` troca (para explorar desfechos); padrão DEFAULT_SEED.
func _seed() -> int:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			return a.trim_prefix("--seed=").to_int()
	return DEFAULT_SEED

func _hps(arr: Array[Combatant]) -> String:
	var parts: PackedStringArray = []
	for c: Combatant in arr:
		parts.append("%s %d" % [c.id, c.hp])
	return ", ".join(parts)

func _run() -> void:
	await _wait(0.5)
	game.go_to(&"dungeon_teste", &"Entry")
	while game.busy or not game.current is LocalMap:
		await get_tree().process_frame
	map = game.current as LocalMap
	map.auto_battle = true
	map.dice_seed = _seed()
	# Sem janela (execução headless com limite de quadros) o chefe não acabaria a tempo: acelera o tempo do jogo.
	# Com janela / --write-movie o tempo segue normal.
	if DisplayServer.get_name() == "headless":
		Engine.time_scale = HEADLESS_TIME_SCALE
	_strengthen()
	game.state.settings.battle_speed = game.state.cfg.battle_speed_mults.size()
	await _wait(0.5)
	map.start_event_battle(load(BOSS_ENCOUNTER) as EncounterDef)
	if map.battle == null:
		_log("FALHA: a batalha do chefe não começou")
		return
	# Depois de iniciada: o roteiro de resultado/nível roda ao fim, sem enfraquecer os inimigos.
	map.battle.demo_result = true
	_watch(map.battle.ctrl)
	_log("batalha do chefe (grupo nível %d)" % PARTY_LEVEL)
	var guard: int = 0
	while map.battle != null and guard < MAX_FRAMES:
		guard += 1
		if guard % 600 == 0 and map.battle.ctrl != null:
			_log("HP: %s | grupo: %s" % [_hps(map.battle.ctrl.b.enemies), _hps(map.battle.ctrl.b.heroes)])
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_log("fim da batalha; chefe derrotado: %s" % game.state.is_defeated(&"chefe_dungeon"))
	await _wait(1.0)
	get_tree().quit()

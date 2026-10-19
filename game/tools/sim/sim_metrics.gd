class_name SimMetrics
extends RefCounted

## Metricas agregadas de um cenario (spec M5 §3). Tempos em segundos de jogo.

var label: String = ""
var runs: int = 0
var wins: int = 0
var losses: int = 0
var timeouts: int = 0
var durations: Array[float] = []
## Acoes por heroi (soma de todas as execucoes), por id do heroi.
var hero_actions: Dictionary[StringName, int] = {}
var basic_actions: int = 0
var basic_damage: int = 0
var ability_actions: int = 0
var ability_damage: int = 0
## Acoes de heroi ate cada inimigo cair, por id do EnemyDef.
var ttk_actions: Dictionary[StringName, Array] = {}
var ttk_seconds: Dictionary[StringName, Array] = {}
## % de HP do grupo (0..1) ao fim de cada execucao.
var party_hp_pct: Array[float] = []
var ap_spent: int = 0
## XP total ganho (so em vitorias) por heroi.
var xp_total: Dictionary[StringName, int] = {}
## Estimativa de batalhas (vitorias) ate o proximo nivel, por heroi; -1 se nao ha XP.
var battles_to_level: Dictionary[StringName, int] = {}
var statuses_applied: int = 0
var statuses_resisted: int = 0
## Dano total causado pelos herois em cada execucao (indice = execucao; permite checar a semente base_seed + i).
var run_hero_damage: Array[int] = []

static func _mean(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var total: float = 0.0
	for v: Variant in arr:
		total += float(v)
	return total / float(arr.size())

func win_rate() -> float:
	return float(wins) / float(maxi(1, runs))

func mean_duration() -> float:
	return _mean(durations)

@warning_ignore("integer_division")
func median_duration() -> float:
	if durations.is_empty():
		return 0.0
	var s: Array[float] = durations.duplicate()
	s.sort()
	var n: int = s.size()
	if n % 2 == 1:
		return s[n / 2]
	return (s[n / 2 - 1] + s[n / 2]) / 2.0

func mean_actions_per_hero() -> float:
	if hero_actions.is_empty() or runs == 0:
		return 0.0
	var total: int = 0
	for n: int in hero_actions.values():
		total += n
	return float(total) / float(hero_actions.size() * runs)

func avg_basic_damage() -> float:
	return float(basic_damage) / float(maxi(1, basic_actions))

## Dano por acao de habilidade (inclui acoes sem dano, ex. estados). Dano de itens fica fora da divisao basico/habilidade.
func avg_ability_damage() -> float:
	return float(ability_damage) / float(maxi(1, ability_actions))

func mean_ttk_actions(enemy_id: StringName) -> float:
	var arr: Array = ttk_actions.get(enemy_id, [])
	return _mean(arr)

func mean_party_hp_pct() -> float:
	return _mean(party_hp_pct)

func mean_ap_spent() -> float:
	return float(ap_spent) / float(maxi(1, runs))

func _ttk_text() -> String:
	var parts: Array[String] = []
	for id: StringName in ttk_actions:
		parts.append("%s %.1f" % [id, mean_ttk_actions(id)])
	return ", ".join(parts)

func _xp_text() -> String:
	var parts: Array[String] = []
	for id: StringName in xp_total:
		var per_win: float = float(xp_total[id]) / float(maxi(1, wins))
		var btl: int = int(battles_to_level.get(id, -1))
		parts.append("%s %.0f (%s)" % [id, per_win, "?" if btl < 0 else str(btl)])
	return ", ".join(parts)

static func header() -> String:
	return "| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes; so execucoes em que o inimigo morreu) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |\n" \
		+ "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"

func to_markdown_row() -> String:
	return "| %s | %d | %d | %d | %d | %.1f | %.1f | %.1f | %.1f | %.1f | %s | %.0f%% | %.1f | %s | %d/%d |" % [
		label, runs, wins, losses, timeouts, mean_duration(), median_duration(), mean_actions_per_hero(),
		avg_basic_damage(), avg_ability_damage(), _ttk_text(), mean_party_hp_pct() * 100.0, mean_ap_spent(),
		_xp_text(), statuses_applied, statuses_resisted]

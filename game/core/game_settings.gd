class_name GameSettings
extends RefCounted

## Configuracoes do jogador (menu Config). Valem para todos os slots; nao fazem parte do save.
## Todos os limites e padroes vem do BalanceConfig.

enum AtbMode { WAIT, ACTIVE }

var atb_mode: AtbMode = AtbMode.WAIT
var cursor_memory: bool = true

var _cfg: BalanceConfig
var _battle_speed: int
var _text_speed: int
var _volume: int

var battle_speed: int:
	get:
		return _battle_speed
	set(v):
		_battle_speed = clampi(v, 1, _cfg.battle_speed_mults.size())

var text_speed: int:
	get:
		return _text_speed
	set(v):
		_text_speed = clampi(v, 1, _cfg.text_speed_max)

var volume: int:
	get:
		return _volume
	set(v):
		_volume = clampi(v, 0, _cfg.volume_max)

func _init(cfg: BalanceConfig) -> void:
	_cfg = cfg
	battle_speed = cfg.default_battle_speed
	text_speed = cfg.default_text_speed
	volume = cfg.default_volume

## Multiplicador do delta do ATB para a velocidade escolhida.
func speed_mult() -> float:
	return _cfg.battle_speed_mults[_battle_speed - 1]

func to_dict() -> Dictionary:
	return {
		"atb_mode": int(atb_mode),
		"battle_speed": _battle_speed,
		"cursor_memory": cursor_memory,
		"text_speed": _text_speed,
		"volume": _volume,
	}

## Campos ausentes ou de tipo errado ficam com o valor atual; valores fora da faixa sofrem clamp.
func from_dict(d: Dictionary) -> void:
	if d.get("atb_mode") is int or d.get("atb_mode") is float:
		atb_mode = AtbMode.ACTIVE if int(d["atb_mode"]) == int(AtbMode.ACTIVE) else AtbMode.WAIT
	if d.get("battle_speed") is int or d.get("battle_speed") is float:
		battle_speed = int(d["battle_speed"])
	if d.get("cursor_memory") is bool:
		cursor_memory = d["cursor_memory"]
	if d.get("text_speed") is int or d.get("text_speed") is float:
		text_speed = int(d["text_speed"])
	if d.get("volume") is int or d.get("volume") is float:
		volume = int(d["volume"])

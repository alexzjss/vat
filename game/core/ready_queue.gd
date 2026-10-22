# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name ReadyQueue
extends RefCounted

## Fila de prontos. Ordem: Velocidade efetiva desc -> entry_tick asc -> tie_key asc.

var _cfg: BalanceConfig
var _dice: Dice
var _entries: Array[Dictionary] = []

func _init(cfg: BalanceConfig, dice: Dice) -> void:
	_cfg = cfg
	_dice = dice

func push(c: Combatant, tick: int) -> void:
	if has(c):
		return
	_entries.append({"combatant": c, "entry_tick": tick, "tie_key": _dice.roll()})

func has(c: Combatant) -> bool:
	for e: Dictionary in _entries:
		if e["combatant"] == c:
			return true
	return false

func remove(c: Combatant) -> void:
	for i: int in range(_entries.size()):
		if _entries[i]["combatant"] == c:
			_entries.remove_at(i)
			return

func _sorted_entries() -> Array[Dictionary]:
	var copy: Array[Dictionary] = _entries.duplicate()
	copy.sort_custom(_before)
	return copy

func _before(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = StatCalculator.effective(a["combatant"], &"speed", _cfg)
	var sb: int = StatCalculator.effective(b["combatant"], &"speed", _cfg)
	if sa != sb:
		return sa > sb
	if a["entry_tick"] != b["entry_tick"]:
		return a["entry_tick"] < b["entry_tick"]
	return a["tie_key"] < b["tie_key"]

func _drop_downed() -> void:
	var kept: Array[Dictionary] = []
	for e: Dictionary in _entries:
		var c: Combatant = e["combatant"]
		if not c.is_out():
			kept.append(e)
	_entries = kept

func ordered() -> Array[Combatant]:
	var out: Array[Combatant] = []
	for e: Dictionary in _sorted_entries():
		out.append(e["combatant"])
	return out

func peek() -> Combatant:
	_drop_downed()
	var s: Array[Dictionary] = _sorted_entries()
	if s.is_empty():
		return null
	return s[0]["combatant"]

func pop_next() -> Combatant:
	var c: Combatant = peek()
	if c != null:
		remove(c)
	return c

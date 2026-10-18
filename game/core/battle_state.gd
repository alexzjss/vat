# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name BattleState
extends RefCounted

var cfg: BalanceConfig
var dice: Dice
var heroes: Array[Combatant] = []
var enemies: Array[Combatant] = []
var ledger: ContributionLedger
var statuses: StatusSystem
var queue: ReadyQueue
var inventory: Inventory
var tick: int = 0

static func create(p_cfg: BalanceConfig, p_dice: Dice, p_heroes: Array[Combatant], p_enemies: Array[Combatant]) -> BattleState:
	var s := BattleState.new()
	s.cfg = p_cfg
	s.dice = p_dice
	s.heroes = p_heroes
	s.enemies = p_enemies
	s.ledger = ContributionLedger.new()
	s.statuses = StatusSystem.new(p_cfg, s.ledger, p_dice)
	s.queue = ReadyQueue.new(p_cfg, p_dice)
	s.inventory = Inventory.new()
	s.tick = 0
	return s

func allies_of(c: Combatant) -> Array[Combatant]:
	return heroes if c.team == Combatant.Team.HERO else enemies

func foes_of(c: Combatant) -> Array[Combatant]:
	return enemies if c.team == Combatant.Team.HERO else heroes

func living(arr: Array[Combatant]) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c: Combatant in arr:
		if not c.is_down():
			out.append(c)
	return out

func all() -> Array[Combatant]:
	var out: Array[Combatant] = []
	out.append_array(heroes)
	out.append_array(enemies)
	return out

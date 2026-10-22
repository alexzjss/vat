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
## Herois da reserva (M8.5): so podem ser chamados como Suporte; nao entram em heroes, fila nem alvos.
var reserve: Array[HeroState] = []
## Onde o reserva aparece (SupportSpot da arena); nao finito = ao lado de quem o chamou.
var support_pos: Vector2 = Vector2.INF
## Reacoes elementais (M14). Injetavel nos testes; em producao vem de TABLE_PATH, se existir (senao nada reage).
var reactions: ReactionTable
## Terreno do mapa da batalha (M15); nulo = sem efeito. O nucleo so le: quem monta a batalha preenche.
var terrain: TerrainDef

const REACTION_TABLE_PATH: String = "res://data/reactions/tabela.tres"

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
	s.reactions = load_reactions()
	return s

## Unico ponto de carga da tabela de reacoes: o arquivo, se existir; senao uma tabela vazia.
static func load_reactions(path: String = REACTION_TABLE_PATH) -> ReactionTable:
	if ResourceLoader.exists(path):
		var t: ReactionTable = load(path) as ReactionTable
		if t != null:
			return t
	return ReactionTable.new()

func allies_of(c: Combatant) -> Array[Combatant]:
	return heroes if c.team == Combatant.Team.HERO else enemies

func foes_of(c: Combatant) -> Array[Combatant]:
	return enemies if c.team == Combatant.Team.HERO else heroes

func living(arr: Array[Combatant]) -> Array[Combatant]:
	var out: Array[Combatant] = []
	for c: Combatant in arr:
		if not c.is_out():
			out.append(c)
	return out

func all() -> Array[Combatant]:
	var out: Array[Combatant] = []
	out.append_array(heroes)
	out.append_array(enemies)
	return out

## Iniciativa por contato (M7): o lado favorecido começa com ATB cheio e já na fila; o outro, com 0.
## NORMAL não mexe em nada (o ATB inicial de sempre).
func apply_initiative(kind: Initiative.Kind) -> void:
	if kind == Initiative.Kind.NORMAL:
		return
	var favored: Array[Combatant] = heroes if kind == Initiative.Kind.PREEMPTIVE else enemies
	var other: Array[Combatant] = enemies if kind == Initiative.Kind.PREEMPTIVE else heroes
	for c: Combatant in other:
		c.atb = 0.0
	for c: Combatant in favored:
		if c.is_down():
			continue
		c.atb = 1.0
		queue.push(c, tick)

# --- Chefes com nucleo e partes (M11) ---

func _role_of(c: Combatant) -> EnemyDef.Role:
	return c.enemy_def.role if c.enemy_def != null else EnemyDef.Role.NORMAL

func has_core() -> bool:
	for c: Combatant in enemies:
		if _role_of(c) == EnemyDef.Role.CORE:
			return true
	return false

## O nucleo `c` esta protegido: ha uma parte com `shields_core` de pe.
func core_shielded(c: Combatant) -> bool:
	if c.is_out() or _role_of(c) != EnemyDef.Role.CORE:
		return false
	for p: Combatant in enemies:
		if not p.is_out() and _role_of(p) == EnemyDef.Role.PART and p.enemy_def.shields_core:
			return true
	return false

## Os inimigos foram derrotados (caidos ou petrificados, M15): com nucleo, a queda de todos os nucleos; senao, de todos os inimigos.
func enemies_defeated() -> bool:
	if not has_core():
		return living(enemies).is_empty()
	for c: Combatant in enemies:
		if _role_of(c) == EnemyDef.Role.CORE and not c.is_out():
			return false
	return true

## Limpeza de quem caiu (por dano, Veneno, Queimadura, Contagem ou queda do nucleo): sem estados, ATB, marca de turno
## contado nem preparacao, fora da fila. Unico caminho de queda: nao deixar estado velho para a proxima vez que reviver.
func take_out(c: Combatant) -> void:
	statuses.clear_all(c)
	c.atb = 0.0
	c.turn_counted = false
	c.charging = null
	queue.remove(c)

## Se todos os nucleos cairam, as partes de pe caem junto (HP 0, sem estados, fora da fila, sem preparacao).
## Cada parte sem contribuicao registrada herda a divisao de contribuicao do(s) nucleo(s), para dar XP.
## Devolve as partes que cairam agora.
func collapse_parts() -> Array[Combatant]:
	var fallen: Array[Combatant] = []
	if not has_core() or not enemies_defeated():
		return fallen
	for p: Combatant in enemies:
		if p.is_down() or _role_of(p) != EnemyDef.Role.PART:
			continue
		p.hp = 0
		take_out(p)
		if ledger.total_against(p.id) <= 0.0:
			for core: Combatant in enemies:
				if _role_of(core) != EnemyDef.Role.CORE:
					continue
				for h: Combatant in heroes:
					ledger.add(h.id, p.id, ledger.get_points(h.id, core.id))
		fallen.append(p)
	return fallen

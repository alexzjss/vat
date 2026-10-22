class_name Combatant
extends RefCounted

enum Team { HERO, ENEMY }

var id: StringName
var team: Team = Team.HERO
var display_name: String = ""
var level: int = 1
var base: Stats
var allocated: Stats
var equipment_mods: Stats
var hp: int = 0
var ap: int = 0
## Espelho de HeroState.limit (0 a 1); volta ao HeroState no fim da batalha. Inimigos nao tem barra.
var limit: float = 0.0
var limit_ability: AbilityDef
var atb: float = 0.0
var position: Vector2 = Vector2.ZERO
var statuses: Array[ActiveStatus] = []
var abilities: Array[AbilityDef] = []
var basic_attack: AbilityDef
var hero_state: HeroState
var enemy_def: EnemyDef
## Heróis: guardados aqui (do equipamento). Inimigos: leem o EnemyDef ao vivo, para que
## ajustes no def depois de criar o combatente continuem valendo.
var _immunities: Array[StringName] = []
var _resistances: Dictionary[StringName, float] = {}
## inimigo: leitura viva de enemy_def; o setter é ignorado
var immunities: Array[StringName]:
	get:
		return enemy_def.immunities if enemy_def != null else _immunities
	set(v):
		_immunities = v
## inimigo: leitura viva de enemy_def; o setter é ignorado
var resistances: Dictionary[StringName, float]:
	get:
		return enemy_def.resistances if enemy_def != null else _resistances
	set(v):
		_resistances = v
## Elementos (M13). Herois: guardados aqui (def + equipamento). Inimigos: leitura viva do EnemyDef.
var _elements: Array[ElementDef] = []
var _element_resist: Dictionary[StringName, float] = {}
## Elemento da arma equipada (ataque basico sem elemento proprio); inimigos nao tem.
var weapon_element: ElementDef
## inimigo: leitura viva de enemy_def; o setter é ignorado
var elements: Array[ElementDef]:
	get:
		return enemy_def.elements if enemy_def != null else _elements
	set(v):
		_elements = v
## Afinidade total por id de elemento (heroi: base + equipamentos; inimigo: leitura viva do def).
var element_resist: Dictionary[StringName, float]:
	get:
		return enemy_def.element_resist if enemy_def != null else _element_resist
	set(v):
		_element_resist = v
## Radioativo (M13): nivel de contaminacao, so dentro da batalha (zera ao cair e no fim).
var contamination: int = 0
## Acoes do afetado desde o ultimo decaimento da contaminacao.
var contam_actions: int = 0
## Marca elemental (M14): no maximo uma por alvo; so dentro da batalha. Nula = sem marca.
var mark: ElementDef
## Turnos ATB do alvo que a marca ainda dura (0 sem marca).
var mark_turns: int = 0
## Reacoes (M14): ATB que o atacante ganha com a reacao enquanto sua acao ainda nao terminou; o controlador
## o devolve depois de zerar a barra no fim da acao.
var atb_bonus: float = 0.0
var start_statuses: Array[StatusDef] = []
var damage_taken_from: Dictionary[StringName, int] = {}
## Chefe (M11): ataque anunciado em preparacao (sai no proximo ATB cheio); nulo = nao esta preparando.
var charging: PendingAction
## Chefe (M11): quantas fases de EnemyDef.phases ja foram aplicadas (0 = regras originais).
var phase_index: int = 0

func is_down() -> bool:
	return hp <= 0

func has_kind(k: StatusDef.Kind) -> bool:
	for s: ActiveStatus in statuses:
		if s.def.kind == k:
			return true
	return false

## Pare, Congelado ou petrificado: o ATB nao enche e nao age (M11, M15).
func is_stopped() -> bool:
	return has_kind(StatusDef.Kind.STOP) or has_kind(StatusDef.Kind.FREEZE) or is_petrified()

## Petrificado (M15): a contagem do estado PETRIFY chegou a 0. Fora da luta: nao age, nao enche ATB, nao e alvo.
func is_petrified() -> bool:
	for s: ActiveStatus in statuses:
		if s.def.kind == StatusDef.Kind.PETRIFY and s.time_left <= 0.0:
			return true
	return false

## Fora da luta: caido ou petrificado (conta como derrotado para o fim da batalha).
func is_out() -> bool:
	return is_down() or is_petrified()

func is_silenced() -> bool:
	return has_kind(StatusDef.Kind.SILENCE)

func is_confused() -> bool:
	return has_kind(StatusDef.Kind.CONFUSION)

## Berserk (M15): age sozinho com o ataque basico num inimigo vivo.
func is_berserk() -> bool:
	return has_kind(StatusDef.Kind.BERSERK)

func is_reflecting() -> bool:
	return has_kind(StatusDef.Kind.REFLECT)

func is_blind() -> bool:
	return has_kind(StatusDef.Kind.BLIND)

func is_charging() -> bool:
	return charging != null

## Regras de IA em vigor: as da fase atual do chefe ou, sem fase, as do EnemyDef. Vazio para herois.
func ai_rules() -> Array[AiRule]:
	if enemy_def == null:
		return []
	if phase_index > 0 and phase_index <= enemy_def.phases.size():
		return enemy_def.phases[phase_index - 1].ai_rules
	return enemy_def.ai_rules

## Unico lugar do enchimento da barra de Limite: dano efetivo sofrido por heroi (dano direto e veneno).
## Inimigos nao enchem; clamp em 1. Heroi ja caido nao recebe dano, logo nao enche.
func gain_limit(damage: int, hp_max: int, cfg: BalanceConfig) -> void:
	if team != Team.HERO or damage <= 0:
		return
	limit = minf(1.0, limit + float(damage) / float(maxi(1, hp_max)) * cfg.limit_fill_mult)

func limit_ready() -> bool:
	return team == Team.HERO and limit >= 1.0 and limit_ability != null

static func from_hero(h: HeroState, pos: Vector2) -> Combatant:
	var c := Combatant.new()
	c.id = h.def.id
	c.team = Team.HERO
	c.display_name = h.def.display_name
	c.level = h.level
	c.base = h.def.base
	c.allocated = h.allocated
	var mods := Stats.make(0, 0, 0, 0)
	for e: EquipmentDef in h.equipment.values():
		if e != null and e.modifiers != null:
			mods = mods.plus(e.modifiers)
	c.equipment_mods = mods
	c.hp = h.hp
	c.ap = h.ap
	c.limit = h.limit
	c.limit_ability = h.def.limit_ability
	c.position = pos
	c.abilities = h.abilities()
	c.basic_attack = h.def.basic_attack
	c.hero_state = h
	c.immunities = EquipmentRules.immunities(h.equipment)
	c.resistances = EquipmentRules.resistances(h.equipment)
	c.start_statuses = EquipmentRules.start_statuses(h.equipment)
	c.elements = h.def.elements.duplicate()
	c.element_resist = EquipmentRules.element_resist(h.def, h.equipment)
	var w: EquipmentDef = h.equipment.get(&"weapon")
	c.weapon_element = w.element if w != null else null
	return c

static func from_enemy(d: EnemyDef, enemy_id: StringName, pos: Vector2, cfg: BalanceConfig) -> Combatant:
	var c := Combatant.new()
	c.id = enemy_id
	c.team = Team.ENEMY
	c.display_name = d.display_name
	c.level = d.level
	c.base = d.base
	c.allocated = Stats.make(0, 0, 0, 0)
	c.equipment_mods = Stats.make(0, 0, 0, 0)
	c.position = pos
	c.abilities = d.abilities.duplicate()
	for a: AbilityDef in d.abilities:
		if a.ap_cost == 0:
			c.basic_attack = a
			break
	c.enemy_def = d
	c.hp = StatCalculator.hp_max(c, cfg)
	c.ap = StatCalculator.ap_max(c, cfg)
	return c

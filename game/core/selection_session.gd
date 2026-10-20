# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8): todos os números vêm de BalanceConfig.
class_name SelectionSession
extends RefCounted

enum Step { COMMAND, TARGET, CONFIRM, DONE }

var step: Step = Step.COMMAND
var actor: Combatant
var b: BattleState
var ability: AbilityDef
var item: ItemDef
var center: Combatant
## Suporte (M8.5): heroi da reserva escolhido (Combatant temporario, fora de b.heroes). Enquanto existe,
## as escolhas de habilidade sao dele (AP dele); o turno e o Limite continuam sendo de `actor`.
var support: Combatant
var _draft: PendingAction

func _init(p_actor: Combatant, p_b: BattleState) -> void:
	actor = p_actor
	b = p_b

func _new_draft() -> PendingAction:
	var d := PendingAction.new()
	d.actor = actor
	return d

## Quem executa o que for escolhido: o reserva chamado, ou o proprio heroi do turno.
func user() -> Combatant:
	return support if support != null else actor

func can_use(ab: AbilityDef) -> bool:
	return user().ap >= ab.ap_cost

## Reservas que podem ser chamados: com HP > 0.
func support_candidates() -> Array[HeroState]:
	var out: Array[HeroState] = []
	for h: HeroState in b.reserve:
		if h.hp > 0:
			out.append(h)
	return out

## "Suporte" habilitado: Limite >= support_cost e ao menos um reserva em pe.
func can_support() -> bool:
	return actor.team == Combatant.Team.HERO and actor.limit >= b.cfg.support_cost and not support_candidates().is_empty()

## Escolhe o reserva; o proximo passo e choose_ability com as acoes dele (support_abilities).
func choose_support(h: HeroState) -> bool:
	if step != Step.COMMAND or support != null:
		push_error("choose_support fora do passo COMMAND")
		return false
	if h == null or not can_support() or not support_candidates().has(h):
		return false
	var pos: Vector2 = b.support_pos if b.support_pos.is_finite() else actor.position + Vector2(-90.0, 0.0)
	support = Combatant.from_hero(h, pos)
	return true

## Desiste do reserva escolhido (volta a lista de reservas).
func cancel_support() -> void:
	if step == Step.COMMAND:
		support = null

## Ataque basico e habilidades do reserva escolhido.
func support_abilities() -> Array[AbilityDef]:
	var out: Array[AbilityDef] = []
	if support == null:
		return out
	if support.basic_attack != null:
		out.append(support.basic_attack)
	out.append_array(support.abilities)
	return out

func choose_ability(ab: AbilityDef) -> bool:
	if step != Step.COMMAND:
		push_error("choose_ability fora do passo COMMAND")
		return false
	if ab == null or not can_use(ab):
		return false
	var u: Combatant = user()
	u.ap -= ab.ap_cost
	_sync_support_ap()
	ability = ab
	_draft = _new_draft()
	_draft.ability = ab
	if support != null:
		_draft.actor = support
		_draft.caller = actor
	step = Step.TARGET
	return true

## O AP do reserva persiste no HeroState dele: gravado ao escolher, devolvido ao desfazer/reembolsar.
func _sync_support_ap() -> void:
	if support != null:
		support.hero_state.ap = support.ap

## Golpe de Limite: so com a barra cheia; sem custo de AP. A barra zera quando a acao comeca (BattleController).
func choose_limit() -> bool:
	if step != Step.COMMAND:
		push_error("choose_limit fora do passo COMMAND")
		return false
	if not actor.limit_ready():
		return false
	ability = actor.limit_ability
	_draft = _new_draft()
	_draft.ability = ability
	_draft.is_limit = true
	step = Step.TARGET
	return true

func choose_item(it: ItemDef) -> bool:
	if step != Step.COMMAND:
		push_error("choose_item fora do passo COMMAND")
		return false
	if it == null or not b.inventory.reserve(it.id):
		return false
	item = it
	_draft = _new_draft()
	_draft.item = it
	step = Step.TARGET
	return true

func target_candidates() -> Array[Combatant]:
	if step != Step.TARGET and step != Step.CONFIRM:
		push_error("target_candidates sem comando escolhido")
		return []
	return Targeting.candidates(_draft.shape(), _draft.side(), _draft.effects(), _draft.actor, b)

func set_center(c: Combatant) -> void:
	if step != Step.TARGET and step != Step.CONFIRM:
		push_error("set_center fora do passo de alvo")
		return
	if not target_candidates().has(c):
		push_error("alvo invalido")
		return
	center = c
	step = Step.CONFIRM

func preview_area() -> Array[Combatant]:
	if center == null:
		return []
	return Targeting.area(_draft.shape(), _draft.side(), _draft.effects(), _draft.radius(), _draft.width(), _draft.actor, center, b)

func back() -> void:
	if step != Step.TARGET and step != Step.CONFIRM:
		return
	if item != null:
		b.inventory.release(item.id)
	elif ability != null and not _draft.is_limit:
		user().ap += ability.ap_cost
		_sync_support_ap()
	ability = null
	item = null
	center = null
	_draft = null
	step = Step.COMMAND

func confirm() -> PendingAction:
	if step != Step.CONFIRM:
		push_error("confirm fora do passo CONFIRM")
		return null
	var a: PendingAction = _draft
	a.center = center
	a.center_pos = center.position
	if item != null:
		b.inventory.commit(item.id)
	step = Step.DONE
	return a

## Forma/raio/largura do comando escolhido (para a prévia da UI). SINGLE/0 sem comando.
func shape() -> AbilityDef.Shape:
	return _draft.shape() if _draft != null else AbilityDef.Shape.SINGLE

func radius() -> float:
	return _draft.radius() if _draft != null else 0.0

func width() -> float:
	return _draft.width() if _draft != null else 0.0

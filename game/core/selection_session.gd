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
var _draft: PendingAction

func _init(p_actor: Combatant, p_b: BattleState) -> void:
	actor = p_actor
	b = p_b

func _new_draft() -> PendingAction:
	var d := PendingAction.new()
	d.actor = actor
	return d

func can_use(ab: AbilityDef) -> bool:
	return actor.ap >= ab.ap_cost

func choose_ability(ab: AbilityDef) -> bool:
	if step != Step.COMMAND:
		push_error("choose_ability fora do passo COMMAND")
		return false
	if ab == null or not can_use(ab):
		return false
	actor.ap -= ab.ap_cost
	ability = ab
	_draft = _new_draft()
	_draft.ability = ab
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
	return Targeting.candidates(_draft.shape(), _draft.side(), _draft.effects(), actor, b)

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
	return Targeting.area(_draft.shape(), _draft.side(), _draft.effects(), _draft.radius(), _draft.width(), actor, center, b)

func back() -> void:
	if step != Step.TARGET and step != Step.CONFIRM:
		return
	if item != null:
		b.inventory.release(item.id)
	elif ability != null:
		actor.ap += ability.ap_cost
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

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

func _init(p_actor: Combatant, p_b: BattleState) -> void:
	actor = p_actor
	b = p_b

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
	step = Step.TARGET
	return true

func choose_item(it: ItemDef) -> bool:
	if step != Step.COMMAND:
		push_error("choose_item fora do passo COMMAND")
		return false
	if it == null or not b.inventory.reserve(it.id):
		return false
	item = it
	step = Step.TARGET
	return true

func _shape() -> AbilityDef.Shape:
	return item.shape if item != null else ability.shape

func _side() -> AbilityDef.Side:
	return item.side if item != null else ability.side

func _effects() -> Array[EffectDef]:
	return item.effects if item != null else ability.effects

func target_candidates() -> Array[Combatant]:
	if step != Step.TARGET and step != Step.CONFIRM:
		push_error("target_candidates sem comando escolhido")
		return []
	return Targeting.candidates(_shape(), _side(), _effects(), actor, b)

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
	var radius: float = 0.0 if item != null else ability.radius
	var width: float = 0.0 if item != null else ability.width
	return Targeting.area(_shape(), _side(), _effects(), radius, width, actor, center, b)

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
	step = Step.COMMAND

func confirm() -> PendingAction:
	if step != Step.CONFIRM:
		push_error("confirm fora do passo CONFIRM")
		return null
	var a := PendingAction.new()
	a.actor = actor
	a.ability = ability
	a.item = item
	a.center = center
	a.center_pos = center.position
	if item != null:
		b.inventory.commit(item.id)
	step = Step.DONE
	return a

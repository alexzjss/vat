class_name SoundEvents
extends RefCounted

## Qual som toca em cada evento do jogo (M19), puro: dado o evento e os defs envolvidos devolve o id do som no
## SoundBank, ou vazio (sem som configurado nunca e erro). Quem toca e o AudioDirector, via `AudioHooks`.
## Os jingles de vitoria e derrota tambem saem daqui (`VICTORY`/`DEFEAT`), mas quem os toca e o `AudioRules`.
##
## Contexto (`ctx`, tudo opcional): `ability` (AbilityDef), `element` (ElementDef; substitui o da tecnica, para o ataque
## basico com o elemento da arma), `item` (ItemDef), `def` (CharacterDef ou EnemyDef de quem levou o golpe ou caiu),
## `damaged` (bool, HIT), `reaction` (ReactionDef), `status` (StatusDef), `cfg` (BalanceConfig, para os sons de interface).

## Novos valores sempre no fim.
enum Event {
	CAST, IMPACT, HIT, DOWN, REACTION, STATUS_APPLIED, ITEM_USE, LEVEL_UP,
	MENU_MOVE, MENU_CONFIRM, MENU_CANCEL, TEXT_TICK, CHEST, DOOR, STEP,
	VICTORY, DEFEAT,
}

static func sound_for(event: Event, ctx: Dictionary = {}) -> StringName:
	var cfg: BalanceConfig = ctx.get("cfg") as BalanceConfig
	match event:
		Event.CAST:
			var a: AbilityDef = ctx.get("ability") as AbilityDef
			return a.sfx_cast if a != null else &""
		Event.IMPACT:
			var ab: AbilityDef = ctx.get("ability") as AbilityDef
			if ab != null and ab.sfx_impact != &"":
				return ab.sfx_impact
			var el: ElementDef = ctx.get("element") as ElementDef
			if el == null and ab != null:
				el = ab.element
			return el.sfx_hit if el != null else &""
		Event.HIT:
			if not bool(ctx.get("damaged", true)):
				return &""
			return _of_combatant(ctx.get("def"), true)
		Event.DOWN:
			return _of_combatant(ctx.get("def"), false)
		Event.REACTION:
			var r: ReactionDef = ctx.get("reaction") as ReactionDef
			return r.sfx if r != null else &""
		Event.STATUS_APPLIED:
			var s: StatusDef = ctx.get("status") as StatusDef
			return s.sfx_apply if s != null else &""
		Event.ITEM_USE:
			var it: ItemDef = ctx.get("item") as ItemDef
			return it.sfx_use if it != null else &""
		Event.LEVEL_UP:
			return cfg.sfx_level_up if cfg != null else &""
		Event.MENU_MOVE:
			return cfg.sfx_menu_move if cfg != null else &""
		Event.MENU_CONFIRM:
			return cfg.sfx_menu_confirm if cfg != null else &""
		Event.MENU_CANCEL:
			return cfg.sfx_menu_cancel if cfg != null else &""
		Event.TEXT_TICK:
			return cfg.sfx_text_tick if cfg != null else &""
		Event.CHEST:
			return cfg.sfx_open_chest if cfg != null else &""
		Event.DOOR:
			return cfg.sfx_open_door if cfg != null else &""
		Event.STEP:
			return cfg.sfx_step if cfg != null else &""
		Event.VICTORY:
			return cfg.victory_jingle if cfg != null else &""
		Event.DEFEAT:
			return cfg.defeat_jingle if cfg != null else &""
	return &""

static func _of_combatant(def: Variant, hit: bool) -> StringName:
	if def is CharacterDef:
		var c: CharacterDef = def
		return c.sfx_hit if hit else c.sfx_down
	if def is EnemyDef:
		var e: EnemyDef = def
		return e.sfx_hit if hit else e.sfx_down
	return &""

## O def de quem esta no combatente: o heroi ou o inimigo (null se nenhum).
static func def_of(c: Combatant) -> Resource:
	if c == null:
		return null
	if c.enemy_def != null:
		return c.enemy_def
	return c.hero_state.def if c.hero_state != null else null

## Os ids padrao que o `AudioRules` usa, vindos do BalanceConfig (null = tudo vazio).
static func audio_defaults(cfg: BalanceConfig) -> Dictionary:
	if cfg == null:
		return AudioRules.make_defaults()
	return AudioRules.make_defaults({
		"battle_music": cfg.default_battle_music,
		"boss_music": cfg.boss_battle_music,
		"victory_jingle": cfg.victory_jingle,
		"defeat_jingle": cfg.defeat_jingle,
	})

## O encontro e de chefe? (`unique_id` preenchido, o mesmo criterio do resto do jogo.)
static func is_boss(encounter: EncounterDef) -> bool:
	return encounter != null and encounter.unique_id != &""

## Quantos tiques de texto soam ao revelar `shown` caracteres, de `every` em `every` (`every` < 1 conta como 1):
## devolve quantos NOVOS tiques entre `before` e `shown`. Pura, para o teste e a caixa de dialogo.
static func ticks_between(before: int, shown: int, every: int) -> int:
	var n: int = maxi(1, every)
	return maxi(0, floori(float(shown) / float(n)) - floori(float(maxi(0, before)) / float(n)))

## O som do inicio de uma acao: o `sfx_use` do item ou o `sfx_cast` da tecnica.
static func action_start_sound(a: PendingAction) -> StringName:
	if a == null:
		return &""
	if a.item != null:
		return sound_for(Event.ITEM_USE, {"item": a.item})
	return sound_for(Event.CAST, {"ability": a.ability})

## Os sons do impacto de uma acao, sem repetir id, na ordem: impacto, golpes que causaram dano, quedas, reacoes e estados.
## `reactions` e a tabela de reacoes da batalha (pode ser null). O ataque basico sem elemento usa o da arma.
static func impact_sounds(a: PendingAction, r: ActionResult, reactions: ReactionTable) -> Array[StringName]:
	var out: Array[StringName] = []
	if a == null or r == null:
		return out
	var by_id: Dictionary[StringName, Combatant] = {}
	for c: Combatant in r.targets:
		by_id[c.id] = c
	for c: Combatant in r.downed:
		by_id[c.id] = c
	if a.actor != null:
		by_id[a.actor.id] = a.actor
	if a.item == null and a.ability != null:
		var element: ElementDef = null
		if a.ability.element == null and a.actor != null and a.ability == a.actor.basic_attack:
			element = a.actor.weapon_element
		_add(out, sound_for(Event.IMPACT, {"ability": a.ability, "element": element}))
	var status_applied: bool = false
	for hit: Dictionary in r.hits:
		var kind: int = int(hit.get("kind", EffectDef.Kind.DAMAGE))
		var landed: bool = not (hit.get("dodged", false) or hit.get("missed", false) or hit.get("petrified", false))
		if kind == EffectDef.Kind.DAMAGE and landed and int(hit.get("amount", 0)) > 0:
			var target: Combatant = by_id.get(hit.get("target_id", &""))
			_add(out, sound_for(Event.HIT, {"def": def_of(target), "damaged": true}))
		if kind == EffectDef.Kind.APPLY_STATUS and int(hit.get("status_result", -1)) == StatusSystem.ApplyResult.APPLIED:
			status_applied = true
	for c: Combatant in r.downed:
		_add(out, sound_for(Event.DOWN, {"def": def_of(c)}))
	if reactions != null:
		for hit: Dictionary in r.hits:
			var rid: StringName = hit.get("reaction", &"")
			for d: ReactionDef in reactions.reactions:
				if rid != &"" and d != null and d.id == rid:
					_add(out, sound_for(Event.REACTION, {"reaction": d}))
	if status_applied:
		for e: EffectDef in a.effects():
			if e.kind == EffectDef.Kind.APPLY_STATUS and e.status != null:
				_add(out, sound_for(Event.STATUS_APPLIED, {"status": e.status}))
	return out

static func _add(out: Array[StringName], id: StringName) -> void:
	if id != &"" and not out.has(id):
		out.append(id)

class_name BattleSprite
extends AnimatedSprite2D

## Sprite de batalha de um combatente (M16), montado em tempo de execução a partir de um [SpriteSet].
## Uma animação por entrada de `SpriteSet.anims` (idle e victory em laço; as demais tocam uma vez e param no último
## quadro). Animação que falta cai em `idle`. O quadro é centrado na origem da [CombatantView].
## `anim` é a animação pedida mais recente (a de `idle` quando a pedida não existe).

const IDLE: StringName = &"idle"
const ATTACK: StringName = &"attack"
const CAST: StringName = &"cast"
const HIT: StringName = &"hit"
const DOWN: StringName = &"down"
const VICTORY: StringName = &"victory"

var sprite_set: SpriteSet
var anim: StringName = IDLE

## Cria o BattleSprite para `sprites`, ou null se o conjunto não tem folha de batalha.
## `flip`: espelha na horizontal (inimigo desenhado virado para a direita, ou herói virado para a esquerda).
static func create(sprites: SpriteSet, flip: bool) -> BattleSprite:
	if sprites == null or not sprites.has_battle_art():
		return null
	var s: BattleSprite = BattleSprite.new()
	s.sprite_set = sprites
	s.centered = true
	s.flip_h = flip
	s.sprite_frames = BattleSprite.build_frames(sprites)
	s.show_anim(IDLE)
	return s

## SpriteFrames com as animações do conjunto; uma animação sem quadros dentro da folha fica de fora.
static func build_frames(sprites: SpriteSet) -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	var sheet_size: Vector2i = Vector2i(sprites.battle_sheet.get_size())
	for key: StringName in sprites.anims:
		var added: int = 0
		for r: Rect2i in sprites.battle_frames(key):
			if r.end.x > sheet_size.x or r.end.y > sheet_size.y:
				continue
			if added == 0:
				frames.add_animation(key)
				frames.set_animation_speed(key, sprites.battle_fps(key))
				frames.set_animation_loop(key, SpriteSet.loops(key))
			var a: AtlasTexture = AtlasTexture.new()
			a.atlas = sprites.battle_sheet
			a.region = Rect2(r)
			frames.add_frame(key, a)
			added += 1
	return frames

## A animação que de fato toca para o pedido `want`: ela mesma, ou `idle` se faltar; vazio se nem `idle` existe.
func resolve(want: StringName) -> StringName:
	if sprite_frames != null and sprite_frames.has_animation(want):
		return want
	if sprite_frames != null and sprite_frames.has_animation(IDLE):
		return IDLE
	return &""

## Toca `want` do começo (com o fallback de [method resolve]). Devolve o nome que tocou.
func show_anim(want: StringName) -> StringName:
	var key: StringName = resolve(want)
	anim = key
	if key != &"":
		play(key)
	return key

## Qual animação abre a ação `a`: golpe de Força (ou ataque básico) = attack; o resto (habilidades, itens) = cast.
static func anim_for_action(a: PendingAction) -> StringName:
	if a == null:
		return IDLE
	if a.item != null or a.ability == null:
		return CAST
	if a.ability == a.actor.basic_attack:
		return ATTACK
	for e: EffectDef in a.ability.effects:
		if e.kind == EffectDef.Kind.DAMAGE and e.scale == EffectDef.Scale.STRENGTH:
			return ATTACK
	return CAST

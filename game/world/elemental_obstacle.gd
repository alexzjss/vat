class_name ElementalObstacle
extends Interactable

## Obstáculo elemental (M15): vinhas, pedra rachada, mecanismo... Interagir abre a escolha de qual herói do grupo,
## entre os que sabem uma técnica de `element`, a usa (o Game abre o ObstacleMenu); a escolha gasta o custo de AP da
## técnica, grava `flag` e o obstáculo some (visual e colisão), como o FlagGate. O estado vive só na flag: o mapa
## reinstanciado e o restore do save o mostram certo. Sem ninguém capaz, mostra `locked_text`.
## Quem é capaz: heróis ativos, em pé; a técnica do elemento mais barata de cada um (a reserva e a Limite não entram).

@export var element: ElementDef
@export var flag: StringName = &""
## Fala depois de abrir o caminho (vazio = nenhuma).
@export_multiline var open_text: String = ""
## Fala quando ninguém do grupo sabe uma técnica do elemento.
@export_multiline var locked_text: String = ""
@export var size: Vector2 = Vector2(32, 32)

const DEFAULT_LOCKED_TEXT: String = "Algo bloqueia o caminho. Ninguém do grupo sabe como passar."

## Uma linha da escolha: o herói, a técnica que ele usaria e se dá para usá-la agora (em pé e com AP).
class Option:
	extends RefCounted
	var hero: HeroState
	var ability: AbilityDef
	var enabled: bool = false

var _blocker: CollisionShape2D

func _init() -> void:
	prompt = "Examinar"

func _ready() -> void:
	super._ready()
	if element == null or flag == &"":
		push_error("ElementalObstacle: element e flag são obrigatórios")
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_blocker = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	_blocker.shape = rect
	body.add_child(_blocker)
	add_child(body)
	sync_state()

func _process(delta: float) -> void:
	super._process(delta)
	sync_state()

## Já aberto (a flag está ligada)?
func is_open() -> bool:
	var s: GameState = game_state()
	return s != null and flag != &"" and s.get_flag(flag) != 0

func can_interact() -> bool:
	return super.can_interact() and not is_open()

## Colisão e visual seguem a flag todo quadro.
func sync_state() -> void:
	var open: bool = is_open()
	if _blocker != null:
		_blocker.set_deferred(&"disabled", open)
	visible = not open

## A técnica mais barata de `h` com o elemento do obstáculo; nula se não sabe nenhuma.
func ability_of(h: HeroState) -> AbilityDef:
	var best: AbilityDef = null
	if element == null:
		return null
	for ab: AbilityDef in h.abilities():
		if ab.element == element and (best == null or ab.ap_cost < best.ap_cost):
			best = ab
	return best

## Os heróis ativos que sabem uma técnica do elemento, na ordem do grupo; `enabled` diz se podem usá-la agora.
func options() -> Array[Option]:
	var out: Array[Option] = []
	var s: GameState = game_state()
	if s == null:
		return out
	for h: HeroState in s.heroes:
		var ab: AbilityDef = ability_of(h)
		if ab == null:
			continue
		var o := Option.new()
		o.hero = h
		o.ability = ab
		o.enabled = h.hp > 0 and h.ap >= ab.ap_cost
		out.append(o)
	return out

## O herói `h` desfaz o obstáculo: gasta o AP da técnica e grava a flag. False se não pode (não está na lista,
## caído, sem AP) ou já estava aberto; nada é gasto nesse caso.
func unlock(h: HeroState) -> bool:
	var s: GameState = game_state()
	if s == null or is_open() or flag == &"":
		return false
	for o: Option in options():
		if o.hero == h and o.enabled:
			h.ap -= o.ability.ap_cost
			s.set_flag(flag, 1)
			sync_state()
			if open_text != "":
				_run_script(EventScript.of([EventScript.say(open_text)] as Array[EventStep]))
			return true
	return false

func _activate() -> void:
	if options().is_empty():
		_run_script(EventScript.of([EventScript.say(locked_text if locked_text != "" else DEFAULT_LOCKED_TEXT)] as Array[EventStep]))
		return
	interacted.emit()
	var m: LocalMap = LocalMap.map_of(self)
	if m != null:
		m.request_obstacle(self)

func _draw() -> void:
	var c: Color = element.color if element != null else Color(0.5, 0.5, 0.5)
	draw_rect(Rect2(-size / 2.0, size), c.darkened(0.45))
	draw_rect(Rect2(-size / 2.0, size), c, false, 2.0)
	if element != null and element.short_name != "":
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(-size.x / 2.0 + 2.0, 5.0), element.short_name.left(3), HORIZONTAL_ALIGNMENT_LEFT, size.x - 4.0, 12, Color.WHITE)

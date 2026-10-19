class_name ItemPage
extends FieldPage

## Itens: lista "Nome xN" do inventário (não usáveis em campo ficam cinza). Escolher um item abre a
## seleção de alvo no painel do grupo (só heróis em quem o item teria efeito); cancelar volta à lista.

var targeting_item: ItemDef = null
var _items: Array[ItemDef] = []

func enter() -> void:
	super.enter()
	targeting_item = null
	_rebuild()
	if _items.is_empty():
		_say("Nenhum item.")

func leave() -> void:
	targeting_item = null
	super.leave()

func move(delta: int) -> void:
	if targeting_item != null:
		menu.party_panel.pick_move(delta)
	else:
		super.move(delta)

func accept() -> void:
	if targeting_item != null:
		_use_on_picked()
		return
	if cursor >= _items.size():
		return
	if not _cursor_ok():
		_say("Não pode ser usado aqui.")
		return
	var item: ItemDef = _items[cursor]
	var cfg: BalanceConfig = state.cfg
	var filter: Callable = func(h: HeroState) -> bool: return FieldActions.would_affect(item.effects, h, cfg)
	if not state.roster().any(filter):
		_say("Ninguém precisa disso.")
		return
	targeting_item = item
	menu.party_panel.begin_pick(filter)
	_say("Usar %s em quem?" % item.display_name)
	_render_list(false)

func cancel() -> bool:
	if targeting_item == null:
		return false
	_end_target()
	_say("")
	return true

func _use_on_picked() -> void:
	var h: HeroState = menu.party_panel.picked()
	if h == null:
		return
	var item: ItemDef = targeting_item
	if FieldActions.use_item(state, item, h):
		_say("%s usado em %s." % [item.display_name, _hero_name(h)])
	else:
		_say("Ninguém precisa disso.")
	_end_target()
	menu.refresh_party()

func _end_target() -> void:
	targeting_item = null
	menu.party_panel.end_pick()
	_rebuild()

func _rebuild() -> void:
	_items = state.inventory.listing()
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	for it: ItemDef in _items:
		texts.append("%s x%d" % [it.display_name, state.inventory.available(it.id)])
		enabled.append(FieldActions.is_field_usable(it.effects))
	_set_entries(texts, enabled)

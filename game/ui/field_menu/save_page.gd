class_name SavePage
extends FieldPage

## Salvar: escolha do slot (confirma antes de sobrescrever). Quem grava é o Game (`menu.save_handler`).

var picker: SaveSlotPicker

func _init() -> void:
	super._init()
	# Esta página usa só o seletor de slots: some com a lista e o aviso vazios da base (lacuna no topo).
	_list.visible = false
	_message.visible = false
	picker = SaveSlotPicker.new()
	picker.chosen.connect(_on_chosen)
	add_child(picker)

func enter() -> void:
	super.enter()
	picker.open(menu.store, SaveSlotPicker.Mode.SAVE)

func move(delta: int) -> void:
	picker.move(delta)

func accept() -> void:
	picker.accept()

func cancel() -> bool:
	return picker.cancel()

func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return false
	return picker.handle_input(event)

func _on_chosen(slot: int) -> void:
	var ok: bool = menu.save_handler.is_valid() and bool(menu.save_handler.call(slot))
	picker.refresh()
	picker.say("Salvo no slot %d." % slot if ok else "Não foi possível salvar.")

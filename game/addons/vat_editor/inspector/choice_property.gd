@tool
extends EditorProperty

## Editor de propriedade que mostra um menu em vez do campo de texto ou do seletor de recurso (M17). Quem cria entrega
## chamadas para: listar as chaves (`lister`), ler a chave atual do objeto (`reader`), converter a chave no valor da
## propriedade (`writer`), dar o rótulo de uma chave (`labeler`) e dizer o que há de errado com ela (`problem`).
## O valor atual aparece mesmo fora da lista, em vermelho. A gravação passa por `emit_changed`, então o undo do Inspector
## continua valendo. O menu é refeito a cada `_update_property`, então acompanha as outras propriedades do objeto.

const Picks: GDScript = preload("res://addons/vat_editor/logic/inspector_picks.gd")
const ERROR_COLOR: Color = Color(1.0, 0.35, 0.35)

## Callable(object: Object) -> Array[String]
var lister: Callable
## Callable(object: Object) -> String (a chave do valor atual; "" = nenhum)
var reader: Callable
## Callable(key: String) -> Variant (o valor a gravar na propriedade)
var writer: Callable
## Callable(key: String) -> String (o texto do item); opcional, o padrão é a própria chave
var labeler: Callable
## Callable(object: Object, key: String) -> String ("" = sem problema)
var problem: Callable

var _button: OptionButton
var _keys: Array[String] = []
var _updating: bool = false

func _init() -> void:
	_button = OptionButton.new()
	_button.fit_to_longest_item = false
	_button.clip_text = true
	_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_button)
	add_focusable(_button)
	_button.item_selected.connect(_on_selected)

func _update_property() -> void:
	var obj: Object = get_edited_object()
	if obj == null:
		return
	var current: String = String(reader.call(obj)) if reader.is_valid() else ""
	var values: Array[String] = []
	if lister.is_valid():
		values.assign(lister.call(obj))
	var c: Dictionary = Picks.choices(values, current)
	_updating = true
	_keys.assign(c["values"])
	_button.clear()
	var invalid: bool = c["invalid"]
	for i: int in _keys.size():
		var key: String = _keys[i]
		var is_current: bool = i == int(c["index"])
		var text: String = key
		if key != "" and labeler.is_valid() and not (invalid and is_current):
			text = String(labeler.call(key))
		_button.add_item(Picks.choice_label(text, invalid, is_current) if key != "" else Picks.NONE_LABEL)
	_button.select(int(c["index"]))
	var msg: String = String(problem.call(obj, current)) if problem.is_valid() else ""
	if invalid and msg == "":
		msg = "valor fora da lista"
	if msg != "":
		_button.add_theme_color_override(&"font_color", ERROR_COLOR)
		_button.add_theme_color_override(&"font_hover_color", ERROR_COLOR)
		_button.add_theme_color_override(&"font_focus_color", ERROR_COLOR)
		_button.tooltip_text = msg
	else:
		_button.remove_theme_color_override(&"font_color")
		_button.remove_theme_color_override(&"font_hover_color")
		_button.remove_theme_color_override(&"font_focus_color")
		_button.tooltip_text = ""
	_updating = false

func _on_selected(index: int) -> void:
	if _updating or index < 0 or index >= _keys.size():
		return
	var value: Variant = writer.call(_keys[index]) if writer.is_valid() else StringName(_keys[index])
	if value is StringName and value == Picks.NO_CHANGE:
		return # chave inválida (ex.: o valor inválido mostrado): a propriedade não muda
	emit_changed(get_edited_property(), value)

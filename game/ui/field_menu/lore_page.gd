class_name LorePage
extends FieldPage

## Base das paginas de consulta do menu (Bestiario, Reacoes - M15): lista rolavel a esquerda (janela de
## `VISIBLE_ROWS` linhas em volta do cursor), painel de detalhe a direita e uma linha de contagem no topo.
## Somente leitura: mover o cursor atualiza o detalhe; Esc volta para a raiz.

const VISIBLE_ROWS: int = 12
const LIST_WIDTH: float = 280.0
const COUNT_COLOR: Color = Color(0.7, 0.8, 1.0)

var _count: Label
var _detail: Label

func _init() -> void:
	super._init()
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 15)
	_count.add_theme_color_override("font_color", COUNT_COLOR)
	add_child(_count)
	move_child(_count, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	remove_child(_list)
	_list.custom_minimum_size = Vector2(LIST_WIDTH, 0.0)
	row.add_child(_list)
	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 16)
	_detail.add_theme_color_override("font_color", TEXT_COLOR)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.custom_minimum_size = Vector2(180.0, 0.0)
	_detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(_detail)
	add_child(row)
	move_child(row, 1)

func move(delta: int) -> void:
	super.move(delta)
	_detail.text = detail_for(cursor)

func detail_text() -> String:
	return _detail.text

func count_text() -> String:
	return _count.text

## Texto do detalhe da linha `i` (as subclasses definem).
func detail_for(_i: int) -> String:
	return ""

func _set_rows(texts: Array[String], count: String) -> void:
	var enabled: Array[bool] = []
	for t: String in texts:
		enabled.append(t != BestiaryText.UNKNOWN)
	_count.text = count
	_set_entries(texts, enabled)
	_detail.text = detail_for(cursor)

func _render_list(show_cursor: bool = true) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.free()
	var first: int = clampi(cursor - VISIBLE_ROWS / 2, 0, maxi(0, _entries.size() - VISIBLE_ROWS))
	for i: int in range(first, mini(_entries.size(), first + VISIBLE_ROWS)):
		var l := Label.new()
		var selected: bool = show_cursor and i == cursor
		l.text = ("> " if selected else "  ") + _entries[i]
		l.add_theme_font_size_override("font_size", 17)
		var color: Color = TEXT_COLOR if _enabled[i] else DISABLED_COLOR
		if selected:
			color = CURSOR_COLOR
		l.add_theme_color_override("font_color", color)
		_list.add_child(l)

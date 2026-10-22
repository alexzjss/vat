class_name ReactionsPage
extends LorePage

## Reacoes (M15): as reacoes da tabela, na ordem dela. Vista (GameState.seen_reactions): "Nome — Fogo + Agua" e,
## no detalhe, o resumo dos efeitos (BestiaryText.reaction_summary). Nao vista: "???". Cabecalho "Vistas N/M".

var _table: ReactionTable
var _injected: bool = false

## Substitui a tabela carregada de BattleState (testes).
func set_table(t: ReactionTable) -> void:
	_table = t
	_injected = true

func enter() -> void:
	super.enter()
	if not _injected:
		_table = BattleState.load_reactions()
	_refresh()

func detail_for(i: int) -> String:
	if _table == null or i < 0 or i >= _table.reactions.size() or state == null:
		return ""
	var d: ReactionDef = _table.reactions[i]
	if not state.seen_reactions.has(d.id):
		return BestiaryText.UNKNOWN
	return "%s\n%s\n%s" % [d.display_name, ReactionText.pair_text(d), BestiaryText.reaction_summary(d)]

func _refresh() -> void:
	var rows: Array[String] = []
	var seen: int = 0
	for d: ReactionDef in _table.reactions:
		if state.seen_reactions.has(d.id):
			seen += 1
			rows.append("%s — %s" % [d.display_name, ReactionText.pair_text(d)])
		else:
			rows.append(BestiaryText.UNKNOWN)
	_set_rows(rows, "Vistas %d/%d" % [seen, _table.reactions.size()])

class_name RoteiroEvent
extends RefCounted

## Um evento do roteiro (M17): `=== id` e os blocos até o próximo `===`. Pura: sem Node e sem IO.
## Os comentários que ficam colados no `===` (sem linha em branco no meio) são do evento e vão em `leading`.
## Os blocos EM_BRANCO e COMENTARIO entre os outros ficam em `blocks`, na ordem.

var id: String = ""
var leading: Array[RoteiroBlock] = []
var blocks: Array[RoteiroBlock] = []
## Linha do `===` quando veio de `parse`; 0 se criado por código.
var line: int = 0

static func make(p_id: String) -> RoteiroEvent:
	var e := RoteiroEvent.new()
	e.id = p_id
	return e

## Insere `block` em `index` (-1 = no fim). Devolve o índice onde ficou.
func add_block(block: RoteiroBlock, index: int = -1) -> int:
	var i: int = blocks.size() if index < 0 or index > blocks.size() else index
	blocks.insert(i, block)
	return i

func remove_block(index: int) -> void:
	if index >= 0 and index < blocks.size():
		blocks.remove_at(index)

## Move o bloco de `from` para `to` (o índice que ele terá depois). Devolve false se algum índice não existe.
func move_block(from: int, to: int) -> bool:
	if from < 0 or from >= blocks.size() or to < 0 or to >= blocks.size():
		return false
	if from == to:
		return true
	var b: RoteiroBlock = blocks[from]
	blocks.remove_at(from)
	blocks.insert(to, b)
	return true

## Copia o bloco logo abaixo dele. Devolve a cópia (null se o índice não existe).
func duplicate_block(index: int) -> RoteiroBlock:
	if index < 0 or index >= blocks.size():
		return null
	var c: RoteiroBlock = blocks[index].copy()
	c.line = 0
	blocks.insert(index + 1, c)
	return c

## Os rótulos declarados (`== nome`), na ordem.
func labels() -> Array[StringName]:
	var out: Array[StringName] = []
	for b: RoteiroBlock in blocks:
		if b.kind == RoteiroBlock.Kind.ROTULO and not out.has(b.target):
			out.append(b.target)
	return out

func equals(other: RoteiroEvent) -> bool:
	if other == null or id != other.id or leading.size() != other.leading.size() or blocks.size() != other.blocks.size():
		return false
	for i: int in leading.size():
		if not leading[i].equals(other.leading[i]):
			return false
	for i: int in blocks.size():
		if not blocks[i].equals(other.blocks[i]):
			return false
	return true

# Roteiro em texto: referência da sintaxe (M16)

O roteiro é um arquivo `.roteiro` em texto simples. Cada arquivo guarda vários eventos; cada evento vira um `EventScript` com o id dele. O compilador (`game/core/script/roteiro_compiler.gd`) transforma o texto nos passos que o jogo já executa, então nada muda no jogo: um roteiro é só outra forma de escrever os mesmos eventos.

Exemplos reais desta página vêm de `game/data/fatia/roteiro/cidade.roteiro`, com textos placeholder.

> **Editor de blocos (M17):** a aba **VAT > Roteiros > Editor** lê e grava este mesmo formato, sem mudar o sentido de nada. Ao salvar, ele escreve no formato canônico: LF, uma linha em branco antes de cada `===` (e dos comentários colados nele), uma linha por bloco e no máximo uma linha em branco seguida. Os 3 arquivos da fatia já estão nesse formato, então salvar não muda os bytes deles. As linhas que o editor não entende viram blocos **Linha não entendida**, com o texto original: nada se perde, e o compilador acusa essas linhas como erro até você corrigi-las.

## Regras gerais

- Uma instrução por linha. Espaços no começo e no fim da linha são ignorados. Tabs viram espaços.
- Linhas vazias são ignoradas.
- `#` só comenta a **linha inteira**, quando ela começa com `#`. Não há comentário no fim de uma linha: um `#` depois de um texto faz parte do texto.
- Acentos e `|` no texto são aceitos.
- Antes do primeiro `=== id` só valem os `@flag` (veja abaixo). Qualquer outra linha dá erro.

## Eventos

```
=== id_do_evento
```

Cada `=== id` começa um evento. O id é uma palavra, sem espaços, e não pode repetir dentro do mesmo arquivo. Um evento termina no próximo `===` ou no fim do arquivo. No fim de todo evento existe um rótulo `fim` implícito: o evento acaba ali.

## Falas

| Linha | Resultado |
|---|---|
| `Nome: texto` | fala de `Nome` |
| `Nome [expressão]: texto` | fala de `Nome` com o retrato da expressão (`neutro`, `feliz`...) |
| `: texto` | fala de sistema, sem nome (placa, aviso) |
| `\| texto` | continua a fala anterior, numa nova linha |

```
Morador A [neutro]: Texto de teste: bem-vindo à Cidade Teste.
: Placa de teste: a saída leva ao mapa-múndi.
Morador E: Texto de teste: a dungeon fica a leste, depois da estrada.
| segunda linha da mesma fala.
```

- `[expressão]` é opcional. Se a expressão não existe no retrato, a caixa usa `neutro`. Sem retrato nenhum, a caixa fica como antes.
- O nome do falante é o `display_name` do herói, ou o `id` / `display_name` de um `SpeakerDef` (veja o [guia de criação](guia-criacao.md)).
- Uma fala vazia (`Nome:` sem texto) dá erro. `|` sem fala antes (ou logo depois de uma escolha) também.

## Escolhas

Uma escolha é uma fala seguida de linhas `*`. A fala vira a pergunta; cada `*` é uma opção:

```
: Gostou da cidade?
* Sim -> gostou
* Não -> nao
```

- De 1 a 4 opções (`MAX_OPTIONS` é 4). Mais de 4 dá erro; sem opção nenhuma dá erro (`escolha sem opções`).
- Cada opção tem o formato `* texto da opção -> rótulo`. O texto é tudo antes do último `->`.
- A pergunta mantém o falante e o retrato da fala que vem antes dos `*`. No exemplo, a pergunta é de sistema (sem nome), porque é a linha `: ...`.
- Uma linha `*` sem pergunta antes dá erro (`opção '*' sem pergunta antes`).
- Convenção, não regra do compilador: escreva a pergunta terminando em `?`.

O compilador gera sozinho a flag oculta `_esc_<evento>_<n>` que guarda a opção escolhida, e os desvios para cada rótulo. Você não precisa declará-la.

## Rótulos e saltos

```
== nome_do_rotulo
-> nome_do_rotulo
-> fim
```

- `== rótulo` marca um ponto do evento. Não pode repetir no mesmo evento.
- `-> rótulo` salta para o rótulo. `-> fim` termina o evento.
- Nome de rótulo: sem espaço e não vazio; não pode começar com `_` (reservado ao compilador) e não pode conter `- > | * # @ ? : = [ ]`.
- `fim` é implícito: não pode ser declarado com `== fim`.
- Todo `->` e toda opção de escolha precisam de um rótulo que exista no evento. Rótulo inexistente dá erro, no fim do evento.

## Condições

Condições são linhas que começam com `?`. Quando a condição é verdadeira, o evento salta para o rótulo; quando é falsa, segue para a linha de baixo.

### Flag

```
? flag == N -> rótulo
```

Operadores: `==`, `!=`, `>=`, `<=`, `>`, `<`. `N` é um inteiro (pode ser negativo). A flag precisa estar declarada com `@flag` no arquivo; senão o compilador avisa (é um aviso, não um erro).

```
? missao_estado != 2 -> ativa
? recrutado_d != 0 -> ja
```

### Item

```
? item id_do_item -> rótulo
? item id_do_item N -> rótulo
```

Verdadeira quando o grupo tem pelo menos `N` do item (padrão 1). O id é resolvido em `res://data`.

```
? item erva_teste -> entrega
```

### Dinheiro

```
? dinheiro >= N -> rótulo
```

Mesmos operadores das flags. `N` é um inteiro, mínimo 0.

## Flags

```
@flag nome
```

Declara uma flag do arquivo. Vale o arquivo inteiro e pode ficar em qualquer lugar. Não muda nada no jogo; serve para o compilador (e o validador) saberem que a flag existe. Sem `@flag`, o uso da flag gera o aviso `flag 'nome' usada sem '@flag nome'`.

```
@set nome N     -- define a flag com N
@add nome N     -- soma N à flag (N pode ser negativo)
```

Valores são inteiros.

## Comandos

Todo comando começa com `@`, e só vale dentro de um evento.

| Comando | Efeito | Argumentos |
|---|---|---|
| `@set flag N` | define a flag | inteiro |
| `@add flag N` | soma N à flag | inteiro |
| `@give item id [N]` | dá N itens (padrão 1) | N ≥ 1 |
| `@give equip id [N]` | dá N equipamentos (padrão 1) | N ≥ 1 |
| `@give moedas N` | dá N moedas | N ≥ 1 |
| `@take item id [N]` | tira N itens (padrão 1) | N ≥ 1 |
| `@xp N [ativos\|todos]` | dá N de XP | N ≥ 1; `ativos` (padrão) ou `todos` |
| `@ensinar heroi habilidade` | ensina a habilidade ao herói | ids |
| `@curar [pct]` | cura o grupo em pct% do HP (padrão 100) | 1 a 100; aceita `50` ou `50%` |
| `@recrutar heroi [nivel N]` | recruta o herói; `nivel N` fixa o nível | N ≥ 1 |
| `@batalha encontro` | inicia um encontro | id |
| `@mover ator marcador [velocidade]` | move um ator até um marcador | velocidade ≥ 0 (padrão 0) |
| `@camera marcador` | move a câmera até um marcador | nome do marcador |
| `@esperar segundos` | espera (aceita `0.6` ou `0,6`) | ≥ 0 |
| `@fim_demo` | encerra a demo (tela de fim) | sem argumentos |

Exemplos da fatia:

```
@take item erva_teste
@give moedas 40
@give equip capacete_teste_b_f
@xp 120
@set missao_estado 2
@recrutar teste_d_f
@camera BossSpot
@esperar 0.6
@fim_demo
```

`@xp` com `todos` dá XP a todo recrutado; com `ativos` (padrão), só ao grupo ativo.

## Ids

Os ids dos comandos e das condições são resolvidos pelos recursos de `res://data/` (itens, equipamentos, heróis, encontros, habilidades), pelo mesmo `id` que o save usa. Um id que não existe dá erro. Veja a seção de importação sobre o que acontece quando um id muda.

## Mensagens de erro

Todo erro e aviso vem com arquivo e linha: `arquivo.roteiro:linha: mensagem`. O compilador segue depois de um erro e junta todos. Exemplos reais de mensagens (o texto exato é esse):

| Situação | Mensagem |
|---|---|
| linha que não é fala nem comando (sem `:`) | `linha não reconhecida (fala é 'Nome: texto')` |
| linha antes do primeiro `===` | `linha fora de um evento (use '=== id' antes)` |
| id de evento com espaço ou vazio | `id de evento inválido ('...'): use uma palavra, sem espaços` |
| evento repetido | `evento 'x' repetido (já definido na linha 3)` |
| fala sem texto | `fala vazia` |
| colchete do retrato não fechado | `colchete do retrato não foi fechado` |
| `\|` sem fala antes | `'\|' continua uma fala, mas não há fala antes` |
| `*` sem pergunta | `opção '*' sem pergunta antes (use 'Nome: pergunta?')` |
| opção sem `->` | `opção sem '-> rótulo'` |
| opção sem texto | `opção vazia` |
| quinta opção | `escolha com mais de 4 opções` |
| escolha sem opções | `escolha sem opções` |
| rótulo com caractere proibido | `nome de rótulo inválido ('a b')` |
| rótulo repetido | `rótulo 'x' repetido (já definido na linha 9)` |
| `== fim` | `rótulo 'fim' é implícito e não pode ser declarado` |
| salto para rótulo que não existe | `rótulo 'aceita' não existe` (no fim do evento) |
| condição sem `->` | `condição sem '-> rótulo'` |
| condição de flag mal formada | `uso: ? flag == N -> rótulo (operadores: == != >= <= > <)` |
| `? item` mal formado | `uso: ? item id [N] -> rótulo` |
| `? dinheiro` mal formado | `uso: ? dinheiro >= N -> rótulo (operadores: == != >= <= > <)` |
| número inválido | `número inválido: 'abc'` |
| número abaixo do mínimo | `número fora do intervalo (mínimo 1): '0'` |
| comando desconhecido | `comando desconhecido '@xyz'` |
| comando com uso errado | `uso: @give item id [N] \| @give equip id [N] \| @give moedas N` (cada comando tem a sua mensagem de uso) |
| id que não existe em `res://data` | `item 'x' não existe` (também `equipamento`, `herói`, `encontro`, `habilidade`) |
| `@curar` fora de 1 a 100 | `porcentagem de cura fora de 1 a 100: '150'` |
| flag sem `@flag` (aviso) | `flag 'x' usada sem '@flag x'` |

No editor, o erro aparece no console do Godot quando o `.roteiro` é importado, e no painel VAT (aba Validar). Veja o [guia de criação](guia-criacao.md).

## Exemplo completo

Trecho de `game/data/fatia/roteiro/cidade.roteiro` (o NPC Morador B tem uma escolha):

```
=== morador_b
Morador B: Texto de teste: o que acha da Cidade Teste?
: Gostou da cidade?
* Sim -> gostou
* Não -> nao
== gostou
Morador B: Texto de teste: que bom! Aproveite a loja.
-> fim
== nao
Morador B: Texto de teste: é uma cidade de mentira mesmo.
```

O compilador lê assim: a primeira fala é um `SayStep` comum. A linha `: Gostou da cidade?` vira a pergunta de uma escolha de duas opções. Se o jogador escolhe "Sim", o evento salta para `gostou`, fala, e termina em `-> fim`. Se escolhe "Não", vai para `nao`, e o `fim` implícito encerra.

Um exemplo com condição, estado e comandos, do mesmo arquivo (Morador C, a missão secundária):

```
=== morador_c
? missao_estado != 2 -> ativa
Morador C: Texto de teste: obrigado de novo pela ajuda.
-> fim
== ativa
? missao_estado != 1 -> inicio
? item erva_teste -> entrega
Morador C: Texto de teste: ainda falta a Erva de Teste. Há um baú no andar 1 da dungeon.
-> fim
== entrega
Morador C: Texto de teste: é a Erva de Teste! Pegue esta recompensa.
@take item erva_teste
@give moedas 40
@give equip capacete_teste_b_f
@xp 120
@set missao_estado 2
: Missão de teste concluída!
-> fim
```

A flag `missao_estado` é declarada no topo do arquivo com `@flag missao_estado`.

## Ligar um evento a um nó

No editor, um nó que aceita evento (NPC, placa, baú, gatilho) tem dois campos:

- `roteiro`: o arquivo `.roteiro`, arrastado do FileSystem (o Godot o mostra como `RoteiroBook`, o recurso que o importador cria);
- `event_id`: o id do evento, exatamente como está em `=== id`.

Se os dois estiverem preenchidos, vale o roteiro. Se o `event_id` não existe no arquivo, o jogo registra um erro no log e usa o `event` (o `.tres` antigo) se houver. Os `.tres` de evento antigos continuam funcionando; o campo `event` só é ignorado quando o roteiro está preenchido.

## Importação e checagem

- O `.roteiro` é importado pelo plugin VAT (`addons/vat_editor/roteiro_importer.gd`). Ao salvar o arquivo, o Godot reimporta sozinho. Se houver erro de compilação, a importação falha e cada erro vai para o console com `arquivo:linha: mensagem`.
- No primeiro import ou abertura de um clone novo, o console pode mostrar `importer for type 'vat.roteiro' not found` / `Failed loading resource ... .roteiro`. O plugin ainda não estava carregado; um segundo `--import` (ou reabrir o editor) sai limpo.
- O importador **não rastreia** os recursos de `res://data/` que o roteiro cita. Se você renomear um item, herói, habilidade ou encontro que o roteiro usa, reimporte o `.roteiro` (salve o `.roteiro` de novo ou reimporte-o pelo FileSystem).
- Checagem fora do editor, sem janela:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --headless --path game -s tools/roteiro/check.gd
& "<Godot_v4.x-stable_win64_console.exe>" --headless --path game -s tools/validate/check_all.gd
```

`check.gd` compila todos os `.roteiro` e sai com código diferente de 0 se houver erro. `check_all.gd` roda todos os validadores de conteúdo, inclusive os roteiros, e também sai com 1 se houver erro. Os dois listam avisos sem falhar.

- Para o jogo exportado, o que vale é o recurso importado: o jogo só carrega o `RoteiroBook` pronto e não compila nada.

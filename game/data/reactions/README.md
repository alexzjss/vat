# Reações (M14)

Esta pasta guarda as 28 reações elementais: um `.tres` por par, do tipo `ReactionDef` (`game/core/defs/reaction_def.gd`), e a `tabela.tres`, do tipo `ReactionTable` (`game/core/defs/reaction_table.gd`), que lista todas. A batalha carrega `res://data/reactions/tabela.tres` ao começar; se o arquivo não carregar, nada reage. Todos os números são valores de teste.

A matriz aprovada pelo usuário está no [plano do M14](../../../.claude/plans/2026-10-22-m14-marcas-reacoes.md#matriz-das-28-reações-aprovada-pelo-usuário-em-2026-10-22), e o relatório de balanceamento em [`docs/balance/2026-10-22-relatorio-reacoes.md`](../../../docs/balance/2026-10-22-relatorio-reacoes.md).

## Campos do ReactionDef

Campo vazio ou 0 não faz nada. Frações são do dano final do golpe que disparou, antes da barreira.

| Campo | Tipo | Unidade e efeito |
|---|---|---|
| `id` | StringName | Identificador único (ex.: `&"vapor"`). Não muda. |
| `display_name` | String | Nome mostrado no popup e no painel de debug. |
| `a`, `b` | ElementDef | Os dois elementos do par; a ordem não importa. Precisam ser diferentes e reagir (`reacts` ligado). |
| `keep` | ElementDef | Vazio consome as duas marcas. Senão fica a marca desse elemento, que precisa ser `a` ou `b`. |
| `bonus_pct` | float | Fração do dano final (0,5 = +50%). Não passa de novo pela afinidade e não marca. |
| `target_statuses` | StatusDef[] | Estados aplicados no alvo; cada um sorteia com `status_chance`. |
| `status_chance` | float, 0 a 1 | Chance dos estados do alvo e da área. Sorteia só quando a reação acontece. |
| `area_radius` | float, pixels | Raio em volta do alvo: P = 120, M = 200, G = 300. 0 = sem área. |
| `area_pct` | float | Fração do dano final para cada outro aliado vivo do alvo dentro do raio. Dano neutro, sem marca e sem reação. |
| `area_statuses` | StatusDef[] | Estados em cada atingido pela área, com `status_chance`. |
| `target_atb` | float, fração da barra | Somado à barra de ATB do alvo: −0,25 atrasa um quarto; 0,25 adianta. Não mexe em quem está cheio e fora da fila. |
| `attacker_atb` | float, fração da barra | O mesmo, no atacante. Se ele age nesse golpe, o ajuste vale depois da ação. |
| `attacker_statuses` | StatusDef[] | Estados no atacante, sem sorteio. |
| `heal_attacker_pct` | float | Cura do atacante, fração do dano final. |
| `heal_allies_pct` | float | Cura cada aliado vivo do atacante (ele incluso), fração do dano final. |
| `remove_target_statuses` | StatusDef[] | Estados removidos do alvo (ex.: a Barreira, quebrada pela Fragmentar). |

## Editar uma reação

1. Abra o `.tres` e mude o número.
2. Mantenha o `id` e o nome do arquivo.
3. Rode `./run_sim.ps1 -Fatia` na raiz do repositório e confira as metas da fatia (comuns e chefe) em relação ao relatório.
4. Rode `./run_tests.ps1`, que inclui `test_reaction_data.gd`.

## Trocar o nome

Mude só `display_name`. O `id` é o que o registro do golpe guarda e o que os testes conferem. O nome do arquivo é a referência em `tabela.tres`: se mudar, a tabela deixa de carregar essa reação.

## O que é `keep`

`keep` define qual marca sobra depois da reação. Se for `a` ou `b`, a marca desse elemento fica com `mark_turns` cheios. Se estiver vazio, as duas marcas somem. Exemplos: o Incêndio (Fogo + Vento) fica com `keep` = Fogo; a Chama Negra (Fogo + Trevas) fica com Trevas.

## A tabela

`tabela.tres` é um `ReactionTable` com o campo `reactions`, que lista os 28 `.tres` como recursos externos. Para adicionar uma reação, crie o `.tres`, inclua-o nessa lista e rode o validador. Um par que não está na tabela não dispara.

## O validador

`ReactionRules.errors(table, elements)` (em `game/core/reaction_rules.gd`) devolve a lista de erros; lista vazia quer dizer que está tudo certo. Ele confere:

- par repetido (a ordem não importa);
- elemento nulo, ou par com o mesmo elemento nos dois lados;
- elemento que não reage (`reacts` desligado, como o Radioativo);
- `keep` fora do par;
- par faltando entre dois elementos que reagem.

O validador roda nos testes (`test_reaction_data.gd`), não no jogo.

## Os 28 arquivos

- `abismo.tres`
- `arco_iris.tres`
- `bencao_do_vento.tres`
- `chama_negra.tres`
- `ciclone_eletrico.tres`
- `cristalizar.tres`
- `eclipse.tres`
- `eletrocutar.tres`
- `ferro.tres`
- `ferver.tres`
- `fragmentar.tres`
- `hemorragia.tres`
- `incendio.tres`
- `julgamento.tres`
- `lama.tres`
- `magma.tres`
- `maldicao.tres`
- `nevoa_rubra.tres`
- `pulso.tres`
- `sepultura.tres`
- `sobrecarga.tres`
- `supernova.tres`
- `sussurro.tres`
- `tempestade.tres`
- `tempestade_areia.tres`
- `transfusao.tres`
- `trovao_negro.tres`
- `vapor.tres`

Mais `tabela.tres`, a lista de todas. O Radioativo não tem reação e não aparece em nenhum arquivo.

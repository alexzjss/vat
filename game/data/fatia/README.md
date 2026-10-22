# Dados da fatia vertical (M12)

Esta pasta guarda os dados da fatia vertical, o percurso que o **Novo jogo** abre (cena `game/world/game_fatia.tscn`). **Tudo aqui é placeholder ou valor de teste**: nomes, textos e números não são canônicos (spec v4.0, seção 8). Nada é história oficial; troque o que quiser.

## O que é placeholder

- **Nomes:** heróis Teste A a E, Morador A a F, Lojista, Pousadeiro, Inimigo F1 a F4, Guardião (fatia), Braço (fatia), e os itens e equipamentos com sufixo `_f` ou nome genérico ("Erva de Teste", "Capacete do Teste B").
- **Nomes novos (M15):** obstáculos Vinhas, Comporta e Mecanismo; terrenos Chuva e Calor; técnicas Desafio, Chuvisco, Geada, Escanear, Contagem e Espelho; Inimigo Raro F; item Lente.
- **Textos:** as falas dos eventos são "Texto", "Texto de teste" ou frases de teste que dizem o que a cena faz.
- **Números:** todo valor, como vitalidade, força, XP, Moedas, drops, chances e preços.

## Onde trocar cada coisa

| O quê | Onde | Observações |
|-------|------|-------------|
| Inimigos | `enemies/` (`inimigo_f1` a `inimigo_f4`, `guardiao_fatia`, `braco_fatia`) | Vitalidade, Moedas e drops (`DropEntry`) de cada um |
| Encontros | `encounters/` (`enc_f1`, `enc_f2`, `enc_f12`, `enc_f3`, `enc_f4`, `enc_f34`, `chefe_fatia`) | Quais inimigos formam cada luta |
| Itens | `items/` (`pocao_f`, `eter_f`, `remedio_f`, `reviver_f`, `chave_f`, `erva_teste`) | Preço em `price`; `erva_teste` é o item-chave da missão |
| Equipamento | `equipment/` (`lamina_aco_f`, `bastao_carvalho_f`, `arco_longo_f`, `armadura_pesada_f`, `capacete_leve_f`, `capacete_teste_b_f`) | Preço em `price` |
| Loja | `shops/loja_cidade.tres` | O que está à venda na cidade (estoque infinito) |
| Eventos | `events/` (`morador_a` a `morador_f`, `pousadeiro`, `recruta_d`, `recruta_e`, `placa_dungeon_1`, `placa_dungeon_2`, `placa_saida`, `chefe_entrada`, `cena_final`) | Texto dos diálogos, flags e recrutamento |
| Perfil de início | `start.tres` | Heróis do grupo inicial, itens, Moedas (50), mapa e ponto de entrada |
| Terrenos | `terrain/` (`chuva`, `calor`) | Multiplicador do dano elemental por elemento (`element_mult`); ver [Terreno](#terreno-terraindef) |
| Obstáculos elementais | nos mapas `world/fatia/` (`dungeon_1.tscn`, `dungeon_2.tscn`) | Elemento, flag e textos de cada obstáculo; ver [Puzzles elementais](#puzzles-elementais-elementalobstacle) |
| Técnicas novas (M15) | `abilities/` (`desafio_f`, `chuvisco_f`, `geada_f`, `escanear_f`, `contagem_f`, `espelho_f`) | Quem usa: Teste A, Teste B, Teste C, Inimigo Raro F e Inimigo F4 (ver [Conteúdo novo](#conteúdo-novo-m15)) |

Os **heróis** da fatia têm cópias próprias em `heroes/` (`teste_a_f` a `teste_e_f`, M13): `start.tres` e os recrutas D e E usam essas, com 1 elemento nativo e 1 técnica elemental (`abilities/`) cada. `data/test/heroes/` fica neutro para as demos e os testes antigos.

Os valores gerais novos ficam em `game/core/defs/balance_config.gd`, com o comentário "valor de teste": `currency_name` (nome da moeda), `inn_price` (preço da pousada), `sell_ratio` (fração do preço que a venda rende) e `max_stack` (limite de pilha ao comprar).

## Puzzles elementais (`ElementalObstacle`)

Um obstáculo elemental é uma instância do script `res://world/elemental_obstacle.gd` (classe `ElementalObstacle`, que estende `Interactable`), filha do nó do mapa. Na cena do mapa, adicione o nó com estes campos exportados:

- `element`: o `ElementDef` do obstáculo, um `.tres` de `data/elements/`. Obrigatório.
- `flag`: o nome da flag que guarda o estado (`StringName`). Obrigatório, e único por obstáculo. Exemplo: `f1_vinhas`.
- `open_text`: fala depois de abrir o caminho. Vazio = nenhuma fala.
- `locked_text`: fala quando ninguém do grupo sabe uma técnica do elemento. Vazio = texto padrão do código.
- `size`: tamanho da colisão e do desenho (`Vector2`, padrão 32×32).

Como funciona: ao interagir, o jogo abre uma escolha com os heróis do grupo que sabem uma técnica do elemento. Só contam os heróis ativos e em pé; a reserva não entra. Escolher um herói gasta o AP da técnica dele com esse elemento (a mais barata, se houver mais de uma). Sem AP, a opção aparece desativada. Ao abrir, a flag vira 1, e o obstáculo some (visual e colisão), também depois de salvar e carregar.

Os três da fatia são placeholders:

| Obstáculo | Mapa | Elemento | Flag | Técnica de exemplo |
|---|---|---|---|---|
| Vinhas | `dungeon_1.tscn` (andar 1) | Fogo (`kagutsuchi`) | `f1_vinhas` | Chama (`chama_f`, 4 AP) |
| Comporta | `dungeon_2.tscn` (andar 2) | Água (`susanoo`) | `f2_comporta` | Chuvisco (`chuvisco_f`, 3 AP) |
| Mecanismo | `dungeon_2.tscn` (andar 2) | Raio (`indra`) | `f2_mecanismo` | Faísca (`faisca_f`, 5 AP) |

Cada obstáculo tem um baú atrás dele, num nicho. A lógica está em `game/world/elemental_obstacle.gd`, e os testes em `game/tests/test_elemental_obstacle.gd`.

## Terreno (`TerrainDef`)

Um terreno (ou clima) muda o dano elemental de todos os golpes da batalha daquele mapa.

1. Crie um `TerrainDef` (`game/core/defs/terrain_def.gd`) em `data/fatia/terrain/<id>.tres`.
2. Preencha os campos:
   - `id`: `StringName` único.
   - `display_name`: o nome que aparece no canto da batalha.
   - `element_mult`: dicionário de id do elemento para multiplicador. Elemento ausente vale 1,0. Exemplo, a Chuva: `&"susanoo": 1.2` e `&"kagutsuchi": 0.8`.
3. Na cena do mapa, no campo `terrain` do `LocalMap`, aponte para o `.tres`. Hoje a estrada usa `chuva` e o `dungeon_2` usa `calor`.

O multiplicador entra depois da afinidade e antes do escudo do núcleo, nos dois lados. Absorção, golpe neutro (sem elemento) e Radioativo não são afetados. Campo `terrain` vazio = sem efeito.

O simulador tem a sua própria tabela de terreno por encontro, `TERRAIN_BY_ENC` em `game/tools/sim/sim_fatia.gd`, que põe o Calor nos encontros do andar 2. Se você mudar o terreno de um mapa, ajuste essa tabela também, para o relatório refletir o jogo.

## Conteúdo novo (M15)

Todos os nomes são placeholder, e os números são valores de teste.

- **Técnicas** (`abilities/`):
  - `desafio_f` (Desafio, 3 AP): Provocar em si mesmo; Teste A.
  - `chuvisco_f` (Chuvisco, 3 AP, Água): aplica Molhado; Teste B.
  - `geada_f` (Geada, 5 AP, Água): aplica Congelado com chance de 50%; Teste B.
  - `escanear_f` (Escanear, 2 AP): Scan, sem dano; Teste C.
  - `contagem_f` (Contagem, 3 AP): aplica Contagem; Inimigo Raro F.
  - `espelho_f` (Espelho, 4 AP): Reflexo em si mesmo; Inimigo F4.
- **Inimigo:** `inimigo_raro_f` (Inimigo Raro F), no encontro `enc_raro` do andar 2 (`dungeon_2.tscn`). Parado num canto, fora da rota, então é opcional. Usa Contagem e é imune a Sono.
- **Item:** `lente_f` (Lente, 20 na loja da cidade), que faz o Scan do bestiário.
- **Imunidades:** o Guardião e os Braços (`guardiao_fatia`, `braco_fatia`) são imunes a Contagem e Petrificação.

## Depois de mudar um número

Rode o simulador da fatia na raiz do repositório:

```powershell
./run_sim.ps1 -Fatia -Runs 60   # grava docs/balance/2026-10-20-relatorio-fatia.md (e o .csv ao lado)
./run_sim.ps1 -Fatia -Quick     # só imprime as métricas, sem gravar o relatório
```

Confira no relatório se o grupo ainda chega ao chefe no Nível 4 a 6 e se o chefe continua entre 15 e 20 segundos. Se a rota típica sair dessa faixa, ajuste os números da fatia (esta pasta), e não a curva de XP global nem os dados de teste.

## Referências

- Relatório de balanceamento: [`docs/balance/2026-10-20-relatorio-fatia.md`](../../../docs/balance/2026-10-20-relatorio-fatia.md)
- Plano do M12: [`.claude/plans/2026-10-20-m12-fatia-vertical.md`](../../../.claude/plans/2026-10-20-m12-fatia-vertical.md)

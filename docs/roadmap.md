# Roteiro de desenvolvimento — núcleo, mecânicas e gameplay

> **Data:** 2026-10-18 · **Estado:** M1 (batalha ATB) e M2 (mapa-múndi → área → encontro no mapa) prontos na `main`, 208 testes.
> **Foco:** continuar construindo **sistemas** (regras, mecânicas, ciclo de jogo) com formas simples, sem arte nem conteúdo narrativo. Cada item vira um marco com design → plano → implementação → revisão, como no M1 e no M2.
> **Como usar:** escolha os itens que quer; a ordem recomendada está no fim. Itens marcados **(spec)** já existem como regra confirmada ou proposta na spec do jogo e só faltam implementar; **(novo)** são ideias que ainda não estão na spec.

---

## Trilha A — Combate

| # | Item | O que entra | Por que importa | Depende de |
|---|---|---|---|---|
| A1 | **Fuga e iniciativa por contato** (spec) | Comando "Fugir" (chance/custo), consequência já confirmada (sem XP); vantagem ao encostar pelas costas, emboscada quando o inimigo encosta primeiro (ATB inicial diferente) | Dá decisão real ao encontro no mapa, estilo Chrono Trigger | M2 |
| A2 | **Personagens de suporte** (spec) | Chamar um personagem fora do grupo para uma ação única; usos limitados por batalha; não recebe XP (já confirmado) | Mecânica confirmada e ainda inexistente | A4 ajuda |
| A3 | **Techs combinadas** (spec, adiada) | Habilidades de 2–3 heróis, exigem todos prontos, custo de Aura de cada um, ATB de todos reinicia | Assinatura de Chrono Trigger; muda muito a tática | estável no M1 |
| A4 | **Grupo de 4 e formação** (spec) | Até 4 ativos (hoje 3), escolher quem entra, posições na arena | Regra confirmada; base para suporte e menu | — |
| A5 | **IA e chefes** (spec) | Telegraph de ataques fortes, fases de chefe por HP, contra-ataques, alvos por posição | Chefes de verdade para o M3 | — |
| A6 | **Catálogo de estados completo** (spec) | Paralisia ativa, mais buffs/debuffs, resistências por inimigo afinadas, Pare/Confusão (novo) | Mais profundidade tática | — |
| A7 | **Elementos e fraquezas** (novo) | Afinidades elementais em habilidades e inimigos | Mais variedade; não está na spec | decisão sua |

## Trilha B — Personagem e progressão

| # | Item | O que entra | Por que importa | Depende de |
|---|---|---|---|---|
| B1 | **Menu de campo** (spec) | Itens fora de combate, status, alocação de pontos, formação, ordem do grupo | Hoje só dá para gerenciar o grupo na batalha | — |
| B2 | **Equipamento** (spec) | Slots concretos, restrições por personagem, menu de equipar, passivos, modificadores negativos | Regra confirmada; completa a progressão | B1 |
| B3 | **Reinício de atributos** (spec) | Item raro usado em ponto de descanso redistribui pontos | Regra confirmada | B1, C1 |
| B4 | **Fórmulas definitivas e balanceamento** (spec, Etapa C) | Trocar valores de teste por fórmulas aprovadas; simulador de batalhas em lote para medir vitória/duração | Hoje tudo é "valor de teste"; afeta a sensação de tudo | qualquer momento |
| B5 | **Habilidades por progressão** (novo) | Aprender habilidades por nível/eventos | A spec não define como habilidades são obtidas | decisão sua |

## Trilha C — Estrutura e exploração

| # | Item | O que entra | Por que importa | Depende de |
|---|---|---|---|---|
| C1 | **Ponto de descanso e save/load em disco** (spec) | Pontos no mapa que recuperam HP/Aura e salvam; vários slots; carregar ao abrir o jogo | Substitui o "descanso provisório" do M1 e o save só na memória do M2 | — |
| C2 | **Comportamentos de inimigo no mapa** (spec) | Rota fixa, perseguir ao ver, inimigo que puxa o grupo (encontro com vários), chefes que não reaparecem | Previsto no design do M2 como plugável | M2 |
| C3 | **Economia e loja** (spec) | Moeda, drops de inimigos, loja de itens/equipamento | Fecha o ciclo explorar → lutar → melhorar | B2 ajuda |
| C4 | **Eventos, diálogo e flags** (spec) | Sistema de diálogo com escolhas, eventos roteirizados, flags de história, XP narrativa (regra já confirmada) — só o sistema, sem texto da história | Base para o conteúdo narrativo seu | — |
| C5 | **Elementos de dungeon** (spec, parcial) | Baús, portas e chaves, interruptores, armadilhas simples | Dungeons com gameplay além de lutar | C4 ajuda |
| C6 | **Várias áreas e transporte** (spec) | Mais de um local, conexões entre áreas, veículo no mapa-múndi | Escala do mundo; menos "núcleo" | C1 |

---

## Escolhas do usuário (2026-10-18)

**Entram:** A1, A2, A4, A5, A6, B1, B2, B4, B5, C1, C2, C4, C5.
**Ficam de fora por enquanto:** A3 Techs combinadas, A7 Elementos, C3 Economia e loja, C6 Várias áreas e transporte.

**Sequência de marcos** (o primeiro foi escolhido pelo usuário; o resto é proposta de ordem):

| Marco | Conteúdo | Motivo da posição |
|---|---|---|
| **M3** | B1 Menu de campo + A4 Grupo de 4 e formação | Escolha do usuário |
| M4 | B2 Equipamento | Usa o menu de campo do M3 |
| M5 | B4 Fórmulas e balanceamento | Depois do equipamento, que entra nas fórmulas |
| M6 | C1 Descanso + save/load (+ B3 reinício de atributos) | Recupera e salva o grupo já completo |
| M7 | A1 Fuga e iniciativa + C2 Comportamentos de inimigo | Encontro no mapa vira decisão |
| M8 | A2 Suporte | Usa a formação do M3 |
| M9 | B5 Habilidades por progressão | Usa níveis e eventos |
| M10 | C4 Eventos/diálogo + C5 Dungeon | Base para conteúdo |
| M11 | A5 IA e chefes + A6 Estados | Chefes para a fatia vertical |
| depois | Fatia vertical (cidade, dungeon, chefe) | Junta tudo |

## Ordem recomendada (original)

1. **C1 Descanso + save/load** — destrava sessões de jogo reais e remove os provisórios do M1/M2.
2. **B1 Menu de campo + A4 Grupo de 4** — o jogador passa a gerenciar o grupo fora da batalha.
3. **A1 Fuga e iniciativa + C2 Comportamentos de inimigo** — o encontro no mapa vira decisão tática.
4. **B2 Equipamento + C3 Economia/loja** — progressão completa.
5. **A2 Suporte + A3 Techs** — as mecânicas de assinatura do combate.
6. **C4 Eventos/diálogo + C5 Dungeon** — preparam o conteúdo.
7. **A5 IA e chefes** → **M3 fatia vertical** (cidade, dungeon, chefe) juntando tudo.
8. **B4 Fórmulas** pode entrar em qualquer ponto; quanto antes, menos rebalanceamento depois.

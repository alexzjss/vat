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

## As partes, em detalhe (inspiração Chrono Trigger / Final Fantasy)

O usuário pediu para construir com base em CT e FF sem nova rodada de perguntas. Cada parte abaixo é o escopo proposto; o **plano detalhado de cada uma é escrito no começo dela**, em cima do código real que as anteriores deixaram (planos escritos cedo demais apontam para arquivos e interfaces que ainda vão mudar). Tudo aqui é escolha do designer (Claude), a revisar.

**M3 — Menu de campo e grupo de 4** · design [`m3-menu-grupo-design`](superpowers/specs/2026-10-18-m3-menu-grupo-design.md) · plano [`m3-menu-grupo`](superpowers/plans/2026-10-18-m3-menu-grupo.md)
Menu estilo FF (Itens, Técnicas, Status, Atributos, Formação) com painel do grupo estilo CT; 4 ativos + reserva; líder anda no mapa.

**M4 — Equipamento** · design [`m4-equipamento-design`](superpowers/specs/2026-10-19-m4-equipamento-design.md) · plano [`m4-equipamento`](superpowers/plans/2026-10-19-m4-equipamento.md)
- Slots: **Arma**, **Armadura**, **Capacete**, **Acessório** (como CT); cada personagem tem uma lista de tipos de arma permitidos (restrição por personagem, como FF/CT).
- Página "Equipar" no menu de campo com prévia antes/depois dos atributos (FF).
- Modificadores positivos e negativos e passivos simples (ex.: "+10% Aura máxima", "imune a Sono") — passivos ligados aos sistemas que já existem.
- Equipamento inicial e alguns itens de teste no inventário.

**M5 — Fórmulas e balanceamento** · design [`m5-formulas-design`](superpowers/specs/2026-10-19-m5-formulas-design.md) · plano M5a [`m5a-simulador`](superpowers/plans/2026-10-19-m5a-simulador.md)
- **Concluído** (M5b, 2026-10-19): fórmulas escolhidas pelo usuário e aplicadas; ver [decisões do M5b](superpowers/specs/2026-10-19-m5-formulas-design.md#decisões-do-m5b) e o [relatório final](balance/2026-10-19-relatorio-final.md).
- Trocar valores de teste por fórmulas propostas (HP/Aura máximos, ATB, esquiva, dano e defesa, curva de XP) para o usuário aprovar, uma de cada vez.
- **Simulador de batalhas em lote** (headless) que mede taxa de vitória, duração e dano por turno de cada encontro de teste; relatório para decidir números.

**M6 — Descanso e save/load** · **Concluído** (2026-10-19) · plano [`m6-descanso-save-config`](superpowers/plans/2026-10-19-m6-descanso-save-config.md)
Entregue: tela de título (Novo jogo / Continuar), save em disco com 3 slots, pontos de descanso com reinício de atributos (Cristal de Reinício), Game Over para o título, página Config e modo ATB Ativo. O descanso provisório do M1 segue só na batalha isolada.
- **Pontos de descanso** no mapa (como os "save points" de CT/FF): recuperam HP/Aura, salvam e permitem o **reinício de atributos** com o item raro (spec).
- Save em disco com **3 slots**, tela de título "Novo jogo / Continuar", carregar volta ao ponto de descanso.
- Remove o "descanso provisório" do M1 e o save só na memória do M2.

**M7 — Fuga, iniciativa e inimigos no mapa** · **Concluído** (2026-10-19) · plano [`m7-fuga-iniciativa-mapa`](superpowers/plans/2026-10-19-m7-fuga-iniciativa-mapa.md)
Entregue: corrida e grupo em fila (Shift/X), fuga segurando Q (barra, sem XP, chefes não fogem), iniciativa por contato (Ataque surpresa / Emboscada), patrulha, perseguição em cone, inimigo escondido, grupo que se junta e chefe que não reaparece.
- Comando **Fugir** (chance por Velocidade do grupo vs inimigos; tentativa consome o turno; sem XP, regra já confirmada).
- **Iniciativa por contato** (CT): encostar pelas costas = ATB do grupo começa cheio; inimigo que encosta primeiro = emboscada (ATB dos inimigos começa cheio).
- Comportamentos novos: **rota fixa**, **perseguir ao ver** (cone de visão), **grupo que se junta** (encostar em um puxa os vizinhos); chefes que não reaparecem.

**M8 — Limite** · **Concluído** (2026-10-19) · plano [`m8-limite-suporte`](superpowers/plans/2026-10-19-m8-limite-suporte.md)
- Barra de Limite por herói (estilo FF7): enche só com dano sofrido, persiste entre lutas e vai no save; com a barra cheia, o comando "Limite" substitui "Atacar" e usa um golpe próprio, sem custo de AP.

**M8.5 — Suporte** · **Concluído** (2026-10-19) · plano [`m8-limite-suporte`](superpowers/plans/2026-10-19-m8-limite-suporte.md)
- A reserva vira **suporte** (spec): comando "Suporte" chama um herói da reserva para uma ação dele (ataque ou habilidade que gasta o AP dele), custando 50% do Limite de quem chama; sem limite de usos por luta; não recebe XP (confirmado).

**M9 — Habilidades por progressão**
- Cada personagem tem uma **lista de habilidades por nível** (FF) e algumas liberadas por eventos (CT); aviso "Aprendeu X!" na tela de resultado.

**M10 — Eventos, diálogo e dungeon**
- Caixas de diálogo com nome, escolhas simples, **flags** de história e **XP narrativa** (regra já confirmada) — só o sistema e textos de teste.
- Objetos de dungeon: **baús**, **portas e chaves**, **interruptores**, **armadilhas** simples; eventos roteirizados que movem personagens.

**M11 — IA, chefes e estados**
- Chefe de teste com **fases por HP**, **ataques anunciados** (telegraph) e **contra-ataque**, alvo por posição.
- Catálogo de estados ampliado (Paralisia em uso, buffs/debuffs de Velocidade e Vitalidade, Pare) e resistências por inimigo.

**Depois — Fatia vertical**: cidade, dungeon e chefe usando tudo acima.

## Ordem recomendada (original)

1. **C1 Descanso + save/load** — destrava sessões de jogo reais e remove os provisórios do M1/M2.
2. **B1 Menu de campo + A4 Grupo de 4** — o jogador passa a gerenciar o grupo fora da batalha.
3. **A1 Fuga e iniciativa + C2 Comportamentos de inimigo** — o encontro no mapa vira decisão tática.
4. **B2 Equipamento + C3 Economia/loja** — progressão completa.
5. **A2 Suporte + A3 Techs** — as mecânicas de assinatura do combate.
6. **C4 Eventos/diálogo + C5 Dungeon** — preparam o conteúdo.
7. **A5 IA e chefes** → **M3 fatia vertical** (cidade, dungeon, chefe) juntando tudo.
8. **B4 Fórmulas** pode entrar em qualquer ponto; quanto antes, menos rebalanceamento depois.

## Decisões do usuário (2026-10-19, rodada 2)

- **Habilidades fixas por personagem** (estilo Chrono Trigger): cada herói aprende as próprias técnicas por nível e por eventos (M9). Nada de sistema de orbes equipáveis.
- **Barra de Limite** (estilo FF7): uma barra que enche ao sofrer dano e libera um golpe especial quando cheia. Entra como marco novo **M8.5 — Limite**, depois do Suporte.
- **Techs combinadas continuam fora.**
- **Dificuldade clássica**: lutas comuns tranquilas (quase nunca perder), chefes exigem tática. Metas do M5b passam a ser: luta comum 20–60 s com `smart` e vitória ≥ 95%; com `basic`, vitória ≥ 75%.

## Decisões do usuário (2026-10-19, rodada 3) — "finalizar a base"

**Escopo:** M5b, M6, M7, M8, M8.5, M9, M10 e M11. Cada marco termina com revisão final do Sonnet, testes verdes e merge ff na `main` local, sem pedir aprovação (nunca push). Paro só se surgir uma dúvida de design.

- **M5b:** aproveitar o trabalho sem commit (revisar e completar).
- **ATB:** modos Espera e Ativo, escolhidos no menu Config.
- **Config:** modo do ATB, velocidade da batalha, memória do cursor, velocidade do texto e volume (placeholder, ainda sem áudio).
- **Movimento:** correr segurando uma tecla; membros do grupo seguem o líder em fila (CT).
- **Save:** 3 slots, só em ponto de descanso e no mapa-múndi; tela de título Novo/Continuar. **Game Over** → carregar o último save.
- **Fuga:** segurar uma tecla enche uma barra de fuga em tempo real, mais rápido com a Velocidade do grupo. Chefes bloqueiam a fuga. Sem XP.
- **Inimigos no mapa:** perseguir ao ver (cone), patrulha por rota, grupo que se junta, emboscada escondida (ATB inimigo adiantado). Iniciativa por contato como já previsto.
- **Limite:** um golpe por herói. A barra enche só com dano sofrido (proporcional ao HP máximo), esvazia ao usar e persiste entre lutas.
- **Suporte:** custa **50% da barra de Limite** de quem chama. Qualquer herói ativo pode chamar, sem limite de usos por luta. Não dá XP.
  - Consequência [I]: como o Suporte depende do Limite, a ordem passa a ser **M8 Limite → M8.5 Suporte**.
- **Reserva:** não ganha XP. Não há troca de membros durante a batalha.
- **Técnicas (M9):** uma técnica no nível 1; 4–6 técnicas até o nível 20; algumas só por evento. Nomes são placeholders.
- **Estados (M11):** Pare, Confusão, buffs e debuffs de Força, Vitalidade e Velocidade, Silêncio, Cegueira, Regeneração e Barreira. **Elementos continuam fora.**
- **Chefe de teste (M11):** fases por HP, ataque anunciado, contra-ataque e partes múltiplas (CT).
- **M10:** baús, portas e chaves, interruptores, armadilhas; caixa de diálogo com nome e escolhas que gravam flags, cenas roteirizadas, NPCs e placas, XP narrativa.

**Ordem:** M5b → M6 (descanso, save, título, Config, ATB Ativo) → M7 (fuga, iniciativa, IA no mapa, corrida, seguidores) → M8 Limite → M8.5 Suporte → M9 Técnicas → M10 Eventos/dungeon → M11 Chefes/estados.

# Roteiro de desenvolvimento — núcleo, mecânicas e gameplay

> **Data:** 2026-10-18 · **Estado:** M1 a M17 prontos (M17 são os editores visuais, concluídos em 2026-10-24; M16 são as ferramentas de criação, concluídas em 2026-10-22; M15 são os estados, o mundo e o bestiário, concluídos em 2026-10-22; M14 são as marcas e reações, concluídas em 2026-10-22; M13 são os elementos, concluídos em 2026-10-22; M12 é a fatia vertical, concluída em 2026-10-21). A base de mecânicas vem do M1 ao M11; o M12 junta tudo numa fatia jogável.
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

**M3 — Menu de campo e grupo de 4** · design [`m3-menu-grupo-design`](../.claude/specs/2026-10-18-m3-menu-grupo-design.md) · plano [`m3-menu-grupo`](../.claude/plans/2026-10-18-m3-menu-grupo.md)
Menu estilo FF (Itens, Técnicas, Status, Atributos, Formação) com painel do grupo estilo CT; 4 ativos + reserva; líder anda no mapa.

**M4 — Equipamento** · design [`m4-equipamento-design`](../.claude/specs/2026-10-19-m4-equipamento-design.md) · plano [`m4-equipamento`](../.claude/plans/2026-10-19-m4-equipamento.md)
- Slots: **Arma**, **Armadura**, **Capacete**, **Acessório** (como CT); cada personagem tem uma lista de tipos de arma permitidos (restrição por personagem, como FF/CT).
- Página "Equipar" no menu de campo com prévia antes/depois dos atributos (FF).
- Modificadores positivos e negativos e passivos simples (ex.: "+10% Aura máxima", "imune a Sono") — passivos ligados aos sistemas que já existem.
- Equipamento inicial e alguns itens de teste no inventário.

**M5 — Fórmulas e balanceamento** · design [`m5-formulas-design`](../.claude/specs/2026-10-19-m5-formulas-design.md) · plano M5a [`m5a-simulador`](../.claude/plans/2026-10-19-m5a-simulador.md)
- **Concluído** (M5b, 2026-10-19): fórmulas escolhidas pelo usuário e aplicadas; ver [decisões do M5b](../.claude/specs/2026-10-19-m5-formulas-design.md#decisões-do-m5b) e o [relatório final](balance/2026-10-19-relatorio-final.md).
- Trocar valores de teste por fórmulas propostas (HP/Aura máximos, ATB, esquiva, dano e defesa, curva de XP) para o usuário aprovar, uma de cada vez.
- **Simulador de batalhas em lote** (headless) que mede taxa de vitória, duração e dano por turno de cada encontro de teste; relatório para decidir números.

**M6 — Descanso e save/load** · **Concluído** (2026-10-19) · plano [`m6-descanso-save-config`](../.claude/plans/2026-10-19-m6-descanso-save-config.md)
Entregue: tela de título (Novo jogo / Continuar), save em disco com 3 slots, pontos de descanso com reinício de atributos (Cristal de Reinício), Game Over para o título, página Config e modo ATB Ativo. O descanso provisório do M1 segue só na batalha isolada.
- **Pontos de descanso** no mapa (como os "save points" de CT/FF): recuperam HP/Aura, salvam e permitem o **reinício de atributos** com o item raro (spec).
- Save em disco com **3 slots**, tela de título "Novo jogo / Continuar", carregar volta ao ponto de descanso.
- Remove o "descanso provisório" do M1 e o save só na memória do M2.

**M7 — Fuga, iniciativa e inimigos no mapa** · **Concluído** (2026-10-19) · plano [`m7-fuga-iniciativa-mapa`](../.claude/plans/2026-10-19-m7-fuga-iniciativa-mapa.md)
Entregue: corrida e grupo em fila (Shift/X), fuga segurando Q (barra, sem XP, chefes não fogem), iniciativa por contato (Ataque surpresa / Emboscada), patrulha, perseguição em cone, inimigo escondido, grupo que se junta e chefe que não reaparece.
- Comando **Fugir** (chance por Velocidade do grupo vs inimigos; tentativa consome o turno; sem XP, regra já confirmada).
- **Iniciativa por contato** (CT): encostar pelas costas = ATB do grupo começa cheio; inimigo que encosta primeiro = emboscada (ATB dos inimigos começa cheio).
- Comportamentos novos: **rota fixa**, **perseguir ao ver** (cone de visão), **grupo que se junta** (encostar em um puxa os vizinhos); chefes que não reaparecem.

**M8 — Limite** · **Concluído** (2026-10-19) · plano [`m8-limite-suporte`](../.claude/plans/2026-10-19-m8-limite-suporte.md)
- Barra de Limite por herói (estilo FF7): enche só com dano sofrido, persiste entre lutas e vai no save; com a barra cheia, o comando "Limite" substitui "Atacar" e usa um golpe próprio, sem custo de AP.

**M8.5 — Suporte** · **Concluído** (2026-10-19) · plano [`m8-limite-suporte`](../.claude/plans/2026-10-19-m8-limite-suporte.md)
- A reserva vira **suporte** (spec): comando "Suporte" chama um herói da reserva para uma ação dele (ataque ou habilidade que gasta o AP dele), custando 50% do Limite de quem chama; sem limite de usos por luta; não recebe XP (confirmado).

**M9 — Habilidades por progressão** · **Concluído** (2026-10-19) · plano [`m9-tecnicas`](../.claude/plans/2026-10-19-m9-tecnicas.md)
- Cada personagem tem uma **lista de habilidades por nível** (FF) e algumas liberadas por eventos (CT); aviso "Aprendeu X!" na tela de resultado.
- Entregue: `LearnEntry` e learnset fixo por personagem, técnicas aprendidas por nível e por evento (`HeroState.learn`, aceita só ids do próprio learnset), `learned` no save (com derivação para saves antigos), aviso de aprendizado na tela de resultado e página Técnicas no menu de campo.

**M10 — Eventos, diálogo e dungeon** · **Concluído** (2026-10-20) · plano [`m10-eventos-dungeon`](../.claude/plans/2026-10-19-m10-eventos-dungeon.md)
- Entregue: sistema de eventos com **flags** (no save e no restore), caixa de diálogo com nome e escolhas, NPCs e placas, cenas roteirizadas que movem atores, **XP narrativa**, objetos de dungeon (**baús**, **portas e chaves**, **interruptores** e portões, **armadilhas** de dano e de batalha) e a dungeon de teste ligada ao mapa-múndi (`--demo-m10`). Os textos são de teste.

**M11 — IA, chefes e estados** · **Concluído** (2026-10-20) · plano [`m11-chefes-estados`](../.claude/plans/2026-10-20-m11-chefes-estados.md)
- Entregue: catálogo de estados completo (Pare, Confusão, buffs e debuffs de Força, Vitalidade e Velocidade, Silêncio, Cegueira, Regeneração e Barreira) com abreviações no HUD; itens Remédio e Panaceia (só na batalha); chefe de teste na dungeon com **fases por HP**, **ataque anunciado**, **contra-ataque**, núcleo e partes (o Guardião e os Braços); alvos por posição (`NEAREST`, `FARTHEST` e `CLUSTER` em `AiRule`, usados pelos Braços no `NEAREST`); cenário de relatório do chefe (seção "Chefe (M11)") e `--demo-m11`.
- Resistências por inimigo não mudaram nesta rodada. Os números são valores de teste.
- **Base de mecânicas concluída (M5b–M11)**: combate, movimento, menu e grupo estão fechados. O próximo passo é a fatia vertical (cidade, dungeon e chefe) juntando tudo.

**M12 — Fatia vertical** · **Concluído** (2026-10-21) · plano [`m12-fatia-vertical`](../.claude/plans/2026-10-20-m12-fatia-vertical.md) · relatório [`2026-10-20-relatorio-fatia`](balance/2026-10-20-relatorio-fatia.md)
- Entregue: o **Novo jogo** abre a fatia vertical (`game_fatia.tscn`): título → cidade → mapa-múndi → estrada → dungeon de dois andares → chefe → tela "Fim da demo" → título. Moeda (Moedas) com drops de inimigos, loja que compra e vende, pousada paga, recrutamento (D na cidade, E no andar 1), ligações entre mapas (`MapLink`), perfil de início (`start.tres`), missão secundária com a erva, e a demo `--demo-fatia` de ponta a ponta.
- Todo nome, texto e número é placeholder ("valor de teste"); os dados estão em `game/data/fatia/`, com o próprio README.
- Ritmo: a rota típica chega ao chefe no Nv 5 (meta Nv 4–6). O chefe fica entre 15 e 20 s no simulador (relatório da fatia).

**Desvios do plano (M12):**
- Um mapa extra, `estrada`, entre o mapa-múndi e a dungeon, para que o caminho tenha lutas; o plano previa só `overworld_fatia`.
- `EventTrigger.requires_defeated` (campo novo): o gatilho só dispara se o inimigo indicado já foi derrotado.
- Chefe encolhido para a luta durar 15–20 s: Vitalidade do Guardião de 28 para 3 e dos Braços de 17 para 2 (`data/fatia/`).
- `EventPlayer` corrigido: a caixa de diálogo fecha antes de começar uma batalha, senão uma fala anterior ficava aberta sobre a luta e consumia o Enter.

**Perguntas em aberto (M12), para o usuário decidir:**
- `max_stack` deve limitar também os drops e os itens de evento? Hoje ele limita só a compra.
- O lojista deve cumprimentar o jogador primeiro? Hoje não cumprimenta.
- A missão deve consumir a erva ao entregar? Hoje ela fica na mochila.
- Onde o jogador deve nascer ao voltar pela estrada? Hoje ele nasce na ponta oeste, e por isso o trecho é pulado.
- O chefe deve ser mais longo ou mais difícil depois?
- A diferença de nível entre os heróis (o Teste C fica para trás) deve ser corrigida?
- A rota mínima (chegar ao chefe no nível 3) é aceitável?

**M13 — Elementos** · **Concluído** (2026-10-22) · plano [`m13-elementos`](../.claude/plans/2026-10-22-m13-elementos.md) · relatório [`2026-10-22-relatorio-elementos`](balance/2026-10-22-relatorio-elementos.md)
- Entregue:
  - 9 elementos em `game/data/elements/` (`ElementDef`), com afinidade em %, em habilidades (um elemento), no ataque básico pela arma, em heróis e inimigos (até dois nativos) e no equipamento defensivo.
  - Um único ponto de cálculo (`ElementMath`): bônus de mesmo elemento (×1,2), afinidade com Imune (0) e Absorveu (cura).
  - Shukketsu (Sangue): roubo de vida, bônus com HP baixo e Sangramento. Radioativo: ignora afinidade, contaminação que estoura, corrói a Vitalidade e fere quem usa.
  - Interface: popups Fraco!/Resistiu/Imune/Absorveu e "Contaminação!", elemento nos menus de comando, Técnicas, Equipar e Status, e painel de debug com elemento e multiplicador.
  - Fatia: heróis com elemento próprio, inimigos com fraquezas e resistências, arma e acessório elementais, habilidade de Sangue e uma radioativa. O simulador `smart` prefere a fraqueza.
- Todo número é valor de teste no `BalanceConfig`; o relatório mostra que o `smart` contra o inimigo fraco vence mais rápido que o `basic`.

**Desvios e notas (M13):**
- Os heróis da fatia são cópias `_f` (`teste_a_f` a `teste_e_f`), para a fatia ter elementos próprios; `data/test` fica neutro.
- A corrosão da contaminação reduz o HP máximo sem cortar o HP atual; a tela corta o que passa do máximo.
- Itens ainda não têm elemento.
- A entrada Limite não mostra elemento (é criada sem ele), e as páginas de Técnicas e Equipar mostram o elemento em texto, sem cor.

**Vai para o M14 (Marcas e reações):** marcas elementais que duram N turnos ATB do alvo (o mesmo elemento só renova), reações (matriz de 28 pares, com nomes e efeitos placeholder para revisão), ícone de marca no alvo, popup com o nome da reação e IA que busca combos. O gancho já existe: todo dano elemental passa por `ElementMath.resolve`, e cada hit grava `element` e `affinity`.

**Vai para o M15 (Estados e efeitos fora da batalha):** Queimadura, Congelado, Molhado/Encharcado, Petrificação, Provocar, Berserk, Contagem (Doom) e Reflexo; resistência a estados em % por herói, inimigo e equipamento; veneno no mapa, puzzles elementais, terreno e clima elemental na batalha; bestiário e Scan.

**M14 — Marcas e reações** · **Concluído** (2026-10-22) · plano [`m14-marcas-reacoes`](../.claude/plans/2026-10-22-m14-marcas-reacoes.md) · relatório [`2026-10-22-relatorio-reacoes`](balance/2026-10-22-relatorio-reacoes.md)
- Entregue:
  - Marcas por alvo (`mark`, `mark_turns` = 3 turnos ATB do alvo); o mesmo elemento só renova.
  - 28 reações em `game/data/reactions/` (`ReactionDef`, um `.tres` por par, com `tabela.tres`). O validador (`ReactionRules.errors`) roda nos testes.
  - IA de combo (`CAN_REACT` e `REACTION_TARGET`), com regra de combo em inimigos da fatia e no Guardião.
  - Interface: ícone de marca no alvo, nome da reação no popup e última reação no painel de debug.
  - Simulador: a política `smart` tenta reação antes de área.
- Notas:
  - A matriz foi aprovada pelo usuário.
  - Tempestade atrasa o ATB do alvo (−15%) e também tem área de 30% no raio G.
  - Chama Negra usa Veneno e Sepultura usa Pare, até o M15 trazer Queimadura e Petrificação.
  - Reações deixam as lutas comuns cerca de 20% mais rápidas: `enc_f34` leva 20,9 s com reações e 26,3 s sem.
  - O chefe não muda (16,9 s nos dois casos), porque o núcleo fica protegido pelos Braços.
  - O Teste C age pouco no chefe no simulador, porque age tarde.
  - Pendências: os popups se sobrepõem em reações com área.
  - Pergunta em aberto para o usuário: as reações devem contar contra o chefe?
- Vai para o M15:
  - Queimadura (no lugar do Veneno da Chama Negra) e Petrificação (no lugar do Pare da Sepultura), junto com os estados novos e as resistências a estados.
  - Página "Reações" no menu de campo, junto com o bestiário.

**M15 — Estados, mundo e bestiário** · **Concluído** (2026-10-22) · plano [`m15-estados-mundo-bestiario`](../.claude/plans/2026-10-22-m15-estados-mundo-bestiario.md) · relatório [`2026-10-22-relatorio-estados`](balance/2026-10-22-relatorio-estados.md)
- Entregue:
  - 8 estados novos (Queimadura, Congelado, Molhado, Petrificação, Contagem, Provocar, Berserk e Reflexo) e resistência a estados em % para heróis (base e equipamento), inimigos e equipamentos.
  - Veneno que continua no mapa, puzzles elementais (`ElementalObstacle`) e terreno (`TerrainDef`) que muda o dano elemental na batalha.
  - Bestiário com Scan (técnica Escanear e item Lente) e a página Reações no menu de campo.
  - Sobras do M14: turno contado uma vez só, ícone da marca pelo `icon_text` do elemento, e a demo com `--quit-after 7500`.
- Notas:
  - Chama Negra → Queimadura (antes Veneno); Sepultura → Petrificação (antes Pare).
  - O Remédio da fatia também cura Veneno, Contagem e Petrificação (além de Confusão, Silêncio e Cegueira).
  - Inimigo petrificado dá XP, dinheiro e drops, como um derrotado.
  - Confusão ignora Provocar.
  - Inimigo Raro F, com Contagem, é opcional no andar 2 (parado num canto, fora da rota).
- Pergunta em aberto para o usuário: as reações ainda não aceleram o chefe (17,2 s com reações contra 17,7 s sem), porque o núcleo continua protegido pelos Braços. As reações devem contar contra o chefe?
**M16 — Ferramentas de criação** · **Concluído** (2026-10-22) · plano [`m16-ferramentas`](../.claude/plans/2026-10-22-m16-ferramentas.md)
- Entregue:
  - Roteiro em texto (`.roteiro`) que compila para os eventos que o jogo já executa; os eventos da fatia estão em `data/fatia/roteiro/`.
  - Plugin VAT no editor do Godot, com as abas Banco, Roteiros, Validar e Testar.
  - Pipeline de arte: `SpriteSet` com mapa (32×48), batalha (64×64) e retratos (96×96), usado no mapa, na batalha e no diálogo.
  - Tiles 32×32 nos 7 mapas da fatia, com a colisão no próprio tileset.
  - Validadores de conteúdo e flags de desenvolvimento (`--start-map`, `--spawn`, `--battle`, `--level`).
- Notas:
  - Escolhas mantêm o falante da pergunta.
  - `@curar` usa porcentagem (1 a 100, padrão 100).
  - Testar e Validar rodam em processo separado: `main_run_args` não passa argumentos no Godot 4.7, então o painel abre o jogo com os flags.
  - `data/test` fica fora dos avisos de arte.
  - Braço e Guardião de teste ganharam imunidade a Contagem e Petrificação (regra de chefes).
  - Flag usada sem `@flag` é aviso, não erro, como o compilador já faz; o plano previa erro no validador estrito.
**M17 — Editores visuais** · **Concluído** (2026-10-24) · plano [`m17-editores-visuais`](../.claude/plans/2026-10-24-m17-editores-visuais.md)
- Entregue:
  - Editor de blocos do roteiro na aba Roteiros > Editor, com o modelo `RoteiroDoc` (ida e volta com o mesmo formato do `.roteiro`) e o simulador de eventos em Roteiros > Simular.
  - Registro de mapas em dados (`data/maps/registro.tres`), no lugar do `Game.MAPS` e do `EXIT_SPAWNS`.
  - Assistente Novo mapa, prefabs de objetos e paleta "Objetos" para colocar os objetos na cena.
  - Escolhas em lista no Inspector: mapa e ponto de entrada, roteiro e evento, encontro, loja, falante e elemento.
  - Aba Mundo, com o grafo das ligações entre mapas e as ligações quebradas em vermelho.
  - Formulários no Banco para heróis, inimigos, encontros, lojas, itens, equipamentos e arte, com "Criar a partir de uma imagem…".
- Notas:
  - Os mapas agora ficam em `data/maps/registro.tres`; `Game.MAPS` saiu.
  - O mapa `estrada` é do tipo masmorra.
  - Testar, Validar e Simular rodam em processo separado.

## Próximos passos (em aberto, para o usuário)
- História e roteiro de verdade: trocar os textos placeholder pelos diálogos finais.
- Arte final: substituir os placeholders de tiles, sprites de mapa e batalha, e retratos.
- Áudio: músicas e efeitos, que ainda não existem no projeto.
- Mais mapas e capítulos, usando o tileset e o roteiro.
- Autotile para os terrenos.
- Em aberto: as reações devem contar contra o chefe? (pergunta do M15, ainda sem resposta.)

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

## Decisões do usuário (2026-10-20, rodada 4) — fatia vertical

Estas são as escolhas do usuário que o plano do M12 registrou como [U]. Tudo que é narrativa é só placeholder.

- **Narrativa:** só placeholder ("Cidade Teste", "Morador A" etc.). Tudo fica em dados (`.tres`), para o usuário trocar depois sem mexer em código.
- **Economia:** moeda por batalha, drops de itens, loja que compra e vende, e loja de equipamento.
- **Visual:** formas geométricas desenhadas em código, como hoje.
- **Grupo:** começa com 3 heróis e recruta mais 2, um na cidade e outro na dungeon.
- **Cidade:** loja, pousada paga, NPCs com falas, uma missão secundária e casas com interior.
- **Chefe:** o Guardião com os braços do M11, rebalanceado para o nível da fatia. A luta dura uns 15–20 s nesta fase de testes.
- **Fluxo:** título → cidade → dungeon → chefe → tela de fim → título. Chega-se à dungeon pelo mapa-múndi, com encontros no caminho.
- **Dungeon:** 2 andares.
- **Ritmo:** cerca de 15 min, com o grupo saindo do Nv 1 e chegando ao chefe perto do Nv 5.
- **Conteúdo antigo:** a fatia substitui o Novo jogo. A área de teste, a dungeon de teste e as demos `--demo-*` continuam existindo, só para as demos e os testes.

## Decisões do usuário (2026-10-22, rodada 5) — elementos, reações, estados e ferramentas

O núcleo de mecânicas e a fatia vertical estão prontos (M1–M12). Estas escolhas guiam os próximos marcos. Os nomes dos elementos são do usuário; nomes e efeitos de reação ainda serão propostos e revisados.

- **Elementos (9):** Kagutsuchi (Fogo), Susanoo (Água), Fuhaku (Vento), Atlas (Terra), Indra (Raio), Tsukuyomi (Trevas), Amaterasu (Luz), Shukketsu (Sangue) e um elemento **radioativo** especial.
- **Onde entram:** habilidades (**um** elemento cada), ataque básico pela arma, heróis e inimigos (**até dois** elementos nativos) e equipamento defensivo.
- **Afinidade:** **percentual livre** por elemento. Resistência de 100% = imune; além disso, absorve (cura).
- **Mesmo elemento:** habilidades do mesmo elemento do usuário ganham bônus de dano.
- **Fórmula:** afinidade base + equipamentos **somam em %** e aplicam uma vez; o bônus de mesmo elemento é outro multiplicador.
- **Radioativo:** ignora afinidade, contaminação que acumula até um limite, corrói atributos enquanto dura, e fere o usuário também. **Não participa de reações.**
- **Shukketsu (Sangue):** rouba vida, aplica Sangramento e causa mais dano quanto menor o HP do usuário.
- **Marcas:** todo golpe elemental deixa uma marca no alvo, que dura **N turnos ATB do alvo**. O mesmo elemento sobre a própria marca **só renova**.
- **Reações:** **matriz completa** dos 8 elementos que reagem (**28 pares**, a ordem não importa). Cada reação define o que consome. Efeitos possíveis: dano extra, estados, área e ATB. O Claude propõe a matriz inteira (nomes e efeitos placeholder) e o usuário revisa antes de virar dados.
- **IA:** inimigos buscam combos (regras de IA preferem habilidades que disparam reações em alvos marcados).
- **Estados novos:** Queimadura, Congelado, Molhado/Encharcado, Petrificação, Provocar, Berserk, Contagem (Doom) e Reflexo.
- **Resistência a estados:** % por estado em heróis, inimigos e equipamentos.
- **Fora da batalha:** veneno no mapa, puzzles elementais e terreno/clima elemental na batalha.
- **Interface:** ícone de marca no alvo, popups "Fraco!/Resistiu/Absorveu" com o nome da reação, bestiário/Scan e elemento nos menus.
- **Criação de conteúdo:** plugin no editor do Godot (bancos de itens, inimigos e habilidades; editor de eventos), **roteiro em texto** para a narrativa, tiles **32×32**, sprites de mapa em 4 direções, sprites de batalha animados e retratos de diálogo.
- **Pendências da fatia a fazer antes:** clear save sem sobrescrever o save de antes do chefe, nomes longos no HUD, prompts do mapa escondidos durante a batalha, volta pela estrada pelo lado leste, limite de 99 também para drops e itens de evento, fala do lojista antes da loja, missão consome a erva (passos "tem item" e "tirar item").

**Ordem:** M12.5 pendências da fatia → M13 Elementos → M14 Marcas e reações → M15 Estados novos, resistências e efeitos fora da batalha → M16 Ferramentas de criação (plugin do editor, roteiro em texto, pipeline de arte 32×32).

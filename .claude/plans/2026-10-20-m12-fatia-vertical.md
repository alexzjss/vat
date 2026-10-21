# M12 — Fatia vertical: plano de implementação

> Execução: Sonnet implementa, Haiku documenta, uma revisão final do Sonnet e merge ff local. Decisões do usuário [U] (rodada de 2026-10-20) estão resumidas abaixo e vão para o `roadmap.md` na Task 7. Spec §: `.claude/specs/2026-10-18-rpg-design.md` (marco "Fatia vertical": cidade, dungeon, chefe, descanso/save, loja, diálogo, XP narrativa, subida de nível, ~15 min com save/load). O resto é decisão do designer [I]. **Todo texto, nome e número é placeholder / "valor de teste"**; nenhuma narrativa é inventada como canônica.

**Goal:** um Novo jogo jogável de ponta a ponta em ~15 min:
**título → cidade → mapa-múndi → dungeon (2 andares) → chefe → tela "Fim da demo" → título**, com o save funcionando em todo o percurso.

## Decisões do usuário [U]
- **Narrativa:** só placeholder ("Cidade Teste", "Morador A" etc.). Tudo fica em dados (`.tres`), e o usuário troca depois sem mexer em código.
- **Economia:** moeda por batalha, drops de itens, loja que compra e vende, e loja de equipamento.
- **Visual:** formas geométricas desenhadas em código, como hoje.
- **Grupo:** começa com 3 heróis e recruta mais 2, um na cidade e outro na dungeon.
- **Cidade:** loja, pousada paga, NPCs com falas, uma missão secundária e casas com interior.
- **Chefe:** o Guardião com braços do M11, rebalanceado para o nível da fatia. A luta é **curta, uns 15–20 s** nesta fase de testes.
- **Fluxo:** título → cidade → dungeon → chefe → tela de fim → título. Chega-se à dungeon **pelo mapa-múndi**, com encontros no caminho.
- **Dungeon:** 2 andares.
- **Ritmo:** ~15 min, com o grupo saindo do Nv 1 e chegando ao chefe por volta do Nv 5.
- **Conteúdo antigo:** a fatia **substitui** o Novo jogo. A área de teste, a `dungeon_teste` e as demos `--demo-*` continuam existindo só para as demos e os testes.

## Decisões de design [I]

### Economia (núcleo)
1. **Moeda:** `GameState.money: int`. Vai no save como campo opcional, mantendo `version` 1, e entra em snapshot/restore. O nome exibido vem de `BalanceConfig.currency_name = "Moedas"` (placeholder).
2. **Recompensa:**
   - `EnemyDef.money: int` e `EnemyDef.drops: Array[DropEntry]`. Cada `DropEntry` é um Resource com `item` ou `equipment`, `chance` e `count`.
   - O drop é sorteado por inimigo derrotado, pelo `Dice`.
   - O total vai para um `BattleRewards` puro, que a tela de resultado mostra ("+N Moedas", "Obteve X!").
   - Fuga não dá recompensa. Partes que caem junto com o núcleo dão recompensa, como a XP do M11.
3. **Preços:** `ItemDef.price` e `EquipmentDef.price`. Vender rende `floor(price × sell_ratio)`, com `sell_ratio = 0.5` [CT/FF7].
   - Item-chave e `price = 0` não são vendáveis.
   - Equipamento vestido não aparece na venda; só o da mochila.
4. **`ShopDef`** (Resource): `id`, `display_name`, `items: Array[ItemDef]` e `equipment: Array[EquipmentDef]`. O estoque é infinito.
   - `ShopRules` (puro) faz `buy(state, def, n)` e `sell(state, def, n)`, e diz o máximo que dá para comprar ou vender.
   - O inventário tem limite de pilha `max_stack = 99`. Se já existir um limite assim, ele é reaproveitado.
5. **Pousada:** `inn_price = 20`. Pagar chama `rest_all()` e abre o seletor de slot. Os pontos de descanso da dungeon continuam grátis.

### Recrutamento e perfil de início
6. **`RecruitStep(hero: CharacterDef, level_mode)`**, novo passo de evento:
   - entra nos ativos se houver vaga (`MAX_ACTIVE`), senão vai para a reserva;
   - `level_mode` é `FIXED(n)` ou `PARTY_AVG`, sendo `PARTY_AVG` o padrão [I]: o recruta chega no nível médio dos ativos, arredondado para baixo, e aprende as técnicas até esse nível;
   - é idempotente: um herói já recrutado é ignorado;
   - o runner devolve a linha de sistema "X entrou no grupo!".
7. Também entram os passos novos `GiveMoneyStep(amount)` e `IfMoneyStep`, este só se a missão precisar dele. Opcional: `EndDemoStep`, que pede ao `Game` a tela de fim.
8. **`StartProfile`** (Resource): `party: Array[CharacterDef]`, itens e equipamento iniciais, `money`, `map` e `spawn`.
   - O `Game` exporta `start_profile`.
   - O Novo jogo usa `data/fatia/start.tres`: heróis A, B e C, algumas Poções, 50 Moedas, começando na cidade.
   - As demos e os testes usam `data/test/start_teste.tres`, que equivale ao `game.tscn` de hoje. Nenhuma demo ou teste existente pode mudar de comportamento.
   - Recrutas: o Teste D na cidade e o Teste E no fim do andar 1 [I].

### Mapas
9. **Ligação entre mapas locais:** `MapLink`, uma `Area2D` com `target_map: StringName` e `target_spawn: StringName`. Ao entrar nela, o `Game.go_to(target_map, target_spawn)` faz um fade.
   - Serve para portas de casas, escadas entre andares e saídas.
   - A saída para o mapa-múndi continua como hoje (`EXIT_SPAWNS`), estendida aos mapas novos.
   - O `MAPS` ganha os mapas da fatia.
   - Na pousada e no ponto de descanso, o save grava o spawn do mapa onde o jogador está, inclusive em interiores.
10. **Mapa-múndi da fatia:** `overworld_fatia.tscn` só com a cidade e a dungeon, mais encontros aleatórios ou visíveis no caminho, no padrão do overworld atual. O overworld antigo fica para as demos.
11. **Tela de fim:** `EndScreen` mostra "Fim da demo", o tempo de jogo e o nível do grupo, e volta ao título.
    - Antes de ir para a tela de fim, um save automático [I] grava a flag `fatia_concluida` no último slot usado. Se nenhum slot foi usado, não grava nada. Esse save funciona como um "clear save".

### Conteúdo (`data/fatia/`, `world/fatia/`)
12. **Cidade** (`cidade.tscn`):
    - Itens: Poção, Éter, Remédio, Reviver.
    - Equipamento: armas e armaduras um nível acima das iniciais. Usar o que já existe em `data/test/equipment`, com cópias de preço próprio em `data/fatia/` se precisar.
    - Pousada com balcão e um NPC.
    - 4–6 moradores com falas de teste, um deles com escolha.
    - 2 casas com interior (`casa_1.tscn`, `casa_2.tscn`). Uma delas tem um baú.
    - **Recruta D:** um evento na casa 2 (diálogo → `RecruitStep`).
    - **Missão secundária:**
      - um NPC pede um item (`ItemDef` "Erva de Teste", item-chave);
      - a erva fica num baú opcional do andar 1;
      - ao entregar, o NPC dá Moedas, um equipamento e XP narrativa `ACTIVE`;
      - as flags controlam as falas antes, durante e depois.
    - Uma placa na saída.
13. **Dungeon, andar 1** (`dungeon_1.tscn`):
    - ponto de descanso na entrada;
    - baús;
    - chave + porta;
    - interruptor + portão;
    - armadilha de dano e armadilha de batalha;
    - inimigos com patrulha, perseguição e um grupo;
    - **recruta E** num evento na sala final, antes da escada.
14. **Andar 2** (`dungeon_2.tscn`):
    - uma sala de puzzle simples com dois interruptores, que só abre com as duas flags;
    - inimigos;
    - ponto de descanso antes do chefe;
    - cena curta ao entrar na sala do chefe e o chefe no mapa (`unique_id`, sem fuga);
    - ao vencer, uma cena final com `EndDemoStep`.
15. **Inimigos da fatia:**
    - 3–4 inimigos comuns em `data/fatia/enemies/`, que podem ser cópias dos X, Y e Z com outro nome, cor, moeda e drops;
    - o Guardião e os braços rebalanceados para o Nv ~5;
    - os de `data/test` não mudam.

### Balanceamento e verificação
16. **Ritmo** [U]: um script de rota (`tools/sim/route_fatia.gd`) soma a XP dos encontros obrigatórios, dos típicos opcionais e dos eventos, e confirma que o grupo chega ao chefe no **Nv 4–6**. Se não chegar, ajustar `xp_base` ou o número de inimigos da fatia, nunca a curva global. O mesmo vale para a moeda: chegar à cidade dá para comprar 1–2 equipamentos.
17. **Metas do simulador** (`run_sim.ps1`, cenários novos com o grupo e o nível da fatia):
    - lutas comuns: as metas clássicas de hoje (smart ≥95% e 20–60 s; basic ≥75%);
    - **chefe** [U]: smart com tempo médio de **15–20 s** e vitória ≥90% [I]; basic só relatado.
    - As metas antigas continuam batendo, porque os dados de teste não mudam.
18. **Demo de ponta a ponta** `--demo-fatia`: um roteiro automático percorre a fatia inteira:
    - Novo jogo → loja (compra) → missão (aceita) → recruta D → pousada (salva no slot de teste) → mapa-múndi → andar 1 (erva, recruta E) → andar 2 → chefe (`auto_battle`) → fim → título.
    - Também testa carregar o save no meio e continuar.
    - É o teste de integração da fatia.

## Global Constraints
- Restrições de sempre:
  - tipos estáticos;
  - `core/` sem `Node`, `Input` e IO;
  - números no `BalanceConfig` (ou nos `.tres` da fatia), com o comentário "valor de teste";
  - código em inglês, UI em português;
  - nada de `Get-Content`/`Set-Content` em arquivos acentuados (usar Write/Edit);
  - `"\n"` em vez de quebra de linha literal;
  - commitar os `.uid`;
  - novos enums sempre no final.
- Suíte (~2 min), metas antigas do simulador e todas as demos `--demo-m2…m11` continuam passando, sem mudar de comportamento. Elas usam o perfil de teste.

## Review Focus
1. **Economia:** moeda ou item duplicado ou perdido ao comprar, vender, fugir, no Game Over → restore e na ida e volta do save. Item-chave e equipamento vestido não podem ser vendáveis. → Tasks 1–2.
2. **Recrutamento:** recrutar duas vezes, a reserva cheia, o nível e as técnicas do recruta, e o save. → Task 2.
3. **Spawns:** o save e o load em interiores e andares, o Game Over voltando ao lugar certo e nenhum `MapLink` levando a um spawn inexistente. Um teste varre todos os links. → Tasks 3–4.
4. **Demos antigas intactas** com o perfil de teste. → Task 3.
5. **Ritmo e metas:** o nível na chegada ao chefe e o tempo do chefe. → Task 5.

---

### Task 1: Economia no núcleo (Sonnet)
**Files:**
- novos: `core/defs/drop_entry.gd`, `core/defs/shop_def.gd`, `core/battle_rewards.gd`, `core/shop_rules.gd`;
- alterados: `core/defs/enemy_def.gd`, `item_def.gd`, `equipment_def.gd`, `core/game_state.gd` (money, save, snapshot), `core/battle_controller.gd` ou o ponto onde a XP é calculada (recompensas), `core/defs/balance_config.gd`;
- testes: `tests/test_economy.gd`.
- Testes:
  - o sorteio de drops é determinístico com o `Dice`;
  - a fuga não dá nada e as partes dão;
  - comprar, vender e os limites;
  - item-chave e item com preço 0 não são vendáveis;
  - a ida e volta do save, e o restore.
- Commit `feat(core): moeda, drops e regras de loja`.

### Task 2: Loja, pousada, recrutamento e passos novos (Sonnet)
**Files:**
- `ui/shop_menu.gd`: Comprar/Vender/Sair, quantidade e comparação de atributos do equipamento para quem pode vestir;
- `world/shop_keeper.gd` e `world/inn.gd` (Interactable);
- `core/events/recruit_step.gd`, `give_money_step.gd`, `if_money_step.gd` (se precisar) e `end_demo_step.gd`;
- `core/game_state.gd` (`recruit`);
- tela de resultado: moeda e drops;
- menu de campo: moeda no painel;
- testes: `tests/test_shop_ui.gd`, `tests/test_recruit.gd`.
- Testes:
  - a loja compra e vende pela UI, sem vazar entrada para o mapa;
  - a pousada sem dinheiro recusa;
  - o recruta vai para os ativos ou para a reserva, conforme a vaga;
  - o recruta chega no nível `PARTY_AVG` e com as técnicas desse nível;
  - recrutar é idempotente;
  - o resultado mostra a moeda e os drops.
- Commit `feat(world): loja, pousada e recrutamento`.

### Task 3: Ligações de mapa, perfil de início e tela de fim (Sonnet)
**Files:**
- novos: `world/map_link.gd`, `core/defs/start_profile.gd`, `data/fatia/start.tres`, `data/test/start_teste.tres`, `world/end_screen.gd`;
- `world/game.gd`: perfil, `MAPS`, `EXIT_SPAWNS`, fim e save automático;
- `world/game.tscn`;
- as demos passam a usar o perfil de teste;
- testes: `tests/test_map_links.gd`, `tests/test_start_profile.gd`.
- Testes:
  - o Novo jogo cai na cidade com A, B, C e 50 Moedas;
  - as demos usam o perfil de teste;
  - o `MapLink` leva ao spawn certo;
  - o save e o load em interiores;
  - o `EndDemoStep` mostra o fim e volta ao título;
  - **um teste que varre todos os mapas em `MAPS` e confirma que cada `MapLink` e cada saída apontam para um mapa e um spawn existentes.**
- Commit `feat(game): ligacoes entre mapas, perfil de inicio e tela de fim`.

### Task 4: Conteúdo da fatia (Sonnet)
**Files:** `world/fatia/*.tscn` (`cidade`, `casa_1`, `casa_2`, `overworld_fatia`, `dungeon_1`, `dungeon_2`); `data/fatia/` (inimigos, encontros, eventos, lojas, itens e equipamento com preço, a erva); `tests/test_fatia_content.gd`.
- Testes:
  - todos os eventos carregam;
  - a missão funciona nos estados antes, durante e depois;
  - a recruta D e a recruta E;
  - o puzzle dos dois interruptores;
  - o chefe só aparece depois da cena de entrada e não volta depois de derrotado.
- Verificação visual: `--write-movie` de alguns trechos.
- Commit `feat(fatia): cidade, mapa-mundi e dungeon de dois andares`.

### Task 5: Ritmo e balanceamento (Sonnet)
**Files:** `tools/sim/route_fatia.gd`, `tools/sim/*` (cenários da fatia), os `.tres` de `data/fatia/` (só eles) e `docs/balance/2026-10-20-relatorio-fatia.md` (novo).
- O relatório inclui: o nível estimado na chegada ao chefe, a moeda acumulada, as metas das lutas comuns e do chefe (15–20 s) e o que foi ajustado.
- Commit `balance(fatia): ritmo de XP, moeda e chefe`.

### Task 6: Demo de ponta a ponta (Sonnet)
**Files:** `world/demo_fatia.gd`, `world/game.gd` (flag), `tests/test_fatia_flow.gd` (cada etapa do roteiro como teste de integração, se a suíte comportar).
- A demo roda headless até a tela de fim, com saída 0, sem erros e dentro do `--quit-after`.
- Verificação visual: `--write-movie` com quadros da cidade, da loja, do recrutamento, da dungeon, do chefe e da tela de fim.
- Commit `feat(fatia): demo de ponta a ponta`.

### Task 7: Documentação (Haiku)
- README: como jogar a fatia, moeda, loja, pousada, recrutamento, `--demo-fatia`, e o Novo jogo agora é a fatia.
- `roadmap.md`: decisões da rodada de 2026-10-20 e M12 concluído.
- `data/fatia/README.md` (novo): o que é placeholder e onde trocar nomes e textos.
- Commit `docs: M12 fatia vertical`.

**Ordem de execução:** 1+2 (um agente), depois 3, depois 4, depois 5+6 (um agente), depois a revisão final e a Task 7 em paralelo, cada agente com arquivos próprios (o reviewer não toca nos docs).

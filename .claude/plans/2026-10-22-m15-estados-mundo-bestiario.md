# M15 — Estados novos, resistências, efeitos fora da batalha e bestiário: plano de implementação

> Execução: Sonnet implementa, Haiku documenta, uma revisão final do Sonnet e merge ff local. As decisões do usuário [U] são da rodada 5 (2026-10-22, em `docs/roadmap.md`). O resto é decisão do designer [I]. **Todo número é "valor de teste"**, e todo nome de mapa, terreno ou obstáculo é placeholder.

**Goal:** fechar o sistema de combate e o mundo antes das ferramentas do M16:
- os 8 estados novos;
- resistência a estados em % para heróis, inimigos e equipamentos;
- veneno que continua no mapa;
- puzzles elementais;
- terreno/clima que muda os elementos na batalha;
- o bestiário com Scan e uma página de reações já vistas;
- as sobras do M14.

## Decisões do usuário [U]
- **Estados novos:** Queimadura, Congelado, Molhado/Encharcado, Petrificação, Provocar, Berserk, Contagem (Doom) e Reflexo.
- **Resistência a estados:** % por estado em heróis, inimigos e equipamentos (ex.: anel anti-veneno).
- **Fora da batalha:** veneno no mapa, puzzles elementais e terreno/clima elemental na batalha.
- **Interface:** bestiário/Scan, que mostra as afinidades dos inimigos já vistos.
- **Do M14:** Chama Negra passa a usar Queimadura e Sepultura passa a usar Petrificação (a matriz aprovada já marcava "→ M15").

**Pergunta aberta para o usuário** (não bloqueia o M15): as reações hoje não aceleram o chefe, porque o núcleo é protegido pelos braços e os braços caem em 1–2 golpes. Se o usuário quiser que reações contem contra o chefe, isso entra na Task 7 (dar HP aos braços, ou deixar o núcleo marcável mesmo protegido).

## Decisões de design [I]

### Estados (novos `StatusDef.Kind`, sempre no fim do enum)
1. **Queimadura (`BURN`):**
   - dano de `potency`% do HP máximo a cada ATB cheio do afetado, como o Veneno, e pode derrubar;
   - enquanto ativa, Força −`burn_str_pct` (`0.2`);
   - `cancels` remove Molhado, e aplicar Molhado remove Queimadura (o campo `cancels` já existe).
2. **Congelado (`FREEZE`):**
   - o ATB não enche e o alvo não age, como o Pare, com duração em `seconds`;
   - o primeiro dano de **Força** (físico) que o alvo recebe quebra o gelo: aquele golpe ganha `freeze_shatter_bonus` (`0.5`, +50%) e o estado sai;
   - dano de Aura não quebra;
   - um golpe de Kagutsuchi (Fogo) também derrete o gelo, sem o bônus.
3. **Molhado (`WET`):**
   - sem dano;
   - enquanto ativo, o alvo sofre `wet_indra_bonus` (`0.3`) a mais de dano de Indra, somado à resistência como fraqueza (`element_resist[indra] −0.3`, na mesma soma do M13);
   - impede Queimadura;
   - um golpe de Kagutsuchi seca (remove Molhado).
4. **Petrificação (`PETRIFY`):**
   - aplicar põe uma contagem de `seconds` (`8`) no alvo; ao zerar, o alvo **petrifica**;
   - petrificado = fora da luta: não age, o ATB não enche e não recebe dano nem estados (popup "Pedra");
   - conta como derrotado para o fim da batalha: todos os inimigos caídos ou petrificados = vitória (inimigo petrificado dá XP como derrotado); todos os heróis caídos ou petrificados = Game Over;
   - cura por item ou habilidade (`REMOVE_STATUS` com o estado);
   - no fim da batalha, o herói petrificado volta com o HP que tinha;
   - a contagem antes de petrificar aparece no HUD.
5. **Contagem (`DOOM`):**
   - uma contagem de `seconds` (`15`) que, ao zerar, derruba o alvo (HP 0, contribuição para quem aplicou);
   - removível por `REMOVE_STATUS`;
   - chefes devem ser imunes nos dados (o validador do conteúdo da fatia confere).
6. **Provocar (`TAUNT`):**
   - estado em quem provoca (normalmente aplicado em si mesmo por uma técnica);
   - enquanto houver um provocador vivo do lado alvo, toda escolha de alvo **único** feita pela IA (inimigos, e heróis confusos ou em Berserk) é forçada para ele;
   - as áreas centram nele;
   - o jogador continua escolhendo à vontade;
   - com dois provocadores, vale o de maior duração restante.
7. **Berserk (`BERSERK`):**
   - o afetado age sozinho com o ataque básico num inimigo aleatório vivo, pelo mesmo caminho que a Confusão já usa para ação automática, sem menu para o jogador;
   - Força +`berserk_str_pct` (`0.5`);
   - não usa habilidades nem itens;
   - em inimigos, troca as regras de IA pelo ataque básico.
8. **Reflexo (`REFLECT`):**
   - habilidades com **elemento** (`AbilityDef.element` não nulo, exceto o ataque básico) que mirarem o refletido voltam para quem lançou: todos os efeitos daquele alvo são aplicados no lançador;
   - numa área, cada alvo refletido devolve a sua parte;
   - um golpe refletido não reflete de novo;
   - o refletido não recebe a marca;
   - duração em turnos;
   - popup "Refletiu".
9. **Matriz do M14:** Chama Negra troca Veneno por Queimadura, e Sepultura troca Pare por Petrificação. Os números continuam os da matriz.
10. **Estados em `data/statuses/`?** Os estados novos ficam em `data/test/statuses/` como os outros (`burn`, `freeze`, `wet`, `petrify`, `doom`, `taunt`, `berserk`, `reflect`). O código só procura pelo `kind`, nunca pelo id.

### Resistência a estados
11. **Heróis:** `CharacterDef.status_resist: Dictionary[StringName, float]` (base), somado às passivas `RESIST` dos equipamentos vestidos.
    - A passiva `IMMUNE` continua valendo, e total ≥ 1 também é imune.
    - Inimigos já têm `resistances` e `immunities` (não muda).
    - A chance de aplicar continua sendo `chance × (1 − resistência)` (`status_system.gd`).
12. A página de Status mostra as resistências a estados diferentes de 0, e o bestiário as dos inimigos (Task 6).

### Fora da batalha
13. **Veneno no mapa:**
    - `StatusDef.persists: bool` (verdadeiro só no Veneno, nos dados);
    - no fim da batalha, os estados `persists` ativos num herói vivo vão para `HeroState.field_statuses: Array[StringName]`, sem duração: ficam até serem curados;
    - no mapa, a cada `poison_step_px` (`320`) andados, cada herói envenenado perde `poison_field_pct` (`0.05`) do HP máximo, **sem cair** (mínimo 1 HP, como em FF);
    - no começo de cada batalha, o estado é reaplicado à força com a duração normal;
    - curado por item de campo (Remédio/Panaceia), por técnica de cura de estado, pela pousada e pelo ponto de descanso;
    - vai no save como campo opcional;
    - o HUD do menu de campo mostra "VEN" no herói.
14. **Puzzles elementais:**
    - `ElementalObstacle` (estende `Interactable`) com `element: ElementDef`, `flag: StringName`, `open_text` e `locked_text`;
    - interagir abre uma lista dos heróis do grupo que sabem uma técnica daquele elemento; escolher um gasta o custo de AP da técnica (sem AP, ela aparece desativada);
    - o obstáculo some (colisão desliga) e grava a flag, como o `FlagGate`; sem ninguém capaz, mostra `locked_text`;
    - placeholders: "Vinhas" (Kagutsuchi), "Pedra rachada" (Atlas), "Mecanismo" (Indra).
15. **Terreno/clima:**
    - `TerrainDef` (Resource): `id`, `display_name` e `element_mult: Dictionary[StringName, float]` (ex.: chuva: Susanoo `1.2`, Kagutsuchi `0.8`);
    - `LocalMap` exporta `terrain: TerrainDef`, e a batalha daquele mapa aplica o multiplicador ao dano elemental do atacante: depois da afinidade e antes do escudo, para os dois lados;
    - a batalha mostra o nome do terreno no canto;
    - nulo = sem efeito.

### Bestiário e Scan
16. **`GameState.bestiary: Dictionary[StringName, Dictionary]`**, por id de inimigo: `{seen: bool, defeated: int, scanned: bool}`.
    - Vai no save como campo opcional.
    - Visto = entrou numa batalha.
    - As afinidades e resistências aparecem quando `scanned` ou quando `defeated >= bestiary_reveal_kills` (`3`).
17. **Scan:**
    - novo `EffectDef.Kind.SCAN` (no fim): marca o inimigo como `scanned` e mostra um popup com as fraquezas, resistências e absorções;
    - uma técnica de Scan para um herói da fatia (aprendida no Nv 2) e um item "Lente" na loja;
    - sem dano e sem contribuição.
18. **Página "Bestiário"** no menu de campo:
    - lista os inimigos vistos (os não vistos aparecem como "???");
    - mostra nome, nível, HP máximo e as derrotas;
    - depois de revelado, mostra os elementos nativos, as afinidades, as resistências a estados e os drops já obtidos.
19. **Página "Reações":**
    - `GameState.seen_reactions: Array[StringName]`, no save;
    - lista as reações já disparadas por alguém, com nome, par e um resumo dos efeitos gerado do `ReactionDef` (ex.: "+50% dano · Cegueira 50%");
    - as não vistas aparecem como "???".

### Sobras do M14
20. **Turno contado duas vezes:** um alvo atrasado por reação, que já estava na fila, não conta o `on_atb_full` de novo ao reencher. A flag `Combatant.turn_counted` zera quando ele age.
21. **Iniciais da marca:** Terra e Trevas ambas "T". O ícone passa a usar `ElementDef.icon_text` (novo campo, padrão 1–2 letras), com "At" para Atlas e "Ts" para Tsukuyomi. O usuário troca no `.tres`.
22. **Limite da demo:** a `--demo-fatia` passa a usar `--quit-after 7500`. O script da demo imprime a folga ("quadro N de 7500").
23. **Combo do F4:** o F4 fecha combos de verdade. Ele reserva AP para a Brasa: a regra de cura passa a ter um limite de HP do aliado, e a de combo vem antes.

## Global Constraints
- Restrições de sempre:
  - tipos estáticos;
  - `core/` sem `Node`, `Input` e IO;
  - números no `BalanceConfig` com o comentário "valor de teste";
  - código em inglês, UI em português;
  - CRLF;
  - commitar os `.uid`;
  - novos enums sempre no fim.
- A suíte, `run_sim.ps1 -Meta` (os dados de teste antigos não usam os estados novos), `-Fatia` e as demos continuam passando. A `--demo-fatia` termina nas seeds 1–5 e na padrão.
- **O save continua com `version` 1:** os campos novos são opcionais, e um save do M14 carrega igual.

## Review Focus
1. **Petrificação e Contagem no fim da batalha:** vitória e derrota com petrificados; XP de inimigo petrificado; Game Over; chefe imune a Contagem. → Task 1.
2. **Congelado:** só dano de Força quebra; o bônus sai uma vez. **Molhado × Queimadura:** cancelamento mútuo. → Task 1.
3. **Provocar, Berserk e Reflexo:** nenhuma escolha do jogador é forçada; Berserk sem menu; Reflexo sem loop e sem marca. → Task 2.
4. **Veneno no mapa:** nunca derruba; cura em todos os caminhos; save e load. → Task 4.
5. **Bestiário e reações vistas:** o save antigo carrega; nada é revelado cedo demais. → Tasks 5–6.
6. **Determinismo:** `-Meta` igual. → todas.

---

### Task 1: Estados de controle e dano (Sonnet)
Queimadura, Congelado, Molhado, Petrificação e Contagem.
- **Files:**
  - `core/defs/status_def.gd`, `core/status_system.gd`, `core/action_executor.gd` (Congelado e Molhado no dano), `core/element_math.gd` (o Molhado soma na resistência), `core/battle_state.gd`/`battle_controller.gd` (o fim da batalha com petrificados e as contagens), `core/defs/balance_config.gd`;
  - `data/test/statuses/{burn,freeze,wet,petrify,doom}.tres`;
  - os rótulos de HUD em `battle/combatant_view.gd`: QUEI, GELO, MOLH, PEDRA (e a contagem), DOOM N;
  - `tests/test_status_new.gd`.
- **Testes:** cada regra das decisões 1–5, os dois fins de batalha com petrificados e a XP.
- Commit `feat(core): queimadura, congelado, molhado, petrificacao e contagem`.

### Task 2: Estados de comportamento (Sonnet)
Provocar, Berserk e Reflexo.
- **Files:** `core/status_system.gd`, `core/enemy_ai.gd` e o alvo da IA (Provocar), o caminho da ação automática da Confusão (Berserk), `core/action_executor.gd` (Reflexo), `battle/battle_scene.gd` (Berserk sem menu), `tools/sim/sim_policy.gd` (respeitar Provocar e Berserk), `data/test/statuses/{taunt,berserk,reflect}.tres`, os rótulos de HUD (PROV, BERS, REFL), `tests/test_status_behavior.gd`.
- **Testes:** as decisões 6–8, incluindo a área centrada no provocador, dois provocadores, o Reflexo em área e o Reflexo do ataque básico com elemento de arma (não reflete).
- Commit `feat(core): provocar, berserk e reflexo`.

### Task 3: Resistências e matriz (Sonnet)
- **Files:** `core/defs/character_def.gd` (`status_resist`), `core/combatant.gd` e `core/equipment_rules.gd` (a soma), `ui/field_menu/status_page.gd` (as resistências a estados), `data/reactions/chama_negra.tres` e `sepultura.tres` (a troca da decisão 9), `tests/test_status_resist.gd`, `tests/test_reaction_data.gd` (as duas linhas).
- Commit `feat(core): resistencia a estados por heroi e equipamento`.

### Task 4: Fora da batalha (Sonnet)
- **Files:**
  - veneno no mapa: `core/defs/status_def.gd` (`persists`), `core/hero_state.gd` (`field_statuses`), `core/game_state.gd` (o save), o fim e o começo da batalha, o andar no mapa (`world/local_map.gd` ou `overworld.gd`), a pousada e o descanso, os itens de campo (`core/field_actions.gd`), e o "VEN" no `party_panel`;
  - `world/elemental_obstacle.gd` com a escolha do herói;
  - `core/defs/terrain_def.gd`, o `terrain` no `LocalMap`, o multiplicador no dano e o rótulo da batalha;
  - `tests/test_field_poison.gd`, `tests/test_elemental_obstacle.gd`, `tests/test_terrain.gd`.
- Commit `feat(world): veneno no mapa, puzzles elementais e terreno`.

### Task 5: Bestiário e Scan no núcleo (Sonnet)
- **Files:** `core/game_state.gd` (`bestiary`, `seen_reactions` e o save), onde as batalhas começam e terminam (visto/derrotado), `core/defs/effect_def.gd` (`SCAN`), `core/action_executor.gd`, `ui/reaction_text.gd` ou um `ui/bestiary_text.gd` puro (os resumos), `tests/test_bestiary.gd`.
- Commit `feat(core): bestiario, scan e reacoes vistas`.

### Task 6: Páginas do menu e popup do Scan (Sonnet)
- **Files:** `ui/field_menu/bestiary_page.gd`, `ui/field_menu/reactions_page.gd`, `ui/field_menu/field_menu.gd` (as entradas novas), o popup do Scan em `battle/combatant_view.gd`, `tests/test_bestiary_ui.gd`.
- **Verificação visual:** capturas das duas páginas, de um Scan e dos estados novos no HUD, na pasta de scratchpad.
- Commit `feat(ui): bestiario e reacoes no menu`.

### Task 7: Fatia, sobras do M14 e balanceamento (Sonnet)
- **Conteúdo** (`data/fatia/`):
  - técnicas com os estados novos espalhadas entre heróis e inimigos: Provocar num herói tanque, Reflexo num inimigo do andar 2, Congelado e Molhado numa técnica de Susanoo, e Contagem num inimigo raro;
  - a técnica de Scan e a Lente na loja;
  - 2–3 `ElementalObstacle` com baús atrás, em `dungeon_1` e `dungeon_2`;
  - um terreno placeholder na estrada e outro no andar 2;
  - o chefe imune a Contagem e a Petrificação.
- **Sobras do M14:** as decisões 20–23.
- **Ajustes:**
  - `--demo-fatia` (usa o Scan, um obstáculo e o veneno no mapa) termina nas seeds 1–5 e na padrão com 7500;
  - as metas do M12–M14 batem;
  - relatório `docs/balance/2026-10-2x-relatorio-estados.md`.
- Commit `feat(fatia): estados novos, puzzles, terreno e bestiario no conteudo`.

### Task 8: Documentação (Haiku)
- **README:** os estados novos em uma linha cada, a resistência a estados, o veneno no mapa, os puzzles, o terreno, o bestiário/Scan e a página de reações.
- **`roadmap.md`:** M15 concluído, e o próximo passo é o M16 (ferramentas).
- **`data/fatia/README.md` e `data/elements/README.md`:** como criar um obstáculo elemental e um terreno, e o campo `icon_text`.
- Commit `docs: M15 estados, mundo e bestiario`.

**Ordem de execução:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → revisão final e Task 8 em paralelo. As Tasks 4 e 5 mexem em `game_state.gd` (o save), por isso vão em sequência.

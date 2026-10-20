# M11 — Chefes e estados: plano de implementação

> Execução: Sonnet implementa, Haiku documenta, uma revisão final do Sonnet e merge ff local. As decisões do usuário estão em [`roadmap.md`](../../roadmap.md), "rodada 3" [U]. A spec é citada como §. O resto é decisão do designer [I], quase sempre inspirada em CT/FF7. Os números são "valor de teste" no `BalanceConfig`, e os nomes são placeholders.

**Goal:** completar o catálogo de estados e ter um chefe de teste de verdade na dungeon do M10:
- estados: Pare, Confusão, buffs e debuffs de Força, Vitalidade e Velocidade, Silêncio, Cegueira, Regeneração e Barreira;
- chefe com fases por HP, ataque anunciado, contra-ataque e partes múltiplas.

Elementos continuam fora [U].

## Decisões de design

### Estados
1. **`StatusDef.Kind`** ganha `STOP`, `CONFUSION`, `SILENCE`, `BLIND` e `REGEN`. Ganha também `negative: bool`, usado para remover "todos os estados negativos".
2. **Pare** [U; regra I, CT]:
   - O ATB não enche e o afetado não age. Ele continua podendo ser alvo, e a esquiva é 0.
   - A duração conta em **segundos de batalha** (`ActiveStatus.time_left`, a partir de `StatusDef.seconds`). Não conta em turnos, porque com o ATB parado ela nunca acabaria. Os outros estados do afetado também não descontam turnos enquanto ele está parado.
   - Pare não sai com dano.
   - Ao ser aplicado:
     - quem está na fila sai dela e mantém o ATB cheio, voltando à fila quando Pare acabar;
     - a sessão aberta de um herói é cancelada, como quando o herói cai;
     - uma ação enfileirada no modo Ativo é reembolsada.
3. **Confusão** [U; regra I, FF7]:
   - Quando o afetado age, uma ação automática substitui a escolha: o ataque básico num alvo sorteado (pelo `Dice`) entre todos os combatentes vivos, menos ele mesmo.
   - O herói confuso não abre menu, e o inimigo confuso ignora a IA.
   - Sai com dano de HP, como o Sono (§ tabela de estados).
4. **Buffs e debuffs** [U]: usam o `ATTR_MOD` que já existe.
   - `potency` pode ser negativa.
   - O atributo efetivo tem mínimo 1.
   - Estados diferentes no mesmo atributo se somam (§).
   - Uma mudança na Velocidade reordena a fila (§ ATB). Conferir se isso já acontece e implementar se não acontecer.
   - Dados novos: `str_down`, `vit_up`, `vit_down`, `spd_up` e `spd_down`.
5. **Silêncio** [U; regra I]: o afetado não usa técnicas. Ataque básico, Limite e itens continuam liberados.
   - No menu, "Técnicas" fica desabilitado.
   - A IA inimiga pula as regras de habilidade e cai no ataque básico.
   - Uma ação enfileirada, ou um herói cuja sessão já está na escolha de técnica, é reembolsada ou volta ao menu raiz.
6. **Cegueira** [U; regra I]: efeitos de `DAMAGE` com `scale == STRENGTH` do afetado erram com chance extra `blind_miss_chance = 0.5`. O erro é sorteado antes da esquiva e aparece como "Errou".
7. **Regeneração** [U]: cura `regen_pct = 0.05` do HP máximo (no mínimo 1) a cada ATB cheio.
   - Acontece no passo (a) do `on_atb_full`, junto com o Veneno: primeiro o Veneno, depois a Regeneração.
   - Não revive.
   - A cura credita o ledger como benefício a aliado (§ 4, contribuição de benefício).
8. **Barreira** já existe. Só entra no catálogo de dados e testes de UI.
9. **Itens e habilidades de teste**:
   - itens: `remedio` (remove Confusão, Silêncio e Cegueira) e `panaceia` (remove todos os `negative`);
   - para isso, `EffectDef` ganha `statuses: Array[StatusDef]` e `REMOVE_STATUS` remove a lista. Com a lista vazia e `status == null`, remove todos os negativos;
   - habilidades de inimigo que aplicam cada estado novo, para o chefe e os testes;
   - os learnsets dos heróis **não mudam**, para não mexer nas metas do simulador.
10. **HUD**: abreviações dos estados ativos sob o nome de cada combatente. Usar ou estender o que já existe, por exemplo PAR, CNF, SIL, CEG, REG, BAR, FOR+ e VEL-.

### Chefe
11. **Fases por HP** [U]: `EnemyDef.phases: Array[BossPhase]`. Cada `BossPhase` (Resource) tem `hp_below: float`, `ai_rules: Array[AiRule]` (substitui as regras) e `banner: String`.
    - A troca acontece logo depois do dano que cruzou o limiar, uma vez por fase, em ordem.
    - Se um golpe cruzar duas fases, aplica a última.
    - A batalha mostra o banner por `banner_time`.
    - Fases do chefe de teste: 0.66 e 0.33.
12. **Ataque anunciado** [U; regra I, CT]: `AiRule.telegraph: bool`.
    - Quando a IA escolhe uma regra anunciada, o chefe gasta o turno "preparando". A batalha mostra "X prepara Y!", e o chefe fica marcado (`Combatant.charging`).
    - No próximo ATB cheio dele, a ação sai sem passar pela IA, com o alvo revalidado pela regra do `Targeting`.
    - O AP é gasto na execução.
    - Pare, Sono ou Paralisia durante a preparação não a cancelam: ela só espera.
    - A morte do chefe cancela a preparação.
13. **Contra-ataque** [U; regra I]: `EnemyDef.counter: AbilityDef`, `counter_chance` e `counter_only_basic: bool`.
    - Dispara quando um herói causa dano de HP no inimigo. Se `counter_only_basic` for true, só dispara para ataque básico.
    - Acontece logo depois da ação do herói, antes da próxima da fila, contra o atacante (ou redirecionado).
    - Não usa nem zera o ATB.
    - Não dispara se o inimigo estiver caído, parado, dormindo, paralisado ou preparando. Contra-ataque não gera contra-ataque.
    - Suporte também provoca contra-ataque, contra o reserva temporário. Se isso não for possível, contra quem chamou.
14. **Partes múltiplas** [U; regra I, CT]: `EnemyDef.role` é `NORMAL`, `CORE` ou `PART`.
    - Se o encontro tem um `CORE`, a vitória é a queda de todos os `CORE`, e as `PART` caem junto.
    - Enquanto houver uma `PART` com `shields_core = true` de pé, o `CORE` recebe dano × `core_shield_mult = 0.25`, e o HUD avisa "Protegido".
    - Nova condição de IA `PART_DOWN`: o núcleo pode reviver uma parte com a habilidade `REVIVE`, que já existe.
    - XP: cada parte derrotada dá a sua XP, inclusive as que caem junto com o núcleo [I].
15. **Alvo por posição** (roadmap): `AiRule.TargetPick` ganha `NEAREST`, `FARTHEST` e `CLUSTER`. `CLUSTER` é o centro que pega mais inimigos na área da habilidade; o empate fica com o primeiro.

### Conteúdo e integração
16. **Chefe de teste** `chefe_dungeon`: encontro com núcleo "Guardião (teste)" e duas partes "Braço (teste)" (`shields_core`).
    - Fase 1: ataques normais.
    - Fase 2 (0.66): aplica Silêncio, Cegueira ou Confusão e revive os braços.
    - Fase 3 (0.33): "Golpe Sísmico" anunciado (ALL, dano alto) e Pare num herói.
    - O núcleo contra-ataca o ataque básico.
    - `can_flee = false` e `unique_id = &"chefe_dungeon"`.
    - Fica no `BossSpot` da `dungeon_teste`, aparece só depois da flag da `cena_final` e não volta depois de derrotado.
17. **Simulador**:
    - As metas das lutas comuns continuam (`run_sim.ps1 -Meta`).
    - Novo cenário só de relatório: `chefe_dungeon` com o grupo de teste no nível pensado para a dungeon. Mostra a taxa de vitória e o tempo de `smart` e `basic` no relatório final, numa seção "Chefe (M11)".
    - Sem meta obrigatória. Chefe exige tática [U, dificuldade clássica], então `basic` pode perder.
    - A política `smart` aprende o mínimo: curar estados com item quando houver e não atacar o núcleo enquanto ele estiver protegido, se der para fazer simples.
18. **Demo** `--demo-m11`: começa direto na batalha do chefe, com o grupo forte e `auto_battle`. Mostra a troca de fase, o anúncio, o contra-ataque, a parte revivida e os estados no HUD, e termina na vitória.

## Global Constraints
- Restrições de sempre: tipos estáticos; `core/` sem `Node`, `Input` ou IO; números no `BalanceConfig`; código em inglês e UI em português; nada de `Get-Content`/`Set-Content` em arquivos acentuados (usar Write/Edit); `"\n"`; commitar `.uid`.
- Suíte (~2 min, via Bash com timeout longo) e demos `--demo-m2/m4/m6/m7/m8/m10` continuam passando. As metas do simulador continuam batendo.

## Review Focus
1. **Pare e fila**: um combatente parado que age, trava a fila ou nunca volta, e a sessão ou ação enfileirada que não é cancelada ou reembolsada. → Task 1.
2. **Contra-ataque em cascata** ou durante o fim da batalha. → Task 3.
3. **Vitória com partes**: a batalha que não termina ou termina cedo demais com núcleo e partes, e a XP das partes. → Task 3.
4. **Fases**: uma fase pulada ou repetida e a preparação que sobrevive à morte do chefe. → Task 3.
5. **Metas do simulador** depois dos estados. → Task 4.

---

### Task 1: Estados no núcleo (Sonnet)
**Files:** `core/defs/status_def.gd`, `core/active_status.gd`, `core/status_system.gd`, `core/battle_controller.gd`, `core/atb_clock.gd`, `core/stat_calculator.gd`, `core/action_executor.gd`, `core/enemy_ai.gd`, `core/selection_session.gd`, `core/defs/effect_def.gd`, `core/defs/balance_config.gd`, `data/test/statuses/*.tres`, `tests/test_status_catalog.gd`.
- Testes:
  - Pare congela o ATB, sai da fila e volta, expira por segundos, cancela a sessão e reembolsa no Ativo.
  - Confusão: alvo aleatório determinístico com `Dice` fixo, sai com dano.
  - Buffs e debuffs: soma, mínimo 1 e reordenação da fila.
  - Silêncio: bloqueia técnicas e a IA cai no básico.
  - Cegueira: erro só em `STRENGTH`.
  - Regeneração: ordem com o Veneno, mínimo 1, não revive.
  - `REMOVE_STATUS` por lista e "todos os negativos".
- Commit `feat(core): catalogo de estados completo`.

### Task 2: Estados na interface e nos itens (Sonnet)
**Files:** HUD da batalha (abreviações), `battle/command_menu.gd` (Técnicas desabilitado com Silêncio), `battle/battle_scene.gd` (herói confuso age sozinho, "Errou"), `data/test/items/remedio.tres`, `panaceia.tres`, `data/test/abilities/` (aplicadores de estado de inimigo), `tests/test_status_ui.gd`.
- Testes:
  - abreviações aparecem e somem;
  - menu com Silêncio;
  - herói confuso não abre menu;
  - itens curam no campo e na batalha.
- Commit `feat(battle): estados no HUD, menu e itens`.

### Task 3: Chefe no núcleo (Sonnet)
**Files:** `core/defs/boss_phase.gd` (novo), `core/defs/enemy_def.gd`, `core/defs/ai_rule.gd`, `core/enemy_ai.gd`, `core/combatant.gd` (`charging`, fase atual), `core/battle_controller.gd` (fases, preparação, contra-ataque, vitória com núcleo), `core/action_executor.gd` (`core_shield_mult`), `core/battle_state.gd`, `tests/test_boss.gd`.
- Testes:
  - fase muda uma vez e na ordem, e um golpe que cruza duas aplica a última;
  - o anúncio gasta um turno e executa no seguinte, com o alvo revalidado;
  - a morte cancela a preparação;
  - o contra-ataque dispara, respeita a chance, os bloqueios e o `counter_only_basic`, e não entra em cascata;
  - o núcleo protegido recebe dano reduzido;
  - a vitória acontece pela queda dos núcleos, e as partes caem junto e dão XP;
  - `PART_DOWN` revive uma parte;
  - `NEAREST`, `FARTHEST` e `CLUSTER`.
- Commit `feat(core): chefes com fases, anuncio, contra-ataque e partes`.

### Task 4: Conteúdo do chefe, cena, simulador e demo (Sonnet)
**Files:**
- `data/test/enemies/` (núcleo e braço), `data/test/encounters/chefe_dungeon.tres`, `data/test/abilities/` (Golpe Sísmico etc.);
- `battle/battle_scene.gd` (banner de fase, "X prepara Y!", aviso "Protegido", contra-ataque visível);
- `world/dungeon_teste.tscn` (chefe no `BossSpot`, condicionado à flag);
- `tools/sim/*` (cenário do chefe, política mínima), `docs/balance/2026-10-19-relatorio-final.md` (seção "Chefe (M11)");
- `world/demo_m11.gd`, `world/game.gd` (flag), `tests/test_boss_content.gd`.
- Testes: o chefe aparece só depois da flag, não volta depois de derrotado e sobrevive ao save; a fuga é bloqueada.
- Rodar `run_sim.ps1 -Meta` e regerar o relatório com `-Final -Runs 30`. Se uma meta comum quebrar, investigar: os inimigos comuns não usam os estados novos, então não deveria quebrar.
- Verificação visual: `--write-movie` da `--demo-m11`, alguns quadros.
- Commit `feat(battle): chefe de teste na dungeon`.

### Task 5: Documentação (Haiku)
- README (estados, chefe, `--demo-m11`), roadmap (M11 concluído e base de mecânicas fechada), `data/test/README.md` (estados novos, itens, chefe).
- Commit `docs: M11 chefes e estados`.

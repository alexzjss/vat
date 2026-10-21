# M8 Limite + M8.5 Suporte — plano de implementação

> Execução: subagentes em sequência (Sonnet implementa, Haiku documenta), uma revisão final do Sonnet, merge ff local. Os dois marcos vão juntos num branch porque o Suporte gasta a barra de Limite. Decisões do usuário em [`roadmap.md`](../../docs/roadmap.md) "rodada 3" [U]; o resto é decisão do designer [I].

**Goal:** Cada herói tem uma barra de Limite (FF7) que enche com dano sofrido e libera um golpe próprio. Gastar metade da barra chama um herói da reserva para uma ação de suporte.

## Decisões de design

1. **Barra** [U]: `HeroState.limit: float` de 0 a 1.
   - Persiste entre lutas e vai no save (campo opcional, `version` 1).
   - Tem espelho em `Combatant.limit`, que volta ao `HeroState` no fim da batalha, pelo mesmo caminho que HP e AP.
2. **Enchimento** [U]: só com dano sofrido, `limit += dano / hp_max × limit_fill_mult`, com `limit_fill_mult = 1.5` ("valor de teste").
   - Herói caído não enche, mas mantém a barra [I, FF7].
   - Inimigos não têm barra.
   - A conta fica num lugar único do núcleo, onde o dano é aplicado (`ActionExecutor`/`EffectMath`).
   - Veneno também enche.
3. **Golpe** [U]: `CharacterDef.limit_ability: AbilityDef`, uma por herói, sem custo de AP.
   - Com a barra cheia, o comando **"Limite"** substitui "Atacar" no menu raiz [I, FF7].
   - Usar zera a barra no início da execução (`_begin`). Se a ação for perdida por falta de alvo, a barra volta.
   - Dados de teste (nomes placeholder): A "Golpe Final" (dano alto, SINGLE), B "Chuva de Flechas" (ALL inimigos), C "Luz Restauradora" (cura ALL aliados), D "Investida Dupla" (LINE), E "Onda de Aura" (CIRCLE_TARGET).
4. **Interface:**
   - Barra de Limite sob o ATB de cada herói no HUD da batalha, piscando quando cheia.
   - Barra no painel do grupo do menu de campo.
   - A página Status mostra a porcentagem.
5. **Simulador:** a política `smart` usa o Limite quando está cheio, e `basic` não usa.
   - Depois da Task 2, rodar as metas (`run_sim.ps1 -Meta`) e confirmar que continuam batendo (smart ≥95% e 20–60 s; basic ≥75%).
   - Se passar do limite, ajustar só `limit_fill_mult` e o poder dos golpes de Limite.
6. **Suporte** [U]: o comando **"Suporte"** fica no menu raiz, depois de Itens.
   - Fica habilitado se o herói tem `limit ≥ support_cost = 0.5` e há pelo menos um herói da reserva com HP > 0.
   - Fluxo: escolher o herói da reserva → escolher a ação dele (ataque básico ou habilidades que o AP **do herói da reserva** paga) → alvo → confirmar.
7. **Execução do Suporte** [I]:
   - O herói da reserva vira um `Combatant` temporário (`from_hero`), posicionado no `SupportSpot` da arena, ou ao lado de quem chamou se a arena não tiver um.
   - Esse combatente não entra em `b.heroes`, não é alvo e não tem ATB.
   - `PendingAction.caller` guarda quem chamou. No fim, o ATB de quem chamou zera, e não o do suporte.
   - Gastos: quem chamou perde 0.5 de Limite, e o reserva gasta o próprio AP (volta ao `HeroState` dele).
   - XP [U]: o reserva não ganha XP, e a contribuição do suporte no ledger conta para quem chamou.
   - Visual: o reserva aparece (fade-in) no início da ação e some no fim.
   - O simulador não usa Suporte.
8. **Modo Ativo:** o Suporte segue as mesmas regras de submit enfileirado e reembolso. O reembolso devolve o Limite de quem chamou e o AP do reserva.

## Global Constraints

- Restrições de sempre: tipos estáticos; `core/` sem `Node`/`Input`/IO; números no `BalanceConfig`; código em inglês e UI em português; nada de `Get-Content`/`Set-Content` em arquivos acentuados; `"\n"`; commitar `.uid`.
- Testes e demos `--demo-m2/m4/m6/m7` continuam passando. A suíte leva ~2 min (rodar via Bash com timeout longo).

## Review Focus

1. **Limite perdido ou duplicado:** ação perdida, fuga, Game Over/restore e ida e volta do save. → Tasks 1 e 3.
2. **Suporte vira combatente de verdade:** não pode ser alvo de inimigo, entrar na fila, receber XP nem contar para vitória/derrota. → Task 3.
3. **Metas de balanceamento depois do Limite.** → Task 2.

---

### Task 1: Limite no núcleo (Sonnet)
**Files:**
- `core/hero_state.gd` (`limit`, snapshot/restore, to/from_dict) e `core/combatant.gd`.
- O ponto onde o dano é aplicado, mais a volta dos valores ao `HeroState`.
- `core/defs/character_def.gd` (`limit_ability`) e `core/defs/balance_config.gd` (`limit_fill_mult`, `support_cost`).
- `core/selection_session.gd` (`choose_limit()`), `core/battle_controller.gd` (zera e devolve o Limite).
- `data/test/abilities/limite_*.tres` e os heróis A–E.
- Testes: `tests/test_limit.gd`.

- Testes: enchimento proporcional e clamp; caído não enche; veneno enche; persiste depois da batalha; snapshot/restore e save; `choose_limit` só com a barra cheia; zera ao começar; ação perdida devolve.
- Commit `feat(core): barra de Limite`.

### Task 2: Limite na interface e no simulador (Sonnet)
**Files:**
- `battle/command_menu.gd` ("Limite" no lugar de "Atacar"), HUD da batalha (barra), `ui/field_menu/party_panel.gd` e `status_page.gd`.
- `tools/sim/sim_policy.gd` (smart usa o Limite).
- `docs/balance/2026-10-19-relatorio-final.md`: regerar com `-Final` e anotar o efeito do Limite.
- Testes de UI: `tests/test_limit_ui.gd`.

- Testes: o menu troca o comando com a barra cheia; a memória do cursor continua funcionando; a política smart usa o Limite.
- Rodar as metas; se quebrarem, ajustar como na decisão 5.
- Commit `feat(battle): comando Limite e barras`.

### Task 3: Suporte (Sonnet)
**Files:**
- `core/pending_action.gd` (`caller`), `core/selection_session.gd` (`choose_support(hero_state)`, ações disponíveis com o AP do reserva), `core/battle_controller.gd`/`action_executor.gd`/`contribution_ledger.gd` (execução, custos, crédito, reembolso).
- `core/battle_state.gd` (acesso à reserva: `reserve: Array[HeroState]` passado no início).
- `battle/command_menu.gd` (submenus Suporte → herói → ação → alvo) e `battle/battle_scene.gd` (visual do reserva, `start_with` recebe a reserva).
- `world/local_map.gd` (passa `state.reserve`), `world/battle_arena.gd` (`SupportSpot` opcional).
- `world/demo_m8.gd` (`--demo-m8`: herói sofre dano até encher, usa Limite, enche de novo e chama o Suporte).
- Testes: `tests/test_support.gd`.

- Testes: comando habilitado e desabilitado (Limite < 0.5, reserva vazia ou caída); custos; o ATB de quem chamou zera; o suporte não é alvo e não entra na fila; sem XP para o reserva e crédito para quem chamou; reembolso em Ativo; o AP do reserva persiste.
- Verificação visual: `--write-movie` da `--demo-m8`, alguns quadros.
- Commit `feat(battle): suporte da reserva`.

### Task 4: Documentação (Haiku)
- README (Limite, Suporte, `--demo-m8`), roadmap (M8 e M8.5 concluídos), `data/test/README.md` (golpes de Limite).
- Commit `docs: M8 Limite e M8.5 Suporte`.

# M5b — Fórmulas escolhidas e rebalanceamento: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** As fórmulas aprovadas pelo usuário viram o comportamento do jogo, e o conteúdo de teste é rebalanceado com o simulador até bater as metas.

**Escolhas do usuário (2026-10-19) [U]:** F1 **B** (faixas Souls) · F2 **B** (HP estilo FF) · F3 **B** (AP com nível) · F4 **A** (ATB linear) · F5 **B** (dano por razão) · F6 **B** (±6%) · F7 **B** (esquiva relativa) · F8 **C** (XP quadrática + linear) · F9 **99** (nível máximo) · F10 **A** (Reviver 25%) · F11 **B** (Veneno % do HP) · F12 **A** (durações dos dados).

**Architecture:** Os enums de modo do M5a **continuam no código** (o simulador segue podendo comparar opções em rebalanceamentos futuros). Muda o **padrão**: `BalanceConfig` passa a ter as escolhas como valores iniciais, e o `game/data/test/balance.tres` também. Os testes de unidade de mecânica continuam usando a fórmula A explicitamente via `Fixtures.cfg()` (eles testam regras, não balanceamento).

**Spec:** [`.claude/specs/2026-10-19-m5-formulas-design.md`](../specs/2026-10-19-m5-formulas-design.md) §4–§5; relatório [`docs/balance/2026-10-19-relatorio-opcoes.md`](../../docs/balance/2026-10-19-relatorio-opcoes.md).

## Global Constraints

- Restrições do M1–M5a (tipos estáticos, núcleo sem `Node`, `Dice`, números no `BalanceConfig`, inglês no código e português na UI, nunca `Get-Content`/`Set-Content` em arquivos acentuados).
- `Fixtures.cfg()` pode ganhar **apenas** linhas que fixam os modos em A (e `max_level = 0`); nenhuma outra alteração de teste existente sem justificativa numérica no relatório.
- Metas (spec §4): batalha comum 30–60 s com `smart` e vitória ≥ 90%; `basic` com vitória 40–70%. Avaliadas nos encontros de teste com o grupo no nível "esperado" para o encontro.
- **Modelos:** Sonnet para implementação e revisões; Haiku para documentação; Opus só no planejamento do controlador.

## Review Focus

1. **Jogo com fórmulas antigas por engano**: `balance.tres` sem os modos novos ou um caminho que cria `BalanceConfig.new()` no jogo sem ler o `.tres`. → Task 1 `test_game_uses_chosen_modes`.
2. **Testes de mecânica afetados pelo padrão novo**: todo teste de unidade continua determinístico com A via `Fixtures`. → suíte inteira.
3. **Rebalanceamento só no simulador**: os números novos estão nos `.tres` que o jogo carrega, não só no cenário do relatório. → Task 2 `test_content_meets_targets` (versão curta do simulador).
4. **Nível máximo 99** com XP em excesso. → já coberto pelo M5a; Task 1 confirma no padrão.

---

### Task 1: Fórmulas escolhidas como padrão (Sonnet)

**Files:** `game/core/defs/balance_config.gd` (valores iniciais dos modos e `max_level = 99`), `game/data/test/balance.tres` (mesmos modos explícitos), `game/tests/fixtures.gd` (fixa modos A e `max_level = 0`), testes de cena que quebrarem por números do conteúdo real (corrigir com a conta), `game/tests/test_chosen_formulas.gd` (novo).

- [ ] Teste novo: `test_game_uses_chosen_modes` (carrega `res://data/test/balance.tres` e confere cada modo), `test_balance_config_defaults_are_chosen`, `test_fixtures_pin_mode_a`.
- [ ] RED → aplicar → suíte inteira. Para cada teste existente que quebrar, decidir: (a) teste de mecânica com cfg próprio → deve passar com `Fixtures` em A (se não, investigar); (b) teste de cena/conteúdo com números → atualizar o número com a conta da fórmula nova, listado no relatório.
- [ ] Demos (`--demo-m2/m3/m4`, `--demo-result`): continuam terminando (rodar cada uma headless com `--quit-after` e conferir que chegam ao fim; ajustar o enfraquecimento dos inimigos do demo se necessário).
- [ ] Commit `feat(core): formulas escolhidas como padrao do jogo`.

### Task 2: Rebalancear o conteúdo de teste com o simulador (Sonnet)

**Files:** `game/data/test/enemies/*.tres`, se necessário `game/data/test/items/*.tres` e coeficientes B/C escolhidos no `BalanceConfig`/`balance.tres`; `game/tools/sim/report.gd` (cenário-meta); `game/tests/test_content_balance.gd` (novo); `docs/balance/2026-10-19-relatorio-final.md` (gerado).

- [ ] Definir os **cenários-meta**: encontro X+Y com o grupo A–D no nível 1 e no nível 5; encontro X+Y+Z no nível 5 e no nível 10 (o mais forte vira o "encontro de nível alto"). Política `smart` e `basic`.
- [ ] Ajustar, nesta ordem e só o necessário: (1) atributos e `xp_base` dos inimigos; (2) coeficientes das fórmulas escolhidas (`hp_*`, `ap_*`, `dmg_ratio_k`, `poison_pct`, `xp_coef_c`/`xp_linear_c`); (3) itens. Registrar cada mudança e o motivo no relatório da task.
- [ ] Meta por cenário: `smart` 30–60 s e vitória ≥ 90%; `basic` vitória 40–70%. Se um cenário não puder bater as duas metas ao mesmo tempo, priorizar a de `smart` e registrar.
- [ ] `test_content_meets_targets`: roda o simulador com poucas execuções (ex.: 10) nos cenários-meta e confere as faixas com margem (smart ≥ 80% e 25–75 s; basic 25–85%) — rápido o bastante para a suíte.
- [ ] Gerar `docs/balance/2026-10-19-relatorio-final.md` (padrão novo nos cenários-meta + tabela "antes × depois" do conteúdo).
- [ ] Commit `feat(data): rebalanceia conteudo de teste para as formulas escolhidas`.

### Task 3: Documentação das fórmulas (Haiku)

**Files:** `.claude/specs/2026-10-19-m5-formulas-design.md` (seção "Decisões do M5b": escolhas [U], fórmulas finais escritas por extenso com os coeficientes, decisão de manter os enums [I]), `.claude/specs/2026-10-18-rpg-design.md` (marcar no catálogo de fórmulas pendentes quais foram decididas no M5, com link), `docs/roadmap.md` (M5 concluído), `README.md` (seção curta "Fórmulas e balanceamento" com link para os relatórios e `run_sim.ps1`).

- [ ] Escrever; conferir cada fórmula contra o código (`stat_calculator.gd`, `effect_math.gd`, `xp_calculator.gd`, `status_system.gd`) e os valores contra `balance.tres`.
- [ ] Commit `docs: registra formulas do M5`.

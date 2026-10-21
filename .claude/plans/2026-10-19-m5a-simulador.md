# M5a — Simulador de batalhas e opções de fórmula: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Opções de fórmula F1–F12 implementadas lado a lado e selecionáveis pelo `BalanceConfig` (padrão = comportamento atual), mais um simulador headless de batalhas em lote que gera um relatório comparativo em `docs/balance/`.

**Architecture:** Cada fórmula ganha um enum de modo no `BalanceConfig` com o valor `A` como padrão. `StatCalculator`, `ActionExecutor`, `StatusSystem` e `XpCalculator` consultam o modo — sem mudar nada no modo A. O simulador vive em `game/tools/sim/` e usa o núcleo de batalha (`BattleState` + `BattleController.tick`) sem cenas, com políticas de herói que montam `SelectionSession` como a UI faria.

**Tech Stack:** Godot 4.7 (GDScript tipado), GUT 9.7.1, `./run_tests.ps1`.

**Spec:** [`.claude/specs/2026-10-19-m5-formulas-design.md`](../specs/2026-10-19-m5-formulas-design.md).

## Global Constraints

- Restrições globais do M1–M4 (tipos estáticos; `game/core/` sem `Node`/`Input`; aleatoriedade via `Dice`; números em `BalanceConfig`; inglês no código, português em texto ao usuário; nada de `Get-Content`/`Set-Content` em arquivos acentuados).
- **Padrão intocado:** com todos os modos em `A`, o jogo se comporta exatamente como hoje — **os 326 testes passam sem nenhuma alteração** em toda task. Nenhum teste existente pode ser editado neste plano.
- Todo coeficiente novo é um campo do `BalanceConfig` com comentário "valor de teste".
- Simulação determinística: mesma semente → mesmas métricas.
- **Modelos (preferência do usuário):** tarefas mecânicas → Haiku; implementação e revisões de tarefa → Sonnet; Opus só na revisão final.

## Review Focus

1. **Modo A diferente de hoje**: qualquer mudança de número com os padrões. → cada task roda a suíte inteira sem editar testes; Task 1 adiciona `test_default_modes_are_a`.
2. **Variação de dano quebrando determinismo**: a variação usa o `Dice` da batalha, nunca `randf()`. → Task 3 `test_variance_deterministic_with_seed`.
3. **Política `smart` travando** (sem alvo válido, sem AP): sempre cai no ataque básico. → Task 5 `test_smart_policy_always_submits`.
4. **Simulação infinita** (ninguém causa dano): limite de tempo por batalha (`sim_max_seconds`), conta como "tempo esgotado" nas métricas. → Task 5 `test_timeout_is_reported`.
5. **Divisão por zero** em fórmulas de razão (F4 B, F5 B, F1 C) com atributos 0. → testes de borda em cada task.

---

### Task 1: Infraestrutura de modos + F1 (retornos decrescentes), F2 (HP), F3 (AP)

**Files:** Modify `game/core/defs/balance_config.gd`, `game/core/stat_calculator.gd`. Create `game/tests/test_formula_modes_stats.gd`.

**Interfaces (Produces):**
- `BalanceConfig`: `enum DrMode { A, B, C }` `dr_mode = A`; `dr_band2_start: int = 20`, `dr_band3_start: int = 40`, `dr_band2_factor: float = 0.5`, `dr_band3_factor: float = 0.25` (B); `dr_smooth_limit: float = 60.0`, `dr_smooth_k: float = 30.0` (C). `enum HpMode { A, B, C }` com `hp_base: int = 30`, `hp_vit_a: int = 8`, `hp_lvl_b: int = 4`, `hp_vit_lvl_c: float = 0.4` (B), `hp_c_level_mult: float = 0.08` (C). `enum ApMode { A, B, C }` com `ap_aura_a: int = 4`, `ap_lvl_b: int = 1` (B), `ap_c_level_mult: float = 0.05` (C).
- `StatCalculator.diminishing`, `hp_max`, `ap_max` respeitam os modos (A = fórmula atual, byte a byte).

**Steps:** testes primeiro (casos numéricos por modo, bordas 0 e valores grandes, `test_default_modes_are_a`) → RED → implementar → suíte inteira GREEN sem editar testes → commit `feat(core): modos de formula para atributos, HP e AP`.

---

### Task 2: F4 (Velocidade → ATB) e F7 (esquiva)

**Files:** Modify `balance_config.gd`, `stat_calculator.gd`, `game/core/atb_clock.gd`, `game/core/action_executor.gd` (só a chamada da esquiva). Create `game/tests/test_formula_modes_speed.gd`.

**Interfaces:**
- `enum AtbMode { A, B, C }`: B = `atb_base_rate × (Vel_ef + 1) / (média de Vel_ef dos combatentes vivos + 1)`; C = `1 / (atb_turn_time × atb_c_r / (atb_c_r + Vel_ef))`. Coeficientes `atb_turn_time: float = 4.0`, `atb_c_r: float = 20.0`.
- `StatCalculator.atb_rate(c, cfg, field_avg_speed: float = -1.0)` — o terceiro parâmetro só é usado no modo B (AtbClock calcula a média uma vez por `advance` e passa). Pressa/Lentidão e `atb_min_rate` continuam valendo em todos os modos.
- `enum DodgeMode { A, B, C }`: B = `clamp((Vel_alvo − Vel_atacante) × dodge_per_speed, 0, dodge_cap)`; C = 0 (só passivos/estados futuros). `StatCalculator.dodge_chance(target, cfg, attacker: Combatant = null)`; `ActionExecutor` passa o atacante.

**Steps:** testes (cada modo; média com 1 combatente; Vel 0) → RED → implementar → GREEN sem editar testes → commit `feat(core): modos de formula para ATB e esquiva`.

---

### Task 3: F5 (dano) e F6 (variação)

**Files:** Modify `balance_config.gd`, `game/core/effect_math.gd`, `action_executor.gd`. Create `game/tests/test_formula_modes_damage.gd`.

**Interfaces:**
- `enum DamageMode { A, B, C }`: A atual; B = `floor(pot×Atr × dmg_ratio_k / (dmg_ratio_k + defesa))` com `defesa = Vit_ef × defense_per_vitality` e `dmg_ratio_k: float = 20.0`; C = `pot×Atr − (Vit_ef × defense_per_vitality + soma de Vitalidade dos modificadores de equipamento × dmg_c_equip_factor)` com `dmg_c_equip_factor: float = 1.0`. Mínimo 1 em todos.
- `enum VarianceMode { A, B, C }`: A nenhuma; B ±`variance_b = 0.06`; C ±`variance_c = 0.12`; fator = `1 + (roll × 2 − 1) × amplitude` com o `Dice` da batalha, aplicado antes do mínimo 1; só em DAMAGE (não em cura).
- A conta fica em `EffectMath.damage(...)` (fonte única); `ActionExecutor` só chama.

**Steps:** testes (cada modo com números; defesa 0; `test_variance_deterministic_with_seed`; variação não consome `Dice` no modo A) → RED → implementar → GREEN sem editar testes → commit `feat(core): modos de formula para dano e variacao`.

---

### Task 4: F8–F12 (XP, nível máximo, reviver, veneno, durações)

**Files:** Modify `balance_config.gd`, `xp_calculator.gd`, `effect_math.gd`, `status_system.gd`. Create `game/tests/test_formula_modes_progress.gd`.

**Interfaces:**
- `enum XpMode { A, B, C }`: A `xp_coef×(n−1)²`; B igual com `xp_coef_b: int = 25`; C `xp_coef_c×(n−1)² + xp_linear_c×(n−1)` (`xp_coef_c = 15`, `xp_linear_c = 30`).
- `max_level: int = 0` (0 = sem limite; opções do relatório 50 e 99). `grant` para em `max_level` e descarta o excesso de XP.
- `enum ReviveMode { A, B, C }`: A potência do efeito (25% nos dados); B 50% fixo (`revive_b = 0.5`); C `revive_c_flat: int = 10` + 10%.
- `enum PoisonMode { A, B, C }`: A potência fixa atual; B `floor(hp_max × poison_pct = 0.06)`; C fixo + %.
- `enum DurationMode { A, B }`: A durações dos dados; B `duration_by_strength: Dictionary[StringName, int]` por id (fraco/médio/forte mapeados nos dados de teste). (C — escalar com Aura — fica para o M5b se você pedir.)

**Steps:** testes por modo + bordas (nível máximo com XP de sobra; veneno em HP baixo) → RED → implementar → GREEN sem editar testes → commit `feat(core): modos de formula para progressao e estados`.

---

### Task 5: Núcleo do simulador e políticas

**Files:** Create `game/tools/sim/sim_scenario.gd`, `sim_policy.gd`, `sim_runner.gd`, `sim_metrics.gd`, `game/tests/test_sim.gd`.

**Interfaces:**
- `SimScenario extends RefCounted`: `heroes: Array[CharacterDef]`, `hero_level: int`, `alloc_rule: StringName` (`&"even"` distribui pontos igualmente, `&"main"` tudo no atributo principal do herói = maior base), `equipment: bool` (usa o equipamento inicial), `enemies: Array[EnemyDef]`, `cfg: BalanceConfig`, `policy: StringName` (`&"basic"`, `&"smart"`), `runs: int`, `seed: int`, `items: Array[ItemDef]`, `item_counts: Array[int]`.
- `SimPolicy` (static): `decide(session: SelectionSession, b: BattleState, policy: StringName) -> PendingAction` — `basic`: ataque básico no inimigo vivo de menor HP; `smart`: regras do design §3, sempre caindo no básico se nada mais for possível.
- `SimRunner` (static): `run(s: SimScenario) -> SimMetrics` — para cada execução cria heróis (`HeroState.create` + níveis/alocação), `BattleState`, `BattleController`, e chama `tick(cfg.sim_tick)` até `battle_ended` ou `sim_max_seconds` (campos novos no `BalanceConfig`: `sim_tick = 0.1`, `sim_max_seconds = 600.0`); quando `hero_turn` dispara, responde com `SimPolicy.decide` + `submit`.
- `SimMetrics`: campos do design §3 (vitórias, derrotas, tempos esgotados, durações, ações, dano por ação por tipo, TTK por inimigo, HP restante %, AP gasto, XP por herói, estados aplicados/resistidos) e `to_markdown_row() -> String`.

**Steps:** testes (cenário pequeno determinístico com `Fixtures`; mesma semente → mesmas métricas; `test_smart_policy_always_submits`; `test_timeout_is_reported`) → RED → implementar → GREEN → commit `feat(tools): nucleo do simulador de batalhas`.

---

### Task 6: Execução por linha de comando e relatório

**Files:** Create `game/tools/sim/run_sim.gd` (SceneTree script), `game/tools/sim/report.gd`, `run_sim.ps1` (raiz), `docs/balance/README.md`, `docs/balance/2026-10-19-relatorio-opcoes.md` (gerado).

**Interfaces:**
- `run_sim.ps1 [-Runs N] [-Out path]` acha o Godot como o `run_tests.ps1` e roda `--headless --path game -s tools/sim/run_sim.gd`.
- `report.gd` monta, para cada fórmula F1–F12, uma tabela com as opções (A/B/C) × cenários (grupo nível 1, 5, 10 × encontro X+Y e X+Y+Z × políticas `basic`/`smart`), variando **uma fórmula por vez** sobre o padrão A, mais uma linha "metas" do design §4. Escreve Markdown e CSV.
- `docs/balance/README.md`: como rodar e ler o relatório.

**Steps:** teste curto de `report.gd` (gera Markdown com cabeçalho e uma linha por opção para um cenário mínimo) → RED → implementar → GREEN → rodar `./run_sim.ps1` de verdade (≤ 10 min) e commitar o relatório gerado → commit `feat(tools): relatorio comparativo de formulas`.

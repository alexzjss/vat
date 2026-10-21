# M1 — Batalha isolada: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Uma batalha ATB jogável no Godot 4, com placeholders geométricos, cujo núcleo de regras implementa e testa a spec v4.0 (ATB, Wait, fila, Aura, itens, estados, geometria, contribuição e XP).

**Architecture:** Núcleo de regras em GDScript tipado (`game/core/`, só `RefCounted`/`Resource`, sem nós visuais), dirigido por `BattleController.tick(delta)` para que tudo seja determinístico e testável com GUT. A apresentação (`game/battle/`) apenas lê `BattleState`, escuta sinais do controller e envia comandos via `SelectionSession`.

**Tech Stack:** Godot 4 (≥ 4.4, estável mais recente), GDScript com tipagem estática, GUT 9.x para testes, PowerShell para o script de testes.

**Spec:** [`.claude/specs/2026-10-18-rpg-design.md`](../specs/2026-10-18-rpg-design.md) (v4.0), que referencia [`docs/historico/guia_continuidade_v3.7.md`](../../docs/historico/guia_continuidade_v3.7.md). Leia as seções 4–8 e 10 da spec antes de começar.

## Global Constraints

- Godot ≥ 4.4 (Dictionary tipado). GDScript com **tipos estáticos em toda declaração**; o projeto configura `untyped_declaration` como erro.
- `game/core/` não pode referenciar `Node`, cenas, `Input` nem `get_tree()`. Aleatoriedade sempre via `Dice` injetado.
- Identificadores de código em **inglês**; textos de UI em **português**. Glossário: Força=`strength`, Velocidade=`speed`, Vitalidade=`vitality`, Aura (atributo)=`aura`, pontos de Aura=`ap`/`ap_max`, contribuição=`contribution`, estado=`status`.
- Todo número de balanceamento vem de `BalanceConfig`. O arquivo e a classe levam o comentário `# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8)`. Nenhum número aparece literal fora dele, exceto em testes.
- Testes **sempre** constroem seu próprio `BalanceConfig` com valores explícitos (não dependem dos defaults).
- Personagens e inimigos do M1 são genéricos: "Teste A/B/C", "Inimigo X/Y/Z". Nenhum nome, fala ou dado narrativo.
- Fora do M1: mapas, overworld, lojas, diálogo, save/load, arte, áudio, Techs, fuga, comando Suporte.

## Decisões deste plano (não estão na spec — marcadas [P-plano])

O executor deve implementá-las como descritas e o usuário pode revisá-las depois; elas também vão para a seção 12 da spec na Task 16.

1. **Ordem da fila:** Velocidade efetiva desc → `entry_tick` asc (quem ficou pronto antes) → `tie_key` asc (sorteado uma vez na entrada). Empates "juntos" = mesmo `entry_tick`.
2. **Incapacitação:** ao chegar a 0 HP, remove todos os estados, zera o ATB, sai da fila. Ao ser revivido, ATB começa em 0.
3. **Ordem em `on_atb_full`:** (a) dano de Veneno; (b) se ainda de pé, verifica bloqueio (Sono/Paralisia); (c) decrementa a duração de todos os estados e remove os expirados; (d) se bloqueado → perde a oportunidade e o ATB volta a 0; senão entra na fila.
4. **Contribuição de benefício a aliado** (cura, buff, barreira aplicada): distribuída entre os inimigos proporcionalmente ao dano que **aquele aliado** recebeu de cada inimigo nesta batalha; se ele não recebeu dano, dividida igualmente entre os inimigos vivos. Proteção absorvida por Barreira é creditada ao inimigo atacante (sem distribuição).
5. **Controle:** cada oportunidade perdida por bloqueio credita `control_value_per_turn` ao aplicador do **primeiro** estado bloqueador ativo (nunca duplica).
6. **Renovação:** reaplicar estado ativo com `remaining = r` e `duration = d` credita `apply_contribution × (d − r) / d`.
7. **Sono acorda** somente se o dano reduziu HP (> 0 após a Barreira).
8. **Linha:** segmento do executor até o centro escolhido, com largura `width`.
9. **Fim de batalha** é verificado quando não há ação executando: todos os inimigos caídos → vitória; todos os heróis caídos → derrota.

## Review Focus

1. **Combatente cai enquanto está na fila** (Veneno ou golpe): deve sair da fila e o menu nunca pode abrir para um herói caído. → teste na Task 10 (`test_downed_hero_in_queue_never_gets_menu`).
2. **Batalha termina com gente na fila**: o último inimigo cai durante uma ação; nenhuma ação seguinte começa e `battle_ended` dispara uma vez. → Task 10 (`test_battle_ends_once_with_ready_queue_nonempty`).
3. **Debuffs levando atributos a zero/negativo**: atributo efetivo ≥ 0, taxa de ATB ≥ `atb_min_rate` (sem soft-lock com Lentidão), dano ≥ 1. → Task 2 (`test_effective_never_negative_and_atb_has_floor`).
4. **Cura/revive em alvos errados**: cura não alveja caído e não passa do HP máximo (contribuição = só o restaurado); reviver só alveja caído. → Task 6 (`test_downed_not_targetable_except_revive`) e Task 7 (`test_heal_clamped_and_credits_only_restored`).
5. **Item esgotado**: item com quantidade disponível 0 (contando reservas) não pode ser selecionado e some/fica desabilitado no menu. → Task 8 (`test_cannot_select_item_out_of_stock`).

---

## Mapa de arquivos

```
run_tests.ps1                     roda GUT headless
game/project.godot
game/addons/gut/                  GUT vendorizado
game/core/defs/                   Resources de definição
  stats.gd balance_config.gd effect_def.gd status_def.gd ability_def.gd
  item_def.gd equipment_def.gd ai_rule.gd character_def.gd enemy_def.gd
game/core/
  dice.gd hero_state.gd combatant.gd stat_calculator.gd
  contribution_ledger.gd active_status.gd status_system.gd
  ready_queue.gd atb_clock.gd targeting.gd
  pending_action.gd action_result.gd action_executor.gd
  inventory.gd selection_session.gd enemy_ai.gd
  battle_state.gd battle_controller.gd xp_calculator.gd
game/tests/
  scripted_dice.gd fixtures.gd test_*.gd
game/data/test/                   .tres do conteúdo genérico do M1
game/battle/
  battle_scene.tscn/.gd combatant_view.tscn/.gd command_menu.gd
  target_preview.gd debug_panel.gd result_screen.gd level_up_screen.gd
```

---

### Task 0: Ambiente, projeto Godot e GUT

**Files:**
- Create: `.gitignore`, `run_tests.ps1`, `game/project.godot`, `game/addons/gut/**`, `game/tests/test_smoke.gd`

**Interfaces:**
- Produces: comando `./run_tests.ps1` (opcional `-Filter <nome_do_arquivo_de_teste>`) que sai com código 0 se todos os testes passarem.

- [ ] **Step 1: Instalar o Godot 4**

Run: `winget install --id GodotEngine.GodotEngine -e`
Depois localize o executável (`Get-Command godot*` ou a pasta do winget) e defina a variável de ambiente de usuário `GODOT` com o caminho completo do `.exe` de console (`*_console.exe`).
Expected: `& $env:GODOT --version` imprime `4.x.stable...` com x ≥ 4.

- [ ] **Step 2: Criar o projeto em `game/`**

Crie `game/project.godot` (pelo editor: Novo projeto → pasta `game`, renderer Compatibility). Em Configurações do Projeto: `debug/gdscript/warnings/untyped_declaration = Error`, `display/window/size/viewport_width = 1280`, `viewport_height = 720`.

- [ ] **Step 3: Vendorizar o GUT**

Baixe a release 9.x do GUT compatível com a versão instalada (github.com/bitwes/Gut, releases) e copie apenas `addons/gut` para `game/addons/gut`. Habilite o plugin em Projeto → Plugins.

- [ ] **Step 4: `.gitignore` e `run_tests.ps1`**

`.gitignore`: `game/.godot/`, `*.import` não (Godot 4 precisa dos `.import`; ignore só `.godot/`), `*.tmp`.
`run_tests.ps1`: executa
`& $env:GODOT --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (com `-gselect=$Filter` quando informado) e repassa `$LASTEXITCODE`.

- [ ] **Step 5: Teste de fumaça**

```gdscript
# game/tests/test_smoke.gd
extends GutTest
func test_gut_runs() -> void:
	assert_eq(1 + 1, 2)
```

Run: `./run_tests.ps1`
Expected: `1 passed`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add .gitignore run_tests.ps1 game
git commit -m "chore: projeto Godot com GUT e script de testes"
```

---

### Task 1: Definições (Resources), `Dice` e fixtures de teste

**Files:**
- Create: `game/core/defs/*.gd`, `game/core/dice.gd`, `game/tests/scripted_dice.gd`, `game/tests/fixtures.gd`, `game/tests/test_defs.gd`

**Interfaces:**
- Produces (todos com `class_name`, `extends Resource`, campos `@export`):
  - `Stats`: `strength: int`, `speed: int`, `vitality: int`, `aura: int`; `func get_attr(name: StringName) -> int`; `func plus(o: Stats) -> Stats`; `static func make(str: int, spd: int, vit: int, aur: int) -> Stats`. `const ATTRS: Array[StringName] = [&"strength", &"speed", &"vitality", &"aura"]`.
  - `BalanceConfig` (comentário de valores de teste), defaults: `hp_per_vitality: int = 10`, `hp_per_level: int = 5`, `ap_per_aura: int = 5`, `atb_base_rate: float = 0.2`, `atb_rate_per_speed: float = 0.02`, `atb_min_rate: float = 0.05`, `dodge_per_speed: float = 0.005`, `dodge_cap: float = 0.15`, `dr_soft_cap: int = 20`, `dr_factor: float = 0.5`, `defense_per_vitality: float = 0.5`, `xp_coef: int = 10`, `control_value_per_turn: int = 10`, `item_cast_time: float = 0.6`, `item_impact_time: float = 0.3`.
  - `EffectDef`: `enum Kind { DAMAGE, HEAL, REVIVE, RESTORE_AP, APPLY_STATUS, REMOVE_STATUS }`; `kind: Kind`; `enum Scale { STRENGTH, AURA, FIXED }`; `scale: Scale`; `potency: float`; `status: StatusDef`; `chance: float = 1.0`; `dodgeable: bool = false`.
  - `StatusDef`: `id: StringName`; `enum Kind { POISON, SLEEP, PARALYSIS, HASTE, SLOW, BARRIER, ATTR_MOD }`; `kind: Kind`; `duration: int` (turnos do afetado); `potency: int` (Veneno: dano por turno; Barreira: pontos; HASTE/SLOW: % de taxa; ATTR_MOD: soma no atributo); `attr: StringName` (só ATTR_MOD); `apply_contribution: int`; `cancels: Array[StringName]` (ids removidos ao aplicar este).
  - `AbilityDef`: `id`, `display_name: String`, `ap_cost: int`, `enum Shape { SINGLE, GROUP, ALL, CIRCLE_TARGET, CIRCLE_SELF, LINE }`, `shape: Shape`, `enum Side { ENEMIES, ALLIES, BOTH }`, `side: Side`, `radius: float`, `width: float`, `cast_time: float`, `impact_time: float`, `effects: Array[EffectDef]`.
  - `ItemDef`: `id`, `display_name: String`, `shape: AbilityDef.Shape`, `side: AbilityDef.Side`, `effects: Array[EffectDef]`.
  - `EquipmentDef`: `id`, `slot: StringName`, `modifiers: Stats`.
  - `AiRule`: `enum Condition { ALWAYS, ALLY_HP_BELOW }`, `condition`, `threshold: float` (fração do HP máx.), `ability: AbilityDef`, `enum TargetPick { LOWEST_HP_ENEMY, RANDOM_ENEMY, LOWEST_HP_ALLY, SELF }`, `pick`.
  - `CharacterDef`: `id`, `display_name: String`, `base: Stats`, `basic_attack: AbilityDef`, `abilities: Array[AbilityDef]`.
  - `EnemyDef`: `id`, `display_name`, `level: int`, `base: Stats`, `xp_base: int`, `abilities: Array[AbilityDef]`, `ai_rules: Array[AiRule]`, `immunities: Array[StringName]`, `resistances: Dictionary[StringName, float]` (0..1 = redução da chance).
  - `Dice extends RefCounted`: `func roll() -> float` (0..1), `func pick_index(n: int) -> int`; construtor com seed opcional.
  - `ScriptedDice extends Dice` (tests): `func _init(values: Array[float])`; `roll()` devolve os valores em sequência e depois `0.99`; `pick_index` usa `roll()`.
  - `Fixtures` (tests, `class_name Fixtures`, só funções estáticas): `cfg() -> BalanceConfig` (os defaults acima, explícitos), `hit(potency: float, shape := AbilityDef.Shape.SINGLE) -> AbilityDef` (dano por Força, custo 0, `cast_time 1.0`, `impact_time 0.5`), `status_def(kind: StatusDef.Kind, duration: int, potency := 0) -> StatusDef`, `hero_def(id: StringName, stats: Stats) -> CharacterDef`, `enemy_def(id: StringName, stats: Stats, xp_base := 100) -> EnemyDef` (level 1, `basic_attack`-equivalente = primeira habilidade `hit(1.0)`). `hit` tem `dodgeable = false`.

- [ ] **Step 1: Teste**

```gdscript
# game/tests/test_defs.gd
extends GutTest
func test_stats_plus_and_get_attr() -> void:
	var s := Stats.make(1, 2, 3, 4).plus(Stats.make(10, 0, 0, -1))
	assert_eq(s.get_attr(&"strength"), 11)
	assert_eq(s.get_attr(&"aura"), 3)
func test_scripted_dice_sequence() -> void:
	var d := ScriptedDice.new([0.1, 0.7])
	assert_eq(d.roll(), 0.1)
	assert_eq(d.roll(), 0.7)
	assert_eq(d.roll(), 0.99)
```

- [ ] **Step 2:** `./run_tests.ps1 -Filter test_defs` → FAIL (classes inexistentes).
- [ ] **Step 3:** Implementar os arquivos listados em Interfaces.
- [ ] **Step 4:** `./run_tests.ps1` → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(core): definicoes de dados, Dice e fixtures"`

---

### Task 2: `HeroState`, `Combatant` e `StatCalculator`

**Files:**
- Create: `game/core/hero_state.gd`, `game/core/active_status.gd`, `game/core/combatant.gd`, `game/core/stat_calculator.gd`, `game/tests/test_stat_calculator.gd`

**Interfaces:**
- Produces:
  - `HeroState extends RefCounted`: `def: CharacterDef`, `level: int = 1`, `xp: int = 0`, `allocated: Stats`, `pending_points: int = 0`, `equipment: Dictionary[StringName, EquipmentDef]`, `hp: int`, `ap: int` (persistem entre batalhas). `static func create(def: CharacterDef, cfg: BalanceConfig) -> HeroState` (HP e AP cheios).
  - `Combatant extends RefCounted`: `enum Team { HERO, ENEMY }`; `id: StringName`, `team: Team`, `display_name: String`, `level: int`, `base: Stats`, `allocated: Stats`, `equipment_mods: Stats`, `hp: int`, `ap: int`, `atb: float` (0..1), `position: Vector2`, `statuses: Array[ActiveStatus]`, `abilities: Array[AbilityDef]`, `basic_attack: AbilityDef`, `hero_state: HeroState` (null p/ inimigo), `enemy_def: EnemyDef` (null p/ herói), `damage_taken_from: Dictionary[StringName, int]`. `func is_down() -> bool` (`hp <= 0`). `static func from_hero(h: HeroState, pos: Vector2) -> Combatant`, `static func from_enemy(d: EnemyDef, id: StringName, pos: Vector2, cfg: BalanceConfig) -> Combatant`.
  - `ActiveStatus extends RefCounted`: `def: StatusDef`, `remaining: int`, `source_id: StringName`, `barrier_left: int` (inicia em `def.potency` para BARRIER), `applied_order: int`.
  - `StatCalculator` (só `static`): `diminishing(raw: int, cfg) -> int`; `effective(c: Combatant, attr: StringName, cfg) -> int`; `hp_max(c, cfg) -> int`; `ap_max(c, cfg) -> int`; `atb_rate(c, cfg) -> float`; `dodge_chance(c, cfg) -> float`.

Fórmulas de teste (spec §5.2 + §8):
```
diminishing(raw) = raw se raw <= dr_soft_cap; senão dr_soft_cap + floor((raw - dr_soft_cap) * dr_factor)
effective = max(0, diminishing(base + allocated + equipment_mods) + soma dos ATTR_MOD ativos daquele attr)
hp_max = effective(vitality) * hp_per_vitality + level * hp_per_level
ap_max = effective(aura) * ap_per_aura
atb_rate = max(atb_min_rate, (atb_base_rate + effective(speed) * atb_rate_per_speed) * Π(1 + p/100 dos HASTE) * Π(1 - p/100 dos SLOW))
dodge_chance = min(dodge_cap, effective(speed) * dodge_per_speed)
```
Nesta task os ATTR_MOD/HASTE/SLOW ainda não existem: `effective` e `atb_rate` iteram `c.statuses` e a Task 4 adiciona os testes desses modificadores.

- [ ] **Step 1: Testes**

```gdscript
# game/tests/test_stat_calculator.gd
extends GutTest
var cfg: BalanceConfig
func before_each() -> void:
	cfg = Fixtures.cfg()
func _c(stats: Stats, level := 1) -> Combatant:
	var h := HeroState.create(Fixtures.hero_def(&"a", stats), cfg)
	h.level = level
	return Combatant.from_hero(h, Vector2.ZERO)
func test_diminishing_returns_above_soft_cap() -> void:
	assert_eq(StatCalculator.diminishing(20, cfg), 20)
	assert_eq(StatCalculator.diminishing(30, cfg), 25)
	assert_eq(StatCalculator.diminishing(31, cfg), 25)
func test_equipment_does_not_bypass_diminishing() -> void:
	var c := _c(Stats.make(20, 0, 0, 0))
	c.equipment_mods = Stats.make(10, 0, 0, 0)
	assert_eq(StatCalculator.effective(c, &"strength", cfg), 25)
func test_derived_values() -> void:
	var c := _c(Stats.make(0, 10, 4, 6), 3)
	assert_eq(StatCalculator.hp_max(c, cfg), 55)
	assert_eq(StatCalculator.ap_max(c, cfg), 30)
	assert_almost_eq(StatCalculator.atb_rate(c, cfg), 0.4, 0.0001)
	assert_almost_eq(StatCalculator.dodge_chance(c, cfg), 0.05, 0.0001)
func test_dodge_is_capped() -> void:
	assert_almost_eq(StatCalculator.dodge_chance(_c(Stats.make(0, 99, 1, 0)), cfg), 0.15, 0.0001)
func test_effective_never_negative_and_atb_has_floor() -> void:
	var c := _c(Stats.make(0, 0, 1, 0))
	c.equipment_mods = Stats.make(-5, -50, 0, 0)
	assert_eq(StatCalculator.effective(c, &"strength", cfg), 0)
	cfg.atb_base_rate = 0.0
	assert_almost_eq(StatCalculator.atb_rate(c, cfg), cfg.atb_min_rate, 0.0001)
```

- [ ] **Step 2:** rodar → FAIL. **Step 3:** implementar. **Step 4:** rodar → PASS.
- [ ] **Step 5: Commit** — `feat(core): HeroState, Combatant e StatCalculator`

---

### Task 3: `ContributionLedger`

**Files:**
- Create: `game/core/contribution_ledger.gd`, `game/tests/test_contribution_ledger.gd`

**Interfaces:**
- Produces `ContributionLedger extends RefCounted`:
  - `func add(actor_id: StringName, enemy_id: StringName, points: float) -> void` (ignora `points <= 0`).
  - `func get_points(actor_id, enemy_id) -> float`; `func total_against(enemy_id) -> float`; `func entries() -> Dictionary` (`{enemy_id: {actor_id: float}}`, para o painel de debug).
  - `func add_ally_benefit(actor_id: StringName, ally: Combatant, points: float, living_enemies: Array[Combatant]) -> void` — regra [P-plano] 4: proporcional a `ally.damage_taken_from`; se vazio/zero, igual entre `living_enemies`; se não houver inimigos vivos, descarta.

- [ ] **Step 1: Testes**

```gdscript
extends GutTest
func _enemy(id: StringName) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1,1,1,1)), id, Vector2.ZERO, Fixtures.cfg())
func test_add_and_totals() -> void:
	var l := ContributionLedger.new()
	l.add(&"a", &"x", 30); l.add(&"b", &"x", 10); l.add(&"a", &"x", 0)
	assert_eq(l.get_points(&"a", &"x"), 30.0)
	assert_eq(l.total_against(&"x"), 40.0)
func test_ally_benefit_proportional_to_damage_taken() -> void:
	var l := ContributionLedger.new()
	var x := _enemy(&"x"); var y := _enemy(&"y")
	var ally := _enemy(&"ally")
	ally.damage_taken_from = {&"x": 30, &"y": 10}
	l.add_ally_benefit(&"healer", ally, 20, [x, y])
	assert_eq(l.get_points(&"healer", &"x"), 15.0)
	assert_eq(l.get_points(&"healer", &"y"), 5.0)
func test_ally_benefit_split_evenly_without_damage_taken() -> void:
	var l := ContributionLedger.new()
	var ally := _enemy(&"ally")
	l.add_ally_benefit(&"healer", ally, 20, [_enemy(&"x"), _enemy(&"y")])
	assert_eq(l.get_points(&"healer", &"x"), 10.0)
	assert_eq(l.get_points(&"healer", &"y"), 10.0)
```

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Commit** — `feat(core): ledger de contribuicao`

---

### Task 4: `ActiveStatus` e `StatusSystem`

**Files:**
- Create: `game/core/status_system.gd`, `game/tests/test_status_system.gd`
- Modify: `game/tests/test_stat_calculator.gd` (novos testes de modificador)

**Interfaces:**
- Consumes: `Combatant`, `StatusDef`, `ContributionLedger`, `Dice`, `StatCalculator`.
- Produces:
  - `StatusSystem extends RefCounted` com `_init(cfg: BalanceConfig, ledger: ContributionLedger, dice: Dice)`:
    - `enum ApplyResult { APPLIED, RENEWED, IMMUNE, RESISTED }`
    - `func apply(target: Combatant, def: StatusDef, source: Combatant, chance: float, living_enemies: Array[Combatant]) -> ApplyResult` — imunidade (`enemy_def.immunities`) → IMMUNE; `roll() >= chance * (1 - resistência)` → RESISTED; se já ativo → renova `remaining = duration` (sem somar potência) e credita fração [P-plano] 6; senão adiciona, remove os ids de `def.cancels` e credita `apply_contribution`. Crédito: alvo inimigo → `ledger.add(source, alvo)`; alvo aliado de herói → `add_ally_benefit`; fonte inimiga não credita.
    - `func remove(target: Combatant, id: StringName) -> bool`
    - `func on_atb_full(c: Combatant, living_enemies: Array[Combatant]) -> AtbFullOutcome` — ordem [P-plano] 3. Dano de Veneno = `potency`, limitado ao HP; credita a `source_id` contra `c` se `c` é inimigo.
    - `class AtbFullOutcome`: `poison_damage: int`, `lost_turn: bool`, `expired: Array[StringName]`.
    - `func absorb_with_barrier(target: Combatant, dmg: int, attacker: Combatant) -> int` — devolve dano restante; credita o absorvido ao `source_id` da Barreira contra `attacker` (se inimigo); Barreira com `barrier_left == 0` é removida.
    - `func on_hp_damage(target: Combatant) -> void` — remove SLEEP (nunca PARALYSIS).
    - `func clear_all(c: Combatant) -> void`
    - `func is_blocked(c: Combatant) -> bool`
  - Controle [P-plano] 5: em `on_atb_full` com `lost_turn` e `c` inimigo, credita `cfg.control_value_per_turn` ao `source_id` do bloqueador com menor `applied_order`.

- [ ] **Step 1: Testes** (cobrem spec §10.3 itens 6, 7, 12, 14 e regras §6)

```gdscript
extends GutTest
var cfg: BalanceConfig; var ledger: ContributionLedger
var hero: Combatant; var foe: Combatant
func _sys(rolls: Array[float] = []) -> StatusSystem:
	return StatusSystem.new(cfg, ledger, ScriptedDice.new(rolls))
func before_each() -> void:
	cfg = Fixtures.cfg(); ledger = ContributionLedger.new()
	hero = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(5,5,5,5)), cfg), Vector2.ZERO)
	foe = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(5,5,5,5)), &"x", Vector2.ZERO, cfg)
func test_immunity_blocks_and_gives_no_contribution() -> void:
	foe.enemy_def.immunities = [&"sleep"]
	var s := Fixtures.status_def(StatusDef.Kind.SLEEP, 2); s.id = &"sleep"; s.apply_contribution = 10
	assert_eq(_sys().apply(foe, s, hero, 1.0, [foe]), StatusSystem.ApplyResult.IMMUNE)
	assert_eq(ledger.total_against(&"x"), 0.0)
func test_partial_resistance_reduces_chance() -> void:
	foe.enemy_def.resistances = {&"sleep": 0.5}
	var s := Fixtures.status_def(StatusDef.Kind.SLEEP, 2); s.id = &"sleep"
	assert_eq(_sys([0.6]).apply(foe, s, hero, 1.0, [foe]), StatusSystem.ApplyResult.RESISTED)
	assert_eq(_sys([0.4]).apply(foe, s, hero, 1.0, [foe]), StatusSystem.ApplyResult.APPLIED)
func test_reapply_renews_without_stacking_and_credits_added_fraction() -> void:
	var p := Fixtures.status_def(StatusDef.Kind.POISON, 4, 3); p.id = &"poison"; p.apply_contribution = 20
	var sys := _sys([0.0, 0.0])
	sys.apply(foe, p, hero, 1.0, [foe])
	foe.statuses[0].remaining = 1
	assert_eq(sys.apply(foe, p, hero, 1.0, [foe]), StatusSystem.ApplyResult.RENEWED)
	assert_eq(foe.statuses.size(), 1)
	assert_eq(foe.statuses[0].remaining, 4)
	assert_eq(ledger.get_points(&"a", &"x"), 20.0 + 15.0)
func test_sleep_loses_turns_then_expires_without_banked_action() -> void:
	var s := Fixtures.status_def(StatusDef.Kind.SLEEP, 2); s.id = &"sleep"
	var sys := _sys([0.0]); sys.apply(foe, s, hero, 1.0, [foe])
	assert_true(sys.on_atb_full(foe, [foe]).lost_turn)
	assert_true(sys.on_atb_full(foe, [foe]).lost_turn)
	assert_false(sys.on_atb_full(foe, [foe]).lost_turn)
	assert_eq(ledger.get_points(&"a", &"x"), 2.0 * cfg.control_value_per_turn)
func test_sleep_ends_on_hp_damage_paralysis_does_not() -> void:
	var sl := Fixtures.status_def(StatusDef.Kind.SLEEP, 3); sl.id = &"sleep"
	var pa := Fixtures.status_def(StatusDef.Kind.PARALYSIS, 3); pa.id = &"para"
	var sys := _sys([0.0, 0.0])
	sys.apply(foe, sl, hero, 1.0, [foe]); sys.apply(foe, pa, hero, 1.0, [foe])
	sys.on_hp_damage(foe)
	assert_eq(foe.statuses.map(func(a: ActiveStatus) -> StringName: return a.def.id), [&"para"])
func test_poison_ticks_on_each_atb_full_and_credits_source() -> void:
	var p := Fixtures.status_def(StatusDef.Kind.POISON, 3, 4); p.id = &"poison"
	var sys := _sys([0.0]); sys.apply(foe, p, hero, 1.0, [foe])
	var hp0 := foe.hp
	assert_eq(sys.on_atb_full(foe, [foe]).poison_damage, 4)
	sys.on_atb_full(foe, [foe])
	assert_eq(foe.hp, hp0 - 8)
	assert_eq(ledger.get_points(&"a", &"x"), 8.0)
func test_haste_cancels_slow() -> void:
	var slow := Fixtures.status_def(StatusDef.Kind.SLOW, 3, 50); slow.id = &"slow"
	var haste := Fixtures.status_def(StatusDef.Kind.HASTE, 3, 50); haste.id = &"haste"; haste.cancels = [&"slow"]
	var sys := _sys([0.0, 0.0])
	sys.apply(hero, slow, foe, 1.0, [foe]); sys.apply(hero, haste, foe, 1.0, [foe])
	assert_eq(hero.statuses.size(), 1)
	assert_eq(hero.statuses[0].def.id, &"haste")
func test_barrier_absorbs_and_credits_protection() -> void:
	var b := Fixtures.status_def(StatusDef.Kind.BARRIER, 5, 10); b.id = &"barrier"
	var sys := _sys([0.0]); sys.apply(hero, b, hero, 1.0, [foe])
	assert_eq(sys.absorb_with_barrier(hero, 14, foe), 4)
	assert_eq(hero.statuses.size(), 0)
	assert_eq(ledger.get_points(&"a", &"x"), 10.0 + b.apply_contribution)
```

Adicione em `test_stat_calculator.gd`: `test_attr_mod_after_diminishing` (força 30 + ATTR_MOD +5 → 30) e `test_slow_halves_atb_rate` (taxa 0.4 → 0.2 com SLOW 50).

- [ ] **Step 2–4:** FAIL → implementar → PASS (todos os arquivos).
- [ ] **Step 5: Commit** — `feat(core): sistema de estados`

---

### Task 5: `ReadyQueue` e `AtbClock`

**Files:**
- Create: `game/core/ready_queue.gd`, `game/core/atb_clock.gd`, `game/tests/test_atb.gd`

**Interfaces:**
- Produces:
  - `ReadyQueue extends RefCounted` `_init(cfg: BalanceConfig, dice: Dice)`: `func push(c: Combatant, tick: int) -> void` (sorteia `tie_key` uma única vez); `func pop_next() -> Combatant` (null se vazia; descarta caídos); `func peek() -> Combatant`; `func remove(c: Combatant) -> void`; `func has(c) -> bool`; `func ordered() -> Array[Combatant]` (ordem [P-plano] 1, recalculada com a Velocidade efetiva atual a cada chamada).
  - `AtbClock extends RefCounted` `_init(cfg: BalanceConfig)`: `func advance(delta: float, combatants: Array[Combatant], queue: ReadyQueue) -> Array[Combatant]` — enche `atb += atb_rate * delta` (máx. 1.0) para quem não está caído e não está na fila; devolve quem chegou a 1.0 neste passo (o chamador decide fila × turno perdido).

- [ ] **Step 1: Testes** (spec §10.3 itens 1, 10)

```gdscript
extends GutTest
var cfg: BalanceConfig
func _c(id: StringName, spd: int) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1, spd, 1, 1)), id, Vector2.ZERO, cfg)
func before_each() -> void:
	cfg = Fixtures.cfg()
func test_faster_fills_sooner() -> void:
	var fast := _c(&"f", 30); var slow := _c(&"s", 0)
	var q := ReadyQueue.new(cfg, ScriptedDice.new())
	var ready := AtbClock.new(cfg).advance(2.0, [fast, slow], q)
	assert_eq(ready, [fast])
func test_queue_orders_by_speed() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new([0.5, 0.5]))
	var a := _c(&"a", 5); var b := _c(&"b", 9)
	q.push(a, 1); q.push(b, 1)
	assert_eq(q.pop_next(), b)
func test_tie_drawn_once_and_kept() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new([0.9, 0.1]))
	var a := _c(&"a", 5); var b := _c(&"b", 5)
	q.push(a, 1); q.push(b, 1)
	assert_eq(q.ordered(), [b, a])
	assert_eq(q.ordered(), [b, a])
func test_equal_speed_earlier_tick_first() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new([0.9, 0.1]))
	var a := _c(&"a", 5); var b := _c(&"b", 5)
	q.push(a, 1); q.push(b, 2)
	assert_eq(q.pop_next(), a)
func test_queue_skips_downed() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new())
	var a := _c(&"a", 9); var b := _c(&"b", 1)
	q.push(a, 1); q.push(b, 1); a.hp = 0
	assert_eq(q.pop_next(), b)
func test_speed_change_reorders_queue() -> void:
	var q := ReadyQueue.new(cfg, ScriptedDice.new())
	var a := _c(&"a", 9); var b := _c(&"b", 5)
	q.push(a, 1); q.push(b, 1)
	a.equipment_mods = Stats.make(0, -8, 0, 0)
	assert_eq(q.peek(), b)
```

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Commit** — `feat(core): ATB e fila de prontos`

---

### Task 6: `BattleState` e `Targeting`

**Files:**
- Create: `game/core/battle_state.gd`, `game/core/inventory.gd` (só a classe; testes na Task 8), `game/core/targeting.gd`, `game/tests/test_targeting.gd`

**Interfaces:**
- Produces:
  - `BattleState extends RefCounted`: `cfg: BalanceConfig`, `dice: Dice`, `heroes: Array[Combatant]`, `enemies: Array[Combatant]`, `ledger: ContributionLedger`, `statuses: StatusSystem`, `queue: ReadyQueue`, `inventory: Inventory` (criado vazio em `create`), `tick: int`. `static func create(cfg, dice, heroes, enemies) -> BattleState`. Helpers: `func allies_of(c) -> Array[Combatant]`, `func foes_of(c) -> Array[Combatant]`, `func living(arr) -> Array[Combatant]`, `func all() -> Array[Combatant]`.
  - `Targeting` (static):
    - `func wants_downed(effects: Array[EffectDef]) -> bool` (true se algum efeito é REVIVE).
    - `func candidates(shape, side, effects, actor: Combatant, b: BattleState) -> Array[Combatant]` — centros válidos: lado conforme `side` relativo ao ator; caídos só se `wants_downed`, e vivos excluídos nesse caso; `CIRCLE_SELF` → `[actor]`.
    - `func area(shape, side, effects, radius: float, width: float, actor, center: Combatant, b) -> Array[Combatant]` — SINGLE → `[center]`; GROUP → todos válidos do lado do centro; ALL → todos válidos dos lados permitidos; CIRCLE_TARGET → válidos com `distance(pos, center.pos) <= radius`; CIRCLE_SELF → idem em volta do ator; LINE → válidos com distância ao segmento `actor.pos→center.pos` ≤ `width/2` ([P-plano] 8). "Válido" = filtro de `candidates` sem a regra de centro.
    - `func redirect(shape, side, effects, actor, original_center: Combatant, original_pos: Vector2, b) -> Combatant` — se `original_center` ainda é candidato, devolve-o; senão o candidato mais próximo de `original_pos`; null se não houver (spec §4.6).

- [ ] **Step 1: Testes** (spec §10.3 itens 2, 13; Review Focus 4)

```gdscript
extends GutTest
var b: BattleState; var h: Combatant; var e1: Combatant; var e2: Combatant; var e3: Combatant
func _e(id: StringName, pos: Vector2) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1,1,1,1)), id, pos, Fixtures.cfg())
func before_each() -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,1,1)), cfg), Vector2(0, 0))
	e1 = _e(&"x", Vector2(100, 0)); e2 = _e(&"y", Vector2(130, 0)); e3 = _e(&"z", Vector2(100, 200))
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [e1, e2, e3])
func _ids(arr: Array[Combatant]) -> Array: return arr.map(func(c: Combatant) -> StringName: return c.id)
func test_circle_includes_by_distance() -> void:
	var got := Targeting.area(AbilityDef.Shape.CIRCLE_TARGET, AbilityDef.Side.ENEMIES, [], 40.0, 0.0, h, e1, b)
	assert_eq(_ids(got), [&"x", &"y"])
func test_line_hits_only_along_segment() -> void:
	var got := Targeting.area(AbilityDef.Shape.LINE, AbilityDef.Side.ENEMIES, [], 0.0, 20.0, h, e2, b)
	assert_eq(_ids(got), [&"x", &"y"])
func test_downed_not_targetable_except_revive() -> void:
	e1.hp = 0
	var heal: Array[EffectDef] = []
	assert_false(Targeting.candidates(AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES, heal, h, b).has(e1))
	var rev := EffectDef.new(); rev.kind = EffectDef.Kind.REVIVE
	h.hp = 0
	var hero2 := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"b", Stats.make(1,1,1,1)), b.cfg), Vector2.ZERO)
	b.heroes.append(hero2)
	assert_eq(Targeting.candidates(AbilityDef.Shape.SINGLE, AbilityDef.Side.ALLIES, [rev], hero2, b), [h])
func test_redirect_to_nearest_or_null() -> void:
	e1.hp = 0
	assert_eq(Targeting.redirect(AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES, [], h, e1, e1.position, b), e2)
	e2.hp = 0; e3.hp = 0
	assert_null(Targeting.redirect(AbilityDef.Shape.SINGLE, AbilityDef.Side.ENEMIES, [], h, e1, e1.position, b))
```

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Commit** — `feat(core): estado de batalha e geometria de alvos`

---

### Task 7: `PendingAction`, `ActionResult` e `ActionExecutor`

**Files:**
- Create: `game/core/pending_action.gd`, `game/core/action_result.gd`, `game/core/action_executor.gd`, `game/tests/test_action_executor.gd`

**Interfaces:**
- Consumes: `BattleState`, `Targeting`, `StatusSystem`, `StatCalculator`, `ContributionLedger`.
- Produces:
  - `PendingAction extends RefCounted`: `actor: Combatant`, `ability: AbilityDef` (ou null), `item: ItemDef` (ou null), `center: Combatant`, `center_pos: Vector2`, `elapsed: float`, `impacted: bool`. Helpers `shape()`, `side()`, `effects()`, `radius()`, `width()`, `cast_time(cfg)`, `impact_time(cfg)` que leem da habilidade ou do item (item usa `cfg.item_*` e raio/largura 0).
  - `ActionResult extends RefCounted`: `fizzled: bool`, `targets: Array[Combatant]`, `hits: Array[Dictionary]` (`{target_id, kind: EffectDef.Kind, amount: int, dodged: bool, status_result: int}`), `downed: Array[Combatant]`.
  - `ActionExecutor` (static): `func apply(a: PendingAction, b: BattleState) -> ActionResult` — chamado no momento de impacto. Redireciona o centro via `Targeting.redirect`; null → `fizzled = true` e nada mais (custo já pago — spec §4.6). Senão calcula `Targeting.area` e aplica **todos** os efeitos em todos os alvos antes de retornar (atômico).

Efeitos (fórmulas de teste):
```
DAMAGE: se dodgeable e roll() < dodge_chance(alvo) → dodged, 0.
        bruto = floor(potency * effective(escala)) (FIXED → floor(potency))
        dano = max(1, bruto - floor(effective(alvo, vitality) * defense_per_vitality))
        dano = statuses.absorb_with_barrier(alvo, dano, ator)
        efetivo = min(dano, alvo.hp); alvo.hp -= efetivo
        se ator herói e alvo inimigo: ledger.add(ator, alvo, efetivo)
        se alvo herói e ator inimigo: alvo.damage_taken_from[ator.id] += efetivo
        se efetivo > 0: statuses.on_hp_damage(alvo)
        se alvo caiu: statuses.clear_all(alvo); alvo.atb = 0; queue.remove(alvo); downed.append
HEAL:   restaurado = min(floor(potency * effective(ator, aura)) [FIXED: floor(potency)], hp_max - hp); só vivos
        ator herói e alvo herói → ledger.add_ally_benefit(ator, alvo, restaurado, inimigos vivos)
REVIVE: só caídos; hp = max(1, floor(hp_max * potency)); atb = 0; conta como HEAL (benefício)
RESTORE_AP: ap = min(ap_max, ap + floor(potency)); sem contribuição (spec não define)
APPLY_STATUS: statuses.apply(alvo, status, ator, chance, inimigos vivos)
REMOVE_STATUS: statuses.remove(alvo, status.id)
```

- [ ] **Step 1: Testes** (spec §10.3 itens 2, 3, 4, 5, 11)

```gdscript
extends GutTest
var b: BattleState; var h: Combatant; var x: Combatant; var y: Combatant
func before_each() -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(10,0,2,4)), cfg), Vector2(0,0))
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1,0,2,1)), &"x", Vector2(100,0), cfg)
	y = Combatant.from_enemy(Fixtures.enemy_def(&"y", Stats.make(1,0,4,1)), &"y", Vector2(120,0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x, y])
func _act(ab: AbilityDef, center: Combatant) -> PendingAction:
	var a := PendingAction.new(); a.actor = h; a.ability = ab; a.center = center; a.center_pos = center.position
	return a
func test_area_overkill_counts_only_remaining_hp() -> void:
	var ab := Fixtures.hit(3.0, AbilityDef.Shape.CIRCLE_TARGET); ab.radius = 50
	x.hp = 5
	var r := ActionExecutor.apply(_act(ab, x), b)
	assert_eq(r.downed, [x])
	assert_eq(b.ledger.get_points(&"a", &"x"), 5.0)
	assert_eq(b.ledger.get_points(&"a", &"y"), 28.0)
func test_fizzle_when_no_valid_target() -> void:
	x.hp = 0; y.hp = 0
	var r := ActionExecutor.apply(_act(Fixtures.hit(1.0), x), b)
	assert_true(r.fizzled)
func test_redirects_when_center_down() -> void:
	var a := _act(Fixtures.hit(1.0), x); x.hp = 0
	assert_eq(ActionExecutor.apply(a, b).targets, [y])
func test_downed_actor_still_completes() -> void:
	h.hp = 0
	ActionExecutor.apply(_act(Fixtures.hit(1.0), x), b)
	assert_lt(x.hp, StatCalculator.hp_max(x, b.cfg))
func test_heal_clamped_and_credits_only_restored() -> void:
	var heal := AbilityDef.new(); heal.shape = AbilityDef.Shape.SINGLE; heal.side = AbilityDef.Side.ALLIES
	var e := EffectDef.new(); e.kind = EffectDef.Kind.HEAL; e.scale = EffectDef.Scale.FIXED; e.potency = 50
	heal.effects = [e]
	h.hp = StatCalculator.hp_max(h, b.cfg) - 7
	h.damage_taken_from = {&"x": 7}
	var a := _act(heal, h)
	ActionExecutor.apply(a, b)
	assert_eq(h.hp, StatCalculator.hp_max(h, b.cfg))
	assert_eq(b.ledger.get_points(&"a", &"x"), 7.0)
func test_damage_minimum_is_one() -> void:
	var ab := Fixtures.hit(0.0)
	var hp0 := x.hp
	ActionExecutor.apply(_act(ab, x), b)
	assert_eq(x.hp, hp0 - 1)
```

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Commit** — `feat(core): execucao de efeitos`

---

### Task 8: `Inventory` e `SelectionSession`

**Files:**
- Create: `game/core/selection_session.gd`, `game/tests/test_selection.gd`
- Modify: `game/core/inventory.gd` (implementar a interface abaixo)

**Interfaces:**
- Produces:
  - `Inventory extends RefCounted`: `func add(item: ItemDef, n: int)`, `func available(id: StringName) -> int` (quantidade − reservas), `func reserve(id) -> bool`, `func release(id)`, `func commit(id)` (consome 1 da reserva), `func listing() -> Array[ItemDef]`.
  - `SelectionSession extends RefCounted` `_init(actor: Combatant, b: BattleState)`:
    - `enum Step { COMMAND, TARGET, CONFIRM, DONE }`, `var step: Step`
    - `func can_use(ab: AbilityDef) -> bool` (`actor.ap >= ap_cost`)
    - `func choose_ability(ab: AbilityDef) -> bool` — falso se sem AP; reserva = desconta AP agora (spec §4.5: consumo na seleção, devolução ao cancelar).
    - `func choose_item(item: ItemDef) -> bool` — falso se `available == 0`; `reserve`.
    - `func target_candidates() -> Array[Combatant]`; `func set_center(c: Combatant) -> void`; `func preview_area() -> Array[Combatant]`.
    - `func back() -> void` — TARGET/CONFIRM → COMMAND devolvendo AP/reserva; em COMMAND não faz nada (spec §4.4 [P*]).
    - `func confirm() -> PendingAction` — `commit` do item; AP já descontado; `step = DONE`.

- [ ] **Step 1: Testes** (spec §10.3 item 8; Review Focus 5)

```gdscript
extends GutTest
var b: BattleState; var h: Combatant; var x: Combatant
func before_each() -> void:
	var cfg := Fixtures.cfg()
	h = Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,1,2)), cfg), Vector2.ZERO)
	x = Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1,1,1,1)), &"x", Vector2(50,0), cfg)
	b = BattleState.create(cfg, ScriptedDice.new(), [h], [x])
	b.inventory = Inventory.new()
func test_cannot_select_without_ap() -> void:
	var ab := Fixtures.hit(1.0); ab.ap_cost = h.ap + 1
	var s := SelectionSession.new(h, b)
	assert_false(s.choose_ability(ab))
	assert_eq(s.step, SelectionSession.Step.COMMAND)
func test_cancel_refunds_ap_fully() -> void:
	var ab := Fixtures.hit(1.0); ab.ap_cost = 4
	var ap0 := h.ap
	var s := SelectionSession.new(h, b)
	assert_true(s.choose_ability(ab))
	assert_eq(h.ap, ap0 - 4)
	s.back()
	assert_eq(h.ap, ap0)
func test_confirm_keeps_cost_and_builds_action() -> void:
	var ab := Fixtures.hit(1.0); ab.ap_cost = 4
	var s := SelectionSession.new(h, b)
	s.choose_ability(ab); s.set_center(x)
	var a := s.confirm()
	assert_eq(a.center, x)
	assert_eq(h.ap, StatCalculator.ap_max(h, b.cfg) - 4)
func test_cannot_select_item_out_of_stock() -> void:
	var it := ItemDef.new(); it.id = &"potion"
	b.inventory.add(it, 1)
	var s := SelectionSession.new(h, b)
	assert_true(s.choose_item(it))
	assert_false(SelectionSession.new(h, b).choose_item(it))
	s.back()
	assert_eq(b.inventory.available(&"potion"), 1)
```

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Commit** — `feat(core): selecao de comando com reserva de custo`

---

### Task 9: `EnemyAI`

**Files:**
- Create: `game/core/enemy_ai.gd`, `game/tests/test_enemy_ai.gd`

**Interfaces:**
- Produces `EnemyAI` (static): `func decide(actor: Combatant, b: BattleState) -> PendingAction` — percorre `actor.enemy_def.ai_rules` em ordem; primeira regra cuja condição vale e cujo `ap_cost <= actor.ap` e que tenha candidato vence; desconta AP; escolhe o centro por `pick` entre `Targeting.candidates`. Sem regra válida → `basic_attack` (ou a primeira habilidade de custo 0) no herói vivo de menor HP.

- [ ] **Step 1: Testes**

```gdscript
extends GutTest
func test_heals_ally_below_threshold_else_attacks_lowest_hp() -> void:
	var cfg := Fixtures.cfg()
	var h1 := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,5,1)), cfg), Vector2.ZERO)
	var h2 := Combatant.from_hero(HeroState.create(Fixtures.hero_def(&"b", Stats.make(1,1,5,1)), cfg), Vector2.ZERO)
	h2.hp = 3
	var d := Fixtures.enemy_def(&"x", Stats.make(1,1,5,5))
	var heal := AbilityDef.new(); heal.side = AbilityDef.Side.ALLIES
	var r1 := AiRule.new(); r1.condition = AiRule.Condition.ALLY_HP_BELOW; r1.threshold = 0.5; r1.ability = heal; r1.pick = AiRule.TargetPick.LOWEST_HP_ALLY
	var r2 := AiRule.new(); r2.ability = Fixtures.hit(1.0); r2.pick = AiRule.TargetPick.LOWEST_HP_ENEMY
	d.ai_rules = [r1, r2]
	var x := Combatant.from_enemy(d, &"x", Vector2.ZERO, cfg)
	var b := BattleState.create(cfg, ScriptedDice.new(), [h1, h2], [x])
	assert_eq(EnemyAI.decide(x, b).center, h2)
	x.hp = 1
	assert_eq(EnemyAI.decide(x, b).ability, heal)
```

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Commit** — `feat(core): IA de inimigo por prioridades`

---

### Task 10: `BattleController`

**Files:**
- Create: `game/core/battle_controller.gd`, `game/tests/test_battle_controller.gd`

**Interfaces:**
- Consumes: tudo acima.
- Produces `BattleController extends RefCounted`, `_init(b: BattleState)`:
  - Sinais: `hero_turn(session: SelectionSession)`, `action_started(a: PendingAction)`, `action_impact(a: PendingAction, r: ActionResult)`, `action_finished(a: PendingAction)`, `turn_lost(c: Combatant)`, `status_tick(c: Combatant, outcome: StatusSystem.AtbFullOutcome)`, `battle_ended(outcome: Outcome)`.
  - `enum Outcome { ONGOING, VICTORY, DEFEAT }`, `var outcome: Outcome`, `var session: SelectionSession` (null fora do Wait), `var executing: PendingAction`.
  - `func is_paused() -> bool` (`session != null`).
  - `func tick(delta: float) -> void`:
    1. Se `outcome != ONGOING` ou pausado: retorna.
    2. `b.tick += 1`; `AtbClock.advance`; para cada pronto: `statuses.on_atb_full`; se `lost_turn` → `atb = 0`, `turn_lost`; senão, se de pé, `queue.push(c, b.tick)`.
    3. Se `executing`: `elapsed += delta`; ao cruzar `impact_time` → `ActionExecutor.apply` uma vez e `action_impact`; ao cruzar `cast_time` → `actor.atb = 0` (mesmo se caído), `action_finished`, `executing = null`.
    4. Se não há `executing`: verifica fim [P-plano] 9 (emite `battle_ended` uma vez); senão `queue.pop_next()`: inimigo → `EnemyAI.decide` e começa a executar; herói → cria `session` e emite `hero_turn`.
  - `func submit(a: PendingAction) -> void` — chamado pela UI após `session.confirm()`; `session = null`; começa a executar (`action_started`).
- Ordem dentro de um mesmo `tick`: ATB → execução → próximo da fila. Uma barra que enche durante a execução só entra na fila.

- [ ] **Step 1: Testes** (spec §10.3 itens 1, 3, 9; Review Focus 1 e 2)

Helper no arquivo: `_battle(hero_speeds: Array[int], enemy_speeds: Array[int]) -> BattleController` usando `Fixtures`, inimigos com `Fixtures.hit(1.0)` como `basic_attack` e IA vazia, e `_run(ctrl, seconds, step := 0.05)`.

```gdscript
func test_menu_pauses_time() -> void
	# herói pronto → hero_turn; enquanto session != null, 5 s de tick não mudam atb de ninguém
func test_ready_during_menu_highest_speed_acts_next() -> void
	# dois heróis prontos; o de maior speed recebe a primeira session; após submit e fim da ação, o outro recebe a seguinte
func test_ready_during_animation_waits_in_queue() -> void
	# inimigo executa ação de cast_time 3.0; herói rápido enche no meio: queue.has(herói) e nenhuma session até action_finished
func test_effects_resolve_before_next_action() -> void
	# ordem de sinais registrada: action_impact(A) e action_finished(A) antes de action_started(B)
func test_downed_actor_action_completes() -> void
	# herói submete; antes do impacto, hp = 0; o dano no inimigo ainda é aplicado
func test_downed_hero_in_queue_never_gets_menu() -> void
	# herói na fila; inimigo o derruba; nenhum hero_turn para ele
func test_battle_ends_once_with_ready_queue_nonempty() -> void
	# último inimigo cai com outro herói na fila; battle_ended(VICTORY) emitido exatamente 1 vez; nenhum hero_turn depois
func test_sleeping_enemy_loses_turn_and_atb_resets() -> void
	# inimigo com SLEEP 1: ao encher, turn_lost, atb == 0, não entra na fila; na próxima vez entra
```

Cada teste usa `watch_signals(ctrl)` + `assert_signal_emit_count` / registro em array e asserções explícitas como as dos comentários.

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Commit** — `feat(core): controlador de batalha ATB`

---

### Task 11: `XpCalculator` e subida de nível

**Files:**
- Create: `game/core/xp_calculator.gd`, `game/tests/test_xp.gd`

**Interfaces:**
- Produces `XpCalculator` (static):
  - `func combat_xp(ledger: ContributionLedger, defeated: Array[Combatant], heroes: Array[Combatant], fled: bool) -> Dictionary[StringName, int]` — fuga → todos 0; por inimigo derrotado, `floor(xp_base * pts / total)` (total 0 → nada); soma por herói; todos os heróis presentes aparecem (0 se nada). Heróis caídos recebem normalmente (spec v3.7 §7.2).
  - `func xp_for_level(level: int, cfg) -> int` = `xp_coef * (level - 1)^2` (cumulativo; quadrático por spec, coeficiente de teste).
  - `func points_for_level(level: int) -> int` = `1 + (2 if level % 5 == 0 else 0)`.
  - `func grant(h: HeroState, xp: int, cfg) -> int` — soma XP, sobe quantos níveis couberem, acumula `pending_points`, devolve níveis ganhos.
  - `func allocate(h: HeroState, attr: StringName, n: int) -> bool` — falso se `n > pending_points`.

- [ ] **Step 1: Testes** (spec §10.3 itens 15, 16)

```gdscript
extends GutTest
func _e(id: StringName, xp: int) -> Combatant:
	return Combatant.from_enemy(Fixtures.enemy_def(id, Stats.make(1,1,1,1), xp), id, Vector2.ZERO, Fixtures.cfg())
func _h(id: StringName) -> Combatant:
	return Combatant.from_hero(HeroState.create(Fixtures.hero_def(id, Stats.make(1,1,1,1)), Fixtures.cfg()), Vector2.ZERO)
func test_per_enemy_floor_and_sum_le_base() -> void:
	var l := ContributionLedger.new()
	l.add(&"a", &"x", 1); l.add(&"b", &"x", 1); l.add(&"c", &"x", 1)
	var xp := XpCalculator.combat_xp(l, [_e(&"x", 100)], [_h(&"a"), _h(&"b"), _h(&"c")], false)
	assert_eq(xp, {&"a": 33, &"b": 33, &"c": 33})
func test_computed_per_enemy_not_on_total() -> void:
	var l := ContributionLedger.new()
	l.add(&"a", &"x", 1); l.add(&"b", &"x", 2); l.add(&"a", &"y", 1)
	var xp := XpCalculator.combat_xp(l, [_e(&"x", 10), _e(&"y", 10)], [_h(&"a"), _h(&"b")], false)
	assert_eq(xp, {&"a": 3 + 10, &"b": 6})
func test_zero_contribution_and_flee() -> void:
	var l := ContributionLedger.new()
	assert_eq(XpCalculator.combat_xp(l, [_e(&"x", 100)], [_h(&"a")], false), {&"a": 0})
	l.add(&"a", &"x", 5)
	assert_eq(XpCalculator.combat_xp(l, [_e(&"x", 100)], [_h(&"a")], true), {&"a": 0})
func test_multi_level_accumulates_points_with_bonus_at_5() -> void:
	var cfg := Fixtures.cfg()
	var h := HeroState.create(Fixtures.hero_def(&"a", Stats.make(1,1,1,1)), cfg)
	h.level = 3; h.xp = XpCalculator.xp_for_level(3, cfg)
	assert_eq(XpCalculator.grant(h, XpCalculator.xp_for_level(6, cfg) - h.xp, cfg), 3)
	assert_eq(h.level, 6)
	assert_eq(h.pending_points, 1 + 3 + 1)
	assert_false(XpCalculator.allocate(h, &"strength", 6))
	assert_true(XpCalculator.allocate(h, &"strength", 5))
	assert_eq(h.allocated.strength, 5)
```

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Commit** — `feat(core): XP por contribuicao e subida de nivel`

---

### Task 12: Conteúdo de teste e cena de batalha (somente leitura)

**Files:**
- Create: `game/data/test/*.tres`, `game/battle/battle_scene.tscn`, `game/battle/battle_scene.gd`, `game/battle/combatant_view.tscn`, `game/battle/combatant_view.gd`
- Modify: `game/project.godot` (cena principal = `battle_scene.tscn`)

**Interfaces:**
- Consumes: `BattleController`, `BattleState`, `Combatant`.
- Produces: `BattleScene` (Node2D) com `var ctrl: BattleController`, `func start(heroes: Array[HeroState]) -> void` (monta a batalha e preserva HP/AP dos `HeroState`), `_process(delta)` → `ctrl.tick(delta)`. Nós `Marker2D` `HeroSpot1..3`, `EnemySpot1..3` definem as posições. `CombatantView`: `func bind(c: Combatant, cfg: BalanceConfig)`; desenha quadrado azul (herói) / círculo vermelho (inimigo), nome, barras de HP, AP e ATB, ícones de texto dos estados; fica cinza quando caído; mostra número de dano/cura ao receber `action_impact`.

Conteúdo genérico (`.tres`) — nomes "Teste A/B/C" e "Inimigo X/Y/Z":
- Estados: `poison`, `sleep`, `paralysis`, `haste` (`cancels: [slow]`), `slow` (`cancels: [haste]`), `barrier`, `str_up` (ATTR_MOD strength).
- Teste A: golpe (único), "Investida" (linha), "Golpe em área" (círculo no alvo).
- Teste B: "Cura" (aliado único), "Barreira" (aliado único), "Pressa" (aliado único), "Sono" (inimigo único).
- Teste C: "Veneno" (inimigo único), "Lentidão" (círculo no alvo), "Pulso" (círculo no executor, dano por Aura).
- Inimigo X: IA atacar menor HP. Inimigo Y: IA curar aliado < 50% senão atacar; imune a `sleep`. Inimigo Z: lento e resistente (`poison: 0.5`); habilidade em linha.
- Itens: "Poção" (HEAL fixo), "Éter" (RESTORE_AP), "Reviver" (REVIVE 0.25). Inventário inicial: 3/2/1.

- [ ] **Step 1:** Criar os `.tres` no editor (ou texto) e as cenas.
- [ ] **Step 2: Verificação manual** — `& $env:GODOT --path game` (F5). Expected: 3 quadrados e 3 círculos nos marcadores; barras ATB enchendo com velocidades visivelmente diferentes; inimigos atacando sozinhos; ao ficar pronto, o tempo para (o menu entra na Task 13).
- [ ] **Step 3:** `./run_tests.ps1` → PASS (nada do núcleo quebrou).
- [ ] **Step 4: Commit** — `feat(battle): cena de batalha e conteudo de teste`

---

### Task 13: Menu de comandos e prévia de alvo

**Files:**
- Create: `game/battle/command_menu.gd` (+ nós na cena), `game/battle/target_preview.gd`
- Modify: `game/battle/battle_scene.gd`, `battle_scene.tscn`

**Interfaces:**
- Consumes: `BattleController.hero_turn(session)`, `SelectionSession`, `BattleController.submit`.
- Produces: `CommandMenu` (Control): `func open(session: SelectionSession) -> void`. Raiz: "Atacar", "Habilidade", "Item". Submenus listam nome + custo; habilidades sem AP e itens com `available == 0` aparecem desabilitados. Na etapa de alvo: ←/→ alterna entre `target_candidates()`; `TargetPreview` (Node2D, `_draw`) desenha o círculo (raio) ou a faixa da linha e destaca `preview_area()`. `ui_accept` avança/confirma; `ui_cancel` chama `session.back()`. Ao confirmar: `ctrl.submit(session.confirm())`.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2: Verificação manual** (roteiro):
  1. Quando um herói fica pronto, o menu abre sozinho e **todas** as barras param (inclusive com submenus abertos).
  2. Escolher habilidade cara → AP desconta; Cancelar → AP volta.
  3. "Golpe em área" mostra o círculo e destaca quem está dentro; "Investida" mostra a faixa.
  4. Usar a última Poção → "Poção" fica desabilitada.
  5. Durante uma animação, outros heróis que ficam prontos esperam; o mais rápido abre primeiro.
- [ ] **Step 3:** `./run_tests.ps1` → PASS.
- [ ] **Step 4: Commit** — `feat(battle): menu de comandos e previa de area`

---

### Task 14: Painel de debug

**Files:**
- Create: `game/battle/debug_panel.gd` (+ nó na cena)
- Modify: `game/battle/battle_scene.gd`

**Interfaces:**
- Produces: `DebugPanel` (Control, alterna com F1): `func refresh(b: BattleState, ctrl: BattleController) -> void` chamado a cada frame. Mostra: (1) fila `queue.ordered()` com Velocidade efetiva; (2) ação executando com `elapsed/cast_time`; (3) por combatente: estados com `remaining` e fonte; (4) `ledger.entries()` em tabela inimigo × herói; (5) "Wait: sim/não".

- [ ] **Step 1:** Implementar.
- [ ] **Step 2: Verificação manual** — aplicar Sono no Inimigo X: o painel mostra `sleep (2)`, e cada vez que a barra dele enche o número cai e a contribuição de Teste B contra X aumenta em `control_value_per_turn`. Aplicar Sono no Inimigo Y: "imune", sem contribuição.
- [ ] **Step 3: Commit** — `feat(battle): painel de debug`

---

### Task 15: Resultado, alocação de pontos e derrota

**Files:**
- Create: `game/battle/result_screen.gd`, `game/battle/level_up_screen.gd` (+ nós)
- Modify: `game/battle/battle_scene.gd`

**Interfaces:**
- Consumes: `BattleController.battle_ended`, `XpCalculator`, `HeroState`.
- Produces:
  - Em VICTORY: `ResultScreen.show_for(xp: Dictionary[StringName, int], before_levels: Dictionary)` mostra a XP por herói e os níveis ganhos; depois, para cada herói com `pending_points > 0`, `LevelUpScreen.open(h: HeroState)` com +/− por atributo e "Confirmar" (usa `XpCalculator.allocate`; não pode confirmar com pontos negativos; pode sair com pontos pendentes, que ficam guardados).
  - Em DEFEAT: tela "Derrota" com "Tentar de novo" (recria a batalha com os `HeroState` restaurados ao estado do início).
  - Após vitória: botão "Lutar de novo" chama `start()` com os **mesmos** `HeroState` (HP/AP persistem — spec §7). Antes de recriar, os `Combatant` copiam `hp`/`ap` de volta para os `HeroState`.

- [ ] **Step 1:** Implementar.
- [ ] **Step 2: Verificação manual:**
  1. Vencer: a XP difere por herói conforme contribuição (quem só curou também recebe).
  2. Herói caído no fim ainda recebe XP se contribuiu.
  3. Ao subir vários níveis, uma única tela com todos os pontos.
  4. "Lutar de novo": HP e AP começam como terminaram.
- [ ] **Step 3:** `./run_tests.ps1` → PASS.
- [ ] **Step 4: Commit** — `feat(battle): resultado, alocacao e derrota`

---

### Task 16: Fechamento do M1

**Files:**
- Modify: `.claude/specs/2026-10-18-rpg-design.md` (nova seção "12. Decisões de implementação do M1 [P-plano]" listando as 9 decisões deste plano, para revisão do usuário)
- Create: `README.md` (como instalar Godot, rodar o jogo e os testes)

- [ ] **Step 1:** `./run_tests.ps1` → todos PASS; anotar a contagem.
- [ ] **Step 2:** Rodar o jogo e repetir os roteiros manuais das Tasks 13–15 de ponta a ponta.
- [ ] **Step 3:** Atualizar spec e README.
- [ ] **Step 4: Commit** — `docs: fecha M1 e registra decisoes de implementacao`

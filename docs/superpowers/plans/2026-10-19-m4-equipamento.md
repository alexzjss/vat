# M4 — Equipamento: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quatro espaços de equipamento por herói (Arma, Armadura, Capacete, Acessório) com modificadores, restrições e passivos (imunidade, resistência, começa com estado), mochila do grupo, página Equipar com prévia, e tudo valendo na batalha.

**Architecture:** Regras puras em `game/core/` — `EquipmentRules` (espaços, restrição, soma de passivos, prévia via `StatCalculator`), `EquipmentBag` (mochila), operações de equipar no `GameState`. Os passivos viram campos do `Combatant` (imunidades, resistências, estados iniciais), e o `StatusSystem` passa a ler esses campos para heróis e inimigos igualmente. A página Equipar segue o padrão das páginas do M3 (`FieldPage`).

**Tech Stack:** Godot 4.7, GDScript tipado, GUT 9.7.1, `./run_tests.ps1`.

**Spec:** [`docs/superpowers/specs/2026-10-19-m4-equipamento-design.md`](../specs/2026-10-19-m4-equipamento-design.md) (inclui §4.1 com as respostas para quem constrói); regras gerais em [`2026-10-18-rpg-design.md`](../specs/2026-10-18-rpg-design.md) §5.3; menu de campo em [`2026-10-18-m3-menu-grupo-design.md`](../specs/2026-10-18-m3-menu-grupo-design.md) §6 (decisões do M3).

## Global Constraints

- Restrições globais do M1–M3: tipos estáticos (`untyped_declaration` = erro), `game/core/` sem `Node`/`Input`, aleatoriedade via `Dice`, números em `BalanceConfig`, inglês no código e português na UI, conteúdo genérico.
- **Os 282 testes atuais continuam passando** em toda task; qualquer teste existente alterado é listado no relatório com o motivo.
- Arquivos com acentos: nunca `Get-Content`/`Set-Content` do PowerShell 5.1 (corrompe UTF-8); usar ferramentas de edição ou Python.
- Espaços canônicos: `EquipmentRules.SLOTS: Array[StringName] = [&"weapon", &"armor", &"helmet", &"accessory"]`; rótulos de UI: Arma, Armadura, Capacete, Acessório.
- Ordem de cálculo da spec: base + alocados + equipamento → retornos decrescentes → temporários (já implementada em `StatCalculator`; não mudar).
- A interface chama o recurso de "AP" (decisão do M3).

## Review Focus

1. **Item perdido ou duplicado** ao trocar, remover, equipar o mesmo item em dois heróis, ou com Game Over: a soma (mochila + equipados) de cada id é constante. → Task 2 `test_item_count_is_conserved`.
2. **Restrição furada**: arma de tipo errado, armadura de outro personagem, item no espaço errado — `equip` recusa e nada muda. → Task 2 `test_equip_refuses_and_changes_nothing`.
3. **Prévia diferente da batalha**: os números da prévia são exatamente os de `StatCalculator` no `Combatant` da próxima batalha. → Task 1 `test_preview_matches_battle_combatant`.
4. **Imunidade/resistência de herói** sem quebrar a de inimigo: os testes atuais do `StatusSystem` continuam iguais; herói imune nunca recebe o estado, nem por "começa com". → Task 3 `test_hero_immunity_from_equipment`, `test_start_status_respects_immunity`.
5. **HP/AP atuais acima do máximo** depois de tirar equipamento: limitados; caído continua com 0. → Task 2 `test_unequip_clamps_current_hp_ap`.

---

## Mapa de arquivos

```
game/core/defs/equipment_def.gd        (+ display_name, weapon_type, allowed_ids, passives)
game/core/defs/equipment_passive.gd    NOVO — Resource: kind IMMUNE/RESIST/START_WITH, status, amount
game/core/defs/character_def.gd        (+ weapon_types, starting_equipment)
game/core/equipment_rules.gd           NOVO — SLOTS, can_equip, passivos agregados, prévia
game/core/equipment_bag.gd             NOVO — mochila
game/core/hero_state.gd                (equipamento inicial em create; snapshot/restore com equipamento)
game/core/game_state.gd                (bag, equip, unequip, save/restore)
game/core/combatant.gd                 (immunities, resistances, start_statuses)
game/core/status_system.gd             (lê campos do Combatant; apply_forced)
game/core/battle_controller.gd         (aplica estados iniciais ao criar)
game/data/test/equipment/*.tres        NOVOS
game/data/test/heroes/*.tres           (weapon_types, starting_equipment)
game/ui/field_menu/equip_page.gd       NOVO
game/ui/field_menu/field_menu.gd       (comando "Equipar")
game/ui/field_menu/status_page.gd      (equipamento e passivos)
game/world/game.gd/.tscn               (mochila inicial), game/world/demo_m4.gd NOVO
game/tests/test_equipment_rules.gd test_equip_state.gd test_equipment_battle.gd test_equip_page.gd test_equip_game.gd
```

---

### Task 1: Dados, regras de equipamento, mochila e conteúdo de teste

**Files:**
- Modify: `game/core/defs/equipment_def.gd`, `game/core/defs/character_def.gd`, `game/tests/test_content.gd`, `game/data/test/heroes/teste_{a,b,c,d,e}.tres`
- Create: `game/core/defs/equipment_passive.gd`, `game/core/equipment_rules.gd`, `game/core/equipment_bag.gd`, `game/data/test/equipment/*.tres`, `game/tests/test_equipment_rules.gd`

**Interfaces:**
- Produces:
  - `EquipmentDef`: `id: StringName`, `display_name: String`, `slot: StringName`, `modifiers: Stats`, `weapon_type: StringName` (vazio = qualquer um usa), `allowed_ids: Array[StringName]` (só armadura/capacete; vazio = todos), `passives: Array[EquipmentPassive]`.
  - `EquipmentPassive extends Resource`: `enum Kind { IMMUNE, RESIST, START_WITH }`, `kind`, `status: StatusDef`, `amount: float` (só RESIST; 0..1).
  - `CharacterDef`: `weapon_types: Array[StringName]` (vazio = não usa armas), `starting_equipment: Array[EquipmentDef]`.
  - `EquipmentRules` (static): `const SLOTS`; `const SLOT_LABELS: Dictionary[StringName, String]`; `can_equip(d: CharacterDef, e: EquipmentDef, slot: StringName) -> bool` (slot igual; arma: `weapon_type` vazio ou em `d.weapon_types`; armadura/capacete: `allowed_ids` vazio ou contém `d.id`; acessório: sempre); `immunities(equipment: Dictionary[StringName, EquipmentDef]) -> Array[StringName]` (IMMUNE + RESIST somado ≥ 1.0); `resistances(equipment) -> Dictionary[StringName, float]` (soma por estado, limitada a 1.0); `start_statuses(equipment) -> Array[StatusDef]` (sem repetir id); `preview(h: HeroState, slot: StringName, e: EquipmentDef, cfg: BalanceConfig) -> Dictionary` com chaves `strength/speed/vitality/aura/hp_max/ap_max`, cada uma `[atual, novo]` — `e == null` significa remover; contas sempre via `StatCalculator` em `Combatant.from_hero` (para o "novo", sobre uma cópia do dicionário de equipamento).
  - `EquipmentBag extends RefCounted`: `add(e: EquipmentDef, n: int = 1)`, `count(id: StringName) -> int`, `take(id: StringName) -> EquipmentDef` (null se 0), `put(e: EquipmentDef)`, `listing() -> Array[EquipmentDef]` (com count > 0, ordem de inserção), `copy() -> EquipmentBag`.
- Conteúdo (genérico): tipos `&"blade"`, `&"staff"`, `&"bow"` (rótulos Lâmina/Bastão/Arco). Armas iniciais por herói (A lâmina, B bastão, C arco, D lâmina, E arco), uma armadura simples para todos; mochila de teste conforme spec §3.5 (uma arma melhor de cada tipo, armadura pesada +Vit −Vel, capacete leve +Aura, capacete exclusivo do Teste B, acessórios Imune a Sono / Resiste a Veneno 50% / Começa com Pressa). `weapon_types`: A blade, B staff, C bow, D blade+staff, E bow.

- [ ] **Step 1: Testes** (exemplos; completar com um por ramo)

```gdscript
func test_weapon_type_restriction() -> void
	# def com weapon_types [blade]: espada (blade) ok; bastão (staff) não; arma sem tipo ok; armadura no espaço weapon não
func test_allowed_ids_restriction() -> void
func test_passives_aggregate_and_cap() -> void
	# dois RESIST 0.6 em poison → resistances poison == 1.0 e poison em immunities
func test_preview_matches_battle_combatant() -> void
	# preview(h, &"armor", pesada).new de cada chave == StatCalculator sobre Combatant.from_hero(h) depois de equipar de fato (montando o dicionário)
func test_preview_remove() -> void
func test_bag_take_put_and_copy_independent() -> void
```

`test_content.gd`: carrega todos os `.tres` de `equipment/`, valida espaço em `SLOTS`, armas com tipo conhecido, e que cada herói pode usar o próprio equipamento inicial.

- [ ] **Step 2–4:** FAIL (RED capturado) → implementar → PASS (suíte inteira).
- [ ] **Step 5: Commit** — `feat(core): dados e regras de equipamento`

---

### Task 2: Equipar no estado do jogo

**Files:**
- Modify: `game/core/hero_state.gd`, `game/core/game_state.gd`, `game/tests/test_game_state.gd`
- Create: `game/tests/test_equip_state.gd`

**Interfaces:**
- Consumes: `EquipmentRules`, `EquipmentBag`.
- Produces:
  - `HeroState.create` coloca `def.starting_equipment` nos espaços (cada um no seu `slot`; ignora e `push_error` se `can_equip` falhar) **antes** de `rest` (HP/AP cheios com o equipamento).
  - `HeroState.snapshot/restore` incluem o equipamento (cópia do dicionário).
  - `GameState.bag: EquipmentBag`. `new_game(..., max_active, bag_items: Array[EquipmentDef] = [], bag_counts: Array[int] = [])`.
  - `GameState.equip(h: HeroState, slot: StringName, e: EquipmentDef) -> bool` — recusa (false, nada muda) se `h` fora do roster, `can_equip` falso ou `bag.count(e.id) == 0`; senão tira da mochila, devolve o antigo, aplica e limita HP/AP atuais ao novo máximo (nunca aumenta; caído fica 0).
  - `GameState.unequip(h: HeroState, slot: StringName) -> bool` — false se vazio; devolve à mochila e limita HP/AP.
  - `save()/restore_save()` cobrem a mochila (cópia) e o equipamento de cada herói.

- [ ] **Step 1: Testes**

```gdscript
func test_starting_equipment_applied_and_full_hp() -> void
func test_equip_swaps_old_back_to_bag() -> void
func test_equip_refuses_and_changes_nothing() -> void
	# tipo errado, allowed_ids, espaço errado, sem estoque, herói fora do roster: false; equipamento, mochila, hp e ap iguais
func test_item_count_is_conserved() -> void
	# sequência de equip/unequip/trocas entre heróis: para cada id, bag.count + nº de heróis com ele equipado == total inicial
func test_unequip_clamps_current_hp_ap() -> void
	# tirar armadura com +Vit: hp limitado ao novo máximo; aumentar máximo não cura; caído fica 0
func test_reserve_can_be_equipped() -> void
func test_restore_save_restores_equipment_and_bag() -> void
```

- [ ] **Step 2–4:** FAIL → implementar → PASS (suíte inteira).
- [ ] **Step 5: Commit** — `feat(core): equipar e remover no estado do jogo`

---

### Task 3: Passivos na batalha

**Files:**
- Modify: `game/core/combatant.gd`, `game/core/status_system.gd`, `game/core/battle_controller.gd`
- Create: `game/tests/test_equipment_battle.gd`

**Interfaces:**
- Produces:
  - `Combatant`: `immunities: Array[StringName]`, `resistances: Dictionary[StringName, float]`, `start_statuses: Array[StatusDef]`. `from_hero` preenche via `EquipmentRules`; `from_enemy` copia `enemy_def.immunities/resistances` (sem estados iniciais).
  - `StatusSystem.apply` passa a ler `target.immunities`/`target.resistances` (mesma ordem de antes: imunidade antes do sorteio). Os testes atuais de estados ficam iguais e passando.
  - `StatusSystem.apply_forced(target: Combatant, def: StatusDef) -> ApplyResult` — IMMUNE se imune; senão aplica/renova como `apply` sem sortear e **sem crédito**; fonte = o próprio alvo.
  - `BattleController._init` aplica `start_statuses` de cada herói com `apply_forced` antes de qualquer tique.

- [ ] **Step 1: Testes**

```gdscript
func test_hero_immunity_from_equipment() -> void
func test_hero_resistance_reduces_chance() -> void
	# ScriptedDice: com resistência 0.5 e chance 1.0, roll 0.6 resiste, 0.4 aplica
func test_start_status_applied_before_first_tick_without_credit() -> void
	# acessório "Começa com Pressa": logo após BattleController.new o herói tem haste; ledger vazio
func test_start_status_respects_immunity() -> void
func test_enemy_immunities_unchanged() -> void
func test_equipment_modifiers_in_battle_stats() -> void
```

- [ ] **Step 2–4:** FAIL → implementar → PASS (suíte inteira).
- [ ] **Step 5: Commit** — `feat(core): passivos de equipamento na batalha`

---

### Task 4: Página Equipar e Status com equipamento

**Files:**
- Create: `game/ui/field_menu/equip_page.gd`, `game/tests/test_equip_page.gd`
- Modify: `game/ui/field_menu/field_menu.gd` (comando "Equipar" entre "Técnicas" e "Status"; ajustar constantes de índice), `game/ui/field_menu/status_page.gd`, testes do M3 que dependem da posição dos comandos (listar no relatório)

**Interfaces:**
- Consumes: `FieldPage` (base do M3), `FieldMenu.set_page_input/set_page_cancel`, `PartyPanel.begin_pick`, `GameState.equip/unequip`, `EquipmentRules.can_equip/preview/SLOT_LABELS`.
- Produces (fluxo spec §3.3, com métodos programáticos para testes):
  1. Escolher herói no painel (roster).
  2. Lista dos 4 espaços: "Arma: Nome" ou "Arma: —".
  3. Escolher espaço → lista dos itens da mochila que o herói pode usar nesse espaço ("Nome xN") + "Remover" se ocupado; se não há nada, mensagem "Nada para equipar aqui." e fica nos espaços.
  4. Prévia ao mover o cursor: uma linha por atributo "Força 12 → 15" (verde se sobe, vermelho se desce, branco se igual), HP máx., AP máx. e "Passivos: Imune a Sono" etc.
  5. Confirmar → `equip`/`unequip`, painel do grupo e lista atualizados, volta à lista de espaços. Esc volta um passo em cada nível.
  - `StatusPage`: bloco "Equipamento" com os 4 espaços e linha "Passivos:".

- [ ] **Step 1: Testes**

```gdscript
func test_equip_command_present_between_techniques_and_status() -> void
func test_slot_list_shows_current_items() -> void
func test_only_usable_items_listed() -> void
func test_preview_lines_show_before_after() -> void
func test_confirm_equips_and_returns_old_to_bag() -> void
func test_remove_option_only_when_occupied() -> void
func test_cancel_goes_back_one_step_each_level() -> void
func test_status_shows_equipment_and_passives() -> void
```

- [ ] **Step 2–4:** FAIL → implementar → PASS (suíte inteira).
- [ ] **Step 5: Verificação visual** — frames da página (lista de espaços, lista de itens com prévia) e do Status; descrever no relatório.
- [ ] **Step 6: Commit** — `feat(ui): pagina equipar no menu de campo`

---

### Task 5: Integração, demonstração e fechamento

**Files:**
- Modify: `game/world/game.gd`, `game/world/game.tscn` (exports `start_equipment: Array[EquipmentDef]`, `start_equipment_counts: Array[int]` com a mochila de teste), `README.md`, `docs/superpowers/specs/2026-10-19-m4-equipamento-design.md` (seção "Decisões de implementação do M4", cada item [I])
- Create: `game/world/demo_m4.gd`, `game/tests/test_equip_game.gd`

**Interfaces:**
- Produces: o jogo começa com o equipamento inicial e a mochila; Game Over restaura ambos. Demo `-- --demo-m4` (padrão do `DemoM3`): abre o menu, equipa no Teste A a armadura pesada e o acessório "Imune a Sono", mostra o Status, fecha, entra na área e luta (inimigos enfraquecidos como nos demos anteriores).

- [ ] **Step 1: Testes**

```gdscript
func test_new_game_has_starting_equipment_and_bag() -> void
func test_game_over_restores_equipment_and_bag() -> void
func test_equipped_passive_holds_in_map_battle() -> void
	# Teste A com "Começa com Pressa" → na batalha da LocalMap ele começa com haste
```

- [ ] **Step 2–4:** FAIL → implementar → PASS (suíte inteira).
- [ ] **Step 5: Verificação visual** — `--write-movie` com `-- --demo-m4`, ler 4–5 quadros e descrever.
- [ ] **Step 6:** README (comando Equipar) e seção de decisões na spec do M4.
- [ ] **Step 7: Commit** — `feat(world): equipamento no jogo e demo do M4`

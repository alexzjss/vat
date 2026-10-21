# M3 — Menu de campo e grupo de 4: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menu de campo (Itens, Técnicas, Status, Atributos, Formação) aberto durante a exploração, e grupo ativo de até 4 heróis com reserva, refletido nas batalhas e no mapa.

**Architecture:** Formação e efeitos fora de combate são lógica pura em `game/core/` (`GameState` ganha reserva e operações de formação; `EffectMath` concentra as fórmulas de cura/reviver/restaurar Aura usadas pela batalha e pelo campo; `FieldActions` aplica itens e técnicas em `HeroState`). A UI do menu fica em `game/ui/field_menu/`, dirigida por métodos programáticos (como `CommandMenu`). O `Game` decide quando o menu pode abrir e congela o mapa atual.

**Tech Stack:** Godot 4.7, GDScript tipado, GUT 9.7.1, `./run_tests.ps1`.

**Spec:** [`.claude/specs/2026-10-18-m3-menu-grupo-design.md`](../specs/2026-10-18-m3-menu-grupo-design.md); regras de batalha em [`2026-10-18-rpg-design.md`](../specs/2026-10-18-rpg-design.md); mapa em [`2026-10-18-m2-mapa-design.md`](../specs/2026-10-18-m2-mapa-design.md) (seção 8 tem as decisões de implementação do M2 que este plano respeita).

## Global Constraints

- Restrições globais do M1/M2: tipos estáticos (`untyped_declaration` = erro), `game/core/` sem `Node`/`Input`, aleatoriedade via `Dice`, números em `BalanceConfig`, inglês no código e português na UI, conteúdo genérico.
- **Os 208 testes atuais continuam passando** em toda task.
- Arquivos com acentos (`.tscn`, `.gd` com texto de UI): **não** editar com `Get-Content`/`Set-Content` do PowerShell 5.1 (corrompe UTF-8 — lição do M2 §8.24); usar as ferramentas de edição de arquivo ou Python.
- `GameState.heroes` continua sendo **o grupo ativo, na ordem da formação** (todo código existente que o usa segue válido). Reserva em `GameState.reserve`.
- Máximo de ativos: `const MAX_ACTIVE: int = 4` em `GameState` (regra da spec, não balanceamento).
- Ação de input nova: `open_menu` = Tab e Esc. Com o menu fechado, o `Game` trata `open_menu`; com o menu aberto, o menu consome Esc como "voltar" e marca o evento como tratado (`set_input_as_handled`), para que a mesma tecla não abra e feche no mesmo quadro.

## Review Focus

1. **Grupo vazio ou líder caído**: nenhuma operação de formação deixa 0 ativos; o líder do mapa é sempre o primeiro ativo de pé (se todos caídos, o primeiro ativo). → Task 1 `test_leader_is_first_standing_active`.
2. **Item gasto sem efeito**: Poção em HP cheio, Éter em Aura cheia, Reviver em herói de pé, Poção em caído — desabilitado e não consome. → Task 2 `test_no_effect_does_not_consume`.
3. **Menu abrindo na hora errada**: durante batalha, fade, telas de resultado ou Game Over, `open_menu` é ignorado; com o menu aberto, inimigos e jogador não se movem e nenhum encontro começa. → Task 6 `test_menu_blocked_during_battle_and_transition`, `test_world_frozen_while_menu_open`.
4. **Formação refletida na batalha**: depois de trocar, a próxima batalha tem os ativos na nova ordem nos pontos 1..N, e a reserva não aparece nem ganha XP. → Task 3 `test_battle_uses_formation_order` e Task 1 `test_reserve_gets_no_combat_xp_path`.
5. **Game Over desfaz a formação**: restaurar o salvamento devolve ativos, reserva e ordem do momento do save. → Task 1 `test_restore_save_restores_formation`.

---

## Mapa de arquivos

```
game/core/
  game_state.gd          (+ reserve, roster(), leader(), formação, save/restore da formação)
  effect_math.gd         NOVO — heal_amount, revive_hp, restore_ap (fonte única)
  action_executor.gd     (usa EffectMath)
  field_actions.gd       NOVO — usar item/técnica fora de combate em HeroState
game/data/test/heroes/teste_d.tres, teste_e.tres   NOVOS (+ habilidades se preciso)
game/battle/battle_scene.tscn  (HeroSpot4)        game/world/local_map.tscn (Arena/HeroSpot4)
game/world/game.gd/.tscn (party com 5 heróis; abre/fecha menu; congela mapa)
game/world/player.gd   (rótulo/cor do líder opcional)
game/ui/field_menu/
  field_menu.gd          NOVO — raiz do menu (CanvasLayer + PanelContainer), comandos e navegação
  party_panel.gd         NOVO — cartões do grupo/reserva, seleção de alvo
  item_page.gd technique_page.gd status_page.gd formation_page.gd   NOVOS
game/tests/
  test_formation.gd test_field_actions.gd test_battle_four.gd test_field_menu.gd test_field_menu_flow.gd
```

---

### Task 1: Formação no `GameState` e conteúdo dos heróis D e E

**Files:**
- Modify: `game/core/game_state.gd`, `game/tests/test_game_state.gd`, `game/tests/test_content.gd`
- Create: `game/data/test/heroes/teste_d.tres`, `game/data/test/heroes/teste_e.tres`, `game/tests/test_formation.gd`

**Interfaces:**
- Produces (em `GameState`):
  - `const MAX_ACTIVE: int = 4`; `var reserve: Array[HeroState] = []`.
  - `new_game(...)` ganha parâmetro final opcional `max_active: int = MAX_ACTIVE`: os primeiros `max_active` defs viram ativos, o resto reserva.
  - `func roster() -> Array[HeroState]` (ativos na ordem, depois reserva).
  - `func leader() -> HeroState` — primeiro ativo com `hp > 0`; se todos caídos, `heroes[0]`.
  - `func swap(a: HeroState, b: HeroState) -> bool` — troca as posições de dois heróis do roster (ativo↔ativo, ativo↔reserva, reserva↔reserva); falso se algum não pertence ao roster.
  - `func to_reserve(h: HeroState) -> bool` — falso se `h` não é ativo ou se é o último ativo.
  - `func to_active(h: HeroState) -> bool` — falso se `h` não está na reserva ou se já há `MAX_ACTIVE` ativos; entra no fim.
  - `save()` e `restore_save()` passam a cobrir o roster inteiro e a formação (quais ids são ativos e em que ordem, e a ordem da reserva). Os objetos `HeroState` continuam os mesmos; só listas e valores mudam.
- Teste D: genérico, atributos coerentes com A/B/C (ex.: equilibrado), básico + 2 habilidades já existentes (por exemplo `golpe_area` e `cura`). Teste E: genérico, básico + 1–2 habilidades existentes. Nenhum nome ou texto narrativo.

- [ ] **Step 1: Testes**

```gdscript
# game/tests/test_formation.gd
extends GutTest
var g: GameState
func before_each() -> void:
	var defs: Array[CharacterDef] = []
	for id: StringName in [&"a", &"b", &"c", &"d", &"e"]:
		defs.append(Fixtures.hero_def(id, Stats.make(1, 1, 3, 2)))
	g = GameState.new_game(Fixtures.cfg(), defs, [], [], ScriptedDice.new(), &"overworld", &"Start")
func _ids(arr: Array[HeroState]) -> Array: return arr.map(func(h: HeroState) -> StringName: return h.def.id)
func test_first_four_active_rest_reserve() -> void:
	assert_eq(_ids(g.heroes), [&"a", &"b", &"c", &"d"])
	assert_eq(_ids(g.reserve), [&"e"])
	assert_eq(_ids(g.roster()), [&"a", &"b", &"c", &"d", &"e"])
func test_swap_active_with_reserve_keeps_slot() -> void:
	assert_true(g.swap(g.heroes[1], g.reserve[0]))
	assert_eq(_ids(g.heroes), [&"a", &"e", &"c", &"d"])
	assert_eq(_ids(g.reserve), [&"b"])
func test_cannot_empty_party_or_overfill() -> void:
	for i: int in 3:
		assert_true(g.to_reserve(g.heroes[0]))
	assert_false(g.to_reserve(g.heroes[0]))
	assert_eq(g.heroes.size(), 1)
	while g.heroes.size() < GameState.MAX_ACTIVE:
		assert_true(g.to_active(g.reserve[0]))
	assert_false(g.to_active(g.reserve[0]))
func test_leader_is_first_standing_active() -> void:
	g.heroes[0].hp = 0
	assert_eq(g.leader(), g.heroes[1])
	for h: HeroState in g.heroes:
		h.hp = 0
	assert_eq(g.leader(), g.heroes[0])
func test_restore_save_restores_formation() -> void:
	var b := g.heroes[1]
	g.swap(b, g.reserve[0])
	g.restore_save()
	assert_eq(_ids(g.heroes), [&"a", &"b", &"c", &"d"])
	assert_eq(g.heroes[1], b)
func test_reserve_gets_no_combat_xp_path() -> void:
	# XpCalculator.combat_xp recebe só os ativos: um id da reserva nunca aparece no resultado
	var l := ContributionLedger.new()
	var e := Combatant.from_enemy(Fixtures.enemy_def(&"x", Stats.make(1,1,1,1), 100), &"x", Vector2.ZERO, g.cfg)
	l.add(&"e", &"x", 10)
	var cs: Array[Combatant] = []
	for h: HeroState in g.heroes:
		cs.append(Combatant.from_hero(h, Vector2.ZERO))
	assert_false(XpCalculator.combat_xp(l, [e], cs, false).has(&"e"))
```

Em `test_content.gd`: carregar `teste_d.tres`/`teste_e.tres` com as mesmas checagens dos outros heróis.

- [ ] **Step 2–4:** FAIL → implementar → PASS (suíte inteira).
- [ ] **Step 5: Commit** — `feat(core): formacao com reserva e herois de teste D e E`

---

### Task 2: `EffectMath` compartilhado e `FieldActions`

**Files:**
- Create: `game/core/effect_math.gd`, `game/core/field_actions.gd`, `game/tests/test_field_actions.gd`
- Modify: `game/core/action_executor.gd` (HEAL/REVIVE/RESTORE_AP passam a usar `EffectMath`; comportamento idêntico)

**Interfaces:**
- Produces:
  - `EffectMath` (static): `heal_amount(e: EffectDef, user_aura_effective: int) -> int` (FIXED → `floor(potency)`; senão `floor(potency * aura)`), `revive_hp(e: EffectDef, hp_max: int) -> int` (`max(1, floor(hp_max * potency))`), `restore_ap_amount(e: EffectDef) -> int` (`floor(potency)`). Só fórmulas — clamps continuam em quem aplica.
  - `FieldActions` (static), todas sobre `HeroState` + `BalanceConfig`:
    - `is_field_usable(effects: Array[EffectDef]) -> bool` — true se não vazio e todo efeito é HEAL, REVIVE ou RESTORE_AP.
    - `would_affect(effects: Array[EffectDef], target: HeroState, cfg) -> bool` — HEAL afeta se de pé e `hp < hp_max`; REVIVE se caído; RESTORE_AP se de pé e `ap < ap_max`; true se ao menos um efeito afeta.
    - `field_techniques(user: HeroState) -> Array[AbilityDef]` — habilidades do usuário com `is_field_usable` e `side == ALLIES`.
    - `can_use_technique(user: HeroState, ab: AbilityDef, target: HeroState, cfg) -> bool` — usuário de pé, `ap >= ap_cost`, `would_affect` (para GROUP/ALL: algum ativo afetado).
    - `use_item(state: GameState, item: ItemDef, target: HeroState) -> bool` — se não usável ou sem efeito ou `available == 0`: false e nada muda; senão aplica todos os efeitos e consome 1 (`reserve` + `commit`).
    - `use_technique(state: GameState, user: HeroState, ab: AbilityDef, target: HeroState) -> bool` — paga `ap_cost` e aplica; SINGLE → `target`; GROUP/ALL → todos os ativos.
    - HP/AP máximos sempre via `StatCalculator` sobre `Combatant.from_hero(h, Vector2.ZERO)` (como `HeroState.rest`). Escala de Aura da técnica usa o atributo efetivo do usuário.

- [ ] **Step 1: Testes**

```gdscript
func test_battle_and_field_heal_use_same_math() -> void
	# mesmo EffectDef HEAL AURA potency 2.0 e usuário com aura efetiva 6: ActionExecutor (via Fixtures/BattleState) e FieldActions restauram o mesmo valor
func test_item_heals_and_is_consumed() -> void
func test_no_effect_does_not_consume() -> void
	# Poção com HP cheio → false, available igual; Reviver em herói de pé → false; Poção em caído → false; Éter com AP cheio → false
func test_revive_item_on_downed() -> void
	# hp = max(1, floor(hp_max*0.25)), item consumido
func test_technique_costs_ap_and_heals() -> void
func test_technique_disabled_without_ap_or_when_user_down() -> void
func test_field_techniques_lists_only_ally_restoratives() -> void
	# herói com cura (lista) + golpe (fora) + sono (fora)
func test_group_technique_affects_all_actives_only() -> void
	# reserva não é curada por técnica GROUP
```

Os testes atuais de `test_action_executor.gd` continuam iguais e passando (garantem a refatoração).

- [ ] **Step 2–4:** FAIL → implementar → PASS (suíte inteira).
- [ ] **Step 5: Commit** — `feat(core): efeitos fora de combate com formulas compartilhadas`

---

### Task 3: Batalha com 4 heróis

**Files:**
- Modify: `game/battle/battle_scene.tscn` (+ `HeroSpot4`, reposicionar os 4 com espaçamento ≥ 150 px dentro de 720 px — ver M2 §8.14), `game/battle/battle_scene.gd` (STANDALONE usa os 4 primeiros `test_heroes`; teste D adicionado ao export da cena), `game/world/local_map.tscn` (`Arena/HeroSpot4`), `game/world/battle_arena.gd` (doc), `game/world/game.tscn` (`party` = A, B, C, D, E)
- Create: `game/tests/test_battle_four.gd`

**Interfaces:**
- Consumes: `GameState.heroes` (ativos em ordem).
- Produces: arenas com `HeroSpot1..4`; `BattleArena.hero_positions()` devolve os 4; a `LocalMap` passa `arena.hero_positions().slice(0, state.heroes.size())`. Batalha com 1–4 heróis funciona (menos que 4: pontos extras ignorados).

- [ ] **Step 1: Testes**

```gdscript
func test_standalone_battle_has_four_heroes_at_spots() -> void
func test_battle_uses_formation_order() -> void
	# GameState com 5 heróis; swap(heroes[0], heroes[3]); toque no inimigo da LocalMap → ctrl.b.heroes ids na nova ordem; posições == hero_positions()[0..3]; nenhum combatente da reserva
func test_battle_with_two_actives_uses_first_two_spots() -> void
func test_four_heroes_fit_on_screen_without_overlap() -> void
	# pontos dos heróis distam ≥ 150 px em y entre si e estão dentro de 0..720 relativos ao centro da arena ± 360
```

- [ ] **Step 2–4:** FAIL → implementar → PASS (suíte inteira; atualizar testes do M1/M2 que contavam 3 heróis **somente** se o novo conteúdo mudou o número esperado — registrar cada ajuste no relatório).
- [ ] **Step 5: Verificação visual** — `--write-movie` da batalha isolada e de um encontro no mapa (`-- --demo-m2`): 4 quadrados azuis sem sobreposição de barras e nomes.
- [ ] **Step 6: Commit** — `feat(battle): batalhas com ate quatro herois`

---

### Task 4: Esqueleto do menu de campo e painel do grupo

**Files:**
- Create: `game/ui/field_menu/field_menu.gd`, `game/ui/field_menu/field_menu.tscn`, `game/ui/field_menu/party_panel.gd`, `game/tests/test_field_menu.gd`
- Modify: `game/project.godot` (ação `open_menu`)

**Interfaces:**
- Produces:
  - `FieldMenu extends CanvasLayer` (camada abaixo do `Fade` e acima do mapa). `signal closed`. `var state: GameState`. `func open(s: GameState) -> void`, `func close() -> void`, `var is_open: bool`. Comandos na ordem `["Itens", "Técnicas", "Status", "Atributos", "Formação", "Fechar"]`. Navegação programática: `move(delta: int)`, `accept()`, `cancel()` (Esc na raiz fecha), `cursor: int`, `command_labels() -> PackedStringArray`, `page: StringName` (`&"root"`, `&"items"`, `&"techniques"`, `&"status"`, `&"attributes"`, `&"formation"`). `_unhandled_input` chama esses métodos (setas, Enter, Esc/`open_menu`). Páginas ainda vazias nesta task: `accept()` em um comando só troca `page` e `cancel()` volta à raiz.
  - `PartyPanel extends VBoxContainer`: `func refresh(s: GameState) -> void`; um cartão por ativo (nome, "Nv N", barras e números HP/Aura, "Caído", "+N pts") e cartões menores para a reserva; modo de seleção: `begin_pick(filter: Callable) -> void` (filtro `HeroState -> bool` para habilitar), `pick_move(delta)`, `picked() -> HeroState`, `signal hero_picked(h: HeroState)`, `end_pick()`.

- [ ] **Step 1: Testes** (instanciar `field_menu.tscn` com um `GameState` de 5 heróis)

```gdscript
func test_open_shows_commands_and_party_cards() -> void
	# command_labels() == [...6...]; panel tem 4 cartões ativos + 1 reserva; texto do cartão contém nome, "Nv 1", "HP x/y"
func test_navigation_and_close() -> void
	# move/accept entra numa página; cancel volta à raiz; cancel na raiz → closed emitido e is_open == false; "Fechar" também fecha
func test_card_shows_downed_and_pending_points() -> void
func test_pick_mode_respects_filter() -> void
	# begin_pick(filtro que só aceita caídos): pick_move pula os não habilitados; accept emite hero_picked do herói certo
```

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Commit** — `feat(ui): esqueleto do menu de campo e painel do grupo`

---

### Task 5: Páginas Itens, Técnicas, Status, Atributos e Formação

**Files:**
- Create: `game/ui/field_menu/item_page.gd`, `technique_page.gd`, `status_page.gd`, `formation_page.gd`, `game/tests/test_field_menu_flow.gd`
- Modify: `game/ui/field_menu/field_menu.gd`

**Interfaces:**
- Consumes: `FieldActions`, `GameState` (formação), `XpCalculator.xp_for_level`, `StatCalculator`, `LevelUpScreen` (M1; instanciar uma própria dentro do menu).
- Produces (fluxos, todos com métodos programáticos usados pelos testes):
  - **Itens:** lista `inventory.listing()` com "Nome xN"; não usáveis em campo desabilitados. Escolher → `PartyPanel.begin_pick(func(h): return FieldActions.would_affect(item.effects, h, cfg))` sobre o roster → `FieldActions.use_item` → painel atualiza e a lista também (item some quando chega a 0). Cancelar na escolha de alvo volta à lista.
  - **Técnicas:** primeiro escolher o usuário (ativos de pé com ao menos uma técnica de campo) → lista `field_techniques(user)` com "Nome — N AP" (desabilitada sem AP) → alvo (SINGLE) ou confirmação direta (GROUP/ALL) → `use_technique`.
  - **Status:** escolher herói (roster) → página com nível, "XP: atual / próximo nível" (`xp_for_level(level+1)`), HP/Aura atuais e máximos, linha por atributo "Força: base + alocado = efetivo", lista de habilidades com custo.
  - **Atributos:** escolher herói com `pending_points > 0` → `LevelUpScreen.open(h)`; ao fechar, volta ao menu com o painel atualizado. Sem ninguém com pontos: comando desabilitado.
  - **Formação:** lista única do roster com marcação "Ativo 1..4" / "Reserva" e "Líder" no primeiro. Fluxo de troca estilo FF: escolher um herói, depois outro → `swap`; ação extra no herói selecionado: "Para reserva"/"Para o grupo" (`to_reserve`/`to_active`); operações recusadas mostram aviso curto ("O grupo precisa de pelo menos 1 herói", "Grupo cheio").

- [ ] **Step 1: Testes** (cena do menu; `GameState` de 5 heróis com Poção 1, Éter 1, Reviver 1; heróis com HP/AP reduzidos)

```gdscript
func test_item_flow_heals_target_and_consumes() -> void
func test_item_target_filter_disables_no_effect_targets() -> void
func test_item_disappears_at_zero() -> void
func test_technique_flow_pays_ap_and_heals() -> void
func test_technique_user_list_excludes_downed_and_no_technique() -> void
func test_status_page_shows_xp_to_next_and_attributes() -> void
func test_attributes_opens_level_up_and_applies() -> void
func test_attributes_disabled_without_pending_points() -> void
func test_formation_swap_active_with_reserve() -> void
func test_formation_refuses_empty_party_with_message() -> void
func test_formation_leader_marked() -> void
```

- [ ] **Step 2–4:** FAIL → implementar → PASS.
- [ ] **Step 5: Verificação visual** — cena de teste/debug que abre o menu em cada página; `--write-movie` e ler 3–4 quadros (raiz com painel, itens com alvo, status, formação).
- [ ] **Step 6: Commit** — `feat(ui): paginas do menu de campo`

---

### Task 6: Integração com o jogo, demonstração e fechamento

**Files:**
- Modify: `game/world/game.gd`, `game/world/game.tscn` (instância do `FieldMenu`), `game/world/local_map.gd`, `game/world/overworld.gd`, `game/world/player.gd` (líder), `README.md`, `.claude/specs/2026-10-18-m3-menu-grupo-design.md` (seção "Decisões de implementação do M3")
- Create: `game/world/demo_m3.gd`, `game/tests/test_field_menu_game.gd`

**Interfaces:**
- Produces:
  - `Game` trata `open_menu` em `_unhandled_input`: abre só se `not busy`, mapa atual sem batalha (`LocalMap.battle == null`), não `locked`, sem tela de resultado/Game Over. Ao abrir: `current.process_mode = PROCESS_MODE_DISABLED` (mesmo mecanismo do fade, M2 §8.17); ao fechar: volta a `INHERIT` e o jogador do mapa passa a representar `state.leader()` (rótulo com a inicial do líder no quadrado azul).
  - `func can_open_menu() -> bool` público (testes).
  - Demo `-- --demo-m3`: começa no mapa-múndi, abre o menu, usa Poção em um herói ferido (o demo fere antes), usa Cura, abre Status, troca D↔E na formação, fecha, entra na área e encosta no inimigo (batalha com a nova formação), vence (mesmo enfraquecimento do demo do M2) e termina.

- [ ] **Step 1: Testes**

```gdscript
func test_menu_opens_on_overworld_and_local_map() -> void
func test_menu_blocked_during_battle_and_transition() -> void
	# durante go_to (busy) e com battle != null: open_menu não abre
func test_world_frozen_while_menu_open() -> void
	# posição de jogador e inimigo não muda em 30 frames com menu aberto; nenhum touched
func test_leader_change_reflects_on_map() -> void
func test_formation_change_reflects_in_next_battle() -> void
```

- [ ] **Step 2–4:** FAIL → implementar → PASS (suíte inteira).
- [ ] **Step 5: Verificação visual** — `--write-movie` com `-- --demo-m3`; ler 5–6 quadros e descrever no relatório.
- [ ] **Step 6:** README (controles: Tab/Esc abre o menu; páginas) e seção de decisões de implementação na spec do M3.
- [ ] **Step 7: Commit** — `feat(world): menu de campo integrado ao jogo e demo do M3`

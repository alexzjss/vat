# M6 — Descanso, save em disco, título e Config: plano de implementação

> Execução: subagentes em sequência (Sonnet implementa, Haiku documenta), uma revisão final do Sonnet, merge ff local. Decisões do usuário em [`roadmap.md`](../../docs/roadmap.md) "rodada 3" [U]; o resto é decisão do designer [I].

**Goal:** O jogo abre numa tela de título (Novo jogo / Continuar), salva em 3 slots no disco só em pontos de descanso e no mapa-múndi, Game Over leva ao título, e o menu de campo ganha a página Config (ATB Espera/Ativo, velocidade da batalha, memória do cursor, velocidade do texto, volume).

## Decisões de design [I]

1. **Config** é um `GameSettings` (RefCounted puro em `core/`): `atb_mode` (`WAIT`, `ACTIVE`), `battle_speed` 1–5 (multiplicador do ATB = `battle_speed_mults[i]` no `BalanceConfig`, padrão `[0.6, 0.8, 1.0, 1.25, 1.5]`, índice padrão 3 → 1.0), `cursor_memory` (bool, padrão true), `text_speed` 1–3 (só guardado; usado no M10), `volume` 0–10 (aplicado ao bus Master; ainda sem áudio). Persistido em `user://settings.cfg` (ConfigFile) por um `SettingsStore` fora de `core/`. É **separado do save**: vale para todos os slots, como em CT e FF7.
2. **ATB Ativo** (como FF7): o tempo continua correndo com o menu de um herói aberto. Inimigos e ações já em execução seguem. Um `submit` feito durante a execução de outra ação fica guardado e começa assim que ela termina. Ao começar, uma ação cujo alvo caiu é redirecionada pela regra do `Targeting` (ou cai no primeiro alvo válido do mesmo lado); se não houver nenhum alvo, a ação é perdida sem gastar AP. Em Espera, nada muda. O simulador continua em Espera.
3. **Velocidade da batalha** multiplica só o delta do ATB, não o tempo das animações e das ações.
4. **Memória do cursor:** o `CommandMenu` lembra o último comando de cada herói, por `def.id`, durante a batalha.
5. **Save:** `GameState.to_dict()` e `GameState.from_dict(d, registry)` cobrem heróis (`def.id`, nível, XP, pontos, alocação, equipamento por id, HP, AP), ativos e reserva, inventário, mochila, mapa e spawn do save, e tempo de jogo. `DefRegistry` resolve id → `CharacterDef`/`ItemDef`/`EquipmentDef` varrendo `res://data/`. `SaveStore` grava `user://save_<1..3>.json` com `version: 1` e um resumo do slot (líder, nível, tempo, local).
   - Arquivo corrompido ou com id desconhecido → o slot aparece como "Dados corrompidos" e não carrega.
   - O save em memória do M2 continua como "último save" da sessão.
6. **Onde salvar** [U]: em ponto de descanso (descansa e salva) e no mapa-múndi (só salva, sem curar). O menu de campo ganha o comando **Salvar**, habilitado só no mapa-múndi ou com o jogador dentro de um ponto de descanso.
7. **Ponto de descanso:** `RestPoint` (Area2D) nos mapas. A tecla nova `interact` (Enter, Espaço ou Z), dentro da área, abre o menu "Descansar e salvar / Reiniciar atributos / Sair".
   - Descansar: chama `rest()` em todos os heróis do roster, inclusive a reserva, e grava o save em memória com o spawn do ponto. Depois abre o seletor de slot.
8. **Reinício de atributos** (spec, B3): o item-chave raro "Cristal de Reinício" é usado só no ponto de descanso. `HeroState.reset_allocation()` devolve a alocação para `pending_points`. Gasta 1 cristal. O inventário inicial do jogo ganha 1 cristal para teste.
9. **Título e Game Over:** `Game` mostra a `TitleScreen` antes do mapa. Com qualquer flag `--demo-*`, o título é pulado e o jogo começa em Novo jogo.
   - Continuar fica desabilitado se não houver slot válido.
   - Game Over [U] mostra a tela "Game Over" e volta ao título; o progresso desde o último save em disco é perdido.
10. **Tempo de jogo:** `GameState.play_time` soma o delta do `Game._process` fora do título.

## Global Constraints

- Restrições de sempre: tipos estáticos, `core/` sem `Node`/`Input`/arquivo, números no `BalanceConfig`, código em inglês e UI em português, nada de `Get-Content`/`Set-Content` em arquivos acentuados, `"\n"` em vez de quebra literal, commitar `.uid`.
- Testes de save usam um diretório temporário (`user://test_saves/`, limpo no `after_each`), nunca os slots reais.
- Todos os testes existentes continuam passando; as demos `--demo-m2/m3/m4` continuam terminando.

## Review Focus

1. **ATB Ativo:** `submit` durante uma execução, alvo morto, herói que cai com o menu aberto (a sessão é cancelada e o menu fecha). → testes da Task 2.
2. **Ida e volta do save:** cada campo volta igual, inclusive equipamento vestido, reserva e itens reservados (reservas zeradas ao salvar). → Task 3.
3. **Demos e testes sem título:** nenhum caminho de teste fica preso na TitleScreen. → Task 4.
4. **Salvar fora de lugar permitido:** o comando Salvar fica desabilitado em área local fora do ponto de descanso. → Task 4/5.

---

### Task 1: GameSettings, página Config e velocidade/memória do cursor (Sonnet)
**Files:** `core/game_settings.gd` (novo), `world/settings_store.gd` (novo), `core/defs/balance_config.gd` (`battle_speed_mults`), `ui/field_menu/config_page.gd` (novo) + registro no `field_menu.gd` (comando "Config" antes de "Fechar"), `battle/battle_scene.gd` e `battle/command_menu.gd` (multiplicador e memória), `world/game.gd` (carrega e aplica as configurações; repassa à batalha via `GameState.settings`), testes `tests/test_game_settings.gd`, `tests/test_config_page.gd`.
- Teste: padrões; clamp dos valores; `to_dict`/`from_dict`; a página altera os valores com esquerda/direita; o multiplicador muda o ATB em `BattleController` (campo `speed_mult`, padrão 1.0); memória do cursor ligada e desligada.
- Commit `feat(config): pagina Config, velocidade da batalha e memoria do cursor`.

### Task 2: ATB Ativo (Sonnet)
**Files:** `core/battle_controller.gd` (`active_mode: bool`; `is_paused()` só em Espera; `_start_next` não abre outra sessão de herói enquanto uma está aberta, mas inimigos seguem; `submit` com `executing != null` → `_queued`; revalidação de alvo em `_begin`), `battle/battle_scene.gd` (lê `settings.atb_mode`; fecha o menu se o herói da sessão cair), `battle/debug_panel.gd` (mostra o modo), testes `tests/test_atb_active.gd`.
- Testes: em Ativo, um inimigo age com a sessão aberta; `submit` durante a execução começa depois; alvo morto é redirecionado; sem alvos, a ação é perdida e o AP fica; o herói que cai com a sessão aberta fecha a sessão e a fila segue; Espera tem o mesmo comportamento de antes (suíte inteira).
- Commit `feat(battle): modo ATB Ativo`.

### Task 3: Save em disco (Sonnet)
**Files:** `core/game_state.gd` (`to_dict`, `from_dict`, `play_time`, `settings` não entra no save), `core/hero_state.gd` (`to_dict`/`from_dict`), `core/inventory.gd` e `core/equipment_bag.gd` (`to_dict`/`from_dict`), `core/def_registry.gd` (novo; recebe as listas, sem IO), `world/save_store.gd` (novo; varre `res://data/` para montar o registry, lê e grava JSON, resumo do slot, diretório configurável), testes `tests/test_save_codec.gd`, `tests/test_save_store.gd`.
- Testes: ida e volta completa; id desconhecido → erro tratado; JSON inválido → slot corrompido; `version` diferente → corrompido; resumo do slot.
- Commit `feat(save): save em disco com 3 slots`.

### Task 4: Título, Game Over e comando Salvar (Sonnet)
**Files:** `world/title_screen.gd` + `.tscn` (Novo jogo / Continuar com lista de 3 slots / Sair), `world/game_over_screen.gd`, `ui/save_slot_picker.gd` (escolher slot para salvar ou carregar, confirmar sobrescrita), `world/game.gd` (fluxo título → jogo → Game Over → título; flags de demo pulam o título; `can_save()`; `play_time`), `ui/field_menu/field_menu.gd` (comando "Salvar" habilitado por `game.can_save()`), testes de cena `tests/test_title_flow.gd`.
- Testes: inicia no título sem flag; Novo jogo cria o estado; Continuar carrega o slot; Game Over → título; Salvar habilitado no mapa-múndi e desabilitado na área.
- Commit `feat(game): tela de titulo, game over e salvar no mapa-mundi`.

### Task 5: Ponto de descanso e reinício de atributos (Sonnet)
**Files:** `world/rest_point.gd` + `.tscn`, `world/local_map.tscn` (um ponto de descanso perto da entrada, com marcador de spawn próprio), `project.godot` (ação `interact`), `ui/rest_menu.gd`, `core/hero_state.gd` (`reset_allocation`), `core/defs/item_def.gd` (flag `key_item`, se não existir), `data/test/items/cristal_reinicio.tres`, `world/game.tscn` (1 cristal no inventário inicial), `world/demo_m6.gd` (`--demo-m6`: anda até o ponto, descansa, salva no slot de teste, reinicia os atributos de um herói), testes `tests/test_rest_point.gd`.
- Testes: descansar cura o roster todo e grava o spawn do ponto; reiniciar devolve os pontos e gasta o cristal; sem cristal, a opção fica desabilitada; o Salvar do menu fica habilitado dentro do ponto.
- Verificação visual: `--write-movie` da demo-m6, conferir alguns quadros.
- Commit `feat(world): ponto de descanso e reinicio de atributos`.

### Task 6: Documentação (Haiku)
- README (como jogar: título, salvar, Config, teclas), roadmap (M6 concluído), `data/test/README.md` (cristal).
- Commit `docs: M6 descanso, save e config`.

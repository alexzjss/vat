# M10 — Eventos, diálogo e dungeon: plano de implementação

> Execução: subagentes em sequência (Sonnet implementa, Haiku documenta), uma revisão final do Sonnet e merge ff local. As decisões do usuário estão em [`roadmap.md`](../../docs/roadmap.md), "rodada 3" [U], e a XP narrativa na spec §5.6 [P]. O resto é decisão do designer [I]. Os textos são de teste: nenhum conteúdo narrativo é inventado como canônico.

**Goal:** sistema de eventos roteirizados, que só leem e gravam flags:
- caixa de diálogo com nome e escolhas;
- NPCs e placas;
- cenas que movem personagens;
- XP narrativa;
- objetos de dungeon: baús, portas e chaves, interruptores e armadilhas;
- uma dungeon de teste ligada ao mapa-múndi.

## Decisões de design

1. **Flags** [U]: `GameState.flags: Dictionary[StringName, int]`, onde bool é 0/1 e também pode ser contador. Vão no save como campo opcional (`version` 1). Também entram em snapshot/restore, como os chefes derrotados.
2. **Roteiro**: o `EventScript` (Resource) tem `steps: Array[EventStep]`. Cada passo é uma subclasse Resource em `core/events/`.
   - Texto e escolha: `Say(speaker, text)` e `Choice(prompt, options: PackedStringArray, flag)`. A escolha grava o índice escolhido na flag.
   - Flags e fluxo: `SetFlag(flag, value)`, `AddFlag(flag, delta)`, `IfFlag(flag, op, value, else_label)` e `Label(name)`/`Goto(label)`.
   - Recompensas: `GiveItem(item, n)`, `GiveEquipment(e, n)`, `Teach(hero_id, ability_id)` (usa `HeroState.learn`) e `GrantXp(amount, rule, include_downed, heroes)`.
   - Mapa: `MoveActor(actor: NodePath, to_marker, speed)`, `Wait(s)`, `CameraTo(marker)`, `StartBattle(encounter)`, `Heal(pct)`.
3. **`EventRunner`** (núcleo, puro) percorre os passos.
   - Os passos de regra (flags, itens, XP, Teach) ele aplica sozinho, direto no `GameState`.
   - Os de apresentação viram um `EventRequest` (tipo e dados). O runner para e espera `resume(answer)`.
   - Um laço sem passo de apresentação aborta depois de `event_max_steps = 1000`, com `push_error`.
4. **XP narrativa** [P, §5.6]: `rule` é `ACTIVE`, `ALL_RECRUITED` ou `LIST`, e `include_downed` vale true ou false. A XP passa por `XpCalculator.grant`, então nível e técnicas funcionam. O runner devolve as linhas "X subiu para o Nv N!" e "X aprendeu Y!" como `Say` do sistema, com nome vazio.
5. **Apresentação**: o `EventPlayer` (Node do `Game`) executa os requests. Durante o evento, o mapa fica congelado (jogador e inimigos parados) e o menu de campo não abre.
   - `DialogueBox` (CanvasLayer): placa de nome e texto revelado a `text_speeds[settings.text_speed]` caracteres/s (no `BalanceConfig`; padrão `[30, 60, 120]`). `accept` completa o texto ou avança, e as escolhas são navegadas com cima/baixo.
   - `MoveActor` anda em linha reta até o marcador, com tween pela velocidade. O jogador e os NPCs são atores; os seguidores acompanham pelo rastro.
6. **Interação**: a base é `Interactable` (Area2D com `prompt` e `event`), e o `RestPoint` passa a herdar dela.
   - `interact` aciona o interagível sobreposto mais próximo do jogador. A lógica de escolha é pura e testável.
   - Subclasses: `Npc` (desenha um losango verde, tem roteiro) e `Sign` (placa marrom, roteiro de `Say`).
7. **Objetos de dungeon** [U]. Todo estado vive em flags, então o mapa reinstanciado reflete tudo.
   - `Chest`: tem `item` ou `equipment`, `count` e `opened_flag`. Ao abrir mostra "Encontrou X!"; aberto, aparece vazio.
   - `Door`: tem `key_item` (opcional) e `open_flag`. Precisa da chave, que é item-chave e não é consumida [I, CT]. Sem chave mostra "Está trancada.", e aberta não bloqueia.
   - `Switch`: alterna uma `flag`. Um `FlagGate` (StaticBody2D) bloqueia a passagem enquanto a flag está diferente de `open_value`.
   - `Trap` (piso): ao pisar, ou causa dano `trap_damage_pct = 0.1` do HP máximo nos ativos (sem matar: o mínimo é 1), ou inicia `StartBattle`. Pode ser de uso único (`once_flag`) e pisca quando está armada.
   - `EventTrigger` (Area2D): roda um roteiro ao entrar, uma vez (`once_flag`).
8. **Conteúdo de teste**: novo mapa `dungeon_teste` (`LocalMap` com outra cena), ligado ao mapa-múndi por uma zona nova. Tem:
   - placa na entrada;
   - NPC com escolha. "Sim" ensina a técnica de evento do Teste A (`rajada`) e dá XP narrativa `ACTIVE`;
   - baú com Poção e baú com "Chave de Teste";
   - porta trancada pela chave;
   - interruptor que abre um portão;
   - armadilha de dano e armadilha de batalha;
   - cena roteirizada na sala final: o NPC anda, fala duas linhas e a câmera vai a um ponto.

   A saída volta ao mapa-múndi. O chefe do M11 fica nesta dungeon depois.
9. **Demo** `--demo-m10`: entra na dungeon, lê a placa, fala com o NPC (escolhe "Sim"), abre os dois baús, abre a porta, aciona o interruptor, pisa na armadilha de dano e assiste à cena.

## Global Constraints

- Restrições de sempre: tipos estáticos; `core/` sem `Node`, `Input` e IO; números no `BalanceConfig`; código em inglês e UI em português; nada de `Get-Content`/`Set-Content` em arquivos acentuados; `"\n"`; commitar `.uid`.
- A suíte (~2 min, via Bash com timeout longo) e as demos `--demo-m2/m4/m6/m7/m8` continuam passando.

## Review Focus

1. **Evento preso**: um passo de apresentação que nunca retoma, ou um laço infinito. → limite de passos e testes do runner.
2. **Estado fora das flags**: baú, porta ou interruptor que reaparece fechado ao reentrar, ao carregar ou no Game Over → restore. → Task 3.
3. **Entrada vazando**: o `accept` do diálogo também aciona `interact`, abre o menu ou move o jogador. → Task 2.
4. **XP narrativa**: regras e `include_downed`. → Task 1.

---

### Task 1: Núcleo de eventos (Sonnet)
**Files:** `core/events/*.gd` (passos, `event_script.gd`, `event_runner.gd`, `event_request.gd`), `core/game_state.gd` (`flags`, save, snapshot), `core/defs/balance_config.gd`, `tests/test_event_runner.gd`, `tests/test_narrative_xp.gd`.
- Testes: cada passo de regra; `IfFlag` com cada operador; `Goto`/`Label`; `Choice` grava a flag e retoma; o limite de passos; `GrantXp` com as três regras e com `include_downed`; `Teach`; flags no save e no restore.
- Commit `feat(core): sistema de eventos e flags`.

### Task 2: Diálogo, EventPlayer e interação (Sonnet)
**Files:** `ui/dialogue_box.gd`, `world/event_player.gd`, `world/interactable.gd`, `world/npc.gd`, `world/sign.gd`, `world/rest_point.gd` (herda de `Interactable`), `world/game.gd` (congelar e bloquear o menu, rotear `interact`), `world/local_map.gd`, `tests/test_dialogue.gd`, `tests/test_interaction.gd`.
- Testes: velocidade do texto; `accept` completa e depois avança; escolha; `MoveActor` chega ao marcador; o mapa fica congelado durante o evento; o mais próximo é escolhido; nenhum vazamento de entrada; o ponto de descanso continua funcionando.
- Commit `feat(world): dialogo, npcs, placas e eventos no mapa`.

### Task 3: Objetos de dungeon (Sonnet)
**Files:** `world/chest.gd`, `world/door.gd`, `world/switch.gd`, `world/flag_gate.gd`, `world/trap.gd`, `world/event_trigger.gd` (e `.tscn` se ajudar), `data/test/items/chave_teste.tres`, `tests/test_dungeon_objects.gd`.
- Testes: baú abre uma vez e o estado persiste entre instâncias do mapa; porta sem chave e com chave; o interruptor alterna o portão; a armadilha de dano respeita o mínimo 1 e o `once_flag`; a armadilha de batalha inicia o encontro; o trigger roda uma vez; Game Over → `restore_save` reverte.
- Commit `feat(world): baus, portas, interruptores e armadilhas`.

### Task 4: Dungeon de teste e demo (Sonnet)
**Files:** `world/dungeon_teste.tscn`, `world/game.gd` (`MAPS`), `world/overworld.tscn` (zona nova), `data/test/events/*.tres`, `world/demo_m10.gd`, `tests/test_dungeon_flow.gd`.
- Testes: entrar e sair da dungeon; o fluxo NPC → `Teach` → técnica aprendida; o save e o carregamento mantêm baús, porta e portão.
- Verificação visual: `--write-movie` da `--demo-m10`, alguns quadros.
- Commit `feat(world): dungeon de teste com eventos`.

### Task 5: Documentação (Haiku)
- README (interagir, diálogo, objetos, `--demo-m10`), roadmap (M10 concluído), `data/test/README.md` (eventos, chave).
- Commit `docs: M10 eventos, dialogo e dungeon`.

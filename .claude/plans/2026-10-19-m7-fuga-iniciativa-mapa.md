# M7: fuga, iniciativa, IA no mapa, corrida e seguidores (plano de implementação)

> **Execução:** subagentes em sequência (Sonnet implementa, Haiku documenta), uma revisão final do Sonnet, merge ff local.
> **Decisões:** as do usuário estão em [`roadmap.md`](../../docs/roadmap.md), "rodada 3" [U]. O resto é decisão do designer [I].

**Goal:** encontros no mapa viram decisão tática, como em Chrono Trigger.
- Correr e grupo em fila.
- Fugir segurando uma tecla.
- Vantagem e emboscada por contato.
- Inimigos que patrulham, perseguem, se escondem e se juntam.
- Chefes que não reaparecem.

## Decisões de design

1. **Corrida** [U]: segurar a ação nova `run` (Shift e X) multiplica a velocidade do jogador por `run_mult = 1.8` (`BalanceConfig`). Funciona no mapa-múndi e nas áreas.
2. **Seguidores** [U, CT]: nas áreas locais, os ativos 2–4 seguem o líder por um rastro.
   - O rastro é um buffer de posições, com uma amostra a cada `follow_spacing = 28` px andados. O seguidor k fica na amostra `k × follow_gap = 1`.
   - Os seguidores são só visuais, sem colisão, e usam a mesma forma e cor do herói na batalha.
   - Na batalha e no fade eles somem; ao voltar ao mapa, o rastro recomeça na posição do líder.
   - No mapa-múndi só aparece o líder [I].
   - A lógica do rastro é pura em `core/world/follow_trail.gd`.
3. **Fuga** [U]: segurar a ação nova `flee` (Q) enche uma barra de fuga de 0 a 1.
   - Velocidade: `flee_base_rate × (Vel média dos heróis vivos + 1) / (Vel média dos inimigos vivos + 1)` por segundo, com `flee_base_rate = 0.25`.
   - Soltar a tecla esvazia a barra a `flee_decay = 0.5`/s.
   - A barra corre em **tempo real**, mesmo com o menu aberto no modo Espera [I]: senão seria impossível fugir em Espera.
   - Cheia: novo resultado `Outcome.FLED`. Sem XP [U], HP e AP ficam como estão, e os itens já gastos continuam gastos.
   - `EncounterDef.can_flee` (padrão true; chefes false): segurar Q mostra "Não dá para fugir!" e a barra não enche.
   - A conta fica em `BattleController.update_flee(real_delta, holding)`, pura e testável.
   - O simulador nunca foge.
   - No mapa, depois da fuga: o jogador volta para onde estava antes da batalha. O inimigo fica `flee_cooldown = 3.0` s sem poder encostar (pisca) e volta ao comportamento normal.
4. **Iniciativa por contato** [U, CT]: o tipo de contato é decidido no toque, por `core/world/initiative.gd` (`classify(enemy_pos, enemy_facing, enemy_chasing, player_pos) -> Kind {NORMAL, PREEMPTIVE, AMBUSH}`).
   - **PREEMPTIVE** (pelas costas): o ângulo entre a frente do inimigo e o vetor inimigo→jogador passa de `backstab_angle = 120°`. Os heróis começam com ATB cheio; os inimigos, com 0.
   - **AMBUSH**: o inimigo estava perseguindo, ou é escondido. Os inimigos começam com ATB cheio; os heróis, com 0.
   - **NORMAL**: o ATB inicial de hoje.
   - A batalha mostra "Ataque surpresa!" ou "Emboscada!" por `banner_time = 1.2` s.
   - A frente do inimigo é a direção da última velocidade diferente de zero.
5. **Comportamentos** (estratégias de `MapMovement`; o step passa a receber a posição do jogador: `step(pos, delta, player_pos)`):
   - `WanderMovement`: como hoje, ignora o jogador.
   - `PatrolMovement`: segue os pontos de uma lista (`PackedVector2Array` exportado no `MapEnemy`), em laço e com pausa `patrol_wait = 0.6` s em cada ponto.
   - `ChaseMovement`: decorador de outro movimento. Vê o jogador num cone (`vision_range = 220`, `vision_angle = 70°`) e o persegue a `chase_speed = 150`. Desiste quando a distância passa de `chase_give_up = 380`, e então volta à base (o movimento de dentro retoma).
   - **Escondido** (`MapEnemy.hidden`): invisível e sem toque até o jogador chegar a `ambush_reveal_dist = 90`. Aí aparece e avança como perseguidor; o contato conta sempre como AMBUSH.
6. **Grupo que se junta** [U]: `MapEnemy.group: StringName`. No toque, todos os inimigos do mesmo grupo a até `group_join_dist = 200` entram na mesma batalha.
   - Os encontros são concatenados e limitados às posições da arena (`EnemySpot1..N`).
   - Os que entraram somem do mapa ao vencer, como o tocado.
7. **Chefes únicos**: `EncounterDef.unique_id` (vazio = comum). Ao vencer, o id vai para `GameState.defeated` (salvo no `to_dict`, campo opcional, `version` continua 1). O `LocalMap` não instancia inimigos com id já derrotado.
8. **Conteúdo de teste** na `local_map.tscn`: um patrulheiro, um perseguidor (wander + chase), um escondido, uma dupla de grupo e um "chefe" (encontro Z sozinho, `can_flee = false`, `unique_id = &"chefe_teste"`). Todos os números novos vão no `BalanceConfig`, com o comentário "valor de teste".
9. **Demo** `--demo-m7`: corre com o grupo em fila, toca um inimigo pelas costas (Ataque surpresa) e foge segurando Q. Depois toca o chefe e mostra "Não dá para fugir!".

## Global Constraints

Restrições de sempre:
- Tipos estáticos.
- `core/` sem `Node`, `Input` ou IO.
- Números no `BalanceConfig`.
- Código em inglês e UI em português.
- Nunca usar `Get-Content`/`Set-Content` em arquivos acentuados.
- Usar `"\n"` em vez de quebra literal.
- Commitar os `.uid`.
- Testes e demos `--demo-m2/m4/m6` continuam passando.
- O simulador continua determinístico.

## Review Focus

1. **Fuga com ação em execução**: a fuga só termina a batalha entre ações. Se uma ação estiver executando, ela acaba primeiro. Ações enfileiradas são reembolsadas. → Task 2.
2. **Iniciativa aplicada no lugar certo**: o ATB inicial vem do `BattleState`/`start_with`, não de um hack na cena. O simulador continua NORMAL. → Task 3.
3. **Grupo maior que a arena**: limite e ordem estáveis. → Task 4.
4. **Chefe derrotado reaparecendo** depois de carregar o save. → Task 4.

---

### Task 1: Corrida e seguidores (Sonnet)

**Files:** `project.godot` (`run`, `flee`), `world/player.gd`, `core/world/follow_trail.gd`, `world/party_followers.gd` (no `local_map.tscn`), `world/local_map.gd` (esconder/reiniciar na batalha), testes `tests/test_follow_trail.gd`, `tests/test_run.gd`.

- Testes:
  - o rastro amostra pela distância;
  - o seguidor k fica na posição certa;
  - reset;
  - o número de seguidores acompanha `state.heroes.size()` depois de mudar a formação;
  - correr multiplica a velocidade.
- Commit: `feat(world): corrida e grupo em fila`.

### Task 2: Fuga (Sonnet)

**Files:** `core/battle_controller.gd` (`flee_gauge`, `update_flee`, `Outcome.FLED`, `can_flee`), `core/defs/encounter_def.gd` (`can_flee`), `battle/battle_scene.gd` (lê o input, desenha a barra e a mensagem, trata FLED sem XP), `world/local_map.gd` (consequência no mapa), `world/map_enemy.gd` (cooldown), testes `tests/test_flee.gd`.

- Testes:
  - a barra enche com a razão das velocidades;
  - esvazia ao soltar;
  - bloqueada com `can_flee = false`;
  - FLED só entre ações;
  - sem XP;
  - o jogador volta à posição de antes;
  - o inimigo não reencosta durante o cooldown.
- Commit: `feat(battle): fuga segurando tecla`.

### Task 3: Iniciativa por contato (Sonnet)

**Files:** `core/world/initiative.gd`, `core/battle_state.gd` ou o ponto onde o ATB inicial é definido (parâmetro `initiative`), `battle/battle_scene.gd` (`start_with(..., initiative)` e faixa de aviso), `world/map_enemy.gd` (`facing`, `is_chasing()`), `world/local_map.gd` (classifica no toque), testes `tests/test_initiative.gd`.

- Testes:
  - `classify` nos três casos e nos limites de ângulo;
  - ATB inicial de cada tipo;
  - NORMAL igual a antes.
- Commit: `feat(world): iniciativa por contato`.

### Task 4: Comportamentos, grupo, chefes únicos, conteúdo e demo (Sonnet)

**Files:** `core/world/map_movement.gd` (assinatura nova), `wander_movement.gd`, `patrol_movement.gd`, `chase_movement.gd`, `world/map_enemy.gd` (`behavior`, `patrol_points`, `hidden`, `group`), `world/local_map.gd` (grupo e únicos), `core/game_state.gd` (`defeated`), `core/defs/encounter_def.gd` (`unique_id`), `data/test/encounters/` (chefe), `world/local_map.tscn`, `world/demo_m7.gd`, testes `tests/test_map_behaviors.gd`, `tests/test_enemy_group.gd`.

- Testes:
  - patrulha em laço;
  - o cone de visão (dentro e fora do ângulo e do alcance);
  - desistir e voltar;
  - o escondido aparece na distância certa e gera AMBUSH;
  - o grupo junta só quem está perto e respeita o limite;
  - o único não reaparece, nem depois de `to_dict`/`from_dict`.
- Verificação visual: `--write-movie` da `--demo-m7`, olhando alguns quadros.
- Commit: `feat(world): comportamentos de inimigo, grupo e chefes unicos`.

### Task 5: Documentação (Haiku)

- README: teclas de correr e fugir, `--demo-m7`.
- Roadmap: M7 concluído.
- `data/test/README.md`: encontro do chefe.
- Commit: `docs: M7 fuga, iniciativa e inimigos no mapa`.

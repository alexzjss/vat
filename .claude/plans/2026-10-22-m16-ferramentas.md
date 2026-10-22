# M16 — Ferramentas de criação: plano de implementação

> Execução: Sonnet implementa, Haiku documenta, uma revisão final do Sonnet e merge ff local. As decisões do usuário [U] são da rodada 5 (2026-10-22) e da rodada 6 (as perguntas do M16, logo abaixo). O resto é decisão do designer [I]. **Nenhum conteúdo narrativo é inventado**: os exemplos usam os textos placeholder da fatia.

**Goal:** o usuário passa a desenvolver o jogo ativamente sem mexer em código:
- escreve diálogos e cenas num **roteiro em texto**;
- cadastra itens, inimigos, habilidades etc. num **painel do editor do Godot**;
- troca formas geométricas por **arte**: sprites de mapa, sprites de batalha, retratos e tiles 32×32;
- testa qualquer mapa ou encontro direto do editor.

## Decisões do usuário [U]
- **Ferramenta:** editor do Godot + plugin próprio. [rodada 5]
- **Narrativa:** roteiro em texto, num **formato próprio simples**: falas `Nome [expressão]: texto`, escolhas com `*`, saltos com `->`, comandos com `@`. Ele compila para os eventos que já existem, sem addon externo. [rodada 6]
- **Tiles:** 32×32. [rodada 5]
- **Arte de personagem:** sprite de mapa em 4 direções, sprite de batalha animado e retrato de diálogo. [rodada 5]
- **Tamanhos** [rodada 6], todos configuráveis no `SpriteSet`:
  - quadro de mapa **32×48**;
  - sprite de batalha **64×64**;
  - retrato **96×96**.
- **Mapas:** migrar **os 7 mapas da fatia** para TileMap, com um tileset placeholder 32×32 que tenha colisão, para o usuário pintar por cima. [rodada 6]

## Decisões de design [I]

### Roteiro (`.roteiro`)
1. **Arquivo:** um arquivo `.roteiro` pode ter vários eventos. Cada `=== id` começa um evento, que vira um `EventScript` com esse id.
2. **Sintaxe**, uma linha por instrução; `#` comenta e linhas vazias são ignoradas:

   | Linha | Vira |
   |---|---|
   | `Nome: texto` / `Nome [expr]: texto` | `SayStep` (speaker, text, portrait `expr`) |
   | `: texto` | `SayStep` de sistema (sem nome) |
   | `\| continua a fala` | junta à fala anterior com `\n` |
   | `Nome: pergunta?` seguido de `* opção -> rótulo` (1 a 4) | `ChoiceStep` + desvios gerados |
   | `== rótulo` | `LabelStep` |
   | `-> rótulo` / `-> fim` | `GotoStep` (`fim` é um rótulo implícito no fim do evento) |
   | `? flag == N -> rótulo` (também `!=`, `>=`, `<=`, `>`, `<`) | `IfFlagStep` com o desvio invertido gerado |
   | `? item erva_teste [N] -> rótulo` | `IfItemStep` |
   | `? dinheiro >= N -> rótulo` | um passo novo `IfMoneyStep`, se ainda não existir |
   | `@flag nome` | declara uma flag (só validação) |
   | `@set flag N` / `@add flag N` | `SetFlagStep` / `AddFlagStep` |
   | `@give item id [N]` / `@give equip id [N]` / `@give moedas N` | `GiveItemStep` / `GiveEquipmentStep` / `GiveMoneyStep` |
   | `@take item id [N]` | `TakeItemStep` |
   | `@xp N [ativos\|todos]` | `GrantXpStep` |
   | `@ensinar heroi habilidade` | `TeachStep` |
   | `@curar [pct]` | `HealStep` |
   | `@recrutar heroi [nivel N]` | `RecruitStep` |
   | `@batalha encontro` | `StartBattleStep` |
   | `@mover ator marcador [velocidade]` / `@camera marcador` | `MoveActorStep` / `CameraToStep` |
   | `@esperar s` | `WaitStep` |
   | `@fim_demo` | `EndDemoStep` |

3. **Ids** resolvem pelos `.tres` de `res://data/` (itens, equipamentos, heróis, encontros, habilidades), por id, com o mesmo registro do save (`SaveStore.build_registry` ou equivalente). Um id inexistente é erro.
4. **Erros** com arquivo e linha (`cidade.roteiro:12: rótulo 'aceita' não existe`). Também são erros:
   - rótulo repetido;
   - rótulo inexistente;
   - escolha sem opções ou com mais de 4;
   - flag usada sem `@flag`, como aviso no editor e erro no validador estrito.
5. **Compilador puro** (`core/script/roteiro_compiler.gd`): recebe texto e devolve `{events: Dictionary[StringName, EventScript], errors: Array, warnings: Array}`. Sem Node e sem IO, para ser testável.
6. **Importador** (`addons/vat_editor/roteiro_importer.gd`, `EditorImportPlugin`): cada `.roteiro` importado vira um recurso `RoteiroBook` (Resource com `events: Dictionary[StringName, EventScript]`).
   - Os nós que hoje recebem um `EventScript` (NPC, placa, gatilho, baú, lojista, pousada) ganham, como alternativa, `roteiro: RoteiroBook` + `event_id: StringName`.
   - Se os dois estiverem definidos, vale o roteiro.
   - Os `.tres` de evento antigos continuam funcionando.
7. **Migração:** os 14 eventos da fatia viram `data/fatia/roteiro/*.roteiro`, por mapa: `cidade.roteiro`, `casas.roteiro` e `dungeon.roteiro`. Os mapas apontam para eles, e os `.tres` antigos saem.
   - Um teste compila cada `.roteiro` da fatia e confere passo a passo que dá o mesmo que os `.tres` antigos antes de apagá-los.
   - Os testes da fatia e a demo continuam passando.
8. **Checagem fora do editor:** `tools/roteiro/check.gd` (`-s`, headless) compila todos os `.roteiro` e sai com código ≠ 0 se houver erro. Ele entra no `run_tests.ps1` como mais um teste.

### Arte
9. **Import de pixel art:**
   - `project.godot` passa a ter filtro de textura padrão *Nearest* e snap 2D de transformações e vértices;
   - um preset de importação em `art/` (sem mipmaps, sem filtro);
   - um teste confere essas configurações.
10. **Pastas:**

    | Pasta | Conteúdo |
    |---|---|
    | `art/characters/<id>/` | `map.png`, `battle.png`, `portraits/<expr>.png` |
    | `art/enemies/<id>/` | `battle.png`, e `map.png` se andar no mapa |
    | `art/npcs/<id>/` | `map.png`, `portraits/<expr>.png` |
    | `art/tiles/` | tilesets |
    | `art/ui/` e `art/icons/` | — |

11. **`SpriteSet`** (Resource, `core/defs/sprite_set.gd`):
    - **mapa:** `map_sheet: Texture2D` e `map_frame: Vector2i = (32, 48)`. Linhas na ordem baixo, esquerda, direita, cima; `walk_frames = 3` e `walk_fps = 8`; o quadro do meio é o parado;
    - **batalha:** `battle_sheet` e `battle_frame = (64, 64)`. As animações vêm de uma tabela `anims: Dictionary[StringName, Vector3i]` (linha, quadros, fps): `idle`, `attack`, `cast`, `hit`, `down`, `victory`. Laço só em `idle` e `victory`;
    - **retratos:** `portraits: Dictionary[StringName, Texture2D]` (`neutro`, `feliz` …) e `portrait_size = (96, 96)`.
    - Tudo opcional. O que faltar cai no desenho geométrico de hoje, então nada quebra sem arte.
12. **Quem usa:**
    - `CharacterDef.sprites`, `EnemyDef.sprites` e `SpeakerDef` (novo: `id`, `display_name`, `sprites`), para NPCs e para os retratos de quem não é herói;
    - no mapa, o jogador, os seguidores, os NPCs e os inimigos do mapa desenham um `AnimatedSprite2D` montado do `SpriteSet`. A direção vem do movimento, e o quadro é ancorado nos pés;
    - na batalha, o `CombatantView` toca `idle`, `attack`/`cast` ao agir, `hit` ao sofrer, `down` ao cair e `victory` no fim. Os HUDs e popups não mudam de lugar.
13. **Retrato no diálogo:**
    - `SayStep.portrait: StringName`, e o falante resolve pelo nome: herói pelo `display_name`, ou `SpeakerDef` pelo `id`/`display_name`;
    - a `DialogueBox` mostra o retrato 96×96 à esquerda quando ele existe; sem retrato, fica igual a hoje;
    - no roteiro, `Morador C [feliz]: …`.
14. **Arte de exemplo:** um herói (Teste A) e um inimigo com folhas placeholder geradas por script, com blocos coloridos e números de quadro, para provar o pipeline. Ficam em `art/_exemplo/` e são marcadas como placeholder.

### Tiles
15. **Tileset placeholder:** `art/tiles/placeholder_32.png`, gerado por script, com as camadas de física e os terrenos de autotile. Cada tile tem uma cor sólida e um rótulo pequeno:

    | Tile | Colisão |
    |---|---|
    | chão | não |
    | caminho | não |
    | grama | não |
    | parede | sim |
    | água | sim |
    | piso interno | não |
    | parede interna | sim |
    | escada | não |
    | ponte | não |
16. **Migração dos 7 mapas** (cidade, casa_1, casa_2, overworld_fatia, estrada, dungeon_1, dungeon_2):
    - cada `LocalMap` ganha `TileMapLayer`s `Chão` e `Paredes` (mais `Decoração`, vazia, para o usuário);
    - as paredes e a água em retângulos (`StaticBody2D` + `RectangleShape2D`) viram tiles com colisão;
    - os nós de jogo (NPCs, portas, baús, `MapLink`, marcadores, zonas, obstáculos, arenas) não mudam de posição;
    - o desenho dos retângulos coloridos sai;
    - um teste de varredura confere que, para cada mapa, os pontos onde havia parede continuam bloqueados e os spawns e caminhos continuam livres, amostrando pontos e passagens. A demo continua terminando.
    - O overworld usa o mesmo tileset (água e grama).

### Plugin do editor (`addons/vat_editor/`)
17. **Aba "VAT" no editor** (main screen plugin), com:
    - **Banco de dados:** abas Heróis, Inimigos, Habilidades, Itens, Equipamentos, Encontros, Lojas, Estados, Elementos, Reações, Terrenos, Falantes. Cada aba tem a lista dos `.tres` da pasta, busca, colunas-chave (id, nome, nível/preço/elemento), e mostra o selecionado no Inspector do Godot;
    - **Novo:** cria um `.tres` a partir de um modelo (cópia de um existente ou um modelo vazio por tipo), pedindo id e pasta (`data/fatia/...` por padrão);
    - **Duplicar** e **Abrir no FileSystem**;
    - **Validar tudo:** roda os validadores e lista os erros e avisos, clicáveis (abre o recurso ou o `.roteiro` na linha);
    - **Roteiros:** lista os `.roteiro`, os eventos de cada um e os erros de compilação.
18. **Validadores** (puros, em `core/validate/`, usados pelo plugin e pelos testes):
    - ids únicos por tipo;
    - referências que existem;
    - no máximo 2 nativos;
    - a tabela de reações;
    - chefes imunes a Contagem e Petrificação;
    - eventos sem rótulo quebrado;
    - `SpriteSet` com tamanho de folha múltiplo do quadro e animações dentro da folha;
    - mapas sem `MapLink` para spawn inexistente (o teste de varredura de hoje vira validador);
    - aviso de herói ou inimigo sem arte (só aviso).
19. **Testar daqui:** botões "Jogar este mapa" (abre o jogo com `--start-map=<id> --spawn=<marker>` no perfil da fatia) e "Testar encontro" (`--battle=<encounter>` com o grupo da fatia num nível escolhido). Esses flags entram no `Game`, só para desenvolvimento, e são documentados.
20. **Fronteira:** o plugin é só do editor. O jogo exportado não depende dele, e o `core/` continua sem Node. A UI do plugin é fina e chama os validadores e o compilador puros.

## Global Constraints
- Restrições de sempre:
  - tipos estáticos;
  - `core/` sem `Node`, `Input` e IO;
  - código em inglês, UI em português;
  - manter o fim de linha de cada arquivo;
  - commitar os `.uid` e os `.import` necessários;
  - novos enums sempre no fim.
- **Sem arte, o jogo fica exatamente como hoje.** Todos os testes, `-Meta`, `-Fatia` e a `--demo-fatia` (seeds 1–5 e a padrão, `--quit-after 7500`) continuam passando.
- **Disco:** temporários, quadros e logs em `E:\Claude\vat\scratch\<task>\`, nunca no C:. Testes, demos e sims rodam **um de cada vez** (compartilham `user://`).
- As imagens placeholder são geradas por script (Python ou GDScript) e ficam pequenas.

## Review Focus
1. **Roteiro:** a gramática inteira; erros com linha; a equivalência com os 14 eventos antigos; escolhas e desvios gerados corretos. → Tasks 1–2.
2. **Importador e nós:** o roteiro tem prioridade sobre `.tres`; o reimport atualiza o jogo; nada quebra sem o plugin ativo no jogo exportado. → Task 2.
3. **Arte:** o fallback geométrico idêntico; a direção e as animações; os retratos; o pixel art sem borrão. → Tasks 3–4.
4. **Tiles:** as colisões equivalentes nos 7 mapas; os spawns livres; a demo. → Task 5.
5. **Plugin:** os validadores corretos e sem falso positivo nos dados atuais; nada roda no jogo. → Tasks 6–7.

---

### Task 1: Compilador do roteiro (Sonnet)
- **Files:** `core/script/roteiro_compiler.gd` (puro), `core/script/roteiro_book.gd`, `core/events/if_money_step.gd` (se não existir), `core/events/say_step.gd` (`portrait`), `core/events/event_runner.gd` (o `IfMoney`), `tests/test_roteiro_compiler.gd`.
- **Testes:** cada linha da tabela da decisão 2; escolhas com 2 e 4 opções; `fim` implícito; cada erro da decisão 4 com o número da linha; ids resolvidos; texto acentuado e `|`.
- Commit `feat(core): compilador do roteiro em texto`.

### Task 2: Importador, nós e migração dos eventos (Sonnet)
- **Files:** `addons/vat_editor/plugin.cfg`, `plugin.gd`, `roteiro_importer.gd`; `project.godot` (habilitar o plugin); os nós de evento em `world/` (`roteiro` + `event_id`); `data/fatia/roteiro/*.roteiro`; os mapas da fatia apontando para eles; `tools/roteiro/check.gd`; `run_tests.ps1` (se a checagem entrar como passo); `tests/test_roteiro_migration.gd`.
- Primeiro o teste de equivalência contra os `.tres`; depois a troca; depois os `.tres` antigos saem.
- Commit `feat(tools): roteiros .roteiro importados e eventos da fatia migrados`.

### Task 3: SpriteSet, import de pixel art e arte no mapa (Sonnet)
- **Files:** `core/defs/sprite_set.gd`, `core/defs/speaker_def.gd`, `CharacterDef`/`EnemyDef` (`sprites`), `project.godot` (filtro e snap), `world/player.gd`, `world/party_followers.gd`, `world/npc.gd`, os inimigos do mapa, `art/_exemplo/` (as folhas geradas e o script gerador em `tools/art/`), `tests/test_sprite_set.gd`.
- Verificação visual: capturas do mapa com o Teste A animado em 4 direções e um NPC com arte, em E:.
- Commit `feat(art): spriteset, pixel art e sprites no mapa`.

### Task 4: Arte na batalha e retratos (Sonnet)
- **Files:** `battle/combatant_view.gd` (o `AnimatedSprite2D` e os estados de animação), `battle/battle_scene.gd` (os gatilhos), `ui/dialogue_box.gd` (o retrato), `core/events/event_runner.gd`/`event_request.gd` (o retrato no pedido de fala), `tests/test_battle_art.gd`, `tests/test_dialogue_portrait.gd`.
- Verificação visual: uma batalha com o herói e o inimigo de exemplo (idle, attack, hit, down) e um diálogo com retrato, em E:.
- Commit `feat(art): sprites de batalha animados e retratos no dialogo`.

### Task 5: Tileset e migração dos mapas (Sonnet)
- **Files:** `art/tiles/placeholder_32.png` + `.tres` do TileSet (gerados por `tools/art/`), os 7 `world/fatia/*.tscn`, `world/local_map.gd` (se o desenho de fundo mudar), `tests/test_map_tiles.gd` (a varredura de colisão e spawns).
- Verificação visual: uma captura de cada mapa, em E:. A demo termina nas seeds 1–5 e na padrão.
- Commit `feat(world): mapas da fatia em tiles 32x32`.

### Task 6: Validadores e flags de teste (Sonnet)
- **Files:** `core/validate/*.gd` (as regras da decisão 18), `world/game.gd` (`--start-map`, `--spawn`, `--battle`, `--level`), `tests/test_validators.gd` (sem erro nos dados atuais; cada regra pega um caso quebrado em memória), `tests/test_dev_flags.gd`.
- Commit `feat(tools): validadores de conteudo e flags de teste`.

### Task 7: Painel do editor (Sonnet)
- **Files:** `addons/vat_editor/` (a tela principal, as abas do banco, Novo/Duplicar, Validar tudo, Roteiros e os botões de teste); os modelos em `addons/vat_editor/templates/`; `tests/test_editor_logic.gd` (a lógica pura do plugin: listagem por pasta, a criação a partir de modelo com id novo, a formatação dos resultados do validador).
- Verificação: abrir o editor headless não dá erro de script (`godot --headless --editor --quit`). Uma captura do editor com a aba VAT, se for possível rodar com janela; se não for, a revisão documenta os passos manuais.
- Commit `feat(tools): painel VAT no editor do Godot`.

### Task 8: Guia de criação e documentação (Haiku)
- `docs/guia-criacao.md` (novo), um passo a passo em português:
  - escrever um diálogo e uma escolha no roteiro e ligar a um NPC;
  - criar um item, um inimigo e um encontro pelo painel VAT;
  - pôr arte num herói (as folhas, os tamanhos, as linhas e as animações) e um retrato;
  - pintar um mapa com o tileset e trocar o tileset placeholder pelo seu;
  - validar e testar um mapa ou encontro pelo painel.
- `docs/roteiro.md` (novo): a referência completa da sintaxe, com exemplos da fatia.
- README: uma seção "Criando conteúdo (M16)" com os links.
- `roadmap.md`: M16 concluído, e próximos passos em aberto para o usuário (história, arte final, áudio, mais mapas).
- Commit `docs: M16 guia de criacao e roteiro`.

**Ordem de execução:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → revisão final e Task 8 em paralelo.
- A Task 5 pode ir em paralelo à 3–4 só se for num agente separado sem tocar `world/player.gd`/`npc.gd`. Por segurança, vai em sequência.
- O fim de linha do `run_tests.ps1` e do `project.godot` deve ser mantido.

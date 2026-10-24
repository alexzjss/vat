# M17 — Editores visuais no painel VAT: plano de implementação

> Execução: Sonnet implementa, Haiku documenta, uma revisão final do Sonnet e merge ff local. Decisões do usuário [U] da rodada 7 (2026-10-24, abaixo). O resto é decisão do designer [I]. Nenhum conteúdo narrativo é inventado.

**Goal:** criar roteiro, mapa e conteúdo **por interface**, dentro do editor do Godot, sem escrever texto nem código:
- um editor de blocos para os eventos;
- um assistente de mapa novo, uma paleta de objetos, ligações escolhidas em lista e um grafo do mundo;
- formulários próprios para heróis, inimigos, encontros, lojas/itens e arte.

O texto `.roteiro` e o Inspector continuam valendo. Os editores gravam os mesmos arquivos.

## Decisões do usuário [U] (rodada 7)
- **Roteiro:** editor visual de **blocos** dentro do painel VAT. Ele lê e grava o mesmo `.roteiro`.
- **Mapas:** os quatro recursos:
  - assistente "Novo mapa";
  - paleta de objetos;
  - ligar mapas visualmente;
  - "mapa do mundo" com as ligações.
- **Formulários:** heróis e progressão; inimigos e encontros; lojas e itens; arte (`SpriteSet`) com prévia.
- **Onde:** dentro do editor do Godot, expandindo o painel VAT.

## Decisões de design [I]

### Base comum
1. **Lógica pura e UI fina**, como no M16:
   - a lógica fica em `addons/vat_editor/logic/` (testável headless) e a UI em `addons/vat_editor/ui/`;
   - o jogo nunca carrega nada do addon. O teste de fronteira do M16 continua valendo.
2. **Widgets compartilhados** (`ui/widgets/`):
   - `ResourcePicker`: lista por tipo, vinda do `ContentIndex`, com busca e "(nenhum)";
   - `ElementDictEditor` e `StatusDictEditor`: chave escolhida em lista, valor em %, com o sinal explicado;
   - `ListEditor`: adicionar, remover, subir, descer e duplicar;
   - `StatsEditor`: os 4 atributos;
   - `SpritePreview`: uma `SubViewport` com `AnimatedSprite2D` tocando.
3. **Salvar:** os formulários editam a mesma instância do Resource (o Inspector fica em sincronia) e só gravam com **Salvar** (`ResourceSaver`).
   - Um indicador de "não salvo" avisa ao trocar de item.
   - As ações estruturais (criar um mapa, colocar um objeto) usam o `EditorUndoRedoManager`, para o Ctrl+Z funcionar na cena.
4. **Validação ao vivo:** cada editor mostra os erros do que está aberto, usando os checks puros do M16 (`ContentChecks`, `MapChecks`, `RoteiroCompiler`), sem rodar o processo inteiro.

### Roteiro em blocos
5. **Modelo `RoteiroDoc`** (puro, `core/script/roteiro_doc.gd`): um arquivo é uma lista de eventos, e cada evento é uma lista de blocos. Cada tipo de bloco corresponde a uma linha da sintaxe do M16:
   - **Texto:** Fala (falante, expressão, texto com várias linhas), Sistema, Comentário;
   - **Fluxo:** Escolha (pergunta, falante, expressão, opções → rótulo), Rótulo, Ir para;
   - **Condições:** Se flag (flag, op, valor → rótulo), Se item, Se dinheiro;
   - **Flags:** Definir flag, Somar flag, Declarar flag;
   - **Itens e dinheiro:** Dar item, Dar equipamento, Dar moedas, Tirar item;
   - **Grupo:** XP, Ensinar, Curar, Recrutar;
   - **Ações:** Batalha, Mover, Câmera, Esperar, Fim da demo.
   - O parser é `RoteiroDoc.parse(text)` e o serializador é `RoteiroDoc.to_text(doc)`, num formato canônico estável. Os comentários viram blocos Comentário, e as linhas em branco entre blocos se preservam como separador.
   - **Ida e volta:**
     - `to_text(parse(t))` compila para o mesmo resultado que `t`;
     - nos 3 `.roteiro` da fatia, o texto canônico é igual ao arquivo, ou o arquivo é regravado uma vez no formato canônico e o teste de equivalência (o golden do M16) continua passando.
6. **Editor de blocos** (aba Roteiros, que passa a ter Lista e Editor):
   - à esquerda ficam os arquivos e os eventos (Novo arquivo, Novo evento, Renomear, Apagar evento);
   - no centro ficam os blocos do evento, um cartão por bloco, com campos e menus;
   - **menus que vêm dos dados:**
     - itens, equipamentos, heróis, encontros e habilidades vêm do `ContentIndex`;
     - os falantes são os heróis e os `SpeakerDef`;
     - as expressões são as chaves de `portraits` do falante;
     - as flags são as declaradas e as usadas no projeto inteiro, mais "nova flag…";
     - os rótulos são os do evento, mais `fim`;
     - os marcadores e atores vêm da cena onde o evento é usado, quando se sabe qual é; senão, um campo de texto;
   - **"+ Adicionar bloco"** com um menu por categoria; arrastar para reordenar; Duplicar; Apagar;
   - os erros e avisos do compilador aparecem ao vivo no rodapé, e cada um destaca o seu bloco;
   - **Salvar** grava o `.roteiro` e reimporta; **Ver texto** mostra o texto gerado (só leitura, com cópia).
7. **Simular evento** (aba Roteiros):
   - roda o evento num `GameState` de teste com o `EventRunner` real;
   - o usuário marca as flags e os itens iniciais e escolhe as respostas das escolhas (ou deixa "perguntar");
   - mostra a transcrição: falas, escolhas, itens dados, flags no fim, batalha "iniciaria aqui".
   - É puro e headless, e serve para testar a missão sem abrir o jogo.

### Mapas
8. **Registro de mapas pelos dados:**
   - `MapDef` (Resource: `id`, `display_name`, `scene: PackedScene`, `kind` cidade/interior/masmorra/mundo, `exit_spawn` opcional) e `MapRegistry` (`data/maps/registro.tres`, com a lista dos `MapDef`);
   - o `Game` monta `maps` a partir do registro, no lugar da constante `MAPS`;
   - o `EXIT_SPAWNS` vira o `MapDef.exit_spawn`;
   - os mapas de teste (`overworld`, `area_teste`, `dungeon_teste`) também entram no registro;
   - os testes que injetam mapas continuam podendo;
   - os validadores e a aba Testar passam a ler o registro.
9. **Assistente "Novo mapa"** (aba Mapas):
   - pede id, nome, tipo, tamanho em tiles e tile base;
   - cria a cena a partir de um modelo por tipo (`addons/vat_editor/templates/maps/*.tscn`):
     - o `LocalMap` ou `Overworld`;
     - as camadas `Chão`, `Paredes` e `Decoração` com o tileset, o chão preenchido e a borda de parede;
     - a câmera com limites, o `Player`, os `PartyFollowers` e os marcadores `Start`/`Entry`;
     - uma `BattleArena` nos tipos que têm batalha;
   - grava em `world/mapas/<id>.tscn`, registra no `MapRegistry` e abre a cena no editor.
10. **Prefabs** (`world/prefabs/*.tscn`):
    - um por objeto de jogo, já montado com colisão e rótulo: NPC, Placa, Porta/Ligação (`MapLink`), Baú, Ponto de descanso, Loja (`ShopKeeper`), Pousada, Inimigo do mapa, Obstáculo elemental, Portão de flag, Gatilho de evento, Marcador de spawn, Zona (mapa-múndi), Armadilha;
    - os prefabs reusam os scripts de hoje, sem lógica nova;
    - os nós da fatia não precisam ser convertidos.
11. **Paleta de objetos** (um dock no editor 2D, visível quando a cena aberta é um mapa):
    - botões com ícone e nome; clicar coloca o prefab no centro da vista, ou no último clique, alinhado à grade de 32, já selecionado e com undo;
    - também tem **"Ajustar à grade"** e **"Renomear com id"**.
12. **Escolhas em lista no Inspector** (`EditorInspectorPlugin`):
    - `MapLink.target_map`/`target_spawn` e as `Zone`: menus com os mapas do registro e os marcadores do mapa de destino;
    - `roteiro` + `event_id`: menus com o livro e os eventos dele, mais o botão "Abrir no editor de blocos";
    - os encontros de inimigos do mapa e das arenas, os falantes e as lojas: `ResourcePicker`;
    - o resto do Inspector continua igual.
13. **Grafo do mundo** (aba Mundo, `GraphEdit`):
    - um nó por mapa do registro, com o tipo e o número de pontos de entrada;
    - as setas vêm de `MapLink`, `Zone` e saídas, com o rótulo do ponto de entrada;
    - uma ligação quebrada aparece em vermelho, com a mensagem;
    - clique duplo abre a cena;
    - as posições dos nós ficam gravadas num arquivo do editor (`addons/vat_editor/mundo_layout.cfg`), para o layout não se perder.

### Formulários (aba Banco, painel à direita da lista)
14. **Herói:**
    - id, nome e atributos base;
    - os elementos nativos (até 2) e as resistências elementais e a estados;
    - o ataque básico, o Limite e os tipos de arma;
    - o equipamento inicial;
    - as técnicas por nível numa tabela (nível × habilidade, com flag "só por evento" se o `LearnEntry` tiver);
    - a arte, com a prévia do `SpriteSet`.
15. **Inimigo:**
    - atributos, nível, XP, moedas e nativos;
    - as afinidades e as resistências e imunidades a estados;
    - as habilidades;
    - as **regras de IA** numa lista (condição, limiar, habilidade, alvo, chance e anúncio), em ordem;
    - os drops numa tabela;
    - as fases de chefe, o contra-ataque e o papel (núcleo/parte);
    - a arte.
16. **Encontro:**
    - a lista de inimigos (adicionar com o `ResourcePicker`), as flags (único, sem fuga) e a prévia em texto da formação;
    - "Testar encontro" já com esse encontro escolhido.
17. **Loja e itens:** a loja é uma tabela editável de itens e equipamentos, com preço, venda calculada e quem pode vestir. Os itens e equipamentos são formulários curtos (preço, efeitos e modificadores).
18. **Editor de `SpriteSet`:**
    - escolher as folhas (mapa e batalha), o tamanho do quadro, os quadros e o fps do mapa;
    - a tabela de animações de batalha (linha, quadros, fps), com a prévia tocando cada uma;
    - a grade de retratos (expressão → textura), com prévia;
    - um aviso ao vivo do `SpriteSet.validate()`;
    - **"Criar a partir de uma imagem"**: escolher um PNG, sugerir os quadros pelo tamanho e montar o `SpriteSet`.

## Global Constraints
- **Restrições de sempre:**
  - tipos estáticos;
  - `core/` sem `Node`, `Input` e IO;
  - código em inglês e UI em português;
  - o fim de linha de cada arquivo é mantido (o `.gitattributes` do M16 cobre `.import`/`.uid`/`.roteiro`);
  - commitar os `.uid`.
- **Nada muda no jogo** fora da troca `MAPS` → `MapRegistry`, que precisa ser equivalente. Os testes, `-Meta`, `-Fatia` e a `--demo-fatia` (seeds 1–5 e a padrão, `--quit-after 7500`) continuam passando.
- **Disco:** temporários, quadros e logs em `E:\Claude\vat\scratch\<task>\`. Testes, demos e sims rodam um de cada vez. O editor com janela reescreve o `project.godot`: reverta o que não for intencional.
- **Verificação visual** com o gancho `--vat-capture=<png> --vat-tab=<aba>` do M16, estendido às abas e subpainéis novos.

## Review Focus
1. **Ida e volta do roteiro:** nada se perde ou muda de sentido ao abrir e salvar no editor de blocos; os comentários se preservam; o golden do M16 continua passando. → Tasks 1–2.
2. **`MapRegistry`:** é equivalente ao `MAPS` e ao `EXIT_SPAWNS` antigos; nenhum teste ou demo muda. → Task 3.
3. **Cenas criadas:** o mapa do assistente e os prefabs passam no validador e na varredura de mapas sem ajuste manual; o undo funciona. → Tasks 4–5.
4. **Formulários:** gravam só no Salvar; não corrompem `.tres` (campos tipados, dicionários tipados, sub-resources). → Tasks 7–8.
5. **Fronteira:** o jogo exportado não referencia o addon. → todas.

---

### Task 1: Modelo do roteiro e ida e volta (Sonnet)
- **Files:** `core/script/roteiro_doc.gd` (o modelo, `parse`, `to_text`), `tests/test_roteiro_doc.gd`.
- **Testes:**
  - cada tipo de bloco nas duas direções;
  - os comentários e as linhas em branco;
  - os 3 arquivos da fatia: `to_text(parse)` compila igual;
  - texto acentuado e `|`.
- Se o formato canônico diferir dos arquivos atuais, regravar os 3 uma vez, e o golden do M16 tem que continuar passando.
- Commit `feat(core): modelo de blocos do roteiro com ida e volta`.

### Task 2: Editor de blocos e simulador (Sonnet)
- **Files:** `addons/vat_editor/ui/roteiro_editor.gd` (+ os cartões de bloco), `addons/vat_editor/logic/roteiro_options.gd` (as listas dos menus), `core/script/event_simulator.gd` (puro: roda e transcreve), `addons/vat_editor/ui/event_simulator_panel.gd`, a integração em `vat_panel.gd`; `tests/test_roteiro_editor_logic.gd`, `tests/test_event_simulator.gd`.
- **Verificação visual:** capturas do editor de blocos com o `morador_c` aberto e do simulador numa rodada da missão.
- Commit `feat(tools): editor de blocos do roteiro e simulador de eventos`.

### Task 3: Registro de mapas pelos dados (Sonnet)
- **Files:** `core/defs/map_def.gd`, `core/defs/map_registry.gd`, `data/maps/registro.tres` + os `MapDef`, `world/game.gd` (`maps` vindo do registro; `EXIT_SPAWNS` → `exit_spawn`), os validadores e a aba Testar, `tests/test_map_registry.gd`.
- **Testes:** equivalência com o `MAPS` e o `EXIT_SPAWNS` antigos (lista fixa no teste); os testes de mapa e a demo iguais.
- Commit `feat(world): registro de mapas em dados`.

### Task 4: Prefabs e assistente de mapa novo (Sonnet)
- **Files:** `world/prefabs/*.tscn`, `addons/vat_editor/templates/maps/*.tscn`, `addons/vat_editor/logic/map_wizard.gd` (puro: valida o id e monta as células do chão e da borda), `addons/vat_editor/ui/map_wizard_dialog.gd`, `tests/test_map_wizard.gd`.
- **Testes:**
  - o mapa criado, para cada tipo, passa no validador e na varredura do `TileGrid` (spawn livre, borda fechada);
  - cada prefab instanciado passa nos checks e tem a colisão e os campos esperados.
- Commit `feat(tools): prefabs e assistente de mapa novo`.

### Task 5: Paleta de objetos e escolhas no Inspector (Sonnet)
- **Files:** `addons/vat_editor/ui/object_palette.gd` (o dock), `addons/vat_editor/inspector/*.gd` (o `EditorInspectorPlugin`: `MapLink`/`Zone`, `roteiro`/`event_id` e os pickers), `addons/vat_editor/logic/palette.gd` (a posição na grade, os nomes únicos), `tests/test_palette_logic.gd`.
- **Verificação visual:** a paleta com um mapa aberto, e o Inspector de um `MapLink` com os menus.
- Commit `feat(tools): paleta de objetos e escolhas em lista no inspector`.

### Task 6: Grafo do mundo (Sonnet)
- **Files:** `addons/vat_editor/logic/world_graph.gd` (puro: os nós e as arestas a partir do registro e das cenas, e as ligações quebradas), `addons/vat_editor/ui/world_graph_panel.gd`, `tests/test_world_graph.gd`.
- **Verificação visual:** o grafo com os mapas da fatia.
- Commit `feat(tools): grafo do mundo com as ligacoes entre mapas`.

### Task 7: Widgets e formulários de herói, inimigo e encontro (Sonnet)
- **Files:** `addons/vat_editor/ui/widgets/*.gd`, `addons/vat_editor/ui/forms/{hero,enemy,encounter}_form.gd`, `addons/vat_editor/logic/forms.gd` (puro: ler e escrever os campos, validar), `tests/test_forms_logic.gd`.
- **Testes:** gravar e recarregar cada tipo sem perder campos (dicionários e arrays tipados, sub-resources de Stats e `AiRule`).
- **Verificação visual:** cada formulário com dados da fatia.
- Commit `feat(tools): formularios de heroi, inimigo e encontro`.

### Task 8: Lojas, itens e editor de SpriteSet (Sonnet)
- **Files:** `addons/vat_editor/ui/forms/{shop,item,equipment,sprite_set}_form.gd`, `addons/vat_editor/logic/sprite_wizard.gd` (puro: sugerir os quadros a partir do tamanho da imagem), `tests/test_sprite_wizard.gd`, `tests/test_forms_logic.gd` (mais casos).
- **Verificação visual:** a loja da fatia na tabela, e o `SpriteSet` do Teste A com a prévia.
- Commit `feat(tools): lojas, itens e editor de spriteset com previa`.

### Task 9: Documentação (Haiku)
- `docs/guia-criacao.md`: refazer o passo a passo pela UI (editor de blocos, simulador, Novo mapa, paleta, ligações, grafo, formulários e editor de arte). O texto `.roteiro` fica como alternativa avançada.
- `docs/roteiro.md`: uma nota de que o editor de blocos grava no formato canônico.
- README e `roadmap.md`: M17 concluído.
- Commit `docs: M17 editores visuais`.

**Ordem de execução:** 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → revisão final e Task 9 em paralelo.

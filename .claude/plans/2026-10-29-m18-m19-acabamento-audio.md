# M18 — Acabamento do editor e autotile · M19 — Áudio: plano de implementação

> Execução: Sonnet implementa, Haiku documenta, uma revisão final do Sonnet e merge ff local, por marco. Decisões do usuário [U] da rodada 8 (2026-10-29): fazer o **acabamento do editor**, o **autotile** e o **áudio** (nessa ordem). O resto é decisão do designer [I]. Os arquivos de som e a arte final são do usuário: o código deixa **placeholders** gerados por script.

## Regras comuns
- Tipos estáticos; `core/` sem `Node`, `Input` e IO; código em inglês, UI em português; manter o fim de linha de cada arquivo; commitar `.uid`.
- **Disco:** temporários, quadros e logs em `E:\Claude\vat\scratch\<task>\`. Testes, demos e sims rodam um de cada vez. Reverter o `project.godot` reescrito pelo editor com janela. `git status` limpo no fim de cada task.
- A suíte, `-Meta`, `-Fatia` e a `--demo-fatia` (seeds 1–5 e a padrão, `--quit-after 7500`) continuam passando. Sem áudio configurado, o jogo fica **idêntico** ao de hoje.
- Fronteira: o jogo exportado não referencia `addons/vat_editor`.

---

# M18 — Acabamento do editor e autotile

## Decisões de design [I]
1. **Reordenar blocos arrastando** (`addons/vat_editor/ui/block_card.gd`, `roteiro_editor.gd`): arrastar o título do cartão e soltar entre outros. A lógica fica em `roteiro_editor_logic.gd` (`move_block(from, to)` já existe no modelo). As setas continuam. Um teste cobre mover para cima, para baixo, para o início e o fim, e que o texto gerado compila igual depois de mover um bloco que não é de fluxo.
2. **Marcadores automáticos:** ao colocar `pousada` ou `ponto_descanso` pela paleta, a mesma ação (um só Ctrl+Z) coloca o `InnSpawn`/`RestSpawn` ao lado, 64 px abaixo, com nome único se já existir. Se o mapa já tem um marcador com esse nome, não cria outro. Lógica pura em `palette.gd`.
3. **Formulário de herói compacto:** grupos recolhíveis (Identidade, Atributos, Afinidades, Técnicas, Arte), todos abertos por padrão exceto Afinidades e Arte, com o estado salvo em `ConfigFile` do editor. Salvar e Reverter continuam fixos no topo. O mesmo para o formulário de inimigo (Afinidades, IA, Drops, Fases).
4. **Autotile.**
   - O TileSet placeholder ganha **um terrain set** (modo "combinar lados") com 4 terrenos: Grama, Caminho, Parede e Água, e para os interiores Piso e Parede interna. Cada tile base recebe os bits de vizinhança do seu terreno, então pintar com a ferramenta de terreno do Godot funciona hoje com os tiles sólidos, e a arte final só acrescenta as variantes de borda e canto nas mesmas coordenadas.
   - `gen_tileset.py` gera o terrain set no `.tres`. O README de tiles explica como acrescentar os tiles de transição (a tabela de bits) e como pintar (aba Terrenos do editor de TileMap).
   - **Nada migra:** os mapas da fatia continuam como estão. O assistente "Novo mapa" passa a pintar o chão e a borda **por terreno** (`set_cells_terrain_connect`), e o teste confere que o resultado é igual ao de antes nos tiles escolhidos.
   - Um teste confere o terrain set (4+ terrenos, bits coerentes, um tile por terreno) e que `set_cells_terrain_connect` headless produz as mesmas células sólidas/livres que a pintura manual.
5. **Sobras pequenas:** o botão "Atualizar" do editor de blocos também limpa o índice de conteúdo em cache; o `_input` do plugin ignora cliques em janelas flutuantes.

## Tasks
- **Task 1:** reordenar por arrastar (decisão 1), marcadores automáticos (2) e as sobras (5). Commit `feat(tools): arrastar blocos, marcadores automaticos e sobras do editor`.
- **Task 2:** formulários compactos (3). Commit `feat(tools): formularios com grupos recolhiveis`.
- **Task 3:** autotile (4). Commit `feat(tools): terrenos de autotile no tileset e no assistente de mapa`.
- **Task 4 (Haiku):** `docs/guia-criacao.md` (arrastar, marcadores, grupos, autotile e como acrescentar transições), `art/tiles/README.md`, README e roadmap (M18 concluído). Commit `docs: M18 acabamento e autotile`.
- Revisão final do Sonnet e a Task 4 em paralelo.

---

# M19 — Áudio

## Decisões de design [I]
6. **Barramentos** (`default_bus_layout.tres`): `Master` → `Música`, `Efeitos`, `Interface`. O volume do `Master` continua vindo de `GameSettings.volume`. A Config ganha **Volume da música** e **Volume dos efeitos** (0–10, mesmos limites do `BalanceConfig`), salvos com a Config e aplicados nos barramentos. A interface fica no volume dos efeitos.
7. **Dados:**
   - `SoundDef` (Resource): `id`, `display_name`, `stream: AudioStream`, `volume_db`, `pitch_variation`, `bus` (Efeitos ou Interface), `cooldown` (s). Uma lista `data/audio/sons.tres` (`SoundBank`) indexa por id.
   - `MusicDef` (Resource): `id`, `display_name`, `stream`, `volume_db`, `loop`, `intro_end` (opcional).
   - Campos novos, todos opcionais: `MapDef.music`; `EncounterDef.music` (nulo = a música de batalha padrão); `BalanceConfig.default_battle_music` e `victory_jingle`, `defeat_jingle`; `AbilityDef.sfx_cast` e `sfx_impact`; `ItemDef.sfx_use`; `EnemyDef.sfx_hit`/`sfx_down` e o mesmo em `CharacterDef`; `ElementDef.sfx_hit`; `ReactionDef.sfx`; `StatusDef.sfx_apply`.
   - Tudo nulo = silêncio, como hoje.
8. **`AudioDirector`** (autoload `world/audio_director.gd`, o único nó que toca): `play_music(id, fade)`, `stop_music(fade)`, `play_sfx(id, position)`, `duck_music(db, s)`. A lógica de decisão (qual música toca onde, quando trocar, quando voltar) fica **pura** em `core/audio/audio_rules.gd`: dado o estado (mapa atual, batalha ativa, chefe, resultado, evento) devolve a lista de comandos. O diretor só executa.
   - Mapa: toca `MapDef.music` ao entrar, com fade de 0,5 s; manter a mesma música ao trocar entre mapas que usam o mesmo `MusicDef`, sem reiniciar.
   - Batalha: guarda a música do mapa, troca para a da batalha, e ao fim toca o jingle e volta à do mapa (a posição não precisa ser retomada).
   - Eventos: novo passo `@musica id|parar [fade]` e `@som id` no roteiro, com `PlayMusicStep` e `PlaySoundStep`.
9. **Onde os sons disparam:** passos, menu (mover, confirmar, cancelar), caixa de diálogo (um tique por letra, desligável na Config), abrir baú e porta, uso de item, início e impacto da habilidade (`sfx_cast`/`sfx_impact`, ou o do elemento como reserva), acerto e queda do combatente, reação (`ReactionDef.sfx` e o do nome), estado aplicado, subida de nível, vitória e derrota. Cada gatilho passa por uma função pura `sound_for(evento, defs)` testada, que escolhe o id ou vazio.
10. **Placeholders:** `tools/audio/gen_placeholders.py` (stdlib, módulo `wave`) gera WAVs curtos e pequenos (bipes, estalos, um acorde de música em laço de poucos segundos) em `art/_exemplo/audio/`, e os `SoundDef`/`MusicDef` de exemplo ligados a: uma música de cidade e de masmorra, uma de batalha, uma de chefe, os jingles, e uma dúzia de efeitos. Marcados como placeholder em um README. Tudo cabe em poucos KB.
11. **Painel VAT:** novas categorias **Sons** e **Músicas** no Banco (formulário com o seletor de arquivo, volume e uma **prévia** que toca no editor); os campos de áudio aparecem nos formulários de mapa (aba Mapas), herói, inimigo, habilidade/encontro, com o seletor de som e o botão ▶. O validador ganha: som ou música referenciados que não existem, `stream` vazio (aviso), id repetido.
12. **Exportação:** `.ogg` e `.wav` importam como streams normais; `.import` com o mesmo tratamento de fim de linha do M16.

## Tasks
- **Task 1:** barramentos, `SoundDef`/`MusicDef`/`SoundBank`, `AudioRules` puro e `AudioDirector`, a Config com os dois volumes, o `GameSettings` com salvar e carregar (campos opcionais, save antigo carrega) e os testes (`AudioRules` por cenário; o diretor com um `AudioServer` real em modo headless, só checando estado: música tocando, barramento, volumes). Commit `feat(audio): barramentos, dados e diretor de audio`.
- **Task 2:** os campos opcionais nos defs (decisão 7) e a ligação dos gatilhos (decisão 9), com `sound_for` e os testes; os passos `PlayMusicStep`/`PlaySoundStep` e `@musica`/`@som` no compilador, no modelo de blocos (novos tipos no fim do enum) e no editor de blocos. Sem som configurado, nada muda nos dados de teste e da fatia. Commit `feat(audio): gatilhos de som e musica em mapas, batalha, menu e eventos`.
- **Task 3:** os placeholders gerados, os defs de exemplo e a fiação na fatia (música por mapa, batalha, chefe, jingles e efeitos), mais a verificação de que a demo e as metas continuam iguais (o áudio headless não pode alterar tempo de jogo). Commit `feat(fatia): audio placeholder na fatia`.
- **Task 4:** painel VAT: categorias Sons e Músicas com prévia, seletores nos formulários e na aba Mapas, validadores novos. Commit `feat(tools): sons e musicas no painel VAT`.
- **Task 5 (Haiku):** guia de criação (como trocar um som, como pôr música num mapa, formatos), README, roadmap (M19 concluído). Commit `docs: M19 audio`.
- Revisão final do Sonnet e a Task 5 em paralelo.

## Review Focus
1. **Sem áudio configurado nada muda:** `-Meta`, `-Fatia` e as demos idênticos; nenhum `AudioStreamPlayer` toca em headless nos testes antigos.
2. **`AudioRules`:** troca de música sem reinício quando é a mesma; volta correta após a batalha, inclusive após fuga, Game Over e eventos de chefe; fim de batalha durante uma troca de mapa.
3. **Save e Config:** os dois volumes novos nos arquivos antigos; limites; aplicação nos barramentos ao carregar.
4. **Editor:** prévia de som não vaza `AudioStreamPlayer` no editor; validadores sem falso positivo nos dados atuais.

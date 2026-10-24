# Guia de criação de conteúdo (M16)

Passo a passo para criar conteúdo sem mexer em código: diálogos num roteiro de texto, itens, inimigos e encontros pelo painel VAT, arte de personagem e mapas pintados com tiles. Tudo é placeholder hoje; a referência da sintaxe do roteiro está em [`roteiro.md`](roteiro.md).

Abra o projeto no Godot 4 (pasta `game/`). O plugin VAT já vem ativado. Na barra superior do editor aparece a aba **VAT**.

## (a) Diálogo com escolha num roteiro, ligado a um NPC

1. Crie um arquivo `.roteiro`, por exemplo `game/data/fatia/roteiro/minha_cidade.roteiro`. Ele é encontrado sozinho pelo importador; não precisa de cadastro.
2. Escreva um evento com `=== id` e as falas. Uma escolha é uma fala seguida de linhas `*`:

   ```
   # Textos placeholder.
   @flag viu_placa

   === morador_novo
   Morador X [neutro]: Texto de teste: quer ajuda?
   : Aceitar a ajuda?
   * Sim -> aceita
   * Não -> recusa
   == aceita
   @set viu_placa 1
   Morador X: Texto de teste: combinado.
   -> fim
   == recusa
   Morador X: Texto de teste: tudo bem, volte se mudar de ideia.
   ```

   `@flag` declara a flag do arquivo (sem ele, o compilador avisa). `== aceita` e `-> aceita` são o mesmo rótulo.
3. Salve. O Godot reimporta o `.roteiro`. Se houver erro, ele aparece no console com `arquivo.roteiro:linha: mensagem`, e a importação falha até você corrigir.
4. Ligue ao NPC: no mapa, selecione o NPC (um nó `Npc`, que é um `Interactable`). No Inspector:
   - `roteiro`: arraste o `.roteiro` do FileSystem (ele aparece como `RoteiroBook`);
   - `event_id`: `morador_novo`.
5. Teste: aba **VAT**, **Testar**, escolha o mapa do NPC e clique em **Jogar este mapa** (veja (e)).

## (b) Item, inimigo e encontro pelo painel VAT

O painel tem a aba **Banco**, com uma sub-aba por tipo: Heróis, Inimigos, Habilidades, Itens, Equipamentos, Encontros, Lojas, Estados, Elementos, Reações, Terrenos e Falantes. Cada uma lista os `.tres` da pasta, com busca e as colunas-chave.

Botões no topo do Banco:

- **Novo...**: pede um **id** e uma **pasta** (padrão: `res://data/fatia/<tipo>`). Cria o recurso a partir do modelo do tipo (`addons/vat_editor/templates/<tipo>.tres`), com o id novo, salvo como `<pasta>/<id>.tres`.
- **Duplicar...**: copia o recurso selecionado, com um id novo.
- **Mostrar no FileSystem** e **Atualizar**.

**Regra do id:** só letras minúsculas sem acento, números e `_`, começando por letra (`^[a-z][a-z0-9_]*$`). Exemplos válidos: `pocao_minha`, `inimigo_g1`. Inválidos: `Poção`, `1_item`, `inimigo g1`. Um id repetido no mesmo tipo é recusado.

O recurso selecionado abre no **Inspector** do Godot, onde você preenche os campos. As colunas do Banco mostram os principais:

| Tipo | Campos principais (no Inspector) |
|---|---|
| Itens | `price` (Preço), `key_item` (item-chave) |
| Inimigos | `level` (Nível), `xp_base` (XP) |
| Encontros | `enemies` (lista de inimigos), `can_flee` (fuga) |

Passo a passo:

1. **Item:** aba Itens, **Novo...**, id `pocao_minha`, pasta padrão. No Inspector, ajuste o preço. Para o roteiro dar o item, use `@give item pocao_minha`.
2. **Inimigo:** aba Inimigos, **Novo...**, id `inimigo_g1`. Ajuste `level` e `xp_base`.
3. **Encontro:** aba Encontros, **Novo...**, id `enc_g1`. Em `enemies`, adicione `inimigo_g1` (pelo id).
4. **Usar no roteiro:** `@batalha enc_g1` começa a luta; `? item pocao_minha -> ...` testa se o grupo tem o item.

Lembrete: se você renomear um id que um `.roteiro` usa, reimporte o `.roteiro` (veja `roteiro.md`, seção Importação).

## (c) Arte de personagem

Tudo é opcional: o que faltar cai no desenho geométrico de hoje. A arte de exemplo está em `game/art/_exemplo/` (Teste A e um NPC), gerada por `game/tools/art/gen_placeholders.py`; serve de modelo.

**Pasta sugerida** (do plano do M16): `game/art/characters/<id>/` para heróis, `game/art/enemies/<id>/` para inimigos, `game/art/npcs/<id>/` para NPCs. Não é obrigatória.

### Folha de mapa

- Quadros de **32×48**.
- **4 linhas**, nesta ordem: **baixo, esquerda, direita, cima**.
- **3 quadros** por linha. O quadro do **meio** (o 2º) é o parado; os outros dois são a passada.
- Exemplo: 96×192 px (3 colunas × 4 linhas).

### Folha de batalha

- Quadros de **64×64**, com a figura **virada para a direita** (o jogo espelha quando precisa; `battle_faces_right`, padrão ligado).
- Uma linha por animação. A tabela `anims` do `SpriteSet` guarda, para cada uma, **(linha, quadros, fps)**. Os valores padrão:

| Animação | Linha | Quadros | FPS | Laço |
|---|---|---|---|---|
| `idle` | 0 | 4 | 6 | sim |
| `attack` | 1 | 4 | 12 | não |
| `cast` | 2 | 4 | 10 | não |
| `hit` | 3 | 2 | 10 | não |
| `down` | 4 | 3 | 6 | não |
| `victory` | 5 | 4 | 6 | sim |

Só `idle` e `victory` repetem; as outras tocam uma vez e param no último quadro. Se a sua folha tiver outra quantidade de quadros por linha, altere a coluna **quadros** na tabela `anims` (o exemplo `teste_a.tres` usa outros números).

### Retratos

- **96×96**, um arquivo por expressão (`neutro`, `feliz`...). Guarde-os no dicionário `portraits` do `SpriteSet`, com a expressão como chave.
- `neutro` é o padrão: uma fala com expressão que não existe cai nele.
- No roteiro: `Nome [feliz]: texto`.

### Criar o `SpriteSet` e ligar

1. No FileSystem, crie um recurso: clique com o botão direito na pasta, **New Resource...**, escolha **SpriteSet** e salve, por exemplo, como `art/characters/<id>/sprites.tres`.
2. No Inspector do `SpriteSet`, preencha `map_sheet` (folha de mapa), `battle_sheet` (folha de batalha), `portraits` (um por expressão). Confira `map_frame` (32×48), `battle_frame` (64×64) e `portrait_size` (96×96), que já são os padrões.
3. Ligue ao dono:
   - **herói:** aba Banco > Heróis, abra o herói e preencha `sprites` no `CharacterDef`;
   - **inimigo:** aba Inimigos, campo `sprites` do `EnemyDef`;
   - **NPC:** crie um `SpeakerDef` (aba Banco > Falantes, **Novo...**) com `id` (o usado no roteiro), `display_name` e `sprites`. O NPC é resolvido pelo `display_name` ou pelo `id` quando fala no roteiro.
4. Confira na aba **Validar** (veja (e)): folhas com tamanho que não é múltiplo do quadro, ou animações que saem da folha, são erros. Herói ou inimigo sem arte de batalha é só aviso.

**Pixel art:** o projeto já vem com o filtro padrão *Nearest* e o snap de pixel ligado (`project.godot`). Não precisa configurar cada imagem.

## (d) Pintar um mapa com o tileset

O tileset `game/art/tiles/placeholder_32.tres` tem tiles de **32×32**, em uma folha de 10 colunas × 2 linhas (320×64). Os 7 mapas da fatia (`game/world/fatia/*.tscn`) já usam ele, em três camadas:

- **`Chão`**: o piso (chão, caminho, grama, piso interno...). Não colide.
- **`Paredes`**: os blocos que colidem.
- **`Decoração`**: vazia, para você pintar enfeites por cima. Não colide.

**Quais tiles colidem:** parede, água, parede interna, casa, casa azul, árvore, pedra, tenda e móvel. Os outros (chão, caminho, grama, escada, ponte, piso da pousada e masmorras) não colidem. A colisão vem do próprio tileset (uma camada de física), então você não precisa de `StaticBody2D`.

Para pintar:

1. Abra um mapa de `world/fatia/` ou crie um `LocalMap` com `TileMapLayer`s que usem esse tileset.
2. Pinte o chão em `Chão`, o que bloqueia em `Paredes` e o resto em `Decoração`.
3. Os nós de jogo (NPCs, portas, baús, `MapLink`, marcadores, zonas) são nós separados do TileMap: deixe-os onde estão.

**Trocar pelo seu desenho, mantendo a grade:**

1. Faça uma folha PNG com a **mesma grade**: 32×32 por tile, 320×64 no total, e **cada tile na mesma coluna e linha** da tabela do `art/tiles/README.md`. Assim os mapas pintados e a colisão (que é por coordenada) continuam certos.
2. Substitua `placeholder_32.png` mantendo o nome, ou aponte `texture` do `TileSetAtlasSource` no `.tres` para o seu PNG. O Godot reimporta.
3. Se acrescentar tiles novos, use colunas e linhas novas e marque a colisão no editor do TileSet (camada de física 0). **Não mova os tiles existentes.**
4. Não rode `gen_tileset.py` depois de trocar: ele sobrescreve o PNG e o `.tres`.

## (e) Validar e testar

### Validar

- Aba **VAT > Validar > Validar tudo**. O painel roda os validadores em outro processo e lista **Erros** e **Avisos**, cada um com o arquivo e, quando há, a linha.
- Pela linha de comando, sem janela (sai com código 1 se houver erro):

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --headless --path game -s tools/validate/check_all.gd
```

O que é checado: ids únicos por tipo, referências que existem, no máximo 2 elementos nativos, a tabela de reações, chefes imunes a Contagem e Petrificação, eventos e roteiros, folhas de `SpriteSet`, mapas com `MapLink` para spawn que existe, e avisos de arte de batalha faltando. Conteúdo de `res://data/test/` não recebe o aviso de arte.

O que é aviso e não erro: flag usada sem `@flag` (no roteiro) e herói ou inimigo sem arte.

### Testar um mapa ou um encontro

Aba **VAT > Testar**:

- **Jogar este mapa**: escolha o mapa e, opcionalmente, o ponto de entrada (*spawn*), e clique. Abre o jogo nesse mapa.
- **Testar encontro**: escolha o encontro, a **arena** (o mapa onde a luta acontece; sem escolha, a do mapa inicial) e o **nível** (1 a 99, padrão 5). Abre o jogo já na luta.
- **Parar o jogo**: encerra a janela do teste.

O teste abre **uma janela de jogo separada**, que não aparece no depurador do editor. Pelos flags, a mesma coisa vale na linha de comando (os flags vão depois de `--`):

```powershell
& "<Godot.exe>" --path game -- --start-map=cidade --spawn=<marcador>
& "<Godot.exe>" --path game -- --battle=<encontro> --level=8 --start-map=<mapa>
```

- Mapas: `overworld`, `area_teste`, `dungeon_teste`, `cidade`, `casa_1`, `casa_2`, `overworld_fatia`, `estrada`, `dungeon_1`, `dungeon_2`.
- `--spawn` e `--level` sozinhos não fazem nada; precisam de `--start-map` ou `--battle`. Mapa, marcador ou encontro desconhecido dá erro no log e volta ao título.
- `--battle` precisa de um mapa com arena. Sem `--level`, o nível é 5.

Os mesmos flags são só para desenvolvimento e não fazem parte do jogo exportado.

## (f) Limites conhecidos

- **Sem autotile:** cada tile é pintado à mão. Não há terrenos que escolhem a borda sozinhos.
- **Animação de ataque:** a animação de ataque começa quando a ação começa, não no momento do golpe.
- **O editor reescreve `project.godot` ao abrir.** Antes de commitar, confira o diff e desfaça o que não for seu.
- **Reimportar pode mudar as quebras de linha dos `.import`.** Se a mudança for só de fim de linha, restaure o arquivo antes de commitar.
- **Não rode demos e testes ao mesmo tempo.** Eles compartilham a pasta `user://` (saves e configurações), e um atrapalha o outro.

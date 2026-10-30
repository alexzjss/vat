# Tileset placeholder 32x32

`placeholder_32.png` e `placeholder_32.tres` são **placeholders** gerados por `tools/art/gen_tileset.py`
(`python game/tools/art/gen_tileset.py`). Cada tile é uma cor sólida com um rótulo de 3 letras. Os 7 mapas da fatia
(`world/fatia/*.tscn`) são pintados com ele, em três camadas `TileMapLayer`: `Chão`, `Paredes` e `Decoração`
(esta última nasce vazia, para você pintar por cima).

## A folha

10 colunas x 2 linhas de 32x32 px (320x64). O ID de um tile é a coordenada dele na folha (coluna, linha).

| Coord. | Tile | Colide | | Coord. | Tile | Colide |
|---|---|---|---|---|---|---|
| 0,0 | chão (`CHO`) | não | | 0,1 | casa (`CAS`) | sim |
| 1,0 | caminho (`CAM`) | não | | 1,1 | casa azul (`CAB`) | sim |
| 2,0 | grama (`GRA`) | não | | 2,1 | árvore (`ARV`) | sim |
| 3,0 | parede (`PAR`) | **sim** | | 3,1 | pedra (`PED`) | sim |
| 4,0 | água (`AGU`) | **sim** | | 4,1 | tenda (`TEN`) | sim |
| 5,0 | piso interno (`PIS`) | não | | 5,1 | móvel (`MOV`) | sim |
| 6,0 | parede interna (`PAI`) | **sim** | | 6,1 | piso da pousada (`POU`) | não |
| 7,0 | escada (`ESC`) | não | | 7,1 | masmorra A (`MA1`) | não |
| 8,0 | ponte (`PON`) | não | | 8,1 | masmorra B (`MA2`) | não |
| 9,0 | vazio (`VAZ`) | não | | 9,1 | masmorra C (`MA3`) | não |

A linha 0 é o conjunto do plano (decisão 15) mais o `vazio` (fundo escuro dos interiores). A linha 1 tem as
variantes que a fatia usava como blocos sólidos de outra cor (casas, árvores, pedras...).

## Colisão

O TileSet tem **uma camada de física** (`physics_layer_0`): camada de colisão 1 e máscara 0, igual aos antigos
`StaticBody2D` das paredes. O jogador e os inimigos de mapa colidem com a camada 1. Cada tile sólido tem um polígono
de tile inteiro (32x32). Quem colide: parede, água, parede interna, casa, casa azul, árvore, pedra, tenda e móvel.

## Terrenos (autotile)

O TileSet tem **um terrain set** no modo **combinar lados** (`terrain_set_0`, `mode = 2`) com 6 terrenos. Cada um tem
**um** tile base, com os 4 bits de lado (direita, baixo, esquerda, cima) apontando para o próprio terreno:

| # | Terreno | Cor | Tile base | Colide |
|---|---|---|---|---|
| 0 | Grama | verde | 2,0 | não |
| 1 | Caminho | marrom | 1,0 | não |
| 2 | Parede | cinza-marrom | 3,0 | sim |
| 3 | Água | azul | 4,0 | sim |
| 4 | Piso interno | marrom médio | 5,0 | não |
| 5 | Parede interna | marrom escuro | 6,0 | sim |

Fora dos terrenos ficam o chão (0,0), a escada, a ponte, o vazio, os tiles da linha 1 (casa, árvore, pedra, tenda,
móvel, pousada) e as masmorras A, B e C. A masmorra A (7,1) é piso mas **não** entra em Piso interno: com dois tiles
candidatos o pincel de terreno escolheria um ao acaso, e o assistente de mapa precisa de um resultado previsível. Esses
tiles continuam sendo pintados à mão.

### Pintar com terrenos

1. Selecione a camada (`Chão` ou `Paredes`) e abra a aba **TileMap** no painel inferior.
2. Abra a aba **Terrenos** (ao lado de **Tiles**), escolha o terreno na lista e o modo **Conectar** (ou **Caminho**).
3. Pinte no mapa. O Godot escolhe o tile de cada célula olhando as quatro vizinhas.

**Só com os tiles base** o pincel coloca o tile base em toda célula: o resultado é igual a pintar à mão. As variantes de
borda e de canto chegam com a arte final; depois que existirem (veja abaixo), o mesmo pincel passa a usá-las sozinho,
sem repintar nada. O assistente "Novo mapa" já pinta o chão e a borda por terreno (`set_cells_terrain_connect`), então
mapas novos ganham as bordas assim que a arte tiver as variantes. Os mapas da fatia não foram migrados.

### Acrescentar tiles de transição

1. Desenhe o tile na folha, em uma célula livre (colunas ou linhas novas; **não mova os tiles existentes**).
2. No editor do TileSet, aba **Tile Set**, selecione a folha e crie o tile (modo **Setup**, clique na célula).
3. Modo **Paint**, propriedade **Terrains**: defina **Terrain Set 0** e **Terrain** (o terreno principal do tile) e
   pinte os bits de vizinhança. No modo combinar lados cada bit é um **lado**; o número do terreno vizinho naquele
   lado vai no bit. Um lado que não toca outro terreno repete o terreno do próprio tile.
4. Se o tile deve bloquear, marque também o polígono na camada de física 0.

Bits do modo **combinar lados** (os nomes são os do `.tres`, `terrains_peering_bit/...`):

| Bit | Lado da célula | Constante do Godot |
|---|---|---|
| `top_side` | cima | `CELL_NEIGHBOR_TOP_SIDE` |
| `right_side` | direita | `CELL_NEIGHBOR_RIGHT_SIDE` |
| `bottom_side` | baixo | `CELL_NEIGHBOR_BOTTOM_SIDE` |
| `left_side` | esquerda | `CELL_NEIGHBOR_LEFT_SIDE` |

(Os cantos, `top_right_corner` etc., só existem nos modos "combinar cantos e lados" e "combinar cantos"; este terrain set
não os usa.)

**Exemplo: borda de grama para caminho.** Um tile novo em 0,2 que é grama com o caminho encostando **embaixo**:

```
0:2/0 = 0
0:2/0/terrain_set = 0
0:2/0/terrain = 0                          # é do terreno Grama (0)
0:2/0/terrains_peering_bit/top_side = 0    # em cima, grama
0:2/0/terrains_peering_bit/right_side = 0  # à direita, grama
0:2/0/terrains_peering_bit/left_side = 0   # à esquerda, grama
0:2/0/terrains_peering_bit/bottom_side = 1 # embaixo, caminho (1)
```

Quando uma célula de grama tem caminho abaixo e grama nos outros três lados, o pincel escolhe esse tile. Repita para
os outros lados e para os cantos (dois lados de caminho) até cobrir todas as combinações que quiser; as que faltarem
caem no tile base. Ao regerar com `gen_tileset.py` as variantes acrescentadas no editor se perdem: acrescente-as também
na lista `TERRAINS`/`TILES` do script, ou não regere.

## Trocar pela arte final

1. Faça uma folha `placeholder_32.png` (ou outro nome, veja abaixo) com **a mesma grade**: 32x32 px por tile, o
   mesmo tamanho de folha (320x64) e **cada tile na mesma coluna e linha** da tabela acima. Assim os mapas já
   pintados continuam certos, e a colisão (que está no `.tres`, por coordenada) continua nos tiles certos.
2. Substitua o PNG mantendo o nome, ou aponte `texture` do `TileSetAtlasSource` do `.tres` para o seu PNG
   (no editor: abra o `.tres`, aba TileSet, e troque a textura). O Godot reimporta sozinho.
3. Se você acrescentar tiles novos, marque a colisão no editor do TileSet (camada de física 0, polígono do tile) para os
   que devem bloquear. Tiles novos podem ir em colunas/linhas novas; **não mova os existentes**.
4. Regerar com `gen_tileset.py` **sobrescreve** o PNG e o `.tres`: só faça isso se quiser voltar ao placeholder.

Para pintar um mapa novo: crie um `LocalMap` (ou abra um de `world/fatia/`), adicione `TileMapLayer`s com este TileSet
e pinte o chão em `Chão`, o que bloqueia em `Paredes` e os enfeites em `Decoração`. A colisão vem do TileSet, não
precisa de `StaticBody2D`.

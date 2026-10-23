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
Não há terrenos de autotile: cada tile é pintado à mão.

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

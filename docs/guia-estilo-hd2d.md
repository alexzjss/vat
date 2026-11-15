# Guia de estilo: pixel art HD-2D (2D com pós-efeitos)

Alvo: o visual dos remasters HD-2D da Square Enix, obtido em 2D puro. Pixel art nítida no centro da tela, com luz quente, bloom, desfoque nas bordas e partículas por cima.

## Regras da pixel art

| Item | Tamanho | Observação |
|---|---|---|
| Tile | 32×32 | Packs 16×16 entram ampliados 2× (inteiro, filtro nearest) |
| Sprite de mapa | 32×48 | Cabeça grande, ~2,5 cabeças de altura |
| Sprite de batalha | 64×64 | Mesmo personagem, mais detalhe |
| Retrato | 96×96 | |

- Nunca misturar densidades de pixel na mesma cena: tudo no mesmo múltiplo inteiro.
- Sem contorno preto puro; contorno na cor mais escura do próprio material.
- Paleta limitada por material (4–6 tons), sombras puxadas para o roxo/azul, luzes para o amarelo/laranja.
- A arte é pintada em luz neutra. Hora do dia e clima vêm do `CanvasModulate` e das luzes, não do sprite.

## Camadas de efeito

1. **Ambiente** (`CanvasModulate` no mapa): escurece e tinge tudo. Dia `(1, 0.98, 0.94)`, entardecer `(0.62, 0.6, 0.78)`, interior/caverna `(0.4, 0.4, 0.55)`.
2. **Luzes** (`fx/luz_quente.tscn`): uma por janela, porta, tocha ou lampião. Mudar `color`, `energy` e `texture_scale` na instância.
3. **Partículas** (`fx/poeira.tscn`): poeira/vagalumes; ajustar `emission_rect_extents` ao tamanho do mapa.
4. **Pós-processamento** (`fx/hd2d_post.gd` + `.gdshader`): criado pelo `Game`, vale para todos os mapas. Tilt-shift (faixa nítida no meio), bloom, saturação/contraste, tom quente e vinheta. Tem modo `map` e `battle`; a UI fica sempre nítida.

## Como aplicar a um mapa

Adicionar ao `.tscn` do mapa: um `CanvasModulate`, instâncias de `luz_quente.tscn` nos pontos de luz e uma de `poeira.tscn`. Exemplo pronto: `game/world/fatia/cidade.tscn`.

## Ainda não coberto

- Normal maps nos tiles (relevo sob a luz) e sombras projetadas (`LightOccluder2D`): dependem da arte final.
- Paralaxe de fundo e água com reflexo.
- Opção em Config para desligar os efeitos.

## Arte de terceiros

Base atual: Tiny RPG Fantasy, de ansimuz (CC0), em `game/art/packs/ansimuz/`. `python game/tools/art/gen_tileset_ansimuz.py` monta `art/tiles/ansimuz_32.tres`, com a mesma folha 10x2 do placeholder (mesmas coordenadas e colisão), então trocar o `tile_set` de um mapa já basta. Casas e árvores ainda são um tile repetido; os prédios de vários tiles do pack precisam de um tileset próprio pintado na camada `Decoração`.

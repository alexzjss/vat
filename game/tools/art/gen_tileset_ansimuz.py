"""Monta art/tiles/ansimuz_32.png: mesma folha 10x2 do placeholder, com tiles do pack ansimuz ampliados 2x.

Uso: python game/tools/art/gen_tileset_ansimuz.py  (precisa de Pillow)
Células sem arte correspondente ficam com o placeholder.
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
PACK = os.path.join(ROOT, "art", "packs", "ansimuz")
TILES = os.path.join(ROOT, "art", "tiles")

town = Image.open(os.path.join(PACK, "town_tileset.png")).convert("RGBA")
cave = Image.open(os.path.join(PACK, "cave_tileset.png")).convert("RGBA")
grass_src = Image.open(os.path.join(PACK, "grass-tile.png")).convert("RGBA")
bush = Image.open(os.path.join(PACK, "bush-1.png")).convert("RGBA")
sheet = Image.open(os.path.join(TILES, "placeholder_32.png")).convert("RGBA")


def up(im):
    return im.resize((32, 32), Image.NEAREST)


def tile(col, row):
    return up(town.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16)))


def cave_tile(col, row):
    return up(cave.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16)))


def tint(im, r, g, b):
    rr, gg, bb, aa = im.split()
    return Image.merge("RGBA", (rr.point(lambda v: min(255, int(v * r))), gg.point(lambda v: min(255, int(v * g))),
                                bb.point(lambda v: min(255, int(v * b))), aa))


grass = up(grass_src.crop((16, 16, 32, 32)))


def over_grass(im):
    out = grass.copy()
    out.alpha_composite(im)
    return out


def fit(im):
    im = im.copy()
    im.thumbnail((32, 32), Image.NEAREST)
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.alpha_composite(im, ((32 - im.width) // 2, 32 - im.height))
    return out


dirt = tile(2, 7)
roof = tile(11, 2)
cells = {
    (0, 0): dirt,                        # chão
    (1, 0): tint(dirt, 1.15, 1.05, 0.85),               # caminho
    (2, 0): grass,                       # grama
    (3, 0): tile(1, 10),                 # parede (penhasco)
    (4, 0): tile(11, 12),                # água
    (0, 1): roof,                        # casa
    (1, 1): tint(roof, 0.55, 0.8, 1.35),  # casa azul
    (2, 1): over_grass(fit(bush)),       # árvore
    (3, 1): over_grass(tile(5, 8)),      # pedra
    (4, 1): tint(roof, 1.1, 0.85, 0.45),  # tenda
    (5, 1): over_grass(tile(9, 8)),      # móvel (barril)
    (6, 1): tint(dirt, 1.05, 0.9, 0.95),  # piso da pousada
    (5, 0): tint(cave_tile(7, 5), 1.25, 1.0, 0.75),  # piso interno
    (6, 0): cave_tile(4, 8),             # parede interna (rocha)
    (9, 0): Image.new("RGBA", (32, 32), (20, 16, 24, 255)),  # vazio
    (7, 1): cave_tile(7, 1),             # masmorra A
    (8, 1): cave_tile(4, 4),             # masmorra B
    (9, 1): cave_tile(7, 4),             # masmorra C
}
for (c, r), im in cells.items():
    sheet.paste(im, (c * 32, r * 32))
sheet.save(os.path.join(TILES, "ansimuz_32.png"))

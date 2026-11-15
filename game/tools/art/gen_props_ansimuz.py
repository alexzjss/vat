"""Monta os adereços de cenário (casas e pinheiro) a partir do tileset de cidade do pack ansimuz, ampliados 2x.

Casa: 8x4 tiles (256x128 px), do tamanho dos blocos de casa dos mapas da fatia, com a porta no meio.
Uso: python game/tools/art/gen_props_ansimuz.py  (precisa de Pillow)
"""
import os
from PIL import Image, ImageOps

PACK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "packs", "ansimuz")
town = Image.open(os.path.join(PACK, "town_tileset.png")).convert("RGBA")
os.makedirs(os.path.join(PACK, "props"), exist_ok=True)

# Colunas do prédio da pousada (9..14) usadas em cada linha da casa de 8 tiles de largura.
ROOF = [9, 10, 11, 12, 12, 12, 13, 14]
# -14 = coluna 14 espelhada (canto esquerdo sem a placa da pousada).
WALL = [-14, 13, 13, 11, 12, 13, 13, 14]
ROWS = [(1, ROOF), (2, ROOF), (5, WALL), (6, WALL)]


def house(roof_tint=None):
    out = Image.new("RGBA", (8 * 16, 4 * 16), (0, 0, 0, 0))
    for y, (row, cols) in enumerate(ROWS):
        for x, col in enumerate(cols):
            c = abs(col)
            t = town.crop((c * 16, row * 16, c * 16 + 16, row * 16 + 16))
            if col < 0:
                t = ImageOps.mirror(t)
            if roof_tint and row <= 2:
                r, g, b, a = t.split()
                t = Image.merge("RGBA", (r.point(lambda v: min(255, int(v * roof_tint[0]))),
                                         g.point(lambda v: min(255, int(v * roof_tint[1]))),
                                         b.point(lambda v: min(255, int(v * roof_tint[2]))), a))
            out.paste(t, (x * 16, y * 16))
    return out.resize((out.width * 2, out.height * 2), Image.NEAREST)


def save(im, name):
    im.save(os.path.join(PACK, "props", name + ".png"))


save(house(), "casa")
save(house((0.55, 0.8, 1.35)), "casa_azul")
pine = town.crop((74, 16, 98, 120))
save(pine.resize((pine.width * 2, pine.height * 2), Image.NEAREST), "pinheiro")

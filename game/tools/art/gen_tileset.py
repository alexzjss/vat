#!/usr/bin/env python3
"""Gera o tileset PLACEHOLDER 32x32 do M16 (so stdlib; sem PIL).

Uso: python game/tools/art/gen_tileset.py [pasta_de_saida]

Escreve em game/art/tiles/:
- placeholder_32.png: a folha de tiles (10 colunas x 2 linhas de 32x32), cada tile uma cor solida com um rotulo
  de 3 letras;
- placeholder_32.tres: o TileSet (tile 32x32, uma camada de fisica) com a colisao de cada tile.

Os IDs sao as coordenadas no atlas (coluna, linha). Para trocar por arte final, mantenha esta grade (ver README.md).
Colisao: camada 1, mascara 0 (igual aos StaticBody2D antigos; jogador e inimigos de mapa usam mascara 1).
"""
import os
import struct
import sys
import zlib

TILE = 32
COLS, ROWS = 10, 2

# Fonte 3x5.
FONT = {
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "C": ["111", "100", "100", "100", "111"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"],
    "F": ["111", "100", "110", "100", "100"],
    "G": ["111", "100", "101", "101", "111"],
    "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["110", "101", "101", "101", "101"],
    "O": ["111", "101", "101", "101", "111"],
    "P": ["110", "101", "110", "100", "100"],
    "R": ["110", "101", "110", "101", "101"],
    "S": ["111", "100", "111", "001", "111"],
    "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"],
    "V": ["101", "101", "101", "101", "010"],
    "Z": ["111", "001", "010", "100", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "111", "001", "111"],
}

# (coluna, linha, id, rotulo, cor RGB, colide). A ordem da linha 0 e a da tabela da decisao 15 do plano.
TILES = [
    (0, 0, "chao", "CHO", (107, 102, 87), False),
    (1, 0, "caminho", "CAM", (128, 107, 77), False),
    (2, 0, "grama", "GRA", (51, 97, 56), False),
    (3, 0, "parede", "PAR", (89, 77, 64), True),
    (4, 0, "agua", "AGU", (51, 102, 179), True),
    (5, 0, "piso_interno", "PIS", (115, 87, 61), False),
    (6, 0, "parede_interna", "PAI", (77, 56, 41), True),
    (7, 0, "escada", "ESC", (166, 153, 128), False),
    (8, 0, "ponte", "PON", (140, 100, 56), False),
    (9, 0, "vazio", "VAZ", (13, 13, 18), False),
    # Variantes: o que na fatia era um bloco solido de outra cor.
    (0, 1, "casa", "CAS", (140, 77, 64), True),
    (1, 1, "casa_azul", "CAB", (77, 102, 140), True),
    (2, 1, "arvore", "ARV", (26, 64, 31), True),
    (3, 1, "pedra", "PED", (115, 107, 102), True),
    (4, 1, "tenda", "TEN", (204, 153, 51), True),
    (5, 1, "movel", "MOV", (89, 64, 38), True),
    (6, 1, "piso_pousada", "POU", (87, 71, 102), False),
    (7, 1, "masmorra_a", "MA1", (51, 51, 66), False),
    (8, 1, "masmorra_b", "MA2", (56, 51, 61), False),
    (9, 1, "masmorra_c", "MA3", (51, 59, 61), False),
]


def write_png(path, width, height, pixels):
    """pixels: lista de linhas, cada uma uma lista de tuplas RGBA."""
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in pixels)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def text_color(rgb):
    lum = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]
    return (20, 20, 20, 255) if lum > 140 else (235, 235, 235, 255)


def make_sheet(path):
    img = [[(0, 0, 0, 0)] * (TILE * COLS) for _ in range(TILE * ROWS)]
    for col, row, _id, label, rgb, _solid in TILES:
        ox, oy = col * TILE, row * TILE
        for y in range(TILE):
            for x in range(TILE):
                img[oy + y][ox + x] = (rgb[0], rgb[1], rgb[2], 255)
        scale = 2
        width = len(label) * 3 * scale + (len(label) - 1) * scale
        x0 = ox + (TILE - width) // 2
        y0 = oy + (TILE - 5 * scale) // 2
        color = text_color(rgb)
        for i, ch in enumerate(label):
            cx = x0 + i * 4 * scale
            for ry, line in enumerate(FONT[ch]):
                for rx, bit in enumerate(line):
                    if bit == "1":
                        for dy in range(scale):
                            for dx in range(scale):
                                img[y0 + ry * scale + dy][cx + rx * scale + dx] = color
    write_png(path, TILE * COLS, TILE * ROWS, img)


def make_tres(path):
    h = TILE // 2
    square = "PackedVector2Array(%d, %d, %d, %d, %d, %d, %d, %d)" % (-h, -h, h, -h, h, h, -h, h)
    lines = [
        '[gd_resource type="TileSet" load_steps=3 format=3]',
        "",
        '[ext_resource type="Texture2D" path="res://art/tiles/placeholder_32.png" id="1_tiles"]',
        "",
        '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_placeholder"]',
        'texture = ExtResource("1_tiles")',
        "texture_region_size = Vector2i(%d, %d)" % (TILE, TILE),
    ]
    for col, row, _id, _label, _rgb, solid in sorted(TILES, key=lambda t: (t[0], t[1])):
        lines.append("%d:%d/0 = 0" % (col, row))
        if solid:
            lines.append("%d:%d/0/physics_layer_0/polygon_0/points = %s" % (col, row, square))
    lines += [
        "",
        "[resource]",
        "tile_size = Vector2i(%d, %d)" % (TILE, TILE),
        "physics_layer_0/collision_layer = 1",
        "physics_layer_0/collision_mask = 0",
        'sources/0 = SubResource("TileSetAtlasSource_placeholder")',
        "",
    ]
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "art", "tiles")
    os.makedirs(out, exist_ok=True)
    make_sheet(os.path.join(out, "placeholder_32.png"))
    make_tres(os.path.join(out, "placeholder_32.tres"))
    print("ok:", os.path.abspath(out))


if __name__ == "__main__":
    main()

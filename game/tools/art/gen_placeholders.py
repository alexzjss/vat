#!/usr/bin/env python3
"""Gera as folhas PLACEHOLDER do M16 em game/art/_exemplo/ (so stdlib; sem PIL).

Uso: python game/tools/art/gen_placeholders.py [pasta_de_saida]

- teste_a_map.png: 4 direcoes (baixo, esquerda, direita, cima) x 3 quadros de 32x48.
  Cada quadro mostra a letra da direcao (D/L/R/U) e o numero do quadro (1..3); o 2 e o quadro parado.
- npc_map.png: mesma grade, tons de verde, letra N e o numero do quadro.
Sao blocos de cor, so para provar o pipeline. Arte final entra em art/characters/<id>/ etc.
"""
import os
import struct
import sys
import zlib

FRAME_W, FRAME_H = 32, 48
COLS, ROWS = 3, 4
DIRS = ["D", "L", "R", "U"]  # baixo, esquerda, direita, cima (a ordem da folha)

# Fonte 3x5.
FONT = {
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "111", "001", "111"],
    "D": ["110", "101", "101", "101", "110"],
    "L": ["100", "100", "100", "100", "111"],
    "R": ["110", "101", "110", "101", "101"],
    "U": ["101", "101", "101", "101", "111"],
    "N": ["101", "111", "111", "111", "101"],
}


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


def blit_text(img, ch, x0, y0, scale, color):
    for ry, line in enumerate(FONT[ch]):
        for rx, bit in enumerate(line):
            if bit == "1":
                for dy in range(scale):
                    for dx in range(scale):
                        img[y0 + ry * scale + dy][x0 + rx * scale + dx] = color


def fill(img, x, y, w, h, color):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            img[yy][xx] = color


def make_sheet(path, body, head, dark, letter):
    img = [[(0, 0, 0, 0)] * (FRAME_W * COLS) for _ in range(FRAME_H * ROWS)]
    for row in range(ROWS):
        for col in range(COLS):
            ox, oy = col * FRAME_W, row * FRAME_H
            step = [-1, 0, 1][col]  # as pernas se mexem nos quadros 1 e 3
            fill(img, ox + 6, oy + 14, 20, 28, body)            # corpo
            fill(img, ox + 9, oy + 2, 14, 12, head)             # cabeca
            fill(img, ox + 8, oy + 42 + (0 if step <= 0 else -2), 6, 6 if step <= 0 else 4, dark)   # perna esq
            fill(img, ox + 18, oy + 42 + (0 if step >= 0 else -2), 6, 6 if step >= 0 else 4, dark)  # perna dir
            # contorno do quadro (1px) para ver o recorte
            fill(img, ox, oy, FRAME_W, 1, dark)
            fill(img, ox, oy + FRAME_H - 1, FRAME_W, 1, dark)
            fill(img, ox, oy, 1, FRAME_H, dark)
            fill(img, ox + FRAME_W - 1, oy, 1, FRAME_H, dark)
            blit_text(img, letter if letter != "dir" else DIRS[row], ox + 12, oy + 18, 3, (255, 255, 255, 255))
            blit_text(img, str(col + 1), ox + 14, oy + 5, 2, (20, 20, 20, 255))
    write_png(path, FRAME_W * COLS, FRAME_H * ROWS, img)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "art", "_exemplo")
    os.makedirs(out, exist_ok=True)
    make_sheet(os.path.join(out, "teste_a_map.png"), (60, 110, 230, 255), (240, 200, 160, 255), (20, 30, 90, 255), "dir")
    make_sheet(os.path.join(out, "npc_map.png"), (70, 190, 90, 255), (245, 215, 170, 255), (20, 80, 30, 255), "N")
    print("ok:", os.path.abspath(out))


if __name__ == "__main__":
    main()

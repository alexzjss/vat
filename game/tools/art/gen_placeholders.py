#!/usr/bin/env python3
"""Gera as folhas PLACEHOLDER do M16 em game/art/_exemplo/ (so stdlib; sem PIL).

Uso: python game/tools/art/gen_placeholders.py [pasta_de_saida]

- teste_a_map.png: 4 direcoes (baixo, esquerda, direita, cima) x 3 quadros de 32x48.
  Cada quadro mostra a letra da direcao (D/L/R/U) e o numero do quadro (1..3); o 2 e o quadro parado.
- npc_map.png: mesma grade, tons de verde, letra N e o numero do quadro.
- teste_a_battle.png / inimigo_f1_battle.png: folhas de batalha 64x64, viradas para a direita. Linhas (a ordem do
  SpriteSet): idle 2 quadros, attack 3, cast 3, hit 2, down 1, victory 2. Cada quadro leva a letra da animacao
  (I, A, C, H, D, V) e o numero do quadro.
- teste_a_portrait_neutro.png, teste_a_portrait_feliz.png, morador_a_portrait_neutro.png: retratos 96x96.
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
    "I": ["111", "010", "010", "010", "111"],
    "A": ["010", "101", "111", "101", "101"],
    "C": ["111", "100", "100", "100", "111"],
    "H": ["101", "101", "111", "101", "101"],
    "V": ["101", "101", "101", "101", "010"],
    "F": ["111", "100", "110", "100", "100"],
}

BATTLE = 64
# (letra, quadros), na ordem das linhas da folha de batalha.
BATTLE_ROWS = [("I", 2), ("A", 3), ("C", 3), ("H", 2), ("D", 1), ("V", 2)]
BATTLE_COLS = 3
PORTRAIT = 96


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


def make_battle(path, body, head, dark):
    """Folha de batalha: figura virada para a direita (um 'olho' branco do lado direito da cabeca)."""
    img = [[(0, 0, 0, 0)] * (BATTLE * BATTLE_COLS) for _ in range(BATTLE * len(BATTLE_ROWS))]
    for row, (letter, count) in enumerate(BATTLE_ROWS):
        for col in range(count):
            ox, oy = col * BATTLE, row * BATTLE
            dx, dy = 0, 0
            if letter == "I":
                dy = col  # respira
            elif letter == "A":
                dx = [-4, 8, 14][col]  # recua, avanca, estica
            elif letter == "C":
                dy = -3 * col  # sobe
            elif letter == "H":
                dx = -6 - 2 * col  # leva o golpe
            elif letter == "V":
                dy = -4 * col  # pula
            if letter == "D":
                fill(img, ox + 8, oy + 40, 48, 16, body)      # deitado
                fill(img, ox + 40, oy + 32, 14, 12, head)
            else:
                fill(img, ox + 18 + dx, oy + 24 + dy, 28, 30, body)   # corpo
                fill(img, ox + 22 + dx, oy + 8 + dy, 20, 16, head)    # cabeca
                fill(img, ox + 34 + dx, oy + 13 + dy, 4, 4, (255, 255, 255, 255))  # olho (lado direito)
                fill(img, ox + 20 + dx, oy + 54 + dy, 8, 6, dark)    # pes
                fill(img, ox + 36 + dx, oy + 54 + dy, 8, 6, dark)
            fill(img, ox, oy, BATTLE, 1, dark)
            fill(img, ox, oy + BATTLE - 1, BATTLE, 1, dark)
            fill(img, ox, oy, 1, BATTLE, dark)
            fill(img, ox + BATTLE - 1, oy, 1, BATTLE, dark)
            blit_text(img, letter, ox + 4, oy + 4, 2, (255, 255, 255, 255))
            blit_text(img, str(col + 1), ox + 4, oy + 18, 2, (255, 255, 255, 255))
    write_png(path, BATTLE * BATTLE_COLS, BATTLE * len(BATTLE_ROWS), img)


def make_portrait(path, bg, skin, dark, letter, happy):
    img = [[bg] * PORTRAIT for _ in range(PORTRAIT)]
    fill(img, 0, 0, PORTRAIT, 2, dark)
    fill(img, 0, PORTRAIT - 2, PORTRAIT, 2, dark)
    fill(img, 0, 0, 2, PORTRAIT, dark)
    fill(img, PORTRAIT - 2, 0, 2, PORTRAIT, dark)
    fill(img, 14, 62, 68, 30, dark)            # ombros
    fill(img, 26, 12, 44, 50, skin)            # rosto
    fill(img, 36, 28, 6, 6, dark)              # olhos
    fill(img, 54, 28, 6, 6, dark)
    if happy:
        fill(img, 36, 46, 24, 4, dark)         # boca larga
        fill(img, 34, 44, 4, 4, dark)
        fill(img, 58, 44, 4, 4, dark)
    else:
        fill(img, 40, 48, 16, 3, dark)         # boca reta
    blit_text(img, letter, 6, 6, 3, (255, 255, 255, 255))
    write_png(path, PORTRAIT, PORTRAIT, img)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "art", "_exemplo")
    os.makedirs(out, exist_ok=True)
    make_sheet(os.path.join(out, "teste_a_map.png"), (60, 110, 230, 255), (240, 200, 160, 255), (20, 30, 90, 255), "dir")
    make_sheet(os.path.join(out, "npc_map.png"), (70, 190, 90, 255), (245, 215, 170, 255), (20, 80, 30, 255), "N")
    make_battle(os.path.join(out, "teste_a_battle.png"), (60, 110, 230, 255), (240, 200, 160, 255), (20, 30, 90, 255))
    make_battle(os.path.join(out, "inimigo_f1_battle.png"), (200, 60, 60, 255), (230, 150, 120, 255), (90, 20, 20, 255))
    make_portrait(os.path.join(out, "teste_a_portrait_neutro.png"), (50, 80, 170, 255), (240, 200, 160, 255), (20, 30, 90, 255), "N", False)
    make_portrait(os.path.join(out, "teste_a_portrait_feliz.png"), (60, 100, 200, 255), (245, 210, 170, 255), (20, 30, 90, 255), "F", True)
    make_portrait(os.path.join(out, "morador_a_portrait_neutro.png"), (50, 140, 70, 255), (245, 215, 170, 255), (20, 80, 30, 255), "N", False)
    print("ok:", os.path.abspath(out))


if __name__ == "__main__":
    main()

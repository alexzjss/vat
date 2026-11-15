"""Monta folhas de mapa 32x48 (3 colunas x 4 linhas: baixo, esquerda, direita, cima) e SpriteSets
a partir de hero.png e npc.png do pack ansimuz (quadros 16x16, ampliados 2x e apoiados na base da célula).

Uso: python game/tools/art/gen_sprites_ansimuz.py  (precisa de Pillow)
"""
import os
from PIL import Image, ImageOps

PACK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "packs", "ansimuz")
RES = "res://art/packs/ansimuz/"
EX = "res://art/_exemplo/"


def frame(sheet, col, row, flip=False):
    im = sheet.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16)).resize((32, 32), Image.NEAREST)
    return ImageOps.mirror(im) if flip else im


def save_sheet(name, rows):
    """rows: 4 listas de 3 quadros 32x32, na ordem baixo, esquerda, direita, cima."""
    out = Image.new("RGBA", (96, 192), (0, 0, 0, 0))
    for r, frames in enumerate(rows):
        for c, im in enumerate(frames):
            out.paste(im, (c * 32, r * 48 + 16))
    out.save(os.path.join(PACK, name + "_map.png"))


def save_set(name, extra_ext="", extra_body=""):
    text = ('[gd_resource type="Resource" script_class="SpriteSet" format=3]\n\n'
            '[ext_resource type="Script" path="res://core/defs/sprite_set.gd" id="1_set"]\n'
            '[ext_resource type="Texture2D" path="%s%s_map.png" id="2_map"]\n%s\n'
            '[resource]\nscript = ExtResource("1_set")\nmap_sheet = ExtResource("2_map")\n%s') % (RES, name, extra_ext, extra_body)
    with open(os.path.join(PACK, name + ".tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


hero = Image.open(os.path.join(PACK, "hero.png")).convert("RGBA")
# Folha do herói: linha 0 de lado (olhando para a esquerda), 1 de costas, 2 de frente. Quadro do meio = parado.
order = [1, 0, 2]
save_sheet("heroi", [
    [frame(hero, c, 2) for c in order],
    [frame(hero, c, 0) for c in order],
    [frame(hero, c, 0, True) for c in order],
    [frame(hero, c, 1) for c in order],
])
# Batalha e retratos ainda são os placeholders do Teste A.
save_set("heroi",
         '[ext_resource type="Texture2D" path="%steste_a_battle.png" id="3_battle"]\n'
         '[ext_resource type="Texture2D" path="%steste_a_portrait_neutro.png" id="4_neutro"]\n'
         '[ext_resource type="Texture2D" path="%steste_a_portrait_feliz.png" id="5_feliz"]\n' % (EX, EX, EX),
         'battle_sheet = ExtResource("3_battle")\n'
         'anims = Dictionary[StringName, Vector3i]({\n&"idle": Vector3i(0, 2, 4),\n&"attack": Vector3i(1, 3, 10),\n'
         '&"cast": Vector3i(2, 3, 8),\n&"hit": Vector3i(3, 2, 8),\n&"down": Vector3i(4, 1, 1),\n&"victory": Vector3i(5, 2, 4)\n})\n'
         'portraits = Dictionary[StringName, Texture2D]({\n&"neutro": ExtResource("4_neutro"),\n&"feliz": ExtResource("5_feliz")\n})\n')

npc = Image.open(os.path.join(PACK, "npc.png")).convert("RGBA")
# Folha de NPCs: um NPC por linha; colunas frente, lado (esquerda), costas. Sem animação de andar.
for i in range(4):
    save_sheet("npc_%d" % (i + 1), [
        [frame(npc, 0, i)] * 3,
        [frame(npc, 1, i)] * 3,
        [frame(npc, 1, i, True)] * 3,
        [frame(npc, 2, i)] * 3,
    ])
    if i == 0:  # o NPC 1 herda o retrato do Morador A
        save_set("npc_1", '[ext_resource type="Texture2D" path="%smorador_a_portrait_neutro.png" id="3_neutro"]\n' % EX,
                 'portraits = Dictionary[StringName, Texture2D]({\n&"neutro": ExtResource("3_neutro")\n})\n')
    else:
        save_set("npc_%d" % (i + 1))

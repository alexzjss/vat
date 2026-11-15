"""Monta os SpriteSets (um quadro, tamanho original) dos inimigos do pack ansimuz.

Os inimigos do pack não têm animação: todas as animações apontam para o mesmo quadro.
Uso: python game/tools/art/gen_inimigos_ansimuz.py  (precisa de Pillow)
"""
import os
from PIL import Image

DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "packs", "ansimuz", "inimigos")
RES = "res://art/packs/ansimuz/inimigos/"
ANIMS = ["idle", "attack", "cast", "hit", "down", "victory"]

for src in ["slime", "Frog", "Mummy", "wizard", "Ogre", "observer"]:
    name = src.lower()
    im = Image.open(os.path.join(DIR, src + ".png")).convert("RGBA")
    anims = ",\n".join('&"%s": Vector3i(0, 1, 1)' % a for a in ANIMS)
    text = ('[gd_resource type="Resource" script_class="SpriteSet" format=3]\n\n'
            '[ext_resource type="Script" path="res://core/defs/sprite_set.gd" id="1_set"]\n'
            '[ext_resource type="Texture2D" path="%s%s.png" id="2_battle"]\n\n'
            '[resource]\nscript = ExtResource("1_set")\nbattle_sheet = ExtResource("2_battle")\n'
            'battle_frame = Vector2i(%d, %d)\nbattle_faces_right = false\n'
            'anims = Dictionary[StringName, Vector3i]({\n%s\n})\n') % (RES, src, im.width, im.height, anims)
    with open(os.path.join(DIR, name + ".tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

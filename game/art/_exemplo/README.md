# art/_exemplo — arte PLACEHOLDER

Estas imagens são **placeholders gerados por script** (`game/tools/art/gen_placeholders.py`), só para provar o pipeline de arte (M16). Não são arte final e podem ser apagadas ou substituídas.

| Arquivo | O que é |
|---|---|
| `teste_a_map.png` | folha de mapa do Teste A: 3 colunas x 4 linhas de quadros 32x48. Linhas: baixo (D), esquerda (L), direita (R), cima (U). O quadro 2 (do meio) é o parado. |
| `teste_a.tres` | `SpriteSet` do Teste A (mapa, batalha e retratos; ligado em `data/fatia/heroes/teste_a_f.tres`). |
| `npc_map.png` | folha de mapa de um NPC, mesma grade (letra N). |
| `npc_exemplo.tres` | `SpriteSet` do NPC. |
| `morador_a_exemplo.tres` | `SpeakerDef` ligado ao Morador A da cidade. |
| `teste_a_battle.png`, `inimigo_f1_battle.png` | folhas de batalha 64x64, viradas para a direita. Linhas: idle (2 quadros), attack (3), cast (3), hit (2), down (1), victory (2). Cada quadro mostra a letra da animação e o número. |
| `inimigo_f1.tres` | `SpriteSet` do Inimigo F1 (ligado em `data/fatia/enemies/inimigo_f1.tres`). |
| `teste_a_portrait_neutro.png`, `teste_a_portrait_feliz.png`, `morador_a_portrait_neutro.png` | retratos 96x96 (`neutro` e `feliz` do Teste A; `neutro` do Morador A). |

Para gerar de novo: `python game/tools/art/gen_placeholders.py`.

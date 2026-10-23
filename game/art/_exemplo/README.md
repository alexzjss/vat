# art/_exemplo — arte PLACEHOLDER

Estas imagens são **placeholders gerados por script** (`game/tools/art/gen_placeholders.py`), só para provar o pipeline de arte (M16). Não são arte final e podem ser apagadas ou substituídas.

| Arquivo | O que é |
|---|---|
| `teste_a_map.png` | folha de mapa do Teste A: 3 colunas x 4 linhas de quadros 32x48. Linhas: baixo (D), esquerda (L), direita (R), cima (U). O quadro 2 (do meio) é o parado. |
| `teste_a.tres` | `SpriteSet` do Teste A (ligado em `data/fatia/heroes/teste_a_f.tres`). |
| `npc_map.png` | folha de mapa de um NPC, mesma grade (letra N). |
| `npc_exemplo.tres` | `SpriteSet` do NPC. |
| `morador_a_exemplo.tres` | `SpeakerDef` ligado ao Morador A da cidade. |

Para gerar de novo: `python game/tools/art/gen_placeholders.py`.

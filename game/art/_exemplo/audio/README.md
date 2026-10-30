# Áudio de exemplo (placeholders)

Estes `.wav` são **placeholders gerados por script**: bipes, estalos e laços de acordes simples, só para provar o
pipeline de áudio (M19) na fatia. Não são arte final.

- Mono, 8 bits, 11025 Hz. O conjunto todo tem cerca de 300 KB.
- Músicas (`musica_*.wav`): laços de 4 s. Jingles (`jingle_*.wav`): 2 a 2,4 s, tocados uma vez. Efeitos (`sfx_*.wav`): menos de 0,6 s.

## Gerar de novo

```
python game/tools/audio/gen_placeholders.py            # escreve aqui
python game/tools/audio/gen_placeholders.py <pasta>    # escreve em outra pasta
```

O gerador só usa a biblioteca padrão do Python e tem semente fixa: rodar de novo dá arquivos idênticos byte a byte.

## Trocar por sons de verdade

Os ids dos `SoundDef`/`MusicDef` (em `data/fatia/audio/`) ficam; só o `stream` muda. Ponha o `.ogg` ou `.wav` novo em
qualquer pasta de `art/`, deixe o Godot importar e aponte o `stream` do def para ele (no inspetor ou no painel VAT).
Nada mais precisa mudar: mapas, encontros e habilidades referenciam o id.

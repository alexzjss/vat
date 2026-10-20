Conteúdo genérico de teste (Teste A/B/C, Inimigo X/Y/Z): VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8).

- `items/cristal_reinicio.tres`: Cristal de Reinício (item-chave). Usado no ponto de descanso para reiniciar a alocação de atributos de um herói; gasta 1 unidade. O inventário inicial do jogo traz 1 para teste.
- `items/chave_teste.tres`: Chave de Teste (item-chave, `key_item = true`). Abre a porta trancada da dungeon de teste e não é gasta. Fica num dos baús da dungeon.
- `encounters/encontro_x.tres`: encontro com o Inimigo X. Usado pelo patrulheiro, pelo escondido (`lurking`) e por um dos inimigos da dupla de grupo.
- `encounters/encontro_y.tres`: encontro com o Inimigo Y. Usado pelo perseguidor e pelo outro inimigo da dupla de grupo.
- `encounters/chefe_teste.tres`: chefe de teste com o Inimigo Z sozinho. `can_flee = false` (não permite fuga) e `unique_id = chefe_teste` (não reaparece depois de vencido).

Golpes de Limite (um por herói de teste, sem custo de AP; nomes placeholder):

- `abilities/limite_a.tres`: **Golpe Final** (herói A). Dano alto em um inimigo (SINGLE), potência 3.5.
- `abilities/limite_b.tres`: **Chuva de Flechas** (herói B). Dano em todos os inimigos (ALL), potência 1.8.
- `abilities/limite_c.tres`: **Luz Restauradora** (herói C). Cura todos os aliados (ALL), potência 4.0.
- `abilities/limite_d.tres`: **Investida Dupla** (herói D). Dois golpes em linha (LINE), potência 1.4 cada.
- `abilities/limite_e.tres`: **Onda de Aura** (herói E). Dano em área de raio 180 ao redor do alvo (CIRCLE_TARGET), potência 2.2.

Learnsets (M9): cada herói aprende a técnica ao alcançar o nível indicado. Nível 0 significa só por evento (não é aprendida por nível). Os nomes são os ids dos arquivos em `abilities/`.

- `heroes/teste_a.tres` (Teste A): `investida` (nv 1), `golpe_area` (nv 3), `golpe_pesado` (nv 6), `lamina` (nv 10), `rajada` (evento).
- `heroes/teste_b.tres` (Teste B): `cura` (nv 1), `barreira` (nv 3), `pressa` (nv 6), `sono` (nv 10), `cura_maior` (nv 15), `tempestade` (evento).
- `heroes/teste_c.tres` (Teste C): `veneno` (nv 1), `lentidao` (nv 3), `pulso` (nv 6), `raio` (nv 10), `tempestade` (nv 15), `sono` (evento).
- `heroes/teste_d.tres` (Teste D): `golpe_area` (nv 1), `cura` (nv 3), `investida` (nv 6), `golpe_pesado` (nv 10), `cura_maior` (nv 20), `lamina` (evento).
- `heroes/teste_e.tres` (Teste E): `pulso` (nv 1), `veneno` (nv 3), `raio` (nv 6), `tempestade` (nv 10), `cura` (nv 15), `lentidao` (evento).

Habilidades placeholder novas (M9), com efeitos já existentes e potências coerentes com o custo: `golpe_pesado`, `lamina`, `raio`, `tempestade` e `cura_maior`.

Eventos (M10), em `events/` (roteiros de teste, lidos pelo `EventRunner`):

- `events/npc_guia.tres`: roteiro do Guia da dungeon de teste. Pergunta "Aprender a técnica?" com as opções "Sim" e "Não". Em "Sim", ensina `rajada` ao Teste A, dá 60 de XP narrativa e grava a flag `guia_ensinou`; depois de ensinada, a fala muda e não ensina de novo.
- `events/cena_final.tres`: cena da sala final, disparada ao entrar. O Vigia (`NpcFinal`) anda até o `CenaMarker`, fala duas linhas, a câmera vai ao `BossSpot` e espera um instante.

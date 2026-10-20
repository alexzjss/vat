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

Estados (M11), em `statuses/`. Valores de teste:

- `statuses/stop.tres`: Pare (`STOP`). Dura 4 segundos de batalha (`seconds`), não turnos. Negativo.
- `statuses/confusion.tres`: Confusão (`CONFUSION`), 3 turnos. Negativo.
- `statuses/silence.tres`: Silêncio (`SILENCE`), 3 turnos. Negativo.
- `statuses/blind.tres`: Cegueira (`BLIND`), 3 turnos. Negativo.
- `statuses/regen.tres`: Regeneração (`REGEN`), 4 turnos. Positivo.
- `statuses/str_down.tres`, `statuses/vit_down.tres`, `statuses/spd_down.tres`: debuffs de Força, Vitalidade e Velocidade (`ATTR_MOD`, potência -4, 3 turnos). Negativos.
- `statuses/vit_up.tres`, `statuses/spd_up.tres`: buffs de Vitalidade e Velocidade (`ATTR_MOD`, potência +4, 3 turnos). O buff de Força é `statuses/str_up.tres`, que já existia.

Habilidades que aplicam estados (M11), em `abilities/`. Quem é alvo: os adversários, exceto Regeneração, que vai a aliados:

- `abilities/pare.tres`, `abilities/confusao.tres`, `abilities/silencio.tres`, `abilities/cegueira.tres`: aplicam, cada uma, o estado de mesmo nome, com 70% de chance.
- `abilities/fraqueza.tres`, `abilities/fragilidade.tres`, `abilities/atraso.tres`: aplicam os debuffs de Força, Vitalidade e Velocidade, com 80% de chance.
- `abilities/regeneracao.tres`: aplica Regeneração a aliados.
- Fraqueza, Fragilidade, Atraso e Regeneração não estão em nenhum inimigo nem herói de teste; `tests/test_status_ui.gd` confere que cada uma aplica o estado certo.

Itens de estado (M11), em `items/`. Só funcionam na batalha; não entram no inventário inicial de teste (o simulador os usa no cenário do chefe):

- `items/remedio.tres`: Remédio. Remove Confusão, Silêncio e Cegueira de um aliado (lista em `EffectDef.statuses`).
- `items/panaceia.tres`: Panaceia. Remove todos os estados negativos de um aliado (`EffectDef` com lista vazia e `status` nulo).

Chefe de teste (M11), em `enemies/` e `encounters/`. Valores de teste:

- `enemies/guardiao_teste.tres`: Guardião (teste), núcleo (`CORE`), nível 9. Fases em 66% ("Fase 2 (teste)") e 33% ("Fase 3 (teste)"). Contra-ataque `abilities/contra_ataque.tres` com 50% de chance, só para ataque básico (`counter_only_basic`).
- `enemies/braco_teste.tres`: Braço (teste), parte (`PART`), nível 6, com `shields_core = true`. Ataca o herói mais próximo (`NEAREST`).
- `abilities/golpe_sismico.tres`: Golpe Sísmico, atinge todos os heróis (`ALL`), custo 6 AP. É a habilidade anunciada na fase 3.
- `abilities/reerguer.tres`: reviver um aliado caído (`REVIVE`), custo 4 AP. Usada pelo Guardião na fase 2, quando um Braço cai.
- `encounters/chefe_dungeon.tres`: Guardião com dois Braços. `can_flee = false` (não permite fuga) e `unique_id = chefe_dungeon` (não reaparece depois de vencido). Fica no `BossSpot` da dungeon de teste, que só aparece depois da flag `cena_final`.

Os learnsets dos heróis não mudam em M11: nenhum herói aprende os estados novos nem os itens de estado.

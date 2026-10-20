Conteúdo genérico de teste (Teste A/B/C, Inimigo X/Y/Z): VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8).

- `items/cristal_reinicio.tres`: Cristal de Reinício (item-chave). Usado no ponto de descanso para reiniciar a alocação de atributos de um herói; gasta 1 unidade. O inventário inicial do jogo traz 1 para teste.
- `encounters/encontro_x.tres`: encontro com o Inimigo X. Usado pelo patrulheiro, pelo escondido (`lurking`) e por um dos inimigos da dupla de grupo.
- `encounters/encontro_y.tres`: encontro com o Inimigo Y. Usado pelo perseguidor e pelo outro inimigo da dupla de grupo.
- `encounters/chefe_teste.tres`: chefe de teste com o Inimigo Z sozinho. `can_flee = false` (não permite fuga) e `unique_id = chefe_teste` (não reaparece depois de vencido).

Golpes de Limite (um por herói de teste, sem custo de AP; nomes placeholder):

- `abilities/limite_a.tres`: **Golpe Final** (herói A). Dano alto em um inimigo (SINGLE), potência 3.5.
- `abilities/limite_b.tres`: **Chuva de Flechas** (herói B). Dano em todos os inimigos (ALL), potência 1.8.
- `abilities/limite_c.tres`: **Luz Restauradora** (herói C). Cura todos os aliados (ALL), potência 4.0.
- `abilities/limite_d.tres`: **Investida Dupla** (herói D). Dois golpes em linha (LINE), potência 1.4 cada.
- `abilities/limite_e.tres`: **Onda de Aura** (herói E). Dano em área de raio 180 ao redor do alvo (CIRCLE_TARGET), potência 2.2.

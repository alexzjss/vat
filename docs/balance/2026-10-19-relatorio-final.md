# Relatorio final de balanceamento (M5b)

Baseline: **padrao escolhido (balance.tres)**. Gerado por `run_sim.ps1 -Final` (30 execucoes por cenario; grupo = herois de teste A-D com equipamento, alocacao `main`; itens: Pocao 3, Eter 2, Reviver 1; sementes 1..N). Valores de teste, nao canonicos.

## Metas

- `smart`: 20-60 s de duracao media (X+Y pode ser menor) e vitoria >= 95%.
- `basic`: vitoria >= 75%.

## Cenarios-meta

| Cenario | Politica | Vitorias | Dur media (s) | Dur mediana (s) | HP final | Meta |
|---|---|---|---|---|---|---|
| N1 X+Y | basic | 100% | 25.1 | 24.3 | 64% | ok |
| N1 X+Y | smart | 100% | 45.7 | 44.1 | 46% | ok |
| N5 X+Y | basic | 100% | 18.5 | 17.5 | 80% | ok |
| N5 X+Y | smart | 100% | 41.6 | 45.2 | 87% | ok |
| N5 X+Y+Z | basic | 100% | 30.8 | 30.0 | 69% | ok |
| N5 X+Y+Z | smart | 100% | 55.4 | 56.1 | 88% | ok |
| N10 X+Y+Z | basic | 100% | 27.6 | 27.4 | 80% | ok |
| N10 X+Y+Z | smart | 100% | 43.3 | 43.0 | 88% | ok |

## Detalhe

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes; so execucoes em que o inimigo morreu) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| escolhido - N1 X+Y basic | 30 | 30 | 0 | 0 | 25.1 | 24.3 | 3.0 | 7.7 | 0.0 | inimigo_x 6.3, inimigo_y 12.0 | 64% | 0.0 | teste_a 89 (1), teste_b 21 (3), teste_c 23 (2), teste_d 65 (1) | 0/0 |
| escolhido - N1 X+Y smart | 30 | 30 | 0 | 0 | 45.7 | 44.1 | 4.5 | 7.0 | 7.9 | inimigo_y 16.3, inimigo_x 18.2 | 46% | 67.7 | teste_a 72 (1), teste_b 60 (1), teste_c 3 (18), teste_d 63 (1) | 48/17 |
| escolhido - N5 X+Y basic | 30 | 30 | 0 | 0 | 18.5 | 17.5 | 2.4 | 7.6 | 0.0 | inimigo_x 6.0, inimigo_y 9.6 | 80% | 0.0 | teste_a 73 (3), teste_b 60 (3), teste_c 0 (381), teste_d 63 (3) | 0/0 |
| escolhido - N5 X+Y smart | 30 | 30 | 0 | 0 | 41.6 | 45.2 | 5.0 | 7.8 | 5.2 | inimigo_y 17.2, inimigo_x 19.1 | 87% | 70.7 | teste_a 49 (4), teste_b 99 (2), teste_c 3 (65), teste_d 47 (4) | 111/64 |
| escolhido - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 30.8 | 30.0 | 4.6 | 7.6 | 0.0 | inimigo_x 5.9, inimigo_y 9.7, inimigo_z 18.3 | 69% | 0.0 | teste_a 132 (2), teste_b 74 (3), teste_c 24 (8), teste_d 116 (2) | 0/0 |
| escolhido - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 55.4 | 56.1 | 7.2 | 8.6 | 5.8 | inimigo_y 21.7, inimigo_x 20.6, inimigo_z 28.7 | 88% | 94.1 | teste_a 85 (2), teste_b 171 (1), teste_c 5 (36), teste_d 86 (2) | 148/89 |
| escolhido - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 27.6 | 27.4 | 4.3 | 7.9 | 0.0 | inimigo_x 5.0, inimigo_y 9.1, inimigo_z 17.1 | 80% | 0.0 | teste_a 121 (3), teste_b 97 (4), teste_c 11 (29), teste_d 116 (3) | 0/0 |
| escolhido - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 43.3 | 43.0 | 5.3 | 6.7 | 9.3 | inimigo_x 16.2, inimigo_y 16.1, inimigo_z 21.4 | 88% | 83.0 | teste_a 102 (4), teste_b 146 (3), teste_c 3 (105), teste_d 95 (4) | 137/92 |

## Antes x depois

| Valor | Antes | Depois | Motivo |
|---|---|---|---|
| Inimigo X: Forca/Vel/Vit | 11 / 9 / 8 | 27 / 10 / 5 | Forca 2,5x o original (teto), Vit >= 5; Vel 10 mantem a pressao do basic em N5 X+Y+Z |
| Inimigo Y: Forca/Vel/Vit | 8 / 7 / 7 | 20 / 12 / 5 | Forca 2,5x, Vit 5; Vel 12 (ameaca rapida e fragil) |
| Inimigo Z: Forca/Vel/Vit | 13 / 2 / 12 | 32 / 7 / 12 | Forca 2,5x, Vit mantida; Vel 7 (a Vel de Z e a alavanca fina: 8 derruba smart para 87%) |
| HP: hp_base | 30 (codigo) | 0 | Com Vit >= 5 nos inimigos, a base 30 deixava as batalhas longas demais (smart 60-80 s) |
| HP: hp_vit_a | 8 (codigo) | 5 | HP = Vit*5 + Nv*3 + Vit*Nv*0,2 (estilo FF: cresce com o nivel); dificuldade classica |
| HP: hp_lvl_b | 4 (codigo) | 3 | Crescimento por nivel mantido (heroi HP 10 tem mais HP que HP 1 com a mesma Vit) |
| HP: hp_vit_lvl_c | 0,4 (codigo) | 0,2 | Termo Vit x Nivel mais suave |
| RD: dr_band2_start | 20 (codigo) | 13 | Faixa 2 mais cedo: retornos decrescentes a partir de 13 |
| RD: dr_band2_factor | 0,5 (codigo) | 0,45 | Faixa 2 um pouco mais dura |
| Dano: dmg_ratio_k | 20,0 (codigo) | 20,0 | Sem mudanca (variar k 20-80 quase nao alterou os resultados) |
| Itens (Pocao 3 / Eter 2 / Reviver 1) | sem mudanca | sem mudanca | Nao foi preciso mexer |
| xp_base dos inimigos (100/100/150) | sem mudanca | sem mudanca | Nao foi preciso mexer |

- A familia "difícil" (fator unico sobre os inimigos) foi desligada no M5b: o conteudo foi reajustado para as formulas escolhidas e os cenarios-meta ja exercem `basic` entre ~50% e 100% de vitoria; o fator antigo (x1,125) era uma aresta de faca calibrada para os atributos antigos.
- TTK (acoes) e a media so das execucoes em que o inimigo morreu (derrotas/tempos esgotados nao entram).
- Diferencas pequenas (alguns pontos de vitoria) em poucas execucoes sao ruido, nao efeito da formula.

# Relatorio final de balanceamento (M5b)

Baseline: **padrao escolhido (balance.tres)**. Gerado por `run_sim.ps1 -Final` (30 execucoes por cenario; grupo = herois de teste A-D com equipamento, alocacao `main`; itens: Pocao 3, Eter 2, Reviver 1; sementes 1..N). Valores de teste, nao canonicos.

## Metas

- `smart`: 20-60 s de duracao media (X+Y pode ser menor) e vitoria >= 95%.
- `basic`: vitoria >= 75%.

## Cenarios-meta

| Cenario | Politica | Vitorias | Dur media (s) | Dur mediana (s) | HP final | Meta |
|---|---|---|---|---|---|---|
| N1 X+Y | basic | 100% | 23.2 | 22.1 | 57% | ok |
| N1 X+Y | smart | 97% | 45.9 | 44.6 | 25% | ok |
| N5 X+Y | basic | 100% | 22.6 | 23.0 | 67% | ok |
| N5 X+Y | smart | 100% | 33.0 | 29.5 | 80% | ok |
| N5 X+Y+Z | basic | 83% | 44.4 | 42.3 | 23% | ok |
| N5 X+Y+Z | smart | 97% | 53.7 | 50.9 | 41% | ok |
| N10 X+Y+Z | basic | 100% | 34.0 | 33.9 | 47% | ok |
| N10 X+Y+Z | smart | 100% | 49.4 | 49.6 | 66% | ok |

## Detalhe

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes; so execucoes em que o inimigo morreu) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| escolhido - N1 X+Y basic | 30 | 30 | 0 | 0 | 23.2 | 22.1 | 2.8 | 8.0 | 0.0 | inimigo_y 6.2, inimigo_x 11.2 | 57% | 0.0 | teste_a 92 (1), teste_b 17 (3), teste_c 29 (2), teste_d 61 (1) | 0/0 |
| escolhido - N1 X+Y smart | 30 | 29 | 1 | 0 | 45.9 | 44.6 | 4.3 | 8.2 | 9.8 | inimigo_x 15.8, inimigo_y 17.0 | 25% | 62.8 | teste_a 85 (1), teste_b 38 (2), teste_c 0 (?), teste_d 74 (1) | 13/6 |
| escolhido - N5 X+Y basic | 30 | 30 | 0 | 0 | 22.6 | 23.0 | 2.9 | 8.2 | 0.0 | inimigo_y 7.2, inimigo_x 11.7 | 67% | 0.0 | teste_a 72 (3), teste_b 36 (5), teste_c 22 (8), teste_d 69 (3) | 0/0 |
| escolhido - N5 X+Y smart | 30 | 30 | 0 | 0 | 33.0 | 29.5 | 4.1 | 8.2 | 6.7 | inimigo_x 14.6, inimigo_y 14.9 | 80% | 57.5 | teste_a 55 (3), teste_b 80 (3), teste_c 12 (14), teste_d 48 (4) | 108/28 |
| escolhido - N5 X+Y+Z basic | 30 | 25 | 5 | 0 | 44.4 | 42.3 | 5.4 | 9.0 | 0.0 | inimigo_y 7.0, inimigo_x 11.0, inimigo_z 21.9 | 23% | 0.0 | teste_a 161 (2), teste_b 38 (5), teste_c 18 (10), teste_d 130 (2) | 0/0 |
| escolhido - N5 X+Y+Z smart | 30 | 29 | 1 | 0 | 53.7 | 50.9 | 6.4 | 10.0 | 7.7 | inimigo_y 13.0, inimigo_x 15.5, inimigo_z 25.4 | 41% | 70.2 | teste_a 126 (2), teste_b 80 (3), teste_c 18 (10), teste_d 122 (2) | 90/46 |
| escolhido - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 34.0 | 33.9 | 4.8 | 9.8 | 0.0 | inimigo_y 5.0, inimigo_x 9.0, inimigo_z 19.1 | 47% | 0.0 | teste_a 146 (3), teste_b 47 (7), teste_c 19 (17), teste_d 135 (3) | 0/0 |
| escolhido - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 49.4 | 49.6 | 6.2 | 10.5 | 9.1 | inimigo_x 15.2, inimigo_y 16.2, inimigo_z 25.0 | 66% | 86.8 | teste_a 121 (3), teste_b 109 (3), teste_c 11 (29), teste_d 104 (4) | 117/77 |

## Antes x depois

| Valor | Antes | Depois | Motivo |
|---|---|---|---|
| Inimigo X: Forca/Vel/Vit | 11 / 9 / 8 | 54 / 10 / 2 | Dano e HP pensados para dificuldade classica com HP = base + Vit*5 e dano por razao; ajuste fino (Forca 54, Vel 10) leva o basic de 63% para 83% em N5 X+Y+Z |
| Inimigo Y: Forca/Vel/Vit | 8 / 7 / 7 | 47 / 12 / 1 | Mesmo criterio: ameacas mais rapidas e fragéis (poucos HP), dano alto contra o grupo |
| Inimigo Z: Forca/Vel/Vit | 13 / 2 / 12 | 62 / 7 / 16 | Mesmo criterio: tanque lento com dano alto; N5/N10 X+Y+Z sao as batalhas mais longas |
| HP: hp_vit_a | 8 (codigo) | 5 | HP = 30 + Vit*5 (modo B): curva mais baixa, dificuldade classica |
| HP: hp_lvl_b | 4 (codigo) | 0 | HP nao cresce direto com o nivel, so via Vit |
| HP: hp_vit_lvl_c | 0,4 (codigo) | 0,0 | Sem termo Vit x Nivel (crescimento so pela alocacao) |
| RD: dr_band2_start | 20 (codigo) | 13 | Faixa 2 mais cedo: retornos decrescentes a partir de 13 |
| RD: dr_band2_factor | 0,5 (codigo) | 0,45 | Faixa 2 um pouco mais dura |
| Dano: dmg_ratio_k | 20,0 (codigo) | 20,45 | k/(k+defesa): ajuste fino para acertar as metas |
| Itens (Pocao 3 / Eter 2 / Reviver 1) | sem mudanca | sem mudanca | Nao foi preciso mexer |
| xp_base dos inimigos (100/100/150) | sem mudanca | sem mudanca | Nao foi preciso mexer |

- A familia "difícil" (fator unico sobre os inimigos) foi desligada no M5b: o conteudo foi reajustado para as formulas escolhidas e os cenarios-meta ja exercem `basic` entre ~50% e 100% de vitoria; o fator antigo (x1,125) era uma aresta de faca calibrada para os atributos antigos.
- TTK (acoes) e a media so das execucoes em que o inimigo morreu (derrotas/tempos esgotados nao entram).
- Diferencas pequenas (alguns pontos de vitoria) em poucas execucoes sao ruido, nao efeito da formula.

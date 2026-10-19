# Relatorio comparativo de formulas (M5a)

Gerado por `run_sim.ps1` (30 execucoes por cenario; grupo = herois de teste A-D com equipamento, alocacao `main`; itens: Pocao 3, Eter 2, Reviver 1; sementes 1..N, deterministico). Valores de teste, nao canonicos.

## Metas

- Batalha comum: 30-60 s de duracao com a politica `smart` e vitoria >= 90%.
- Politica `basic`: vitoria entre 40% e 70% (pressao real sem ser impossivel).
- Chefe de teste: 2-4 min.
- Chefe: a meta de 2-4 min ainda nao tem cenario (nao ha chefe de teste; fica para o M11).
- Cenario "difícil": nivel 1, X+Y+Z com atributos dos inimigos multiplicados por um fator (ver abaixo), para medir a pressao com `basic` (meta 40-70%) e dar efeito a Reviver, Veneno e duracoes.
- Fonte: spec M5 (`docs/superpowers/specs/2026-10-19-m5-formulas-design.md`, §4).
- Cada formula varia apenas ela mesma sobre o padrao (tudo A); a opcao A das tabelas e o padrao.

## Padrao (tudo A)

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| padrao - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| padrao - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| padrao - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| padrao - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| padrao - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| padrao - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| padrao - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| padrao - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| padrao - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| padrao - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| padrao - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| padrao - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| padrao - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| padrao - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

## F1 - Retornos decrescentes

- A: 1 limiar (ate 20 integral, acima x0,5)
- B: faixas estilo Souls (x1 / x0,5 / x0,25)
- C: suave limite*v/(v+k)

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F1-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F1-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F1-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F1-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F1-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F1-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F1-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F1-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F1-B | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F1-B | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F1-B | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F1-B | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F1-B | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F1-B | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F1-B | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F1-B | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F1-C | basic | 1 | 100% | 0 | 79.4 | 79.1 | 6.6 | 0.0 | 65% | 68 | 1.1 |
| F1-C | smart | 1 | 100% | 0 | 85.2 | 85.7 | 6.2 | 6.3 | 86% | 68 | 1.3 |
| F1-C | basic | 5 | 100% | 0 | 59.9 | 59.7 | 8.4 | 0.0 | 80% | 68 | 2.5 |
| F1-C | smart | 5 | 100% | 0 | 47.5 | 46.4 | 9.8 | 11.8 | 90% | 68 | 33.4 |
| F1-C | basic | 10 | 100% | 0 | 49.7 | 48.7 | 10.1 | 0.0 | 86% | 68 | 5.2 |
| F1-C | smart | 10 | 100% | 0 | 38.3 | 37.8 | 9.4 | 14.7 | 92% | 68 | 35.6 |
| F1-C | basic | 1 difícil | 0% | 0 | 145.3 | 143.9 | 8.3 | 0.0 | 0% | 0 | ? |
| F1-C | smart | 1 difícil | 70% | 0 | 232.6 | 232.9 | 7.5 | 6.0 | 7% | 86 | 3.0 |

<details><summary>Detalhe por cenario</summary>

**F1-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F1-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F1-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F1-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F1-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F1-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F1-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F1-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F1-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F1-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F1-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F1-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F1-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F1-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F1-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F1-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F1-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F1-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F1-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F1-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F1-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F1-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F1-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F1-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F1-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F1-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F1-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F1-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F1-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F1-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F1-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F1-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 59.8 | 59.2 | 8.8 | 6.8 | 0.0 | inimigo_y 16.5, inimigo_x 35.3 | 71% | 0.0 | teste_a 87 (1), teste_b 49 (1), teste_c 8 (2), teste_d 53 (1) | 0/0 |
| F1-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 62.1 | 62.7 | 9.9 | 7.1 | 6.1 | inimigo_y 30.5, inimigo_x 39.4 | 86% | 154.3 | teste_a 85 (1), teste_b 55 (1), teste_c 4 (3), teste_d 53 (1) | 284/129 |
| F1-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 99.0 | 99.0 | 16.1 | 6.5 | 0.0 | inimigo_y 16.5, inimigo_x 35.3, inimigo_z 64.2 | 58% | 0.0 | teste_a 173 (1), teste_b 50 (1), teste_c 28 (1), teste_d 95 (1) | 0/0 |
| F1-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 108.4 | 108.7 | 18.1 | 5.4 | 6.5 | inimigo_y 34.2, inimigo_x 43.1, inimigo_z 72.4 | 85% | 171.4 | teste_a 142 (1), teste_b 95 (1), teste_c 14 (1), teste_d 95 (1) | 341/166 |
| F1-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 46.7 | 46.8 | 6.8 | 8.8 | 0.0 | inimigo_y 12.7, inimigo_x 27.3 | 80% | 0.0 | teste_a 83 (2), teste_b 47 (2), teste_c 0 (?), teste_d 68 (2) | 0/0 |
| F1-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.2 | 34.9 | 5.6 | 8.6 | 11.6 | inimigo_y 19.8, inimigo_x 22.3 | 92% | 107.4 | teste_a 75 (2), teste_b 45 (3), teste_c 0 (225), teste_d 77 (2) | 194/85 |
| F1-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 73.1 | 72.7 | 12.8 | 8.1 | 0.0 | inimigo_y 12.7, inimigo_x 27.1, inimigo_z 51.3 | 80% | 0.0 | teste_a 149 (1), teste_b 60 (2), teste_c 13 (8), teste_d 124 (1) | 0/0 |
| F1-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 58.8 | 57.9 | 9.4 | 11.1 | 11.9 | inimigo_y 22.4, inimigo_x 25.8, inimigo_z 37.5 | 89% | 139.3 | teste_a 134 (1), teste_b 75 (2), teste_c 3 (31), teste_d 134 (1) | 308/159 |
| F1-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 38.8 | 37.7 | 5.7 | 10.5 | 0.0 | inimigo_y 10.7, inimigo_x 22.8 | 87% | 0.0 | teste_a 85 (3), teste_b 40 (5), teste_c 0 (?), teste_d 73 (3) | 0/0 |
| F1-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 31.3 | 31.4 | 4.8 | 5.9 | 13.3 | inimigo_y 16.0, inimigo_x 19.2 | 94% | 94.6 | teste_a 76 (3), teste_b 45 (5), teste_c 1 (133), teste_d 75 (3) | 201/82 |
| F1-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 60.7 | 59.7 | 10.7 | 9.7 | 0.0 | inimigo_y 10.8, inimigo_x 22.7, inimigo_z 42.7 | 86% | 0.0 | teste_a 150 (2), teste_b 51 (4), teste_c 10 (19), teste_d 135 (2) | 0/0 |
| F1-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 45.4 | 44.1 | 7.0 | 12.9 | 16.1 | inimigo_y 16.0, inimigo_x 19.2, inimigo_z 28.2 | 89% | 109.9 | teste_a 147 (2), teste_b 55 (4), teste_c 1 (133), teste_d 143 (2) | 253/124 |
| F1-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 0 | 20 | 0 | 145.3 | 143.9 | 14.3 | 8.3 | 0.0 | inimigo_y 47.4, inimigo_x 59.7 | 0% | 0.0 | teste_a 0 (?), teste_b 0 (?), teste_c 0 (?), teste_d 0 (?) | 0/0 |
| F1-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 14 | 6 | 0 | 232.6 | 232.9 | 24.9 | 7.5 | 6.0 | inimigo_y 75.7, inimigo_x 79.3, inimigo_z 101.7 | 7% | 157.8 | teste_a 176 (1), teste_b 93 (1), teste_c 1 (9), teste_d 75 (1) | 176/63 |

</details>

## F2 - HP maximo

- A: Vit*10 + Nv*5
- B: base + Vit*a + Nv*b + Vit*Nv*c
- C: (base + Vit*a)*(1 + Nv*b)

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F2-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F2-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F2-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F2-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F2-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F2-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F2-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F2-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F2-B | basic | 1 | 100% | 0 | 81.1 | 80.6 | 4.6 | 0.0 | 81% | 68 | 1.0 |
| F2-B | smart | 1 | 100% | 0 | 86.9 | 87.6 | 4.7 | 4.8 | 83% | 67 | 1.0 |
| F2-B | basic | 5 | 100% | 0 | 51.1 | 50.4 | 7.2 | 0.0 | 92% | 68 | 3.8 |
| F2-B | smart | 5 | 100% | 0 | 46.3 | 47.1 | 7.2 | 10.3 | 92% | 68 | 3.3 |
| F2-B | basic | 10 | 100% | 0 | 40.2 | 40.2 | 9.1 | 0.0 | 95% | 68 | 10.4 |
| F2-B | smart | 10 | 100% | 0 | 33.1 | 32.4 | 8.3 | 13.7 | 96% | 68 | 8.1 |
| F2-B | basic | 1 difícil | 95% | 0 | 196.7 | 196.5 | 5.0 | 0.0 | 14% | 87 | 1.0 |
| F2-B | smart | 1 difícil | 100% | 0 | 187.5 | 189.4 | 4.7 | 3.6 | 40% | 86 | 1.0 |
| F2-C | basic | 1 | 100% | 0 | 81.5 | 81.1 | 4.6 | 0.0 | 81% | 68 | 1.0 |
| F2-C | smart | 1 | 100% | 0 | 87.3 | 87.8 | 4.7 | 4.8 | 83% | 67 | 1.0 |
| F2-C | basic | 5 | 100% | 0 | 51.4 | 50.4 | 7.2 | 0.0 | 92% | 68 | 3.8 |
| F2-C | smart | 5 | 100% | 0 | 46.3 | 47.1 | 7.3 | 10.3 | 93% | 68 | 3.3 |
| F2-C | basic | 10 | 100% | 0 | 40.3 | 40.2 | 9.1 | 0.0 | 95% | 68 | 10.4 |
| F2-C | smart | 10 | 100% | 0 | 33.2 | 32.5 | 8.4 | 13.6 | 96% | 68 | 8.1 |
| F2-C | basic | 1 difícil | 95% | 0 | 198.8 | 199.4 | 5.0 | 0.0 | 13% | 87 | 1.0 |
| F2-C | smart | 1 difícil | 100% | 0 | 188.7 | 190.7 | 4.7 | 3.6 | 40% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F2-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F2-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F2-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F2-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F2-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F2-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F2-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F2-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F2-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F2-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F2-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F2-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F2-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F2-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F2-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F2-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F2-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 56.0 | 55.3 | 9.1 | 5.3 | 0.0 | inimigo_y 15.9, inimigo_x 36.4 | 81% | 0.0 | teste_a 105 (1), teste_b 29 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F2-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 69.6 | 69.8 | 11.5 | 5.6 | 3.6 | inimigo_y 34.2, inimigo_x 46.0 | 85% | 128.4 | teste_a 71 (1), teste_b 54 (1), teste_c 27 (1), teste_d 44 (1) | 425/129 |
| F2-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 106.2 | 105.9 | 20.5 | 4.0 | 0.0 | inimigo_y 15.8, inimigo_x 36.2, inimigo_z 82.0 | 81% | 0.0 | teste_a 193 (1), teste_b 41 (1), teste_c 13 (1), teste_d 99 (1) | 0/0 |
| F2-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 104.2 | 105.3 | 19.3 | 3.7 | 5.9 | inimigo_y 27.5, inimigo_x 39.0, inimigo_z 77.2 | 81% | 118.6 | teste_a 169 (1), teste_b 65 (1), teste_c 18 (1), teste_d 93 (1) | 230/113 |
| F2-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 36.9 | 36.1 | 6.1 | 7.9 | 0.0 | inimigo_y 11.5, inimigo_x 24.5 | 92% | 0.0 | teste_a 99 (1), teste_b 26 (4), teste_c 0 (?), teste_d 72 (2) | 0/0 |
| F2-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 42.2 | 42.5 | 6.6 | 8.1 | 8.3 | inimigo_y 23.1, inimigo_x 25.7 | 93% | 113.5 | teste_a 70 (2), teste_b 44 (3), teste_c 18 (5), teste_d 64 (2) | 313/104 |
| F2-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 65.2 | 64.7 | 12.6 | 6.5 | 0.0 | inimigo_y 11.6, inimigo_x 24.8, inimigo_z 50.2 | 92% | 0.0 | teste_a 178 (1), teste_b 35 (3), teste_c 6 (16), teste_d 126 (1) | 0/0 |
| F2-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 50.4 | 51.8 | 8.8 | 6.3 | 12.3 | inimigo_y 17.0, inimigo_x 21.5, inimigo_z 35.1 | 92% | 103.1 | teste_a 155 (1), teste_b 49 (2), teste_c 10 (10), teste_d 132 (1) | 216/102 |
| F2-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 30.8 | 30.3 | 5.1 | 9.5 | 0.0 | inimigo_y 9.3, inimigo_x 20.4 | 95% | 0.0 | teste_a 92 (3), teste_b 21 (9), teste_c 0 (?), teste_d 84 (3) | 0/0 |
| F2-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 29.3 | 28.1 | 4.5 | 4.3 | 12.4 | inimigo_x 17.7, inimigo_y 17.0 | 96% | 86.8 | teste_a 68 (3), teste_b 39 (5), teste_c 10 (19), teste_d 79 (3) | 205/69 |
| F2-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 49.7 | 50.1 | 9.4 | 8.7 | 0.0 | inimigo_y 9.4, inimigo_x 20.0, inimigo_z 37.6 | 95% | 0.0 | teste_a 167 (2), teste_b 27 (8), teste_c 4 (51), teste_d 148 (2) | 0/0 |
| F2-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 36.9 | 36.7 | 6.3 | 12.2 | 14.9 | inimigo_y 14.3, inimigo_x 16.2, inimigo_z 25.0 | 96% | 91.6 | teste_a 138 (2), teste_b 51 (4), teste_c 7 (27), teste_d 151 (2) | 214/101 |
| F2-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 19 | 1 | 0 | 196.7 | 196.5 | 22.9 | 5.0 | 0.0 | inimigo_y 38.0, inimigo_x 58.1, inimigo_z 92.0 | 14% | 0.0 | teste_a 236 (1), teste_b 11 (1), teste_c 15 (1), teste_d 85 (1) | 0/0 |
| F2-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 187.5 | 189.4 | 25.1 | 4.7 | 3.6 | inimigo_y 53.8, inimigo_x 68.0, inimigo_z 100.3 | 40% | 125.2 | teste_a 150 (1), teste_b 74 (1), teste_c 42 (1), teste_d 78 (1) | 194/82 |

**F2-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F2-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 56.0 | 55.3 | 9.1 | 5.3 | 0.0 | inimigo_y 15.9, inimigo_x 36.4 | 81% | 0.0 | teste_a 105 (1), teste_b 29 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F2-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 69.6 | 69.8 | 11.5 | 5.6 | 3.6 | inimigo_y 34.2, inimigo_x 46.0 | 85% | 128.4 | teste_a 71 (1), teste_b 54 (1), teste_c 27 (1), teste_d 44 (1) | 425/129 |
| F2-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 106.9 | 107.0 | 20.7 | 4.0 | 0.0 | inimigo_y 15.8, inimigo_x 36.2, inimigo_z 82.7 | 81% | 0.0 | teste_a 192 (1), teste_b 41 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F2-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 105.0 | 105.9 | 19.5 | 3.7 | 5.9 | inimigo_y 27.5, inimigo_x 39.0, inimigo_z 77.9 | 81% | 118.6 | teste_a 169 (1), teste_b 64 (1), teste_c 17 (1), teste_d 93 (1) | 230/113 |
| F2-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 36.9 | 36.1 | 6.1 | 7.9 | 0.0 | inimigo_y 11.5, inimigo_x 24.5 | 92% | 0.0 | teste_a 99 (1), teste_b 26 (4), teste_c 0 (?), teste_d 72 (2) | 0/0 |
| F2-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 42.2 | 42.5 | 6.6 | 8.1 | 8.3 | inimigo_y 23.1, inimigo_x 25.7 | 93% | 113.5 | teste_a 70 (2), teste_b 44 (3), teste_c 18 (5), teste_d 64 (2) | 313/104 |
| F2-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 65.8 | 64.7 | 12.7 | 6.5 | 0.0 | inimigo_y 11.6, inimigo_x 24.8, inimigo_z 50.8 | 92% | 0.0 | teste_a 179 (1), teste_b 35 (3), teste_c 6 (16), teste_d 125 (1) | 0/0 |
| F2-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 50.5 | 51.8 | 8.8 | 6.4 | 12.3 | inimigo_y 17.0, inimigo_x 21.5, inimigo_z 35.1 | 92% | 103.2 | teste_a 156 (1), teste_b 49 (2), teste_c 10 (10), teste_d 131 (1) | 217/102 |
| F2-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 30.8 | 30.3 | 5.1 | 9.5 | 0.0 | inimigo_y 9.3, inimigo_x 20.4 | 95% | 0.0 | teste_a 92 (3), teste_b 21 (9), teste_c 0 (?), teste_d 84 (3) | 0/0 |
| F2-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 29.3 | 28.1 | 4.5 | 4.3 | 12.4 | inimigo_x 17.7, inimigo_y 17.0 | 97% | 86.8 | teste_a 68 (3), teste_b 39 (5), teste_c 10 (19), teste_d 79 (3) | 205/69 |
| F2-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 49.7 | 50.1 | 9.4 | 8.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.0, inimigo_z 37.6 | 95% | 0.0 | teste_a 167 (2), teste_b 27 (8), teste_c 4 (51), teste_d 148 (2) | 0/0 |
| F2-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 37.1 | 36.8 | 6.3 | 12.4 | 14.8 | inimigo_y 14.3, inimigo_x 16.2, inimigo_z 25.2 | 96% | 92.2 | teste_a 138 (2), teste_b 50 (4), teste_c 7 (27), teste_d 151 (2) | 216/103 |
| F2-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 19 | 1 | 0 | 198.8 | 199.4 | 23.1 | 5.0 | 0.0 | inimigo_y 38.0, inimigo_x 58.2, inimigo_z 92.6 | 13% | 0.0 | teste_a 236 (1), teste_b 11 (1), teste_c 15 (1), teste_d 85 (1) | 0/0 |
| F2-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 188.7 | 190.7 | 25.2 | 4.7 | 3.6 | inimigo_y 53.8, inimigo_x 68.3, inimigo_z 100.9 | 40% | 125.3 | teste_a 150 (1), teste_b 74 (1), teste_c 42 (1), teste_d 78 (1) | 194/83 |

</details>

## F3 - AP maximo

- A: Aura*5
- B: Aura*a + Nv*b
- C: Aura*a*(1 + Nv*b)

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F3-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F3-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F3-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F3-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F3-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F3-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F3-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F3-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F3-B | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F3-B | smart | 1 | 100% | 0 | 76.7 | 77.0 | 4.6 | 4.4 | 84% | 68 | 1.0 |
| F3-B | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F3-B | smart | 5 | 100% | 0 | 43.4 | 44.1 | 10.1 | 6.9 | 92% | 68 | 2.9 |
| F3-B | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F3-B | smart | 10 | 100% | 0 | 28.2 | 28.4 | 9.6 | 12.8 | 96% | 68 | 7.8 |
| F3-B | basic | 1 difícil | 85% | 0 | 173.6 | 174.4 | 4.9 | 0.0 | 14% | 86 | 1.0 |
| F3-B | smart | 1 difícil | 100% | 0 | 168.1 | 167.7 | 4.4 | 3.7 | 40% | 86 | 1.0 |
| F3-C | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F3-C | smart | 1 | 100% | 0 | 76.7 | 77.0 | 4.6 | 4.4 | 84% | 68 | 1.0 |
| F3-C | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F3-C | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F3-C | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F3-C | smart | 10 | 100% | 0 | 29.1 | 29.1 | 7.6 | 12.7 | 96% | 68 | 7.5 |
| F3-C | basic | 1 difícil | 85% | 0 | 173.6 | 174.4 | 4.9 | 0.0 | 14% | 86 | 1.0 |
| F3-C | smart | 1 difícil | 100% | 0 | 168.1 | 167.7 | 4.4 | 3.7 | 40% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F3-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F3-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F3-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F3-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F3-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F3-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F3-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F3-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F3-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F3-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F3-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F3-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F3-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F3-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F3-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F3-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F3-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F3-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 58.3 | 59.3 | 9.6 | 5.4 | 3.9 | inimigo_y 28.3, inimigo_x 38.2 | 85% | 109.0 | teste_a 69 (1), teste_b 53 (1), teste_c 28 (1), teste_d 46 (1) | 341/115 |
| F3-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F3-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 95.0 | 94.7 | 17.8 | 3.8 | 4.8 | inimigo_y 22.7, inimigo_x 34.3, inimigo_z 71.3 | 83% | 106.5 | teste_a 164 (1), teste_b 71 (1), teste_c 19 (1), teste_d 92 (1) | 241/130 |
| F3-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F3-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 34.5 | 35.6 | 5.4 | 10.8 | 6.9 | inimigo_y 15.9, inimigo_x 21.7 | 93% | 81.6 | teste_a 74 (2), teste_b 44 (3), teste_c 20 (5), teste_d 59 (2) | 246/79 |
| F3-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F3-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 52.3 | 52.7 | 9.5 | 9.3 | 6.9 | inimigo_y 13.3, inimigo_x 19.9, inimigo_z 38.0 | 92% | 105.9 | teste_a 144 (1), teste_b 67 (2), teste_c 14 (7), teste_d 121 (1) | 312/156 |
| F3-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F3-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 23.8 | 24.1 | 3.5 | 6.0 | 11.9 | inimigo_y 12.2, inimigo_x 14.1 | 96% | 71.7 | teste_a 79 (3), teste_b 38 (6), teste_c 11 (17), teste_d 69 (3) | 175/55 |
| F3-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F3-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 32.5 | 32.6 | 5.5 | 13.1 | 13.7 | inimigo_y 11.0, inimigo_x 13.0, inimigo_z 22.0 | 95% | 83.1 | teste_a 158 (2), teste_b 47 (5), teste_c 8 (24), teste_d 135 (2) | 206/94 |
| F3-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 17 | 3 | 0 | 173.6 | 174.4 | 20.3 | 4.9 | 0.0 | inimigo_y 30.5, inimigo_x 48.5, inimigo_z 82.1 | 14% | 0.0 | teste_a 232 (1), teste_b 12 (1), teste_c 16 (1), teste_d 87 (1) | 0/0 |
| F3-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 168.1 | 167.7 | 22.6 | 4.4 | 3.7 | inimigo_y 45.3, inimigo_x 58.4, inimigo_z 90.6 | 40% | 113.3 | teste_a 153 (1), teste_b 76 (1), teste_c 37 (1), teste_d 79 (1) | 154/95 |

**F3-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F3-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F3-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 58.3 | 59.3 | 9.6 | 5.4 | 3.9 | inimigo_y 28.3, inimigo_x 38.2 | 85% | 109.0 | teste_a 69 (1), teste_b 53 (1), teste_c 28 (1), teste_d 46 (1) | 341/115 |
| F3-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F3-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 95.0 | 94.7 | 17.8 | 3.8 | 4.8 | inimigo_y 22.7, inimigo_x 34.3, inimigo_z 71.3 | 83% | 106.5 | teste_a 164 (1), teste_b 71 (1), teste_c 19 (1), teste_d 92 (1) | 241/130 |
| F3-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F3-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F3-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F3-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F3-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F3-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.6 | 24.5 | 3.7 | 3.9 | 11.8 | inimigo_y 12.3, inimigo_x 15.0 | 96% | 72.5 | teste_a 77 (3), teste_b 38 (5), teste_c 12 (17), teste_d 70 (3) | 176/56 |
| F3-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F3-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.6 | 33.7 | 5.8 | 11.3 | 13.5 | inimigo_y 11.0, inimigo_x 13.5, inimigo_z 23.0 | 95% | 83.8 | teste_a 153 (2), teste_b 48 (4), teste_c 8 (24), teste_d 138 (2) | 209/96 |
| F3-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 17 | 3 | 0 | 173.6 | 174.4 | 20.3 | 4.9 | 0.0 | inimigo_y 30.5, inimigo_x 48.5, inimigo_z 82.1 | 14% | 0.0 | teste_a 232 (1), teste_b 12 (1), teste_c 16 (1), teste_d 87 (1) | 0/0 |
| F3-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 168.1 | 167.7 | 22.6 | 4.4 | 3.7 | inimigo_y 45.3, inimigo_x 58.4, inimigo_z 90.6 | 40% | 113.3 | teste_a 153 (1), teste_b 76 (1), teste_c 37 (1), teste_d 79 (1) | 154/95 |

</details>

## F4 - Velocidade para ATB

- A: linear
- B: relativo ao campo (media de Velocidade)
- C: tempo de turno T*r/(r+Vel)

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F4-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F4-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F4-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F4-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F4-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F4-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F4-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F4-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F4-B | basic | 1 | 100% | 0 | 105.8 | 104.5 | 4.5 | 0.0 | 69% | 68 | 1.0 |
| F4-B | smart | 1 | 100% | 0 | 107.2 | 106.9 | 4.3 | 4.3 | 83% | 67 | 1.0 |
| F4-B | basic | 5 | 100% | 0 | 65.8 | 65.2 | 6.3 | 0.0 | 86% | 68 | 2.9 |
| F4-B | smart | 5 | 100% | 0 | 55.8 | 55.7 | 5.0 | 8.8 | 92% | 68 | 2.3 |
| F4-B | basic | 10 | 100% | 0 | 50.7 | 49.2 | 8.0 | 0.0 | 92% | 68 | 7.0 |
| F4-B | smart | 10 | 100% | 0 | 41.0 | 40.9 | 8.1 | 10.8 | 96% | 68 | 4.4 |
| F4-B | basic | 1 difícil | 100% | 0 | 215.1 | 216.8 | 4.8 | 0.0 | 22% | 86 | 1.3 |
| F4-B | smart | 1 difícil | 100% | 0 | 200.9 | 201.2 | 3.8 | 4.0 | 57% | 86 | 1.0 |
| F4-C | basic | 1 | 100% | 0 | 70.6 | 69.8 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F4-C | smart | 1 | 100% | 0 | 73.9 | 73.5 | 4.4 | 5.4 | 84% | 68 | 1.0 |
| F4-C | basic | 5 | 100% | 0 | 42.4 | 41.4 | 7.7 | 0.0 | 91% | 68 | 3.8 |
| F4-C | smart | 5 | 100% | 0 | 41.6 | 42.0 | 5.6 | 9.9 | 92% | 68 | 3.1 |
| F4-C | basic | 10 | 100% | 0 | 36.0 | 35.0 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F4-C | smart | 10 | 100% | 0 | 29.4 | 29.2 | 8.9 | 12.8 | 96% | 68 | 8.1 |
| F4-C | basic | 1 difícil | 5% | 0 | 175.5 | 175.3 | 5.3 | 0.0 | 0% | 87 | 1.0 |
| F4-C | smart | 1 difícil | 100% | 0 | 182.0 | 182.8 | 4.5 | 3.8 | 32% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F4-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F4-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F4-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F4-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F4-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F4-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F4-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F4-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F4-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F4-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F4-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F4-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F4-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F4-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F4-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F4-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F4-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 73.5 | 72.6 | 10.3 | 4.8 | 0.0 | inimigo_y 21.1, inimigo_x 41.1 | 78% | 0.0 | teste_a 88 (1), teste_b 29 (1), teste_c 31 (1), teste_d 50 (1) | 0/0 |
| F4-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 82.6 | 82.8 | 11.3 | 4.9 | 4.0 | inimigo_y 37.4, inimigo_x 44.8 | 85% | 144.2 | teste_a 67 (1), teste_b 49 (1), teste_c 37 (1), teste_d 43 (1) | 536/158 |
| F4-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 138.1 | 136.3 | 18.7 | 4.3 | 0.0 | inimigo_y 20.9, inimigo_x 39.8, inimigo_z 74.6 | 60% | 0.0 | teste_a 183 (1), teste_b 24 (1), teste_c 44 (1), teste_d 94 (1) | 0/0 |
| F4-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 131.7 | 131.0 | 20.0 | 3.6 | 4.7 | inimigo_y 38.0, inimigo_x 47.6, inimigo_z 80.0 | 80% | 143.9 | teste_a 134 (1), teste_b 63 (1), teste_c 67 (1), teste_d 79 (1) | 652/216 |
| F4-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 47.8 | 47.5 | 6.7 | 6.6 | 0.0 | inimigo_y 13.0, inimigo_x 26.9 | 91% | 0.0 | teste_a 88 (2), teste_b 26 (4), teste_c 18 (5), teste_d 63 (2) | 0/0 |
| F4-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 46.1 | 46.6 | 6.3 | 3.7 | 8.1 | inimigo_y 23.2, inimigo_x 25.0 | 96% | 111.9 | teste_a 66 (2), teste_b 44 (3), teste_c 24 (4), teste_d 62 (2) | 362/126 |
| F4-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 83.8 | 83.0 | 12.9 | 5.9 | 0.0 | inimigo_y 13.0, inimigo_x 26.5, inimigo_z 51.5 | 82% | 0.0 | teste_a 166 (1), teste_b 36 (3), teste_c 21 (5), teste_d 122 (1) | 0/0 |
| F4-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 65.4 | 64.7 | 9.6 | 6.2 | 9.4 | inimigo_y 25.3, inimigo_x 25.2, inimigo_z 38.5 | 89% | 134.0 | teste_a 131 (1), teste_b 56 (2), teste_c 43 (3), teste_d 115 (1) | 522/209 |
| F4-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 37.2 | 35.9 | 5.2 | 8.4 | 0.0 | inimigo_y 9.8, inimigo_x 20.6 | 95% | 0.0 | teste_a 86 (3), teste_b 23 (9), teste_c 12 (17), teste_d 76 (3) | 0/0 |
| F4-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 33.8 | 33.7 | 4.7 | 4.7 | 10.5 | inimigo_y 16.1, inimigo_x 18.8 | 98% | 74.8 | teste_a 58 (4), teste_b 45 (5), teste_c 23 (9), teste_d 70 (3) | 255/71 |
| F4-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 64.2 | 62.5 | 9.9 | 7.5 | 0.0 | inimigo_y 9.7, inimigo_x 20.5, inimigo_z 39.5 | 89% | 0.0 | teste_a 155 (2), teste_b 31 (7), teste_c 15 (13), teste_d 142 (2) | 0/0 |
| F4-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 48.3 | 48.1 | 7.1 | 11.6 | 11.1 | inimigo_x 19.4, inimigo_y 19.5, inimigo_z 28.5 | 93% | 116.0 | teste_a 119 (2), teste_b 58 (4), teste_c 38 (6), teste_d 131 (2) | 458/176 |
| F4-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 20 | 0 | 0 | 215.1 | 216.8 | 22.1 | 4.8 | 0.0 | inimigo_y 39.3, inimigo_x 55.2, inimigo_z 88.3 | 22% | 0.0 | teste_a 231 (1), teste_b 10 (2), teste_c 21 (1), teste_d 84 (1) | 0/0 |
| F4-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 200.9 | 201.2 | 26.6 | 3.8 | 4.0 | inimigo_y 55.3, inimigo_x 62.1, inimigo_z 106.6 | 57% | 145.1 | teste_a 149 (1), teste_b 56 (1), teste_c 58 (1), teste_d 82 (1) | 474/142 |

**F4-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F4-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 47.0 | 45.6 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.0 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F4-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 55.0 | 54.2 | 8.7 | 5.1 | 5.0 | inimigo_y 26.7, inimigo_x 34.6 | 84% | 114.6 | teste_a 80 (1), teste_b 48 (1), teste_c 20 (1), teste_d 50 (1) | 248/95 |
| F4-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 94.3 | 94.0 | 18.2 | 3.9 | 0.0 | inimigo_y 12.8, inimigo_x 30.2, inimigo_z 73.0 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F4-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.8 | 92.9 | 17.1 | 3.6 | 5.7 | inimigo_y 24.5, inimigo_x 32.9, inimigo_z 68.3 | 83% | 119.4 | teste_a 167 (1), teste_b 63 (1), teste_c 21 (1), teste_d 95 (1) | 240/116 |
| F4-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 29.8 | 28.7 | 4.7 | 8.5 | 0.0 | inimigo_y 8.4, inimigo_x 18.8 | 91% | 0.0 | teste_a 101 (1), teste_b 19 (5), teste_c 0 (?), teste_d 78 (2) | 0/0 |
| F4-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.7 | 37.2 | 5.6 | 4.5 | 8.7 | inimigo_y 21.0, inimigo_x 21.8 | 93% | 104.7 | teste_a 70 (2), teste_b 45 (2), teste_c 17 (6), teste_d 65 (2) | 279/87 |
| F4-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 54.9 | 54.0 | 10.4 | 6.9 | 0.0 | inimigo_y 8.5, inimigo_x 18.7, inimigo_z 41.6 | 91% | 0.0 | teste_a 179 (1), teste_b 26 (4), teste_c 7 (14), teste_d 135 (1) | 0/0 |
| F4-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.4 | 46.7 | 7.9 | 6.7 | 11.2 | inimigo_y 16.0, inimigo_x 17.1, inimigo_z 31.8 | 91% | 97.1 | teste_a 148 (1), teste_b 54 (2), teste_c 11 (9), teste_d 134 (1) | 211/106 |
| F4-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.1 | 25.1 | 4.2 | 9.5 | 0.0 | inimigo_y 7.4, inimigo_x 16.8 | 94% | 0.0 | teste_a 96 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F4-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 24.6 | 3.8 | 6.6 | 12.1 | inimigo_y 14.2, inimigo_x 15.0 | 97% | 74.4 | teste_a 66 (3), teste_b 41 (5), teste_c 9 (21), teste_d 81 (3) | 167/62 |
| F4-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 46.0 | 44.9 | 8.7 | 8.2 | 0.0 | inimigo_y 7.3, inimigo_x 16.9, inimigo_z 35.0 | 94% | 0.0 | teste_a 169 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F4-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 34.0 | 33.8 | 5.8 | 11.3 | 13.5 | inimigo_y 12.0, inimigo_x 14.0, inimigo_z 23.2 | 95% | 83.0 | teste_a 135 (2), teste_b 53 (4), teste_c 8 (25), teste_d 152 (2) | 203/98 |
| F4-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 1 | 19 | 0 | 175.5 | 175.3 | 17.6 | 5.3 | 0.0 | inimigo_y 34.5, inimigo_x 51.1, inimigo_z 85.0 | 0% | 0.0 | teste_a 235 (1), teste_b 12 (1), teste_c 18 (1), teste_d 81 (1) | 0/0 |
| F4-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 182.0 | 182.8 | 23.5 | 4.5 | 3.8 | inimigo_y 54.5, inimigo_x 63.6, inimigo_z 94.1 | 32% | 134.8 | teste_a 145 (1), teste_b 68 (1), teste_c 56 (1), teste_d 75 (1) | 283/114 |

</details>

## F5 - Dano fisico/habilidade

- A: subtrativo
- B: razao k/(k+defesa)
- C: subtrativo com defesa de equipamento

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F5-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F5-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F5-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F5-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F5-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F5-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F5-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F5-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F5-B | basic | 1 | 100% | 0 | 48.8 | 48.7 | 6.6 | 0.0 | 81% | 68 | 1.0 |
| F5-B | smart | 1 | 100% | 0 | 57.2 | 57.8 | 6.4 | 6.6 | 87% | 68 | 1.0 |
| F5-B | basic | 5 | 100% | 0 | 36.4 | 35.6 | 8.6 | 0.0 | 90% | 68 | 2.1 |
| F5-B | smart | 5 | 100% | 0 | 35.3 | 35.5 | 7.8 | 11.2 | 90% | 68 | 5.0 |
| F5-B | basic | 10 | 100% | 0 | 30.4 | 29.2 | 10.3 | 0.0 | 94% | 68 | 4.4 |
| F5-B | smart | 10 | 100% | 0 | 28.8 | 28.6 | 7.7 | 13.5 | 95% | 68 | 8.0 |
| F5-B | basic | 1 difícil | 100% | 0 | 101.9 | 97.9 | 6.8 | 0.0 | 44% | 87 | 1.0 |
| F5-B | smart | 1 difícil | 100% | 0 | 115.2 | 113.4 | 6.5 | 6.3 | 71% | 86 | 1.0 |
| F5-C | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 84% | 68 | 1.0 |
| F5-C | smart | 1 | 100% | 0 | 76.5 | 76.7 | 4.6 | 4.7 | 87% | 68 | 1.0 |
| F5-C | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 93% | 68 | 3.7 |
| F5-C | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 93% | 68 | 3.0 |
| F5-C | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 95% | 68 | 9.7 |
| F5-C | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 97% | 68 | 8.0 |
| F5-C | basic | 1 difícil | 100% | 0 | 182.1 | 182.5 | 4.8 | 0.0 | 21% | 86 | 1.0 |
| F5-C | smart | 1 difícil | 100% | 0 | 177.9 | 179.1 | 4.5 | 3.6 | 43% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F5-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F5-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F5-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F5-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F5-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F5-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F5-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F5-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F5-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F5-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F5-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F5-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F5-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F5-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F5-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F5-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F5-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 37.7 | 37.7 | 6.0 | 6.7 | 0.0 | inimigo_y 11.3, inimigo_x 23.9 | 81% | 0.0 | teste_a 89 (1), teste_b 49 (1), teste_c 0 (?), teste_d 59 (1) | 0/0 |
| F5-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 54.1 | 54.6 | 8.6 | 6.9 | 5.0 | inimigo_x 28.9, inimigo_y 33.3 | 88% | 120.4 | teste_a 67 (1), teste_b 58 (1), teste_c 25 (1), teste_d 47 (1) | 340/124 |
| F5-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 59.8 | 59.7 | 11.0 | 6.5 | 0.0 | inimigo_y 11.4, inimigo_x 23.9, inimigo_z 44.0 | 81% | 0.0 | teste_a 151 (1), teste_b 72 (1), teste_c 30 (1), teste_d 95 (1) | 0/0 |
| F5-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 60.3 | 60.9 | 10.4 | 6.0 | 8.2 | inimigo_y 22.6, inimigo_x 27.2, inimigo_z 41.5 | 85% | 112.0 | teste_a 146 (1), teste_b 69 (1), teste_c 13 (1), teste_d 117 (1) | 220/110 |
| F5-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 27.4 | 26.2 | 4.5 | 9.0 | 0.0 | inimigo_y 8.5, inimigo_x 17.9 | 91% | 0.0 | teste_a 85 (2), teste_b 46 (2), teste_c 0 (?), teste_d 67 (2) | 0/0 |
| F5-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 31.9 | 32.6 | 4.8 | 5.2 | 9.7 | inimigo_y 17.8, inimigo_x 18.7 | 91% | 92.0 | teste_a 67 (2), teste_b 42 (3), teste_c 14 (7), teste_d 73 (2) | 234/83 |
| F5-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.5 | 44.9 | 8.6 | 8.3 | 0.0 | inimigo_y 8.6, inimigo_x 18.1, inimigo_z 34.3 | 90% | 0.0 | teste_a 141 (1), teste_b 70 (2), teste_c 22 (5), teste_d 113 (1) | 0/0 |
| F5-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 38.7 | 38.3 | 6.4 | 10.5 | 12.8 | inimigo_y 14.0, inimigo_x 16.1, inimigo_z 25.4 | 89% | 91.0 | teste_a 141 (1), teste_b 52 (2), teste_c 4 (22), teste_d 150 (1) | 207/100 |
| F5-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 22.7 | 21.5 | 3.7 | 10.8 | 0.0 | inimigo_y 7.2, inimigo_x 14.9 | 94% | 0.0 | teste_a 86 (3), teste_b 38 (6), teste_c 0 (?), teste_d 74 (3) | 0/0 |
| F5-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 24.2 | 3.8 | 3.8 | 12.5 | inimigo_x 15.0, inimigo_y 14.5 | 95% | 72.4 | teste_a 65 (3), teste_b 42 (5), teste_c 8 (23), teste_d 82 (3) | 164/61 |
| F5-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 38.1 | 36.9 | 7.2 | 9.9 | 0.0 | inimigo_y 7.4, inimigo_x 14.7, inimigo_z 28.8 | 94% | 0.0 | teste_a 140 (2), teste_b 61 (4), teste_c 19 (11), teste_d 128 (2) | 0/0 |
| F5-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 32.7 | 33.0 | 5.6 | 11.5 | 14.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 22.5 | 94% | 83.4 | teste_a 131 (2), teste_b 50 (4), teste_c 9 (22), teste_d 156 (2) | 207/94 |
| F5-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 20 | 0 | 0 | 101.9 | 97.9 | 14.2 | 6.8 | 0.0 | inimigo_y 21.3, inimigo_x 35.5, inimigo_z 56.7 | 44% | 0.0 | teste_a 169 (1), teste_b 26 (1), teste_c 41 (1), teste_d 110 (1) | 0/0 |
| F5-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 115.2 | 113.4 | 16.6 | 6.5 | 6.3 | inimigo_x 44.1, inimigo_y 44.8, inimigo_z 66.5 | 71% | 121.1 | teste_a 121 (1), teste_b 101 (1), teste_c 30 (1), teste_d 93 (1) | 169/75 |

**F5-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F5-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 84% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F5-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.6 | 61.1 | 9.8 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 87% | 124.9 | teste_a 70 (1), teste_b 55 (1), teste_c 27 (1), teste_d 44 (1) | 381/133 |
| F5-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 84% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F5-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.4 | 92.4 | 17.1 | 3.6 | 5.6 | inimigo_y 24.5, inimigo_x 33.2, inimigo_z 68.5 | 86% | 118.1 | teste_a 167 (1), teste_b 64 (1), teste_c 18 (1), teste_d 97 (1) | 230/116 |
| F5-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 93% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F5-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 94% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F5-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 92% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F5-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 92% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F5-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 95% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F5-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F5-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 95% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F5-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 96% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F5-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 20 | 0 | 0 | 182.1 | 182.5 | 22.1 | 4.8 | 0.0 | inimigo_y 36.0, inimigo_x 53.7, inimigo_z 88.5 | 21% | 0.0 | teste_a 228 (1), teste_b 11 (1), teste_c 17 (1), teste_d 90 (1) | 0/0 |
| F5-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.9 | 179.1 | 24.0 | 4.5 | 3.6 | inimigo_y 51.2, inimigo_x 63.7, inimigo_z 96.2 | 43% | 124.8 | teste_a 150 (1), teste_b 77 (1), teste_c 38 (1), teste_d 79 (1) | 188/95 |

</details>

## F6 - Variacao de dano

- A: nenhuma
- B: +-6%
- C: +-12%

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F6-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F6-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F6-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F6-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F6-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F6-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F6-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F6-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F6-B | basic | 1 | 100% | 0 | 78.0 | 77.3 | 4.2 | 0.0 | 81% | 68 | 1.0 |
| F6-B | smart | 1 | 100% | 0 | 82.5 | 82.6 | 4.1 | 4.4 | 83% | 68 | 1.0 |
| F6-B | basic | 5 | 100% | 0 | 46.8 | 46.0 | 6.7 | 0.0 | 92% | 68 | 3.7 |
| F6-B | smart | 5 | 100% | 0 | 43.5 | 42.9 | 5.6 | 9.5 | 92% | 68 | 3.1 |
| F6-B | basic | 10 | 100% | 0 | 35.6 | 34.7 | 8.9 | 0.0 | 95% | 68 | 10.5 |
| F6-B | smart | 10 | 100% | 0 | 29.9 | 29.7 | 10.1 | 12.4 | 96% | 68 | 8.9 |
| F6-B | basic | 1 difícil | 35% | 0 | 196.4 | 198.7 | 4.9 | 0.0 | 2% | 87 | 1.5 |
| F6-B | smart | 1 difícil | 100% | 0 | 198.8 | 198.5 | 4.4 | 3.2 | 27% | 86 | 1.0 |
| F6-C | basic | 1 | 100% | 0 | 78.0 | 77.3 | 4.1 | 0.0 | 81% | 68 | 1.0 |
| F6-C | smart | 1 | 100% | 0 | 82.5 | 82.6 | 4.1 | 4.4 | 84% | 68 | 1.0 |
| F6-C | basic | 5 | 100% | 0 | 46.9 | 46.0 | 6.7 | 0.0 | 92% | 68 | 3.7 |
| F6-C | smart | 5 | 100% | 0 | 43.5 | 43.1 | 5.7 | 9.5 | 92% | 68 | 3.1 |
| F6-C | basic | 10 | 100% | 0 | 35.6 | 34.7 | 8.9 | 0.0 | 95% | 68 | 10.5 |
| F6-C | smart | 10 | 100% | 0 | 30.0 | 29.7 | 10.0 | 12.3 | 96% | 68 | 8.6 |
| F6-C | basic | 1 difícil | 30% | 0 | 198.2 | 200.1 | 4.9 | 0.0 | 2% | 87 | 1.5 |
| F6-C | smart | 1 difícil | 100% | 0 | 198.7 | 198.6 | 4.4 | 3.2 | 28% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F6-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F6-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F6-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F6-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F6-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F6-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F6-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F6-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F6-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F6-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F6-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F6-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F6-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F6-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F6-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F6-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F6-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 51.9 | 50.9 | 8.4 | 4.8 | 0.0 | inimigo_y 14.3, inimigo_x 33.6 | 82% | 0.0 | teste_a 110 (1), teste_b 26 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F6-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 63.6 | 63.7 | 10.3 | 5.0 | 3.5 | inimigo_y 30.2, inimigo_x 41.0 | 84% | 122.5 | teste_a 74 (1), teste_b 53 (1), teste_c 25 (1), teste_d 45 (1) | 327/149 |
| F6-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 104.0 | 103.7 | 20.1 | 3.5 | 0.0 | inimigo_y 14.4, inimigo_x 33.6, inimigo_z 80.6 | 81% | 0.0 | teste_a 197 (1), teste_b 39 (1), teste_c 14 (1), teste_d 96 (1) | 0/0 |
| F6-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 101.4 | 101.5 | 18.9 | 3.3 | 5.2 | inimigo_y 26.4, inimigo_x 36.3, inimigo_z 75.6 | 83% | 118.5 | teste_a 172 (1), teste_b 64 (1), teste_c 19 (1), teste_d 91 (1) | 227/111 |
| F6-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 32.7 | 31.7 | 5.4 | 7.4 | 0.0 | inimigo_y 9.7, inimigo_x 21.7 | 92% | 0.0 | teste_a 102 (1), teste_b 21 (5), teste_c 0 (?), teste_d 75 (2) | 0/0 |
| F6-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.9 | 35.7 | 5.7 | 5.4 | 8.3 | inimigo_x 22.5, inimigo_y 19.9 | 93% | 103.7 | teste_a 72 (2), teste_b 40 (3), teste_c 17 (6), teste_d 67 (2) | 250/108 |
| F6-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 60.9 | 60.3 | 11.8 | 6.0 | 0.0 | inimigo_y 9.7, inimigo_x 21.8, inimigo_z 47.1 | 92% | 0.0 | teste_a 178 (1), teste_b 31 (3), teste_c 7 (14), teste_d 130 (1) | 0/0 |
| F6-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 50.1 | 50.1 | 8.9 | 5.7 | 10.7 | inimigo_y 16.0, inimigo_x 19.8, inimigo_z 35.5 | 92% | 97.6 | teste_a 153 (1), teste_b 48 (2), teste_c 11 (8), teste_d 134 (1) | 204/119 |
| F6-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 25.6 | 24.8 | 4.2 | 9.6 | 0.0 | inimigo_y 7.5, inimigo_x 16.6 | 95% | 0.0 | teste_a 96 (2), teste_b 17 (12), teste_c 0 (?), teste_d 85 (3) | 0/0 |
| F6-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.4 | 23.6 | 3.8 | 7.2 | 12.2 | inimigo_y 14.0, inimigo_x 15.0 | 97% | 71.8 | teste_a 69 (3), teste_b 39 (5), teste_c 6 (34), teste_d 83 (3) | 140/73 |
| F6-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.3, inimigo_x 16.7, inimigo_z 34.9 | 95% | 0.0 | teste_a 170 (2), teste_b 23 (9), teste_c 4 (48), teste_d 148 (2) | 0/0 |
| F6-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 35.4 | 35.8 | 6.1 | 13.1 | 12.6 | inimigo_y 13.5, inimigo_x 14.5, inimigo_z 24.6 | 96% | 88.9 | teste_a 133 (2), teste_b 53 (4), teste_c 11 (18), teste_d 149 (2) | 219/119 |
| F6-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 7 | 13 | 0 | 196.4 | 198.7 | 20.6 | 4.9 | 0.0 | inimigo_y 38.0, inimigo_x 55.8, inimigo_z 87.0 | 2% | 0.0 | teste_a 254 (1), teste_b 8 (2), teste_c 10 (2), teste_d 74 (1) | 0/0 |
| F6-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 198.8 | 198.5 | 24.9 | 4.4 | 3.2 | inimigo_y 53.6, inimigo_x 67.3, inimigo_z 99.7 | 27% | 121.7 | teste_a 159 (1), teste_b 78 (1), teste_c 34 (1), teste_d 74 (1) | 183/83 |

**F6-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F6-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 51.9 | 50.9 | 8.4 | 4.8 | 0.0 | inimigo_y 14.3, inimigo_x 33.6 | 82% | 0.0 | teste_a 110 (1), teste_b 26 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F6-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 63.5 | 63.8 | 10.2 | 5.0 | 3.5 | inimigo_y 30.2, inimigo_x 41.0 | 84% | 122.5 | teste_a 74 (1), teste_b 52 (1), teste_c 26 (1), teste_d 45 (1) | 327/149 |
| F6-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 104.2 | 103.7 | 20.2 | 3.5 | 0.0 | inimigo_y 14.5, inimigo_x 33.7, inimigo_z 80.7 | 81% | 0.0 | teste_a 196 (1), teste_b 39 (1), teste_c 14 (1), teste_d 97 (1) | 0/0 |
| F6-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 101.5 | 101.4 | 18.9 | 3.3 | 5.2 | inimigo_y 26.4, inimigo_x 36.3, inimigo_z 75.6 | 83% | 118.7 | teste_a 172 (1), teste_b 64 (1), teste_c 19 (1), teste_d 91 (1) | 227/113 |
| F6-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 32.9 | 31.7 | 5.5 | 7.3 | 0.0 | inimigo_y 9.8, inimigo_x 21.8 | 92% | 0.0 | teste_a 102 (1), teste_b 21 (5), teste_c 0 (?), teste_d 75 (2) | 0/0 |
| F6-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 37.0 | 35.7 | 5.7 | 5.7 | 8.3 | inimigo_x 22.5, inimigo_y 19.9 | 92% | 103.6 | teste_a 72 (2), teste_b 40 (3), teste_c 17 (6), teste_d 68 (2) | 249/107 |
| F6-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 60.9 | 60.3 | 11.8 | 6.0 | 0.0 | inimigo_y 9.8, inimigo_x 21.9, inimigo_z 47.2 | 92% | 0.0 | teste_a 178 (1), teste_b 31 (3), teste_c 7 (14), teste_d 130 (1) | 0/0 |
| F6-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 50.0 | 50.5 | 8.8 | 5.7 | 10.8 | inimigo_y 16.1, inimigo_x 19.7, inimigo_z 35.4 | 92% | 98.2 | teste_a 152 (1), teste_b 48 (2), teste_c 13 (8), teste_d 133 (1) | 209/112 |
| F6-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 25.6 | 24.8 | 4.2 | 9.6 | 0.0 | inimigo_y 7.5, inimigo_x 16.6 | 95% | 0.0 | teste_a 96 (2), teste_b 17 (12), teste_c 0 (?), teste_d 85 (3) | 0/0 |
| F6-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.7 | 3.8 | 6.7 | 11.9 | inimigo_y 14.0, inimigo_x 15.4 | 96% | 72.8 | teste_a 69 (3), teste_b 40 (5), teste_c 6 (32), teste_d 83 (3) | 145/75 |
| F6-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.3, inimigo_x 16.7, inimigo_z 34.9 | 95% | 0.0 | teste_a 171 (2), teste_b 23 (9), teste_c 4 (48), teste_d 147 (2) | 0/0 |
| F6-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 35.1 | 35.7 | 6.1 | 13.4 | 12.7 | inimigo_y 13.5, inimigo_x 14.5, inimigo_z 24.4 | 96% | 88.1 | teste_a 132 (2), teste_b 53 (4), teste_c 11 (18), teste_d 150 (2) | 218/116 |
| F6-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 6 | 14 | 0 | 198.2 | 200.1 | 20.6 | 4.9 | 0.0 | inimigo_y 38.0, inimigo_x 55.9, inimigo_z 87.8 | 2% | 0.0 | teste_a 255 (1), teste_b 8 (2), teste_c 9 (2), teste_d 75 (1) | 0/0 |
| F6-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 198.7 | 198.6 | 25.0 | 4.4 | 3.2 | inimigo_y 53.7, inimigo_x 67.3, inimigo_z 99.9 | 28% | 122.0 | teste_a 158 (1), teste_b 78 (1), teste_c 34 (1), teste_d 74 (1) | 183/84 |

</details>

## F7 - Esquiva

- A: Vel*k com teto
- B: relativa (Vel alvo - Vel atacante)
- C: so equipamento/estado

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F7-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F7-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F7-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F7-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F7-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F7-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F7-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F7-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F7-B | basic | 1 | 100% | 0 | 68.5 | 67.9 | 4.8 | 0.0 | 81% | 68 | 1.0 |
| F7-B | smart | 1 | 100% | 0 | 76.1 | 77.2 | 4.8 | 4.6 | 85% | 68 | 1.0 |
| F7-B | basic | 5 | 100% | 0 | 43.9 | 43.8 | 7.2 | 0.0 | 91% | 68 | 3.7 |
| F7-B | smart | 5 | 100% | 0 | 41.2 | 41.1 | 5.3 | 9.9 | 91% | 68 | 3.0 |
| F7-B | basic | 10 | 100% | 0 | 34.8 | 34.7 | 9.1 | 0.0 | 94% | 68 | 9.9 |
| F7-B | smart | 10 | 100% | 0 | 29.0 | 28.5 | 9.7 | 12.9 | 96% | 68 | 8.0 |
| F7-B | basic | 1 difícil | 70% | 0 | 182.6 | 181.9 | 5.4 | 0.0 | 4% | 86 | 1.3 |
| F7-B | smart | 1 difícil | 100% | 0 | 175.6 | 174.9 | 4.9 | 3.7 | 35% | 86 | 1.0 |
| F7-C | basic | 1 | 100% | 0 | 68.5 | 67.9 | 4.8 | 0.0 | 81% | 68 | 1.0 |
| F7-C | smart | 1 | 100% | 0 | 76.0 | 77.2 | 4.8 | 4.6 | 85% | 68 | 1.0 |
| F7-C | basic | 5 | 100% | 0 | 43.8 | 43.8 | 7.2 | 0.0 | 91% | 68 | 3.7 |
| F7-C | smart | 5 | 100% | 0 | 41.2 | 41.1 | 5.3 | 9.9 | 91% | 68 | 3.0 |
| F7-C | basic | 10 | 100% | 0 | 34.7 | 34.7 | 9.2 | 0.0 | 94% | 68 | 10.0 |
| F7-C | smart | 10 | 100% | 0 | 29.0 | 28.5 | 9.7 | 12.9 | 95% | 68 | 8.0 |
| F7-C | basic | 1 difícil | 80% | 0 | 181.9 | 181.9 | 5.4 | 0.0 | 4% | 86 | 1.3 |
| F7-C | smart | 1 difícil | 100% | 0 | 175.7 | 174.9 | 4.9 | 3.7 | 35% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F7-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F7-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F7-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F7-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F7-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F7-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F7-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F7-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F7-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F7-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F7-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F7-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F7-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F7-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F7-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F7-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F7-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 45.4 | 45.4 | 7.3 | 5.5 | 0.0 | inimigo_y 12.0, inimigo_x 29.0 | 81% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F7-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.1 | 61.0 | 9.7 | 5.8 | 3.7 | inimigo_y 29.3, inimigo_x 38.9 | 85% | 124.4 | teste_a 70 (1), teste_b 56 (1), teste_c 26 (1), teste_d 45 (1) | 371/135 |
| F7-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 91.5 | 90.5 | 17.7 | 4.0 | 0.0 | inimigo_y 12.0, inimigo_x 29.0, inimigo_z 70.9 | 81% | 0.0 | teste_a 194 (1), teste_b 42 (1), teste_c 12 (1), teste_d 99 (1) | 0/0 |
| F7-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.1 | 93.5 | 17.0 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.1, inimigo_z 68.0 | 85% | 121.2 | teste_a 164 (1), teste_b 64 (1), teste_c 18 (1), teste_d 100 (1) | 230/125 |
| F7-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 30.7 | 30.6 | 5.0 | 8.0 | 0.0 | inimigo_y 9.0, inimigo_x 20.1 | 91% | 0.0 | teste_a 97 (1), teste_b 27 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F7-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 92% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F7-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 57.1 | 57.0 | 11.0 | 6.5 | 0.0 | inimigo_y 9.0, inimigo_x 20.0, inimigo_z 44.1 | 91% | 0.0 | teste_a 177 (1), teste_b 36 (3), teste_c 6 (15), teste_d 128 (1) | 0/0 |
| F7-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.4 | 46.4 | 8.0 | 6.4 | 11.2 | inimigo_y 16.0, inimigo_x 17.1, inimigo_z 32.1 | 91% | 97.4 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 214/105 |
| F7-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 24.9 | 24.8 | 4.0 | 9.9 | 0.0 | inimigo_y 7.0, inimigo_x 16.1 | 94% | 0.0 | teste_a 94 (3), teste_b 21 (9), teste_c 0 (?), teste_d 83 (3) | 0/0 |
| F7-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 96% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F7-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 44.6 | 44.6 | 8.5 | 8.4 | 0.0 | inimigo_y 7.0, inimigo_x 16.0, inimigo_z 34.0 | 94% | 0.0 | teste_a 167 (2), teste_b 28 (7), teste_c 4 (48), teste_d 147 (2) | 0/0 |
| F7-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.2 | 33.2 | 5.7 | 13.7 | 13.6 | inimigo_y 13.2, inimigo_x 14.1, inimigo_z 23.0 | 95% | 83.6 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F7-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 14 | 6 | 0 | 182.6 | 181.9 | 19.5 | 5.4 | 0.0 | inimigo_y 32.8, inimigo_x 49.4, inimigo_z 79.4 | 4% | 0.0 | teste_a 245 (1), teste_b 9 (2), teste_c 12 (1), teste_d 80 (1) | 0/0 |
| F7-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 175.6 | 174.9 | 22.8 | 4.9 | 3.7 | inimigo_y 49.4, inimigo_x 61.6, inimigo_z 91.3 | 35% | 121.3 | teste_a 153 (1), teste_b 83 (1), teste_c 29 (1), teste_d 79 (1) | 154/99 |

**F7-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F7-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 45.4 | 45.4 | 7.3 | 5.5 | 0.0 | inimigo_y 12.0, inimigo_x 29.0 | 81% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F7-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.0 | 60.9 | 9.7 | 5.8 | 3.7 | inimigo_y 29.3, inimigo_x 38.8 | 85% | 124.4 | teste_a 71 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 372/134 |
| F7-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 91.5 | 90.5 | 17.7 | 4.0 | 0.0 | inimigo_y 12.0, inimigo_x 29.0, inimigo_z 70.9 | 81% | 0.0 | teste_a 194 (1), teste_b 42 (1), teste_c 12 (1), teste_d 99 (1) | 0/0 |
| F7-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.0 | 93.5 | 17.0 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.1, inimigo_z 67.9 | 85% | 120.9 | teste_a 164 (1), teste_b 64 (1), teste_c 18 (1), teste_d 100 (1) | 230/122 |
| F7-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 30.6 | 30.6 | 5.0 | 8.0 | 0.0 | inimigo_y 9.0, inimigo_x 20.0 | 91% | 0.0 | teste_a 98 (1), teste_b 27 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F7-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 92% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F7-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 57.0 | 57.0 | 11.0 | 6.5 | 0.0 | inimigo_y 9.0, inimigo_x 20.0, inimigo_z 44.0 | 91% | 0.0 | teste_a 177 (1), teste_b 36 (3), teste_c 6 (15), teste_d 128 (1) | 0/0 |
| F7-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.4 | 46.4 | 8.0 | 6.4 | 11.2 | inimigo_y 16.0, inimigo_x 17.0, inimigo_z 32.0 | 90% | 97.3 | teste_a 150 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F7-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 24.8 | 24.8 | 4.0 | 10.0 | 0.0 | inimigo_y 7.0, inimigo_x 16.0 | 94% | 0.0 | teste_a 94 (3), teste_b 21 (10), teste_c 0 (?), teste_d 83 (3) | 0/0 |
| F7-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 96% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F7-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 44.6 | 44.6 | 8.5 | 8.4 | 0.0 | inimigo_y 7.0, inimigo_x 16.0, inimigo_z 34.0 | 94% | 0.0 | teste_a 167 (2), teste_b 28 (7), teste_c 4 (48), teste_d 147 (2) | 0/0 |
| F7-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.2 | 33.2 | 5.7 | 13.7 | 13.6 | inimigo_y 13.2, inimigo_x 14.1, inimigo_z 23.0 | 95% | 83.6 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F7-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 16 | 4 | 0 | 181.9 | 181.9 | 19.5 | 5.4 | 0.0 | inimigo_y 32.8, inimigo_x 49.1, inimigo_z 78.9 | 4% | 0.0 | teste_a 246 (1), teste_b 9 (2), teste_c 12 (1), teste_d 78 (1) | 0/0 |
| F7-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 175.7 | 174.9 | 22.8 | 4.9 | 3.7 | inimigo_y 49.4, inimigo_x 61.5, inimigo_z 91.2 | 35% | 121.3 | teste_a 153 (1), teste_b 83 (1), teste_c 29 (1), teste_d 79 (1) | 154/99 |

</details>

## F8 - Curva de XP

- A: coef 10 quadratico
- B: coef calibrado
- C: coef + termo linear

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F8-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F8-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F8-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F8-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F8-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F8-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F8-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F8-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F8-B | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.1 |
| F8-B | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.1 |
| F8-B | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 8.5 |
| F8-B | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 6.9 |
| F8-B | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 23.4 |
| F8-B | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 19.4 |
| F8-B | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 2.0 |
| F8-B | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F8-C | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.7 |
| F8-C | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.5 |
| F8-C | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 6.4 |
| F8-C | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 5.1 |
| F8-C | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 15.8 |
| F8-C | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 13.0 |
| F8-C | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 2.8 |
| F8-C | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.3 |

<details><summary>Detalhe por cenario</summary>

**F8-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F8-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F8-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F8-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F8-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F8-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F8-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F8-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F8-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F8-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F8-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F8-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F8-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F8-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F8-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F8-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F8-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F8-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F8-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (2), teste_d 100 (1) | 0/0 |
| F8-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (2), teste_d 99 (1) | 230/125 |
| F8-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (3), teste_b 26 (9), teste_c 0 (?), teste_d 73 (4) | 0/0 |
| F8-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (4), teste_b 44 (6), teste_c 17 (14), teste_d 65 (4) | 270/90 |
| F8-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (2), teste_b 36 (7), teste_c 6 (36), teste_d 129 (2) | 0/0 |
| F8-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (2), teste_b 49 (5), teste_c 13 (18), teste_d 135 (2) | 215/103 |
| F8-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (5), teste_b 21 (23), teste_c 0 (?), teste_d 81 (6) | 0/0 |
| F8-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (8), teste_b 42 (12), teste_c 8 (57), teste_d 81 (6) | 164/61 |
| F8-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (3), teste_b 28 (17), teste_c 4 (118), teste_d 146 (4) | 0/0 |
| F8-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (4), teste_b 50 (10), teste_c 9 (54), teste_d 152 (4) | 207/96 |
| F8-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (3), teste_c 12 (3), teste_d 81 (1) | 0/0 |
| F8-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F8-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F8-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (2), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F8-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (2), teste_d 44 (2) | 378/133 |
| F8-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (2), teste_c 13 (4), teste_d 100 (1) | 0/0 |
| F8-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (3), teste_d 99 (1) | 230/125 |
| F8-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (2), teste_b 26 (7), teste_c 0 (?), teste_d 73 (3) | 0/0 |
| F8-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (3), teste_b 44 (4), teste_c 17 (10), teste_d 65 (3) | 270/90 |
| F8-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (5), teste_c 6 (27), teste_d 129 (2) | 0/0 |
| F8-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (2), teste_b 49 (4), teste_c 13 (13), teste_d 135 (2) | 215/103 |
| F8-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (4), teste_b 21 (15), teste_c 0 (?), teste_d 81 (4) | 0/0 |
| F8-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (5), teste_b 42 (8), teste_c 8 (38), teste_d 81 (4) | 164/61 |
| F8-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (12), teste_c 4 (79), teste_d 146 (3) | 0/0 |
| F8-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (3), teste_b 50 (7), teste_c 9 (36), teste_d 152 (3) | 207/96 |
| F8-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (5), teste_c 12 (4), teste_d 81 (1) | 0/0 |
| F8-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (2), teste_d 78 (1) | 170/85 |

</details>

## F9 - Nivel maximo (so afeta XP)

- A: sem limite
- B: 50
- C: 99

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F9-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F9-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F9-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F9-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F9-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F9-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F9-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F9-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F9-B | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F9-B | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F9-B | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F9-B | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F9-B | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F9-B | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F9-B | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F9-B | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F9-C | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F9-C | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F9-C | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F9-C | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F9-C | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F9-C | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F9-C | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F9-C | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F9-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F9-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F9-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F9-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F9-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F9-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F9-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F9-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F9-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F9-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F9-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F9-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F9-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F9-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F9-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F9-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F9-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F9-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F9-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F9-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F9-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F9-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F9-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F9-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F9-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F9-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F9-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F9-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F9-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F9-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F9-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F9-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F9-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F9-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F9-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F9-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F9-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F9-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F9-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F9-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F9-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F9-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F9-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F9-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F9-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

</details>

## F10 - Reviver

- A: 25% do HP max
- B: 50%
- C: fixo + 10%

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F10-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F10-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F10-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F10-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F10-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F10-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F10-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F10-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F10-B | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F10-B | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F10-B | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F10-B | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F10-B | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F10-B | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F10-B | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F10-B | smart | 1 difícil | 100% | 0 | 178.7 | 178.7 | 4.5 | 3.6 | 42% | 86 | 1.0 |
| F10-C | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F10-C | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F10-C | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F10-C | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F10-C | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F10-C | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F10-C | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F10-C | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F10-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F10-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F10-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F10-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F10-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F10-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F10-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F10-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F10-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F10-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F10-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F10-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F10-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F10-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F10-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F10-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F10-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F10-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F10-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F10-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F10-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F10-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F10-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F10-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F10-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F10-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F10-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F10-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F10-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F10-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 178.7 | 178.7 | 24.2 | 4.5 | 3.6 | inimigo_y 52.1, inimigo_x 64.5, inimigo_z 96.8 | 42% | 124.8 | teste_a 148 (1), teste_b 79 (1), teste_c 39 (1), teste_d 79 (1) | 176/93 |

**F10-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F10-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F10-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F10-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F10-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F10-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F10-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F10-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F10-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F10-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F10-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F10-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F10-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F10-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F10-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 151 (1), teste_b 81 (1), teste_c 35 (1), teste_d 77 (1) | 170/85 |

</details>

## F11 - Veneno

- A: dano fixo por turno
- B: % do HP max
- C: fixo + %

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F11-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F11-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F11-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F11-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F11-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F11-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F11-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F11-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F11-B | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F11-B | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F11-B | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F11-B | smart | 5 | 100% | 0 | 40.9 | 41.0 | 5.3 | 10.0 | 92% | 68 | 3.1 |
| F11-B | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F11-B | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F11-B | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F11-B | smart | 1 difícil | 100% | 0 | 171.8 | 170.4 | 4.8 | 3.7 | 38% | 86 | 1.0 |
| F11-C | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F11-C | smart | 1 | 100% | 0 | 75.9 | 75.6 | 4.7 | 4.6 | 86% | 68 | 1.0 |
| F11-C | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F11-C | smart | 5 | 100% | 0 | 40.4 | 39.4 | 5.4 | 10.0 | 92% | 68 | 3.0 |
| F11-C | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F11-C | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F11-C | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F11-C | smart | 1 difícil | 100% | 0 | 160.1 | 158.5 | 4.8 | 3.8 | 43% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F11-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F11-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F11-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F11-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F11-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F11-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F11-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F11-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F11-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F11-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F11-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F11-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F11-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F11-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F11-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F11-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F11-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F11-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F11-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F11-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F11-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F11-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F11-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F11-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 45.9 | 46.2 | 7.9 | 6.6 | 11.3 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 31.6 | 91% | 96.7 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (8), teste_d 135 (1) | 212/103 |
| F11-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F11-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F11-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F11-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F11-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F11-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 171.8 | 170.4 | 22.3 | 4.8 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 89.3 | 38% | 121.6 | teste_a 146 (1), teste_b 80 (1), teste_c 43 (1), teste_d 76 (1) | 170/85 |

**F11-C**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F11-C - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F11-C - N1 X+Y smart | 30 | 30 | 0 | 0 | 59.2 | 58.8 | 9.6 | 5.7 | 3.7 | inimigo_y 29.4, inimigo_x 38.3 | 86% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 28 (1), teste_d 43 (1) | 378/133 |
| F11-C - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F11-C - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F11-C - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F11-C - N5 X+Y smart | 30 | 30 | 0 | 0 | 35.9 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F11-C - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F11-C - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 44.9 | 43.1 | 7.7 | 6.8 | 11.3 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 30.8 | 91% | 96.4 | teste_a 150 (1), teste_b 49 (2), teste_c 14 (7), teste_d 134 (1) | 210/103 |
| F11-C - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F11-C - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F11-C - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F11-C - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F11-C - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F11-C - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 160.1 | 158.5 | 21.0 | 4.8 | 3.8 | inimigo_y 50.6, inimigo_x 61.9, inimigo_z 84.0 | 43% | 120.7 | teste_a 135 (1), teste_b 81 (1), teste_c 58 (1), teste_d 72 (1) | 167/85 |

</details>

## F12 - Duracoes de estado

- A: valores de teste por estado
- B: tabela unica por forca

| Opcao | Politica | Nivel | Vitorias | Tempos esg. | Dur media (s) | Dur mediana (s) | Dano basico | Dano habil. | HP final | XP/vit/heroi | Batalhas p/ nivel |
|---|---|---|---|---|---|---|---|---|---|---|---|
| F12-A | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F12-A | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F12-A | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F12-A | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F12-A | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F12-A | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F12-A | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F12-A | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |
| F12-B | basic | 1 | 100% | 0 | 70.4 | 70.1 | 4.6 | 0.0 | 82% | 68 | 1.0 |
| F12-B | smart | 1 | 100% | 0 | 76.8 | 76.8 | 4.6 | 4.6 | 85% | 68 | 1.0 |
| F12-B | basic | 5 | 100% | 0 | 44.9 | 43.8 | 7.0 | 0.0 | 91% | 68 | 3.7 |
| F12-B | smart | 5 | 100% | 0 | 41.4 | 41.1 | 5.2 | 9.9 | 92% | 68 | 3.0 |
| F12-B | basic | 10 | 100% | 0 | 35.8 | 34.7 | 8.8 | 0.0 | 94% | 68 | 9.7 |
| F12-B | smart | 10 | 100% | 0 | 29.1 | 28.5 | 9.6 | 12.9 | 96% | 68 | 8.0 |
| F12-B | basic | 1 difícil | 55% | 0 | 185.8 | 187.2 | 5.2 | 0.0 | 5% | 86 | 1.3 |
| F12-B | smart | 1 difícil | 100% | 0 | 177.8 | 177.1 | 4.7 | 3.7 | 35% | 86 | 1.0 |

<details><summary>Detalhe por cenario</summary>

**F12-A**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F12-A - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F12-A - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F12-A - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F12-A - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F12-A - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F12-A - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F12-A - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F12-A - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F12-A - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F12-A - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F12-A - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F12-A - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F12-A - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F12-A - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

**F12-B**

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| F12-B - N1 X+Y basic | 30 | 30 | 0 | 0 | 46.9 | 46.5 | 7.5 | 5.3 | 0.0 | inimigo_y 12.7, inimigo_x 30.1 | 82% | 0.0 | teste_a 106 (1), teste_b 30 (1), teste_c 0 (?), teste_d 62 (1) | 0/0 |
| F12-B - N1 X+Y smart | 30 | 30 | 0 | 0 | 60.8 | 61.1 | 9.9 | 5.6 | 3.7 | inimigo_y 29.4, inimigo_x 39.4 | 85% | 124.8 | teste_a 70 (1), teste_b 55 (1), teste_c 26 (1), teste_d 44 (1) | 378/133 |
| F12-B - N1 X+Y+Z basic | 30 | 30 | 0 | 0 | 93.9 | 93.8 | 18.2 | 3.9 | 0.0 | inimigo_y 12.9, inimigo_x 30.2, inimigo_z 72.9 | 82% | 0.0 | teste_a 192 (1), teste_b 42 (1), teste_c 13 (1), teste_d 100 (1) | 0/0 |
| F12-B - N1 X+Y+Z smart | 30 | 30 | 0 | 0 | 92.7 | 92.5 | 17.2 | 3.7 | 5.4 | inimigo_y 24.5, inimigo_x 33.5, inimigo_z 68.7 | 85% | 120.7 | teste_a 165 (1), teste_b 64 (1), teste_c 18 (1), teste_d 99 (1) | 230/125 |
| F12-B - N5 X+Y basic | 30 | 30 | 0 | 0 | 31.4 | 30.6 | 5.2 | 7.8 | 0.0 | inimigo_y 9.4, inimigo_x 20.6 | 91% | 0.0 | teste_a 98 (1), teste_b 26 (4), teste_c 0 (?), teste_d 73 (2) | 0/0 |
| F12-B - N5 X+Y smart | 30 | 30 | 0 | 0 | 36.0 | 35.7 | 5.5 | 4.1 | 8.7 | inimigo_y 20.6, inimigo_x 21.6 | 93% | 103.5 | teste_a 71 (2), teste_b 44 (3), teste_c 17 (6), teste_d 65 (2) | 270/90 |
| F12-B - N5 X+Y+Z basic | 30 | 30 | 0 | 0 | 58.5 | 57.0 | 11.3 | 6.3 | 0.0 | inimigo_y 9.5, inimigo_x 20.8, inimigo_z 45.3 | 91% | 0.0 | teste_a 176 (1), teste_b 36 (3), teste_c 6 (15), teste_d 129 (1) | 0/0 |
| F12-B - N5 X+Y+Z smart | 30 | 30 | 0 | 0 | 46.8 | 46.4 | 8.1 | 6.3 | 11.2 | inimigo_y 16.0, inimigo_x 17.4, inimigo_z 32.4 | 91% | 97.2 | teste_a 151 (1), teste_b 49 (2), teste_c 13 (7), teste_d 135 (1) | 215/103 |
| F12-B - N10 X+Y basic | 30 | 30 | 0 | 0 | 26.0 | 24.8 | 4.3 | 9.4 | 0.0 | inimigo_y 7.3, inimigo_x 17.0 | 94% | 0.0 | teste_a 95 (2), teste_b 21 (9), teste_c 0 (?), teste_d 81 (3) | 0/0 |
| F12-B - N10 X+Y smart | 30 | 30 | 0 | 0 | 24.9 | 23.8 | 3.8 | 5.8 | 12.2 | inimigo_x 15.2, inimigo_y 14.5 | 97% | 73.6 | teste_a 67 (3), teste_b 42 (5), teste_c 8 (23), teste_d 81 (3) | 164/61 |
| F12-B - N10 X+Y+Z basic | 30 | 30 | 0 | 0 | 45.6 | 44.6 | 8.7 | 8.2 | 0.0 | inimigo_y 7.5, inimigo_x 16.8, inimigo_z 34.9 | 94% | 0.0 | teste_a 168 (2), teste_b 28 (7), teste_c 4 (48), teste_d 146 (2) | 0/0 |
| F12-B - N10 X+Y+Z smart | 30 | 30 | 0 | 0 | 33.3 | 33.2 | 5.8 | 13.5 | 13.6 | inimigo_y 13.2, inimigo_x 14.2, inimigo_z 23.0 | 95% | 83.7 | teste_a 136 (2), teste_b 50 (4), teste_c 9 (22), teste_d 152 (2) | 207/96 |
| F12-B - N1 X+Y+Z difícil ×1.125 basic | 20 | 11 | 9 | 0 | 185.8 | 187.2 | 20.0 | 5.2 | 0.0 | inimigo_y 34.8, inimigo_x 51.3, inimigo_z 82.8 | 5% | 0.0 | teste_a 243 (1), teste_b 10 (2), teste_c 12 (1), teste_d 81 (1) | 0/0 |
| F12-B - N1 X+Y+Z difícil ×1.125 smart | 20 | 20 | 0 | 0 | 177.8 | 177.1 | 23.1 | 4.7 | 3.7 | inimigo_y 50.6, inimigo_x 62.6, inimigo_z 92.2 | 35% | 121.6 | teste_a 152 (1), teste_b 80 (1), teste_c 35 (1), teste_d 78 (1) | 170/85 |

</details>

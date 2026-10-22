# Relatório de balanceamento da fatia vertical (M12)

Baseline: **padrao escolhido (balance.tres)**. Gerado por `run_sim.ps1 -Fatia` (60 execuções por cenário de luta e 30 execuções de rota por perfil; grupo = heróis de teste A-D com equipamento inicial, alocação `main`; itens: Poção 3, Éter 2, Reviver 1 e, no chefe, Remédio 2; sementes 1..N). Valores de teste, não canônicos.

## Metas

- Lutas comuns: `smart` com vitória >= 95% e duração média de 10-60 s (as lutas da fatia têm 1-2 inimigos, por isso o piso é 10 s; a meta clássica de 20 s vale para 3 inimigos); `basic` com vitória >= 75%.
- Chefe (decisão do usuário, plano M12): `smart` com duração média de **15-20 s** e vitória >= 90%; `basic` só é relatado. Leitura: segundos de jogo do simulador (a mesma unidade dos 20-60 s das lutas comuns), média sobre as execuções, grupo no Nv 5 com equipamento inicial.
- Ritmo: a rota **típica** (obrigatório + errantes/patrulheiros + baús + missão entregue) chega ao chefe no **Nv 4-6** (média dos 4 ativos).
- Moeda: as duas visitas à cidade compram 1-2 equipamentos.

## Rota e ritmo

A rota simulada (`tools/sim/route_fatia.gd`) percorre: cidade (recruta D, loja) -> estrada -> andar 1 (recruta E, baús) -> volta à cidade (missão, loja, pousada) -> andar 2 -> chefe, com o `GameState` real: XP por contribuição, moeda e drops sorteados, compras pelo `ShopRules`, cura de campo com itens e volta ao ponto de descanso quando o grupo fica fraco (coluna "Voltas"). Perfis: **mínimo** = só o obrigatório (perseguidores, armadilha de batalha, chefe; sem baús nem missão); **típico** = obrigatório + errantes e patrulheiros + baús + missão entregue; **completo** = tudo, inclusive os grupos ("dupla") dos três mapas. O recruta E vai para a reserva (o grupo ativo já tem 4) e não entra na média.

| Perfil | Execuções | Chegou ao chefe | Nível médio no chefe (mín-máx) | Moeda no chefe | Moeda ganha / gasta até lá | Lutas até o chefe | Tempo de luta até o chefe (s) | Voltas ao descanso | Chefe pela rota (vitórias, dur. média s) |
|---|---|---|---|---|---|---|---|---|---|
| minimo | 30 | 30 | 3.0 (2.75-3.25) | 62 | 62 / 50 | 4.0 | 120 | 2.1 | 30/30, 19.1 |
| tipico | 30 | 30 | 5.05 (4.75-5.25) | 56 | 156 / 150 | 10.0 | 183 | 1.7 | 30/30, 15.8 |
| completo | 30 | 30 | 5.95 (5.75-6.25) | 84 | 214 / 180 | 13.0 | 279 | 1.7 | 30/30, 15.6 |

Nível médio por herói ao chegar ao chefe:

| Perfil | Teste A | Teste B | Teste C | Teste D |
|---|---|---|---|---|
| minimo | 3.6 | 3.77 | 1.43 | 3.2 |
| tipico | 6.0 | 5.53 | 3.3 | 5.37 |
| completo | 6.97 | 7.03 | 3.6 | 6.2 |

**Nível estimado no chefe (rota típica): 5.05** (alvo 4-6): dentro da meta. Mínimo: 3.0; completo: 5.95.

**Moeda acumulada (rota típica):** 156 ganhas até o chefe (lutas e missão), 150 gastas (lojas e pousada), 56 no bolso ao entrar na sala do chefe; mais a inicial.

### Rota típica, etapa por etapa

| Etapa | Tag | Nível do grupo ao chegar | Vitórias | Dur. média (s) | XP médio por herói | Nível depois | Moeda depois |
|---|---|---|---|---|---|---|---|
| Cidade: recruta D | - | 1.0 | - | - | - | 1.0 | 50 |
| Cidade: loja (1a visita) | - | 1.0 | - | - | - | 1.0 | 0 |
| Estrada: errante | tipico | 1.0 | 30/30 | 11.0 | 25 | 1.1 | 6 |
| Estrada: patrulheiro | tipico | 1.1 | 30/30 | 11.8 | 25 | 1.69 | 14 |
| Estrada: perseguidor | obrig | 1.69 | 30/30 | 30.2 | 49 | 2.17 | 28 |
| Andar 1: ponto de descanso da entrada | - | 2.17 | - | - | - | 2.17 | 28 |
| Andar 1: patrulheiro | tipico | 2.17 | 30/30 | 10.8 | 25 | 2.5 | 34 |
| Andar 1: errante | tipico | 2.5 | 30/30 | 11.2 | 25 | 2.66 | 42 |
| Andar 1: armadilha de batalha | obrig | 2.66 | 30/30 | 39.1 | 49 | 3.17 | 56 |
| Andar 1: perseguidor | obrig | 3.17 | 30/30 | 10.7 | 25 | 3.26 | 64 |
| Andar 1: baus (Eter x2 e a Erva) | - | 3.26 | - | - | - | 3.26 | 64 |
| Andar 1: recruta E (vai para a reserva) | - | 3.26 | - | - | - | 3.26 | 64 |
| Cidade: entrega da missao | - | 3.26 | - | - | - | 4.43 | 104 |
| Cidade: loja (2a visita) | - | 4.43 | - | - | - | 4.43 | 4 |
| Cidade: pousada | - | 4.43 | - | - | - | 4.43 | 4 |
| Andar 2: patrulheiro | tipico | 4.43 | 30/30 | 16.2 | 37 | 4.53 | 16 |
| Andar 2: errante | tipico | 4.53 | 30/30 | 11.7 | 25 | 4.63 | 30 |
| Andar 2: baus (Pocao x2, Reviver) | - | 4.63 | - | - | - | 4.63 | 30 |
| Andar 2: ponto de descanso antes do chefe | - | 4.63 | - | - | - | 4.63 | 30 |
| Andar 2: perseguidor | obrig | 4.63 | 30/30 | 30.8 | 62 | 5.05 | 56 |
| Andar 2: descanso antes de entrar na sala do chefe | - | 5.05 | - | - | - | 5.05 | 56 |
| Chefe | obrig | 5.05 | 30/30 | 15.8 | 174 | 5.85 | 196 |

### Loja e moeda

Preços da `loja_cidade` e quantas lutas típicas de moeda cada um custa (média da rota típica: 11.6 Moedas por luta, sem contar a missão).

| Item | Preço | Venda (x0.5) | Lutas para pagar |
|---|---|---|---|
| Poção | 10 | 5 | 0.9 |
| Éter | 25 | 12 | 2.2 |
| Remédio | 15 | 7 | 1.3 |
| Reviver | 40 | 20 | 3.4 |
| Lâmina de Aço | 80 | 40 | 6.9 |
| Bastão de Carvalho | 80 | 40 | 6.9 |
| Arco Longo | 80 | 40 | 6.9 |
| Armadura Pesada | 100 | 50 | 8.6 |
| Capacete Leve | 50 | 25 | 4.3 |

Compras da rota (política de compra do simulador: equipamento por prioridade se algum herói ativo ganha com ele, depois Poções até 6):

| Perfil | Visita | Moeda ao chegar | Compra mais frequente | Moeda ao sair |
|---|---|---|---|---|
| tipico | 1 | 50 | Capacete Leve | 0 |
| tipico | 2 | 104 | Lâmina de Aço, Poção x2 | 4 |
| completo | 1 | 50 | Capacete Leve | 0 |
| completo | 2 | 136 | Lâmina de Aço, Capacete Leve | 6 |

Recompensa da missão (lida do evento `morador_c`): 40 Moedas, `Capacete do Teste B` e 120 de XP narrativa para cada herói ativo.

## Lutas comuns

Nível do grupo = o da rota típica ao encontrar cada encontro (média dos ativos, arredondada para baixo; encontros que voltam bem mais tarde aparecem de novo), grupo A-D no equipamento inicial.

| Cenário | Política | Vitórias | Dur média (s) | Dur mediana (s) | HP final | Meta |
|---|---|---|---|---|---|---|
| N1 enc_f1 | basic | 100% | 11.0 | 11.3 | 84% | ok |
| N1 enc_f1 | smart | 100% | 11.0 | 11.3 | 87% | ok |
| N1 enc_f2 | basic | 100% | 11.6 | 11.1 | 93% | ok |
| N1 enc_f2 | smart | 100% | 11.6 | 11.1 | 93% | ok |
| N2 enc_f12 | basic | 100% | 24.7 | 24.3 | 58% | ok |
| N2 enc_f12 | smart | 100% | 30.1 | 30.3 | 69% | ok |
| N3 enc_f12 | basic | 100% | 26.0 | 27.6 | 60% | ok |
| N3 enc_f12 | smart | 100% | 38.1 | 37.7 | 61% | ok |
| N3 enc_f2 | basic | 100% | 11.5 | 11.1 | 94% | ok |
| N3 enc_f2 | smart | 100% | 11.5 | 11.1 | 94% | ok |
| N4 enc_f3 | basic | 100% | 15.6 | 15.6 | 92% | ok |
| N4 enc_f3 | smart | 100% | 16.4 | 16.7 | 92% | ok |
| N4 enc_f4 | basic | 100% | 12.3 | 12.1 | 95% | ok |
| N4 enc_f4 | smart | 100% | 12.3 | 12.1 | 95% | ok |
| N5 enc_f34 | basic | 100% | 26.1 | 25.6 | 85% | ok |
| N5 enc_f34 | smart | 100% | 31.2 | 30.9 | 89% | ok |

<details><summary>Detalhe por cenário</summary>

| Cenario | Exec | Vit | Der | Tempo esg | Dur media (s) | Dur mediana (s) | Acoes/heroi | Dano basico | Dano habil. | TTK (acoes; so execucoes em que o inimigo morreu) | HP final | AP gasto | XP/vit (batalhas p/ nivel) | Estados apl/res |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N1 enc_f1 basic | 60 | 60 | 0 | 0 | 11.0 | 11.3 | 1.4 | 6.8 | 0.0 | inimigo_f1 5.7 | 84% | 0.0 | teste_a 45 (1), teste_b 25 (2), teste_c 0 (?), teste_d 28 (2) | 0/0 |
| N1 enc_f1 smart | 60 | 60 | 0 | 0 | 11.0 | 11.3 | 1.4 | 7.1 | 6.7 | inimigo_f1 5.5 | 87% | 0.9 | teste_a 39 (2), teste_b 36 (2), teste_c 0 (?), teste_d 24 (2) | 0/0 |
| N1 enc_f2 basic | 60 | 60 | 0 | 0 | 11.6 | 11.1 | 1.6 | 7.3 | 0.0 | inimigo_f2 6.3 | 93% | 0.0 | teste_a 44 (2), teste_b 22 (3), teste_c 0 (?), teste_d 32 (2) | 0/0 |
| N1 enc_f2 smart | 60 | 60 | 0 | 0 | 11.6 | 11.1 | 1.6 | 7.3 | 0.0 | inimigo_f2 6.3 | 93% | 0.0 | teste_a 44 (2), teste_b 22 (3), teste_c 0 (?), teste_d 32 (2) | 0/0 |
| N2 enc_f12 basic | 60 | 60 | 0 | 0 | 24.7 | 24.3 | 3.0 | 7.3 | 0.0 | inimigo_f2 6.6, inimigo_f1 12.2 | 58% | 0.0 | teste_a 89 (1), teste_b 21 (4), teste_c 24 (4), teste_d 63 (2) | 0/0 |
| N2 enc_f12 smart | 60 | 60 | 0 | 0 | 30.1 | 30.3 | 3.2 | 8.5 | 11.2 | inimigo_f2 10.5, inimigo_f1 11.3 | 69% | 21.1 | teste_a 63 (2), teste_b 40 (2), teste_c 28 (3), teste_d 65 (2) | 40/5 |
| N3 enc_f12 basic | 60 | 60 | 0 | 0 | 26.0 | 27.6 | 3.2 | 7.6 | 0.0 | inimigo_f2 7.7, inimigo_f1 12.8 | 60% | 0.0 | teste_a 84 (2), teste_b 21 (5), teste_c 24 (5), teste_d 68 (2) | 0/0 |
| N3 enc_f12 smart | 60 | 60 | 0 | 0 | 38.1 | 37.7 | 3.7 | 4.8 | 12.3 | inimigo_f1 14.7, inimigo_f2 13.1 | 61% | 41.9 | teste_a 59 (2), teste_b 66 (2), teste_c 2 (49), teste_d 70 (2) | 12/0 |
| N3 enc_f2 basic | 60 | 60 | 0 | 0 | 11.5 | 11.1 | 1.6 | 7.3 | 0.0 | inimigo_f2 6.3 | 94% | 0.0 | teste_a 41 (3), teste_b 23 (5), teste_c 0 (?), teste_d 35 (3) | 0/0 |
| N3 enc_f2 smart | 60 | 60 | 0 | 0 | 11.5 | 11.1 | 1.6 | 7.3 | 0.0 | inimigo_f2 6.3 | 94% | 0.0 | teste_a 41 (3), teste_b 23 (5), teste_c 0 (?), teste_d 35 (3) | 0/0 |
| N4 enc_f3 basic | 60 | 60 | 0 | 0 | 15.6 | 15.6 | 2.8 | 6.9 | 0.0 | inimigo_f3 11.0 | 92% | 0.0 | teste_a 57 (3), teste_b 31 (5), teste_c 9 (15), teste_d 51 (3) | 0/0 |
| N4 enc_f3 smart | 60 | 60 | 0 | 0 | 16.4 | 16.7 | 2.9 | 7.0 | 0.0 | inimigo_f3 11.8 | 92% | 3.0 | teste_a 55 (3), teste_b 33 (5), teste_c 10 (14), teste_d 50 (3) | 32/28 |
| N4 enc_f4 basic | 60 | 60 | 0 | 0 | 12.3 | 12.1 | 1.8 | 7.5 | 0.0 | inimigo_f4 7.1 | 95% | 0.0 | teste_a 37 (4), teste_b 29 (5), teste_c 0 (?), teste_d 33 (5) | 0/0 |
| N4 enc_f4 smart | 60 | 60 | 0 | 0 | 12.3 | 12.1 | 1.8 | 7.5 | 0.0 | inimigo_f4 7.1 | 95% | 0.0 | teste_a 37 (4), teste_b 29 (5), teste_c 0 (?), teste_d 33 (5) | 0/0 |
| N5 enc_f34 basic | 60 | 60 | 0 | 0 | 26.1 | 25.6 | 4.5 | 7.2 | 0.0 | inimigo_f4 7.0, inimigo_f3 18.0 | 85% | 0.0 | teste_a 91 (2), teste_b 61 (3), teste_c 14 (12), teste_d 81 (3) | 0/0 |
| N5 enc_f34 smart | 60 | 60 | 0 | 0 | 31.2 | 30.9 | 4.7 | 6.4 | 12.7 | inimigo_f4 12.1, inimigo_f3 18.6 | 89% | 31.6 | teste_a 95 (2), teste_b 52 (4), teste_c 7 (23), teste_d 93 (2) | 28/27 |

</details>

## Chefe

Encontro `chefe_fatia` (Guardião + 2 Braços), grupo A-D, alocação `main`, itens: Poção 3, Éter 2, Reviver 1, Remédio 2. Meta no Nv 5: `smart` 15-20 s e vitória >= 90%; os outros níveis mostram a sensibilidade.

| Nível do grupo | Política | Vitórias | Derrotas | Dur média (s) | Dur mediana (s) | HP final | Meta |
|---|---|---|---|---|---|---|---|
| N3 | basic | 100% | 0 | 23.3 | 23.1 | 68% | - |
| N3 | smart | 100% | 0 | 21.6 | 21.3 | 84% | FORA (sensibilidade) |
| N4 | basic | 100% | 0 | 22.5 | 22.6 | 73% | - |
| N4 | smart | 100% | 0 | 19.5 | 19.2 | 83% | ok (sensibilidade) |
| N5 | basic | 100% | 0 | 21.7 | 21.5 | 76% | - |
| N5 | smart | 100% | 0 | 18.4 | 18.9 | 85% | ok (alvo) |
| N6 | basic | 100% | 0 | 19.5 | 19.3 | 80% | - |
| N6 | smart | 100% | 0 | 17.0 | 17.9 | 86% | ok (sensibilidade) |

Chefe pela rota (grupo e kit reais de cada perfil): mínimo 30/30 em 19.1 s; típico 30/30 em 15.8 s; completo 30/30 em 15.6 s.

## Antes -> depois

Só os `.tres` de `data/fatia/` mudaram.

| Valor | Antes | Depois | Motivo |
|---|---|---|---|
| Guardião (fatia): Vitalidade | 28 | 3 | Alvo do chefe: 15-20 s. HP = Vit*5 + Nv*3 + Vit*Nv*0,2: 191 -> 37 de HP; era a maior parte do tempo da luta |
| Braço (fatia) x2: Vitalidade | 17 | 2 | Os braços protegem o núcleo e têm de cair antes dele: 117 -> 24 de HP cada |
| Braço (fatia) x2: nível | 5 | 4 | O nível entra no HP (3 por nível); ajuste fino para ficar dentro de 15-20 s também no Nv 4 |
| Inimigo F1: Vitalidade | 5 | 7 | A luta de 1 inimigo no Nv 1 durava 9,3 s; com Vit 7 fica em ~11 s (piso de 10 s das lutas pequenas) |
| Guardião e Braços: Força, Velocidade, Aura, fases, habilidades e IA | 24 / 8 / 10 (Guardião), 16 / 8 / 2 (Braço) | sem mudança | Só o HP precisava mudar. Subir a Força (até 50/36) e a Velocidade (10 ou 12) não ajudou: a Força quase não mexe na duração e a Velocidade deixa a luta mais longa e mais perigosa (30-39 s, vitória do smart de 83% a 100%) |
| xp_base dos inimigos comuns e do chefe | 100 / 100 / 150 / 100 | sem mudança | A rota típica já chega ao chefe no Nv 5 (alvo 4-6) |
| Moeda, drops, preços da loja e recompensa da missão | valores do conteúdo | sem mudança | A 1ª visita à cidade compra 1 capacete (50) e a 2ª, 1 arma (80): 1-2 equipamentos (alvo) |

Efeito medido (antes: dados da Task 4, 60 execuções por cenário e 30 de rota, mesmas sementes):

| Métrica | Antes | Depois |
|---|---|---|
| Chefe N4 `smart` (vitórias, dur. s) | 72%, 153.8 | 100%, 19.5 |
| Chefe N5 `smart` (vitórias, dur. s) | 92%, 165.6 | 100%, 18.4 |
| Chefe N6 `smart` (vitórias, dur. s) | 88%, 154.5 | 100%, 17.0 |
| Chefe N5 `basic` (vitórias, dur. s) | 0%, 60.1 | 100%, 21.7 |
| Chefe pela rota mínimo (vitórias de 30, dur. s) | 4, 124.5 | 30, 19.1 |
| Chefe pela rota típico (vitórias de 30, dur. s) | 30, 130.2 | 30, 15.8 |
| Chefe pela rota completo (vitórias de 30, dur. s) | 30, 124.0 | 30, 15.6 |
| Luta enc_f1 N1 `smart` (dur. s) | 9.3 | 11.0 |

## Notas e limites

- **Leitura do alvo de 15-20 s.** O plano diz "tempo médio de 15-20 s" para o chefe `smart`; foi lido como segundos de jogo do simulador, a mesma unidade dos 20-60 s das lutas comuns. Efeito colateral: o chefe fica mais curto que as lutas comuns de 2 inimigos (25-38 s) e o HP total dele (Guardião ~37 + 2 Braços ~24 cada) é parecido com o de um inimigo comum. As fases e o contra-ataque continuam nos dados, mas passam rápido. Se a intenção era outra unidade ou uma luta com mais corpo, basta subir a Vitalidade do Guardião e dos Braços (cada ponto de Vit do Guardião soma ~2 s à luta no Nv 5; Vit 4 já leva o Nv 4 para ~20-21 s).
- O chefe quase não ameaça o `smart` (HP final do grupo ~85%) e o `basic` também vence, ao contrário do chefe do M11 (0%).
- **Tempo de jogo.** Só o combate é medido: ~183 s (3.1 min) de luta até o chefe na rota típica, mais ~16 s do chefe. Os ~15 min da fatia dependem de caminhada, diálogos, menus e da volta à cidade, que o simulador não mede; o combate sozinho não preenche esse tempo.
- A volta à cidade para entregar a missão supõe que o andar 1 reaparece sem lutas (o jogador passa direto); lutas de reaparição somariam XP.
- Cura de campo e compras seguem regras simples do simulador (ver `route_fatia.gd`); um jogador real pode gastar a moeda de outro jeito. A moeda que sobra depois da 2ª visita não tem onde ser gasta antes do fim da demo.
- Convenções (TTK, ruído, colunas do detalhe): ver `docs/balance/2026-10-19-relatorio-final.md`.

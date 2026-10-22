# Relatório de balanceamento dos elementos (M13)

Baseline: **padrao escolhido (balance.tres)**. Gerado por `run_sim.ps1 -Fatia -Quick -Runs 60 -RouteRuns 30` (60 execuções por cenário de luta e 30 de rota por perfil; grupo = heróis da fatia A-D com equipamento inicial, alocação `main`; itens e sementes como no relatório do M12). Valores de teste, não canônicos. O relatório do M12 (`2026-10-20-relatorio-fatia.md`) não foi regenerado: continua sendo a referência da rota e das tabelas completas.

## O que mudou na fatia

Só `data/fatia/` e o simulador; `data/test/` fica neutro (as metas antigas do `run_sim.ps1` batem igual: `-Meta` idêntico antes e depois).

- **Heróis próprios da fatia** (`data/fatia/heroes/teste_a_f` a `teste_e_f`): cópias dos heróis de teste com id `_f` (o registro de saves indexa heróis por id; um id repetido faria o save da fatia carregar a versão de teste). Cada um ganha 1 elemento nativo e 1 técnica elemental aprendida no Nv 1 (`data/fatia/abilities/`): A Kagutsuchi/Chama, B Susanoo/Onda, C Indra/Faísca, D Amaterasu/Brilho, E Fuhaku/Vendaval. `start.tres` e os recrutas D e E apontam para as cópias.
- **Inimigos:** cada um com 1-2 fraquezas (-50%) e 1 resistência (50%); o Guardião também absorve Indra (150%). Inimigo F3 (nativo Shukketsu) usa `Mordida` (Sangue + Sangramento, 40% das vezes); Inimigo F4 (nativo Radioativo) usa `Emanação` (40%).
- **Loja:** `Lâmina de Aço` é Kagutsuchi; `Capacete Leve` resiste 30% a Shukketsu.
- **Simulador:** `smart` prefere a técnica/alvo de maior multiplicador elemental (só com fraqueza), escolhe o alvo do ataque básico pelo mesmo critério e nunca escolhe alvo/área com imune ou absorção; `basic` ignora elementos. Com dados neutros o multiplicador é sempre 1 e nada muda.

## Cenário elemental (smart x basic)

Nv 3, duas cópias de Inimigo F3 sem habilidades elementais (`SimFatia.elemental_scenario`). "Fraco" = fraqueza de -50% aos quatro elementos dos heróis A-D; "neutro" = sem afinidade.

| Inimigo | Política | Vitórias | Dur média (s) | HP final |
|---|---|---|---|---|
| neutro | basic | 100% | 34.4 | 71% |
| neutro | smart | 100% | 33.5 | 89% |
| fraco | basic | 100% | 34.4 | 71% |
| fraco | smart | 100% | 21.8 | 93% |

`basic` não muda (ignora elementos); `smart` contra o inimigo fraco vence 37% mais rápido que o `basic` e que ele mesmo no neutro.

## Antes -> depois (só `data/fatia/*.tres`)

Com as fraquezas, o `smart` ficou rápido demais (comuns abaixo do piso de 10 s e chefe no limite de 15 s), então a Vitalidade subiu:

| Valor | Antes | Depois | Motivo |
|---|---|---|---|
| Inimigo F1: Vitalidade | 7 | 8 | `smart` N1 caiu de 11,0 para 9,5 s |
| Inimigo F2: Vitalidade | 5 | 9 | `smart` caiu de 11,6 para ~7 s |
| Inimigo F3: Vitalidade | 12 | 13 | margem sobre o piso de 10 s (N4 `smart` 10,8 s) |
| Inimigo F4: Vitalidade | 5 | 12 | `smart` N4 caiu de 12,3 para 6,7 s |
| Guardião: Vitalidade | 4 (M12: 3) | 6 | centrar o chefe `smart` em 15-20 s com a fraqueza |
| Moeda, drops, preços, XP, Braços | - | sem mudança | rota típica continua no Nv 5 |

## Metas da fatia (M12)

| Meta | Resultado | Situação |
|---|---|---|
| Comuns: `smart` vitória >= 95% e 10-60 s | 100%, 10,3-40,1 s (8 casos) | ok |
| Comuns: `basic` vitória >= 75% | 100% (8 casos) | ok |
| Chefe N5 `smart`: 15-20 s e vitória >= 90% | 100%, 17,8 s | ok |
| Chefe N4 / N6 `smart` (sensibilidade) | 18,8 s / 17,4 s | ok |
| Chefe N3 `smart` (sensibilidade) | 20,6 s | FORA por 0,6 s (já estava fora no M12: 21,6 s) |
| Nível no chefe, rota típica: 4-6 | 5,02 (mín. 3,08; completo 5,89) | ok |
| Chefe pela rota (vitórias, dur. s) | mínimo 30/30, 17,9; típico 30/30, 17,2; completo 30/30, 16,7 | ok |

Chefe N5 `basic`: 100%, 25,3 s (relatado, sem meta). Lutas de 2 inimigos no Nv 3 (`enc_f12`) ficam com `smart` em 40,1 s e 50% de HP final: dentro das metas, mas mais apertadas que no M12 (38,1 s, 61%).

## Notas

- O `smart` só usa a técnica elemental quando há fraqueza, e o ataque básico segue a arma (a `Lâmina de Aço` de Kagutsuchi só aparece depois da 2ª visita à cidade).
- Sangue e Radioativo só aparecem nos dois inimigos comuns; a `Emanação` ignora a afinidade dos heróis, e o `Capacete Leve` só protege da `Mordida`.
- Convenções (TTK, colunas do detalhe): ver `docs/balance/2026-10-19-relatorio-final.md`.

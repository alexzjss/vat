# Relatório de balanceamento das reações (M14)

Baseline: **padrao escolhido (balance.tres)**. Gerado por `run_sim.ps1 -Fatia -Quick` (grupo = heróis da fatia A-D com equipamento inicial, alocação `main`; kit de itens como no relatório do M12). Valores de teste, não canônicos. Os relatórios do M12 e do M13 continuam sendo a referência da rota e das tabelas completas.

## O que mudou

Só `data/fatia/` (Vitalidade e Força de 4 inimigos), a ordem de uma regra do `smart` em `tools/sim/sim_policy.gd` e um teste. **Nenhum número das 28 reações mudou** (`data/reactions/` intacto): os nomes, efeitos e consumos aprovados ficam como estão. `data/test/` fica neutro: `run_sim.ps1 -Meta` idêntico antes e depois (só a linha de tempo muda).

## Problema

Com as reações ligadas, o `smart` encadeava as técnicas elementais dos heróis (A Chama/Fogo, B Onda/Água, C Faísca/Indra, D Brilho/Luz, E Vendaval/Vento) e três lutas comuns caíam abaixo do piso de 10 s: `enc_f1` N1 em 8,4 s, `enc_f2` N1 em 10,0 s e `enc_f3` N4 em 9,0 s. O chefe ficava como antes. Medido no cenário de reações, as reações quase não pesavam: `enc_f34` 21,5 s com reações contra 22,6 s sem (5%).

## Cenário das reações

Nv 5, grupo A-D, 60 execuções. "Sem reações" = tabela vazia (vale também para os inimigos). `basic` ignora marcas, mas os inimigos reagem normalmente.

| Encontro | Política | Vitórias | Dur média (s) | HP final |
|---|---|---|---|---|
| `enc_f34` | smart com reações | 100% | 20.9 | 92% |
| `enc_f34` | smart sem reações | 100% | 26.3 | 89% |
| `enc_f34` | basic | 100% | 40.0 | 74% |
| `chefe_fatia` | smart com reações | 100% | 16.9 | 85% |
| `chefe_fatia` | smart sem reações | 100% | 16.9 | 85% |
| `chefe_fatia` | basic | 100% | 23.6 | 69% |

Antes (só as Tasks 1-5): `enc_f34` 21,5 s com contra 22,6 s sem; chefe 17,5 contra 17,6 s. Agora o `smart` com reações fecha `enc_f34` **20% mais rápido** que sem reações (e 48% mais rápido que o `basic`).

**No chefe as reações continuam sem efeito mensurável** (0%), e isso é estrutural, não de números:

- O Guardião tem o núcleo protegido pelos Braços; o `smart` não mira o núcleo protegido com reação (o golpe já sofre o redutor do escudo).
- Só 3 heróis agem na luta (~12 ações em ~17 s). O Teste C age tarde e o B repete a Onda no núcleo, que só renova a marca de Água.
- Os Braços morrem em 1-2 golpes, então o dano extra de uma reação é quase todo excesso.
- Subir `bonus_pct` de Vapor, Sobrecarga, Supernova e Julgamento para 1-2 (testado) não mexeu em nada no chefe e deixou as reações dos inimigos (Brasa + Faísca do Guardião = Sobrecarga) mais duras com os heróis.

Mudar isso exigiria mexer no chefe (escudo, HP, fases) ou nas regras do `smart`: fica como pergunta em aberto.

## Antes -> depois

| Valor | Antes | Depois | Motivo |
|---|---|---|---|
| Regras do `smart` (`sim_policy.gd`): ordem | área -> reação -> fraqueza | reação -> área -> fraqueza | Com a área antes, o `smart` gastava a AP no golpe em área e quase nunca fechava combos (< 1 reação por luta). Sem marca reagente a área decide como antes (`-Meta` idêntico). Foi a alavanca que fez a reação pesar ~20% em `enc_f34` |
| Inimigo F1: Vitalidade | 8 | 10 | `enc_f1` N1 `smart` caiu de 10,3 para 8,3 s com os combos; volta para 10,8 s |
| Inimigo F1: Força | 27 | 18 | HP maior = luta mais longa; a demo (`--demo-fatia --seed=4`) perdia a armadilha do andar 1 (`enc_f12`). A Força não mexe na duração do `smart` |
| Inimigo F2: Vitalidade | 9 | 10 | `enc_f2` N1 `smart` ficava em 10,0 s (no piso); 14,1 s agora |
| Inimigo F3: Vitalidade | 13 | 20 | `enc_f3` N4 `smart` (Chama + Brilho = Supernova) caía para 9,0 s; agora 11,1 s |
| Guardião: Vitalidade | 6 | 5 | N3 (sensibilidade) ficava em 20,3 s, fora dos 20; centra N3-N6 em 16,7-18,2 s |
| Reações (`data/reactions/*.tres`) | - | sem mudança | A ordem do `smart` bastou; os números aprovados ficam |
| Moeda, drops, preços, XP, Braços, técnicas dos heróis | - | sem mudança | Custo de AP das técnicas testado (4-5 -> 3): sem efeito (a AP não era o limite) |

Trade-off: preferi segurar as lutas curtas pelo conteúdo (Vitalidade dos comuns) a enfraquecer as reações. O custo é que as lutas dos inimigos F1, F2 e F3 ficam mais longas sem reações (por exemplo `enc_f3` N4 sem reações: 14,4 s), o que é o ponto: o combo é o que as encurta.

## Metas da fatia (M12/M13)

| Meta | Resultado | Situação |
|---|---|---|
| Comuns: `smart` vitória >= 95% e 10-60 s | 100%, 10,8-42,9 s (8 casos; mínimos: F1 N1 10,8, F3 N4 11,1, F4 N4 11,5, F2 N3 12,2) | ok |
| Comuns: `basic` vitória >= 75% | 100% (8 casos) | ok |
| Chefe N5 `smart`: 15-20 s e vitória >= 90% | 100%, 16,9 s | ok |
| Chefe N4 / N6 `smart` | 17,1 s / 16,7 s, 100% | ok |
| Chefe N3 `smart` (sensibilidade) | 18,2 s, 100% | ok |
| Nível no chefe, rota típica: 4-6 | 5,01 (mín. 3,03; completo 5,82) | ok |
| Chefe pela rota (vitórias, dur. s) | mínimo 30/30, 16,8; típico 30/30, 16,0; completo 30/30, 15,8 | ok |

Chefe `basic` N5: 100%, 23,6 s (relatado, sem meta). Cenário elemental Nv 3: `smart` x `fraco` 19,1 s contra 43,6 s do `basic` (neutro: 43,4 s).

## Transfusão (Luz + Sangue)

A UI mostrou dois números verdes no atacante, "+6" e "+3". **Não é bug**: o "+6" é a cura da reação (`heal_attacker_pct` 0,5 do golpe) e o "+3" é o roubo de vida do Sangue (`blood_lifesteal` 25% do dano efetivo, `lifesteal` do golpe) quando o golpe que dispara é o do Shukketsu. Com `heal_allies_pct` 0 a lista `heal_allies` fica vazia (o atacante não entra nela). Teste novo em `tests/test_reactions.gd`: `test_transfusion_shows_reaction_heal_and_blood_lifesteal_separately`.

## Demo

`--headless --path game --fixed-fps 60 --quit-after 6000 -- --demo-fatia --seed=N`, todas terminam em `roteiro concluído` (12 lutas):

| Semente | Quadro final |
|---|---|
| 1 | 4110 |
| 2 | 4274 |
| 3 | 4024 |
| 4 | 4235 |
| 5 | 4147 |
| padrão | 4063 |

A semente 4 falhava (quadro 1577, "armadilha de batalha vencida") com a Vitalidade de F1 em 10 e a Força em 27; com a Força em 18 passa. Mesma causa e mesma correção (só dado) do relatório do M13.

## Notas

- `run_sim.ps1 -Meta`: idêntico ao anterior, ignorando a linha de tempo.
- As reações dos inimigos contam no cenário "com reações" (Guardião: Brasa + Faísca; F3/F4: Sangue e Radioativo); com a tabela vazia elas também somem.
- Convenções (TTK, colunas do detalhe): ver `docs/balance/2026-10-19-relatorio-final.md`.

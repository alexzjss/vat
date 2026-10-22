# Relatório de balanceamento dos estados, puzzles e terreno (M15)

Baseline: **padrao escolhido (balance.tres)**. Gerado por `run_sim.ps1 -Fatia -Quick` (grupo = heróis da fatia A-D com equipamento inicial, alocação `main`; kit de itens como no relatório do M12). Valores de teste, não canônicos. O relatório do M14 (`2026-10-22-relatorio-reacoes.md`) é a referência do "antes".

## O que mudou

- **Conteúdo** (`data/fatia/`, `world/fatia/`, todo nome é placeholder):
  - Teste A: **Desafio** (Provocar em si mesmo, Nv 2, 3 AP).
  - Teste B: **Chuvisco** (Susanoo, aplica Molhado, Nv 3, 3 AP) e **Geada** (Susanoo, 50% de Congelado, Nv 6, 5 AP).
  - Teste C: **Escanear** (Scan, Nv 2, 2 AP). A **Lente** (Scan) custa 20 na loja.
  - Inimigo F4 (andar 2): **Espelho** (Reflexo em si, 25% por turno).
  - **Inimigo Raro F** (`enc_raro`, andar 2, parado no canto, fora da rota): **Contagem** (50% por turno).
  - O Guardião e os Braços são imunes a Contagem e Petrificação. O Remédio também cura Contagem e Petrificação.
  - Obstáculos elementais, cada um com um baú no nicho atrás: **Vinhas** (Kagutsuchi, andar 1), **Comporta** (Susanoo, andar 2) e **Mecanismo** (Indra, andar 2).
  - Terreno: **Chuva** na estrada (Susanoo 1,2, Kagutsuchi 0,8) e **Calor** no andar 2 (Kagutsuchi 1,2, Susanoo 0,8).
- **Simulador** (`tools/sim/`): `SimScenario.terrain` e `SimFatia.TERRAIN_BY_ENC` põem o Calor nos encontros do andar 2 (F3, F4, F3+F4 e o chefe), então os números abaixo já incluem o terreno. F1, F2 e F1+F2 aparecem na estrada e no andar 1, e ficam neutros. O `smart` passa a ver o Molhado (`total_resist` com `cfg`); a IA, o `ElementText` e o painel de debug também.
- **Sobras do M14:** `turn_counted` (decisão 20), `ElementDef.icon_text` (21), demo com limite 7500 (22), F4 fecha combos (23). Detalhes na seção própria.

Nenhum número das 28 reações, dos heróis nem do chefe mudou. `data/test/` fica neutro.

## Antes -> depois

| Valor | Antes | Depois | Motivo |
|---|---|---|---|
| F4: regra de cura (`ALLY_HP_BELOW`) | 0,5 | 0,35 | A cura gastava a vez e o AP antes do combo; agora só cura aliado bem ferido |
| F4: regra do Brasa (combo) | primeira | primeira (igual) | Já vinha antes da cura; a falha era outra (abaixo) |
| F4: Mordida (Sangue), 50% | - | nova, logo depois do combo | O F4 fica vivo ~2 turnos e o F3 (Vel 7) quase nunca mordia antes dele agir: 0 combos do F4 em 25 lutas. Com a própria Mordida, ele marca o herói e fecha o Ferver no turno seguinte |
| F4: Espelho (Reflexo), 25% | - | nova | Reflexo no andar 2 |
| Terreno nos cenários do andar 2 | nenhum | Calor | `enc_f3`, `enc_f4`, `enc_f34`, chefe |
| Técnicas novas (Desafio, Chuvisco, Geada, Escanear) | - | só dados | O `smart` não as usa (prefere Onda, Chama etc.): não mexem nos números do simulador |

Tentei antes: acelerar o F3 (Vel 8 a 12) e subir a chance da Mordida dele para 1,0. Fecha o combo, mas as lutas `enc_f34` iam a 31-41 s (de 21 s). Descartado.

## Metas da fatia (M12-M14)

| Meta | Antes (M14) | Depois | Situação |
|---|---|---|---|
| Comuns: `smart` vitória 100% e 10-60 s | 10,8-42,9 s | 10,7-42,8 s (mínimo F3 N4: 11,1 -> 10,7) | ok |
| Comuns: `basic` vitória >= 75% | 100% | 100% (8 casos) | ok |
| `enc_f4` N4 `smart` | 11,5 s | 15,0 s | ok |
| `enc_f34` N5 `smart` | 20,9 s | 24,8 s (sem reações 35,5 s: reação encurta 30%) | ok |
| Chefe N5 `smart`: 15-20 s e vitória >= 90% | 100%, 16,9 s | 100%, 17,2 s | ok |
| Chefe N4 / N6 `smart` | 17,1 / 16,7 s | 17,5 / 16,9 s, 100% | ok |
| Chefe N3 `smart` (sensibilidade) | 18,2 s | 19,1 s, 100% | ok |
| Nível no chefe, rota típica: 4-6 | 5,01 (mín. 3,03; completo 5,82) | 4,99 (mín. 3,01; completo 5,81) | ok |
| Chefe pela rota (vitórias, dur. s) | 30/30: 16,8 / 16,0 / 15,8 | 30/30: 17,2 / 15,4 / 14,3 | ok |

Chefe `basic` N5: 100%, 23,6 s (sem meta). Cenário elemental Nv 3: `smart` x `fraco` 19,5 s contra 43,6 s do `basic`.

Estrada com Chuva (fora do relatório fixo, 30 execuções): `enc_f2` N1 `smart` 12,9 -> 11,5 s; `enc_f1` N1 e `enc_f12` N2 não mudam (10,0 e 28,5 -> 29,0 s). Todos acima de 10 s. O `basic` não usa técnicas elementais e não sente o terreno.

## Combos do F4 (decisão 23)

`enc_f34`, Nv 5, `smart`, 25 execuções, só reações disparadas por ações do F4:

| Medida | Antes | Depois |
|---|---|---|
| Brasa lançada pelo F4 | 0 | 30 |
| **Ferver** fechado pelo F4 (Brasa sobre Sangue) | **0** | **25** |
| Mordida do F4 | - | 27 |
| Cura do F4 | 23 | 1 |

Sem o Calor, o mesmo cenário dá 28 Ferver. Quem marcava o herói antes era só o F3, que agia 1 a 2 vezes por luta.

## Demo

`--headless --path game --fixed-fps 60 --quit-after 7500 -- --demo-fatia --seed=N`, todas terminam em `roteiro concluído` (12 lutas). O último quadro e a folga em relação a 7500:

| Semente | Quadro final | Folga |
|---|---|---|
| 1 | 4113 | 3387 |
| 2 | 4332 | 3168 |
| 3 | 4151 | 3349 |
| 4 | 4309 | 3191 |
| 5 | 4133 | 3367 |
| padrão | 4195 | 3305 |

A rota nova usa o Escanear da Teste C numa luta (em geral no F3 do andar 1, via `BattleScene.auto_hook`), abre as Vinhas com a Chama da Teste A, compra Remédio e Lente, anda com veneno no mapa (forçado em um herói, já que nenhum inimigo da fatia envenena; 3 passos tiram HP sem derrubar) e o cura com o Remédio, e confere o bestiário (4 entradas, todas reveladas, antes do chefe).

Aviso: as sementes 1 e 4 perderam a armadilha de batalha do andar 1 na primeira versão da demo. Causa: o veneno forçado deixava a Teste A 9 HP mais fraca na entrada da armadilha (Nv 3, HP em ~60% depois da armadilha de dano). A demo devolve o HP com Poções depois de curar; nenhum dado de combate mudou.

## Sobras do M14

- **Turno contado duas vezes (20):** `Combatant.turn_counted`, ligado quando uma reação atrasa quem já estava na fila (`ReactionRules.shift_atb`); ao reencher, o controlador só devolve o alvo à fila, sem rodar `on_atb_full`. Zera quando o alvo age, quando a ação dele termina e quando ele cai. Teste: `test_delayed_queued_target_does_not_count_its_turn_twice`.
- **Iniciais da marca (21):** `ElementDef.icon_text` (vazio = primeira letra do `short_name`). Atlas "At", Tsukuyomi "Ts", Radioativo "Rd", Kagutsuchi "F", Susanoo "Á", Indra "R", Amaterasu "L", Fuhaku "V", Shukketsu "S": nove ícones distintos.
- **Limite da demo (22):** 7500; a demo imprime "folga: quadro N de 7500". Lê o `--quit-after` da linha de comando quando existe.
- **Molhado visível (extra):** `ElementMath.total_resist` recebe `cfg` na IA dos inimigos, no `smart` do simulador, no `ElementText` e no painel de debug. `run_sim.ps1 -Meta` idêntico antes e depois (só a linha de tempo muda).

## Notas

- O `smart` não lança Desafio, Chuvisco, Geada nem Escanear; quem exercita essas técnicas é o jogador (e a demo, para o Escanear). Os testes de conteúdo e de fluxo cobrem os dados.
- Pergunta em aberto do M14 (as reações no chefe): sem mudança. O chefe continua sem ganho de reação (17,2 s com reações contra 17,7 s sem).
- Convenções (TTK, colunas do detalhe): ver `docs/balance/2026-10-19-relatorio-final.md`.

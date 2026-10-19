# Balanceamento: simulador e relatório de opções

Esta pasta guarda o relatório comparativo das fórmulas F1–F12 (spec M5, §4) gerado pelo simulador de batalhas. Todos os valores são **de teste**, não canônicos.

## Como rodar

Na raiz do repositório:

```powershell
./run_sim.ps1                      # 30 execuções por cenário, grava o relatório padrão
./run_sim.ps1 -Runs 10             # menos execuções (mais rápido, mais ruído)
./run_sim.ps1 -Out C:\tmp\r.md     # outro destino (o CSV vai ao lado, mesmo nome com .csv)
./run_sim.ps1 -Hard 1.13           # outro fator do cenário difícil (padrão 1,125)
./run_sim.ps1 -HardRuns 10         # execuções do cenário difícil (padrão 20)
./run_sim.ps1 -Search -Runs 30     # só a busca do fator (não grava relatório)
```

O script acha o Godot como o `run_tests.ps1` (variável `GODOT` ou pacote do winget), roda `--import` e depois `tools/sim/run_sim.gd`. `-Hard`, `-HardRuns` e `-Search` são repassados ao script do Godot (`-hard`, `-hardruns`, `-search`). `-Search` varre os fatores 1,12 / 1,125 / 1,13 / 1,135 / 1,14 (`basic` e `smart`, com `-Runs` execuções) e imprime a vitória e a duração de cada um, sem gerar relatório. Com os padrões (30 execuções, 20 no cenário difícil) leva cerca de 9 minutos (medido: 530 s); o tempo cresce linearmente com `-Runs`. O resultado é determinístico: a execução *i* usa a semente `1 + i`.

Arquivos gerados: `2026-10-19-relatorio-opcoes.md` e `2026-10-19-relatorio-opcoes.csv`.

## Cenários

- Grupo: heróis de teste A–D com equipamento inicial, níveis 1, 5 e 10, pontos alocados todos no atributo principal (`main`).
- Encontros: X+Y e X+Y+Z (inimigos de teste).
- Políticas: `basic` (só ataque básico no inimigo de menor HP) e `smart` (revive, cura, Éter, área, estados).
- Cenário **difícil**: nível 1 com equipamento, X+Y+Z com os atributos dos inimigos multiplicados por **1,125** (cópias em código; os `.tres` não mudam), 20 execuções por opção/política. Existe porque nos cenários normais o grupo vence 100% das vezes e Reviver/Veneno/durações não aparecem. O fator vem de uma busca (30 execuções, `basic`/`smart`; o `-search` atual cobre só 1,12–1,14, os fatores maiores foram testados antes com o mesmo comando): ×1,12 → 97%/100%; ×1,125 → 57%/100%; ×1,14 → 10%/100%; ×1,2 → 3%/100%; ×1,3 → 0%/0%; ×1,5, 2,0, 2,5 e 3,0 → 0%/0%. A transição é abrupta (os atributos são arredondados), por isso o fator é fino e só ×1,125–1,135 cai em 40–70% com `basic`.
- Itens: Poção 3, Éter 2, Reviver 1.
- Cada fórmula varia **uma** opção por vez sobre o padrão (tudo A). F9 (nível máximo) só afeta as métricas de XP; F12 tem só A e B (e a tabela B só difere dos dados para barreira, aceleração e paralisia, que as políticas quase não usam: F12 fica praticamente sem teste neste simulador).

## Como ler

1. **Metas**: critérios do design (batalha comum 30–60 s e vitória ≥ 90% com `smart`; `basic` entre 40% e 70%).
2. **Padrão (tudo A)**: tabela completa do comportamento atual, base para comparar.
3. Uma seção por fórmula: resumo por opção × política × nível (somando os dois encontros; o cenário difícil é uma linha própria, nível "1 difícil") e, em "Detalhe por cenário", a tabela completa de cada opção × cenário.

Colunas: *Vitórias* (% de batalhas ganhas), *Tempos esg.* (batalhas que bateram o limite de 600 s de jogo), *Dur média/mediana* (segundos de jogo), *Dano básico/habil.* (dano médio por ação), *HP final* (% do HP do grupo ao fim), *XP/vit/herói* e *Batalhas p/ nível* (estimativa de vitórias até o próximo nível; `?` se não há XP). No detalhe também: ações por herói, TTK por inimigo (ações até cair; média só das execuções em que o inimigo morreu), AP gasto e estados aplicados/resistidos.

O CSV tem uma linha por fórmula × opção × cenário (`BASE` é o padrão), pronto para planilha.

- **M5b**: `./run_sim.ps1 -Final -Runs 30` gera `2026-10-19-relatorio-final.md/.csv` (padrão escolhido, `balance.tres`, nos cenários-meta N1/N5 X+Y e N5/N10 X+Y+Z; metas: smart ≥95% e 20–60 s, basic ≥75%); `-Meta` só imprime as métricas. Baselines: `SimScenario.config_all_a()` (relatório de opções, tudo A) e `config_chosen()` (jogo).
- O cenário "difícil" (×1,125) fica desligado por padrão desde o M5b (conteúdo reajustado; reative com `-Hard F`); o relatório de opções de 2026-10-19 foi gerado com o conteúdo antigo.

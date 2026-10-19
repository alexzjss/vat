# Balanceamento: simulador e relatório de opções

Esta pasta guarda o relatório comparativo das fórmulas F1–F12 (spec M5, §4) gerado pelo simulador de batalhas. Todos os valores são **de teste**, não canônicos.

## Como rodar

Na raiz do repositório:

```powershell
./run_sim.ps1                      # 30 execuções por cenário, grava o relatório padrão
./run_sim.ps1 -Runs 10             # menos execuções (mais rápido, mais ruído)
./run_sim.ps1 -Out C:\tmp\r.md     # outro destino (o CSV vai ao lado, mesmo nome com .csv)
```

O script acha o Godot como o `run_tests.ps1` (variável `GODOT` ou pacote do winget), roda `--import` e depois `tools/sim/run_sim.gd`. Opções extras: `-Hard`/`-HardRuns` e `-Search` são aceitas direto pelo script do Godot (`-- -hard 1.125 -hardruns 20`, `-- -search`). Com 30 execuções (20 no cenário difícil) leva cerca de 8 a 10 minutos; o tempo cresce linearmente com `-Runs`. O resultado é determinístico: a execução *i* usa a semente `1 + i`.

Arquivos gerados: `2026-10-19-relatorio-opcoes.md` e `2026-10-19-relatorio-opcoes.csv`.

## Cenários

- Grupo: heróis de teste A–D com equipamento inicial, níveis 1, 5 e 10, pontos alocados todos no atributo principal (`main`).
- Encontros: X+Y e X+Y+Z (inimigos de teste).
- Políticas: `basic` (só ataque básico no inimigo de menor HP) e `smart` (revive, cura, Éter, área, estados).
- Cenário **difícil**: nível 1 com equipamento, X+Y+Z com os atributos dos inimigos multiplicados por **1,125** (cópias em código; os `.tres` não mudam), 20 execuções por opção/política. Existe porque nos cenários normais o grupo vence 100% das vezes e Reviver/Veneno/durações não aparecem. O fator vem de uma busca (`-search`, 30 execuções, `basic`/`smart`): ×1,12 → 97%/100%; ×1,125 → 57%/100%; ×1,14 → 10%/100%; ×1,2 → 3%/100%; ×1,3 → 0%/0%; ×1,5, 2,0, 2,5 e 3,0 → 0%/0%. A transição é abrupta (os atributos são arredondados), por isso o fator é fino e só ×1,125–1,135 cai em 40–70% com `basic`.
- Itens: Poção 3, Éter 2, Reviver 1.
- Cada fórmula varia **uma** opção por vez sobre o padrão (tudo A). F9 (nível máximo) só afeta as métricas de XP; F12 tem só A e B.

## Como ler

1. **Metas**: critérios do design (batalha comum 30–60 s e vitória ≥ 90% com `smart`; `basic` entre 40% e 70%).
2. **Padrão (tudo A)**: tabela completa do comportamento atual, base para comparar.
3. Uma seção por fórmula: resumo por opção × política × nível (somando os dois encontros; o cenário difícil é uma linha própria, nível "1 difícil") e, em "Detalhe por cenário", a tabela completa de cada opção × cenário.

Colunas: *Vitórias* (% de batalhas ganhas), *Tempos esg.* (batalhas que bateram o limite de 600 s de jogo), *Dur média/mediana* (segundos de jogo), *Dano básico/habil.* (dano médio por ação), *HP final* (% do HP do grupo ao fim), *XP/vit/herói* e *Batalhas p/ nível* (estimativa de vitórias até o próximo nível; `?` se não há XP). No detalhe também: ações por herói, TTK por inimigo (ações até cair), AP gasto e estados aplicados/resistidos.

O CSV tem uma linha por fórmula × opção × cenário (`BASE` é o padrão), pronto para planilha.

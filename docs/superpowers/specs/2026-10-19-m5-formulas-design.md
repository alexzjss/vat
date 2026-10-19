# M5 — Fórmulas e balanceamento: design

> **Data:** 2026-10-19
> **Base:** spec do jogo v4.0 (§5 atributos, §8 valores de teste, catálogo de fórmulas pendentes do guia v3.7 §11), M1–M4 na `main`, [roadmap](../../roadmap.md).
> **Legenda:** **[U]** usuário · **[C]** confirmado na spec · **[E]** escolha do designer (Claude), inspirada em Chrono Trigger (CT) / Final Fantasy (FF), a revisar.

## 1. Intenção e regra de ouro

Tudo que define números hoje é "valor de teste". O M5 troca isso por **fórmulas de verdade** — mas a spec é clara: **fórmulas e coeficientes são decisão do usuário** **[C]** (guia v3.7: "não invente fórmulas, coeficientes… como se fossem decisões"). Então o M5 tem duas metades:

- **M5a — medir e propor (construído agora):** um **simulador de batalhas em lote** e as **opções de fórmula implementadas lado a lado**, selecionáveis por configuração, com um relatório comparando as opções nos encontros de teste.
- **M5b — decidir e aplicar (depois da sua escolha):** você escolhe uma opção por fórmula (ou pede outra); ela vira o padrão, os valores de teste antigos saem, e o conteúdo de teste é rebalanceado até bater as metas.

Este documento detalha o M5a e lista as opções que o M5a vai implementar e medir. Nenhuma opção vira padrão sem a sua aprovação.

## 2. Objetivos / não-objetivos

**Objetivos (M5a)**
- Simulador headless (sem janela) que roda **N batalhas** de um cenário com sementes diferentes e produz métricas.
- Cada fórmula pendente com **2–3 opções** implementadas e escolhidas por um campo do `BalanceConfig`; a opção **atual** continua sendo o padrão (os testes atuais não mudam).
- Relatório em `docs/balance/` (Markdown) gerado por um comando, com uma tabela por fórmula comparando opções.

**Não-objetivos** — escolher fórmulas (é seu), rebalancear conteúdo (M5b), IA nova, interface gráfica do simulador.

**Anti-objetivos** — mudar o comportamento padrão do jogo antes da aprovação; métricas com aleatoriedade não reproduzível (toda execução é determinística pela semente).

## 3. Simulador **[E]**

- **Cenário** (Resource ou dicionário em código de teste): grupo (heróis de teste, nível, pontos alocados por uma regra simples, equipamento), encontro (inimigos), `BalanceConfig` (com as opções escolhidas), política dos heróis, número de batalhas, semente inicial.
- **Políticas dos heróis:**
  - `basic` — só ataque básico no inimigo de menor HP.
  - `smart` — a política usada na revisão do M1: área quando atinge 2+, Veneno/Sono no mais perigoso, Cura abaixo de 40% de HP, Reviver em caído, Éter sem AP.
- **Métricas por cenário:** taxa de vitória; duração média e mediana (segundos de jogo); ações por herói; dano médio por ação (por fonte: ataque básico, habilidade); quantas ações para derrotar cada inimigo (TTK); HP restante do grupo no fim; AP gasto; XP por herói e batalhas até o próximo nível; estados aplicados/resistidos.
- **Execução:** `godot --headless --path game -s tools/sim/run_sim.gd -- <cenário> <opções>`; também uma função chamável por teste GUT (o simulador é testado com batalhas pequenas determinísticas).
- **Saída:** tabela Markdown + CSV em `docs/balance/`.

## 4. Fórmulas e opções a medir **[E]**

Cada linha vira um campo enum no `BalanceConfig` (padrão = A, igual ao jogo de hoje) e coeficientes próprios (valores de teste).

| # | Fórmula | A (atual) | B | C |
|---|---|---|---|---|
| F1 | **Retornos decrescentes** | 1 limiar: até 20 integral, acima ×0,5 | **Estilo Souls** (a spec cita Souls): faixas 1–20 ×1, 21–40 ×0,5, 41+ ×0,25 | Suave: `limite × v / (v + k)` |
| F2 | **HP máximo** | `Vit×10 + Nv×5` | **Estilo FF:** `base + Vit×a + Nv×b + Vit×Nv×c` (investir em Vitalidade rende mais com o nível) | `(base + Vit×a) × (1 + Nv×b)` |
| F3 | **AP máximo** | `Aura×5` | `Aura×a + Nv×b` | `Aura×a × (1 + Nv×b)` |
| F4 | **Velocidade → ATB** | linear: `base + Vel×k` | **relativo ao campo (estilo FF):** taxa normalizada pela Velocidade média de todos os combatentes | tempo de turno `T × r/(r+Vel)` |
| F5 | **Dano físico/habilidade** | subtrativo: `pot×Atr − Vit×0,5` (mín. 1) | **razão (estilo FF):** `pot×Atr × k/(k + defesa)` (nunca zera, escala bem) | subtrativo com defesa de equipamento: `pot×Atr − (Vit×d + Def_eq)` |
| F6 | **Variação de dano** | nenhuma | ±6% (FF usa ~1/16) | ±12% |
| F7 | **Esquiva** | `Vel×k`, teto 15% | **relativa (estilo CT):** `(Vel_alvo − Vel_atacante)×k`, entre 0 e o teto | fixa por equipamento/estado apenas |
| F8 | **Curva de XP** (forma quadrática confirmada **[C]**) | `coef×(n−1)²` com coef 10 | coef calibrado para ~1 nível a cada 3 batalhas comuns no início | coef + termo linear (`a(n−1)² + b(n−1)`) para os primeiros níveis |
| F9 | **Nível máximo** | sem limite | 50 | 99 (FF/CT) |
| F10 | **Reviver** | 25% do HP máx. | 50% | valor fixo + 10% |
| F11 | **Veneno** | dano fixo por turno | % do HP máx. por turno (FF) | fixo + % |
| F12 | **Durações de estado** | valores de teste por estado | tabela única por "força" (fraco/médio/forte) | duração escala com Aura do aplicador |

Métrica-alvo sugerida para a sua decisão (também **[E]**): batalha comum 30–60 s com política `smart` e vitória ≥ 90%; com `basic`, vitória entre 40% e 70% (pressão real sem ser impossível); chefe de teste 2–4 min.

## 5. Processo de decisão (M5b)

1. O M5a entrega o relatório com as opções lado a lado nos cenários de teste (grupo nível 1, 5 e 10; encontro X+Y e X+Y+Z).
2. Você escolhe por linha (ou pede uma opção D). Pode aprovar em blocos.
3. O M5b aplica: as escolhidas viram padrão, as outras saem do código, o `BalanceConfig` ganha valores definitivos (ainda ajustáveis), conteúdo de teste rebalanceado até as metas, e os testes que dependem de números são atualizados com a conta explicada.

## 6. Fica a critério de quem constrói

Estrutura de arquivos do simulador, formato do cenário, nomes dos enums, como a política `smart` escolhe alvos (desde que documentado), coeficientes iniciais das opções B/C (valores de teste razoáveis).

## 7. Validação (M5a)

Testes: cada opção de fórmula com casos numéricos; padrão A idêntico ao atual (os 326 testes passam sem alteração); simulador determinístico (mesma semente → mesmas métricas); política `smart` nunca trava (sempre submete uma ação válida); relatório gerado por comando. Revisão final confere que o comportamento padrão do jogo não mudou.

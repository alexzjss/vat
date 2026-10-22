# Dados da fatia vertical (M12)

Esta pasta guarda os dados da fatia vertical, o percurso que o **Novo jogo** abre (cena `game/world/game_fatia.tscn`). **Tudo aqui é placeholder ou valor de teste**: nomes, textos e números não são canônicos (spec v4.0, seção 8). Nada é história oficial; troque o que quiser.

## O que é placeholder

- **Nomes:** heróis Teste A a E, Morador A a F, Lojista, Pousadeiro, Inimigo F1 a F4, Guardião (fatia), Braço (fatia), e os itens e equipamentos com sufixo `_f` ou nome genérico ("Erva de Teste", "Capacete do Teste B").
- **Textos:** as falas dos eventos são "Texto", "Texto de teste" ou frases de teste que dizem o que a cena faz.
- **Números:** todo valor, como vitalidade, força, XP, Moedas, drops, chances e preços.

## Onde trocar cada coisa

| O quê | Onde | Observações |
|-------|------|-------------|
| Inimigos | `enemies/` (`inimigo_f1` a `inimigo_f4`, `guardiao_fatia`, `braco_fatia`) | Vitalidade, Moedas e drops (`DropEntry`) de cada um |
| Encontros | `encounters/` (`enc_f1`, `enc_f2`, `enc_f12`, `enc_f3`, `enc_f4`, `enc_f34`, `chefe_fatia`) | Quais inimigos formam cada luta |
| Itens | `items/` (`pocao_f`, `eter_f`, `remedio_f`, `reviver_f`, `chave_f`, `erva_teste`) | Preço em `price`; `erva_teste` é o item-chave da missão |
| Equipamento | `equipment/` (`lamina_aco_f`, `bastao_carvalho_f`, `arco_longo_f`, `armadura_pesada_f`, `capacete_leve_f`, `capacete_teste_b_f`) | Preço em `price` |
| Loja | `shops/loja_cidade.tres` | O que está à venda na cidade (estoque infinito) |
| Eventos | `events/` (`morador_a` a `morador_f`, `pousadeiro`, `recruta_d`, `recruta_e`, `placa_dungeon_1`, `placa_dungeon_2`, `placa_saida`, `chefe_entrada`, `cena_final`) | Texto dos diálogos, flags e recrutamento |
| Perfil de início | `start.tres` | Heróis do grupo inicial, itens, Moedas (50), mapa e ponto de entrada |

Os **heróis** da fatia têm cópias próprias em `heroes/` (`teste_a_f` a `teste_e_f`, M13): `start.tres` e os recrutas D e E usam essas, com 1 elemento nativo e 1 técnica elemental (`abilities/`) cada. `data/test/heroes/` fica neutro para as demos e os testes antigos.

Os valores gerais novos ficam em `game/core/defs/balance_config.gd`, com o comentário "valor de teste": `currency_name` (nome da moeda), `inn_price` (preço da pousada), `sell_ratio` (fração do preço que a venda rende) e `max_stack` (limite de pilha ao comprar).

## Depois de mudar um número

Rode o simulador da fatia na raiz do repositório:

```powershell
./run_sim.ps1 -Fatia -Runs 60   # grava docs/balance/2026-10-20-relatorio-fatia.md (e o .csv ao lado)
./run_sim.ps1 -Fatia -Quick     # só imprime as métricas, sem gravar o relatório
```

Confira no relatório se o grupo ainda chega ao chefe no Nível 4 a 6 e se o chefe continua entre 15 e 20 segundos. Se a rota típica sair dessa faixa, ajuste os números da fatia (esta pasta), e não a curva de XP global nem os dados de teste.

## Referências

- Relatório de balanceamento: [`docs/balance/2026-10-20-relatorio-fatia.md`](../../../docs/balance/2026-10-20-relatorio-fatia.md)
- Plano do M12: [`.claude/plans/2026-10-20-m12-fatia-vertical.md`](../../../.claude/plans/2026-10-20-m12-fatia-vertical.md)

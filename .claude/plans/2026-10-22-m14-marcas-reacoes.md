# M14 — Marcas e reações: plano de implementação

> Execução: Sonnet implementa, Haiku documenta, uma revisão final do Sonnet e merge ff local. As decisões do usuário [U] são da rodada 5 (2026-10-22, em `docs/roadmap.md`). O resto é decisão do designer [I]. **Todo número é "valor de teste"**. A **matriz das 28 reações** abaixo é uma **proposta para o usuário revisar**: nomes, efeitos e consumo podem mudar antes da Task 3, que transforma a matriz em dados.

**Goal:** golpes elementais deixam marcas; um elemento diferente sobre uma marca dispara uma das 28 reações; a IA dos inimigos busca combos; a batalha mostra a marca e o nome da reação.

**Fora do M14:** estados novos (Queimadura, Congelado, Molhado, Petrificação, Provocar, Berserk, Contagem, Reflexo), resistência a estados ampliada, efeitos fora da batalha e bestiário → **M15**. Onde a matriz pede um desses estados, o M14 usa um estado que já existe e marca a troca com "→ M15".

## Decisões do usuário [U]
- **Marca:** todo golpe elemental deixa uma marca no alvo (estilo Genshin). Um elemento diferente sobre ela dispara a reação.
- **Duração:** N turnos ATB do alvo. O mesmo elemento sobre a própria marca **só renova**.
- **Matriz completa:** os 8 elementos que reagem formam **28 pares**, e a ordem não importa. O **Radioativo não reage** e não deixa marca.
- **Consumo:** cada reação define o que acontece com as marcas.
- **Efeitos possíveis:** dano extra, estados, área e ATB.
- **IA:** os inimigos buscam combos.
- **Interface:** ícone da marca no alvo e o nome da reação no popup.

## Decisões de design [I]

### Marcas
1. **Uma marca por alvo.** O alvo guarda no máximo uma marca: `Combatant.mark: ElementDef` e `Combatant.mark_turns: int`. Mais simples de ler na tela e de prever; o consumo vira "qual elemento fica".
2. **Quem marca:** um golpe `DAMAGE` com elemento que **reage** (`ElementDef.reacts`) e que **chegou ao alvo**: não foi esquiva, erro ou imune, e não foi absorvido. Dano 0 por barreira **marca** (o golpe acertou). O Radioativo e o neutro não marcam.
3. **Duração:** `mark_turns = 3` turnos ATB do alvo (valor de teste), contados no mesmo ponto em que os estados descontam turnos (`on_atb_full`). O mesmo elemento renova para 3, sem reação.
4. **A marca some** ao cair, no fim da batalha (pelos dois caminhos de fim, como a contaminação) e quando uma reação a consome. Nada de marca no save.
5. **Habilidade com vários efeitos `DAMAGE`:** marca e reage **uma vez por habilidade por alvo**, no primeiro efeito `DAMAGE` que acertar [I]. Evita reação dupla no mesmo golpe.
6. **Área:** cada alvo atingido pela área é tratado à parte (pode reagir em uns e marcar outros).

### Reações
7. **`ReactionDef`** (Resource, `core/defs/reaction_def.gd`):
   - `id`, `display_name`, `a: ElementDef`, `b: ElementDef`;
   - `keep: ElementDef` (nulo = consome as duas marcas; senão fica a marca desse elemento, que precisa ser `a` ou `b`);
   - `bonus_pct: float` (dano extra no golpe que disparou, em % do dano final dele);
   - `target_statuses: Array[StatusDef]` + `status_chance: float`;
   - `area_radius: float` + `area_pct: float` (% do dano final para os **outros** inimigos do alvo no raio) + `area_statuses` com a mesma chance;
   - `target_atb: float` / `attacker_atb: float` (somados à barra, em fração dela: −0,25 atrasa um quarto);
   - `attacker_statuses: Array[StatusDef]`;
   - `heal_attacker_pct: float` (o atacante cura % do dano final) e `heal_allies_pct: float` (o grupo do atacante cura % do dano final);
   - `remove_target_statuses: Array[StatusDef]` (ex.: quebrar Barreira).
   - Um campo vazio ou 0 não faz nada. Novos efeitos entram como novos campos.
8. **`ReactionTable`** (Resource): `reactions: Array[ReactionDef]`, em `data/reactions/tabela.tres`, mais os 28 `.tres` em `data/reactions/`. Um validador acusa par repetido, par faltando entre os elementos que reagem, `keep` fora do par e reação com o Radioativo.
9. **Ordem no golpe:** o dano do golpe é calculado inteiro como no M13 (bônus de mesmo elemento → Sangue → afinidade → escudo → barreira). Se o alvo tinha uma marca de outro elemento, a reação dispara **depois**:
   - o dano extra = `floori(dano final × bonus_pct)`. Ele não passa de novo pela afinidade (já está no dano final) e não marca. A barreira absorve o que sobrou dela;
   - a área atinge os outros com dano **neutro**, sem marcar e sem reagir (nada de reação em cadeia);
   - estados, ATB, cura e remoção de estados, nessa ordem;
   - por fim, o consumo: a marca vira `keep`, ou some.
   - Se o golpe novo não marcaria (absorvido, imune), não há reação. Se o alvo caiu com o golpe, não há reação.
10. **Crédito:** o dano extra e o da área contam para a contribuição de quem atacou, como dano normal. A reação não dá bônus de XP à parte. Estados aplicados pela reação dão o crédito de estado de hoje.
11. **Simetria:** heróis também recebem marcas e sofrem reações dos inimigos.
12. **Resultado:** cada hit ganha `mark` (o elemento que ficou no alvo, ou vazio) e `reaction` (o id, ou vazio). O dano extra, os alvos da área e os efeitos vão num registro `reaction_effects`, para a UI.

### IA e simulador
13. **IA de combo:** novo `AiRule.Condition.CAN_REACT` (algum alvo vivo tem uma marca que reage com o elemento da habilidade da regra) e novo `AiRule.TargetPick.REACTION_TARGET` (o alvo com essa marca; empate: menor HP). Novos valores no fim dos enums.
    - Regras antigas não mudam de comportamento.
    - A Task 4 dá a pelo menos um inimigo da fatia uma regra de combo, e o Guardião ganha uma.
14. **Política `smart` do simulador:** entre as habilidades que já considera, prefere a que dispara reação no alvo; depois, a de fraqueza (M13). Nunca prefere absorção ou imunidade. A `basic` ignora marcas.

### Interface
15. **Ícone da marca:** um círculo pequeno na cor do elemento, com a inicial do `short_name` e os turnos restantes, ao lado do combatente.
16. **Popup da reação:** o nome da reação em destaque, na cor de `a` misturada com `b` (ou a cor de `a`), acima do número do golpe; o dano extra, a cura e os estados aparecem como os popups de hoje.
17. **Debug:** a marca de cada combatente, a última reação e o cálculo do dano extra.
18. **Menu de campo:** fica para o M15, junto com o bestiário (uma página "Reações" com as que o jogador já viu).

## Matriz das 28 reações (aprovada pelo usuário em 2026-10-22)

Elementos que reagem: **Kagutsuchi (Fogo)**, **Susanoo (Água)**, **Fuhaku (Vento)**, **Atlas (Terra)**, **Indra (Raio)**, **Tsukuyomi (Trevas)**, **Amaterasu (Luz)**, **Shukketsu (Sangue)**. O Radioativo fica de fora.

Leitura das colunas:
- **Extra**: dano extra em % do dano final do golpe.
- **Estado**: aplicado no alvo, com a chance entre parênteses.
- **Área**: % do dano final para os outros no raio (P = pequeno 120, M = médio 200, G = grande 300).
- **ATB**: no alvo (A) ou no atacante (At).
- **Fica**: a marca que sobra; "—" = consome as duas.

| # | Par | Nome | Extra | Estado | Área | ATB | Outros | Fica |
|---|---|---|---|---|---|---|---|---|
| 1 | Fogo + Água | Vapor | +50% | Cegueira (50%) | — | — | — | — |
| 2 | Fogo + Vento | Incêndio | +20% | — | 40% P | — | — | Fogo |
| 3 | Fogo + Terra | Magma | +30% | Lentidão (70%) | — | — | — | — |
| 4 | Fogo + Raio | Sobrecarga | +30% | — | 50% M | A −25% | — | — |
| 5 | Fogo + Trevas | Chama Negra | +20% | Veneno (70%) → M15 Queimadura | — | — | — | Trevas |
| 6 | Fogo + Luz | Supernova | +80% | — | — | — | — | — |
| 7 | Fogo + Sangue | Ferver | +20% | Sangramento (100%) | — | — | — | Sangue |
| 8 | Água + Vento | Tempestade | — | — | 30% G | A −15% | — | — |
| 9 | Água + Terra | Lama | — | Lentidão (100%) | — | — | — | Terra |
| 10 | Água + Raio | Eletrocutar | +30% | Paralisia (60%) | — | — | — | — |
| 11 | Água + Trevas | Abismo | +10% | Silêncio (60%) | — | — | — | Trevas |
| 12 | Água + Luz | Arco-íris | — | — | — | — | grupo do atacante cura 20% do dano | — |
| 13 | Água + Sangue | Hemorragia | +20% | Sangramento (100%) | — | — | — | — |
| 14 | Vento + Terra | Tempestade de Areia | — | Cegueira (60%, também na área) | 10% M | — | — | — |
| 15 | Vento + Raio | Ciclone Elétrico | — | — | 40% G | — | — | Raio |
| 16 | Vento + Trevas | Sussurro | — | Confusão (40%) | — | — | — | — |
| 17 | Vento + Luz | Bênção do Vento | — | — | — | At +30% | atacante ganha Pressa | — |
| 18 | Vento + Sangue | Névoa Rubra | — | Sangramento (50%, também na área) | 10% M | — | — | — |
| 19 | Terra + Raio | Fragmentar | +60% | — | — | — | quebra a Barreira do alvo | — |
| 20 | Terra + Trevas | Sepultura | — | Pare (30%) → M15 Petrificação | — | — | — | — |
| 21 | Terra + Luz | Cristalizar | — | — | — | — | atacante ganha Barreira | Terra |
| 22 | Terra + Sangue | Ferro | +20% | Vitalidade − (70%) | — | — | — | — |
| 23 | Raio + Trevas | Trovão Negro | +40% | — | — | A −40% | — | — |
| 24 | Raio + Luz | Julgamento | +70% | — | — | — | — | — |
| 25 | Raio + Sangue | Pulso | — | Paralisia (40%) | — | At +25% | — | — |
| 26 | Trevas + Luz | Eclipse | +50% | Força − (60%) | — | — | — | — |
| 27 | Trevas + Sangue | Maldição | — | Veneno (70%) e Força − (70%) | — | — | — | Trevas |
| 28 | Luz + Sangue | Transfusão | — | — | — | — | atacante cura 50% do dano | — |

Notas da proposta:
- Os estados são os que já existem (`data/test/statuses`). As trocas marcadas "→ M15" acontecem quando os estados novos entrarem.
- Tentei dar a cada elemento um "papel" nas reações: Fogo e Luz explodem dano, Vento espalha (área) e apressa, Água e Terra controlam (Lentidão, Paralisia, Silêncio), Raio mexe no ATB e quebra defesa, Trevas debilita e fica (muitas reações deixam Trevas), Sangue sangra e cura.
- Os números são de teste e vão ser ajustados na Task 6 com o simulador.

## Global Constraints
- Restrições de sempre:
  - tipos estáticos;
  - `core/` sem `Node`, `Input` e IO;
  - números no `BalanceConfig` (ou nos `.tres` das reações) com o comentário "valor de teste";
  - código em inglês, UI em português;
  - nada de `Get-Content`/`Set-Content` em arquivos acentuados;
  - `"\n"` em vez de quebra de linha literal;
  - commitar os `.uid`; manter CRLF;
  - novos enums sempre no final.
- A suíte, `run_sim.ps1 -Meta` (igual ao de hoje, porque os dados de teste são neutros), `run_sim.ps1 -Fatia` e as demos continuam passando. A `--demo-fatia` precisa terminar em **várias seeds** (1–5 e a padrão), com `--quit-after 6000`.
- Nenhuma regra nova consome o `Dice`, exceto as chances de estado das reações, que usam o mesmo caminho de chance de estado de hoje (só quando a reação acontece; dados neutros nunca reagem).

## Review Focus
1. **Marca:** quem marca e quem não (esquiva, erro, imune, absorção, Radioativo, neutro, barreira); uma vez por habilidade por alvo; some ao cair e nos dois fins de batalha. → Task 1.
2. **Reação:** não dispara se o alvo caiu ou se o golpe não marcaria; o dano extra não passa de novo pela afinidade; área sem cadeia; consumo correto (`keep`). → Task 2.
3. **Tabela:** exatamente os 28 pares, nenhum com o Radioativo. → Task 3.
4. **IA:** regras antigas inalteradas; `CAN_REACT` e `REACTION_TARGET` só valem com marca reagente. → Task 4.
5. **Determinismo e dados antigos:** `-Meta` igual; as demos antigas iguais. → todas.

---

### Task 1: Marcas no núcleo (Sonnet)
**Files:** `core/combatant.gd` (`mark`, `mark_turns`), `core/element_math.gd` ou um `core/mark_rules.gd` puro, `core/action_executor.gd` (marcar depois do dano), `core/status_system.gd` (descontar turnos em `on_atb_full`; limpar em `clear_all`), `core/battle_controller.gd` (limpar nos dois fins), `core/defs/balance_config.gd` (`mark_turns`); `tests/test_marks.gd`.
- Testes: cada caso do item 2; renovar com o mesmo elemento; contagem de turnos; uma vez por habilidade; área marca cada alvo; some ao cair e nos fins; o hit carrega `mark`.
- Commit `feat(core): marcas elementais`.

### Task 2: Motor de reações (Sonnet)
**Files:** novos `core/defs/reaction_def.gd`, `core/defs/reaction_table.gd`, `core/reaction_rules.gd` (puro: encontrar o par, aplicar o resultado); `core/action_executor.gd`; `core/battle_state.gd` (a tabela da batalha, carregada de `data/reactions/tabela.tres` ou injetada nos testes); `tests/test_reactions.gd` com uma tabela pequena em memória.
- Testes: cada campo do `ReactionDef` isolado (extra, estado com chance, área sem cadeia, ATB, cura do atacante e do grupo, remover estado, `keep`); sem reação se o alvo caiu ou absorveu; crédito; simetria (inimigo em herói); o validador.
- Commit `feat(core): reacoes elementais`.

### Task 3: A matriz em dados (Sonnet)
**Depois da revisão do usuário.** Cria os 28 `.tres` em `data/reactions/` e `tabela.tres` a partir da matriz aprovada.
- Testes: a tabela carrega; 28 pares, todos os elementos que reagem cobertos, nenhum com o Radioativo; cada reação referencia estados que existem.
- Commit `feat(data): matriz das 28 reacoes`.

### Task 4: IA de combo e simulador (Sonnet)
**Files:** `core/defs/ai_rule.gd`, `core/enemy_ai.gd`, `tools/sim/sim_policy.gd` e cenários; regras de combo em inimigos da fatia (`data/fatia/` só); `tests/test_enemy_ai.gd` (ou o arquivo de IA que existir).
- Testes: `CAN_REACT` e `REACTION_TARGET`; regras antigas iguais; a política smart prefere reação, depois fraqueza.
- Um cenário novo do simulador: smart com reações × smart sem reações × basic.
- Commit `feat(ai): inimigos buscam combos de reacao`.

### Task 5: Interface (Sonnet)
**Files:** `battle/combatant_view.gd` (ícone da marca, popup da reação), `battle/battle_scene.gd`, `battle/debug_panel.gd`, `ui/element_text.gd`; `tests/test_reaction_ui.gd`.
- Verificação visual: `--write-movie` de uma batalha com marca, reação simples, reação em área e reação com ATB, na pasta de scratchpad, fora do repositório.
- Commit `feat(ui): marcas e reacoes na batalha`.

### Task 6: Fatia e balanceamento (Sonnet)
**Files:** `data/fatia/` (técnicas que fecham combos entre os heróis, regras de combo), `data/reactions/*.tres` (só os números), `tools/sim/*`, `docs/balance/2026-10-2x-relatorio-reacoes.md` (novo), `tests/test_fatia_content.gd`.
- As metas do M12/M13 continuam: chefe smart N4–N6 em 15–20 s com ≥90%, lutas comuns nas metas (piso de 10 s), nível no chefe ~4–6. `--demo-fatia` termina nas seeds 1–5 e na padrão.
- Commit `balance(fatia): reacoes no conteudo`.

### Task 7: Documentação (Haiku)
- README: marcas e reações em poucas linhas, com a matriz resumida ou um link para ela.
- `roadmap.md`: M14 concluído; o que fica para o M15.
- `data/reactions/README.md` (novo): como editar uma reação (cada campo), como trocar nome, e o validador.
- Commit `docs: M14 marcas e reacoes`.

**Ordem de execução:** 1 → 2 → **revisão da matriz pelo usuário** → 3 → 4 → 5 → 6 → revisão final e Task 7 em paralelo. As Tasks 1 e 2 não dependem da matriz final: os testes usam tabelas em memória.

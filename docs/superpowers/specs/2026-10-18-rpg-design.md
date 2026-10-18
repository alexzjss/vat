# Design do RPG — versão 4.0

> **Data:** 2026-10-18
> **Base:** guia de continuidade v3.7 (preservado em [`docs/historico/guia_continuidade_v3.7.md`](../../historico/guia_continuidade_v3.7.md)).
> **Regra de leitura:** toda regra da v3.7 continua válida, salvo indicação explícita aqui. Esta versão **acrescenta** decisões; não reescreve as anteriores.
>
> Legenda usada em todo o documento:
> - **[C]** Confirmado pelo usuário (inclui decisões da v3.7 e as novas desta sessão).
> - **[C-4.0]** Confirmado nesta sessão (novo na v4.0).
> - **[P]** Proposta provisória, aprovada como ponto de partida, sujeita a revisão em testes.
> - **[P*]** Proposta nova escrita neste documento, **ainda não revisada** pelo usuário.
> - **[A]** Em aberto.

---

## 0. O que mudou da v3.7 para a v4.0

| Tema | v3.7 | v4.0 |
|---|---|---|
| Motor | Não escolhido | **Godot 4, GDScript tipado** [C-4.0] |
| Escopo do projeto | — | Solo, hobby/aprendizado [C-4.0] |
| Encontros | — | **Inimigos visíveis, batalha no próprio mapa (estilo Chrono Trigger)** [C-4.0] |
| Posição em batalha | Fixa, sem movimentação | Continua fixa, **mas tem efeito mecânico** (áreas de efeito) [C-4.0] |
| HP pós-batalha | Em aberto | **Persiste, como a Aura** [C-4.0] |
| Save | — | **Somente em pontos de descanso** [C-4.0] |
| Batalhas no overworld | — | **Não; somente em mapas locais** [C-4.0] |
| Ação sem alvos válidos | Em aberto | **Falha; Aura gasta é perdida** [C-4.0] |
| Poder de habilidades | Não coberto | **Atributo Aura também escala habilidades; defesa vem de Vitalidade + equipamento** [C-4.0] |
| Soma da XP de combate | Ambíguo | **Cada um recebe fração proporcional arredondada para baixo; soma ≤ XP-base** [C-4.0] |
| Cenário | — | Fantasia + tecnologia (tom próximo de FF7) [C-4.0] |
| Arte | Pixel art moderna | Pixel art moderna como alvo; **formas simples até validar as mecânicas** [C-4.0] |
| Pontos de Etapa A (Wait, fila, desempate, alvo, turnos) | Em aberto | Propostas aprovadas [P] (seção 4) |

---

## 1. Identidade do jogo

- **Gênero:** RPG narrativo clássico [C].
- **Referências:** Chrono Trigger e Final Fantasy VII clássico, como repertório de convenções, não como cópia [C].
- **Visual:** 2D top-down, pixel art moderna [C]. Placeholders geométricos durante a validação [C-4.0].
- **Plataforma:** PC [C].
- **Cenário:** fantasia com tecnologia [C-4.0]. História, personagens, facções e mundo pertencem ao usuário e **não estão neste documento** [C]. Nenhum conteúdo narrativo deve ser inventado.
- **Projeto:** solo, hobby/aprendizado, sem prazo [C-4.0]. Desenvolvedor com experiência em programação (JS/TS), sem experiência prévia em motores [C-4.0].

### 1.1. Pilares [P]

1. **Combate ATB tático** — Velocidade, posição e estados importam, não só dano.
2. **Batalha sem troca de tela** — inimigos visíveis, luta no próprio cenário.
3. **Recompensa por contribuição** — curar, proteger e controlar também fazem evoluir.
4. **Progressão com escolhas** — pontos livres, retornos decrescentes, equipamento com trade-offs.
5. **Gestão de recursos na dungeon** — HP e Aura persistem; descanso e save são pontos de alívio.

---

## 2. Arquitetura técnica

### 2.1. Plataforma

- **Godot 4** (versão estável mais recente no início do M1) [C-4.0].
- **GDScript com tipagem estática** em todo o código [P] — mais integrado ao motor e próximo de TypeScript.
- **Testes:** GUT (Godot Unit Test) [P]; gdUnit4 é alternativa equivalente.
- **Controle de versão:** este repositório git.

### 2.2. Duas camadas

**Núcleo de regras** — scripts GDScript sem dependência de nós visuais (`RefCounted`/`Resource`). Toda regra de jogo vive aqui e é testável isoladamente.

| Unidade | Responsabilidade |
|---|---|
| `StatCalculator` | Atributos efetivos: base + alocados + equipamento → retornos decrescentes → modificadores temporários; derivados (HP máx., Aura máx., taxa ATB, esquiva). |
| `AtbClock` | Avança as barras ATB pelo tempo, respeitando Wait; emite "combatente pronto". |
| `ReadyQueue` | Fila de prontos ordenada por Velocidade, com desempate sorteado uma vez. |
| `ActionResolver` | Máquina de estados da ação: seleção → alvo → confirmação → execução → efeitos → reinício do ATB; reserva/devolução de Aura e itens; redirecionamento e falha. |
| `TargetingService` | Alvos válidos e geometria (alvo único, grupo, todos, círculo, linha). |
| `StatusSystem` | Aplicação, resistência, imunidade, duração por ATB do afetado, gatilhos de remoção, efeitos periódicos. |
| `ContributionLedger` | Registro por (personagem, inimigo) em pontos equivalentes de HP. |
| `XpCalculator` | XP por inimigo e por personagem a partir do ledger; XP narrativa; curva de nível; pontos de atributo. |
| `EnemyAI` | Escolhe ação e alvo por regras de prioridade declaradas no `EnemyDef`. |
| `BattleState` | Estado agregado da batalha; único ponto que a apresentação lê. |

**Apresentação** — cenas, animação, UI, câmera, mapas, áudio. Lê `BattleState` e envia comandos ao núcleo; **nunca decide regras**.

**Fluxo de dados:**
```
Entrada do jogador → UI → comando → ActionResolver → BattleState → sinais → UI/animação
                                         ↑
                    AtbClock / ReadyQueue / StatusSystem / EnemyAI
```

A animação informa ao núcleo o *momento de impacto* de cada efeito (a habilidade define sua duração e quando os efeitos são aplicados [C]); o núcleo aplica os efeitos de forma atômica.

### 2.3. Dados como Resources (`.tres`)

`CharacterDef`, `EnemyDef`, `AbilityDef`, `StatusDef`, `ItemDef`, `EquipmentDef`, `NarrativeEventDef`. Valores ajustáveis no editor sem tocar em código. Os valores de teste ficam concentrados e marcados como **não canônicos** (seção 8).

### 2.4. Estrutura de pastas [P]

```
game/                 projeto Godot
  core/               núcleo de regras (sem nós visuais)
  data/               Resources .tres (defs e balanceamento de teste)
  battle/             cenas e UI de batalha
  world/              mapas, overworld, NPCs (a partir do M2)
  ui/                 menus de campo e componentes
  tests/              testes GUT do núcleo
docs/                 especificação e histórico
```

---

## 3. Mundo e exploração

### 3.1. Modos de jogo [C]

1. **Overworld** em escala reduzida — deslocamento entre locais. **Sem batalhas** [C-4.0].
2. **Mapas locais** — cidades, dungeons e ambientes específicos, em TileMap.
3. **Combate** — no próprio mapa local (seção 4).

### 3.2. Overworld

- Personagem em miniatura; locais marcados levam a mapas próprios [C].
- Meios de transporte liberados pela narrativa [P]; quais e quando: decisão narrativa do usuário [A].

### 3.3. Mapas locais

- NPCs, baús, portas, gatilhos de evento [P].
- Dungeons com inimigos visíveis e **pontos de batalha** marcados no mapa [C-4.0].
- Puzzles, armadilhas e rotas alternativas: quantidade e tipo a definir [A].

### 3.4. Encontros

- Inimigos visíveis patrulham ou ficam parados; contato inicia a batalha [C-4.0].
- Encontros de história são disparados por evento [P].
- Inimigos comuns reaparecem ao sair e voltar à área; chefes e encontros de história não [P].
- Fuga: ninguém recebe XP do combate [C]. Após fugir, o inimigo fica inativo por alguns segundos [P] (duração [A]).
- Como a fuga é executada (comando, chance, custo) [A].
- Vantagem/desvantagem de iniciativa por contato (ex.: atacar pelas costas) [A].

### 3.5. Descanso e save

- **Save somente em pontos de descanso** [C-4.0].
- Descanso recupera HP e Aura por completo [P], sem custo [P].
- Reinício da distribuição de atributos com item raro em ponto de descanso [C].

### 3.6. Sistemas de apoio [P]

- **Menu de campo:** itens, equipamento, status, alocação de pontos, formação (até 4 ativos + suporte), configurações.
- **Lojas:** compra e venda. Moeda (nome, fontes, valores) [A].
- **Diálogo e cutscenes:** diálogo com escolhas opcionais; eventos roteirizados; concessão de XP narrativa.
- **Flags de história:** registro global que controla eventos, portas, NPCs.
- Uso de itens fora de combate e suas restrições [A].

---

## 4. Combate

Todas as regras de combate da v3.7 (seções 3 e 4 do guia) continuam válidas [C]. Abaixo, o que a v4.0 acrescenta.

### 4.1. Batalha no mapa [C-4.0]

1. Contato com inimigo visível → a câmera trava na área da batalha.
2. Heróis e inimigos se movem para **pontos de batalha** definidos no mapa.
3. As posições ficam **fixas** até o fim (preserva a regra v3.2 de "sem movimentação tática") [C].
4. Ao terminar: tela de resultado, possível alocação de pontos, retorno à exploração no mesmo lugar.

### 4.2. Ciclo de uma ação [P]

```
ATB enche → entra na ReadyQueue → é o primeiro da fila e nenhuma ação está executando
  → (herói) menu abre automaticamente, tempo pausa (Wait)
  → comando → alvo(s) → confirmação
  → execução (tempo volta a correr) → efeitos aplicados atomicamente → ATB reinicia
```

- Para inimigos, `EnemyAI` escolhe comando e alvo no lugar do menu.
- O jogador não escolhe a ordem entre heróis prontos [C]: o menu abre para o primeiro da fila.

### 4.3. Fila de prontos e prioridade [P]

- Quem enche a barra entra na `ReadyQueue`, ordenada por Velocidade (maior primeiro) [C].
- Barras que enchem **durante** uma execução apenas entram na fila; nenhuma ação é interrompida [C].
- Ao término de uma ação (todos os efeitos resolvidos [C]), o primeiro da fila age.
- **Desempate:** sorteado **uma única vez**, no momento em que os empatados entram juntos na fila; o resultado é mantido [P].
- Comparação de Velocidade usa a Velocidade efetiva no momento da ordenação [P*]. Se um buff/debuff mudar a Velocidade de quem já está na fila, a fila é reordenada [P*].

### 4.4. Modo Wait [P]

- A pausa do tempo global vale para **todos os submenus**: comando, habilidades, itens, alvo e confirmação.
- Cancelar volta um nível de menu; cancelar no menu principal não é permitido enquanto o personagem é o próximo da fila (ele precisa agir) [P*]. Comando "Defender"/"Passar" para quem não quer agir [A].

### 4.5. Custo, reserva e cancelamento

- Aura é reservada na seleção e devolvida integralmente se o comando for cancelado antes da confirmação [C]. Implementação: reserva na seleção, efetivação na confirmação [P].
- Itens seguem a mesma semântica: reservados na seleção, consumidos na confirmação, devolvidos ao cancelar [P].
- Sem Aura suficiente, a habilidade não pode ser selecionada [C].

### 4.6. Alvos inválidos

- Se um alvo se tornar inválido antes da aplicação do efeito, o efeito é **redirecionado automaticamente** para outro alvo válido do mesmo tipo (mesmo lado, mesma regra de alvo) [P]. Isso concilia a regra v3.7 "solicitar novo alvo quando possível" com o fato de o tempo não estar pausado durante a execução: a "solicitação" é resolvida automaticamente.
- Se não houver nenhum alvo válido, a ação **falha**; a Aura (ou o item) já gasta é **perdida**, e o ATB reinicia normalmente [C-4.0].
- Para habilidades de área, o redirecionamento usa o alvo central; se o centro sumir, escolhe-se o alvo válido mais próximo da posição original [P*].

### 4.7. Geometria e áreas de efeito [C-4.0]

A posição tem efeito mecânico. Formas de alvo:

| Forma | Descrição |
|---|---|
| Alvo único | Um combatente. |
| Grupo / todos | Todos os elegíveis de um lado ou de ambos [C]. |
| Círculo no alvo | Atinge quem estiver dentro de um raio a partir do alvo escolhido. |
| Círculo no executor | Raio centrado em quem usa a habilidade. |
| Linha | Faixa entre o executor e o alvo (e possivelmente além) [P]. |

- Distâncias medidas em unidades do mapa a partir do ponto de batalha de cada combatente [P*].
- Cada habilidade declara se afeta aliados, inimigos ou ambos [P] (fogo amigo existe?) [A].
- A UI mostra uma **prévia da área** durante a seleção de alvo [P].
- Raios, larguras e alcances: **sem valores** [A].
- Inimigos ou habilidades que alteram posições (empurrar, puxar, trocar) [A] — conflitaria com posições fixas; exige decisão explícita.

### 4.8. Turnos para estados [P]

- Um "turno" do afetado = **cada vez que sua barra ATB enche**, inclusive as oportunidades perdidas por Sono/Paralisia. Isso concilia "duração em turnos/ações do afetado" [C] com o ATB contínuo.
- Consequência: estados duram menos tempo real em personagens rápidos.

### 4.9. Grupo ativo e suporte

- Até 4 ativos [C]; suporte executa uma ação sem entrar no grupo [C].
- Chamar o suporte **gasta a ação de quem chama** [P].
- Cada suporte tem um número limitado de usos por batalha [P]; quantidade [A].
- Disponibilidade narrativa e regras de alvo do suporte [A].
- Techs combinadas: **adiadas, não rejeitadas** [C].

### 4.10. IA de inimigos

- IA própria por inimigo [C], declarada no `EnemyDef` como lista de regras com prioridade [P*] (ex.: "se aliado com HP baixo → curar; senão → atacar herói com menor HP").
- Telegraphing de ações fortes [A].

---

## 5. Atributos, equipamento e progressão

### 5.1. Atributos [C]

| Atributo | Função |
|---|---|
| Força | Poder físico; escalonamento de habilidades físicas. |
| Velocidade | Taxa de ATB; chance de esquiva (baixa no geral). |
| Vitalidade | Com o nível, HP máximo. **Também contribui para defesa** [C-4.0]. |
| Aura | Capacidade máxima de pontos de Aura. **Também escala o poder das habilidades de Aura** [C-4.0]. |

- Inteiros, valores iniciais por personagem, retornos decrescentes em todos [C].
- Defesa vem de **Vitalidade + equipamento**; não há atributo de Defesa separado [C-4.0].
- O conjunto pode mudar no futuro [C].

### 5.2. Ordem de cálculo [P]

```
valor_bruto  = base_do_personagem + pontos_alocados + modificadores_de_equipamento
valor_curvado = retornos_decrescentes(valor_bruto)
valor_efetivo = aplicar_modificadores_temporários(valor_curvado)
```

Motivação: equipamento não fura os retornos decrescentes; buffs continuam perceptíveis em níveis altos. Forma das curvas e dos modificadores temporários (somatório/percentual) [A].

### 5.3. Equipamento [C]

Modifica atributos (inclusive negativamente), pode ter passivos, um item por espaço, sem acúmulo no mesmo espaço. Slots concretos e restrições [A].

### 5.4. XP e nível [C]

- XP de combate e narrativa; curva cumulativa quadrática (coeficientes [A]); nível máximo [A].
- 1 ponto por nível; +2 extras nos níveis múltiplos de 5.
- Tela de alocação após batalha/cena com subida de nível; uma tela para vários níveis.

### 5.5. XP de combate [C]

Todas as regras da v3.7 (seções 7.2 e 8) continuam válidas. Esclarecimento v4.0:

- Para cada inimigo, cada personagem recebe `floor(XP_base_do_inimigo × contribuição_do_personagem / contribuição_total_contra_o_inimigo)`; a soma das parcelas é **≤ XP-base** por causa do arredondamento, e o resíduo é descartado [C-4.0].
- Se a contribuição total for zero, ninguém recebe XP por aquele inimigo [C].

### 5.6. XP narrativa [P]

Cada `NarrativeEventDef` declara sua elegibilidade escolhendo uma regra:
- `GRUPO_ATIVO` — somente os ativos no momento do evento;
- `TODOS_RECRUTADOS` — todos os personagens já recrutados, presentes ou não;
- `LISTA` — personagens específicos.

E um sinalizador `inclui_incapacitados` (sim/não). Isso explicita o caso "ausente/incapacitado" da v3.7 sem escolher uma interpretação global.

---

## 6. Estados de combate

Regras da v3.7 (seção 9.1) continuam válidas [C]. Catálogo inicial [P]:

| Estado | Efeito | Remoção |
|---|---|---|
| Veneno | Dano a cada ATB cheio do afetado (valor [A]). | Fim natural, item, habilidade. |
| Sono | Perde as oportunidades de ação; sem ação acumulada ao acordar [C]. | Fim natural, item, habilidade, **dano recebido** [P]. |
| Paralisia | Perde as oportunidades de ação, como Sono. | Fim natural, item, habilidade; **não** por dano [P]. |
| Pressa | Aumenta a taxa de ATB. | Fim natural, habilidade. |
| Lentidão | Reduz a taxa de ATB. | Fim natural, item, habilidade. |
| Barreira | Absorve dano até um limite; conta como proteção no ledger [C]. | Esgotamento, fim natural. |
| Buff/debuff de atributo | Altera um atributo e seus derivados [C]. | Fim natural, item, habilidade. |

- Reaplicação do mesmo estado renova a duração, sem acumular intensidade [C].
- Estados **diferentes** que alteram o mesmo atributo **se somam** [P].
- Pressa e Lentidão no mesmo alvo se anulam (aplicar um remove o outro) [P*].
- Imunidade total impede a aplicação [C]; **resistência parcial reduz a chance de aplicação** [P], podendo ser refinada por estado depois.
- Veneno ao chegar a 0 HP incapacita normalmente [P*].
- Contribuição de controle (Sono/Paralisia) = valor comum por turno efetivamente controlado [C]; valor [A].

---

## 7. Itens, recuperação e economia

- Itens restauram HP ou Aura; uso em combate consome a ação ATB [C].
- Reviver consome a ação normalmente [P] (confirma a leitura da v3.7).
- Revivificação restaura HP reduzido (valor [A]) [C].
- HP e Aura **persistem** entre batalhas [C/C-4.0].
- Inimigos deixam dinheiro e itens [P]; tabelas de drop [A].
- Moeda, preços e lojas [A].

---

## 8. Valores de teste (não canônicos)

O M1 precisa de números para rodar. Regra:

- Todos os números ficam em Resources de balanceamento identificados como **"valores de teste — não canônicos"**.
- As fórmulas de teste são **deliberadamente simples** (ex.: lineares) e existem apenas para exercitar as regras; serão substituídas pelas fórmulas aprovadas na Etapa C da v3.7.
- Nenhum valor de teste deve ser citado como decisão de design.

---

## 9. Marcos de desenvolvimento [P]

| Marco | Conteúdo | Pronto quando |
|---|---|---|
| **M1 — Batalha isolada** | Ver seção 10. | Batalha jogável do início ao fim; testes do núcleo passando; painel de debug confirma as regras. |
| **M2 — Mapa + encontro** | Um mapa local pequeno, movimento do herói, um inimigo visível, entrada/saída da batalha no mapa, pontos de batalha. | Andar → encostar → lutar → voltar a explorar, com HP/Aura persistindo. |
| **M3 — Fatia vertical** | Cidade, dungeon, chefe, ponto de descanso/save, loja, diálogo, XP narrativa, subida de nível. | ~15 min jogáveis do início ao fim, com save/load. |
| **M4+ — Mundo** | Overworld, transporte, conteúdo narrativo do usuário, arte final, áudio. | Definido depois. |

---

## 10. Escopo do M1

### 10.1. Inclui

- Cena de batalha isolada no Godot, com formas geométricas e pontos de batalha fixos.
- **3 heróis genéricos** ("Teste A/B/C") e **2–3 tipos de inimigo genéricos** — nenhum é personagem da história.
- 3–4 habilidades por herói cobrindo: dano em um alvo, círculo, linha, cura, Barreira, Veneno, Sono, Lentidão/Pressa.
- ATB, `ReadyQueue`, Wait em todos os submenus, menu de comandos (Atacar, Habilidade, Item, Suporte opcional).
- Seleção de alvo com prévia de área; redirecionamento; falha com perda de Aura.
- Itens: um de cura, um de Aura, um de reviver.
- IA simples por prioridades.
- Fim de batalha: XP por personagem calculada por inimigo; tela de alocação de pontos se houver subida de nível.
- **Painel de debug:** fila ATB, estados ativos com duração restante, ledger de contribuição por (personagem, inimigo).

### 10.2. Não inclui

Mapas de exploração, overworld, lojas, diálogo, save/load, arte final, áudio, Techs combinadas, fuga (pode entrar como comando simples se trivial).

### 10.3. Testes automatizados (GUT)

Cenários da Etapa F da v3.7:
1. Vários combatentes ficam prontos com o menu pausado → age o de maior Velocidade.
2. Alvo morre antes do efeito → redirecionamento.
3. Executor derrotado após iniciar → ação completa.
4. Área com dano excedente em um inimigo e efetivo em outro → contribuição limitada ao HP restante.
5. Cura/proteção contribuem sem duplicar impacto.
6. Efeito parcialmente resistido / negado por imunidade.
7. Personagem dormindo perde a oportunidade e desperta depois sem ação acumulada.
8. Tentativa sem Aura suficiente; cancelamento devolve a Aura.

Acrescentados na v4.0:
9. Barras enchendo durante uma animação entram na fila sem interromper.
10. Empate de Velocidade sorteado uma vez e mantido.
11. Nenhum alvo válido → ação falha, Aura perdida, ATB reinicia.
12. Sono termina ao receber dano; Paralisia não.
13. Círculo e linha incluem/excluem combatentes corretamente pela posição.
14. Veneno causa dano a cada ATB cheio do afetado.
15. XP por inimigo: arredondamento para baixo; soma ≤ base; contribuição zero → nenhuma XP; fuga → nenhuma XP.
16. Subida de vários níveis → pontos acumulados numa única tela; níveis múltiplos de 5 dão 3 pontos.

---

## 11. Questões em aberto prioritárias

Fecham antes ou durante o M1:
1. Raios/larguras de áreas e se existe fogo amigo (4.7).
2. Comando para "passar a vez"/defender (4.4).
3. Forma da curva de retornos decrescentes (5.2) — começa com valores de teste.

Fecham antes do M2/M3:
4. Mecânica de fuga e iniciativa por contato (3.4).
5. Usos do suporte por batalha (4.9).
6. Moeda, lojas, drops (7).
7. Slots e restrições de equipamento (5.3).
8. Material narrativo: tom e cenário detalhados, quando o usuário quiser compartilhar.

O catálogo de fórmulas pendentes da v3.7 (seção 11 do guia) continua integralmente válido.

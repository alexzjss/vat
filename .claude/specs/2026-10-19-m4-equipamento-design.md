# M4 — Equipamento: design

> **Data:** 2026-10-19
> **Base:** spec do jogo v4.0 (§5.3 Equipamento [C]), M1–M3 na `main`, [roadmap](../../docs/roadmap.md).
> **Legenda:** **[U]** decidido pelo usuário · **[C]** confirmado na spec do jogo · **[E]** escolha do designer (Claude), inspirada em Chrono Trigger (CT) e Final Fantasy (FF), a revisar.
> O usuário pediu para seguir com escolhas inspiradas em CT/FF sem nova rodada de perguntas **[U]**.

## 1. Intenção

A progressão hoje é só nível e pontos de atributo. O M4 adiciona a segunda alavanca clássica: **equipar** armas, armaduras, capacetes e acessórios, cada um com vantagens e desvantagens, alguns com efeitos especiais — e ver na hora como isso muda o herói.

**Sucesso é:** abrir o menu de campo, entrar em **Equipar**, escolher um herói e um espaço, ver a lista do que ele pode usar com a prévia "antes → depois" dos atributos, equipar uma armadura pesada que dá Vitalidade e tira Velocidade, equipar um acessório que impede Sono — e na próxima batalha o herói estar mais resistente, um pouco mais lento e imune a Sono.

## 2. Objetivos / não-objetivos / anti-objetivos

**Objetivos**
- Quatro espaços por herói: **Arma**, **Armadura**, **Capacete**, **Acessório** **[E]** (CT).
- Modificadores de atributo positivos e negativos **[C]**; um item por espaço, trocar substitui **[C]**.
- **Restrições** **[C]** (critério **[E]**): armas têm um **tipo** e cada personagem tem a lista de tipos que pode usar (CT/FF); armaduras e capacetes podem ter uma lista de quem pode usar (vazia = todos); acessórios servem para todos.
- **Efeitos passivos** **[C]**, poucos e ligados a sistemas que já existem **[E]**: imunidade a um estado, resistência a um estado, e começar a batalha com um estado (por exemplo, Pressa ou Barreira).
- Página **Equipar** no menu de campo com prévia antes/depois (FF) e a opção de remover.
- **Mochila de equipamento** compartilhada pelo grupo **[E]** (FF): equipamento sem dono fica nela; equipar tira da mochila, remover devolve.
- Equipamento inicial e um conjunto de itens de teste genéricos.

**Não-objetivos** — loja e drops (C3 ficou fora), "otimizar" automático, equipamento que muda o visual, equipar dentro da batalha, passivos que mexem em fórmulas (porcentagem de HP máximo etc. — ficam para depois do M5 de fórmulas).

**Anti-objetivos** — equipamento furar os retornos decrescentes (a ordem da spec é base + alocados + equipamento → retornos decrescentes → temporários **[C]**); duplicar fórmulas de atributo entre prévia e batalha; deixar um herói equipar o que não pode; perder ou duplicar um item ao trocar.

## 3. Como funciona

### 3.1. Dados
- Cada equipamento tem: nome, espaço, modificadores dos 4 atributos (podem ser negativos), e opcionalmente: tipo de arma (só armas), lista de quem pode usar (só armaduras e capacetes), passivos.
- Cada personagem passa a ter a lista de tipos de arma que usa.
- Tipos de arma de teste, genéricos **[E]**: **Lâmina**, **Bastão**, **Arco**.
- Passivos **[E]**:
  - **Imune a [estado]** — o estado nunca é aplicado no herói.
  - **Resiste a [estado] N%** — reduz a chance de aplicação, como a resistência dos inimigos.
  - **Começa com [estado]** — no início de cada batalha o herói já entra com esse estado (duração normal do estado).
  - Vários itens podem somar resistências do mesmo estado; o total vale no máximo 100% (= imune).

### 3.2. Estado do jogo
- Cada herói guarda o que está em cada espaço (pode estar vazio).
- O grupo tem a mochila (cada equipamento com quantidade).
- O ponto de salvamento guarda equipamento de todos os heróis e a mochila **[E]**.
- Ao trocar equipamento fora de combate: se o HP ou AP máximo **diminuir**, o atual é limitado ao novo máximo; se **aumentar**, o atual não muda **[E]** (FF).

### 3.3. Página Equipar (menu de campo) **[E]**
1. Escolher o herói (ativos e reserva) no painel do grupo.
2. Ver os 4 espaços com o item atual de cada um (ou "—") e um resumo dos atributos.
3. Escolher um espaço → lista dos itens da mochila **que esse herói pode usar nesse espaço**, mais a opção **Remover** (se o espaço não estiver vazio). Itens que o herói não pode usar não aparecem.
4. Ao passar o cursor por um item, a **prévia** mostra para cada atributo "atual → novo" (em cor: verde se sobe, vermelho se desce), HP máximo e AP máximo, e os passivos que o item traz.
5. Confirmar equipa (o item antigo volta para a mochila). Esc volta um passo.
- O comando **Equipar** entra no menu entre Técnicas e Status **[E]**.
- A página **Status** passa a mostrar o equipamento e os passivos ativos do herói.

### 3.4. Na batalha
- Os modificadores entram nos atributos efetivos pela ordem da spec **[C]** — já é assim no código desde o M1.
- Imunidade e resistência valem para heróis do mesmo jeito que já valem para inimigos.
- "Começa com" é aplicado logo antes do primeiro tique da batalha, sem gerar contribuição de XP **[E]**.

### 3.5. Conteúdo de teste **[E]** (genérico, só para exercitar os sistemas)
- Cada herói de teste começa com uma arma do seu tipo e uma armadura simples.
- Na mochila, pelo menos: uma arma melhor de cada tipo, uma armadura pesada (+Vitalidade, −Velocidade), um capacete leve (+Aura), um capacete que só um herói pode usar, e três acessórios — um "Imune a Sono", um "Resiste a Veneno 50%" e um "Começa com Pressa".

## 4. Fica a critério de quem constrói

Nomes de classes e arquivos, layout e cores da página, como as restrições são representadas, onde a soma dos passivos é calculada (desde que seja um lugar só, usado pela prévia, pelo status e pela batalha), números exatos dos itens de teste (valores de teste).

## 4.1. Respostas às dúvidas do revisor de design (todas **[E]**)

1. **"Começa com"** é aplicado de novo **no início de cada batalha**, depois que os combatentes são criados e antes do primeiro tique; não é salvo (estados nunca sobrevivem ao fim da batalha). Se o herói cair e for revivido no meio da luta, o estado não volta.
2. "Começa com" é **forçado**: não rola chance nem resistência, mas **respeita imunidade** (herói imune ao estado não o recebe). A fonte é o próprio herói e **não gera contribuição**. Precisa de um caminho próprio no sistema de estados (aplicação forçada, sem crédito).
3. Resistência de herói usa a mesma conta dos inimigos (`chance × (1 − resistência)`); imunidade devolve "imune" **antes** de qualquer sorteio (como já acontece com inimigos). Heróis não têm resistências próprias; só as do equipamento.
4. Espaços canônicos em inglês no código: `&"weapon"`, `&"armor"`, `&"helmet"`, `&"accessory"` (constantes num lugar só). Hoje não existe nenhum dado de equipamento — `HeroState.equipment` e a soma em `Combatant.from_hero` existem mas nada usa; não há migração.
5. "Quem pode usar" (armaduras e capacetes) é uma lista de **ids de personagem**; vazia = todos. Cada personagem tem **uma ou mais** classes de arma; lista vazia = não usa armas. Arma sem tipo serve para todos. Conteúdo de teste: A = Lâmina, B = Bastão, C = Arco, D = Lâmina e Bastão, E = Arco.
6. Ainda não há save em disco (vem no M6); o salvamento é o da memória (`GameState.save`), que passa a incluir equipamento e mochila. O **equipamento inicial** fica na definição do personagem (aplicado ao criar o herói); a **mochila inicial** vem do jogo raiz, como os itens. O demo segue o padrão do `DemoM3`.
7. O limite do HP/AP atual vale para equipar e remover (os únicos caminhos fora de combate que podem baixar o máximo). Herói caído pode ser equipado e continua com HP 0.
8. Heróis da reserva usam as mesmas regras e contas.
9. A mochila é indexada pelo id do equipamento; duas cópias do mesmo item podem estar em heróis diferentes.
10. A prévia e o Status mostram os valores **efetivos** (os mesmos que a batalha usa, já com retornos decrescentes) dos 4 atributos, mais HP máximo e AP máximo. Nada além disso.

## 5. Validação

Testes de: equipar/remover/trocar sem perder nem duplicar item; restrições por tipo de arma e por lista; prévia usando as mesmas contas da batalha; HP/AP atuais limitados quando o máximo cai; imunidade, resistência e "começa com" funcionando na batalha; salvamento cobrindo equipamento e mochila; página Equipar navegável por teclado e Esc voltando um passo. Demo `--demo-m4` com quadros conferidos. Os 282 testes atuais continuam passando. No fim, partida manual pelo usuário.

## 6. Decisões de implementação do M4

Tomadas durante a construção; todas **[I]** (para revisão do usuário).

1. **[I]** Classes: `EquipmentDef` (nome, espaço, modificadores, `weapon_type`, `allowed_ids`, `passives`), `EquipmentPassive` (tipo + estado + valor), `EquipmentBag` (mochila indexada pelo id) e `EquipmentRules` (`can_equip`, `immunities`, `resistances`, `start_statuses`, `preview`) — o lugar único da soma dos passivos, usado por prévia, Status e batalha.
2. **[I]** A prévia monta um `HeroState` descartável (def, nível, pontos alocados e cópia do equipamento) e lê dele os valores efetivos; o herói real nunca é tocado. (Ressalva menor: o clone compartilha a referência de `allocated`; só leitura.)
3. **[I]** Equipamento inicial aplicado em `HeroState.create` antes do descanso inicial, validado por `can_equip` (item inválido gera `push_error` e é ignorado); não consome a mochila. Dois itens iniciais no mesmo espaço: o último sobrescreve sem aviso.
4. **[I]** Itens de teste: armas `lamina/bastao/arco_simples` (iniciais) e `lamina_aco`, `bastao_carvalho`, `arco_longo`; `armadura_simples` (inicial) e `armadura_pesada`; `capacete_leve`, `capacete_teste_b` (só Teste B); `amuleto_sono` (Anti-Sono), `amuleto_veneno` (Anti-Veneno 50%), `amuleto_pressa` (Começa com Pressa).
5. **[I]** O jogo raiz (`game.tscn`) tem `start_equipment`/`start_equipment_counts`: uma unidade de cada item de teste que não é inicial; passados para `GameState.new_game` (parâmetros `bag_items`/`bag_counts`, opcionais).
6. **[I]** `GameState.equip` devolve o item antigo para a mochila e limita HP/AP atuais (`HeroState.clamp_to_max`); `unequip` idem. `save`/`restore_save` guardam cópias do equipamento (por herói) e da mochila.
7. **[I]** Inimigos: `Combatant.immunities`/`resistances` são leituras vivas de `enemy_def` (o setter é ignorado para inimigos), e não cópias — assim os testes de estados existentes, que alteram o def depois de criar o combatente, continuam valendo sem mudança. Heróis guardam os valores do equipamento.
8. **[I]** "Começa com" é aplicado em `BattleController._init` por `StatusSystem.apply_forced` (sem sorteio, sem resistência, sem crédito/contribuição, mas respeitando imunidade); heróis caídos no início da batalha são pulados. Se o estado já existe, renova sem sorteio.
9. **[I]** Página Equipar: comando "Equipar" entre "Técnicas" e "Status" no menu (as posições dos comandos seguintes mudam; testes do M3 passaram a usar `COMMAND_PAGES.find`/`ATTRIBUTES_INDEX`). Fluxo: herói → 4 espaços ("Arma: Nome" / "Arma: —") → itens usáveis da mochila ("Nome xN") + "Remover" só se ocupado; espaço vazio sem nada usável mostra "Nada para equipar aqui." e não abre lista. Ao confirmar, volta à lista de espaços com o cursor no espaço.
10. **[I]** Prévia: uma linha por atributo/HP máx./AP máx. "antes → depois" (verde sobe, vermelho desce, branco igual), "Tipo: Lâmina|Bastão|Arco" para armas e "Passivos: ..." do equipamento resultante.
11. **[I]** Nomes de estados na interface vêm de um mapa no lado da UI (`EquipPage.STATUS_NAMES`), pois `StatusDef` não tem nome de exibição; id sem entrada aparece com a inicial maiúscula. Rótulos de tipo de arma também ficam na UI.
12. **[I]** Status: bloco "Equipamento:" (4 espaços + "Passivos:") antes de Habilidades; linha de atributo no formato "base + alocado [+ equip] = efetivo" (o termo do equipamento só aparece se não for zero; "(retornos decrescentes)" é acrescentado quando a soma difere do efetivo).
13. **[I]** Demo `--demo-m4` segue o `DemoM3`: abre o menu, em Equipar põe no Teste A a Armadura Pesada (mostrando a prévia) e o Amuleto Anti-Sono, mostra o Status, fecha e entrega ao `DemoM2` (área, batalha com inimigos enfraquecidos, volta).

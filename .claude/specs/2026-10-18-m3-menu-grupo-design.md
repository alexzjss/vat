# M3 — Menu de campo e grupo de 4: design

> **Data:** 2026-10-18
> **Base:** spec do jogo v4.0, M1 (batalha) e M2 (mapa) na `main`; escolha do usuário no [roadmap](../../docs/roadmap.md).
> **Legenda:** **[U]** decidido pelo usuário · **[C]** confirmado na spec do jogo · **[E]** escolha do designer (Claude), inspirada em Chrono Trigger (CT) e Final Fantasy (FF), a revisar.
> O usuário pediu para construir "baseado em inspirações de Chrono Trigger e Final Fantasy" sem nova rodada de perguntas **[U]**.

## 1. Intenção

Hoje o grupo só pode ser gerenciado dentro da batalha. O M3 dá ao jogador o **menu de campo** clássico: abrir durante a exploração, ver o estado do grupo, curar com itens e técnicas, distribuir pontos e montar a **formação** — agora com **até 4 heróis ativos** **[C]** e heróis de reserva.

**Sucesso é:** no mapa, abrir o menu, curar um herói com Poção e outro com a técnica Cura (gastando Aura), alocar pontos pendentes, trocar um herói ativo por um da reserva e mudar o líder — e a próxima batalha refletir tudo isso (4 heróis nos pontos certos, o novo líder andando no mapa).

## 2. Objetivos / não-objetivos / anti-objetivos

**Objetivos**
- Menu de campo com: **Itens**, **Técnicas**, **Status**, **Atributos**, **Formação**, **Fechar** **[E]** (estrutura de FF; técnicas de cura fora de combate como CT e FF).
- Grupo ativo de **1 a 4** heróis **[C]**; os demais ficam na **reserva** **[E]**.
- Batalhas com 4 heróis (arena e batalha isolada com 4 pontos de herói).
- Conteúdo de teste: dois heróis genéricos novos, **Teste D** (ativo) e **Teste E** (reserva).

**Não-objetivos** — equipamento (M4), save em disco e descanso (M6), suporte em batalha (M8), loja, menu de configurações, trocar formação dentro da batalha.

**Anti-objetivos** — duplicar as fórmulas de cura/reviver entre batalha e menu; deixar o jogador montar um grupo vazio; abrir o menu durante batalha, transição ou Game Over; o menu deixar o mundo andando por baixo.

## 3. Como funciona

### 3.1. Abrir e fechar **[E]**
- Ação `open_menu` (**Tab** ou **Esc**) durante a exploração no mapa-múndi ou na área local. Fecha com Esc no nível raiz ou com "Fechar".
- Com o menu aberto, o mapa fica congelado (jogador e inimigos) — como o modo Wait da batalha.
- Não abre durante batalha, transição, telas de resultado ou Game Over.

### 3.2. Tela principal **[E]** (layout FF / painel de grupo de CT)
- À esquerda, a lista de comandos. À direita, o **painel do grupo**: um cartão por herói ativo (nome, nível, barras e números de HP e Aura, marca "caído" e "pontos para alocar"), na ordem da formação; abaixo, a reserva em cartões menores.
- Navegação por teclado como os menus da batalha (setas, Enter, Esc); métodos programáticos para testes.

### 3.3. Itens
- Lista os itens do inventário com quantidade. Usáveis fora de combate: os que só têm efeitos de **cura, reviver ou restaurar Aura** **[E]**; os outros aparecem desabilitados.
- Escolher o item → escolher o herói no painel (ativos e reserva **[E]**) → aplica. Item que não teria efeito (HP cheio para Poção, herói de pé para Reviver, caído para Poção/Éter) fica desabilitado para aquele alvo e não é gasto.
- Fórmulas: as mesmas da batalha (uma única fonte) **[E]**.

### 3.4. Técnicas
- Escolher um herói ativo de pé → lista as habilidades dele cujos efeitos são só **cura/reviver/restaurar Aura** e com alvo aliado **[E]** (CT/FF: Cura fora de combate). Outras habilidades não aparecem.
- Custo de Aura cobrado normalmente; sem Aura suficiente, desabilitada **[C]**.
- Alvo: um herói (ativo ou reserva). Habilidades de grupo afetam todos os ativos **[E]**.
- Fora de combate não há contribuição nem XP **[E]**.

### 3.5. Status
- Por herói: nível, XP atual e quanto falta para o próximo nível, HP/Aura atuais e máximos, os 4 atributos (base, alocados, efetivo), e a lista de habilidades com custo.

### 3.6. Atributos
- Escolher um herói com pontos pendentes → a mesma tela de alocação da subida de nível (M1) **[E]**.

### 3.7. Formação **[E]** (troca de grupo de FF + líder de CT)
- Mostra os ativos (até 4, em ordem: 1º = **líder**, que anda no mapa) e a reserva.
- Ações: **trocar** a posição de dois heróis (ativos entre si, ou um ativo com um da reserva), **mover para a reserva** e **trazer da reserva** (se houver vaga).
- Sempre pelo menos **1** herói ativo; um grupo só com caídos é permitido (o jogador pode revivê-los com itens) — mas **o líder precisa estar de pé**: se o líder estiver caído, o primeiro ativo de pé passa a liderar o mapa **[E]**.
- A ordem da formação define o **ponto de batalha** de cada herói (ativo 1 → ponto 1, …) **[E]**.
- Reserva **não recebe XP de combate** **[C]** e não entra na batalha.

### 3.8. Batalha com 4
- A arena da área local e a batalha isolada do M1 ganham o 4º ponto de herói. A batalha usa os ativos na ordem da formação.
- O ponto de salvamento guarda a formação, a reserva e todos os heróis **[E]**.

## 4. Fica a critério de quem constrói

Nomes de nós e cenas, layout exato e cores, como o menu congela o mapa, onde vivem as funções de efeito compartilhadas, atributos e habilidades do Teste D e do Teste E (genéricos, coerentes com A/B/C).

## 5. Validação

Testes do estado de formação (regras de 1–4, líder, troca, reserva fora da XP), efeitos fora de combate (mesmos números da batalha, sem gasto quando não há efeito), menu (abrir/fechar só quando permitido, navegação, cada submenu), batalha com 4 nos pontos certos, salvamento com formação. Demo `--demo-m3` com quadros conferidos. Os 208 testes atuais continuam passando. No fim, partida manual pelo usuário.

## 6. Decisões de implementação do M3

Tomadas durante a construção; cada uma está marcada **[I]** para revisão do usuário.

1. **[I]** A interface chama o recurso de **"AP"** em todo o menu (cartões, Técnicas, Status), e não "Aura" como diz o texto desta spec — consistente com a batalha do M1. O atributo continua "Aura".
2. **[I]** Itens e técnicas de alvo único podem ter como alvo **heróis da reserva** (o painel do grupo inclui a reserva na seleção). Técnicas de grupo/todos afetam só os ativos.
3. **[I]** Nas listas das páginas, o cursor **pode parar em entradas cinza** (aceitar mostra um aviso, ex.: "AP insuficiente.", "Não pode ser usado aqui."); já na seleção de alvo no painel do grupo, heróis sem efeito são **pulados**.
4. **[I]** **Esc/Tab** dentro do menu é "voltar": desfaz um passo da página (seleção de alvo, ficha do Status, herói escolhido na Formação), depois volta à raiz, e na raiz fecha. O evento é sempre consumido pelo menu, então nunca reabre o menu no mesmo toque. Fora do menu, o Game trata `open_menu` só quando o menu está fechado.
5. **[I]** `FieldActions.can_use_technique` recebe um argumento opcional `state`: sem ele, técnicas de grupo/todos só olham o usuário; a UI sempre passa o estado.
6. **[I]** O menu só abre fora de transição (`Game.busy`), sem batalha no mapa (o que cobre as telas de resultado e de nível) e com o mapa não travado (Game Over). Enquanto aberto, o mapa atual fica com `process_mode = DISABLED` (mesmo mecanismo do fade, M2 §8.17); ao fechar volta a `INHERIT`. Um toque de inimigo que já estava encostado ao abrir pode disparar logo depois de fechar (igual ao fim do fade).
7. **[I]** O marcador do jogador mostra a **inicial da última palavra do nome do líder** ("Teste D" → "D"), porque todos os nomes de teste começam com "Teste". É atualizado ao entrar num mapa e ao fechar o menu.
8. **[I]** Grupo inicial: A, B, C, D ativos e E na reserva (`MAX_ACTIVE = 4`); Teste D tem Golpe em área e Cura, Teste E tem Pulso.
9. **[I]** Batalha com 4: pontos de herói em zigue-zague com 150 px entre eles (batalha isolada e arena da área local). Na batalha do mapa a margem vertical é de ~15 px.
10. **[I]** O ponto de salvamento guarda a formação por ids (ativos e reserva) mais os valores de cada herói; restaurar reordena as mesmas instâncias de `HeroState`.
11. **[I]** Painel do grupo: 4 cartões grandes (nome, nível, "Caído", "+N pts", barras de HP/AP) e cartões pequenos da reserva em grade de 2 colunas; a seleção de alvo usa `pick_accept()` (não `accept`) para não confundir com o `accept` do menu.
12. **[I]** Páginas compartilham uma base `FieldPage` (lista com cursor, linha de aviso); o FieldMenu roteia o teclado para a página ativa por `set_page_input` e o "voltar" por `set_page_cancel`.
13. **[I]** Formação no estilo FF: escolher um herói e depois outro troca os dois; com um herói escolhido aparece a ação extra "Para reserva" / "Para o grupo". Recusas mostram aviso ("Grupo cheio", "O grupo precisa de pelo menos 1 herói").
14. **[I]** Itens não usáveis em campo aparecem em cinza; se ninguém seria afetado, "Ninguém precisa disso." e nada é gasto.
15. **[I]** Demos de debug: `-- --demo-m3` (DemoM3: fere A e C, usa Poção e Cura, abre Status, troca D↔E, fecha e entrega ao DemoM2 para entrar na área e vencer a batalha com a nova formação) e `-- --demo-field-menu` (DemoFieldMenu, movido do game.gd para um nó próprio).

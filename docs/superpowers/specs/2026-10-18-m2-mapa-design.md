# M2 — Mapa-múndi, área local e encontro no mapa: design

> **Data:** 2026-10-18
> **Base:** spec do jogo v4.0 ([`2026-10-18-rpg-design.md`](2026-10-18-rpg-design.md)) e o M1 já implementado (batalha isolada na `main`).
> **Legenda:** **[U]** decidido pelo usuário nesta conversa · **[C]** já confirmado na spec do jogo · **[E]** escolha do designer (Claude), a revisar pelo usuário.

---

## 1. Intenção

O M1 provou que a batalha ATB funciona isolada. O M2 prova o **ciclo de jogo**: andar pelo mundo, entrar num lugar, encontrar um inimigo, lutar **sem trocar de tela** e voltar a explorar. É o primeiro momento em que o jogo "parece um RPG" de ponta a ponta, mesmo com formas simples.

**Sucesso é** jogar este roteiro sem tropeços, só com teclado:

1. Começar no mapa-múndi com o líder do grupo **[U]**.
2. Andar livremente até um local marcado e entrar nele com uma transição simples **[U]**.
3. Andar pela área local, ver um inimigo vagando, encostar nele **[U]**.
4. A batalha acontece ali mesmo: câmera trava, combatentes vão aos pontos de batalha, combate ATB do M1 **[U]** **[C]**.
5. Vencer → telas de resultado/nível do M1 → voltar a andar no mesmo lugar, com o inimigo removido **[U]**.
6. Sair da área e voltar ao mapa-múndi, ao lado do local **[U]**.
7. Se perder: tela de Game Over → recomeçar no último ponto de salvamento, que no M2 é o início no mapa-múndi **[U]**.

## 2. Objetivos, não-objetivos e anti-objetivos

**Objetivos**
- Movimento livre em 8 direções, estilo Chrono Trigger **[U]**, com colisão em paredes/obstáculos.
- Um mapa-múndi pequeno com **um** local de entrada; uma área local pequena com **uma** saída e **um** inimigo visível.
- Inimigos de mapa com comportamento de movimento **plugável**; no M2 só existe "vagar aleatoriamente dentro de uma área delimitada" **[U]**.
- Batalha no próprio mapa reutilizando todo o núcleo e a interface do M1.
- Estado do grupo contínuo entre batalhas e mapas (HP, Aura, XP, níveis, inventário).
- Game Over com retorno ao ponto de salvamento.

**Não-objetivos (ficam para depois)**
- Arte, tiles desenhados, animações de personagem, áudio.
- Gravar em arquivo (save/load em disco), pontos de descanso, menu de campo.
- NPCs, diálogo, lojas, baús, eventos, flags de história.
- Fuga da batalha, iniciativa por contato (atacar pelas costas).
- Outros comportamentos de inimigo (rota fixa, perseguir) — só a interface para eles.
- Veículos, vários locais, várias áreas, transições elaboradas.
- Seguidores (os outros heróis andando atrás do líder).

**Anti-objetivos (seria fracasso mesmo funcionando)**
- A batalha "parecer outra tela": trocar de cena, apagar o mapa ou teletransportar a câmera para longe.
- Quebrar ou duplicar regras do M1 (a batalha tem que ser o mesmo núcleo, não uma cópia).
- Inventar história, nomes ou lugares — tudo continua genérico ("Mundo de teste", "Área de teste", "Inimigo X").
- O jogador ficar preso: sem saída de uma tela, sem como voltar a jogar após derrota, ou preso dentro de colisão após a batalha.

## 3. Restrições

- Godot 4.7, GDScript com tipos estáticos, GUT; mesmas restrições globais do plano M1 (núcleo sem `Node`, números em `BalanceConfig`, identificadores em inglês e textos em português).
- **Sem batalhas no mapa-múndi** **[C]**.
- **HP e Aura persistem** entre batalhas, sem recuperação automática **[C]**.
- Inimigos comuns reaparecem ao sair e voltar à área; chefes/encontros de história não **[C]** (no M2 só há inimigo comum).
- Posições fixas durante a batalha; a posição tem efeito mecânico (áreas de efeito) **[C]**.
- Tudo com formas geométricas e cores lisas **[U]** (continuação do M1).

## 4. Como funciona

### 4.1. Estado do jogo
- Existe um **estado de jogo** único que vive enquanto o jogo roda: os `HeroState` do grupo (os 3 heróis de teste do M1 **[E]**), o inventário, e o **ponto de salvamento**.
- **Inventário passa a persistir** entre batalhas **[E]** (no M1 ele reiniciava a cada batalha; isso era só do M1, spec §12.13).
- **Ponto de salvamento** **[U]**: uma cópia completa do estado do grupo (HP, Aura, XP, nível, pontos alocados e pendentes) e do inventário, mais onde no mundo o jogo recomeça. No M2 é criado uma vez, no início do jogo, e fica **só na memória** **[E]**.
- O estado de jogo é lógica pura (testável sem cenas); a parte visual só lê e pede mudanças.

### 4.2. Mapa-múndi
- Mapa pequeno (cerca de 2–3 telas) feito de formas: chão, alguns obstáculos (água/montanhas como blocos de cor) e **um local marcado** (por exemplo, um quadrado com rótulo "Área de teste").
- O líder é uma forma simples (como o quadrado azul do M1, menor). A câmera o segue, limitada às bordas do mapa.
- Entrar no local (encostar/entrar no marcador) dispara a transição para a área local, no ponto de entrada dela.

### 4.3. Área local
- Mapa pequeno (cerca de 2 telas) com paredes, alguns obstáculos, **uma saída** marcada e **um inimigo** vagando.
- Sair pela saída → transição → mapa-múndi, com o líder ao lado do local (não em cima dele, para não reentrar sem querer) **[E]**.
- Ao reentrar na área, o inimigo derrotado reaparece **[C]**.

### 4.4. Transição
- Escurecer a tela, trocar de mapa, clarear **[E]**. Duração curta (valor de teste no `BalanceConfig`). Durante a transição o jogador não se move.

### 4.5. Movimento do jogador
- Livre em 8 direções **[U]**, velocidade constante (valor de teste), diagonal normalizada (não anda mais rápido na diagonal).
- Controles: setas e WASD **[E]**; Enter/Esc continuam sendo confirmar/cancelar nos menus.
- Colisão com paredes e obstáculos; não atravessa inimigos (encostar inicia a batalha).
- Movimento bloqueado durante transição, batalha e telas de resultado/Game Over.

### 4.6. Inimigo no mapa
- Cada inimigo de mapa tem: uma forma visível (como o círculo vermelho do M1, menor), um **comportamento de movimento** e um **encontro** **[E]**.
- **Comportamento "vagar"** **[U]**: escolhe um ponto aleatório dentro da sua área delimitada, anda até lá, espera um pouco, repete. Nunca sai da área. Aleatoriedade sempre pelo `Dice` injetado (testável).
- Comportamentos são intercambiáveis **[U]**: outros tipos (rota fixa, perseguir) poderão ser adicionados sem mudar o inimigo nem o encontro.
- **Encontro** **[E]**: a lista de inimigos que entram na luta e onde cada combatente fica. No M2: 1 ou 2 inimigos do M1 (por exemplo, Inimigo X sozinho, ou X + Y). Isso deixa pronto, para o futuro, um encostão que puxa um grupo inteiro, como em Chrono Trigger.

### 4.7. Começo do combate no mapa
1. Jogador encosta no inimigo → tudo no mapa congela (jogador e todos os inimigos de mapa).
2. A câmera desliza até o centro da **arena** do encontro e trava **[U]** **[C]**.
3. Os três heróis aparecem/deslizam para os **pontos de batalha** dos heróis e os inimigos do encontro para os pontos dos inimigos **[C]**. Só o líder estava visível no mapa; os outros dois aparecem junto dele e deslizam para seus pontos **[E]**.
4. A forma de mapa do inimigo encostado some e dá lugar ao(s) combatente(s) da batalha.
5. Começa a batalha ATB do M1, com o mesmo núcleo, menu, prévia de área, painel de debug e telas.
- **Pontos de batalha** **[C]**: cada encontro tem uma arena marcada no mapa — um centro e os pontos de cada herói e de cada inimigo. A arena fica perto de onde o inimigo vaga, em espaço aberto (o designer do mapa garante que os pontos não ficam dentro de paredes).

### 4.8. Fim do combate
- **Vitória:** XP e telas de nível do M1. Em seguida a ação é só **"Continuar"** **[E]** (as opções "Descansar e lutar"/"Lutar de novo" são do modo de batalha isolada do M1 e não aparecem no mapa). Os combatentes somem, o líder volta a ficar visível **no ponto de batalha do líder** (ou onde estava, se aquele ponto estiver bloqueado), a câmera volta a segui-lo e o mapa descongela. O inimigo derrotado fica removido até o jogador sair da área.
- **Derrota:** tela de **Game Over** **[U]** com uma ação "Continuar" → restaura o ponto de salvamento (grupo + inventário) e coloca o jogador no início do mapa-múndi **[U]**.
- HP e Aura do grupo depois da vitória continuam como terminaram **[C]**; heróis caídos continuam caídos até serem revividos (spec §12.12).

### 4.9. Batalha isolada do M1
- Continua existindo e funcionando (útil para testar regras de combate). O jogo passa a abrir no mapa-múndi; a batalha isolada fica acessível como cena separada / opção de depuração **[E]**.

## 5. Validação

- Testes automatizados para: estado de jogo (salvar/restaurar ponto de salvamento, inventário persistente), comportamento "vagar" (nunca sai da área, determinístico com `Dice` fixo), começo/fim do encontro (congelar, posições de batalha, remoção do inimigo, retorno do líder), Game Over (restaura e volta ao início), transições (entrar/sair coloca o jogador no lugar certo), reaparecimento do inimigo ao reentrar.
- Um roteiro de demonstração (`--demo-m2`) que percorre o ciclo inteiro sozinho, para gerar quadros com `--write-movie` e conferir visualmente.
- Os testes do M1 continuam passando.
- Ao final: partida manual pelo usuário com teclado.

## 6. Fica a critério de quem constrói

- Estrutura de cenas e nomes de nós; como o estado de jogo é exposto às cenas (autoload ou nó raiz).
- Como os mapas são montados (polígonos, `TileMapLayer` com tiles geradas por código, ou nós de colisão simples), desde que sejam formas e cores lisas.
- Como a batalha do M1 é extraída para ser instanciada dentro de um mapa, desde que não duplique lógica.
- Velocidades, tempos de espera, duração de transição e tamanhos (valores de teste no `BalanceConfig`).
- Formas, cores e rótulos dos marcadores.

## 7. Escolhas do designer a revisar ([E])

1. Grupo = os 3 heróis de teste do M1; só o líder aparece andando.
2. Inventário persiste entre batalhas no M2.
3. Ponto de salvamento só na memória.
4. Saída da área deixa o líder ao lado do local no mapa-múndi.
5. Transição = escurecer/clarear.
6. Controles: setas e WASD.
7. Inimigo de mapa aponta para um "encontro" com 1–2 inimigos.
8. Os outros dois heróis aparecem junto do líder e deslizam aos pontos de batalha.
9. Após vitória no mapa, só "Continuar"; líder reaparece no ponto de batalha do líder.
10. Jogo abre no mapa-múndi; a batalha isolada do M1 fica como cena separada.
11. A batalha no mapa acontece **nas coordenadas do próprio mapa**: os pontos da arena são a fonte das posições dos combatentes, e por isso as áreas de efeito e a prévia de alvo usam essas posições. Cada arena cabe inteira numa tela (1280×720) com a câmera centrada nela.
12. No mapa aparece **uma** forma de inimigo; o encontro dela tem **2** combatentes (Inimigo X + Inimigo Y do M1), para validar várias posições. A forma some e os dois combatentes aparecem nos seus pontos.
13. Inventário: no mapa usa o do estado de jogo (persistente); a batalha isolada do M1 mantém seu próprio inventário inicial. Itens gastos não voltam no M2 (não há lojas nem baús), exceto pelo Game Over, que restaura o inventário salvo.
14. Game Over restaura exatamente a cópia feita no início do jogo (grupo cheio, inventário inicial). A área local volta ao normal porque o jogador recomeça no mapa-múndi.
15. As telas de resultado do M1 ganham um modo: no mapa mostram só "Continuar"; na batalha isolada mantêm "Descansar e lutar"/"Lutar de novo". Os testes do M1 continuam valendo.

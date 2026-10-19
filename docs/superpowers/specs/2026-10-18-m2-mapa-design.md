# M2 — Mapa-múndi, área local e encontro no mapa: design

> **Data:** 2026-10-18
> **Base:** spec do jogo v4.0 ([`2026-10-18-rpg-design.md`](2026-10-18-rpg-design.md)) e o M1 já implementado (batalha isolada na `main`).
> **Legenda:** **[U]** decidido pelo usuário nesta conversa · **[C]** já confirmado na spec do jogo · **[E]** escolha do designer (Claude), a revisar pelo usuário · **[I]** decidido durante a implementação, a revisar pelo usuário (seção 8).

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

## 8. Decisões de implementação do M2

O que a implementação decidiu além deste design. Tudo aqui é **[I]**: funciona e está coberto por testes (208 no fim do M2), mas cada item é para o usuário revisar. Fontes: relatórios das tarefas 1–9 do plano do M2.

**Estado de jogo e dados**
1. **[I]** `GameState` vive no nó raiz `Game` (não é autoload). `HeroState.snapshot/restore` e `Inventory.copy` viraram API pública, e a `BattleScene` do M1 passou a usá-las (as cópias privadas dela foram removidas).
2. **[I]** Nove campos novos no `BalanceConfig` (velocidade do jogador, tempos de fade, de deslize da câmera e da batalha, parâmetros do "vagar" etc.), todos valores de teste.
3. **[I]** O `Game` usa `world_seed = -1` por padrão: o `Dice` do jogo é aleatório em partida normal; os testes usam semente fixa.

**Inimigo de mapa e "vagar"**
4. **[I]** "Vagar": a primeira espera já consome um número aleatório; um alvo fora da área é trazido para dentro (sem sorteio); se o inimigo fica preso (não sai do lugar por um tempo), volta a esperar.
5. **[I]** `MapEnemy.touched` dispara uma vez até `rearm()`; `rearm()` dispara de novo na hora se o jogador ainda estiver encostado. A área de toque (raio 22) é maior que o corpo (raio 14).
6. **[I]** Camadas de colisão: mundo = camada 1, jogador = camada 2 (colide com 1 e 3), inimigos de mapa = camada 3.

**Jogador, câmera e zonas**
7. **[I]** O `Player` só anda depois de receber `cfg` (sem `cfg` fica parado). Tem `override_dir`, que substitui o teclado (testes e demo).
8. **[I]** Os limites da câmera ficam no código de cada mapa (`MAP_RECT`), não na cena. `resume_follow` interpola até a posição atual do jogador, para não dar salto.
9. **[I]** `Zone` só dispara em `body_entered`, e só para o `Player`: rearmar uma zona com o jogador já dentro não dispara; é preciso sair e entrar de novo. O retângulo visível da zona vem do `RectangleShape2D` dela.

**Batalha no mapa**
10. **[I]** A `BattleScene` ganhou `Mode { STANDALONE, MAP }` e `start_with(...)`, que recebe posições, o inventário (o mesmo objeto, sem cópia) e a posição de onde os combatentes deslizam. O deslize é uma interpolação manual em `_process`, e o ATB não avança enquanto ele dura. Fundo e rótulo de desfecho somem no modo MAP pelo script (a cena não mudou).
11. **[I]** No modo MAP os ids dos inimigos são indexados (`inimigo_x_0`, `inimigo_y_1`), sempre, mesmo com um só inimigo, porque o encontro pode repetir o mesmo inimigo. Na batalha isolada continuam sendo o id da definição (testes do M1).
12. **[I]** Ordem de início: a `BattleScene` ainda tem o `_auto_start` adiado do M1; quem a hospeda chama `start_with` de forma síncrona logo depois do `add_child`, e o `_auto_start` é pulado porque o `ctrl` já existe.
13. **[I]** Depois de `finished`, a `BattleScene` não se remove sozinha; quem hospeda (a `LocalMap`) a libera.
14. **[I]** Pontos da arena dos heróis com 150 px de distância vertical (como os do M1): com 110 px as barras de um herói cobriam o nome do seguinte.
15. **[I]** O líder volta exatamente ao ponto do líder na arena; o designer do mapa garante que esse ponto está livre (a alternativa "onde estava, se o ponto estiver bloqueado" do §4.8 não foi implementada).
16. **[I]** `LocalMap.dice_seed` (semente do `Dice` da batalha; -1 = sorteada do `Dice` do jogo) e `LocalMap.locked` (bloqueia encontro e saída depois da derrota e durante a transição de saída). Inimigo sem encontro gera erro e é ignorado.

**Jogo raiz, transições e Game Over**
17. **[I]** Durante o fade os dois mapas ficam congelados (`process_mode = DISABLED`): o que sai é congelado de forma adiada (a troca costuma vir de um callback de física) e, enquanto isso, `locked` barra encontros e saída; o que entra fica congelado até o fim do clarear. Uma zona ou um inimigo que já esteja encostado quando o mapa descongela dispara nesse momento (não se perde).
18. **[I]** `Game.busy` ignora sinais de mapa e novas chamadas de `go_to` durante a transição. O fade cancela o tween anterior; com o `busy` isso nunca acontece, mas o fade não foi feito para ser cancelável.
19. **[I]** Fade numa `CanvasLayer` na camada 10, acima da interface da batalha. Com tempo 0 ele ainda espera um quadro.
20. **[I]** O Game Over sempre volta a `save_map/save_spawn`, que no M2 é sempre o início do mapa-múndi (nada grava no meio do jogo).

**Demonstração e verificação**
21. **[I]** `-- --demo-m2`: o `Game` adiciona um `DemoM2`, que anda com o jogador por pontos fixos dos mapas de teste (reavaliados a cada quadro de física, esperando `Game.busy`), liga `auto_battle` e `demo_result` na área local e aceita as telas pelo roteiro da batalha. O ciclo inteiro leva cerca de 38 s de jogo.
22. **[I]** No demo os inimigos do encontro começam com 2 de HP. O enfraquecimento do M1 (1/4 do HP) não basta no mapa: o Inimigo Y cura o X e o ataque básico do `auto_battle` tira cerca de 2 de HP, então a batalha não terminava. Só afeta o demo.
23. **[I]** `BattleScene.demo_result` virou público (antes `_demo_result`) e a `LocalMap` o repassa; no modo MAP o roteiro também aceita o "Continuar" final.
24. **[I]** Lição de codificação: o PowerShell 5.1 (`Get-Content`/`Set-Content`) corrompe UTF-8 em `.tscn`/`.gd` (o rótulo "Saída" virou mojibake uma vez). Arquivos com acentos são editados com Python ou com o editor, e um teste confere o texto "Saída".

# Prototipo de RPG com batalha ATB (Godot 4)

Prototipo de um RPG com combate em tempo real por barra de ATB, feito em Godot 4 com GDScript tipado e placeholders geometricos. Nao ha conteudo narrativo; personagens, inimigos e lugares sao genericos.

O marco atual e o M10, que acrescenta ao M9 o sistema de eventos (caixa de diálogo com nome e escolhas, flags de história, NPCs e placas, cenas roteirizadas e XP narrativa), os objetos de dungeon (baús, portas e chaves, interruptores e armadilhas) e uma dungeon de teste ligada ao mapa-mundi. Antes disso, o M9 acrescentou as técnicas por personagem, mantendo a barra de Limite (M8), o Suporte da reserva (M8.5), fuga, iniciativa por contato, corrida e inimigos com comportamento no mapa: o jogo abre numa tela de título (Novo jogo / Continuar), de onde se chega a um mapa-mundi de teste com áreas locais e inimigos de mapa; tocar um inimigo inicia a batalha no próprio mapa. Há save em disco com 3 slots, gravado só em pontos de descanso e no mapa-mundi, e a página Config do menu de campo. Na derrota (Game Over), o jogo volta ao título e o progresso desde o último save em disco se perde.

A batalha do M1 continua disponivel como cena isolada: ATB com modo Wait, fila de prontos, pontos de Aura, itens, estados, areas de efeito, contribuicao e XP.

**Os numeros em `game/data/test` sao valores de teste, nao canonicos** (spec v4.0, secao 8).

## Requisitos

- Godot 4.7 (>= 4.4). Instalacao no Windows:

```powershell
winget install --id GodotEngine.GodotEngine -e
```

## Como rodar o jogo

- Abra a pasta `game/` no editor do Godot e pressione **F5**; ou
- rode o executavel de console com `--path game`:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --path game
```

O winget instala o executavel em `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_<...>\` (ex.: `Godot_v4.7.2-stable_win64_console.exe`); use o caminho completo ou defina `$env:GODOT` com ele.

O jogo abre na tela de título (`res://world/game.tscn`). A batalha isolada do M1 continua disponivel: abra `game/battle/battle_scene.tscn` no editor e pressione **F6**, ou rode:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --path game --scene res://battle/battle_scene.tscn
```

## Como jogar

**Título.** Ao abrir o jogo, a tela de título tem **Novo jogo**, **Continuar** e **Sair**. Continuar abre a lista dos 3 slots e fica desabilitado se nenhum slot tiver um save válido. Um slot com dados corrompidos aparece como "Dados corrompidos" e não carrega. Qualquer flag `--demo-*` pula o título e começa em Novo jogo.

**Salvar.** O jogo tem 3 slots em disco (`user://save_1.json` a `save_3.json`). Só é possível salvar em dois lugares:

- no **mapa-mundi**, pelo comando **Salvar** do menu de campo (salva sem curar o grupo);
- num **ponto de descanso** (marcado nas áreas locais): ao apertar a tecla de interação dentro dele, o menu mostra **Descansar e salvar**, **Reiniciar atributos** e **Sair**. Descansar cura todo o grupo, inclusive a reserva, grava o ponto de descanso como spawn e depois pede o slot.

Fora desses dois lugares, o comando Salvar fica desabilitado.

**Game Over.** Na derrota, a tela de Game Over leva de volta ao título. O progresso desde o último save em disco se perde, por isso vale salvar em pontos de descanso com frequência.

**Cristal de Reinício.** Item-chave raro, usado só no ponto de descanso (opção **Reiniciar atributos**): devolve a alocação de pontos de um herói para os pontos a distribuir e gasta 1 cristal. Sem cristal, a opção fica desabilitada. O inventário inicial de teste já traz 1 cristal.

**Config.** No menu de campo, a página **Config** guarda opções que valem para todos os slots (não fazem parte do save). Esquerda e direita mudam o valor da linha; Enter avança um passo.

- **ATB**: **Espera** (padrão) pausa o tempo enquanto o menu de um herói está aberto. **Ativo** deixa o tempo correr com o menu aberto, como no FF7: inimigos e ações em andamento seguem; um comando confirmado enquanto outra ação executa fica guardado e começa quando ela termina. Se o alvo cair, a ação é redirecionada ao alvo válido do mesmo lado; se não houver nenhum, a ação se perde sem gastar AP.
- **Velocidade da batalha**: de 1 a 5, padrão 3 (×1,0). Os níveis são ×0,6, ×0,8, ×1,0, ×1,25 e ×1,5 e alteram só o ritmo do ATB, não as animações.
- **Memória do cursor**: quando ligada (padrão), o menu de comandos da batalha lembra o último comando de cada herói.
- **Velocidade do texto**: de 1 a 3, guardada para o sistema de diálogo: a fala aparece a 30, 60 ou 120 caracteres por segundo (valores de teste).
- **Volume**: de 0 a 10, padrão 10, aplicado ao áudio geral (ainda não há som no jogo).

## Controles

No mapa:

| Tecla | Acao |
|-------|------|
| Setas / WASD | Andar |
| Shift / X (segurar) | Correr; o grupo segue o líder em fila |
| Tab / Esc | Abrir o menu de campo (fora de batalha e de transicao) |
| Enter / Espaço / Z | Interagir (ex.: abrir o menu do ponto de descanso) |

Na caixa de diálogo (M10):

| Tecla | Acao |
|-------|------|
| Enter / Espaço / Z | Completar o texto ou avançar para a fala seguinte; confirmar a opção escolhida |
| Cima / Baixo | Escolher a opção (nas escolhas) |

No menu de campo (paginas Itens, Tecnicas, Equipar, Status, Atributos, Formacao, Salvar, Config e Fechar; o mapa fica congelado enquanto ele esta aberto):

| Tecla | Acao |
|-------|------|
| Setas | Navegar comandos, listas e herois do painel do grupo (esquerda/direita nos atributos) |
| Enter | Confirmar |
| Tab / Esc | Voltar um nivel (na raiz, fecha o menu) |

O quadrado azul do mapa mostra a inicial do lider (primeiro ativo de pe). A ordem da Formacao vale na proxima batalha (ativo 1 -> ponto 1, ...); a reserva nao luta nem recebe XP de combate.

**Equipar** (M4): escolha o heroi, depois um dos 4 espacos (Arma, Armadura, Capacete, Acessorio) e um item da mochila (ou **Remover**). Ao mover o cursor na lista de itens, a previa mostra os atributos efetivos, HP max. e AP max. antes -> depois (verde sobe, vermelho desce) e os passivos resultantes. O item antigo volta para a mochila; HP/AP atuais ficam limitados ao novo maximo. Armas tem tipo (Lamina, Bastao, Arco) e cada heroi usa um ou mais tipos; armaduras e capacetes podem ter lista de quem pode usar. Acessorios dao passivos: "Imune a X", "Resiste a X N%" e "Comeca com X" (aplicado no inicio de cada batalha). O **Status** mostra o equipamento e a conta "base + alocado [+ equip] = efetivo". Cada heroi de teste comeca com uma arma e uma armadura simples; a mochila inicial tem uma unidade de cada outro item de teste. O salvamento (e o Game Over) cobre equipamento e mochila.

Na batalha:

| Tecla | Acao |
|-------|------|
| Setas | Navegar menus, escolher alvos e as acoes da tela de resultado |
| Enter | Confirmar |
| Esc | Voltar um nivel de menu (na etapa de alvo, volta a lista de onde o comando veio) |
| F1 | Painel de debug (fila ATB, acao em execucao, estados, contribuicao) |
| Q (segurar) | Encher a barra de fuga (não funciona em encontros sem fuga, como o chefe de teste) |

## Fluxo da batalha

No mapa (M2): ao tocar um inimigo, a batalha roda sobre o mapa. Na vitoria, depois das telas de resultado/nivel, **Continuar** devolve o controle no mapa (o inimigo some ate a area ser reaberta). Na derrota, a tela de resultado ja e o **Game Over**; **Continuar** leva de volta ao titulo, e o progresso desde o ultimo save em disco se perde.

Na batalha isolada (M1, `--scene res://battle/battle_scene.tscn`):

- Vitoria: tela de resultado (XP por heroi) -> telas de alocacao de pontos para quem subiu de nivel -> escolha entre **Descansar e lutar** (padrao: HP/AP cheios e caidos revividos, depois nova batalha) e **Lutar de novo** (HP/AP como terminaram).
- Derrota: **Tentar de novo** (volta ao estado do inicio da batalha) ou **Descansar e tentar de novo** (volta ao inicio e enche HP/AP).
- Na batalha isolada, o descanso e um substituto provisorio do ponto de descanso (M6), que existe so nos mapas (spec, secao 12, item 15).
- A verificacao manual dos menus e das telas de resultado/nivel ainda depende do playtest do usuario; ate agora foram verificados por testes automatizados e por quadros gravados com `--write-movie`.

**Fuga (M7).** Segurando **Q** na batalha, enche-se uma barra de fuga em tempo real, inclusive com o menu aberto no modo Espera. Ela enche mais rápido quando a Velocidade média do grupo supera a dos inimigos; soltar a tecla a esvazia. A fuga só se conclui quando nenhuma ação está executando. Ao encher, a batalha termina sem XP: o grupo volta ao ponto de onde saiu, e o inimigo fica alguns segundos sem poder encostar.

**Iniciativa por contato (M7).** Quem toca primeiro define o começo da batalha. Encostar num inimigo pelas costas mostra **Ataque surpresa!** e os heróis começam com a barra ATB cheia. Ser tocado por um inimigo que estava perseguindo, ou um escondido, mostra **Emboscada!** e são os inimigos que começam com a barra cheia. Nos demais casos, a batalha começa como antes.

**Limite (M8).** Cada herói tem uma barra de Limite (estilo FF7). Ela enche com o dano que o herói sofre, proporcional ao HP máximo (veneno também conta); herói caído não enche, mas mantém a barra. A barra persiste entre as lutas e vai no save. Com a barra cheia, o comando **Limite** substitui **Atacar** no menu do herói e usa o golpe próprio dele, sem custo de AP; usar zera a barra. Se a ação for perdida por falta de alvo, a barra volta. A barra aparece sob o ATB de cada herói na batalha, no painel do grupo do menu de campo, e a página Status mostra a porcentagem. Inimigos não têm barra.

**Suporte (M8.5).** Com pelo menos 50% da barra de Limite, o comando **Suporte** (depois de Itens) chama um herói da reserva para uma ação dele: o ataque básico ou uma habilidade que gasta o AP do próprio reserva. Quem chama perde 50% de Limite. O reserva não entra no grupo, não vira alvo e não ganha XP; a contribuição da ação conta para quem chamou. O comando fica desabilitado se a barra estiver abaixo de 50% ou se a reserva estiver vazia ou caída.

**Técnicas (M9).** Cada herói tem uma lista fixa de técnicas, como em Chrono Trigger. Todo herói começa com a técnica de nível 1 e aprende as demais ao alcançar o nível indicado no seu learnset (entre os níveis 3 e 20, conforme o herói). Algumas técnicas não entram por nível: são liberadas só por evento, e o sistema de eventos do M10 vai ligá-las à história e à dungeon. Ao ganhar XP, quando um herói aprende uma técnica, a tela de resultado mostra "<Herói> aprendeu <Técnica>!" entre a XP e a tela de nível. A página Técnicas do menu de campo lista as técnicas aprendidas e mostra, em cinza, a próxima com o nível em que chega. Os learnsets de teste estão em [`game/data/test/README.md`](game/data/test/README.md).

**Diálogo (M10).** Interagir com um NPC ou uma placa (tecla de interação, a mesma do ponto de descanso) abre a caixa de diálogo, com o nome de quem fala e o texto, que aparece aos poucos. A tecla de interação completa o texto se ele ainda estiver aparecendo; com o texto completo, avança para a fala seguinte. Em uma escolha, cima e baixo mudam a opção e a tecla de interação confirma. Enquanto a caixa está aberta, o mapa fica congelado, o menu de campo não abre e a tecla não chega ao jogador. Alguns NPCs gravam flags de história conforme a escolha; uma escolha pode também dar técnicas ou XP narrativa.

**Objetos de dungeon (M10).** Todo estado desses objetos fica em flags, então eles continuam como foram deixados ao sair do mapa, ao salvar e ao carregar.

- **Baús**: interagir abre o baú e mostra "Encontrou X!". Depois de aberto, fica vazio e não se abre de novo.
- **Portas**: uma porta trancada mostra "Está trancada." Com a chave no inventário, ela abre e fica aberta. A chave (item-chave) não é gasta.
- **Interruptores e portões**: interagir com o interruptor liga ou desliga uma flag; o portão bloqueia a passagem enquanto a flag não estiver no valor de abertura.
- **Armadilhas**: ao pisar, a armadilha de dano tira 10% do HP máximo dos heróis ativos (valor de teste; nunca mata, o mínimo é 1), e a armadilha de batalha inicia um encontro. Nas armadilhas de uso único, depois de disparar elas não se repetem; enquanto estão armadas, piscam.
- **Gatilhos de cena**: uma área que roda um roteiro ao ser atravessada, uma única vez.

**Dungeon de teste (M10).** Entra-se nela pela zona **Dungeon de teste** no mapa-mundi, e a saída leva de volta ao mapa-mundi. Ela tem uma placa na entrada; um NPC guia que oferece ensinar a técnica `rajada` ao Teste A (a escolha "Sim" ensina a técnica e dá XP narrativa; depois, ele só repete a fala); dois baús (Poção e Chave de Teste); uma porta trancada pela chave; um interruptor que abre um portão; uma armadilha de dano e uma de batalha; e, na sala final, uma cena em que um NPC anda até um ponto, fala duas linhas e a câmera vai a outro ponto. Os textos são de teste.

**Inimigos de teste no mapa (M7)**, na área `area_teste`:

- **Vagante**: o inimigo de sempre, anda ao acaso.
- **Patrulheiro**: anda entre dois pontos fixos, em laço, parando um instante em cada um.
- **Perseguidor**: vagueia e, ao ver o jogador num cone de 70° (abertura total) a até 220 px, corre atrás dele. Desiste a 380 px e volta à base.
- **Escondido** (`lurking`): fica invisível e sem contato até o jogador chegar a 90 px; aparece e persegue. O contato com ele sempre conta como emboscada.
- **Dupla de grupo**: dois inimigos perto um do outro. Ao tocar um, o outro entra na mesma batalha.
- **Chefe de teste** (`chefe_teste`): não permite fuga e não reaparece depois de vencido, mesmo após salvar e carregar.

## Testes

Na raiz do repositorio, em PowerShell (usa GUT, sem interface):

```powershell
./run_tests.ps1                    # todos os testes
./run_tests.ps1 -Filter test_x     # apenas um arquivo de teste
```

Codigo de saida 0 significa que tudo passou. Se o Godot nao for encontrado, defina `$env:GODOT` com o caminho do executavel de console.

## Flags de debug

Passadas depois de `--` (argumentos de usuario), roteirizam entradas para verificacao visual. As flags de batalha exigem a cena isolada (`--scene`); o `--demo-local` exige a cena da area local:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --path game --scene res://battle/battle_scene.tscn -- --demo-menu     # roteiriza entradas no menu de comandos
& "<Godot_v4.x-stable_win64_console.exe>" --path game --scene res://battle/battle_scene.tscn -- --demo-debug    # abre o painel F1 com auto_battle
& "<Godot_v4.x-stable_win64_console.exe>" --path game --scene res://battle/battle_scene.tscn -- --demo-result   # auto_battle ate o fim; telas de resultado e nivel
& "<Godot_v4.x-stable_win64_console.exe>" --path game --scene res://world/local_map.tscn -- --demo-local   # area local sozinha: leva o jogador ate o inimigo (auto_battle)
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-m2   # jogo inteiro: ciclo do M2 sozinho (mapa-mundi -> area -> batalha -> saida -> mapa-mundi)
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-m3   # menu de campo (Pocao, Cura, Status, troca D<->E) e depois o ciclo do M2 com a nova formacao
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-m4   # Equipar no Teste A (Armadura Pesada com previa, Amuleto Anti-Sono), Status e depois o ciclo do M2
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-m6   # ponto de descanso: descansa, salva, reinicia os atributos com o Cristal e mostra a pagina Salvar
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-m7   # corre com o grupo em fila, toca um inimigo pelas costas (Ataque surpresa), foge segurando Q e depois toca o chefe ("Não dá para fugir!")
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-field-menu   # abre o menu de campo e percorre as paginas
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-m8   # herói sofre dano até encher a barra, usa Limite, enche de novo e chama o Suporte
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-m10  # dungeon de teste: lê a placa, fala com o guia (Sim), abre os baús e a porta, aciona o interruptor, pisa nas armadilhas e assiste à cena final
```

O `--demo-m2` roda no jogo principal (sem `--scene`) e leva cerca de 40 s de jogo. Ele anda com o jogador por pontos fixos dos mapas de teste, liga o `auto_battle`, deixa os inimigos do encontro com 2 de HP (so no demo) e aceita as telas de resultado e de nivel. Para gravar quadros:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --path game --write-movie <pasta>/f.png --fixed-fps 10 --quit-after 420 -- --demo-m2
```

O `--demo-m3` leva cerca de 50 s (use `--quit-after 950` com `--fixed-fps 10`). O `--demo-m4` leva cerca de 55 s (`--quit-after 600`). O `--demo-m6` pula o título e grava o save num diretório de demo, nunca nos slots reais.

## Fórmulas e balanceamento

As fórmulas do jogo foram escolhidas no M5 (ver [decisões do M5b](docs/superpowers/specs/2026-10-19-m5-formulas-design.md#decisões-do-m5b)). Os relatórios do simulador de batalhas ficam em [docs/balance/](docs/balance/):

- [Relatório final](docs/balance/2026-10-19-relatorio-final.md): padrão escolhido, com as metas de vitória e duração.
- [Relatório de opções](docs/balance/2026-10-19-relatorio-opcoes.md): as opções A/B/C de cada fórmula lado a lado (M5a).

Para gerar os relatórios de novo, na raiz do repositório:

```powershell
./run_sim.ps1                  # relatório de opções (cerca de 9 minutos com os padrões)
./run_sim.ps1 -Final -Runs 30  # relatório final
```

## Estrutura

- `docs/` - spec, plano e historico
  - `docs/superpowers/specs/2026-10-18-rpg-design.md` - [spec v4.0](docs/superpowers/specs/2026-10-18-rpg-design.md)
  - `docs/superpowers/plans/2026-10-18-m1-batalha-isolada.md` - [plano do M1](docs/superpowers/plans/2026-10-18-m1-batalha-isolada.md)
  - `docs/superpowers/plans/2026-10-18-m2-mapa.md` - [plano do M2](docs/superpowers/plans/2026-10-18-m2-mapa.md)
  - `docs/historico/` - guia de continuidade v3.7
- `game/core/` - regras de combate (sem nos, cenas ou Input; aleatoriedade via `Dice` injetado)
- `game/battle/` - apresentacao da batalha (cena, menus, painel de debug, telas de resultado)
- `game/world/` - jogo raiz (`game.tscn`: transicoes com fade e Game Over), mapa-mundi, area local, jogador, inimigos de mapa e zonas
- `game/data/test/` - dados de teste (herois, inimigos, habilidades, itens, estados, `balance.tres`)
- `game/tests/` - testes GUT

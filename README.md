# Prototipo de RPG com batalha ATB (Godot 4)

Prototipo de um RPG com combate em tempo real por barra de ATB, feito em Godot 4 com GDScript tipado e placeholders geometricos. Nao ha conteudo narrativo; personagens, inimigos e lugares sao genericos.

O marco atual e o M6: o jogo abre numa tela de título (Novo jogo / Continuar), de onde se chega a um mapa-mundi de teste com áreas locais e inimigos de mapa; tocar um inimigo inicia a batalha no próprio mapa. Há save em disco com 3 slots, gravado só em pontos de descanso e no mapa-mundi, e a página Config do menu de campo. Na derrota (Game Over), o jogo volta ao título e o progresso desde o último save em disco se perde.

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
- **Velocidade do texto**: de 1 a 3, guardada para o sistema de diálogo (ainda sem efeito).
- **Volume**: de 0 a 10, padrão 10, aplicado ao áudio geral (ainda não há som no jogo).

## Controles

No mapa:

| Tecla | Acao |
|-------|------|
| Setas / WASD | Andar |
| Tab / Esc | Abrir o menu de campo (fora de batalha e de transicao) |
| Enter / Espaço / Z | Interagir (ex.: abrir o menu do ponto de descanso) |

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

## Fluxo da batalha

No mapa (M2): ao tocar um inimigo, a batalha roda sobre o mapa. Na vitoria, depois das telas de resultado/nivel, **Continuar** devolve o controle no mapa (o inimigo some ate a area ser reaberta). Na derrota, a tela de resultado ja e o **Game Over**; **Continuar** leva de volta ao titulo, e o progresso desde o ultimo save em disco se perde.

Na batalha isolada (M1, `--scene res://battle/battle_scene.tscn`):

- Vitoria: tela de resultado (XP por heroi) -> telas de alocacao de pontos para quem subiu de nivel -> escolha entre **Descansar e lutar** (padrao: HP/AP cheios e caidos revividos, depois nova batalha) e **Lutar de novo** (HP/AP como terminaram).
- Derrota: **Tentar de novo** (volta ao estado do inicio da batalha) ou **Descansar e tentar de novo** (volta ao inicio e enche HP/AP).
- Na batalha isolada, o descanso e um substituto provisorio do ponto de descanso (M6), que existe so nos mapas (spec, secao 12, item 15).
- A verificacao manual dos menus e das telas de resultado/nivel ainda depende do playtest do usuario; ate agora foram verificados por testes automatizados e por quadros gravados com `--write-movie`.

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
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-field-menu   # abre o menu de campo e percorre as paginas
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

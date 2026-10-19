# Prototipo de RPG com batalha ATB (Godot 4)

Prototipo de um RPG com combate em tempo real por barra de ATB, feito em Godot 4 com GDScript tipado e placeholders geometricos. Nao ha conteudo narrativo; personagens, inimigos e lugares sao genericos.

O marco atual e o M2: o jogo abre num mapa-mundi de teste, de onde se entra numa area local com um inimigo de mapa; tocar o inimigo inicia a batalha no proprio mapa. Na derrota (Game Over), o grupo volta ao ultimo ponto de salvamento (inicio do mapa-mundi).

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

O jogo abre no mapa-mundi (`res://world/game.tscn`). A batalha isolada do M1 continua disponivel: abra `game/battle/battle_scene.tscn` no editor e pressione **F6**, ou rode:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --path game --scene res://battle/battle_scene.tscn
```

## Controles

No mapa:

| Tecla | Acao |
|-------|------|
| Setas / WASD | Andar |
| Tab / Esc | Abrir o menu de campo (fora de batalha e de transicao) |

No menu de campo (paginas Itens, Tecnicas, Equipar, Status, Atributos, Formacao e Fechar; o mapa fica congelado enquanto ele esta aberto):

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

No mapa (M2): ao tocar um inimigo, a batalha roda sobre o mapa. Na vitoria, depois das telas de resultado/nivel, **Continuar** devolve o controle no mapa (o inimigo some ate a area ser reaberta). Na derrota, a tela de resultado ja e o **Game Over**; **Continuar** restaura o ponto de salvamento (todo o estado dos herois: HP, AP, XP, nivel, pontos alocados e pendentes; e o inventario) e o jogo volta ao inicio do mapa-mundi.

Na batalha isolada (M1, `--scene res://battle/battle_scene.tscn`):

- Vitoria: tela de resultado (XP por heroi) -> telas de alocacao de pontos para quem subiu de nivel -> escolha entre **Descansar e lutar** (padrao: HP/AP cheios e caidos revividos, depois nova batalha) e **Lutar de novo** (HP/AP como terminaram).
- Derrota: **Tentar de novo** (volta ao estado do inicio da batalha) ou **Descansar e tentar de novo** (volta ao inicio e enche HP/AP).
- O descanso e um substituto provisorio do ponto de descanso, que ainda nao existe no M1 (spec, secao 12, item 15).
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
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-field-menu   # abre o menu de campo e percorre as paginas
```

O `--demo-m2` roda no jogo principal (sem `--scene`) e leva cerca de 40 s de jogo. Ele anda com o jogador por pontos fixos dos mapas de teste, liga o `auto_battle`, deixa os inimigos do encontro com 2 de HP (so no demo) e aceita as telas de resultado e de nivel. Para gravar quadros:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --path game --write-movie <pasta>/f.png --fixed-fps 10 --quit-after 420 -- --demo-m2
```

O `--demo-m3` leva cerca de 50 s (use `--quit-after 950` com `--fixed-fps 10`). O `--demo-m4` leva cerca de 55 s (`--quit-after 600`).

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

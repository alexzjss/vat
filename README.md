# Prototipo de batalha ATB (Godot 4)

Prototipo de um RPG com combate em tempo real por barra de ATB, feito em Godot 4 com GDScript tipado. O marco atual (M1) contem apenas uma batalha isolada, com placeholders geometricos: ATB com modo Wait, fila de prontos, pontos de Aura, itens, estados, areas de efeito, contribuicao e XP. Nao ha conteudo narrativo; personagens e inimigos sao genericos.

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

## Controles

| Tecla | Acao |
|-------|------|
| Setas | Navegar menus, escolher alvos e as acoes da tela de resultado |
| Enter | Confirmar |
| Esc | Voltar um nivel de menu (na etapa de alvo, volta a lista de onde o comando veio) |
| F1 | Painel de debug (fila ATB, acao em execucao, estados, contribuicao) |

## Fluxo da batalha

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

Passadas depois de `--` (argumentos de usuario), roteirizam entradas para verificacao visual:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-menu     # roteiriza entradas no menu de comandos
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-debug    # abre o painel F1 com auto_battle
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-result   # auto_battle ate o fim; telas de resultado e nivel
```

## Estrutura

- `docs/` - spec, plano e historico
  - `docs/superpowers/specs/2026-10-18-rpg-design.md` - [spec v4.0](docs/superpowers/specs/2026-10-18-rpg-design.md)
  - `docs/superpowers/plans/2026-10-18-m1-batalha-isolada.md` - [plano do M1](docs/superpowers/plans/2026-10-18-m1-batalha-isolada.md)
  - `docs/historico/` - guia de continuidade v3.7
- `game/core/` - regras de combate (sem nos, cenas ou Input; aleatoriedade via `Dice` injetado)
- `game/battle/` - apresentacao da batalha (cena, menus, painel de debug, telas de resultado)
- `game/data/test/` - dados de teste (herois, inimigos, habilidades, itens, estados, `balance.tres`)
- `game/tests/` - testes GUT

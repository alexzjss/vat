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
godot_console.exe --path game
```

## Controles

| Tecla | Acao |
|-------|------|
| Setas | Navegar menus e escolher alvos |
| Enter | Confirmar |
| Esc | Voltar/cancelar |
| F1 | Painel de debug (fila ATB, acao em execucao, estados, contribuicao) |

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
godot_console.exe --path game -- --demo-menu     # roteiriza entradas no menu de comandos
godot_console.exe --path game -- --demo-debug    # abre o painel F1 com auto_battle
godot_console.exe --path game -- --demo-result   # auto_battle ate o fim; telas de resultado e nivel
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

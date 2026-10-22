# Elementos (M13)

Esta pasta guarda os 9 elementos do jogo, um `.tres` por elemento, todos do tipo `ElementDef` (`game/core/defs/element_def.gd`). Os números de afinidade e as regras são valores de teste (`BalanceConfig`, comentados como "valor de teste").

Arquivos: `amaterasu.tres`, `atlas.tres`, `fuhaku.tres`, `indra.tres`, `kagutsuchi.tres`, `radioativo.tres`, `shukketsu.tres`, `susanoo.tres`, `tsukuyomi.tres`.

## Renomear um elemento ou mudar a cor

Abra o `.tres` no Inspector do Godot, ou edite o texto:

- `display_name`: o nome próprio, como "Kagutsuchi". Aparece nos dados e no painel de debug.
- `short_name`: o rótulo curto que a UI mostra, como "Fogo". Aparece na batalha e nos menus.
- `color`: a cor dos popups e do elemento nos menus.

**Não mude o `id` nem o nome do arquivo.** A UI carrega cada elemento pelo caminho `data/elements/<id>.tres`, e `element_resist` usa o `id` como chave. Se for criar um elemento novo, a tabela de afinidade da UI o põe depois dos 9 (ordem por id).

## `rule` e `reacts`

- `rule` escolhe a regra especial que o código aplica: `0` = normal (sem regra), `1` = `BLOOD` (Sangue, só o Shukketsu), `2` = `RADIOACTIVE` (só o Radioativo). Um elemento novo sem `rule` é um elemento comum. Uma regra nova exige código, não só dados.
- `reacts` (padrão `true`) diz se o elemento participa de reações. Só o Radioativo tem `reacts = false`. Reações são do M14, então hoje o campo não faz nada na batalha.

## Dar um elemento a habilidade, arma, herói, inimigo ou equipamento

| Onde | Campo | Regra |
|---|---|---|
| Habilidade (`AbilityDef`) | `element` | Um elemento. Vale para todo efeito de dano da habilidade. Vazio = neutro. |
| Arma (`EquipmentDef`) | `element` | Elemento do ataque básico, se a habilidade do básico não tiver o seu próprio. |
| Herói (`CharacterDef`) ou inimigo (`EnemyDef`) | `elements` | Até **2** nativos. Dão só o bônus de mesmo elemento (×1,2). Mais de 2 é erro de dados (`ElementMath.native_errors`). |
| Herói ou inimigo | `element_resist` | Afinidade base. |
| Equipamento (`EquipmentDef`) | `element_resist` | Afinidade somada à do herói que veste o item. |

Cura, reviver e estados não são elementais, mesmo que a habilidade tenha elemento.

## `element_resist`: exemplo

`element_resist` é um dicionário de `id do elemento` para número. O valor é a fração do dano:

- `0.3` = sofre 30% menos (resistência);
- `-0.5` = sofre 50% mais (fraqueza);
- `1.0` = imune (dano 0, rótulo "Imune");
- `1.5` = absorve 50%: o alvo se cura com a metade do dano, e não recebe dano (rótulo "Absorveu").

Um inimigo com:

```
element_resist = Dictionary[StringName, float]({
&"kagutsuchi": -0.5,
&"susanoo": 0.3,
&"amaterasu": 1.5,
&"indra": 1.0
})
```

Com um golpe de 20 de dano (já depois de defesa e variação), do elemento:

- Fogo (`-0.5`): 20 vira 30, rótulo "Fraco!";
- Água (`0.3`): 20 vira 14, rótulo "Resistiu";
- Luz (`1.5`): 0 de dano e cura de 10, rótulo "Absorveu";
- Raio (`1.0`): 0 de dano, rótulo "Imune".

Se um herói veste um equipamento com `element_resist = {&"shukketsu": 0.3}`, a afinidade total dele ao Sangue é a base mais 0,3. A soma é aplicada uma vez.

## Depois de mudar números da fatia

Mexeu em algo de `data/fatia/` (inclusive afinidades)? Rode o simulador da fatia na raiz do repositório:

```powershell
./run_sim.ps1 -Fatia
```

As metas do M12 (chefe em 15–20 s, comuns em 10–60 s) precisam continuar batendo. Os detalhes estão em [`game/data/fatia/README.md`](../fatia/README.md) e no [relatório dos elementos](../../../docs/balance/2026-10-22-relatorio-elementos.md).

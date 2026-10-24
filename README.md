# Prototipo de RPG com batalha ATB (Godot 4)

Prototipo de um RPG com combate em tempo real por barra de ATB, feito em Godot 4 com GDScript tipado e placeholders geometricos. Nao ha conteudo narrativo; personagens, inimigos e lugares sao genericos.

O marco atual é o M16, ferramentas de criação (seção [Criando conteúdo (M16)](#criando-conteúdo-m16)). Antes dele, o M15 trouxe estados, mundo e bestiário (seção [Estados, mundo e bestiário (M15)](#estados-mundo-e-bestiário-m15)), e o M14 trouxe as marcas e reações (seção [Marcas e reações (M14)](#marcas-e-reações-m14)) e o M13 os elementos (seção [Elementos (M13)](#elementos-m13)). Antes deles, o M12 entregou a fatia vertical: o **Novo jogo** agora percorre uma demo jogável de ponta a ponta (cidade, mapa-múndi, estrada com encontros, dungeon de dois andares, chefe e tela de fim), com moeda, loja, pousada paga e recrutamento. Tudo na fatia é placeholder; veja a seção [Fatia vertical](#fatia-vertical-m12).

Antes disso, o M11 acrescenta ao M10 o catálogo completo de estados (Pare, Confusão, buffs e debuffs, Silêncio, Cegueira, Regeneração e Barreira), os itens Remédio e Panaceia e um chefe de teste na dungeon de teste (fases por HP, ataque anunciado, contra-ataque e partes). Antes disso, o M10 acrescentou ao M9 o sistema de eventos (caixa de diálogo com nome e escolhas, flags de história, NPCs e placas, cenas roteirizadas e XP narrativa), os objetos de dungeon (baús, portas e chaves, interruptores e armadilhas) e uma dungeon de teste ligada ao mapa-mundi. Antes disso, o M9 acrescentou as técnicas por personagem, mantendo a barra de Limite (M8), o Suporte da reserva (M8.5), fuga, iniciativa por contato, corrida e inimigos com comportamento no mapa: o jogo abre numa tela de título (Novo jogo / Continuar), de onde se chega a um mapa-mundi de teste com áreas locais e inimigos de mapa; tocar um inimigo inicia a batalha no próprio mapa. Há save em disco com 3 slots, gravado só em pontos de descanso e no mapa-mundi, e a página Config do menu de campo. Na derrota (Game Over), o jogo volta ao título e o progresso desde o último save em disco se perde.

A batalha do M1 continua disponivel como cena isolada: ATB com modo Wait, fila de prontos, pontos de Aura, itens, estados, areas de efeito, contribuicao e XP.

**Os numeros em `game/data/test` e em `game/data/fatia` sao valores de teste, nao canonicos** (spec v4.0, secao 8). Os nomes e textos da fatia tambem sao placeholder; veja [`game/data/fatia/README.md`](game/data/fatia/README.md).

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

O jogo abre na tela de título (cena principal `res://world/game_fatia.tscn`). A batalha isolada do M1 continua disponivel: abra `game/battle/battle_scene.tscn` no editor e pressione **F6**, ou rode:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --path game --scene res://battle/battle_scene.tscn
```

## Como jogar

**Título.** Ao abrir o jogo, a tela de título tem **Novo jogo**, **Continuar** e **Sair**. Continuar abre a lista dos 3 slots e fica desabilitado se nenhum slot tiver um save válido. Um slot com dados corrompidos aparece como "Dados corrompidos" e não carrega. Qualquer flag `--demo-*` pula o título e começa em Novo jogo, exceto `--demo-fatia`, que passa pelo título como um jogador faria.

**Salvar.** O jogo tem 3 slots em disco (`user://save_1.json` a `save_3.json`). Só é possível salvar em três lugares:

- no **mapa-mundi**, pelo comando **Salvar** do menu de campo (salva sem curar o grupo);
- num **ponto de descanso** (marcado nas áreas locais): ao apertar a tecla de interação dentro dele, o menu mostra **Descansar e salvar**, **Reiniciar atributos** e **Sair**. Descansar cura todo o grupo, inclusive a reserva, grava o ponto de descanso como spawn e depois pede o slot.
- na **pousada** da cidade (fatia): o descanso pago cura o grupo e depois pede o slot.

Fora desses lugares, o comando Salvar fica desabilitado.

**Game Over.** Na derrota, a tela de Game Over leva de volta ao título. O progresso desde o último save em disco se perde, por isso vale salvar em pontos de descanso com frequência.

**Cristal de Reinício.** Item-chave raro, usado só no ponto de descanso (opção **Reiniciar atributos**): devolve a alocação de pontos de um herói para os pontos a distribuir e gasta 1 cristal. Sem cristal, a opção fica desabilitada. O inventário inicial de teste já traz 1 cristal.

**Config.** No menu de campo, a página **Config** guarda opções que valem para todos os slots (não fazem parte do save). Esquerda e direita mudam o valor da linha; Enter avança um passo.

- **ATB**: **Espera** (padrão) pausa o tempo enquanto o menu de um herói está aberto. **Ativo** deixa o tempo correr com o menu aberto, como no FF7: inimigos e ações em andamento seguem; um comando confirmado enquanto outra ação executa fica guardado e começa quando ela termina. Se o alvo cair, a ação é redirecionada ao alvo válido do mesmo lado; se não houver nenhum, a ação se perde sem gastar AP.
- **Velocidade da batalha**: de 1 a 5, padrão 3 (×1,0). Os níveis são ×0,6, ×0,8, ×1,0, ×1,25 e ×1,5 e alteram só o ritmo do ATB, não as animações.
- **Memória do cursor**: quando ligada (padrão), o menu de comandos da batalha lembra o último comando de cada herói.
- **Velocidade do texto**: de 1 a 3, guardada para o sistema de diálogo: a fala aparece a 30, 60 ou 120 caracteres por segundo (valores de teste).
- **Volume**: de 0 a 10, padrão 10, aplicado ao áudio geral (ainda não há som no jogo).

## Fatia vertical (M12)

O **Novo jogo** abre a fatia vertical, na cena principal `game/world/game_fatia.tscn`. O percurso é: título → **cidade** → mapa-múndi → **estrada**, com encontros no caminho → **dungeon** (andares 1 e 2) → **chefe** → tela **Fim da demo** → título. O save funciona no percurso todo, como nos outros marcos.

Tudo na fatia é placeholder: nomes são "Teste", "Morador A" etc., e os textos são de teste. Os dados ficam em [`game/data/fatia/`](game/data/fatia/README.md), onde está também a lista do que trocar.

- **Moedas.** Cada inimigo derrotado dá Moedas (nome de teste, `BalanceConfig.currency_name`) e pode deixar um item ou equipamento. A tela de resultado mostra "+N Moedas" e "Obteve X!". Fugir não dá nada.
- **Loja.** Na cidade, a loja tem **Comprar** e **Vender**. Comprar tem estoque infinito e respeita o limite de pilha de 99. Vender rende metade do preço (valor de teste). Item-chave e equipamento vestido não se vendem.
- **Pousada.** Descanso pago (20 Moedas, valor de teste): cura o grupo e depois pede o slot de save. Os pontos de descanso das dungeons continuam grátis.
- **Recrutamento.** Dois heróis entram no grupo durante a fatia: o recruta D na cidade e o recruta E no andar 1. Se o grupo ativo (4 heróis) estiver cheio, o recruta vai para a reserva. Quem chega ao grupo entra no nível médio dos ativos, arredondado para baixo. Recrutar o mesmo herói de novo não tem efeito.

O relatório de balanceamento da fatia está em [`docs/balance/2026-10-20-relatorio-fatia.md`](docs/balance/2026-10-20-relatorio-fatia.md).

## Elementos (M13)

Habilidades, armas, heróis, inimigos e equipamentos podem ter elemento. São 9 elementos, um `.tres` cada em [`game/data/elements/`](game/data/elements/README.md). Os nomes são os do usuário; o nome curto é o que a UI mostra. O elemento radioativo ainda não tem nome próprio e aparece como "Radioativo".

| Nome | Nome curto | Regra |
|---|---|---|
| Kagutsuchi | Fogo | normal |
| Susanoo | Água | normal |
| Fuhaku | Vento | normal |
| Atlas | Terra | normal |
| Indra | Raio | normal |
| Tsukuyomi | Trevas | normal |
| Amaterasu | Luz | normal |
| Shukketsu | Sangue | Sangue |
| Radioativo | Radioativo | Radioativo |

**Onde entra:**
- **Habilidade:** um elemento (`AbilityDef.element`). Vale para todo efeito de dano da habilidade; cura, reviver e estados não são elementais.
- **Ataque básico:** o elemento da arma equipada (`EquipmentDef.element`). Habilidade com elemento próprio ignora a arma.
- **Heróis e inimigos:** até dois elementos nativos (`elements`). Eles dão só o bônus de mesmo elemento.
- **Equipamento:** afinidade defensiva (`element_resist`), somada à do herói.

**Fórmula:** o dano depois de defesa e variação é multiplicado por 1,2 se o elemento é nativo do atacante, depois pelo bônus de Sangue (só Shukketsu), e por fim por `1 − afinidade total`. A afinidade total é a base mais os equipamentos vestidos, aplicada uma vez. O dano mínimo é 1, exceto em Imune (0). 100% é imunidade; acima de 100% o alvo absorve, e a cura é `dano × (total − 1)`. Radioativo não usa afinidade.

**Sangue (Shukketsu):**
- Rouba 25% do dano efetivo como HP do atacante, até o máximo. Não rouba quando o golpe causa 0 de dano (imune ou absorvido), e não conta como contribuição de cura.
- Causa mais dano com HP baixo: até +50% com HP perto de zero.
- O Sangramento (estado `bleed`, 5% do HP máximo por ação, 4 turnos) é aplicado só pelas habilidades que o colocam. Ele cobra quando o afetado age e deixa no mínimo 1 HP.

**Radioativo:**
- Ignora afinidade (fraqueza, resistência, imunidade e absorção); o bônus de mesmo elemento continua valendo. Não reage com outros elementos (reações são do M14).
- Cada golpe que causa dano soma 1 de contaminação no alvo. Em 3, estoura: 15% do HP máximo do alvo como dano extra, e zera. O alvo perde 1 a cada 2 ações.
- Cada nível de contaminação corrói 10% da Vitalidade efetiva do alvo. O atacante perde 10% do dano efetivo, sem cair (mínimo 1 HP).

Os valores estão em `BalanceConfig` e são valores de teste. O relatório do M13 está em [`docs/balance/2026-10-22-relatorio-elementos.md`](docs/balance/2026-10-22-relatorio-elementos.md).

**Textos na batalha:** além do número, aparecem "Fraco!", "Resistiu", "Imune" e "Absorveu" (este com o número em verde), na cor do elemento. Neutro não mostra rótulo. Quando o Radioativo estoura, aparece "Contaminação! -N". Nos menus, o nome curto do elemento aparece no comando de batalha, nas Técnicas, em Equipar (com a prévia de resistência) e em Status (nativos e tabela de afinidade). Itens ainda não têm elemento.

## Marcas e reações (M14)

Todo golpe com elemento que reage deixa uma **marca** no alvo. Um elemento diferente sobre a marca dispara uma **reação**, uma das 28 da matriz (a ordem dos elementos não importa). O Radioativo não reage e não deixa marca. Todos os números são valores de teste.

**Marcas.**
- Um golpe marca quando tem elemento que reage e chega ao alvo. Esquiva, erro, imunidade e absorção não marcam. Barreira que absorve todo o dano ainda marca, porque o golpe acertou.
- A marca dura `mark_turns` (3) turnos ATB do alvo, contados como os estados. Um golpe do mesmo elemento só renova a marca para 3, sem reação.
- Cada alvo tem no máximo uma marca. Em habilidade com vários efeitos de dano, só o primeiro que acerta marca ou reage. Em área, cada alvo é tratado à parte.
- A marca some quando o alvo cai, no fim da batalha e quando uma reação a consome. Ela não entra no save.
- Heróis também recebem marcas e sofrem reações dos inimigos.

**Reações.** A reação é aplicada depois do dano normal do golpe, que já passou por afinidade, escudo e barreira. Nesta ordem:
1. **Dano extra** (`bonus_pct`, fração do dano final do golpe). Não passa de novo pela afinidade e não marca.
2. **Área** (`area_pct` nos outros aliados do alvo dentro de `area_radius`). O dano é neutro, sem marca e sem reação: não há cadeia.
3. **Estados** no alvo e na área, com a chance da reação.
4. **ATB** do alvo e do atacante.
5. **Estados no atacante**, sem sorteio.
6. **Cura** do atacante e do grupo dele.
7. **Remoção de estados** do alvo (a Fragmentar, por exemplo, quebra a Barreira).
8. **Consumo**: a marca fica como `keep` (o elemento que sobra) ou some.

Não há reação se o alvo cai com o golpe, nem se o golpe não marcaria. O dano extra e o da área contam como dano do atacante. A reação não dá XP à parte.

**Inimigos buscam combos.** Uma regra de IA com a condição `CAN_REACT` só vale se algum alvo vivo tem uma marca que reage com o elemento da habilidade. O alvo `REACTION_TARGET` é o alvo com essa marca. As regras antigas não mudam.

**Na batalha.** Um círculo pequeno ao lado do combatente mostra a marca: a inicial do elemento e os turnos que faltam. O popup do golpe mostra o nome da reação; o dano extra, a cura e os estados aparecem como os outros popups. O painel de debug (F1) mostra a última reação e o cálculo do dano extra.

**Matriz e dados.** A matriz das 28 reações, aprovada pelo usuário, está no [plano do M14](.claude/plans/2026-10-22-m14-marcas-reacoes.md#matriz-das-28-reações-aprovada-pelo-usuário-em-2026-10-22). Cada reação é um `.tres` em [`game/data/reactions/`](game/data/reactions/README.md), que explica como editar. O relatório de balanceamento está em [`docs/balance/2026-10-22-relatorio-reacoes.md`](docs/balance/2026-10-22-relatorio-reacoes.md).

**Demo.** O `--demo-fatia` usa `--quit-after 7500` desde o M15 (antes era 6000). Com a rota atual, o último quadro fica entre 4113 e 4332 (sementes 1 a 5 e padrão), então 7500 tem folga.

## Estados, mundo e bestiário (M15)

Os estados novos, a resistência a estados, o veneno no mapa, os puzzles, o terreno e o bestiário são o M15. Todo número é valor de teste. O relatório de balanceamento está em [`docs/balance/2026-10-22-relatorio-estados.md`](docs/balance/2026-10-22-relatorio-estados.md).

**Estados novos** (`game/data/test/statuses/`; a abreviação é a do HUD):

| Estado | HUD | Regra |
|---|---|---|
| Queimadura | QUEI | Dano de 6% do HP máximo a cada ATB cheio do afetado, pode derrubar. Força −20% enquanto dura (3 turnos). Num alvo Molhado não entra, e o Molhado sai. |
| Congelado | GELO | Para o ATB, como o Pare, por 5 s de batalha. O primeiro golpe de Força que o alvo recebe quebra o gelo, com +50% naquele golpe. Golpe de Fogo derrete o gelo sem bônus e seca o Molhado. Dano de Aura não quebra. |
| Molhado | MOLH | Sem dano, 3 turnos. Soma 30% de fraqueza a Raio (`wet_indra_bonus`). Impede Queimadura. |
| Petrificação | PEDRA | Põe uma contagem de 8 s; ao zerar, o alvo petrifica: fora da luta, sem ação, sem dano e sem estados. Conta como derrotado. Herói petrificado volta com o HP que tinha. |
| Contagem | DOOM | Contagem de 15 s; ao zerar, derruba o alvo. Pode ser removida. Guardião e Braços são imunes. |
| Provocar | PROV | 3 turnos. Enquanto o provocador estiver vivo, o alvo único escolhido pela IA inimiga é ele, e as áreas centram nele. Confusão ignora. |
| Berserk | BERS | 3 turnos. Força +50%. Age sozinho: ataque básico num inimigo vivo sorteado, sem menu, sem habilidade e sem item. |
| Reflexo | REFL | 3 turnos. Habilidade com elemento (não o básico) que mira o refletido volta para quem lançou, com os efeitos dela. Um golpe refletido não reflete de novo. |

**Resistência a estados.**
- **Heróis:** `status_resist` do personagem, somado às passivas RESIST dos equipamentos vestidos. O total fica em no máximo 100%. Passiva IMMUNE ou total ≥ 100% = imune. Negativo = vulnerável.
- **Inimigos:** `resistances` (a mesma soma) e `immunities`.
- A chance de aplicar é `chance × (1 − resistência)`.

**Veneno no mapa.** O Veneno tem `persists`: no fim da batalha, o Veneno ativo num herói vivo fica com ele, sem duração, e volta a valer no começo da batalha seguinte.
- A cada 320 px andados, cada herói envenenado perde 5% do HP máximo, no mínimo 1. Ele nunca cai: o HP para em 1. A reserva não anda e não perde.
- Cura: item de campo com `REMOVE_STATUS` (o Remédio da fatia; a Panaceia nos dados de teste), técnica de cura de estado e descanso (pousada e ponto de descanso).
- O painel do grupo mostra "VEN" no herói.

**Puzzles elementais.** Um `ElementalObstacle` (obstáculo de um elemento) abre a escolha dos heróis do grupo que sabem uma técnica daquele elemento. A escolha gasta o AP da técnica (a mais barata do elemento); sem AP, ela fica desativada. Depois de aberto, o obstáculo some e grava a flag. Sem ninguém capaz, mostra o texto de bloqueio. Os três da fatia são Vinhas (andar 1, Fogo), Comporta (andar 2, Água) e Mecanismo (andar 2, Raio). Como criar um, está no [README da fatia](game/data/fatia/README.md#puzzles-elementais-elementalobstacle).

**Terreno.** Um `TerrainDef` (terreno ou clima) multiplica o dano elemental dos dois lados, depois da afinidade e antes do escudo do núcleo. Elemento fora da tabela vale 1,0. Chuva fica na estrada (Água 1,2, Fogo 0,8), e Calor no andar 2 (Fogo 1,2, Água 0,8). O nome do terreno aparece no canto da batalha. Como criar um, está no [README da fatia](game/data/fatia/README.md#terreno-terraindef).

**Bestiário e Scan.**
- Um inimigo fica "visto" ao entrar numa batalha, e conta as derrotas. Afinidades, fraquezas e resistências a estados aparecem depois de um Scan ou de `bestiary_reveal_kills` (3) derrotas.
- **Scan:** a técnica Escanear (Teste C, 2 AP, sem dano) e o item Lente (20 na loja). O popup mostra fraquezas, resistências e absorções.
- **Página Bestiário:** lista os inimigos vistos (os não vistos aparecem como "???"), com nome, nível, HP máximo e derrotas.
- **Página Reações:** lista as reações já disparadas. As não vistas aparecem como "???", e a vista mostra o par de elementos e um resumo dos efeitos.

**Menu de campo, na ordem:** Itens, Técnicas, Equipar, Status, Bestiário, Reações, Atributos, Formação, Salvar, Config e Fechar.

## Criando conteúdo (M16)

Dá para criar conteúdo sem código: diálogos e escolhas num arquivo `.roteiro` (exemplos em `game/data/fatia/roteiro/`), itens, inimigos e encontros pela aba **VAT** do editor do Godot, arte de personagem (mapa, batalha e retratos) e mapas pintados com tiles 32×32. A mesma aba valida o conteúdo e testa um mapa ou encontro numa janela à parte.

- Guia passo a passo: [`docs/guia-criacao.md`](docs/guia-criacao.md).
- Sintaxe completa do roteiro: [`docs/roteiro.md`](docs/roteiro.md).
- Checagem sem janela: `godot --headless --path game -s tools/validate/check_all.gd`.

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

**Estados de batalha (M11).** Valores de teste, em `game/data/test/statuses/`. Na batalha, a HUD mostra a abreviação dos estados sob o nome de cada combatente; buffs e debuffs mostram o atributo e o sinal (FOR+, VEL-...).

| Estado | Abreviação | Regra |
|--------|------------|-------|
| Pare | PARE | O ATB não enche e o afetado não age. Esquiva 0 e não sai com dano. Dura 4 segundos de batalha (não conta turnos). Quem estava na fila sai dela e volta quando o Pare acaba; a sessão aberta de um herói é cancelada, e uma ação enfileirada no modo Ativo é reembolsada. |
| Confusão | CNF | Quando o afetado age, a ação vira um ataque básico num alvo sorteado entre os combatentes vivos (menos ele mesmo). Herói confuso não abre menu; inimigo confuso ignora a IA. Sai com dano de HP. Dura 3 turnos. |
| Força+ / Força- | FOR+ / FOR- | Buff e debuff de Força: soma ±4 à Força (valor de teste). Estados do mesmo atributo se somam, e o atributo efetivo não cai abaixo de 1. Dura 3 turnos. |
| Vitalidade+ / Vitalidade- | VIT+ / VIT- | Buff e debuff de Vitalidade: soma ±4 à Vitalidade (valor de teste), com as mesmas regras de soma e mínimo. Dura 3 turnos. |
| Velocidade+ / Velocidade- | VEL+ / VEL- | Buff e debuff de Velocidade: soma ±4 à Velocidade (valor de teste), com as mesmas regras de soma e mínimo. Dura 3 turnos. |
| Silêncio | SIL | O afetado não usa Habilidades (técnicas): o comando fica desabilitado no menu de batalha, e a IA inimiga cai no ataque básico. Ataque básico, Limite e itens continuam liberados. Dura 3 turnos. |
| Cegueira | CEG | Os golpes de dano que escalam com Força do afetado erram com 50% extra de chance (valor de teste), sorteada antes da esquiva; a batalha mostra "Errou". Dura 3 turnos. |
| Regeneração | REG | Cura 5% do HP máximo (mínimo 1, valor de teste) a cada ATB cheio, depois do Veneno. Não revive. Dura 4 turnos. |
| Barreira | BAR | Absorve dano até a potência (20, valor de teste). Já existia; entrou agora no catálogo e nos testes de interface. |

**Remédio e Panaceia (M11).** Itens que funcionam só na batalha, pelo comando **Item**; não estão no inventário inicial do jogo.

- **Remédio**: remove Confusão, Silêncio e Cegueira de um aliado.
- **Panaceia**: remove todos os estados negativos de um aliado (Veneno, Sono, Paralisia, Lentidão, Pare, Confusão, Silêncio, Cegueira e os debuffs).

**Chefe de teste da dungeon (M11).** Aparece na dungeon de teste depois da cena final, no ponto do chefe, e é formado pelo **Guardião (teste)**, núcleo, e por dois **Braços (teste)**, partes. Os números são valores de teste.

- **Fases por HP**: acima de 66% do HP, o chefe usa só os ataques normais. Abaixo de 66%, entra a "Fase 2 (teste)", com Silêncio, Cegueira ou Confusão num herói (cada uma com 35% de chance) e a chance de reerguer um Braço caído (70%). Abaixo de 33%, entra a "Fase 3 (teste)", com Pare num herói (35%) e o Golpe Sísmico. A troca de fase mostra um banner.
- **Ataque anunciado**: o Golpe Sísmico (atinge todos os heróis, dano alto) é anunciado com "Guardião (teste) prepara Golpe Sísmico!". O chefe gasta o turno preparando e a ação sai no próximo ATB cheio, com o alvo revalidado. O AP é gasto na execução. Pare, Sono ou Paralisia só adiam a ação, e a morte do chefe a cancela.
- **Contra-ataque**: quando um herói causa dano de HP ao Guardião com o ataque básico, o Guardião contra-ataque com 50% de chance. A ação sai logo depois da do herói, sem gastar AP e sem zerar o ATB. Não dispara se o Guardião estiver caído, parado, dormindo, paralisado ou preparando, e um contra-ataque não gera outro.
- **Núcleo e Braços**: vencer é derrotar o Guardião, e os Braços caem junto. Enquanto algum Braço estiver de pé, o Guardião aparece como **Protegido** no HUD e recebe 25% do dano (valor de teste). Um Braço caído pode voltar pela regra de reerguer da fase 2. Os Braços que caem junto com o núcleo também dão XP, pela contribuição dele.
- **Sem fuga e sem volta**: o encontro não permite fuga, e o chefe não reaparece depois de derrotado, mesmo após salvar e carregar.

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
& "<Godot_v4.x-stable_win64_console.exe>" --path game -- --demo-m11  # chefe de teste da dungeon: começa direto na batalha, com o grupo forte e auto_battle; mostra a troca de fase, o anúncio, o contra-ataque, a parte revivida e os estados no HUD (--seed=N troca a semente)
& "<Godot_v4.x-stable_win64_console.exe>" --headless --path game --fixed-fps 60 --quit-after 7500 -- --demo-fatia   # fatia inteira, do título à tela de fim (--seed=N e --speed=1 aceitos)
```

O `--demo-fatia` (M12) percorre a fatia inteira sozinho, do título à tela de fim: cidade, loja, recrutas, pousada com save e load, estrada, dungeon de dois andares, chefe e título. Ele roda na cena principal (`game_fatia.tscn`) com o perfil da fatia; os saves vão para `user://demo_saves/`, nunca para os slots reais.

Sucesso é a última linha do log, `roteiro concluído: 12 lutas`. O `--quit-after` também sai com código 0, então o código de saída sozinho não basta para dizer que a demo passou. Quando uma etapa não bate, a demo sai com código 1 e imprime `FALHA: ...` com a etapa que falhou.

No fim, a demo imprime a folga do limite: `folga: quadro N de 7500 (sobram M)`. Hoje o último quadro fica entre 4113 e 4332, com folga de 3168 a 3387 quadros. O limite padrão, sem `--quit-after`, é o `FRAME_LIMIT` de `game/world/demo_fatia.gd`.

Não rode sementes da demo em paralelo. Todas gravam em `user://demo_saves/`, o mesmo diretório, e uma execução pode ler o save da outra.

As demais flags `--demo-*` continuam usando o perfil de teste (`game/data/test/start_teste.tres`), como antes. Só o `--demo-fatia` usa o perfil da fatia.

O `--demo-m2` roda no jogo principal (sem `--scene`) e leva cerca de 40 s de jogo. Ele anda com o jogador por pontos fixos dos mapas de teste, liga o `auto_battle`, deixa os inimigos do encontro com 2 de HP (so no demo) e aceita as telas de resultado e de nivel. Para gravar quadros:

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --path game --write-movie <pasta>/f.png --fixed-fps 10 --quit-after 420 -- --demo-m2
```

O `--demo-m3` leva cerca de 50 s (use `--quit-after 950` com `--fixed-fps 10`). O `--demo-m4` leva cerca de 55 s (`--quit-after 600`). O `--demo-m6` pula o título e grava o save num diretório de demo, nunca nos slots reais.

## Fórmulas e balanceamento

As fórmulas do jogo foram escolhidas no M5 (ver [decisões do M5b](.claude/specs/2026-10-19-m5-formulas-design.md#decisões-do-m5b)). Os relatórios do simulador de batalhas ficam em [docs/balance/](docs/balance/):

- [Relatório final](docs/balance/2026-10-19-relatorio-final.md): padrão escolhido, com as metas de vitória e duração.
- [Relatório de opções](docs/balance/2026-10-19-relatorio-opcoes.md): as opções A/B/C de cada fórmula lado a lado (M5a).
- [Relatório da fatia](docs/balance/2026-10-20-relatorio-fatia.md): ritmo de XP, moeda e metas do chefe da fatia vertical (M12).
- [Relatório dos elementos](docs/balance/2026-10-22-relatorio-elementos.md): cenário elemental smart × basic e os ajustes de Vitalidade da fatia (M13).

Para gerar os relatórios de novo, na raiz do repositório:

```powershell
./run_sim.ps1                  # relatório de opções (cerca de 9 minutos com os padrões)
./run_sim.ps1 -Final -Runs 30  # relatório final
./run_sim.ps1 -Fatia -Runs 60  # relatório da fatia vertical (M12)
```

## Estrutura

- `docs/` - spec, plano e historico
  - `.claude/specs/2026-10-18-rpg-design.md` - [spec v4.0](.claude/specs/2026-10-18-rpg-design.md)
  - `.claude/plans/2026-10-18-m1-batalha-isolada.md` - [plano do M1](.claude/plans/2026-10-18-m1-batalha-isolada.md)
  - `.claude/plans/2026-10-18-m2-mapa.md` - [plano do M2](.claude/plans/2026-10-18-m2-mapa.md)
  - `docs/historico/` - guia de continuidade v3.7
- `game/core/` - regras de combate (sem nos, cenas ou Input; aleatoriedade via `Dice` injetado)
- `game/battle/` - apresentacao da batalha (cena, menus, painel de debug, telas de resultado)
- `game/world/` - jogo raiz (`game.tscn`: transicoes com fade e Game Over), mapa-mundi, area local, jogador, inimigos de mapa e zonas
- `game/data/test/` - dados de teste (herois, inimigos, habilidades, itens, estados, `balance.tres`, `start_teste.tres`)
- `game/data/fatia/` - dados da fatia vertical, placeholders ([README](game/data/fatia/README.md))
- `game/tests/` - testes GUT

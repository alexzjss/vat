# Guia de criação de conteúdo (M17)

Passo a passo para criar conteúdo pela interface do editor do Godot, sem escrever código: eventos num editor de blocos, mapas novos com um assistente, objetos colocados numa paleta, formulários para heróis, inimigos, encontros, lojas, itens e arte. O texto `.roteiro` continua valendo como alternativa avançada (veja a seção dedicada, antes dos limites). A sintaxe do roteiro está em [`roteiro.md`](roteiro.md).

Abra o projeto no Godot 4 (pasta `game/`). O plugin VAT já vem ativado. Na barra superior do editor aparece a aba **VAT**, com as abas **Banco**, **Roteiros** (sub-abas **Lista**, **Editor** e **Simular**), **Mapas**, **Mundo**, **Validar** e **Testar**.

## (a) Escrever um evento no editor de blocos

1. Aba **VAT > Roteiros > Lista**: escolha um arquivo `.roteiro` ou crie um com **Novo arquivo** (ele fica em `data/fatia/roteiro/`).
2. Vá para **Editor**. À esquerda estão os arquivos e os eventos do arquivo aberto. Use **Novo evento** para criar um evento; **Renomear** e **Apagar evento** agem sobre o evento escolhido.
3. No centro, cada bloco do evento é um cartão. Para acrescentar, use **+ Adicionar bloco**, que abre um menu por categoria:
   - **Texto:** Fala, Sistema, Comentário;
   - **Fluxo:** Escolha, Rótulo, Ir para;
   - **Condições:** Se flag, Se item, Se dinheiro;
   - **Flags:** Definir flag, Somar à flag, Declarar flag;
   - **Itens e dinheiro:** Dar item, Dar equipamento, Dar moedas, Tirar item;
   - **Grupo:** XP, Ensinar técnica, Curar, Recrutar;
   - **Ações:** Batalha, Mover, Câmera, Esperar, Fim da demo.
4. Preencha os campos de cada cartão. Os campos de texto (**Falante**, **Expressão**, **Flag** e **Rótulo**) oferecem sugestões vindas do projeto, e você também pode digitar um valor novo:
   - **Falante**: os heróis e os falantes (`SpeakerDef`); **Expressão**: as expressões do falante escolhido;
   - **Flag**: as flags declaradas e as usadas no projeto;
   - **Rótulo** e **Então ir para**: os rótulos do evento (e `fim`);
   - **Item**, **Equipamento**, **Herói**, **Técnica** e **Encontro** são listas de recursos do projeto, com a opção "(nenhum)".
5. **Escolha**: em **Opções**, use **+ Opção** para cada resposta e escolha o rótulo de destino de cada uma. A pergunta mantém o falante.
6. Em cada cartão, as setas **▲** e **▼** (Subir e Descer) reordenam os blocos; **Duplicar** copia o bloco logo abaixo; **Apagar** remove o bloco. Não há arrastar (veja os limites).
7. No rodapé, o resumo mostra **N erro(s), M aviso(s)**, com a mensagem do compilador. Clicar num item da lista destaca o bloco com o problema.
8. **Salvar** grava o `.roteiro` e o reimporta. Enquanto houver alterações, aparece **● não salvo**. Ao trocar de arquivo ou evento com alterações, o painel pergunta: **Salvar**, **Cancelar** ou **Não salvar**.
9. **Ver texto** mostra o texto gerado, só para leitura, com o botão **Copiar**.

**Simular o evento:** aba **Roteiros > Simular**.
- Escolha o arquivo e o evento.
- **+ Flag** e **+ Item** definem o estado de partida; **Moedas de partida** define o dinheiro; o campo **Respostas das escolhas** aceita `auto` ou uma lista como `0, 1, 0`.
- **Rodar** executa o evento com o motor real do jogo, num processo à parte. O resultado mostra as falas, as escolhas, os itens dados, as flags no fim e se a batalha começaria ali.
- Se o roteiro tiver erros, a simulação não roda: corrija no Editor antes.

## (b) Criar um mapa novo

1. Aba **VAT > Mapas**, botão **Novo mapa…**.
2. Preencha:
   - **Id** (letras minúsculas, números e `_`, começando por letra; um id repetido é recusado);
   - **Nome** (opcional; se vazio, vem do id);
   - **Tipo**: Cidade, Interior, Masmorra ou Mapa-múndi;
   - **Largura** e **Altura** em tiles (o assistente recusa tamanhos fora de 40 × 23 até 160 × 100 tiles);
   - **Tile base**: o piso que preenche o mapa (Chão, Caminho, Grama, Piso interno, Piso da pousada, Masmorra A, B ou C).
3. **Criar** monta o mapa. Os erros aparecem no próprio diálogo, e o botão só fica ligado quando o plano é válido.

O que é criado:
- **A cena**, em `world/mapas/<id>.tscn`, a partir do modelo do tipo (`addons/vat_editor/templates/maps/`). Ela já tem as camadas de tiles **Chão**, **Paredes** e **Decoração**, o chão preenchido com o tile base e uma borda de parede, além de **Start** (ponto inicial), **Entry** (entrada), **Player** e **MapCamera**. Os tipos Cidade, Interior e Masmorra também trazem a arena de batalha; o Mapa-múndi não tem.
- **O `MapDef`**, em `data/maps/<id>.tres`, com o nome e o tipo.
- **A entrada no registro**, em `data/maps/registro.tres`. É por aí que o jogo, a aba Testar e o Mundo encontram o mapa.

O mapa aparece na lista da aba **Mapas** e abre na cena do editor. Para ele, a aba **Mapas** tem **Abrir** e **Remover do registro** (esta última não apaga a cena; ligações que apontam para o mapa passam a acusar erro na validação).

**Pintar:** pinte com o TileMap do Godot. Em **Chão**, o piso; em **Paredes**, o que bloqueia; em **Decoração**, os enfeites (não colide). O tileset é `game/art/tiles/placeholder_32.tres`, de tiles 32×32, e a colisão vem do próprio tileset: não precisa de `StaticBody2D`. Os nós de jogo (NPCs, portas, baús, ligações, marcadores) são nós separados do TileMap: coloque-os pela paleta (seção (c)).

## (c) Colocar objetos com a paleta e configurar pelo Inspector

**Paleta "Objetos".** Com um mapa aberto (um `LocalMap` ou um `Overworld`), o dock **Objetos** mostra um botão por objeto: NPC, Placa, Ligação, Baú, Ponto de descanso, Loja, Pousada, Inimigo do mapa, Obstáculo elemental, Portão de flag, Porta com chave, Interruptor, Gatilho de evento, Armadilha, Marcador de spawn e Zona (só no mapa-múndi).

- Clicar num botão coloca o prefab no último clique da vista 2D ou, sem clique, no centro da vista. A posição é alinhada à grade de 32 px, o nome recebe um id único, o nó novo fica selecionado e a ação entra no **Ctrl+Z** do editor.
- **Ajustar à grade** alinha à grade de 32 px os nós selecionados.
- **Renomear com id** troca as flags provisórias (ou repetidas) dos nós selecionados por flags únicas do mapa.
- Cada botão usa um prefab de `world/prefabs/`, um por tipo de objeto.

**Inspector.** Selecione o objeto e preencha os menus (em vez de digitar):
- **Ligação** (`MapLink`): **target_map** (mapa de destino, dos mapas do registro) e **target_spawn** (ponto de entrada, dos marcadores do mapa de destino).
- **Zona** (mapa-múndi): **zone_id** e **spawn**, do mesmo jeito.
- **Roteiro e evento** (qualquer nó com `roteiro` e `event_id`): **roteiro** lista os livros `.roteiro`; **event_id** lista os eventos do livro escolhido. O botão **Abrir no editor de blocos** abre esse evento em **Roteiros > Editor**.
- **Inimigo do mapa** (`MapEnemy`): **encounter**, com o seletor de encontros.
- **Loja** (`ShopKeeper`): **shop**, com o seletor de lojas.
- **NPC** (`Npc`): **speaker**, com o seletor de falantes.
- **Obstáculo elemental** (`ElementalObstacle`): **element**, com o seletor de elementos.

O resto do Inspector continua igual.

## (d) Conferir o mundo na aba Mundo

- A aba **Mundo** desenha um nó por mapa do registro, com o tipo e o número de pontos de entrada. Cada seta é uma ligação (`MapLink`, `Zone` ou saída), com o rótulo do ponto de entrada.
- Uma ligação quebrada aparece em **vermelho**, com a mensagem, e entra na lista **Ligações quebradas (N)**. Mapas que a navegação não alcança aparecem na lista **Inalcançáveis**.
- **Clique duplo** num mapa abre a cena. Clicar numa seta ou num item da lista abre a cena de origem e seleciona o nó.
- **Arraste** os nós para arrumar. **Reorganizar** volta ao layout automático. **Atualizar** relê o registro e as cenas.
- Marque **mostrar mapas de teste** para incluir os mapas de teste (`overworld`, `area_teste`, `dungeon_teste`).
- As posições ficam em `game/addons/vat_editor/mundo_layout.cfg`. É um arquivo do editor, não do jogo. **Reorganizar** apaga esse arquivo e volta ao layout automático.

## (e) Editar conteúdo no Banco, com formulários

Na aba **Banco**, escolha a categoria (Heróis, Inimigos, Habilidades, Itens, Equipamentos, Encontros, Lojas, Estados, Elementos, Reações, Terrenos, Falantes e Arte) e clique na lista. O formulário aparece à direita. **Novo...** cria um recurso a partir do modelo, e **Duplicar...** copia o selecionado (a regra do id é a mesma da seção (b)).

Em todos os formulários:
- **Salvar** grava o recurso; **Reverter** descarta as alterações e relê o arquivo.
- O indicador **● não salvo** aparece quando há alterações pendentes.
- Os erros e avisos do que está aberto aparecem no próprio formulário, pelos mesmos checks da aba **Validar**.

**Heróis.** Id, nome e atributos base; elementos nativos (até 2); afinidades e resistência a estados; ataque básico, **Golpe de Limite** e tipos de arma; equipamento inicial; **Técnicas por nível** (uma tabela de nível × habilidade; nível 0 significa "só por evento"); arte. Se o herói não tem atributos, o botão **Criar atributos** os cria.

**Inimigos.** Atributos, nível, XP base, moedas, elementos nativos; afinidades, resistências e imunidades a estados; habilidades; **Regras de IA**, em ordem (vale a primeira que se aplica, de cima para baixo); drops; fases de chefe (cada uma com as suas regras); contra-ataque e papel; "protege o núcleo" (para partes); arte.

**Encontros.** A lista de inimigos, **Pode fugir** e **Id único** (para chefes, gravado ao vencer). A **Prévia da formação** mostra o total de inimigos, o XP base e as moedas. **Testar encontro** abre o jogo já na luta com este encontro, usando o nível e a arena da aba **Testar**. Salve antes: o jogo lê do disco.

**Lojas.** A seção **O que a loja vende** é uma tabela de itens e equipamentos, com as setas **↑** (Subir), **↓** (Descer) e **✕** (Tirar da loja), e com **+ Adicionar item** / **+ Adicionar equipamento**. O preço é do item ou equipamento e vale em todas as lojas; a coluna **Venda** mostra o que o jogador recebe ao vender (o preço vezes a razão de venda, arredondado para baixo). Preço 0 ou item-chave não se vende. A seção **Arquivos gravados ao salvar** lista os arquivos que o Salvar vai escrever, antes de você gravar.

**Itens e Equipamentos.** Itens: nome, preço, item-chave e efeitos (em ordem). Equipamentos: espaço, tipo de arma (só para armas), **Quem veste** (só para armadura e capacete; nenhum marcado significa todos), atributos somados, elemento, afinidade somada, passivos e preço.

**Arte (SpriteSet).** Folha de mapa (tamanho do quadro, quadros por direção, quadros por segundo); folha de batalha (tamanho do quadro e se a figura está virada para a direita); a tabela de **animações** (linha, quadros e fps), com **+ Adicionar animação** e uma prévia que toca cada uma; os **retratos** (expressão → imagem, com **+ Adicionar retrato**) e a prévia. Os avisos de folha e tamanho aparecem ao vivo.

**Criar a partir de uma imagem…** (botão na aba **Banco**, junto de **Novo...** e **Duplicar...**): escolha um PNG do projeto com **Escolher…**, ajuste **Ler como** e o tamanho do **Quadro** (o assistente mostra o tamanho da imagem e sugere a grade), dê um id e a pasta e clique em **Criar**. Nada é gravado antes de Criar. O `SpriteSet` novo abre no formulário de arte.

## (f) Validar e testar

### Validar

- Aba **VAT > Validar > Validar tudo**. O painel roda os validadores em outro processo e lista **Erros** e **Avisos**, cada um com o arquivo e, quando há, a linha.
- Pela linha de comando, sem janela (sai com código 1 se houver erro):

```powershell
& "<Godot_v4.x-stable_win64_console.exe>" --headless --path game -s tools/validate/check_all.gd
```

O que é checado: ids únicos por tipo, referências que existem, no máximo 2 elementos nativos, a tabela de reações, chefes imunes a Contagem e Petrificação, eventos e roteiros, folhas de `SpriteSet`, mapas com `MapLink` para spawn que existe, e avisos de arte de batalha faltando. Conteúdo de `res://data/test/` não recebe o aviso de arte.

O que é aviso e não erro: flag usada sem `@flag` (no roteiro) e herói ou inimigo sem arte.

### Testar um mapa ou um encontro

Aba **VAT > Testar**:

- **Jogar este mapa**: escolha o mapa e, opcionalmente, o ponto de entrada (*spawn*), e clique. Abre o jogo nesse mapa. A lista de mapas vem do registro (`data/maps/registro.tres`).
- **Testar encontro**: escolha o encontro, a **arena** (o mapa onde a luta acontece; sem escolha, a do mapa inicial) e o **nível** (1 a 99, padrão 5). Abre o jogo já na luta.
- **Parar o jogo**: encerra a janela do teste.

O teste abre **uma janela de jogo separada**, que não aparece no depurador do editor. Pelos flags, a mesma coisa vale na linha de comando (os flags vão depois de `--`):

```powershell
& "<Godot.exe>" --path game -- --start-map=cidade --spawn=<marcador>
& "<Godot.exe>" --path game -- --battle=<encontro> --level=8 --start-map=<mapa>
```

- `--spawn` e `--level` sozinhos não fazem nada; precisam de `--start-map` ou `--battle`. Mapa, marcador ou encontro desconhecido dá erro no log e volta ao título.
- `--battle` precisa de um mapa com arena. Sem `--level`, o nível é 5.

Os mesmos flags são só para desenvolvimento e não fazem parte do jogo exportado.

## Alternativa avançada: escrever o roteiro em texto

O editor de blocos (a seção (a)) lê e grava o mesmo formato. Quem prefere escrever à mão pode editar o `.roteiro` num editor de texto; o compilador é o mesmo, e o Godot reimporta o arquivo ao salvar. A sintaxe completa está em [`roteiro.md`](roteiro.md).

Exemplo, num arquivo como `game/data/fatia/roteiro/minha_cidade.roteiro`:

```
# Textos placeholder.
@flag viu_placa

=== morador_novo
Morador X [neutro]: Texto de teste: quer ajuda?
: Aceitar a ajuda?
* Sim -> aceita
* Não -> recusa
== aceita
@set viu_placa 1
Morador X: Texto de teste: combinado.
-> fim
== recusa
Morador X: Texto de teste: tudo bem, volte se mudar de ideia.
```

- `@flag` declara a flag do arquivo (sem ele, o compilador avisa). `== aceita` e `-> aceita` são o mesmo rótulo.
- Erros aparecem no console como `arquivo.roteiro:linha: mensagem`, e a importação falha até você corrigir.
- Para ligar a um NPC, selecione o nó `Npc` no mapa e, no Inspector, use **roteiro** e **event_id** (seção (c)).

## (g) Limites conhecidos

- **Sem arrastar no editor de blocos:** os blocos se reordenam só com as setas ▲ e ▼.
- **Renomear um evento não atualiza `event_id` nos mapas.** O próprio diálogo avisa; ajuste os mapas à mão.
- **Interruptor e portão de flag recebem flags diferentes.** Para o portão abrir com o interruptor, escolha a mesma flag nos dois.
- **Primeira gravação de um `.tres` por formulário** reordena as chaves e os ids dos sub-recursos. O diff fica grande só na primeira vez.
- **Formulários longos** precisam de rolagem.
- **Edição só no Inspector não marca o formulário como "● não salvo".** Se mexeu no Inspector, grave ou reverta pelo formulário.
- **O editor reescreve `project.godot` ao abrir.** Antes de commitar, confira o diff e desfaça o que não for seu.
- **Sem autotile:** cada tile é pintado à mão.
- **Animação de ataque:** a animação de ataque começa quando a ação começa, não no momento do golpe.
- **Reimportar pode mudar as quebras de linha dos `.import`.** Se a mudança for só de fim de linha, restaure o arquivo antes de commitar.
- **Não rode demos e testes ao mesmo tempo.** Eles compartilham a pasta `user://` (saves e configurações), e um atrapalha o outro.
- **Primeiro import de um clone novo:** na primeira abertura ou `--import` de um clone recém-feito pode aparecer `importer for type 'vat.roteiro' not found` / `Failed loading resource ... .roteiro`. É só o plugin ainda não carregado; um segundo `--import` (ou reabrir o editor) sai limpo.

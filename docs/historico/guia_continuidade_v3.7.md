# Guia de continuidade do desenvolvimento do RPG

> Documento de transferência de contexto para outro agente de IA. Deve ser tratado como a referência de trabalho para continuar a especificação do jogo sem perder decisões já tomadas.
>
> **Idioma de trabalho:** português brasileiro.  
> **Estado desta compilação:** reúne as ideias e regras disponíveis no contexto desta conversa até a versão de especificação 3.7.  
> **Regra central:** preservar o que o usuário decidiu, diferenciar claramente fatos confirmados de propostas e perguntas em aberto e não inventar história, personagens, fórmulas, números ou regras como se já tivessem sido aprovados.

---

## 1. Instruções para o agente que assumir o projeto

Você é o agente responsável por ajudar o usuário a desenvolver, documentar e validar, progressivamente, as mecânicas de um RPG narrativo clássico. Sua função é ser um **parceiro de design e sistematização**, não tomar a autoria do jogo.

### 1.1. Como conduzir a colaboração

1. **Preserve as decisões anteriores.** Não substitua uma regra confirmada por uma convenção genérica de RPG, a menos que o usuário peça explicitamente para revisá-la.
2. **Separe a informação em três categorias:**
   - **Confirmado:** decisão explicitamente tomada pelo usuário.
   - **Proposta provisória:** solução sugerida para facilitar o desenvolvimento, ainda sujeita à aprovação.
   - **Em aberto:** lacuna, ambiguidade, conflito ou decisão que ainda exige resposta.
3. **Não transforme referências em cópias.** Chrono Trigger e Final Fantasy VII clássico são referências para convenções do gênero; isso não autoriza importar automaticamente suas regras para o projeto.
4. **Não invente conteúdo autoral do usuário.** A história e os personagens já foram desenvolvidos pelo usuário, mas seus detalhes não constam deste contexto. Não crie enredo, personagens, mundo, facções, diálogos ou revelações para preencher lacunas.
5. **Não invente fórmulas ou valores.** As fórmulas de atributos, dano, ATB, XP e contribuição ainda não foram definidas. Não apresente coeficientes, probabilidades, curvas, durações ou quantidades numéricas como decisões existentes.
6. **Use convenções clássicas como ponto de partida provisório.** O usuário pediu expressamente que o agente não seja excessivamente rígido ou faça perguntas demais. Quando uma mecânica secundária estiver indefinida, pode-se sugerir um padrão convencional inspirado em Chrono Trigger/Final Fantasy VII clássico, desde que ele seja rotulado como proposta e não contrarie decisões confirmadas.
7. **Pergunte apenas o que importa.** Priorize decisões que afetam estrutura, balanceamento, possibilidades táticas, arquitetura ou coerência entre sistemas. Não entregue questionários longos para cada detalhe menor. Agrupe, quando útil, poucas perguntas de alto impacto.
8. **Desenvolva incrementalmente.** Feche um sistema de cada vez, registre as decisões, verifique interações com sistemas anteriores e avance para a próxima etapa. O jogo deverá ser construído e validado por partes.
9. **Reconheça contradições sem corrigi-las silenciosamente.** Se duas regras parecerem incompatíveis, preserve ambas no registro, explique o conflito e formule uma proposta de conciliação.
10. **Mantenha rastreabilidade.** Ao editar a especificação, indique o que mudou, o que foi confirmado agora e o que continua provisório. Não apague silenciosamente decisões antigas.

### 1.2. Formato recomendado para cada atualização

- **Decisões confirmadas:** regras aprovadas pelo usuário.
- **Propostas provisórias:** soluções sugeridas, não aprovadas.
- **Questões em aberto:** poucas perguntas prioritárias.
- **Impactos e consistência:** como as decisões se relacionam com sistemas já documentados.
- **Próxima etapa:** uma tarefa concreta de design, teste ou validação.

### 1.3. Como interpretar as versões

O histórico de design contém referências às versões 3.2, 3.4, 3.5, 3.6 e 3.7. Essas etiquetas são marcos de organização dos sistemas, não significam que todos os detalhes do jogo já estejam fechados. A versão 3.7 incorpora decisões sobre estados de combate. Se criar nova versão, mantenha o histórico e não reescreva o significado das anteriores.

---

## 2. Conceito geral do jogo

### 2.1. Identidade e referências

- **Gênero:** RPG narrativo clássico.
- **Referências centrais:** Chrono Trigger e Final Fantasy VII original/clássico.
- **Combate:** RPG por turnos com ATB, além de conceitos de combate que o usuário já vinha desenvolvendo com influência de RPG de mesa.
- **Apresentação visual:** 2D, perspectiva top-down, pixel art moderna.
- **Plataforma-alvo inicial:** PC.
- **Motor e tecnologia:** ainda não escolhidos.
- **Escopo de construção:** desenvolver o jogo por etapas, validar cada parte e ajustar os sistemas durante os testes.

As referências devem orientar o repertório de soluções convencionais, a linguagem do gênero e o nível de complexidade esperado. Não devem substituir as decisões próprias do projeto.

### 2.2. Modos de jogo

O jogo está dividido conceitualmente em três modos:

1. **Exploração do overworld:** mapa geral do mundo, em escala reduzida, no estilo clássico de RPG.
2. **Exploração de ambientes menores:** mapas próprios para cidades, dungeons e outros locais.
3. **Combate RPG:** batalhas com ATB e ações de combate.

A estrutura do mundo será clássica: overworld em escala reduzida e mapas separados para cidades, dungeons e ambientes específicos.

### 2.3. História e personagens

- O usuário afirma já ter definido a história e os personagens.
- Os detalhes narrativos não foram incluídos no contexto reunido neste documento.
- O próximo agente deve pedir ou consultar o material narrativo do usuário quando ele for necessário para uma tarefa específica, mas não deve reconstruí-lo nem inventar substitutos.

---

## 3. Estrutura do combate — ATB

### 3.1. Regras confirmadas (marco v3.2)

- As barras ATB de personagens aliados e inimigos são preenchidas continuamente.
- A Velocidade influencia a taxa de preenchimento da barra ATB.
- Quando a barra fica cheia, o combatente está pronto para agir, mas aguarda sua prioridade automática.
- Entre combatentes prontos, o personagem com maior Velocidade age primeiro.
- Empates de Velocidade são resolvidos aleatoriamente.
- O jogador não escolhe manualmente a ordem de execução entre vários combatentes prontos.
- Quando o jogador abre o menu de comandos, o tempo global do combate é pausado.
- Essa pausa é o **modo Wait**.
- As animações e a execução de uma ação não pausam o tempo global do combate.
- Depois de agir, o ATB do personagem é reiniciado e começa a preencher novamente.
- Se vários combatentes estiverem prontos após a pausa do menu, o de maior Velocidade age primeiro; os demais aguardam sua vez.
- Uma ação que já começou não pode ser interrompida por outra ação.
- Todos os efeitos de uma ação devem ser resolvidos por completo antes de o próximo combatente começar a agir.
- Inimigos têm IA própria, com regras e prioridades próprias; detalhes ainda não especificados.
- O campo de batalha tem posições fixas: não há movimentação tática durante a batalha.
- O combate comporta até quatro personagens ativos no grupo.
- Personagens de suporte podem ser chamados para executar uma única ação sem entrar no grupo ativo.
- A ação começa após o jogador confirmar o comando e os alvos.
- As ações podem ter alvos diferentes conforme a habilidade: um alvo, vários alvos, um grupo ou todos os aliados/inimigos elegíveis.
- Um personagem incapacitado não pode agir.
- A habilidade define sua duração e o momento em que os efeitos são aplicados.
- Se o executor for derrotado depois que a ação começou, mas antes da aplicação de seus efeitos, a ação ainda se completa normalmente.
- A próxima ação não começa até que todos os efeitos da ação corrente estejam resolvidos.

### 3.2. Seleção de comando, alvo e custo de recurso

- O jogador seleciona o comando e escolhe o(s) alvo(s) antes da confirmação e execução.
- O custo de recurso é consumido quando o comando é selecionado.
- Se o jogador cancelar antes de confirmar o comando, o recurso é integralmente devolvido; não deve haver custo líquido por uma ação cancelada antes da confirmação.
- Se não houver Aura suficiente, a habilidade não pode ser selecionada ou confirmada.
- A especificação deverá preservar o comportamento acima, mesmo que a implementação interna use reserva de recurso, consumo seguido de restituição ou outra técnica equivalente.
- Se um alvo se tornar inválido antes da aplicação do efeito, o jogo deve solicitar um novo alvo, quando isso for possível.
- O comportamento quando todos os alvos válidos deixarem de existir ainda está em aberto.

**Detalhe de implementação ainda a conciliar:** o custo é descrito como consumido na seleção e também integralmente devolvido se houver cancelamento antes da confirmação. Uma implementação pode reservar o recurso no início da seleção e efetivar o gasto na confirmação, ou consumir e devolver ao cancelar. A semântica visível ao jogador é a parte confirmada; a abordagem técnica exata não é.

### 3.3. Modo Wait e tempo de combate

Está confirmado que abrir o menu de comandos pausa o tempo global do combate e que animações/execução continuam com o tempo avançando. Permanecem em aberto:

- Se a pausa inclui todos os submenus (seleção de habilidade, itens, alvo e confirmação) ou somente o menu principal.
- Como o cancelamento entre submenus afeta a seleção e o recurso.
- O que acontece com combatentes que chegam a ATB cheio enquanto outra ação está em execução.
- Se o desempate aleatório por Velocidade é sorteado uma única vez para uma situação de empate ou recalculado.
- Como representar e resolver a prioridade quando surgem novos combatentes prontos durante uma ação.

O próximo agente não deve inventar silenciosamente respostas para esses pontos. Pode propor a solução mais simples e coerente quando necessário.

### 3.4. Inimigos e ações concorrentes

- Inimigos agem de acordo com IA própria, suas regras e prioridades.
- A ordem de ação de combatentes prontos é automática e baseada em Velocidade, com desempate aleatório.
- A resolução dos efeitos de uma ação é atômica em relação à próxima ação: nenhum outro combatente inicia sua ação antes que os efeitos atuais tenham sido resolvidos.
- Uma ação já iniciada não pode ser cancelada pela derrota do executor.

**Em aberto:** prioridades exatas da IA, telegraphing de ações, decisões de alvo, possíveis exceções a essa regra de ação atômica e tratamento de novas barras ATB completas durante animações.

### 3.5. Grupo ativo e suporte

- Até quatro personagens podem estar ativos no grupo de combate.
- Um personagem de suporte pode ser invocado para realizar uma ação única sem entrar no grupo ativo.
- Habilidades combinadas entre personagens, no estilo das Techs de Chrono Trigger, foram adiadas para uma etapa futura; não foram rejeitadas.
- Suporte e personagens fora do grupo ativo não recebem XP de combate pelas regras de contribuição registradas mais adiante.

**Em aberto:** custo, limitações, frequência, disponibilidade narrativa e regras de alvo das ações de suporte. Não implementar habilidades combinadas sem uma etapa específica de design.

---

## 4. Incapacitação, HP e recuperação

### 4.1. Regras confirmadas

- Um personagem que chega a **0 HP** fica incapacitado.
- Um personagem incapacitado não pode agir.
- Personagens incapacitados podem ser revividos.
- A ação de um personagem que foi iniciada antes de ele ser derrotado continua normalmente, conforme a regra de resolução de ações.
- A revivificação restaura uma quantidade reduzida de HP; o valor exato ou a fórmula ainda não foram definidos.
- HP e Aura devem ser tratados como recursos distintos.
- O HP após uma batalha **não** foi decidido como persistente ou automaticamente recuperado; não assumir nenhuma dessas opções como fato.

### 4.2. Propostas provisórias para recuperação

As seguintes ideias foram sugeridas, mas ainda não são decisões confirmadas em sua totalidade:

- Pontos de descanso podem recuperar HP e Aura.
- O jogador pode precisar administrar o HP entre combates se for adotada persistência de HP.
- A recuperação por descanso ocorre somente em locais específicos.

### 4.3. Uso de itens em combate

- Usar um item durante o combate consome a ação ATB do personagem.
- Itens podem restaurar HP ou Aura, dependendo do item.
- O momento de consumo definitivo do item (na confirmação do comando ou quando o efeito é aplicado) está em aberto.
- Não foi definido se qualquer item pode ser usado fora de combate nem quais restrições existem.

---

## 5. Atributos e progressão de personagem

### 5.1. Atributos registrados

Os atributos atuais são:

| Atributo | Função conhecida | Limites atuais da especificação |
|---|---|---|
| **Força** | Representa poder físico e contribui para o escalonamento de habilidades pertinentes. | Fórmula de dano e contribuições por habilidade ainda não definidas. |
| **Velocidade** | Aumenta a taxa de preenchimento da barra ATB e a chance de esquiva. | Fórmula de preenchimento e curva de esquiva ainda não definidas; a esquiva deve permanecer baixa no geral. |
| **Vitalidade** | Contribui, junto ao nível, para o HP máximo. | Fórmula ainda não definida. |
| **Aura** | Atributo que determina a capacidade máxima de pontos de Aura. | Fórmula de capacidade ainda não definida. |

- Os valores dos atributos são números inteiros.
- Os valores iniciais de atributo são específicos para cada personagem.
- O conjunto de atributos ainda pode mudar; não tratá-lo como imutável.
- Todos os atributos têm retornos decrescentes, numa inspiração geral em jogos Souls. Não existe ainda uma curva numérica, faixa ou fórmula determinada.
- Os pontos recebidos ao subir de nível são distribuídos livremente, sem custo adicional ou requisito de distribuição confirmado.
- O jogador pode reiniciar a distribuição de atributos em um ponto de descanso, usando um item específico e raro. A intenção é permitir nova distribuição quando as condições necessárias forem atendidas.

### 5.2. Fórmulas e cálculos derivados

As seguintes fórmulas ainda **não** foram definidas:

- HP máximo a partir de Vitalidade e nível.
- Capacidade máxima de Aura a partir do atributo Aura.
- Taxa de preenchimento da barra ATB a partir de Velocidade.
- Chance de esquiva a partir de Velocidade e possíveis outros fatores.
- Dano base, mitigação, ataque/defesa e escalonamento de habilidades.
- Curvas numéricas dos retornos decrescentes.
- Ordem de aplicação dos retornos decrescentes, modificadores de equipamento e efeitos temporários.

A regra geral de design é que os retornos decrescentes se aplicam a todos os atributos. A forma exata de combinar atributo-base, pontos investidos, equipamento e modificadores temporários ainda precisa ser projetada.

### 5.3. Habilidades e escalonamento

- O escalonamento é híbrido: existem fórmulas compartilhadas e particularidades específicas de cada habilidade.
- Cada habilidade tem custo fixo de pontos de Aura.
- O usuário deseja documentar primeiro o sistema de combate e suas regras; depois será possível revisar e balancear as habilidades em detalhe.
- Não existem valores de custo, fórmulas de escalonamento ou números de dano confirmados neste documento.

### 5.4. Equipamento

- Equipamentos modificam atributos.
- Equipamentos podem ter modificadores negativos.
- Equipamentos também podem ter efeitos passivos.
- Existem restrições de equipamento, mas os critérios não foram especificados.
- Substituir um equipamento em determinado espaço substitui seus modificadores pelos do novo equipamento; não há acúmulo de vários equipamentos no mesmo espaço.
- Os modificadores de equipamento são considerados nos cálculos de HP máximo, capacidade de Aura, Velocidade/ATB e esquiva, conforme os atributos envolvidos.
- Efeitos temporários também podem modificar atributos.
- A ordem de aplicação de equipamento, efeitos temporários e retornos decrescentes ainda está em aberto.

---

## 6. Aura: atributo e recurso consumível

É essencial não confundir **Aura** com **pontos de Aura**.

- **Aura (atributo):** atributo inteiro que determina a capacidade máxima de pontos de Aura do personagem.
- **Pontos de Aura:** recurso consumível gasto ao usar habilidades.
- Cada habilidade tem um custo fixo em pontos de Aura.
- O atributo Aura tem retornos decrescentes, como os demais atributos.
- Equipamentos e efeitos temporários podem modificar atributos e valores derivados, incluindo a capacidade de Aura.
- Pontos de Aura podem ser recuperados por itens, descanso e habilidades específicas.
- Pontos de Aura atuais persistem após o fim do combate: não há recuperação automática ao encerrar uma batalha.
- A recuperação por descanso ocorre somente em locais específicos.
- Se não houver Aura suficiente, a habilidade não pode ser selecionada ou confirmada.
- Cancelar antes de confirmar o comando devolve integralmente o custo reservado/consumido.

**Em aberto:** fórmula da capacidade máxima de Aura, recuperação exata por item/descanso/habilidade e momento exato de consumo de itens. A persistência do HP, diferentemente da Aura, não foi decidida.

---

## 7. Experiência (XP) e subida de nível

### 7.1. Fontes e progressão

- XP é obtida principalmente em combate e também por eventos narrativos.
- A quantidade de XP necessária para subir de nível cresce progressivamente mais rápido em níveis altos.
- A curva cumulativa planejada é **quadrática**, ainda sem fórmula ou coeficientes.
- O ritmo desejado é moderado e deverá ser avaliado com marcos narrativos e tempo de jogo.
- A curva pode ser ajustada durante testes, mantendo o formato quadrático.
- O nível máximo ainda não foi definido.
- Cada personagem possui seu próprio nível e quantidade de XP.
- Cada nível concede 1 ponto de atributo.
- Nos níveis 5, 10, 15, 20 e assim sucessivamente, o personagem ganha **dois pontos adicionais** além do ponto normal daquele nível. Portanto, nesses níveis, a recompensa total daquele nível é de três pontos.
- A distribuição é livre: sem custo nem requisito de atributo confirmado.
- Após uma batalha ou cena em que um personagem subir de nível, aparece uma tela dedicada para alocar pontos.
- Se um personagem subir vários níveis no mesmo combate/cena, uma única tela permite gastar todos os pontos acumulados.

### 7.2. XP de combate

- Cada inimigo define uma quantidade-base de XP.
- Chefes usam o mesmo método geral de distribuição, com sua própria quantidade-base de XP.
- A XP de cada inimigo é calculada individualmente para cada personagem, proporcional à contribuição efetiva do personagem contra aquele inimigo.
- A XP não é simplesmente dividida em partes inteiras que necessariamente somem à XP-base do inimigo.
- Não há contribuição mínima obrigatória: qualquer contribuição efetiva pode gerar XP.
- A derrota de um inimigo conta para todos os personagens que contribuíram efetivamente contra ele, não apenas para quem deu o golpe final.
- A XP é calculada separadamente por inimigo, não apenas pelo total combinado do combate.
- O resultado é arredondado para baixo; XP residual perdida por arredondamento é descartada.
- Se a contribuição total contra um inimigo for zero, nenhuma XP é distribuída por esse inimigo.
- Personagens de suporte e personagens fora do grupo ativo não recebem XP de combate.
- Um personagem incapacitado que nunca contribuiu não recebe XP desse combate. Se contribuiu antes de ficar incapacitado, a contribuição anterior continua contando.
- Um personagem que termina a batalha derrotado/morto ainda recebe XP conforme sua contribuição.
- Reviver o personagem depois do combate não altera a recompensa de XP.
- Se o grupo fugir do combate, ninguém recebe XP daquela batalha, inclusive por inimigos derrotados antes da fuga. Não há outra consequência de fuga confirmada.

### 7.3. XP narrativa

- Eventos da história concedem um valor fixo de XP definido individualmente por evento.
- A intenção geral é que todos os personagens elegíveis do grupo ativo recebam o mesmo valor definido para o evento.
- A elegibilidade pode variar de evento para evento.
- Há uma regra ainda não formalizada: personagens incapacitados ou ausentes podem receber XP narrativa quando cumprem os critérios de elegibilidade do evento, embora a regra geral indique que apenas o grupo ativo é elegível. O próximo agente deve ajudar a explicitar o que significa estar “ausente” e como isso se concilia com a regra de grupo ativo, sem escolher silenciosamente uma interpretação.

---

## 8. Modelo de contribuição para XP em combate

O sistema usa **pontos equivalentes de HP** como escala comum de contribuição. Os valores por efeito serão calibrados manualmente; não existem valores numéricos definidos.

### 8.1. Dano, cura e proteção

- Dano efetivo conta ponto a ponto, limitado ao HP restante do inimigo no momento em que o dano é aplicado.
- Cura conta apenas os pontos de HP efetivamente restaurados.
- Proteção conta os pontos de dano efetivamente prevenidos ou absorvidos.
- Dano, cura e proteção têm o mesmo valor de contribuição por ponto efetivo na escala comum.

### 8.2. Buffs, debuffs e efeitos diversos

- Buffs, debuffs e outros efeitos recebem um valor de contribuição próprio, definido manualmente para cada efeito.
- Esse valor representa a aplicação bem-sucedida do efeito.
- Para efeitos persistentes, a aplicação bem-sucedida gera o valor predefinido mesmo se o efeito acabar antes da duração esperada.
- A aplicação inicial de um efeito persistente mantém a contribuição integral mesmo que o efeito seja interrompido ou termine cedo.
- A reaplicação pode gerar contribuição adicional quando produz impacto adicional.
- A renovação/extensão da duração pode contar pela duração efetivamente adicionada.
- Efeitos de controle usam um valor comum predefinido por turno efetivamente controlado, igual entre tipos diferentes de controle.
- Se um efeito for parcialmente resistido, somente a parte efetiva conta, proporcionalmente à porção efetiva.
- Uma imunidade total não gera contribuição pelo efeito negado.
- A aplicação bem-sucedida de um efeito persistente pode contar mesmo quando não há resultado mensurável posterior.
- Não há limite geral de contribuição por ação.
- Em habilidades com múltiplos efeitos, somam-se os efeitos efetivos individualmente, sem duplicar o mesmo impacto.
- Quando uma ação beneficia outro personagem, a contribuição é atribuída a quem executou a ação, e não ao beneficiário.
- Um mesmo impacto não pode ser contado duas vezes; somente impactos efetivamente distintos podem somar contribuição.
- Se efeitos diferentes tiverem contribuição própria, podem ser contados separadamente desde que não contabilizem duas vezes o mesmo impacto.

### 8.3. Atribuição por inimigo e ao longo do combate

- A contribuição é monitorada separadamente para cada inimigo.
- Uma habilidade que atinge vários inimigos gera um registro de contribuição para cada inimigo afetado.
- Efeitos aplicados antes de um inimigo ser diretamente atacado podem contar se contribuírem efetivamente para o combate contra aquele inimigo.
- A contribuição de efeitos persistentes fica vinculada ao personagem que os aplicou, de acordo com o impacto efetivo.
- A contribuição total contra o inimigo inclui todos os personagens que contribuíram efetivamente contra ele, mesmo se ficarem incapacitados depois.
- Para controle, conta o número de turnos efetivamente controlados, com valor comum por turno controlado.

### 8.4. Lacunas operacionais do modelo

Ainda precisam de especificação, sem inventar valores no processo:

- Como converter o registro total de contribuição em fração da XP-base de cada inimigo e em XP individual.
- Como consolidar/contabilizar impactos de cada personagem sem duplicidade.
- Valores manuais dos efeitos de buff, debuff, controle e efeitos persistentes.
- Regras para renovação de duração, sobreposição de efeitos e efeitos reaplicados.
- Como tratar turnos de controle incompletos ou interrupções no turno.
- Como atribuir impactos indiretos e causalidade compartilhada quando um efeito prepara ou amplifica a ação de outro personagem.
- Regras precisas de contribuição em dano refletido, dano ao longo do tempo, barreiras, prevenção parcial e efeitos de área, se esses tipos existirem.

Esses pontos são importantes para balanceamento. Não se deve simplificar o sistema para “dano causado” apenas, pois o modelo confirmado inclui cura, proteção, controle e efeitos diversos.

---

## 9. Estados de combate, buffs e debuffs — versão 3.7

O usuário respondeu ao diagnóstico de estados de combate com sete decisões explícitas. Esta seção registra as decisões sem converter as propostas anteriores em fatos.

### 9.1. Decisões confirmadas

**Duração**
- A duração dos estados é medida em turnos ou ações do personagem afetado.
- Não foi definida uma duração padrão universal; ela pode variar por estado.

**Sono e ATB**
- Um personagem dormindo não pode agir.
- Se sua barra ATB encher enquanto estiver sob Sono, ele perde a oportunidade de ação.
- Não recebe automaticamente uma ação acumulada ao despertar.

**Veneno**
- Veneno causa dano periódico durante o combate.
- O momento, intervalo e valor do dano não foram definidos.

**Reaplicação do mesmo estado**
- Reaplicar renova a duração.
- A intensidade não se acumula pela reaplicação do mesmo estado.

**Buffs e debuffs**
- Modificam atributos e os cálculos derivados correspondentes.

**Resistências**
- Há imunidade total e resistência parcial.
- A forma matemática/operacional da resistência parcial ainda está indefinida.

**Remoção**
- Estados podem ser removidos por itens, habilidades e término natural.

### 9.2. Propostas provisórias registradas anteriormente

Estas propostas foram sugeridas como convenções iniciais; o usuário ainda não as confirmou individualmente:

- Criar um catálogo inicial de estados clássicos como Sono, Veneno, Paralisia e outros que demonstrem utilidade estratégica.
- Verificar imunidade e resistência antes da aplicação de um estado.
- Controlar a duração separadamente para cada estado e personagem.
- Após acordar, deixar a barra ATB funcionar normalmente, sem restaurar a oportunidade perdida.
- Definir cada buff/debuff com os atributos afetados e duração própria.
- Determinar o dano periódico de Veneno com regra específica para o estado, sem assumir se o intervalo será medido por ação ou por tempo.

Não trate essas propostas como aprovadas sem uma resposta posterior do usuário.

### 9.3. Questões em aberto sobre estados

- **Paralisia:** bloqueia todas as ações quando a barra ATB enche ou permite agir em algumas oportunidades?
- **Veneno:** causa dano em intervalos de tempo, ao fim de uma ação ou em outro marco do combate?
- **Resistência parcial:** reduz chance de aplicação, duração, intensidade ou combinações desses aspectos? Esta escolha pode variar por estado?
- **Conflito de buffs/debuffs:** vários efeitos que alteram o mesmo atributo podem coexistir? Eles se somam, se anulam, substituem um ao outro ou seguem uma regra por efeito?
- **Sono:** quais situações encerram o estado? Término natural, dano recebido, item, habilidade ou alguma combinação? A remoção por dano ainda não foi confirmada.
- **Duração por ação ou por turno:** como o sistema definirá o fim da duração, considerando que ATB é contínuo e que os turnos podem não ser globais?
- **Periodicidade do Veneno:** como integrar o dano periódico à natureza temporal do ATB sem introduzir inconsistências?

O próximo agente deve evitar um questionário grande. Pode escolher um padrão provisório coerente para o catálogo inicial e consultar o usuário somente sobre as decisões que mudem substancialmente a estratégia de combate.

---

## 10. Itens e descansos: regras e questões cruzadas

### Confirmado

- Itens podem recuperar HP ou pontos de Aura conforme o tipo.
- Usar um item em combate consome a ação ATB.
- Pontos de Aura persistem após a batalha.
- Aura pode ser recuperada por itens, descansos em locais específicos e habilidades.
- Revivificação restaura uma quantidade reduzida de HP.
- A distribuição de atributos pode ser reiniciada em um local de descanso ao usar um item raro específico.

### Ainda em aberto

- HP atual persiste ou é restaurado ao fim da batalha?
- Os descansos recuperam HP, Aura ou ambos? “Ambos” foi sugerido, mas ainda é provisório.
- Quanto cada tipo de item recupera e quando seu efeito é aplicado?
- O item é consumido na confirmação ou na aplicação do efeito?
- Um item de revivificação consome a ação normalmente? A regra geral diz que o uso de item em combate consome a ação ATB, portanto a leitura atual é que sim, salvo decisão posterior.
- Descansos têm custo, risco, frequência ou consequências narrativas?

---

## 11. Catálogo de fórmulas que ainda não existem

O agente de continuidade deve manter explícito que estas fórmulas estão pendentes. **Não preencher com valores plausíveis como se fossem decisões do usuário.**

1. HP máximo em função de Vitalidade e nível.
2. Capacidade máxima de pontos de Aura em função do atributo Aura.
3. Taxa de preenchimento do ATB em função de Velocidade.
4. Fórmula de chance de esquiva e suas curvas, mantendo a intenção de que ela permaneça baixa no geral.
5. Curvas de retornos decrescentes para todos os atributos.
6. Ordem de cálculo entre atributo-base, pontos alocados, equipamento e efeitos temporários.
7. Fórmulas gerais de dano/mitigação e escalonamento de habilidades.
8. Valores fixos de custo de Aura por habilidade.
9. Fórmula quadrática de XP cumulativa e coeficientes, além de nível máximo.
10. Fórmula operacional de XP individual por contribuição para cada inimigo.
11. Valores de contribuição para buffs, debuffs, controle e efeitos persistentes.
12. Dano, intervalo e duração de estados como Veneno; durações dos demais estados.
13. Chance, duração ou outras regras de resistência parcial.
14. Quantidade restaurada por revivificação e por cada método de recuperação.

Pode ser útil, mais tarde, reunir fórmulas e variáveis em uma especificação matemática separada, com exemplos calculados, assim que o usuário começar a aprovar os parâmetros.

---

## 12. Registro sintético do que é confirmado e do que não é

| Sistema | Confirmado | Provisório ou em aberto |
|---|---|---|
| Conceito | RPG narrativo clássico, 2D top-down, pixel art moderna, PC; overworld, mapas menores e combate. | Motor, tecnologia e detalhes do escopo técnico. |
| Referências | Chrono Trigger e Final Fantasy VII clássico como referências. | Quais convenções específicas serão adotadas fora das regras já decididas. |
| ATB | Preenchimento contínuo, Velocidade influencia ritmo, modo Wait, prioridade automática, ação não interrompível, efeitos resolvidos antes da próxima ação. | Submenus pausados, novos combatentes prontos durante execução, desempate, detalhes da IA. |
| Grupo | Até quatro ativos; personagens de suporte podem executar uma ação sem entrar no grupo. | Custo/limites do suporte; habilidades combinadas adiadas. |
| Recurso | Aura atributo determina capacidade; pontos de Aura são consumíveis; persistem após combate. | Fórmula de capacidade e valores de recuperação. |
| HP/incapacitação | 0 HP incapacita; incapacitados não agem; podem ser revividos. | Persistência de HP, cura pós-combate e valores de revivificação. |
| Atributos | Força, Velocidade, Vitalidade e Aura; inteiros; todos com retornos decrescentes; pontos livres ao subir nível. | Curvas, fórmulas, ordem de modificadores e possível alteração do conjunto de atributos. |
| Equipamento | Modifica atributos, pode ter penalidades/passivos, substitui item do mesmo espaço. | Slots concretos, restrições e valores. |
| XP de combate | XP individual por inimigo, proporcional à contribuição, com regras para dano, cura, proteção, controle e efeitos; fugir elimina toda XP do combate. | Fórmula e valores numéricos da contribuição e distribuição. |
| XP narrativa | Valor fixo por evento; elegibilidade depende do evento. | Critérios de elegibilidade, inclusive personagem ausente/incapacitado. |
| Estados | Duração em turnos/ações do afetado; Sono faz perder oportunidade ATB; Veneno periódico; reaplicação renova sem empilhar intensidade; buffs/debuffs alteram atributos e derivados; imunidade total e parcial; remoção por item, habilidade ou fim natural. | Catálogo completo, periodicidade, resistência parcial, interação entre efeitos, remoção de Sono, detalhes de Paralisia. |
| Narrativa | História e personagens já existem na concepção do usuário. | Seus detalhes não estão neste documento e não devem ser inventados. |

---

## 13. Prioridades sugeridas para continuar o desenvolvimento

A ordem abaixo é uma recomendação de trabalho, não uma decisão mecânica aprovada.

### Etapa A — Fechar a máquina de combate

Esclarecer apenas os pontos que alteram diretamente a resolução: quais menus são pausados pelo Wait; o que ocorre quando outros ATBs enchem durante uma animação; e como solicitar um novo alvo quando todos os alvos originalmente válidos deixam de ser elegíveis. Depois documentar a máquina de estados de uma ação: seleção → alvo → confirmação → execução → aplicação/resolução dos efeitos → reinício do ATB.

### Etapa B — Fechar o modelo mínimo de estados

Definir um catálogo inicial pequeno e útil, com cada estado descrito por: condição de aplicação, atributo/efeito, duração, periodicidade, gatilhos de remoção, imunidades/resistências e contribuição de XP. Dar atenção especial à relação entre o modelo ATB contínuo e a expressão “turnos ou ações do afetado”.

### Etapa C — Definir fórmulas por blocos

Começar pelos derivados essenciais: HP máximo, capacidade máxima de Aura, ATB e esquiva. Em seguida definir a forma dos retornos decrescentes e a ordem dos modificadores. Só depois partir para números finais de dano e habilidade.

### Etapa D — Formalizar contribuição e XP

Traduzir o modelo de contribuição já confirmado em procedimento calculável por personagem e por inimigo. Criar exemplos artificiais para verificar situações de cura, proteção, dano excedente, efeitos persistentes e arredondamento, sem apresentá-los como cânone ou conteúdo narrativo.

### Etapa E — Economia e recuperação

Definir persistência de HP, descanso, consumíveis e revivificação. Preservar a persistência de Aura já confirmada. Verificar os efeitos dessas decisões no ritmo de exploração e na dificuldade entre batalhas.

### Etapa F — Validar com cenários de teste

Antes de implementar um sistema de forma definitiva, testar situações pequenas e mecânicas, por exemplo:

- Vários combatentes ficam prontos enquanto o menu está pausado.
- O alvo de uma habilidade morre antes da aplicação do efeito.
- O executor é derrotado após iniciar uma ação.
- Uma habilidade de área produz dano excedente em um inimigo e dano efetivo em outro.
- Cura ou proteção contribui para XP sem duplicar impacto.
- Um efeito é resistido parcialmente ou negado por imunidade.
- Um personagem dormindo perde a oportunidade ATB e desperta depois.
- O jogador tenta usar uma habilidade sem Aura suficiente e depois cancela uma seleção.

Esses testes devem verificar consistência das regras, não ditar por conta própria valores ou conteúdos de história.

---

## 14. Princípios de design a preservar

- **RPG clássico com espaço para profundidade:** as regras podem ser sistemáticas, mas não precisam ser excessivamente complicadas para o jogador.
- **Combate orientado por tempo e decisões:** ATB, Wait e prioridade automática devem continuar coerentes entre si.
- **Contribuição além de causar dano:** cura, proteção, controle e efeitos úteis fazem parte do modelo de recompensa.
- **Atributos com decisões significativas:** distribuição livre, retornos decrescentes e equipamentos com modificadores positivos ou negativos.
- **Balanceamento baseado em testes:** progressão, curvas e valores podem ser ajustados, mas mudanças precisam manter coerência com o desenho já aprovado.
- **Separação entre autoria e sistematização:** o agente pode estruturar regras e propor mecânicas, mas história, personagens e identidade autoral pertencem ao usuário.
- **Pragmatismo:** adotar propostas convencionais quando ajudarem a avançar, mas sempre rotulá-las e pedir aprovação apenas quando a decisão tiver impacto importante.

---

## 15. Prompt inicial para o próximo agente

Copie o texto abaixo ao iniciar uma nova conversa e forneça este arquivo como contexto.

> Você está assumindo o desenvolvimento de um RPG narrativo clássico concebido pelo usuário. Leia integralmente o arquivo de continuidade antes de propor mudanças. Use-o como registro de decisões, com a distinção obrigatória entre fatos confirmados, propostas provisórias e questões em aberto.
>
> O jogo é um RPG 2D top-down em pixel art moderna para PC, inspirado em Chrono Trigger e Final Fantasy VII clássico. Há overworld em escala reduzida, mapas separados para cidades/dungeons e combate por turnos com ATB em modo Wait. A história e os personagens já foram concebidos pelo usuário, mas não estão detalhados neste arquivo; não invente nada sobre eles.
>
> Preserve todas as regras já confirmadas, principalmente as regras de ATB, Aura como atributo separado dos pontos de Aura consumíveis, progressão/XP individual e cálculo de contribuição para XP. Não invente fórmulas, coeficientes, valores de dano, durações, probabilidades ou níveis máximos. Quando uma regra secundária faltar, use uma convenção clássica como proposta provisória — não como fato — e faça poucas perguntas de alto impacto, pois o usuário prefere um processo pragmático, incremental e sem questionários excessivos.
>
> Continue a especificação de forma organizada. Primeiro identifique os pontos que precisam ser resolvidos para avançar, proponha a solução mais simples e coerente, indique impactos nas regras existentes e espere aprovação para registrar uma sugestão como confirmada. Não apague decisões anteriores nem resolva conflitos silenciosamente. Trabalhe em etapas e valide cada sistema com exemplos mecânicos simples, sem criar narrativa ou personagens.

---

## 16. Nota de completude

Este documento agrega o conhecimento mecânico que está disponível no contexto desta conversa: conceito do jogo, ATB, grupo ativo e suporte, atributos, Aura, equipamento, XP, contribuição para XP, estados de combate, recuperação, propostas e lacunas. A história e os personagens são mencionados como material já pertencente ao usuário, mas seu conteúdo não estava presente no contexto usado para esta compilação. Caso o usuário possua documentos anteriores com a narrativa, habilidades ou outras mecânicas não resumidas aqui, eles devem ser incorporados como fontes adicionais antes de afirmar que esta é uma especificação integral do jogo inteiro.

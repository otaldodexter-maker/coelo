---
title: "Rodada noturna 09→10/09/2026 — relatório ao Owner"
source: "Coordenação e Integração — Claude; entregas dos oito grupos; inventario-etapa-2.json"
status: "em construção — fechado após o corte das 05:00 de 10/09"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Rodada noturna — relatório ao Owner

> Documento vivo. Os números são medidos, datados e reproduzíveis; onde falta
> medição, está escrito que falta.

## Como o trabalho foi verificado

Oito grupos trabalharam em worktrees isoladas a partir da base integrada
`d784462c1`. Todo lote entrou em `dev` por revisão de código mais verificação na
base conjunta, nunca por confiança no relato do autor. O padrão foi medir a mesma
seleção de testes **antes** e **depois** do merge, para separar falha
preexistente de regressão.

O método já evitou três enganos concretos:

- As falhas de golden que três frentes reportaram eram deriva da própria base.
  Reproduzi cada conjunto numa worktree destacada em `d784462c1` intocado e
  encontrei exatamente as mesmas falhas, com os lotes somando apenas casos que
  passam.
- Dois lotes adicionaram, cada um por sua conta, o mesmo parâmetro
  `principalCircularRepository` ao router, ao app, ao auth scope e ao `main`. O
  Git mesclou os dois lados limpo, porque as linhas não se sobrepõem, e só o
  analisador pegou os nove erros. **Merge limpo não é árvore que compila.**
- Três grupos escolheram independentemente o mesmo carimbo de migration, e um
  escolheu carimbos anteriores a migrations já existentes. Worktree separada não
  protege de colisão lógica; a ordem da fila é global e pertence ao integrador.

## Movimento medido da suíte

| Base | Hora | Resultado |
| --- | --- | --- |
| `ecc8eae2b` | 19:30 | 5707 PASS, 9 SKIP, 190 FAIL |
| `414b82b29` | 20:40 | 5871 PASS, 9 SKIP, 182 FAIL — 144 golden, 38 não |
| `b0f816560` | 21:40 | 6811 PASS, 9 SKIP, 156 FAIL — 127 golden, **29 não** |

A rodada somou casos que passam e **reduziu 8 falhas**. Nenhum número soma
reexecuções. O catálogo das 182, por arquivo e por dono, está no
[catálogo de falhas](NOTURNA-catalogo-falhas.md).

O número que importa mais que o total: das 182, **144 são suítes de golden e
apenas 38 não são**. A metade de golden depende da sua decisão de rebaseline, não
de código. Dez das 38 foram recuperadas logo depois dessa medição, com uma linha
por construção de router numa flag que voltou a ser necessária desde
`b20a9c205`.

## Conclusão certificada

| Camada | Antes | Agora |
| --- | --- | --- |
| Front-end `verified` | 7/230 | 11/230 |
| Back-end `done` | 0/223 | 0/223 |
| Integração `verified-e2e` | 0/198 | 0/198 |

Backend e integração não se moveram, e isso é esperado: **nada foi aplicado em
ambiente remoto**. O projeto Supabase `coelo` e os buckets R2 são produção, e
você ficou indisponível a partir das 18:26, portanto nenhuma autorização nominal
pôde ser concedida. Nenhuma rota rodou contra Supabase autenticado, e prova local
não promove E2E.

O que avançou além dos quatro certificados foi a honestidade do resto. Os
bloqueios agora estão separados entre `blocked-decision`, onde falta uma decisão
sua, e `blocked-environment`, onde o pacote está revisável e só falta a aplicação
remota que esta rodada proibiu.

## O defeito mais grave encontrado: Segurança infantil não se dispõe em produção

Duas frentes mediram `/safety` de forma independente, e o diagnóstico mais
preciso mudou a categoria do problema. **Não é transbordamento: a grade de
cartões não se dispõe.** São vinte exceções de layout por largura, encabeçadas
por `LayoutBuilder does not support returning intrinsic dimensions` com
`IntrinsicHeight` como causador, seguidas de dezenove `RenderBox was not laid
out` em cascata.

A cadeia está rastreada até o fim: `safety_pages.dart:292` envolve cada linha da
grade em `IntrinsicHeight`; o cartão é `SafetyChildDirectoryCard`, que retorna
`CoeloAdminInteractiveCard`, que contém `CoeloAdminExpandableStatusIndicator`, e
esse é literalmente um `LayoutBuilder` na linha 42 do pacote. `IntrinsicHeight`
pergunta dimensões intrínsecas; `LayoutBuilder` não sabe responder; a asserção
dispara.

**E isso alcança produção.** `childSafetyRepository` é composto como
`SupabaseChildSafetyRepository` real, o controlador é construído em
`superadmin_app.dart:231`, a rota produtiva `/safety` monta `SafetyLandingPage`
com ele, e o modo de exibição padrão é cartões. Basta existir um registro para a
tela quebrar no primeiro carregamento. Não é protótipo com defeito: é MVP, com
repositório de produção ligado, sobre dados de criança.

Duas correções possíveis, e a escolha é sua com o `coelo-ui`: contida em
`safety`, deixando de envolver a linha em `IntrinsicHeight`; ou no componente
compartilhado, tirando o `LayoutBuilder` do indicador, o que resolve para todo
consumidor mas mexe no Design System e move goldens de outras telas. A primeira
está atribuída para execução; a segunda fica registrada, porque qualquer tela
que um dia envolver esse indicador em `IntrinsicHeight` cai no mesmo buraco.

A divergência de medição sobre acessibilidade nesta tela terminou num terceiro
lugar, e é o mais honesto: **nenhuma das duas medições vale**. Uma frente
reportou as três diretrizes reprovando, a outra reportou duas passando — e a
segunda foi verificar e mostrou que a asserção de layout dispara durante
`performLayout`, antes de qualquer avaliação. Mesmo drenando as exceções à mão, a
árvore de render continua marcada `NEEDS-LAYOUT`, então a semântica avaliada em
cima dela não representa a tela. Um alvo que não foi disposto pode medir zero e
reprovar, ou não ser visitado e passar: as duas coisas são artefato do mesmo
defeito.

Registro portanto a acessibilidade de `child_safety` como **não medida**, com o
motivo, a ser remedida depois da correção de layout.

E isso fecha as três observações iniciais sobre a tela — transborda, falha nas
três diretrizes, fica presa carregando — como **três sintomas da mesma causa**,
e a causa é uma linha. Não é uma tela com três problemas independentes; é uma
tela que não renderiza. A prioridade continua a mesma; a natureza do trabalho
não.

## O achado mais importante da rodada

Uma frente entregou 61 testes verdes de Suporte e reportou aceite funcional
exercitado. Depois voltou por conta própria, contra o próprio número e com o
delta já aplicado, para corrigir: **Suporte não tem camada de dados**. A pasta
tem apenas domain e presentation, sem data, sem repositório, sem sequer uma
interface, e nada em packages define SupportTicket. Em produção a rota nem abre:
nenhum ponto de composição injeta o controlador e o router devolve 503. Os 61
casos exercitavam um controlador de protótipo em memória.

Verde sobre protótipo não é verde sobre produção. A partir dessa correção, toda
promoção de estado passou a exigir três respostas por escrito: main.dart compõe o
caminho? o router monta a página produtiva? existe implementação de produção do
repositório, e não só a interface?

**Em menos de uma hora a mesma pergunta pegou mais três casos independentes**, e
é esse resultado que muda o significado do painel:

- `forms.respond`: a rota constrói a página sem api e descartando o
  `:occurrenceId` que o próprio path declara. A correção de limites numéricos
  está provada no widget e não é alcançável pela rota produtiva.
- `health-care` e `medication`: a rota produtiva monta o controlador com
  `UnavailableHealthCareRepository`, e o escopo autenticado injeta
  `UnavailableMedicationPlanRepository`. Não existe implementação Supabase de
  nenhum dos dois. Os 182 PASS de um e os 39 do outro são verdes sobre fixture.
- `daily_routine`: `RoutineRepository` só tem implementação Development e
  Unavailable.

E um caso pior que o de Suporte: em `attendance` a camada de dados **existe em
Dart, está ligada, e chama funções que não existem no servidor**. As RPCs
`superadmin_attendance_*` não aparecem em nenhuma das 173 migrations vivas, só em
`.recovery-archives`. Só não quebra porque a rota está fechada.

## O padrão que apareceu quatro vezes: cobertura que não cobre

Não é um defeito, é a forma de vários deles, e muda o que o painel significa:

- O teste de acessibilidade do shell verifica rótulo e **não verifica tamanho de
  alvo**. O shell tem teste de acessibilidade — e o app inteiro está sem essa
  verificação. O botão do menu do usuário expõe 44 px contra os 48 exigidos, mas
  **o item não é os 4 px, é a diretriz que nunca foi aplicada ali**.
- A Agenda tem um teste chamado "matriz a 200 por cento funciona em claro e
  escuro", verde, enquanto o calendário no shell a 375 transborda a 100%. O
  teste cobre outra superfície.
- Minha conta tem golden que amarra tema à largura — claro só abaixo de 1024,
  escuro só acima — então metade da matriz visual nunca foi renderizada.
- `errors.409` era cobrado por um golden cujo arquivo de referência nunca
  existiu.

E a variante mais cara, que apareceu quatro vezes em telas diferentes: **verde
sobre protótipo não é verde sobre produção**. Suporte, `forms.respond`,
`health-care` com `medication`, e `daily_routine` têm suítes verdes sobre
repositórios que não existem em produção.

## O problema não é falta de conhecimento no time

Este é o enquadramento que eu levaria primeiro, se você só lesse um parágrafo.

Os dois defeitos estruturais encontrados hoje **já tinham sido resolvidos neste
mesmo codebase**, em telas diferentes, por gente diferente, e nos dois casos com
um comentário explicando a razão:

- O controller que morre antes da transição de fechamento: Rotina tinha o
  defeito; `access_profiles` já o havia resolvido com um `DialogRoute` próprio
  que espera `route.completed`, com o comentário "The text controller must
  outlive the closing transition".
- O `IntrinsicHeight` sobre um `LayoutBuilder`: `safety` quebra por isso;
  `access_profiles` já o havia resolvido com `Table`, com o comentário dizendo
  que o status canônico usa `LayoutBuilder` e não pode participar de
  `IntrinsicHeight`.

Os defeitos que sobraram estão exatamente onde a solução existente não foi
transplantada. Isso é mais acionável que uma lista de bugs: **o problema não é
falta de conhecimento no time, é o conhecimento não chegar a todas as telas.**

## O censo de `IntrinsicHeight`

Vale como exemplo do que uma varredura barata entrega. Há exatamente quatro usos
em `apps/superadmin`, e os quatro estados diferentes contam a história inteira:

- `access_profiles` **já bateu neste defeito, resolveu com `Table`** e deixou na
  linha 633 um comentário dizendo que o status canônico usa `LayoutBuilder` e não
  pode participar de `IntrinsicHeight`.
- `errors` é seguro: envolve apenas `Text` e `VerticalDivider`.
- `people` tem o padrão **idêntico** ao de `safety` e só não quebra porque o
  cartão de lá usa indicador próprio em vez do canônico. É uma armadilha armada:
  no dia em que alguém padronizar o indicador, quebra na hora.
- `safety` é a única vítima.

É o argumento mais forte para tirar o `LayoutBuilder` do componente
compartilhado, em vez de corrigir só a tela que quebrou.

## Decisões que dependem de você

1. **Goldens: uma mudança global de renderização, e não 144 telas redesenhadas.**
   Esta seção foi reescrita três vezes esta noite, e é a terceira leitura que a
   medição sustenta. Primeiro tratei tudo como deriva de ambiente; depois a
   magnitude — 21 de 28 comparações acima de 8%, máximo de 43,94% — me fez
   registrar que a população grande "só podia ser mudança visual real nunca
   reaprovada". Uma frente foi mais fundo, escreveu um decodificador de PNG e
   comparou master contra teste pixel a pixel, e desmontou a minha própria
   conclusão com três fatos medidos:

   - Em **355 pares comparados a dimensão da tela é idêntica em 100% deles**.
     Nenhum golden falha porque a tela mudou de tamanho.
   - Nas falhas grandes a diferença está **espalhada por quase toda a
     superfície**: em `forms_editor_dark_375`, 43,94% dos pixels atingindo 93,9%
     das linhas e 91,5% das colunas. Em `access_profile_cards_dark_375`, 91,90%
     dos pixels atingindo **100% das linhas e 100% das colunas**. Mudança de
     conteúdo atinge uma faixa, não a imagem inteira nos dois eixos.
   - A diferença **correlaciona com a largura**, na mesma tela e no mesmo
     estado: `forms_editor_light` dá 38,99% em 375, 14,38% em 768, 8,38% em 1440
     e 3,88% em 1024. Uma tela redesenhada não muda de gravidade conforme o
     viewport; uma mudança de métrica de texto muda, porque em 375 o texto quebra
     apertado, um delta mínimo reflui a coluna inteira e cascateia.

   O mesmo gradiente aparece em **quatro** features independentes, de donos
   diferentes, três delas intocadas por quem mediu. E o refinamento é mais forte
   que a confirmação cega: a assinatura de gradiente aparece nas quatro, mas a
   **magnitude escala com a densidade da tela**. Diretórios administrativos
   densos explodem — `access_profile_cards_dark_375` em 91,90%,
   `group_directory_cards_dark_375` em 17,37% — enquanto um feed do Principal,
   com poucos elementos grandes, quase não muda:
   `principal_happens dark_375` em 0,63%, caindo a 0,15% em 1440, na mesma ordem
   por largura. É exatamente o que uma mudança de métrica de renderização prevê,
   e encaixa com o harness carregar ícones do SDK local: tela com muito texto e
   muitos ícones sofre muito, tela com poucos sofre pouco.

   A causa provável está verificada e é simples: **não existe ambiente de
   referência fixado**. O `pubspec.yaml` declara `flutter: ">=3.38.0"` sem limite
   superior, não há `.fvmrc` nem `.tool-versions`, **não há CI** — nenhum golden
   foi gravado em ambiente controlado — e o histórico mostra que as referências
   foram atualizadas por commits locais comuns, o último em 01/09. A referência
   visual do projeto é comparada contra o que a máquina do momento tiver. **Isso muda a decisão de
   auditoria para decisão única:** você não precisa investigar 144 telas para
   descobrir o que mudou em cada uma. Precisa identificar a mudança de ambiente
   ou de toolchain entre `f71b6a9c5` e hoje, e reaprovar as referências em bloco.

   E a consequência que mais importa para o painel: **enquanto a referência não
   for reaprovada, todo golden do repositório está cego**. Não é só que 144 estão
   vermelhos — é que os verdes também não provam nada sobre aparência, porque a
   base de comparação não corresponde ao ambiente atual.

   Nenhuma imagem foi regravada fora do critério acordado. A causa raiz não foi
   identificada: o que está medido é dispersão, gradiente por largura e dimensão
   idêntica.
1b. **Pinar o SDK antes de regravar qualquer golden.** Uma frente foi atrás da
   causa e eu confirmei por conta própria no código: as suítes de golden carregam
   `MaterialIcons` do SDK **local**, por caminho relativo a
   `Platform.resolvedExecutable`, enquanto a Nunito Sans vem do repositório. E o
   `pubspec.yaml` declara só um piso, `flutter: ">=3.38.0"`, sem `.fvmrc`, sem
   `.flutter-version` e sem nenhum registro de qual SDK gravou as baselines. As
   referências estão presas a um SDK que o repositório não registra, então
   qualquer máquina em outro Flutter falha em bloco sem que feature nenhuma tenha
   causado nada. **Regravar sem pinar só transfere a deriva para a próxima
   máquina.** A ressalva do autor, que eu mantenho: vendorizar a fonte de ícones
   remove uma das duas variáveis, não as duas — o fantasma aparece também no
   texto em Nunito Sans, que já vem do repositório, então o rasterizador do
   engine também difere. Ambiente desta rodada: Flutter 3.44.2 stable, framework
   c9a6c48423, engine 04efd7c093, Dart 3.12.2, Windows.
2. **Baseline visual de `errors.409`**, que nunca existiu.
3. **Visibilidade do leitor Principal no Sobre.** Não existe token de leitura em
   `profiles.about.*`, apenas manage, publish e update_official_data.
4. **Contraste do chip DESTAQUE em Para Você:** 3,75:1 contra o mínimo AA de
   4,5:1 para 11 px. Corrigir altera composição aprovada e move 20 goldens.
5. **Contrato visual de Editar perfil.**
6. **Contrato de UX de Lançamentos** (`daily-routine.publish`): o comando existe,
   a tela não, e a spec 021 não cobre Lançamentos.
7. **Rota Testar de Formulários** como superfície de leitura autorizada: hoje é
   mantida sem leitura por um contrato de teste verde e deliberado.
8. **Navegação no editor de Rotina:** habilitar a guarda de saída pela barra
   lateral faz o shell desenhar sua navegação e move seis goldens. É decisão
   visual, não de fiação.
9. **Suporte entra no MVP?** Hoje não existe backend nenhum.
10. **Preflight de leitura em produção** para confirmar se as RPCs internas
    existem. A baseline `20260901101500` insere permissão sem os rótulos que
    passaram a ser NOT NULL: ou ela nunca aplicou, e o realm interno inteiro
    falha fechado contra gateway inexistente, ou alguém a ajustou fora do
    repositório. Não é distinguível sem acesso de leitura autorizado.
11. **Autorizações remotas nominais** para os pacotes preparados nesta rodada.

## Pacotes remotos preparados e não aplicados

Ver [fila SQL serializada](NOTURNA-fila-sql-serializada.md), com a ordem
atribuída, os carimbos originais que os manifests dos grupos ainda citam, e o
hash que prova que só o nome mudou.

## Achados transversais distribuídos

- **Idempotência de escrita:** 13 sítios geram a chave inline, então o cliente
  perde a capacidade de repetir a mesma intenção. Publicação e criação são os
  casos graves, porque não há revisão esperada barrando a repetição.
- **Catálogo:** 16 divergências, contra 14 registradas. A ferramenta usa o mesmo
  caminho como entrada e saída, então regenerar o relatório versionado não
  subnotifica: **apaga o aviso** e deixa o catálogo verde no app com as 16
  divergências intactas no código.
- **Badge de não lidas:** medido, sem efeito observável em nenhuma rota de
  produção. Sai da fila um refactor de 44 arquivos.
- **Captura estreita de exceções:** repositórios que só capturavam
  `PostgrestException` deixavam falha de transporte escapar crua até a UI.
- **Guarda de mutação:** o risco real não é a chamada sem argumento, é alguém
  **adicionar** um ramo `/attendance` por simetria com invites, notices e
  circulars. O repositório injetado é real, então o ramo abriria as rotas contra
  RPCs que não existem.

## A classe de geometria fixa

Quatro telas transbordam porque a moldura não cresce: o cartão do diretório de
Planos tem `mainAxisExtent` fixo, a célula de Cardápios tem proporção quadrada, a
célula do calendário da Agenda tem altura fixa, e a tabela administrativa não rola
na vertical. Não é falta de `Flexible` num rótulo — esse caso existia e foi
corrigido em Planos, sem mudar nada a 100%.

Duas medições impedem a leitura confortável de que isso é problema de dados de
teste:

- Com a composição **padrão**, que é fail-closed e não injeta repositório nenhum,
  as oito rotas de produção passam a 100% em 375 e 1440 — 16 de 16. A 200%, duas
  falham. **Cardápios transborda os mesmos 37 pixels com e sem dados**, o que
  prova que a causa é a moldura e não o conteúdo.
- A Agenda a 375 transborda com texto a **100%**, no estado padrão de um
  telefone. Autorizei estender a adaptação que a própria tela já tinha
  (`occurrences.take(largeText ? 1 : 2)`) para largura estreita; foi medido e
  **não resolveu**: nem o número do dia com uma única marca cabe nos 39,6 de
  altura que o shell deixa. A alteração foi revertida em vez de escalar para
  geometria. A decisão volta a ser sua, e é a mais severa das quatro porque
  ocorre sem o usuário ampliar nada.

## Acessibilidade medida pelas diretrizes nativas

Depois de corrigido o instrumento, as reprovações reais de diretriz no app são
**13 e não 18**: sete de rótulo — todas já corrigidas por uma única linha —,
cinco de tamanho de alvo, e uma de contraste. A de contraste é o selo DESTAQUE
em Para Você, com razão 3,75 contra os 4,5 exigidos para 11 px, e é real.

`/dev/imports` reprova apenas **tamanho de alvo**, e não as três: rótulo e
contraste eram contaminação do transbordamento da própria tela.

Um candidato ficou sem identificação e está registrado como candidato, não como
defeito: um nó de 128×48 no cabeçalho de quatro telas expõe apenas `longPress`
sem rótulo. Sete hipóteses foram descartadas, seis delas por teste isolado, e o
nó só aparece na composição completa pelo router — nunca nos componentes
isolados. Quem retomar deve atacar pela composição.

## Duas decisões de componente e uma de segurança

**Tabela administrativa redimensionável.** O `SingleChildScrollView` de
`CoeloAdminResizableTable._tableBody` rola apenas na horizontal, então a coluna
que empilha cabeçalho e linhas não tem para onde rolar na vertical. A aritmética
fecha exatamente com o overflow relatado: 56 de cabeçalho mais 25 linhas de 65
dá 1681, contra 612 de altura disponível, o que produz os 1069 pixels. **As
linhas abaixo do corte não estão clipadas, estão inalcançáveis.** Não corrigi e
proibi a alternativa barata de limitar as linhas da tela de Importações: fechar a
suíte escondendo um defeito de acessibilidade real seria pior que a suíte
vermelha. A correção verdadeira exige sincronizar dois eixos entre corpo e coluna
fixada num Stack com posicionamento absoluto, atinge todos os diretórios
administrativos e é autoridade de `coelo-ui`. É decisão sua.

**Exposição de bucket e chave (severidade baixa, mas contraria a ADR 0032).**
`public.authorize_circular_media_read` está no grant para `authenticated` e
devolve `bucket_id` e `object_key`. Precisa ser chamável pelo usuário porque a
Edge Function usa o cliente dele para autorizar antes de assinar. Não concede
acesso — o bucket é privado e sem assinatura nada se lê — mas a ADR 0032 diz
para nunca expor bucket, chave ou provedor ao cliente. A correção seria devolver
um identificador opaco, o que muda o contrato entre a RPC e a Edge Function e
entra na fila SQL com autorização nominal. Nada foi aplicado.

**Redação corrigida no rastreador.** O inventário registrava
`save_circular_response_draft`, `submit_circular_response` e `delete_circular`
como ausentes no gateway. É verdade para o gateway administrativo v2 e falso
para o caminho Principal: as nove RPCs que os repositórios do Principal chamam
estão definidas em `20260821190000_circulars_production.sql`, com `revoke all`
seguido de grant a `authenticated`, 28 funções `security definer` e 29 com
`search_path` vazio. Isso prova **definição local, não aplicação remota** — a
lacuna muda de redação, não de estado.

## Verificações positivas registradas

O registro do que **não** é problema evita que o próximo revisor gaste o mesmo
tempo:

- O `file_picker` com leitura de bytes reais existe no assistente de importação,
  o que pareceria contrariar a política de importação adiada. Não contraria: a
  rota só monta o assistente sob a guarda de capacidade e a composição produtiva
  injeta o repositório indisponível nos dois pontos. Fail-closed em duas camadas,
  e o picker só vive em `/dev`.
- Acontece e Agora foram verificados contra o mesmo padrão de perda que atingiu
  Momentos, e já têm embedded e mediaPicker convivendo.
- `attendance.correct` e `attendance.finish` não têm lacuna de cliente: o
  conflito de versão tem exceção tipada, tratamento e dois testes.

## Higiene e preservação

- Os 90 artefatos de WIP ignorados na raiz do checkout integrador estão
  preservados por caminho e SHA256 em [manifesto](NOTURNA-wip-raiz-manifest.txt).
  Nada foi apagado.
- Os PNGs sob `test/**/failures/` ficam fora do índice: são diffs regenerados a
  cada execução e, rastreados, fazem qualquer frente aparecer no fechamento com
  alterações que não são trabalho.

## O que ainda falta

Preenchido no fechamento, após o corte das 05:00.

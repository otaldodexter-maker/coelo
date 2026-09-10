---
title: "Decisão do Owner — três ações de Circulares sem afordância"
source: "Varredura de 25 métodos de interface das famílias acontece, agora, momentos e circulars contra consumidores em presentation, application e app; rodada noturna de 09-10/09/2026"
status: "decision-request; nenhuma tela nova criada; nenhuma mutação remota executada"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Três ações de Circulares que existem no backend e não existem na tela

Este documento junta **uma** decisão em vez de três perguntas soltas. As três
ações compartilham a mesma causa: caminho completo do banco até o repositório,
sem nenhuma afordância que as acione.

Uma delas já foi corrigida nesta rodada; as outras duas dependem de decisão.

## O que existe hoje, ação por ação

| Ação | RPC no gateway v2 | Método no repositório | Afordância na tela |
| --- | --- | --- | --- |
| `circulars.attach` | sim | sim | **corrigido em `4e825eef5`** |
| `circulars.close` | `superadmin_circular_close_v2` | `closeResponses`, implementado em 4 lugares | **nenhuma** |
| `circulars.delete` | **nenhuma** | existe fora da interface, sem consumidor | **nenhuma** |

`circulars.attach` era o caso mais barato: o botão existia e apenas anunciava
que o envio "seria habilitado depois". Hoje seleciona arquivo, envia pelo
caminho de mídia e reporta falha honestamente.

`circulars.close` é o caso mais frustrante: tudo pronto, ninguém consegue
acionar.

Sobre `circulars.delete`, uma precisão que corrige uma afirmação anterior minha:
não é verdade que não exista método de repositório. `SupabaseCircularRepository`
tem um `delete` completo, que chama `public.delete_circular` com requisição,
identificador e versão esperada. O que não existe é declaração desse método na
interface `CircularRepository`, nem qualquer consumidor, nem RPC no gateway
administrativo v2 — que tem sete funções e nenhuma de exclusão.

Isso barateia a opção completa: o caminho de dados do lado do Principal já está
escrito. O que falta do lado administrativo continua sendo a RPC de gateway com
capacidade própria.

## Por que não foram implementadas de madrugada

O portão de mutação de produção do router é baseado em **localização**:
`_isProductionMutationLocation` olha o caminho da rota e libera ou bloqueia.
Um botão "Encerrar" no leitor `/circulars/:circularId/read` seria uma mutação
numa rota de leitura, portanto fora do portão.

Isso **não** seria inseguro: a RPC exige a capacidade
`circulars.circulars.manage` no servidor, e o cliente nunca é a fronteira de
autorização. Seria, porém, a única mutação do produto fora do portão — uma
inconsistência de arquitetura introduzida sem revisão.

Há uma pista do desenho pretendido: o portão **já reconhece** caminhos
terminados em `/manage`. Mas a pista cobre a **rota**, não a **tela**. Decidir
o que essa tela mostra é composição visual, autoridade do `coelo-ui` e decisão
do Owner.

## O que a opção completa exigiria

Se o Owner aprovar, o caminho é este e não precisa de descoberta adicional:

1. **Rota** `/circulars/:circularId/manage`, já reconhecida pelo portão de
   mutação, portanto sujeita à checagem de capacidade como as demais.
2. **Tela** com o mínimo para decidir: título, contexto, estado atual e o
   resumo de respostas — que passou a existir no leitor em `536b1f222` e pode
   ser reaproveitado sem nada novo.
3. **Ações** na tela:
   - *Encerrar respostas*, com confirmação, versão otimista e recarga. Usa
     `closeResponses`, que já existe nas quatro implementações.
   - *Excluir*, **se** o Owner decidir que exclusão lógica administrativa entra
     no MVP. Esta é a única que exige trabalho novo de backend: uma RPC de
     gateway v2 com capacidade própria, porque `public.delete_circular` hoje
     pertence ao caminho do Principal.
4. **Auditoria**: `close_circular_responses` já registra; a exclusão precisaria
   do equivalente antes de existir.

## As três perguntas, em uma

1. Encerrar respostas entra pela rota `/manage` dedicada, como o portão sugere?
2. Exclusão lógica administrativa entra no MVP, ou fica adiada como importação
   e exportação?
3. Se entrar, a tela `/manage` reúne as duas ações, ou a exclusão fica em outro
   lugar?

Respondidas as três, a implementação é direta e não depende de mais nada.

## O que NÃO está sendo pedido

Não se pede redesenho de Circulares. Título, texto, anexos, perguntas,
políticas de resposta, revisão, agendamento e público já estão definidos, e a
confirmação visual do shell foi resolvida pelo Owner em 09/09/2026.

## Quarta decisão, da mesma família: o teto do feed de Acontece

O feed misto lê **uma** página de 20 itens e descarta o cursor que o servidor
devolve. A capacidade de paginação existe pronta nas duas pontas: a RPC
`list_visible_happens_feed` aceita cursor e o repositório já o monta quando a
página vem cheia. A tela simplesmente não a consome.

O efeito não é apenas "não dá para ver o que é antigo". O feed é **misto**: une
publicações e Circulares numa ordenação única por data. Com teto de 20 no total
e sem paginação, uma sequência de publicações empurra as Circulares para fora
da primeira página — e uma Circular publicada há pouco fica **invisível** no
Acontece, sem aviso.

Não foi corrigido aqui porque a correção é afordância de carregar mais ou
rolagem infinita, composição visual do Coelo Principal com referências
aprovadas e goldens existentes. Diferente do diretório de Circulares, onde o
hospedeiro apenas entregava a lista a uma página que já paginava sozinha e por
isso deu para corrigir sem tocar composição.

A pergunta: o feed pagina por rolagem, por botão, ou o teto de 20 é decisão
consciente de MVP? Se for consciente, ainda vale registrar que Circulares
competem com publicações pelo mesmo teto.

## Quinta decisão: agendar Circular está desabilitado em toda parte

A seção **Agendamento** existe no compositor, com o botão "Escolher data e
hora" e o subtítulo que muda quando há publicação futura. O botão está
**desabilitado**, e honestamente: `onPressed` é nulo quando nenhum host fornece
o seletor. Nenhum host fornece — nem o produtivo nem o de desenvolvimento.

O resto do caminho está pronto: o compositor guarda `_publishAt`, passa
`controller.publish(publishAt: _publishAt)`, e
`superadmin_circular_publish_v2` aceita o `timestamptz`.

O que falta é uma decisão pequena de UX, não código. O compositor espera
`Future<DateTime?> Function()`, ou seja, um **diálogo** que devolve a escolha.
O componente da casa é `CoeloDateTimeField`, usado pelas publicações de
Acontece e de Agora, mas ele é um **campo inline**, não um diálogo. Então:

- envolver `CoeloDateTimeField` num diálogo introduz um padrão que hoje não
  existe no produto; ou
- trocar o botão por um campo inline, como nas publicações irmãs, altera a
  composição aprovada do compositor.

Não há golden do compositor, então qualquer das duas é tecnicamente barata. A
escolha é de linguagem visual, não de custo.

## Sexta decisão: uma tela inteira sem rota

`PrincipalCircularComposerPage` tem 750 linhas em `lib` e 238 de teste próprio.
As únicas referências a ela em `lib` são as cinco dentro do seu próprio
arquivo. **Nenhuma rota, nenhum host, nenhum ponto de composição a constrói.**

O custo não é o código parado. A suíte dela passa para sempre, então ela conta
como área coberta e saudável; e quem lê conclui que existe um compositor de
Circular na superfície do Principal, quando o que está roteado é o
`SuperadminCircularComposerPage`, administrativo.

Não foi removida porque, diferente do contrato órfão de retirada — onde havia
dois contratos vivos para a mesma coisa e um estava ligado — aqui há uma tela
sozinha, e não dá para distinguir código morto de tela preparada para uma
superfície ainda não roteada.

A pergunta: existe um compositor de Circular na superfície do Coelo Principal,
ou compor Circular é ação exclusivamente administrativa? Se for exclusivamente
administrativa, a tela e seus testes saem. Se não for, falta a rota — e aí é
trabalho, não lixo.

## Sétima decisão: abas do Perfil implementadas duas vezes

`PrincipalProfileContentTabs`, com o enum `PrincipalProfileContentTab`, vive em
`principal_circulars/presentation/principal_circular_surfaces.dart` e tem
**zero** consumidores em `lib`. Tem dois em `test`, e um deles é o golden — ou
seja, existe **referência visual aprovada** para um componente que ninguém vê
no produto.

E é duplicata: `principal_profile_preview_page.dart` traz a sua própria
implementação privada das mesmas abas, com o enum `_ProfileTab` e o widget
`_ProfileTabButton`, nos mesmos quatro destinos e com as mesmas etiquetas. Essa
é a que está ligada.

Pior que código morto comum: quem for mexer nas abas encontra primeiro a versão
pública, com nome claro e golden, e conclui que é a canônica. Mexer nela não
muda nada no produto e o golden segue verde, então o engano só aparece quando
alguém abre a tela.

Cruza territórios: `principal_circulars` e `principal_profile` pertencem a
grupos diferentes. Qual sobrevive não é decisão de um executor — e a resposta
provavelmente contraria a intuição, porque a viva é a privada e a com prova
visual é a morta.

## Oitava decisão: telas produtivas dizem ao usuário que ele está numa prévia

Seis mensagens em três superfícies do Principal afirmam um contexto que não é o
da tela: `principal_happens_preview_page` (281, 1323, 1661),
`principal_now_preview_page` (327, 343) e `principal_moments_preview_page`
(242). Os textos falam em "indisponível nesta prévia" e "estará disponível na
experiência completa".

Essas páginas **são** as rotas produtivas hoje. Na tela real, tocar em responder
no Agora informa que a resposta está indisponível "nesta prévia". Não é apenas
afordância inerte: é o produto dizendo à pessoa que ela está olhando um rascunho
dele.

Há precedente contraditório dentro do repositório:
`principal_profile_route_page_test` exige que "experiência completa" **não**
apareça na rota real, enquanto `principal_for_you_route_responsive_test` espera
que apareça. Duas superfícies Principal, duas decisões contrárias.

Duas saídas, e a escolha é uma só para todas: ou a ação some quando não há
capacidade, como a galeria do Acontece já faz com compartilhar e salvar; ou a
mensagem passa a ser verdadeira nos dois contextos, sem afirmar prévia.

Não foi corrigido aqui porque são seis textos em três features e quatro testes
que travam as frases exatas, um deles em `principal_for_you`, de outro grupo.
Corrigir só uma superfície troca um defeito por uma inconsistência.

## Padrão, não acidente

O padrão apareceu por três ângulos nesta rodada, e vale registrar como um só:

1. **O dado existe e nenhuma tela o alcança** — `closeResponses` implementada em
   quatro lugares sem afordância; o resumo de respostas com RPC, método e teste
   e nenhum consumidor, corrigido em `536b1f222`.
2. **A tela existe e não alcança o dado** — o leitor administrativo recebia o
   repositório pelo tipo mais estreito, o que tornava a chamada impossível mesmo
   com a instância certa injetada.
3. **A tela existe e ninguém alcança a tela** — `PrincipalCircularComposerPage`,
   750 linhas com teste e sem rota.

Nos três, tudo passa: análise limpa, suíte verde, nenhum alarme. O que falta é
sempre a ligação, e ligação não falha em teste — ela simplesmente não existe.

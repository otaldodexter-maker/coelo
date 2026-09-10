---
title: "Entrega do grupo operacoes-sistema — rodada noturna 09/10 de setembro"
source: "trabalho proprio sobre a base d784462c1, branch work/etapa2-noturna-operacoes-sistema"
status: "documento vivo; atualizado ate a pre-entrega das 04:50"
generated_at: "2026-09-09"
last_update: "2026-09-10 01:50 (America/Sao_Paulo)"
group: "operacoes-sistema"
---

# Entrega — operacoes-sistema

Recorte: `auth`, `shell`, `agenda`, `imports`, `audit`, `support`, `account`,
`catalog`, `plans`, `meal_plans`, `error_pages`. 61 IDs, mapeados no inventário
sem reauditoria. Nenhum arquivo reservado foi escrito: router, migrations
aplicadas, plataforma de mídia, inventário e os três rastreadores permanecem do
coordenador.

## Correções entregues

| Commit | O que fecha |
| --- | --- |
| `1ac657de6` | Cardápios: a intenção de escrita sobrevive ao recibo divergente; validação de recibo num ponto único; `submitForReview` coberto junto. |
| `5f42fbcbd` | Planos: o diretório fecha em erro quando a falha não é do repositório. |
| `01081d3fc` | Planos: `_rpc` passa a tipar falha de transporte — causa raiz do anterior. |
| `585351fec` | Planos: o formulário fecha em erro quando o payload é inválido. |
| `29fa6ff13` | Agenda: intenção idempotente nos três comandos e falha de transporte fechada. |
| `f07545d35` | Cardápios/mídia: transporte fechado nos três métodos, com validação preservada; primeiro arquivo de teste do repositório. |
| `ac3238f7c` | Planos: o rótulo da métrica encolhe a 150% e 200%. |
| `0626c7655` | Páginas de erro: os goldens 409 ausentes viram skip com motivo, em vez de vermelho permanente. |
| `ef4b423a8`, `153b2dbfa` | Cinco suítes de rota recuperadas, 19 falhas ao todo. |
| `9a074a05c` | 96 artefatos de diff de golden destrackeados; a worktree deixa de sujar. |
| `458277400` | Minha conta: 32 casos cobrindo largura × tema × escala. |
| `94465f9c3` | Agenda: reprodução do transbordamento a 375 preservada como skip, com o resultado negativo da correção tentada. |
| `87de5d09e` | Auto-revisão do meu próprio diff de Agenda, antes do review. |
| `7b553ab75` | Hunk do router para a guarda de tenant de Cardápios — aplicado pelo coordenador em `59c842b32`. |
| `179a54532` | Nome acessível na região de long-press do toggle compartilhado: sete telas de cinco donos saem da reprovação. |
| `dfd39b8e8` | **Correção da regressão que `179a54532` causou.** Quem integrar o primeiro precisa integrar este. |

## Medições publicadas

| Relatório | Resultado |
| --- | --- |
| Censo de goldens | 226 PASS, 6 SKIP, 151 FAIL em 49 suítes, 27 features. |
| Catálogo | 16 divergências reais, não 14; e a armadilha que apaga o aviso. |
| Idempotência de escrita | 13 sítios fora do recorte, por dono. |
| Composição de produção | Suporte sem camada de dados; `account.profile` só em `/dev`; `account.sessions` sem tela. |
| Overflow da tabela admin | Causa raiz nomeada; linhas inalcançáveis, não clipadas. |
| Texto a 200% | Quatro telas falham; nenhuma largura sozinha acharia as três novas. |
| Diretrizes a11y do Flutter, app inteiro | 13 reprovações reais, não 18; `/dev/safety` tem zero. |
| Reflow no app inteiro | 61 de 66 a 100%, 59 de 66 a 200%; problema concentrado em 4 telas. |
| Alvos menores que 48 | Três causas, duas compartilhadas; hunk de shell pronto. |
| Captura estreita de transporte | Oito arquivos, lista precisa, por dono. |

## Entregas transversais, fora do recorte

Duas varreduras usando instrumento que só existia aqui, entregues por dono e sem
alterar nada fora de `operacoes-sistema`:
`E2-noturna-transversal-por-dono-20260909.md`.

A primeira versão do instrumento de acessibilidade usava `pumpAndSettle`, que
nunca assenta com `CircularProgressIndicator` em tela. `/dev/safety` expirava
depois de cinco minutos e teria sido entregue como não avaliada — justamente a
tela que, medida com pumps limitados, falha nas três diretrizes. Refazer o
instrumento antes de entregar evitou imputar falha a telas nunca avaliadas e
revelou o achado mais grave da varredura.

## A regressão que eu causei, e como apareceu

`179a54532` corrigiu a diretriz de rótulo em sete telas e **quebrou quatro testes
em duas outras áreas**. `Semantics` sem `container` não cria nó próprio: anexa o
rótulo ao nó ancestral mais próximo, que na barra de listagem engloba o campo de
busca. O nó ficou com o rótulo certo e perdeu a flag `isTextField`.

Quebrou um caso em Instituições e três em Pessoas. `container: true` resolve os
quatro sem desfazer o ganho — as sete telas continuam passando a diretriz.

Apareceu porque eu rodei as suítes das **dezoito** features que usam o widget
antes de considerar a entrega feita. A contrapartida de poder commitar em arquivo
compartilhado é medir o alcance, não só o ganho; medir o alcance é o que pegou
isto. Medindo só o ganho, a regressão entraria silenciosa e apareceria no
fechamento como falha de outra frente.

## Gate de conhecimento

Dois artigos projetados em `docs/knowledge/team/`, ambos `draft`, validador PASS
em 56 artigos: a armadilha da linha de base do sincronizador do Catálogo, e
"suíte verde não prova que a tela existe em produção".

## Acessibilidade — o que ficou medido

Classe única nas quatro telas que transbordam: **geometria fixa que não acompanha
a escala de texto**. `mainAxisExtent` fixo em Planos, célula quadrada em
Cardápios, célula de calendário em Agenda, tabela sem rolagem vertical em
Importações.

Agenda é a mais severa porque ocorre com **texto a 100%** num viewport de
telefone. A correção autorizada — estender a condição `largeText` existente para
largura estreita — foi aplicada, medida e **não resolve**: com uma única marca o
transbordamento permanece idêntico, porque nem o número do dia mais uma marca
cabe em 39,6 pixels. Revertida, e registrada a correção da minha própria
recomendação: ela não é a mais barata de aprovar.

### O estado vazio também transborda

As oito rotas de produção, com a composição padrão fail-closed, passam em 16 de
16 casos com texto a 100% — o caminho de indisponibilidade honesta está sólido.
A 200%, duas falham em 375: `/agenda` e `/meal-plans`. Cardápios transborda 37
pixels, o **mesmo número** medido com dados de desenvolvimento.

Isso afasta a explicação confortável de que esses defeitos vêm do volume de
dados semeado em desenvolvimento. Eles ocorrem no estado mais vazio possível da
aplicação, e o número idêntico mostra que a causa é a moldura, não o conteúdo.

Para Agenda, as três medições juntas descrevem a tela: com dados e texto a 100%
em 375, falha; sem dados a 100%, passa; sem dados a 200%, falha. A célula não tem
folga nenhuma. É também por isso que a extensão autorizada não tinha margem para
recuperar, e a pergunta certa ao Owner passa a ser se a célula precisa de mais
altura ou de outra composição — não quantas marcas cabem.

### Travessia por teclado

Oito das nove telas passam uma travessia de doze Tabs sem exceção e com o foco
avançando. A nona, `/dev/imports`, falha pela exceção de overflow já
diagnosticada, e **não** por defeito de foco. Registrado assim para não contar
duas vezes o mesmo defeito em eixos diferentes.

Tema não é fator em nenhum caso. Claro e escuro falham identicamente nas mesmas
rotas, o que separa o eixo de tema do eixo de largura e dispensa metade da
matriz para quem vier depois.

## Bloqueios, com a natureza de cada um

- **Decisão do Owner:** baseline 409; rebaseline de Suporte; altura do cartão de
  Planos a 200%; componente `CoeloAdminResizableTable`.
- **Ambiente/autorização remota:** pacote AUDIT-READ-V2 pronto e revisável,
  replay 0/145.
- **Ausência de implementação, não verificação pendente:** Suporte, 503 em
  produção; `account.sessions`, sem tela; `shell.switch-context`, sem seletor.
- **Decisão de produto:** `plans.activate` e `plans.assign`.

## O que NÃO foi feito, e por quê

Nenhuma execução remota. Nenhum golden regravado. Nenhum arquivo de produto de
outra frente alterado — as quatro suítes de rota fora do recorte são arquivos de
teste, com autorização nominal registrada. Nenhuma asserção afrouxada para
fechar suíte.


## Estrutura — o checklist escrito depois das correções achou mais três defeitos

Corrigi a mesma classe de contrato de escrita em quatro repositórios e só então
escrevi o artigo de conhecimento, nomeando `supabase_institution_directory_repository`
como implementação de referência porque ele já fazia tudo. Depois apliquei o
próprio checklist às seis famílias de estrutura, em arquivos que eu já havia lido
na mesma noite sem ver nada:

| Família | Resultado |
| --- | --- |
| Instituições | Nenhuma lacuna. É a referência nas quatro perguntas. |
| Unidades | Faltava conferir o recibo na atualização. Corrigido em `65880be56`. |
| Turmas | Faltava conferir o recibo. Corrigido em `fa4b968a3`. |
| Atividades | Faltava fechar transporte. Corrigido em `f30cc20c2`, preservando a negação de autorização. |
| Locais | Sem lacuna. |
| Avaliações | Sem lacuna; já recusa gradebook com ID divergente e instituição cruzada. |

Duas decisões valem tanto quanto as correções. Em Turmas eu **não** "corrigi" a
intenção de escrita, que já estava certa no formulário com `_pendingSave ??=`;
aplicar o checklist mecanicamente teria produzido mudança sem defeito. E rodei o
teste existente de composição idempotente **antes** de escrever o meu, porque uma
guarda mal escrita recusaria também o recibo correto — e esse é o modo de falha
clássico dessa correção.

Avaliações é o contraste mais limpo da noite entre cobertura funcional e aceite
visual: é a família mais bem guardada das seis, 42 PASS e zero falha, e mesmo
assim não promove, porque o aceite exige um golden que **nunca foi criado**.
Rastreei o histórico de `origin/dev` para distinguir cobertura perdida de
cobertura que nunca existiu; os artefatos de falha vêm de `cacf7cbc5`, uma branch
que não está em dev e que inclusive apaga um golden.

## O contrato RPC entre cliente e banco (`e14718844`, `5cab49f09`)

Nenhum teste do app confere se a RPC chamada existe no banco, porque todos usam
cliente falso ou interceptam transporte. Medi os dois lados: 80 chamadas, 76
nomes distintos, contra 383 funções do pacote.

**Cinco RPCs do diretório de Unidades não são criadas por nenhum arquivo do
repositório** — e duas delas são reusadas pelos filtros de Turmas. A evidência
que fecha a dúvida de varredura: a migration versionada `20260825180500` *chama*
`app_private.create_unit_for_superadmin` e o cabeçalho dela diz "Repair locally
installed Unit import/export worker functions". Uma migration do pacote depende
de função que o pacote nunca cria. Ou as funções existem fora do versionamento, e
então o pacote não descreve produção, ou Unidades falha fail-closed no primeiro
uso. **Não escolho entre as duas**: um `select` de catálogo resolve em segundos e
é o que a próxima janela autorizada deve fazer antes de qualquer promoção de
Unidades. Units não está pendente de verificação de front-end; está pendente de
saber se o backend dela existe.

**Cardápios chama a forma legada do delete de imagem.** A migration de recibos
criou a forma de três argumentos com `p_expected_revision` e manteve a de dois
como compatibilidade, cujo corpo lê a revisão corrente do próprio banco. Para o
banco a chamada é legítima, nada falha, e a guarda de concorrência nunca roda em
produção. Não corrigi porque o domínio de imagem não tem conceito de revisão:
**ler a revisão no cliente logo antes do delete reproduziria exatamente o furo
que a guarda existe para fechar**.

A regressão está fechada em `apps/superadmin/test/contracts/rpc_contract_test.dart`,
4 PASS, com controle negativo nos quatro casos, incluindo a aresta de leitura
direta por PostgREST. A lista de ausências conhecidas **também falha se uma delas
passar a existir** e continuar na lista, senão envelhece e vira o esconderijo do
próximo defeito.

## Expectativa superada em Formulários (`c2e6bda5d`)

Duas frentes leram estaticamente que `/forms/form-1/files` chamava backend em
rota declarada fail-closed e me pediram o número. Medi: uma chamada em cada uma
das quatro rotas de operação, zero em mídia. E então li o outro teste: o que
passa 7/7 **exige** exatamente uma chamada, e foi escrito em `3f5449940`, de
08/09, junto com a decisão de ligar rotas normais a leitura autorizada. O que
falhava é de 01/09. Não havia defeito: havia duas asserções opostas sobre a mesma
rota convivendo sete dias.

Corrigi a asserção com comentário datado, em vez de remover a rota do teste, para
que ninguém "conserte" de volta. Medi também, porque foi perguntado, que a sessão
daquele teste **não tem capacidade de Formulários**: `signInForTesting` concede
apenas `platform.read` e `withFormsAuthorization` consulta somente
`isAuthenticated`. O contrato de 08/09 delega a autorização de leitura
inteiramente ao servidor — decisão legítima, diferente de "o cliente confere
capacidade", e registrada no próprio teste.

`import_development_routes_test` é outra família: zero chamada ao repositório de
produção nas duas rotas `/dev`. Ele falha por RenderFlex estourando 1409 pixels
na superfície padrão, que é o overflow de `/dev/imports` já catalogado. Mesmo
sintoma vermelho, três causas diferentes em três rotas.

## Correções que fiz contra o meu próprio relato

Registradas porque mudam o que o leitor deve confiar:

1. Classifiquei Suporte como bloqueado por golden. O bloqueio real é ausência de
   camada de dados e 503 em produção. Os 61 testes verdes exercitam protótipo.
2. Afirmei que o aviso do Catálogo subnotificava. O risco é o inverso: regenerar
   o relatório **apaga** o aviso.
3. Descrevi a guarda de rota como bloqueio pela chamada sem argumento. O bloqueio
   vem do redirect com location; a causa é ausência do ramo.
4. Disse que `prototype_navigation` não mudou com a flag. O contador não mudou; o
   modo de falha mudou.
5. Classifiquei a fiação morta de `authorizedMealPlanTenantId` como baixa
   severidade. Faltava procurar quem **esperava** aquele valor: uma guarda de
   fail-closed especificada em teste e nunca implementada. Fiação morta sozinha é
   baixa; fiação morta mais guarda ausente significa que o assistente de mutação
   abria sem tenant autorizado.
6. Estimei "cerca de vinte" repositórios sem fechar falha de transporte. São oito.
   A estimativa contava apenas ausência de captura ampla e ignorava que vários já
   tratam `ClientException`.
7. **A mais grave.** Reportei `/dev/safety` reprovando as três diretrizes de
   acessibilidade e a chamei de "o pior conjunto do app", numa tela de dados de
   criança. Ela não reprova nenhuma. Uma exceção lançada durante o layout faz o
   caso falhar **antes** de a diretriz ser avaliada, e eu li isso como reprovação.
   Outra frente mediu independentemente, discordou, e estava certa. Também
   corrigi `/dev/imports`, que reprova apenas tamanho de alvo.
   A lição é a mesma que eu já havia declarado para o `pumpAndSettle` que não
   assenta, e não apliquei: **medição que falha por exceção é medição não feita**,
   e um instrumento que confunde "lançou" com "reprovou" produz acusação.
   Declarar uma lição não é tê-la internalizado.
8. Afirmei ter verificado por reversão que doze falhas não-golden não eram
   minhas. Tinha verificado uma; três eram minhas. Eu as agrupei como
   pré-existentes porque apareciam na mesma lista — **inferência por vizinhança,
   não medição**. As outras nove são pré-existentes, e agora isso está verificado
   e não assumido.
9. Medi que `/forms/form-1/files` dispara uma chamada de backend e mandei o
   número ao coordenador **antes** de saber qual dos dois testes em conflito
   encodava a decisão vigente. Uma chamada é violação contra um contrato e
   conformidade contra o outro: o número não estava errado, faltava o
   denominador. A cadeia estática que eu havia confirmado provava o mecanismo e
   não provava a infração. Uma correção de composição estava sendo atribuída com
   base nisso e foi parada a tempo.

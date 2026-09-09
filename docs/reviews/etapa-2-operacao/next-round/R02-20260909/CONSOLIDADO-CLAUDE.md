---
title: "E2 R02 — consolidado das frentes Claude (L00 → D00)"
source: "handoffs L01/L02/L03 pelos caminhos absolutos; verificações próprias de L00 no remoto e no código"
status: "consolidado-parcial-antes-do-corte"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Consolidado L00 → D00

Montado a partir dos handoffs originais das três frentes e de verificações que
**eu mesmo fiz** no remoto e no código. Onde afirmo algo que não verifiquei
pessoalmente, digo que é relato do executor. Este documento **não substitui** os
handoffs originais de L01, L02 e L03; D00 os lê pelos caminhos do registro.

## Identidades e SHAs verificados

| Frente | Sessão | Branch | HEAD verificado por L00 |
| --- | --- | --- | --- |
| L01 | `coelo-0f` | `codex/e2-r02-l01-publicacoes` | `e8a2a087e` (relato); base técnica `aec0c4afe` |
| L02 | `coelo-b7` | `codex/e2-r02-l02-chat-comunicacoes` | `811aac6e` (relato) |
| L03 | `coelo-03` | `codex/e2-r02-l03-perfil-para-voce` | `ae17f59b1` **verificado** |
| L00 | `coelo-ed` | `codex/e2-r02-l00-coordenacao-claude` | `1eb01b4c0` **verificado**, push conferido |

Todas as branches publicadas em `origin`. Nenhuma integrou `dev`: integração é de D00.

## Números por frente — sem somar suítes sobrepostas

**Denominador do grupo Claude: 39 IDs MVP** (L01 23, L02 13, L03 3), depois da
reconciliação de Circulares. Anterior era 28. O crescimento é **cobertura de
inventário**, não regressão.

| Frente | Implementação fechada | Contrato/BE local | **E2E certificado** |
| --- | --- | --- | ---: |
| L01 | 6/23 | 6/23 | **0/23** |
| L02 | 4/13 | 0/13 | **0/13** |
| L03 | 3/3 (base atual) | 0/3 | **0/3** |
| **Grupo Claude** | — | — | **0/39** |

**E2E é zero em toda leitura.** A causa não é falta de código: é a ausência de
autorização nominal para o pacote remoto, somada aos bloqueios abaixo.

### Testes únicos, por frente, com escopo declarado

- **L01** — widget/unidade: 216 P / 11 F; 74 P / 10 F; 88 P / 0 F; 151 P / 2 F.
  pgTAP: 32/0 (negativas comportamentais), 53/0, 16/0, 23/0, 46/0, 60/0, 50/0.
  Deno: 27/0. `dart analyze lib` limpo. B, S e U em zero.
  As 23 falhas únicas são golden e **todas preexistentes**: 11 em Momentos, 10 no
  Acontece, 2 no diretório de Circulares. **Causa não estabelecida** — ver abaixo.
- **L02** — recorte (chat, notices, principal_chat, rotas de chat):
  **P=316, F=12, B=1, S=0, U=0**. Taxa aprovada 96,34%. O `B=1` é o pgTAP,
  bloqueado pelo achado de plataforma abaixo.
- **L03** — recorte: **192 P / 10 F**, as 10 sendo golden drift preexistente,
  reproduzido por controle em worktree intocada. Suíte completa do app:
  **5104 P / 201 F / 5 S**, com as ~191 falhas fora do recorte classificadas como
  **NÃO REVALIDADAS** — nem preexistentes, nem dele. Aprovei a classificação.

**Não somei os três.** As suítes se sobrepõem e o contrato proíbe.

### Controle de regressão que L02 fez e que vale registrar

Comparou contra a base em vez de presumir: `test/app` na árvore dele 473 P / 33 F;
com router e rotas revertidos, 457 P / 34 F. A base tem **uma falha a mais**, e a
diferença é explicada pelo teste reescrito rodando contra o router antigo.
Verificação dirigida: zero falhas nos três arquivos do recorte dele. O candidato
mais provável a regressão, `persistent_shell_routes_test.dart`, dá `+6 -9` nas
**três** versões testadas — não é dele.

## O achado central da rodada

**Teste de widget verde não prova que a tela abre.** Quatro defeitos apareceram
hoje, todos sobreviveriam a lote verde, e todos só aparecem seguindo o caminho de
composição e o redirect da rota real:

1. **Feed misto nunca consultado** (L01). `principalMixedFeedRepository` é
   instanciado em `superadmin_auth_scope.dart:372` e declarado em
   `superadmin_router.dart:281` — e **nenhum builder o consome**. Verifiquei por
   contagem própria: dos dez repositórios Principal, nove têm parâmetro mais um
   uso; este tem **só a declaração**. Como `circulars.happens-card` virou
   subaceite obrigatório, **`acontece.feed` não fecha**.
2. **Repositório administrativo no lugar do autorizado** (L03). A aba Circulares
   do Perfil recebia o repositório administrativo, cujo `listProfile` delega ao
   diretório do Superadmin guardado por permissão administrativa — **o servidor
   respondia por permissão administrativa em vez de por visibilidade do ator**.
   Verifiquei: o repositório correto nunca era instanciado em `lib/`.
   Os testes de L03 **passavam nas duas configurações**, porque injetam direto.
3. **Rota inalcançável por guarda global** (L03). `/principal-profile/edit`
   termina em `/edit`, a guarda classifica como mutação autoritativa, e sem
   capacidade declarada o redirect mandava toda visita para a tela de erro.
   Rota, persistência e oito provas de widget entregues — **e a tela não abria**.
4. **Badge de não lidas nunca alimentado** (L02). Vertical completa —
   RPC com grant, método no domínio e nas implementações, parâmetro declarado e
   consumido pelo launcher — e **nenhum caller em `lib/`** fornecia o parâmetro.

**A explicação mais concreta veio de L01:** todos os testes de rota do Agora
exercitavam `/dev/`, e o único que tocava a rota real de publicação **só afirmava
a URL, rodando com repositório nulo** — passava verde enquanto a tela renderizava
indisponível. Era teste de path, não de composição. É a resposta factual para por
que contagens de teste nunca demonstraram entrega E2E nesta Etapa.

## Veredito da varredura dirigida de L01 — seis IDs implementados e não verificados

Eu havia mandado L01 verificar, no eixo FE, os seis IDs que ele mesmo apontou
como implementados **antes** desta rodada e pendentes de verificação, não de
implementação. Resultado, já com uma correção que ele fez do próprio achado:

| ID | Veredito |
| --- | --- |
| `agora.create` | **Verificado com evidência** na rota real |
| `agora.publish` | **Verificado com evidência** na rota real |
| `acontece.create` | Verificado **para escopo com turma** |
| `acontece.publish` | Verificado **para escopo com turma** |
| `acontece.feed` | **Parcial, não fecha** — projeção de Circulares ausente, subaceite obrigatório |
| `agora.view` | **Dois defeitos**: composição e retorno contextual |

### Correção de escopo que L01 fez sozinho, e que eu verifiquei

L01 havia relatado `agora.view` como **rota inalcançável pela navegação real**,
afirmando que `onOpenNow` era a única referência a `principalNowName` no app.
**Ele mesmo desmentiu antes de eu consolidar**, e eu confirmei por conta própria:
`principalNowName` aparece em `superadmin_router.dart` nas linhas 810, 857, 912 e
— o ponto que derruba a afirmação — **4899 e 5287**, os dois despachantes de
navegação; e o menu do hospedeiro expõe o destino `principal-now` em
`app/navigation/superadmin_navigation.dart:176`, com a folha de publicar na 177.
**A rota é alcançável pelo menu.**

Causa do erro, declarada por ele: um subagente concluiu "única referência" por
busca, e ele repassou sem reconferir — depois de passar o dia inteiro insistindo
que leitura não é verificação.

**O que sobrevive e continua sendo defeito real:** a Acontece real é montada com
`PrincipalHappensPreviewData.empty`, cujo `nowItems` é vazio, então o carrossel
Agora exigido pela spec050 aparece **vazio** e nenhum card de história é
construído — a entrada em contexto não existe, embora a entrada pelo menu exista.
É **defeito de composição**, não de acesso, e entra no movimento único em outra
ordem de gravidade. Os testes dele sempre asseriram exatamente isso e continuam
válidos; errada estava a moldura em volta, corrigida dentro do próprio arquivo em
`36ba21db5` para ninguém reconstruir a afirmação larga a partir dele.

O segundo defeito de `agora.view` permanece como reportado e foi medido por
teste: o retorno contextual usa `go` em vez de `pop`, então a origem é
**remontada** em vez de restaurada, e o feed da Acontece é relido ao fechar o
viewer. A rota `/dev` equivalente já faz `pop` quando pode — a preview está mais
correta que a produção. Correção exata para o movimento único: no builder de
`principalNow`, `if (context.canPop()) { context.pop(); return; }` com o
`goNamed` como fallback, espelhando `_closePrincipalViewer`.

**Nota de método, e é o motivo de eu registrar este episódio:** o consolidado que
publiquei às 15:0x **não** continha a afirmação exagerada — verifiquei antes de
escrever e o item não estava entre os quatro defeitos centrais. O erro foi
apanhado pelo próprio autor e confirmado por mim antes de virar registro. Isso é
o processo funcionando, não um deslize a esconder.


## Proveniência das provas — quem executou o quê

Pedi a L01 que reconferisse se alguma afirmação dele dependia de leitura de
subagente sem prova própria. Ele produziu uma tabela de proveniência que eu
adoto como padrão para o consolidado, porque o contrato exige a distinção.

**Executado pelo próprio L01:** `principal_happens` 74/10 e a base 66/10 sem as
mudanças; os 9 testes de retirada; `principal_now` + `principal_moments` +
`principal_circulars` 216/11; `principal_circulars` + `circulars` 156/2;
`test/app/router/` 288/1/30 com a classificação das 30; os 3 testes de composição
do Acontece; os 9 da rota real do Agora; e `principal_moments_publication` 88/0,
que ele **não** havia rodado e reexecutou nesta auditoria.

**Reexecutado pelo próprio L01 depois da auditoria — o número que solta a
retenção de D00:** a suíte comportamental do Acontece, **`1..32`, 32 `ok`,
0 `not ok`**, sem linha `# Looks like`. Ele subiu Postgres 17.6 descartável do
zero, reconstruiu os shims de `auth` e `storage` (`auth.jwt()`, `auth.uid()`,
`auth.role()`, tabelas `storage.buckets` e `storage.objects` e as funções
`foldername`, `filename` e `extension`, sem os quais a migration do Acontece
falha ao registrar o bucket), replicou as 170 migrations uma por transação com
`ON_ERROR_STOP=1`, confirmou que `withdraw_happens_post`,
`list_visible_happens_posts` e a capacidade `happens.posts.remove` existem depois
do replay, e rodou o teste.

**Corroboração de método, que vale mais que o número:** o replay dele deu
**93 aplicadas e 77 falhas**, idêntico ao do subagente, e **nenhuma migration do
Acontece está entre as falhas** — a única do território de L01 que falhou é
`20260901191921_superadmin_internal_circulars_v2.sql`, superfície administrativa
de Circulares, fora da cadeia do Acontece. Caminho próprio, mesmo ambiente, mesmo
resultado.

**Depois disso, L01 reexecutou o bloco inteiro por conta própria.** Situação
final da proveniência: **sete linhas "eu", uma "subagente"**. Reexecutados por
ele e conferindo número por número com o relato dos subagentes: retirada do
Acontece `1..32`; contrato existente do Acontece `1..53`; Momentos `1..23`;
expiração do Agora `1..16`; Circulares em R2 `1..46`; contrato anterior de
Circulares `1..60`; e Deno `circular-media` 27 passed, 0 failed. Dois containers
descartáveis, ambos removidos e confirmado por listagem.

**Reprodutibilidade que atesta o método:** os dois replays independentes dele
deram **exatamente 93 aplicadas e 77 falhas**, o mesmo número do subagente.
Nenhuma migration do Acontece, do Agora, de Momentos ou de Circulares está entre
as falhas; a única do território de L01 que falha é a superfície administrativa
`20260901191921_superadmin_internal_circulars_v2.sql`, fora da cadeia do Principal.

### A sétima linha, e a pré-condição que ela revelou para o preflight de D00

`20260909135000_private_media_catalog_chat_kind_v1.sql` — o `catalog_kind` de chat,
do qual o `chat.attach` de L02 depende — **falha no replay completo**, com
`constraint "media_assets_catalog_shape_ck" of relation "media_assets" does not
exist`. L01 diagnosticou antes de classificar e **não é defeito da migration**:
a dependência `20260908160000_private_media_catalog_r2_v1.sql` não aplica porque
`20260813155118_forms_responses_and_private_media.sql` falha primeiro, e a cadeia
de Formulários inteira fica de fora, levando junto `20260908170000` e
`20260908215522`.

A divergência com o 50/50 do subagente está explicada e **não é contradição**: o
subagente montou um replay **parcial nominal de 19 migrations**, escolhidas para
levantar a fundação do catálogo; L01 usou o replay **completo em ordem de nome**,
onde a fundação não se levanta. Dois harnesses honestos, escopos diferentes.

**Entrega concreta para D00:** o delta de `catalog_kind` de chat **só aplica sobre
uma base que já tenha a fundação do catálogo privado de mídia**. Em produção
presumivelmente tem, mas é **pré-condição a confirmar no preflight, não a
presumir**, e a ordem de aplicação importa. Registrado como pré-condição, não
como defeito.

### As duas fundações quebradas, apresentadas juntas

Separadas parecem azar; juntas são um fato do repositório. **L02** mostrou que
nenhum SQL do realm interno do Superadmin é provável localmente, porque a cadeia
de **Atividades** quebra. **L01** mostrou que o catálogo privado de mídia tem o
mesmo problema pela cadeia de **Formulários**. Duas fundações diferentes, o mesmo
padrão — e juntas explicam por que quase nada de backend consegue ser provado
nesta máquina hoje, sem que isso seja falha dos pacotes de nenhuma frente.

Classificação correta desses seis: foram produzidos **nesta sessão, sobre esta base,
com relato item a item**, portanto **não** são resultado histórico não
revalidado. Mas não foram exercidos pelo executor responsável, e **quem for
certificar deve reexecutá-los no perfil nominal de replay** — que é exatamente o
que o pacote remoto já exige de D00. L01 declarou que não reexecutou por decisão
de tempo, não por confiança cega: cada um exige subir container e aplicar dezenas
de migrations. Preferiu declarar a proveniência com precisão a rodar um e deixar
seis sem carimbo. Concordo com a escolha.

### Estreitamento: a causa das 11 falhas de golden de Momentos NÃO está estabelecida

L01 vinha reportando que falham porque o sprite
`assets/principal_moments/moments-strip.png` não resolve no ambiente de teste.
Ele mesmo desmentiu e **eu verifiquei**: o arquivo existe, tem **2.408.205
bytes**, e está declarado em `apps/superadmin/pubspec.yaml:58`. A execução não
levanta erro de carregamento de asset; o que existe é diferença de 99,53% a
100,00% dos pixels. Isso é **compatível** com a mídia não pintar no harness, mas
é hipótese, não fato — e, como estava escrito, levaria alguém a procurar um asset
ausente que está no repositório.

**O que permanece verificado:** são preexistentes, medidas duas vezes de forma
independente com as alterações fora da árvore, dando 0 aprovados e 11 falhos; e
regenerá-las gravaria o que quer que este ambiente renderize como referência
aprovada. A decisão de não regenerar continua certa; só a explicação estava firme
demais.

**Balanço do eixo:** duas afirmações de L01 foram estreitadas hoje, ambas nascidas
do mesmo hábito de repassar conclusão de subagente sem exercer a prova — a
varredura de alcançabilidade pegou a primeira, a auditoria de proveniência pegou
a segunda, e **nenhuma das duas chegou a este consolidado**. Registro como
processo funcionando.


## Bloqueios que não são das frentes Claude

### 1. Realm interno do Superadmin não é provável nesta máquina

Achado por L02. `20260831211945_activities_v2_internal_gateways.sql` falha com
`relation "app_private.superadmin_internal_activity_command_receipts" does not
exist`; sem ela, `app_private.audit_append_superadmin_internal` só existe com 13
argumentos e a de 14 nunca aparece; por isso as migrations de chat v2 e notices
v2 são recusadas pelas próprias guardas.

**Nenhum SQL do realm interno pode ser provado localmente, por nenhuma frente.**
Explica a assimetria: L01 rodou pgTAP de mídia porque não depende do realm
interno. **A causa raiz é do domínio de Atividades, de D02.** As guardas
funcionaram como desenhadas — é qualidade, não defeito.

### 2. Medições de replay divergem

**122/168**, **93/170** e **83/165** nesta rodada. Perfis e momentos diferentes;
nenhuma é "a" medição. D00 precisa reexecutar no perfil nominal
(`scripts/Invoke-SafeLocalMigrationReplay.ps1`) antes de considerar pacote pronto.

### 3. Guarda de mutação por sufixo — candidatos a rota inalcançável

Achado meu, generalizando o defeito 3. Status: **leitura da guarda e das rotas,
não execução do app**. A guarda cobre `/new`, `/edit`, `/duplicate` e
`/assessment-settings`; `hasAuthoritativeMutationCapability` declara **apenas**
`/invites`, `/notices` e `/circulars`. Rotas com repositório **real** e sem
capacidade declarada:

`/people/new` e `/people/:personId/edit` (D04); `/safety/new` e a edição de
autorizações (D04); `/internal-users/new` e `/edit` (D04); `/attendance/new` (D03).

Onde o repositório é `Unavailable`, a rota já falharia fechada e a guarda é
redundante. **Não instruí ninguém a corrigir**: são de D03 e D04, e alargar
capacidade é mudança de superfície de autorização. **Se D01–D04 contarem FE
dessas telas por prova de widget, o número está errado.**

## Movimento único de hospedagem — para D00 montar

As rotas Principal são declaradas como **irmãs** da `ShellRoute`, então o shell
nunca é construído para elas: a decisão do Owner sobre preservar o shell é
**estrutural, não visual**. Achado independentemente por L01 e L03.

**Não pode ser serializado em três hunks**: se só uma frente mover as suas, o
menu some ao navegar entre telas irmãs. Exige inverter 17 asserções em 6 arquivos
de `test/app/router/`. Eu havia autorizado L03 a mover só as dele e **reverti** a
autorização quando L01 mostrou a consequência; L03 confirmou por diff que router
e testes de router ficaram intactos, e eu verifiquei o mesmo em L01.

Hunks publicados: `propostas/L01-hunks-composicao.md` (L01) e
`propostas/L03-hunks-hospedagem-rotas.md` (L03). **Escopo maior do que mover
rotas**: `/principal-moments` precisa da cadeia completa por auth scope, app e
main, porque `PrincipalMomentsFeedRepository` não aparece em `app/` nem `core/`.

**Peço que a inversão do teste `principal_happens_composition_gaps_test.dart`
(`167cbd584`) seja critério de aceite do movimento.** Ele prende o defeito do feed
misto e manda inverter, não apagar. Sem isso, a correção pode ser feita sem
ninguém saber se funcionou.

### Reservas concedidas, sem sobreposição

L03 nos builders de Perfil e Para Você mais `superadmin_routes.dart`,
`superadmin_auth_scope.dart`, `superadmin_app.dart` e `main.dart` (retroativa,
concedida, **não mandei reverter**); L01 em `/principal-happens` (l.669),
`/principal-moments` (l.835) e as duas construções de
`ProductionCircularComposerHost` (~l.4391 e ~l.4431); L02 nas construções do shell
(l.450, l.465, l.966) e na rota nova `/principal-conversations`.
**Ordem de integração: L03 → L01 → L02.**

## Decisões que tomei e que D00 pode reverter

1. **Assimetria de `withdraw_moment` aceita** — versão opcional em Momentos,
   obrigatória no Acontece. A projeção de Momentos não expõe versão; autoria,
   tenant, escopo e capacidade seguem validados no servidor; retirada idempotente
   e soft. Nenhuma fonte aprovada impõe simetria.
2. **Corrigir dentro da migration não aplicada** em vez de empilhar remendo.
   Forward-only vale para o que já foi aplicado.
3. **Tela indistinguível do Acontece é defeito**, mesmo com o estreitamento sendo
   decisão de produto: devolver ao ator recusado a mesma tela que sinaliza
   aplicativo quebrado faz o produto mentir sobre a causa.
4. **`enableInlinePreview` em `/notices` é pergunta, não defeito.** Não há fonte
   aprovada exigindo a prévia em produção; proibi implementar.
5. **Composição Principal sem editar/revogar é decisão declarada**, não lacuna:
   o ator do Principal não é o autor interno e `can_manage` viria falso.
6. **Proibi a correção geral do badge** — 58 construções de `SuperadminShell` em
   46 arquivos, contadas por mim, atingindo D01–D04. Lote incompatível com o tempo.
7. **Propriedade das fontes compartilhadas**: `specs/050` e a referência
   `coelo-ui` são commit meu (`03969969a`); as frentes preservam as suas.

## Pendências que exigem decisão do Owner ou de D00

- **Autorização nominal do pacote remoto de L01** — é o que separa E2E zerado de
  E2E real. Bloco A (Postgres puro: Momentos, expiração do Agora, retirada do
  Acontece) e bloco B (Circulares em R2: migration, Edge Function e quatro
  segredos, com buckets **não inspecionados** nesta rodada). Recomendei A primeiro.
- **Concessão das capacidades** `moments.publications.remove` e
  `happens.posts.remove`: catalogadas, **não concedidas**. Sem atribuição a
  perfil, as ações seguem negadas mesmo com tudo aplicado.
- **`pg_cron` e consumidor `service_role`** para a materialização de
  `notices.publish` (L02 pediu a D00).
- **Verificação remota de `get_profile_about`** (L03): sem RPC de leitura, o
  `load` via PostREST retorna negado se as tabelas estiverem sob RLS
  deny-by-default.
- **`principal.profile-edit` sem contrato visual aprovado** — gate por entregável
  exige aprovação de imagem. D00 registra "editor Principal próprio já aprovado";
  se cobrir esta composição, resolve.
- **Estreitamento de escopo do Acontece** (unidade e turma não nulas) versus
  esquema que aceita publicação institucional.
- **Desdobrar `chat.*` em `.admin` e `.principal`** — proposta de L02, endossada
  por mim. Muda denominador, não implementação.
- **Correção arquitetural do badge** nas 58 construções de shell.
- **Política de audiências na escrita** (L01): `save_now_draft` insere o
  `audience_kind` que o cliente enviar. L01 **calibrou e não chamou de defeito de
  segurança** — não há vazamento cross-tenant e não achou regra aprovada violada.
  A afirmação que fica: se existir política sobre quais públicos cada papel pode
  endereçar, ela precisa ser imposta no servidor **antes** de abrir audiências na UI.

## Higiene de Git — incidentes registrados, nada perdido

- **L03**, `git add -A`, varreu **quatro** arquivos alheios e 62 PNGs de
  `**/failures/`. Corrigiu o próprio relato de dois para quatro. Devolvidos em
  `9c6042732`, `d1b6e0f39` e `4b40083fb`, com deltas preservados em patch.
  **Verifiquei**: o diff da branch contra a base devolve 31 arquivos, todos dele,
  e **nenhum arquivo alheio remanescente**. Sem reset, clean ou force push.
- **L01**, subagente rodou `git stash` uma vez; recuperado com `stash pop`, nada
  perdido, e comandos git proibidos nominalmente aos subagentes. Índice git
  corrompido pelo reinício do host às 14:03, reconstruído a partir do HEAD sem
  tocar na árvore.
- **Nada foi apagado para deixar Git limpo** em nenhuma frente.

## Erros meus, declarados

1. Afirmei que não havia runner de pgTAP nesta máquina. **Falso** — há, e L01
   executou várias suítes. A ressalva verdadeira é que o replay local é parcial.
2. Chamei o contrato de mídia de chat de **desbloqueio** de `chat.attach`. Errado:
   faltam a RPC de staging/commit e a Edge Function, e a migration não concede grant.
3. **Autorizei L03 a mover só as rotas dele** para o `ShellRoute`; revertido
   quando L01 mostrou que o menu sumiria entre telas irmãs.
4. Cobrei de L01 um teste pgTAP que ele **já havia atualizado** — li a baseline,
   não a ponta da branch.
5. Estimei horários em prosa mais adiantados que o relógio, mais de uma vez.

## Estado das frentes

As três em execução até 16:00 e disponíveis na janela de consolidação até 16:45.
Nenhum processo pesado ativo; L02 removeu os três containers Postgres que subiu e
L01 removeu o dele. Nenhuma frente criou agendamento. **Nada foi aplicado em
Supabase ou Cloudflare remoto por nenhuma frente Claude.**

## Achado convergente: o ator institucional é excluído das DUAS rotas de publicação

Dois executores, por caminhos independentes, encontraram a mesma causa em telas
diferentes. Registro junto porque separados parecem casos isolados.

- **L01, no Acontece:** publicar exige unidade e turma não nulas, enquanto o
  esquema aceita publicação institucional com os dois nulos.
- **L03, no Agora:** `/principal-now/publication` exige `unitId`, `unitName`,
  `groupId` e `groupName` e cai em `_unavailableCompositionRootRoute` se faltar
  qualquer um. Um ator com vínculo em **nível de instituição** — que o Perfil
  atende normalmente, porque trata unit e group nulos — toca "Publicar no Agora"
  no dock e recebe a tela de indisponível.

**Mantenho a separação que fiz, com peso alterado.** O estreitamento de escopo
continua sendo **decisão de produto**, do Owner e de D00, e proibi implementar a
abertura. Mas a **tela indistinguível** continua sendo **defeito** e agora tem
**duas ocorrências**, o que a tira da categoria de descuido pontual: é o
comportamento das duas rotas de publicação do Principal para um ator legítimo.
Ele encontra dois becos e nos dois recebe a mensagem de aplicativo quebrado.

L03 não alterou nada, corretamente: esconder a ação central mudaria a composição
aprovada do dock, e a rota é de L01.

## Sexto defeito de L03, nascido de escrever a cobertura que faltava

A tela de edição **não tinha nenhuma cobertura responsiva**, e escrevê-la achou o
defeito: a 375 px com texto a 200%, o rodapé com "Recarregar" e "Salvar"
estourava **173 px à direita** — num celular com texto ampliado o botão de salvar
saía da tela. Corrigido em `5d8a951a7`, trocando `Row` por `Wrap`. Nove provas
cobrem 375/768/1024/1440 a 200%, com as duas ações alcançáveis e os estados
negado e de erro anunciados, legíveis, passando contraste e alvo de toque.

Vale registrar o método: o defeito não apareceu auditando o que existia, apareceu
**escrevendo a prova que faltava**. Ausência de cobertura não é neutra.

## Vazio distinguível de erro — provado nas três telas de L03

No hub: vazio por audiência mantém os seis atalhos e o bloco de contexto e não
exibe erro nem não autorizado; falha mostra o erro com "Tentar novamente" e nunca
o vazio; negação não mostra nem vazio nem erro e não oferece retry. No Perfil:
Sobre sem conteúdo publicado ainda renderiza a identidade autorizada com a aba
dizendo pendente e nunca cai em erro; Sobre que falha nunca renderiza como perfil
sem conteúdo.

É o mesmo princípio do zero silencioso que recusei no badge de L02 e da tela
indistinguível que classifiquei como defeito no Acontece: **"não há o que mostrar
para este ator" e "não consegui mostrar" são fatos diferentes** e não podem ter a
mesma resposta.

## Escopo das projeções consumidas por L03 — conferido pela composição

As duas projeções que L03 consome e não produz recebem escopo **derivado do
contexto autorizado**, nunca herdado nem padrão: a aba Acontece monta
`PrincipalHappensFeedScope(institutionId, unitId, groupId)` a partir do
`runtimeContext` resolvido por `list_my_principal_contexts`, e a aba Circulares
monta `CircularScope` do mesmo contexto. Prova de rota para Circulares — o teste
assere que o escopo que chega ao repositório tem o `institutionId` do contexto —
e prova de widget para Acontece, onde trocar o escopo recarrega e envia o novo
`unitId`. Foi essa checagem que expôs o defeito do diretório administrativo, e
ele a repetiu para as duas.

Números de L03 no fim da auditoria: **210 P / 10 F**, as mesmas 10 goldens
preexistentes; nenhum teste novo alterou a contagem de falhas; `flutter analyze
lib` limpo.

## Defeito achado, correção pronta, deliberadamente NÃO entregue — L02

**Conflito de versão em Avisos é beco sem saída.** Quando uma ação de ciclo de
vida falha com `NoticeConflictException`, o diretório mostra a mensagem — que é
literalmente *"O aviso foi alterado. Recarregue e tente novamente"* — e **não
recarrega**. A lista segue exibindo a versão antiga, quem tenta de novo repete a
`managementVersion` obsoleta e bate no mesmo conflito **indefinidamente**.
**A tela promete uma recarga que não faz.**

Mesma família do zero silencioso e da tela indistinguível: a interface afirmando
algo que não corresponde ao que ela faz.

Detalhe que torna a correção segura e que merece constar: `_actionIntentKey`
**já inclui** `managementVersion`, então recarregar gera chave de intenção nova e
a próxima tentativa não reusa o id de idempotência anterior. Quem escreveu pensou
na concorrência; faltou o recarregamento. A correção é de **uma linha** —
`_refresh` em vez de `_feedback`, só para `Conflict` e `NotFound`.

**L02 implementou e reverteu deliberadamente**, por não conseguir dirigir o
flyout de ações em teste de widget no tempo restante: o alvo é encontrado, o
toque não abre o menu naquele harness, e a ação nunca aparece. Sem prova, seria
mudança de comportamento entregue no escuro perto do corte — exatamente o que ele
já havia recusado em `chat.attach` e no Realtime. **Árvore limpa, nada commitado.**

Registro com destaque porque é a decisão mais difícil do dia: correção óbvia,
defeito claro, incentivo todo apontando para entregar e escrever "coberta por
inspeção". Ele não fez, e manteve o mesmo critério que aplicou o dia inteiro.
**Fica como defeito registrado com correção pronta**, para quem tiver janela e
conseguir o harness.

## Realtime: recusa fundamentada de fabricar teste

L02 recusou escrever os estados de Realtime, e concordo. Testar "a autorização de
Realtime nega" exigiria simular um gatilho que **não existe**: `refreshAfterRealtime`
não tem caller, e `postgres_changes` nunca entregaria evento ao realm interno,
porque as policies resolvem por `current_person_id()` e a identidade interna não
tem linha em `people`. Seria **teste verde sobre caminho morto** — pior que
ausência de teste, porque criaria confiança falsa.

## Verificações de L02 com prova, nesta janela

**Rotas de Avisos** (`notice_routes_capability_test.dart`, 2 casos verdes): com
repositório autorizado, `/notices` recebe `onCreate`, `onEdit` e
`canManageLifecycle`; `/notices/new` monta o formulário com o mesmo repositório; e
`/notices/:id/edit` **leva o id adiante** — sem isso **uma edição viraria aviso
novo**, e esse é o tipo de defeito que só aparece exercendo a rota. Sem
repositório autorizado, o diretório não oferece o que o servidor negaria e
`/notices/new` responde com `production-mutation-capability-unavailable` em vez de
montar formulário mudo. Confirma minha hipótese de que `/notices` não cai na
guarda que deixou a rota de L03 inalcançável.

**Vazio por permissão versus por ausência no Chat** (`principal_chat_page_test.dart`,
18 casos): conversa vazia **autorizada** mostra o estado vazio e **mantém o
composer**; conversa **negada** purga o instantâneo privado, composer incluído, e
mostra o painel de sem permissão. Distinguíveis, como exigido.

## Mapa transitivo de dependência — o que D00 precisa confirmar no preflight

L01 entrou para converter a oitava linha da tabela de proveniência, **não
conseguiu**, e o que trouxe de volta vale mais que a linha: o mapa real da
dependência do delta de `catalog_kind` de chat, que antes era só "falta a
fundação do catálogo".

**Ordem real da cadeia:** base de Formulários → `20260813155118_forms_responses_and_private_media.sql`
→ cadeia de auth interno com `app_private.superadmin_internal_identities`
(`20260827233000_superadmin_internal_auth_context.sql` e
`20260901190927_deploy_superadmin_internal_auth.sql`, que também não aplicam
neste harness) → `20260908160000_private_media_catalog_r2_v1.sql` →
`20260909135000_private_media_catalog_chat_kind_v1.sql`.

**D00 precisa confirmar a cadeia inteira no preflight, não só a fundação.**

### Dois ajustes de harness que destravam ~30 migrations no replay local

Registrados para quem repetir o replay não redescobrir:

1. **`check_function_bodies=off`** — sozinho levou o replay de **93 para 112** aplicadas.
2. **Relaxar o `not null`** de `module_label`, `screen_label` e `action_label` em
   `platform_permissions` — recuperou mais **11**, e com isso
   `20260813155118` passou a aplicar.

Depois disso a fundação do catálogo ainda falhou, por outro motivo:
`relation "app_private.superadmin_internal_identities" does not exist`.
L01 parou aí, dentro do time-box, e removeu o container com verificação.

**Ressalva obrigatória:** replay com `check_function_bodies=off` e constraints
relaxadas **não é o mesmo ambiente** que o perfil nominal. Prova contrato, não
banco de produção. Repassei os dois ajustes a L02, cujo bloqueio é a cadeia de
**Atividades** e não a de Formulários — pode ou não alcançar; se não alcançar,
o `B=1` dele permanece bloqueado e assim será relatado.

**A oitava linha da tabela permanece "subagente, não reexecutado"**, agora com o
motivo mapeado em vez de nota vaga. L01 não fingiu que fechou.

## Correção minha, registrada

Listei duas vezes, como pendente, o congelamento em teste do defeito de tela
indistinguível. **Ele já estava feito desde `02072307c`** para o caso do Acontece.
O que L01 acrescentou agora foi o **quarto caso**, o do Agora achado por L03: o
teste dirige `/principal-now/publication` com repositório fornecido e ator de
escopo institucional, e prova que ele recebe a **mesma** `SuperadminErrorScreen`
de indisponibilidade. Quatro casos, todos verdes, `dart analyze` limpo.

### A formulação que fica, e é de L01

**O ator institucional é legítimo e atendido pelo Perfil** — não é caso de borda
inventado. É um usuário real que encontra dois becos e recebe, nos dois, a
mensagem de que o aplicativo quebrou. O estreitamento de quem pode publicar é
decisão de produto que nenhum executor toma; o que está preso em teste é a
**resposta ser indistinguível de aplicativo quebrado**, errada independentemente
de como aquela decisão cair.

## Procedimento reproduzível do replay local — entregável de L01 para D00

L01 fechou o handoff com o passo a passo do harness, para que ninguém redescubra
o que ele descobriu hoje. Ponta em `e88e0ee39`. Conteúdo, com efeitos medidos:

- receita do container Postgres 17.6 descartável;
- **shims de `auth` e `storage`** que a imagem não traz — `auth.jwt()`,
  `auth.uid()`, `auth.role()`, tabelas `storage.buckets` e `storage.objects` e as
  funções `foldername`, `filename` e `extension` — sem os quais a migration do
  Acontece **falha ao registrar o bucket**;
- **`check_function_bodies=off`**: de **93 para 112** aplicadas. Causa
  identificada: um `if ... case ... then` em `20260813155005` que não compila no
  PostgreSQL 17.6 com a checagem ligada;
- **relaxar o `not null`** de `module_label`, `screen_label` e `action_label` em
  `platform_permissions`: mais **11 numa segunda passada**;
- **teto conhecido do harness**: a fundação do catálogo ainda exige
  `app_private.superadmin_internal_identities`;
- **armadilha de ambiente**: no Git Bash do Windows é preciso exportar
  **`MSYS_NO_PATHCONV=1`** antes dos `docker exec`, senão `/tmp/arquivo.sql` é
  convertido para caminho Windows e o `psql` dentro do container não acha o
  arquivo, **sem erro que explique**. Repassei a L02 na hora.

**A ressalva que L01 deixou escrita e que eu subscrevo:** este harness **prova
contrato, não banco de produção**, e o perfil nominal
`Invoke-SafeLocalMigrationReplay.ps1` continua sendo o que D00 roda antes de
aplicar. A facilidade de subir um container **não** substitui o preflight.

## Estado final de L01 no corte — verificado por L00

Verifiquei em vez de aceitar o relato: HEAD e `origin/codex/e2-r02-l01-publicacoes`
ambos em **`e88e0ee39`**. O diff desde a baseline em `apps/superadmin/lib/app/router/`
e `apps/superadmin/test/app/router/` devolve **exatamente dois arquivos**, ambos
**testes novos que documentam defeito** — `principal_happens_composition_gaps_test.dart`
e `principal_now_real_route_test.dart`. **`superadmin_router.dart` intocado**,
como a disciplina do movimento único exigia.

Árvore limpa exceto as três fontes compartilhadas, preservadas e intocadas;
nenhum container, subagente ou agendamento. Handoff em
`C:/Users/adrie/Documents/Coelo.worktrees/e2-r02-l01-publicacoes/docs/reviews/etapa-2-operacao/next-round/R02-20260909/handoffs/L01.md`.

## DEFEITO QUE FARIA MIGRATION FALHAR NA APLICAÇÃO — achado por L02, corroborado por L00

**É o achado de maior consequência prática do dia**, e só existe porque mandei as
frentes voltarem a trabalhar em vez de ficarem em estado seguro. L02 tentou os
ajustes de harness que L01 mapeou, **não** obteve o número que procurava, e no
lugar dele achou um defeito no **próprio pacote** que o faria falhar em produção.

### O defeito

**Linha do tempo exata, verificada por L01 e reconferida por L00 arquivo por
arquivo.** A primeira descrição, de L02, dizia "NOT NULL sem default desde
`20260811215451`". **Não é isso**, e a correção **fortalece** o diagnóstico:

1. `20260811215451_access_profile_management_v2.sql:62` torna os três rótulos
   **`not null`** em `platform_permissions`, e o mesmo em `institution_permissions`
   logo abaixo — **mas naquele momento havia default**.
2. `20260831130726_reconcile_permission_labels_after_replay.sql` **remove os
   defaults** das três colunas, nas duas tabelas. **Verifiquei o `alter column
   ... drop default` para as três.**
3. `20260901191921_superadmin_internal_circulars_v2.sql:109-111` insere em
   `platform_permissions` com a lista
   `code,module_code,screen_code,action_code,description,risk_level,requires_mfa,status`
   — **os três rótulos ficam de fora**. **Verifiquei a lista de colunas.**

**Por que a data importa:** qualquer `insert` sem rótulos escrito entre 11/08 e
31/08 funcionava e passou a falhar em 31/08. O arquivo problemático é de
**01/09** — **nasceu depois da remoção do default**, ou seja, foi escrito já
quebrado, não quebrado por mudança posterior. Isso muda o julgamento de quem for
avaliar se ele chegou a rodar em produção.

Qualquer `insert` em `platform_permissions` que **omita os três** falha com
`null value in column "module_label" ... violates not-null constraint`.

### Instância corrigida

A migration `20260909130000` de L02 inseria `chat.internal.manage` **omitindo os
três**. **Não é artefato de replay local:** em qualquer base que já tenha a
migration de agosto — e produção tem, é de um mês atrás — **o pacote falharia ao
aplicar**. Corrigido em `98ebd975`, fornecendo os três explicitamente pela
convenção de `20260901210000_superadmin_internal_users_directory.sql` e incluindo
os rótulos também no `on conflict do update`.

### Duas instâncias latentes, que NÃO são para as frentes corrigirem

Verifiquei por conta própria: **nenhuma das duas menciona `module_label`**.

1. **`20260901101500_superadmin_internal_chat_v2.sql`** — mesmo defeito, e é a
   **baseline das RPCs de chat que o app chama hoje**. Ou ela **nunca aplicou em
   produção**, e então as RPCs `superadmin_chat_*_v2` não existem lá e o FE de
   chat está falhando fechado contra um gateway inexistente; **ou** alguém a
   ajustou fora do repositório. Nenhuma frente consegue distinguir daqui sem
   acesso remoto, que não temos e não pedimos. **As duas hipóteses são materiais
   para o preflight de D00.**
2. **`20260901191921_superadmin_internal_circulars_v2.sql`** — território de L01,
   mesmo defeito latente. É justamente a única migration do território dele que
   falha no replay, e agora há causa provável que **não é o harness**.

**Instruí L01 a diagnosticar e registrar, NÃO a corrigir.** A migration dele é de
01/09 e o estado remoto dela é desconhecido; alterar migration que possa já ter
sido aplicada exige decisão de D00. A de L02 era desta rodada e nunca aplicada, o
que torna a correção em lugar segura — a diferença importa e está declarada.

### O que L02 recusou fazer, e estava certo

Usou **apenas** `check_function_bodies=off` e **não** relaxou os `not null`,
porque o pgTAP dele afirma **estrutura** e passar por cima de constraint tornaria
qualquer verde enganoso. Foi exatamente essa recusa que expôs o defeito: quem
relaxa a constraint nunca o veria. Replay foi de **83 para 123 de 166**, e
`20260831211945_activities_v2_internal_gateways.sql` **passou a aplicar** — o
bloqueio raiz dele caiu, e o erro seguinte foi o defeito acima.

**O `B=1` dele continua bloqueado** e será reportado assim: chat v2 e notices v2
seguem sem aplicar, esta última por outro motivo,
`relation "public.notice_events" does not exist`. Ele parou dentro do teto que
L01 mediu, a minutos do corte. E declarou junto: replay com
`check_function_bodies=off` **prova contrato, não banco de produção**.

## Defeito de conflito em Avisos: reaberto e fechado COM prova

L02 tinha revertido a correção por não conseguir dirigir o flyout. **O problema
era o harness, não o comportamento:** o diretório só expõe o flyout na composição
**compacta**; ele testava na tabela ampla. Com `375x800` o menu abre.
`notice_directory_conflict_test.dart`, 3 casos verdes, provando **pela contagem
de leituras do repositório** — conflito recarrega, ausência recarrega,
indisponibilidade não. Correção de volta em `c68affc4`.

Registro a sequência inteira porque ela é o método funcionando: achou, corrigiu,
**reverteu por falta de prova**, achou o motivo da falta de prova, e reentregou
**com** prova. Nenhum passo foi pulado.

---

# Fechamento das três frentes — números finais verificados

## A pergunta que eu levaria ao Owner ANTES de qualquer certificação de Chat

É a formulação de L02 e eu a adoto inteira, porque é a de maior consequência do
consolidado:

`20260901101500_superadmin_internal_chat_v2.sql` tem o defeito de rótulos
`NOT NULL` e **é a baseline das RPCs que o app chama hoje**. Duas hipóteses,
ambas materiais e nenhuma verificável daqui:

- **Nunca aplicou em produção** — e então as RPCs `superadmin_chat_*_v2` não
  existem lá, o FE de Chat está falhando fechado contra um gateway inexistente, e
  a leitura de `chat.list`, `chat.open` e `chat.send` muda de "existentes, não
  certificados" para **"provavelmente inoperantes"**.
- **Foi ajustada fora do repositório** — e então o repositório não descreve a
  produção, o que é problema de outra natureza e igualmente sério.

Nenhuma frente Claude tem acesso remoto e nenhuma pediu. **Isso é preflight de
D00 e decisão do Owner.**

## Lição generalizável, na formulação de L02

**Guarda de dependência bem escrita não substitui exercitar a aplicação.** Ele
havia declarado o próprio pacote como "escrito e revisável, aguardando
autorização" e ele **não teria aplicado**. Todo pacote de banco desta rodada que
insere em `platform_permissions` deve ser conferido quanto a isso antes do
preflight.

## Números finais por frente

| Frente | HEAD verificado por L00 | P | F | B | S | U | Taxa aprovada |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| L01 | `e88e0ee39` | ver detalhamento por lote | — | 0 | 0 | 0 | — |
| L02 | `af9b5043` | 325 | 12 | 1 | 0 | 0 | 96,44% |
| L03 | `fe3bbb61f` | 211 | 10 | 0 | 0 | 0 | 95,48% |

L02 reporta ainda execução 99,70% e aprovação do plano 96,15%. Os 325 incluem 18
casos da composição Principal, 5 da rota Principal, 3 da fiação do badge, 3 do
conflito de versão em Avisos e 2 da capacidade das rotas de Avisos. As 12 falhas
são goldens preexistentes provados na base limpa; o `B=1` é o pgTAP bloqueado.

**Não somei as três.** As suítes se sobrepõem.

### FE / BE / E2E no fechamento

| Frente | FE | BE | **E2E** |
| --- | --- | --- | ---: |
| L01 | 6/23 | 6/23 | **0/23** |
| L02 | 4/13 | 0/13 | **0/13** |
| L03 | 3/3 | 0/3 | **0/3** |
| **Grupo Claude** | — | — | **0/39** |

**L02 deliberadamente NÃO promoveu FE** depois da segunda auditoria, e a razão é
correta: provar que as rotas de Avisos montam a composição verifica **composição,
não comportamento completo da ação** — a mesma regra de que leitura não vira FE
verificado. Manteve 4/13. Registro como rigor, não como falta de entrega.

## Higiene de Git no fechamento — verificada por L00, não aceita por relato

- **L03**: eu detectei que os 62 PNGs de `failures/` **voltaram** à branch no
  commit `3688f224d`, que reintroduziu exatamente os que ele havia restaurado em
  `2af5dde69` — a execução do lote regenerou os artefatos e eles entraram junto
  com trabalho legítimo, em três domínios alheios (auth, help center, support).
  Ele restaurou de novo em `07a028b71`, commit próprio, sem reset, clean ou force
  push. **Verifiquei depois**: diff da branch contra a base devolve **32
  arquivos** e **zero resíduo** em `failures/`, `specs/`, `PRINCIPAL.md` ou nas
  fontes compartilhadas. Handoff corrigido para r7 (`fe3bbb61f`), registrando que
  aconteceu **duas vezes** em vez da afirmação errada de árvore limpa da r6.
- A regra que L03 adotou e escreveu no handoff, que vale para todas as frentes:
  **todo commit feito depois de rodar teste exige conferir o diff acumulado antes
  de qualquer anúncio de estado final.** Ele havia enunciado essa régua de manhã,
  aplicou uma vez e não reaplicou — anunciou "árvore limpa" olhando exatamente o
  indicador que ele mesmo dissera não servir.
- **L01**: verifiquei que o diff dele em `apps/superadmin/lib/app/router/` e
  `apps/superadmin/test/app/router/` contém **apenas dois arquivos**, ambos
  testes novos que documentam defeito. `superadmin_router.dart` **intocado**.

## Total de defeitos reais achados nesta rodada pelas frentes Claude

**Dezesseis**, dos quais a maioria invisível em lote verde. L03 sozinho achou
oito, seis corrigidos com prova e dois deliberadamente registrados sem correção
por serem decisão de composição aprovada. L02 achou o badge, o conflito de
Avisos, a divergência de gerações em métricas e o defeito de aplicação do próprio
pacote. L01 achou o feed misto, os quatro defeitos da retirada do Acontece, a
composição vazia do Agora e o retorno contextual.

**A frase que resume o dia, e é de L03:** nesta frente, teste de widget verde não
provou que a tela abre, que ela lê da fonte autorizada, nem que ela cabe na tela —
os três só apareceram auditando o caminho de composição, o redirect da rota real e
a matriz responsiva.

## Verificação final do pacote remoto — o defeito NÃO alcança os blocos A e B

Pergunta que ficou aberta quando o defeito apareceu: os pacotes que o Owner pode
autorizar hoje estão contaminados? **Não.** L01 conferiu e **eu reconferi na
branch dele**:

- `20260909133000_happens_post_withdrawal_v1.sql` (semeia `happens.posts.remove`)
  e `20260909136000_moments_feed_and_withdrawal_v1.sql` (semeia
  `moments.publications.remove`) **trazem os três rótulos** — duas ocorrências de
  `module_label` em cada, na lista de colunas e no `on conflict do update`.
- As outras quatro migrations do pacote **não tocam tabela de permissão**.

**Conclusão: o bloco A e o bloco B seguem aplicáveis** do ponto de vista deste
defeito. O que continua condicionando a aplicação é a autorização nominal do
Owner, o preflight de D00 e as pré-condições de cadeia já registradas.

## O que ficou fechado e o que continua aberto no caso de `20260901191921`

**Fechado:** a causa. Antes eu registrava "a única migration do território de L01
que falha no replay", sem causa e com risco de alguém atribuir ao harness.
**Não é harness** — são as três linhas acima.

**Aberto, e nenhuma frente pode fechar:** se ela chegou a aplicar em produção, ou
se foi ajustada fora do repositório. Exige acesso remoto que nenhuma frente tem e
nenhuma pediu. Mesma estrutura do caso de `20260901101500` (chat), e ambos são
preflight de D00 e decisão do Owner.

**Nenhuma frente alterou essas migrations**, conforme determinei: são de 01/09,
estado remoto desconhecido, e mexer em migration que possa já ter sido aplicada é
decisão de D00. A correção de referência está registrada como **recomendação**,
não como alteração.

## Atualização final de L03 — oitavo defeito preso em teste

HEAD **`dfac55bf4`**, handoff r8. **Verifiquei**: diff acumulado contra a base
devolve **33 arquivos** (os 32 anteriores mais o teste novo) e **zero resíduo**
em `failures/`, `specs/`, `PRINCIPAL.md` ou nas fontes compartilhadas.

**A regra que ele adotou funcionou:** conferiu o diff acumulado depois do commit
que veio de execução de teste, **antes** de anunciar. Desta vez a execução não
regenerou artefato — e ele conferiu mesmo assim, que é exatamente o ponto.

O teste `principal_profile_edit_preview_affordance_test.dart` tem três provas:
abaixo de 1120 px o botão "Pré-visualizar" renderiza com `onPressed` nulo, com
`reason` explicando que é defeito registrado; o defeito está **confinado às telas
estreitas**, porque a partir de 1120 px o editor mostra o painel embutido e
nenhum botão morto chega ao usuário; e o salvar continua habilitado, para separar
este defeito de uma tela quebrada.

O cabeçalho manda **inverter** a asserção quando o handler for ligado — habilitar
o botão e apagar a asserção de desabilitado — **em vez de relaxá-la**, e remover
a isenção de tela estreita. O widget compartilhado não foi tocado.

**Números finais de L03: P=214, F=10, B=0, S=0, U=0.** Taxa aprovada 95,54%,
execução 100%. As 10 seguem sendo o golden drift preexistente com controle em
worktree alheia. `flutter analyze` limpo. **FE 3/3, BE 0/3, E2E 0/3.**

**Balanço da frente:** oito defeitos reais, seis corrigidos com prova e dois
registrados por serem decisão de composição aprovada e não dele — e os dois
registrados estão **documentados**, um com medição de contraste e o outro **preso
em teste**. Defeito registrado sem prova executável some no próximo turno;
com prova, não some.

---

# Mapa de integração — simulação de merge feita por L00

Ninguém tinha previsto os conflitos que D00 vai encontrar. Fiz a simulação com
`git merge-tree --write-tree`, que é **leitura pura**: nada foi integrado, nenhuma
branch foi tocada, `dev` não foi mexido.

## Fato que muda o plano: D00 JÁ executou o movimento único de hospedagem

`dev` avançou **76 commits** desde a base comum `56eb3f19d` e está em `d7ce6976b`.
Dois desses commits tocam território Principal:

- **`f5e5d8dfc fix(superadmin): preserve the host across Principal routes`** —
  **366 linhas** alteradas em `superadmin_router.dart`, mais
  `principal_moments_publication_route.dart`, `principal_now_preview_page.dart` e
  `test/app/router/principal_real_route_test.dart`. **Confirmei no arquivo de
  dev**: `ShellRoute` na linha 755, e `principalNow` (852), `principalForYou`
  (949), `principalMoments` (957) e `principalProfile` (965) **todos dentro dele**.
  **O movimento que escalei foi feito.**
- **`7271f4a39 feat(principal): filter Para Você by authorized audience scope`** —
  mesmo assunto do `8c041ed50` de L03. D00 levou o trabalho dele para dev.

## Conflitos por frente, medidos

| Frente | Arquivos em conflito com `origin/dev` |
| --- | --- |
| **L01** | 2: `principal_moments_publication_route.dart` e `principal_now_preview_page.dart` |
| **L02** | 1: `superadmin_router.dart` |
| **L03** | 5: `superadmin_router.dart` e quatro de Para Você (adapter, preview data, route page e o teste do adapter) |

### Leitura dos conflitos

- **L01 não conflita no router.** A disciplina de não tocar no arquivo, que
  cobrei e ele cumpriu, é exatamente o motivo. Os dois arquivos que conflitam
  foram alterados **pelo próprio commit de hospedagem de D00**. É a demonstração
  prática de por que a regra valia.
- **L02 conflita só no router**, onde estava a reserva dele. Pedi que ele diga,
  trecho a trecho, o que precisa sobreviver — e em especial que a rota nova
  `/principal-conversations` provavelmente deve entrar **dentro** do `ShellRoute`
  como as outras, para D00 não deixá-la fora do shell.
- **Os quatro conflitos de Para Você em L03 são a mesma mudança chegando por dois
  caminhos**: o commit dele e o cherry-pick de D00. Não são divergência de
  conteúdo até prova em contrário — pedi que ele verifique se a versão de dev
  divergiu da dele e em quê.

## O que pedi às três frentes, e é trabalho de integração real

1. **Rodar as próprias provas contra a composição de dev.** É a pergunta de maior
   retorno agora: a hospedagem de D00 **corrigiu, manteve ou mudou** os defeitos
   que cada uma prendeu em teste? Para L01 especificamente, se o feed misto
   continua nunca sendo consultado, o teste dele segue válido; se D00 ligou a
   composição, o teste precisa ser **invertido**, como o próprio cabeçalho manda.
2. **Escrever, conflito a conflito, qual lado deve prevalecer e por quê.** Quem
   conhece o código é o autor; a análise economiza D00 e reduz risco de escolha
   errada.
3. **Marcar as propostas de hunks como superadas ou apontar o que ficou de fora.**
   Proposta obsoleta que fica no pacote sem aviso vira retrabalho para quem ler
   depois. Em particular, verificar se a cadeia por auth scope, app e main para
   `/principal-moments` — que L01 dizia ser maior que mover a rota — foi coberta.

**Nenhuma frente deve integrar `dev`.** Isso é de D00 e eu não pedi a ninguém.

## ALERTA DE INTEGRAÇÃO — a hospedagem em dev NÃO ligou as composições

**Verifiquei eu mesmo no `superadmin_router.dart` de `origin/dev`**, depois do
commit de hospedagem `f5e5d8dfc`. É o achado mais importante desta análise e é
exatamente o risco que eu havia registrado antes de ele acontecer: hospedar uma
rota que continua resolvendo para a tela de indisponível **parece progresso sem
ser**.

### O que a hospedagem entregou

As rotas Principal estão dentro do `ShellRoute` (linha 755): `principalHappens`
(789), `principalNow` (852), `principalForYou` (949), `principalMoments` (957) e
`principalProfile` (965). O shell do hospedeiro passa a ser construído para elas —
que é o que a decisão do Owner exigia.

### O que a hospedagem NÃO entregou

**1. Três rotas continuam resolvendo incondicionalmente para a tela de
indisponível**, agora hospedadas: `principalForYou` (949), `principalMoments`
(957) e `principalProfile` (965). O builder das três é
`builder: (context, _) => _unavailableCompositionRootRoute(context)` — destino
fixo, não `fail-closed` por repositório nulo. **O usuário passa a ver o menu do
hospedeiro em volta de uma tela que diz que a composição está indisponível.**

**2. O feed misto continua nunca sendo consultado.** `principalMixedFeedRepository`
aparece **uma única vez** no router de dev, na linha 282, **só a declaração do
parâmetro**. O builder de `principalHappens` (789) usa
`principalHappensFeedRepository` com `fail-closed` correto, mas **não** o feed
misto. Como `circulars.happens-card` é subaceite obrigatório de `acontece.feed`,
**esse ID continua sem poder fechar**, mesmo com a hospedagem feita.

### O que isso significa para a leitura do progresso

**Hospedagem e composição são duas coisas diferentes e só uma foi feita.**
Quem olhar o commit de hospedagem e concluir "Principal hospedado" estará certo
sobre o shell e errado sobre o produto: três das cinco telas continuam mostrando
indisponível dentro do shell novo.

**O trabalho que corrige duas das três já existe e não foi integrado.** L03 ligou
as composições reais de `principalProfile`, `principalProfileEdit` e
`principalForYou` na branch dele, com `profileAboutRepository` atravessando auth
scope, app e main. D00 levou de L03 apenas o cherry-pick do filtro de audiência
(`7271f4a39`), **não** a composition root. É por isso que a branch de L03
conflita em cinco arquivos e não em um.

`principalMoments` depende de L01, que declarou precisar da cadeia completa por
auth scope, app e main, porque `PrincipalMomentsFeedRepository` não aparece em
`app/` nem em `core/`.

### Recomendação a D00

Tratar a hospedagem como **primeira metade** e a composição como segunda, e não
declarar nenhuma ação Principal fechada por causa do movimento de hospedagem.
Os testes que L01 prendeu documentam o defeito do feed misto e **continuam
válidos contra dev** — não devem ser apagados como obsoletos. Integrar a
composition root de L03 fecha duas das três telas; `principalMoments` exige a
cadeia de L01.

## RISCO DE INTEGRAÇÃO SILENCIOSO — um conflito que NÃO pode ser resolvido por lado

L01 analisou os dois conflitos dele e um deles apaga função real se D00 resolver
no automático. **É o item mais acionável deste consolidado.**

**`principal_moments_publication_route.dart` EXIGE UNIÃO DOS DOIS LADOS.** São
mudanças diferentes no mesmo arquivo: `dev` acrescentou `embedded` e o repasse;
L01 acrescentou a porta `mediaPicker` com o seletor padrão. **Resolver por
"ficar com um dos lados" apaga função.** Ficando só com `dev`, a rota produtiva
de publicar Momentos **volta a não conseguir publicar nada**, porque o controller
exige ao menos uma mídia e não haverá porta de seleção — que é exatamente o
defeito que esta rodada corrigiu. As duas mudanças não se tocam; a união é
trivial. **Se for resolvido no automático, o risco é real e silencioso.**

**`principal_now_preview_page.dart` é benigno.** Os dois lados fizeram a mesma
coisa — flag `embedded` mais o helper que evita reaplicar os insets do
hospedeiro. Equivalentes. Recomendação de L01: **ficar com o lado de `dev`** e,
se for barato, reaproveitar os comentários que documentam a decisão do Owner.

## Convergência independente sobre o efeito do movimento

L01 chegou por leitura direta de `origin/dev` à mesma conclusão que eu havia
chegado por conta própria, e as duas análises batem: **nenhum defeito foi
corrigido pelo movimento, e nenhum teste precisa ser invertido.**

Em `dev`, depois da hospedagem: o builder de `/principal-happens` continua
passando `feedRepository` e `data: PrincipalHappensPreviewData.empty` **sem**
`mixedFeedRepository`; o carrossel Agora continua alimentado pelo fixture vazio;
as quatro guardas de nulo de publicar no Acontece continuam, e a mesma no Agora;
`onClose` e `onOpenHappens` continuam `goNamed` em vez de `pop`; e
`/principal-moments` continua devolvendo `_unavailableCompositionRootRoute` direto.

**Achado colateral que L01 passou a L03:** em `dev`, `/principal-profile` também
resolve **incondicionalmente** para a composição indisponível, no mesmo formato
de `/principal-moments`. Se L03 considerava a rota fora do fail-closed, o estado
integrado não reflete isso.

## Estado das propostas de hunks: PARCIALMENTE superadas

L01 marcou no próprio arquivo, para não virar retrabalho. **Superado:** mover as
rotas e passar `embedded`. **NÃO superado:** toda a cadeia de injeção — em `dev`
o router ainda não usa `principalMixedFeedRepository`,
`PrincipalMomentsFeedRepository` **não existe** na composição, e
`CircularMediaRepository` não é injetado. **As três injeções continuam
necessárias e nenhuma foi feita.**

### A frase que resume, e é de L01

**A hospedagem resolveu o encaixe visual e não resolveu o acesso ao dado.**
Depois do movimento, `/principal-moments` continua sem saída, o Acontece continua
sem a projeção de Circulares que virou subaceite obrigatório de `acontece.feed`,
e as duas rotas de publicação continuam com o beco do ator institucional.
**O movimento era necessário e não era suficiente.**

---

# Resolução de conflitos escrita pelas frentes — instruções para D00

As três analisaram os próprios conflitos e escreveram, trecho a trecho, o que
deve prevalecer. Nenhuma integrou `dev`, nenhuma fez merge ou rebase: tudo foi
`merge-tree` e `git show`, leitura pura. Destaco os pontos onde resolver no
automático causa dano.

## PERIGO 1 — tomar o lado de `dev` em Para Você REINTRODUZ um buraco de segurança

L03 diffou `origin/dev` contra a HEAD dele arquivo a arquivo. **`dev` tem a
versão ANTIGA dele** — o `8c041ed50` que D00 levou como `7271f4a39`. Nessa
versão o `scope` de audiência é **opcional** e o adapter ainda injeta sprite de
estoque em toda comunicação.

A versão da branch dele tornou o escopo **obrigatório** em `highlights` e
`isEligible`, tirou o asset, e preservou os seis atalhos aprovados.

**Tomar o lado de `dev` nos quatro arquivos de Para Você reintroduz o buraco:**
gate de autorização opcional é um argumento que se esquece de passar e desliga a
verificação **em silêncio** — e o teste que em `dev` afirma o caminho sem escopo
é justamente o que L03 inverteu. **Prevalece a branch de L03 nos quatro.**
Isso é segurança, não preferência.

## PERIGO 2 — sem a declaração de capacidade, a rota de edição volta a ser inalcançável

Só existe do lado de L03 e **precisa ser acrescentada**: o GoRoute de
`/principal-profile/edit` (que **não existe em `dev`**), os dois parâmetros
opcionais, os imports, e **a declaração em `hasAuthoritativeMutationCapability`**.
Sem ela, a guarda global de mutação volta a mandar toda visita para a tela de
erro — que foi um dos defeitos que L03 achou e corrigiu hoje.

## PERIGO 3 — sem trocar os três destinos, a hospedagem só reposiciona o defeito

L02 verificou que os **três** destinos `?from=principal` continuam em `dev`
(linhas 699, 810 e 5468). Se a resolução perder essa troca, **o launcher do
Principal volta a abrir a página administrativa** e a hospedagem terá
reposicionado o defeito em vez de resolvê-lo. A rota nova
`/principal-conversations` precisa entrar **dentro** do `ShellRoute` com
`embedded: true`, não ficar de fora. E a guarda `is UnavailableChatRepository` no
badge tem de sobreviver intacta, senão volta o zero silencioso.

`chatUnreadCountLoader` **não aparece em `dev`** — não é que não sobreviveu:
nunca esteve lá, vem com o merge de L02.

## PERIGO 4 — o conflito que exige união, repetido porque é o mais fácil de errar

`principal_moments_publication_route.dart`: `dev` acrescentou `embedded`, L01
acrescentou a porta `mediaPicker`. **Ficar com um lado apaga função** e a rota
produtiva volta a não conseguir publicar nada. União trivial, dano silencioso.

## Resolução recomendada do router, na forma que L03 propôs e eu endosso

**Prevalece `dev` na colocação** — os GoRoute ficam dentro do `ShellRoute`, não
reverter. **Prevalece a branch da frente no corpo de cada builder** — trocar
`_unavailableCompositionRootRoute` pelo builder real e acrescentar
`embedded: true`, que as composition roots já aceitam desde `7ca7ee63a`, feito
exatamente para este cenário. **As duas metades são complementares, não
concorrentes:** D00 resolveu a colocação, a composição continua nas branches.
É por isso que o conflito do router é de forma, não de intenção.

## Por que as provas não podem ser rodadas contra `dev` puro

L03 respondeu com o motivo em vez de deixar em aberto: as 11 provas dele chamam
`createSuperadminRouter` com `profileAboutRepository` e
`principalCircularRepository`, que **não existem em `dev`** — não compilam; e
asserem composição real, que em `dev` é **falsa por construção**. Elas exercitam
exatamente a composição da resolução recomendada e devem ser reexecutadas
**depois do merge**; se alguma quebrar ali, é achado do merge e não da branch.
Cada frente deixou escrita a lista mínima a reexecutar — L02 indicou
`principal_chat_route_test.dart`, `chat_unread_badge_wiring_test.dart` e
`chat_routes_test.dart`, que são os que afirmam os pontos acima e falham se a
resolução perder algum.

## pgTAP de L02 passou a executar — resultado misto, mantido bloqueado

Com os ajustes de harness de L01 mais dois shims que ele próprio criou
(`auth.users.email_confirmed_at` e a tabela `auth.sessions`), L02 conseguiu
montar a base: replay com `check_function_bodies=off` (123/166), baseline
`20260901101500` aplicada com os rótulos destravados **no container**,
`not null` restaurado — e então **o pacote dele aplicou sem nenhum ajuste**.
**Prova direta de que a correção de rótulos funciona.**

**Resultado: 14 `ok`, 21 `not ok`.** Ele não maquiou.

**E rodou um controle de propósito:** executou no mesmo ambiente o pgTAP
**pré-existente** `superadmin_internal_chat_v2_test.sql`, que não é dele —
**8 `ok`, 13 `not ok`**, mesmo padrão: estrutural e grants passam, funcional
falha em bloco. Isso **identifica a causa**: o ambiente shimado não estabelece
contexto interno autenticado, `require_superadmin_internal_context` nega tudo, e
qualquer gateway falha, dele ou não. **As falhas funcionais são do harness.**

**Ficou provado:** as duas funções existem com assinatura exata; `authenticated`
invoca e `PUBLIC` não; `chat.internal.manage` existe com MFA e pertence ao
`owner`; a trilha é RPC-only sob RLS forçada; o envelope da spec 039 é
respeitado; e o pacote **aplica** com o `not null` ativo.

**NÃO ficou provado:** nenhum comportamento de editar, revogar ou projetar recibo.

**Ele manteve o `B=1` bloqueado**, e a justificativa é exatamente certa: verde
nesse ambiente não valeria, e o vermelho não condena o pacote. Um assert ele se
recusou a classificar como harness sem verificar — `not ok 3`, `has_table` da
trilha de edição, que pode ser qualificação de schema no teste.

Rodar um controle com teste alheio para separar falha de produto de falha de
ambiente é o método correto e vale registrar como padrão para a Etapa 2.

## Nono achado de L03 — acessibilidade, encontrado ao escrever a cobertura

A aba Acontece ganhou 11 provas responsivas e de acessibilidade, e escrevê-las
achou o defeito: o card de publicação **não tinha `explicitChildNodes`**, então o
leitor de tela anunciava autor, contexto, corpo e métricas como **um bloco único**
em vez de permitir navegar entre eles. Corrigido em `0128ab8e0`.

É a segunda vez no dia que **escrever a prova que faltava** produz um defeito,
e vale como método: ausência de cobertura não é estado neutro.

Diff acumulado de L03 conferido depois de tudo: **35 arquivos**, zero resíduo.

## Conhecimento durável capturado — e por que ele vale mais que a correção

L02 investigou se existia um **gerador ou modelo** que tivesse originado as três
migrations quebradas. **Não existe.** Ele procurou template, scaffold e
generator; os arquivos com "template" no nome são de *templates de atividade*,
conceito de produto, não andaime de migration. Nem as skills nem os planos
documentavam o padrão de insert de permissão. **As três se replicaram por cópia,
numa mesma passagem de autoria.**

Isso muda a natureza da prevenção: **não há modelo para consertar**. O que
protege o futuro é a invariante estar escrita onde o agente lê **antes** de
escrever o próximo pacote. Ele registrou em
`.agents/skills/coelo-supabase/SKILL.md`, seção de migrations, commit `97407afd`:

> Pacote revisável não é pacote aplicável: exercitar a aplicação sobre uma base
> que já tenha as migrations anteriores, não só escrever guarda de dependência.
> Uma guarda bem escrita recusa o que falta; ela não descobre que o próprio
> insert viola constraint criada depois.

**Aprovei a redação.** Ela separa duas coisas que se confundem com facilidade e
explica por que o pacote dele passou por revisão e ainda assim não teria
aplicado. O caso medido vai junto — a data, o `not null` sem default, as três
migrations, e a **regra de comparar a data** antes de tratar ocorrência como
defeito, que é o que salva o próximo leitor de revisar catorze arquivos sãos.

**A skill precisa viajar no delta para D00 integrar**, não ficar só na worktree
de L02 — regra do `AGENTS.md`, que ele aplicou sem eu precisar lembrar.

## Convergência independente na varredura de migrations

L01 e L02 varreram por caminhos próprios e chegaram ao **mesmo conjunto**:
3 reais (`20260901101500` l.18, `20260901185008` l.136, `20260901191921` l.109)
e **14 falsas** anteriores ao corte `20260831130726`. Convergência por caminhos
separados é evidência melhor que confirmação de um pelo outro. Nenhuma das três
foi alterada por nenhuma frente, conforme determinei.

## Um assert que ficou honestamente sem causa

L02 tinha deixado o `not ok 3` explicitamente em aberto e voltou para fechá-lo
até onde dava: **não é tabela ausente** — o assert é qualificado corretamente, e
o teste 10 passou dereferenciando
`app_private.superadmin_internal_chat_message_edits::regclass`, o que falharia
com erro duro se a relação não existisse. É nuance da asserção `has_table` do
pgTAP naquele ambiente, e ele **não afirma a causa exata porque não a isolou**.

Fechar o que dá e declarar o resto como não isolado é o mesmo critério que o fez
manter o `B=1` bloqueado. Vai assim ao relatório.

---

# Snapshot de consolidação — verificado por L00 antes do corte das 16:00

## Git das quatro branches Claude

| Frente | HEAD local | Remoto | Sincronizado | Não commitado | Stash |
| --- | --- | --- | --- | ---: | ---: |
| L00 | `05df77889` | igual | SIM | 0 | 0 |
| L01 | `47e1f1cc6` | igual | SIM | 2 | 0 |
| L02 | `97407afdb` | igual | SIM | 5 | 0 |
| L03 | `e35f33591` | igual | SIM | 0 | 0 |

**Zero stashes em todas.** Nenhuma frente integrou `dev`, que está em `605e2a236`.

### Separação SHA apto × WIP — o que o snapshot achou

- **L01, 2 arquivos**: as duas fontes compartilhadas que **eu instruí** a manter
  preservadas e não commitadas. Esperado, não é WIP.
- **L03, árvore limpa.**
- **L02, 5 arquivos** — e **dois são código real não commitado**:
  `principal_chat_page.dart` e `principal_chat_page_test.dart`. Não estavam no
  HEAD, não havia stash, e existiam **apenas no disco**. Alertei a cinco minutos
  do corte, com a instrução de commitar como apto se verde ou **como WIP
  declarado** se parcial — o contrato manda separar, não descartar. Foi o único
  risco material que o snapshot encontrou em quatro branches, e é a justificativa
  de fazer o snapshot **antes** e não no horário.

## Handoffs lidos pelos caminhos absolutos

L01 655 linhas, L02 871, L03 478 — todos presentes e atualizados nas worktrees
registradas.

## Propostas publicadas, que são o pacote real para D00

**L01 (7):** negativas comportamentais do Acontece; prova local da retirada;
mapeamento de Circulares; contrato de mídia de chat; hunks de composição;
**pacote remoto nominal**; resolução de conflitos com dev.
**L02 (2):** hunk do shell do chat Principal; materialização de notices.publish.
**L03 (3):** análise de conflitos com dev; hunks de hospedagem (marcada como
superada na colocação); **verificação pós-merge do grupo**.

## Duas correções de L03 aos insumos que eu passei, ambas aceitas

1. **Dois dos três destinos `?from=principal` são de L03**, não de L02 — a ação
   Mensagem do Perfil e o launcher do hub, ambos apontando hoje para
   `conversationsName`. Quando a rota de L02 existir na base integrada, é uma
   linha em cada callback. Ele não fez a troca porque **a rota não existe na base
   dele**, e registrou o motivo para ninguém ler como esquecimento.
2. **As ~191 falhas fora de recorte NÃO são "pré-existentes".** São **não
   revalidadas**: ninguém estabeleceu baseline. Eu as havia listado junto das
   goldens conhecidas e a diferença importa — **as goldens têm controle, essas
   não têm**. Correção adotada em todo o consolidado.

## Varredura de capacidade concluída no recorte de L03

Só existe `/principal-profile/edit`, já declarado. `/circulars/new` e
`/circulars/:id/edit` estão cobertos pelo `startsWith('/circulars')` existente.
`/profiles/...` e `/profile-models/...` são **isentos por desenho**, com
comentário no código dizendo que as RPCs revalidam ator, escopo, MFA e versão no
servidor.

**Candidata fora do recorte, registrada como PERGUNTA e não como achado:**
`/health-care/profiles/new` e `/health-care/profiles/:childId/edit` — não há
`startsWith('/health-care')` em `hasAuthoritativeMutationCapability`, o que as
deixaria sempre redirecionadas. **Pode ser fechamento intencional do domínio de
saúde.** Não é do grupo Claude julgar; fica para quem responde por ele.

## Disciplina de proveniência na checklist

L03 marcou, item a item, **o que verificou em código e o que veio relatado** —
incluindo declarar que **não** conferiu o perigo de Momentos, porque o arquivo
não existe na base dele. Misturar as duas coisas é o que faz o integrador confiar
demais numa peça e de menos noutra.

---

# CORREÇÃO DE L00 — eu inverti a semântica dos testes que documentam defeito

Erro meu, apanhado por L01 antes de virar instrução operacional. **É a correção
mais consequente que recebi hoje**, porque estava a caminho da checklist que D00
usaria no merge.

**O que eu escrevi, errado:** que `principal_happens_composition_gaps_test.dart`,
`principal_now_real_route_test.dart` e
`principal_profile_edit_preview_affordance_test.dart` **não devem passar** depois
do merge, e que verde inesperado neles seria suspeita.

**O correto:** esses testes **asseveram o comportamento defeituoso de hoje**.

- **VERDE é o esperado** enquanto o defeito existir. É o estado normal.
- **VERMELHO significa que alguém corrigiu a composição** — e aí o teste precisa
  ser **INVERTIDO, não apagado**, como o cabeçalho de cada um manda.

**O risco da minha versão errada era concreto**, e L01 nomeou os dois modos de
falha: alguém vê verde e abre investigação à toa; ou, pior, vê vermelho, conclui
que é falha e **"conserta" o teste apagando a prova do defeito**. O segundo não
tem volta.

**A raiz do erro, que vale como regra:** teste que documenta defeito tem
**semântica trocada** em relação a um teste comum, e por isso precisa estar
marcado como tal em qualquer lista de verificação. Foi exatamente o tipo de coisa
que se lê ao contrário — eu li ao contrário **enquanto escrevia a instrução**.
Pedi a L03 que corrija a checklist e referencie a formulação de L01, publicada em
`propostas/L01-resolucao-conflitos-dev.md` (`80fa94750`).

## Blocos prontos para colar de L01 — `80fa94750`

**Conflito perigoso, `principal_moments_publication_route.dart`:** o arquivo
resolvido **inteiro**, com a união dos dois lados, mais a lista das diferenças em
relação a `dev` para conferência rápida — o import de `file_picker`, o parâmetro
`this.mediaPicker`, o campo, a linha
`mediaPicker: widget.mediaPicker ?? pickMomentsMediaFiles` no `build`, e as duas
funções de apoio. Todo o resto idêntico a `dev`, **inclusive
`embedded: widget.embedded`**, que substitui o `embedded: false` da branch dele.
Verificação após aplicar: **88 aprovados**.

**Conflito benigno, `principal_now_preview_page.dart`:** ficar integralmente com
`dev`. Os comentários de L01 ficam como reaproveitamento opcional, porque
registram **por que** a flag existe — e esse porquê some no código de `dev`.

### As três injeções, com uma surpresa boa

**A do feed misto é um SÍTIO ÚNICO.** L01 verificou que a cadeia já está inteira
em `dev` — instanciado no auth scope, declarado, `null` no caminho sem sessão,
repassado no app e no main, chegando ao parâmetro do router — e **só o builder
não usa**. O bloco entregue usa o construtor `.mixed` quando o repositório
existir, mantendo o caminho atual como exceção.

Cuidado não óbvio que ele registrou: **`.mixed` fixa `feedScope = null`**, então
a página passa a ler **só** o feed misto. É o desejado, porque a RPC já devolve
publicações e Circulares, mas **muda o caminho de leitura**.

**Momentos e mídia de Circulares exigem a cadeia completa de quatro passos** —
auth scope, app, main e router — com as linhas de `dev` como âncora. Nenhuma das
duas classes aparece em qualquer ponto da composição de `dev`. **Aplicação
parcial não compila**, e o analisador pega.

### Prioridade recomendada por L01, se D00 tiver tempo para uma só

**A injeção do feed misto.** Um sítio, cadeia pronta, e fecha o subaceite
obrigatório `circulars.happens-card` de `acontece.feed` — hoje o que impede
aquele ID de fechar. Melhor relação custo-benefício das três.

## Blocos prontos para colar de L02 — `60d271ee`

Apêndice de `propostas/L02-hunk-principal-chat-shell.md`. Trechos finais já
reindentados para onde entram, ancorados em `origin/dev` `d7ce6976` lido **sem
merge**:

1. As **4 constantes** de `superadmin_routes.dart`, separadas entre `principal*`
   e `devPrincipal*`.
2. O import de `principal_chat_page.dart`.
3. O `GoRoute` de `/principal-conversations` **com indentação de 10 espaços**,
   igual às irmãs a partir da linha 788, com `embedded: true` e a falha fechada
   preservada.
4. O `GoRoute` de `/dev/principal-conversations`, mesma lista.
5. Os **três destinos** com o "de/para" literal e as linhas de `dev`
   identificadas: **697-700, 808-811 e 5465-5469**.
6. As **três inserções** do `chatUnreadCountLoader`, incluindo a do
   `SuperadminShell.host` reescrito, posicionada logo após `onDestinationSelected`.
7. As duas linhas de mídia da preview `/dev/conversations`.

Mais uma tabela dos **quatro perigos e qual teste pega cada um**: rota fora do
`ShellRoute` → `principal_chat_route_test`; destino não trocado →
`chat_routes_test` e `principal_chat_route_test`; guarda do badge perdida →
`chat_unread_badge_wiring_test`; mídia da preview perdida → o mesmo.

### O aviso que L02 destacou, e que eu repito porque é o mais fácil de perder

**A guarda `is UnavailableChatRepository` NÃO é opcional.** Sem ela o shell chama
o repositório fail-closed, cujo `fetchUnreadTotal` devolve `0`, e o launcher passa
a afirmar **"não há não lidas" quando na verdade não sabe**. Perder essa condição
no merge **transforma a correção no defeito que ela consertou** — e passa
despercebido, porque o código continua compilando e o teste que a pega é um só.

É a mesma família de todos os achados do dia: a interface afirmando um fato que
ela não tem como sustentar.

## Checklist corrigida — e a correção teve dois autores do erro

L03 corrigiu em `7c30b41e2` e acrescentou algo que eu não teria escrito por ele:
**ele tinha a prova na mão e não conferiu.**

O `principal_profile_edit_preview_affordance_test.dart` dele passou **3/3** quando
rodou, e o cabeçalho que ele mesmo escreveu manda inverter a asserção quando o
handler for ligado. Ou seja: tinha a execução verde e o cabeçalho na frente, e
ainda assim escreveu que verde ali seria suspeita. **Propagou a inversão sem
confrontar com o próprio artefato.**

A lição que ele registrou, e que é melhor que "L00 errou": **instrução repassada
precisa ser confrontada com o artefato antes de virar lista de verificação** — e
ele tinha como fazer isso em segundos.

A seção agora usa a formulação de L01, referenciada como canônica em vez de
duplicada, e a tabela de L03 só acrescenta o arquivo dele. Os dois modos de falha
de leitura estão registrados, incluindo o grave: ver vermelho, chamar de falha do
merge e **"consertar" o teste apagando a prova do defeito**.

Ele também incorporou, marcado como **relatado** e não verificado, o insumo novo
de L01 sobre as três injeções ordenadas por custo, e sugeriu que D00 faça a do
feed misto **junto com o merge**, porque é uma linha, separando as duas de cadeia
completa.

## Observação de fechamento, de L03, que eu adoto

> Três correções em um dia num canal de coordenação não é sinal de processo ruim
> — é sinal de que o canal está funcionando, porque as três foram pegas antes de
> virar dano. A que mais me preocupa das minhas é a que ninguém pegou ainda, se
> houver.

Registro porque é a postura certa para D00 herdar: o valor do canal não está em
não errar, está em o erro ser apanhado por outro antes de virar instrução.
Hoje foram quatro correções recebidas por mim e pelo menos três feitas pelas
frentes sobre si mesmas — L01 estreitou duas afirmações próprias, L02 reverteu
uma correção por falta de prova e corrigiu o próprio achado para maior, L03
corrigiu o próprio relato de dois para quatro arquivos varridos. **Nenhuma delas
chegou ao consolidado como fato.**

## O conflito de L02 MEDIDO — o trabalho manual é 2 pontos, não 7

L02 mediu em vez de descrever, e o resultado **reduz e reordena** a instrução que
eu ia dar a D00. **Confirmei por conta própria** com `git merge-tree`:
**um arquivo, uma única região de conflito** em `superadmin_router.dart`.

A natureza do conflito importa: **não é disputa linha a linha**. O lado de `dev`
naquela região está **vazio** — o bloco são as rotas `/principal-*` de produção
que `dev` **moveu** para dentro do `ShellRoute`. É "um lado acrescenta num bloco
que o outro removeu".

### O git já resolveu quase tudo, verificado no resultado

Vieram **automaticamente**: as **3** inserções de `chatUnreadCountLoader`, a rota
`/dev/principal-conversations` e suas constantes, o destino do menu de
desenvolvimento, o destino de `/dev/principal-happens`, e as duas linhas de mídia
da preview. Restou **um** `?from=principal` no arquivo inteiro.

### Sobram exatamente dois pontos manuais

1. **Reinserir a rota de produção `/principal-conversations` dentro do
   `ShellRoute`**, com `embedded: true`. **Aqui está o risco que a medição
   revelou:** resolver o conflito **ficando com o lado de `dev` descarta essa
   rota**, porque ela vive dentro da região que `dev` esvaziou. É o erro mais
   provável desta resolução e é **silencioso** — compila, e só
   `principal_chat_route_test.dart` acusa.
2. **Trocar o único `?from=principal` restante**, por volta da linha 1030 do
   resultado: o `onOpenMessages` de `/principal-happens` de produção, dentro do
   bloco que `dev` moveu.

### A instrução para D00 muda de forma

**Não é "aplicar 7 pontos". É "fazer 2 e não estragar 2".** Os outros dois
perigos da tabela — a guarda do badge e a mídia da preview — **já vieram
automaticamente** e agora só precisam **não ser desfeitos** durante a resolução
manual.

Isso é diferente e mais fácil de errar: manter algo que o git já acertou exige
atenção passiva, que é justamente a que falta numa resolução manual apressada.

**Nenhuma integração aconteceu.** `merge-tree --write-tree` não escreve na árvore
de trabalho nem cria commit; nenhuma frente fez merge ou rebase.

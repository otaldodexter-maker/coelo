---
title: "L01 - Hunks de composicao: midia de Circulares e feed produtivo de Momentos"
source: "Frente L01 (Publicacoes) - Etapa 2, rodada R02, worktree e2-r02-l01-publicacoes"
status: "patch-pronto-para-aplicacao-pelo-coordenador"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Objetivo

Este documento entrega os hunks exatos de duas injecoes de composicao. Os arquivos
de composicao (`superadmin_auth_scope.dart`, `superadmin_app.dart`,
`superadmin_router.dart`, `main.dart`) sao reservados ao coordenador, por isso a
frente L01 descreve o patch em vez de aplica-lo. Nenhum arquivo de codigo foi
alterado por esta frente ao produzir este documento.

Ambas as injecoes atravessam a mesma cadeia de composicao, confirmada por leitura:

1. `apps/superadmin/lib/core/config/superadmin_auth_scope.dart` - declara o campo,
   constroi a instancia com o `SupabaseClient` no caminho autorizado e devolve o
   valor fail-closed no caminho sem sessao (`_createUnavailableScope`).
2. `apps/superadmin/lib/app/superadmin_app.dart` - campo do widget e repasse para
   `createSuperadminRouter`.
3. `apps/superadmin/lib/app/router/superadmin_router.dart` - parametro nomeado de
   `createSuperadminRouter` e uso no builder da rota.
4. `apps/superadmin/lib/main.dart` - repasse do `authScope` para `SuperadminApp`.

O router **nao** tem acesso ao `SupabaseClient`; ele so recebe repositorios ja
construidos. Por isso nenhuma das duas injecoes cabe apenas no router.

## Base de aplicacao

A ordem de integracao combinada e **L03, depois L01, depois L02**. Os hunks abaixo
estao ancorados no estado publicado de `origin/codex/e2-r02-l03-perfil-para-voce`,
que foi lido com sucesso (`git show` redirecionado para
`C:/Users/adrie/AppData/Local/Temp/`, fora do repositorio). Os numeros de linha
citados sao os dessa versao de L03. Ver a secao "Ordem e colisoes" ao final.

---

# Injecao A - repositorio de midia de Circulares

## Por que e necessaria

Sem `mediaRepository`, `ProductionCircularComposerHost` nunca constroi o
`CircularMediaUploadCoordinator` e toda tentativa de anexar cai no caminho de
excecao `'Envio de anexos indisponivel nesta composicao.'`
(`apps/superadmin/lib/features/circulars/presentation/production_circular_hosts.dart:248`),
mesmo com selecao e envio de anexos ja implementados.

Sem o repasse equivalente em `PrincipalCircularReader`, os anexos existentes nao
abrem na leitura: o widget mantem os anexos honestamente fechados quando
`mediaRepository` e nulo.

## Arquivos a tocar, em ordem

1. `apps/superadmin/lib/core/config/superadmin_auth_scope.dart`
2. `apps/superadmin/lib/app/superadmin_app.dart`
3. `apps/superadmin/lib/app/router/superadmin_router.dart`
4. `apps/superadmin/lib/main.dart`
5. `apps/superadmin/lib/features/principal_circulars/presentation/principal_circular_detail_page.dart` (independente da cadeia; ver nota A.6)

## A.1 - `superadmin_auth_scope.dart`

### A.1.a Imports novos (junto do bloco de imports `principal_circulars`, hoje nas linhas 35-36)

ANTES:

```dart
import '../../features/principal_circulars/data/supabase_principal_mixed_feed_repository.dart';
import '../../features/principal_circulars/domain/principal_happens_mixed_feed.dart';
```

DEPOIS:

```dart
import '../../features/principal_circulars/data/supabase_circular_auxiliary_repositories.dart';
import '../../features/principal_circulars/data/supabase_principal_mixed_feed_repository.dart';
import '../../features/principal_circulars/domain/circular_repository.dart';
import '../../features/principal_circulars/domain/principal_happens_mixed_feed.dart';
```

### A.1.b Parametro do construtor (aprox. linha 154, versao L03)

ANTES:

```dart
    this.principalRuntimeContextRepository,
    this.profileAboutRepository,
```

DEPOIS:

```dart
    this.principalRuntimeContextRepository,
    this.circularMediaRepository,
    this.profileAboutRepository,
```

### A.1.c Campo (aprox. linha 206, versao L03)

ANTES:

```dart
  final PrincipalRuntimeContextRepository? principalRuntimeContextRepository;
  final ProfileAboutRepository? profileAboutRepository;
```

DEPOIS:

```dart
  final PrincipalRuntimeContextRepository? principalRuntimeContextRepository;

  /// Capacidade de midia do dominio Circulares. Ausente, o compositor e o leitor
  /// permanecem fail-closed para anexos em vez de simular uma selecao local.
  final CircularMediaRepository? circularMediaRepository;
  final ProfileAboutRepository? profileAboutRepository;
```

### A.1.d Caminho autorizado (aprox. linha 369, versao L03)

ANTES:

```dart
      principalRuntimeContextRepository: SupabasePrincipalRuntimeContextRepository(client),
      profileAboutRepository: SupabaseProfileAboutRepository(client),
```

DEPOIS:

```dart
      principalRuntimeContextRepository: SupabasePrincipalRuntimeContextRepository(client),
      circularMediaRepository: SupabaseCircularMediaRepository(client),
      profileAboutRepository: SupabaseProfileAboutRepository(client),
```

### A.1.e Caminho sem sessao, em `_createUnavailableScope` (aprox. linha 438, versao L03)

ANTES:

```dart
    principalRuntimeContextRepository: null,
    profileAboutRepository: null,
```

DEPOIS:

```dart
    principalRuntimeContextRepository: null,
    circularMediaRepository: null,
    profileAboutRepository: null,
```

> Divergencia observada em relacao ao briefing: **nao existe**
> `UnavailableCircularMediaRepository` no repositorio. O contrato
> `CircularMediaRepository`
> (`apps/superadmin/lib/features/principal_circulars/domain/circular_repository.dart:234`)
> nao tem implementacao "Unavailable"; o seam ja e nulavel e o proprio
> `ProductionCircularComposerHost` documenta que "when it is absent the composer
> stays fail-closed for attachments". Portanto o padrao fail-closed correto aqui e
> `null`, como em `principalHappensFeedRepository`, e nao uma implementacao
> "Unavailable" como em `circularRepository` (que e o `SuperadminCircularRepository`,
> outro contrato).

## A.2 - `superadmin_app.dart`

### A.2.a Import novo

ANTES (contexto: bloco de imports de features; L03 introduziu a linha 62):

```dart
import '../features/profile_about/domain/profile_about_repository.dart';
```

DEPOIS:

```dart
import '../features/principal_circulars/domain/circular_repository.dart';
import '../features/profile_about/domain/profile_about_repository.dart';
```

(o import deve respeitar a ordenacao alfabetica ja praticada no arquivo; o ponto
material e que `CircularMediaRepository` passa a ser um nome resolvido aqui.)

### A.2.b Parametro do construtor (aprox. linha 142, versao L03)

ANTES:

```dart
    this.principalRuntimeContextRepository,
    this.profileAboutRepository,
```

DEPOIS:

```dart
    this.principalRuntimeContextRepository,
    this.circularMediaRepository,
    this.profileAboutRepository,
```

### A.2.c Campo (aprox. linha 197, versao L03)

ANTES:

```dart
  final PrincipalRuntimeContextRepository? principalRuntimeContextRepository;
  final ProfileAboutRepository? profileAboutRepository;
```

DEPOIS:

```dart
  final PrincipalRuntimeContextRepository? principalRuntimeContextRepository;
  final CircularMediaRepository? circularMediaRepository;
  final ProfileAboutRepository? profileAboutRepository;
```

### A.2.d Repasse para o router (aprox. linha 276-279, versao L03)

ANTES:

```dart
      principalRuntimeContextRepository:
          widget.principalRuntimeContextRepository ??
          const UnavailablePrincipalRuntimeContextRepository(),
      profileAboutRepository: widget.profileAboutRepository,
```

DEPOIS:

```dart
      principalRuntimeContextRepository:
          widget.principalRuntimeContextRepository ??
          const UnavailablePrincipalRuntimeContextRepository(),
      circularMediaRepository: widget.circularMediaRepository,
      profileAboutRepository: widget.profileAboutRepository,
```

## A.3 - `superadmin_router.dart`

### A.3.a Import novo

ANTES (linha 143 na baseline L01; na versao L03 o bloco `principal_circulars`
continua com uma unica entrada de dominio):

```dart
import '../../features/principal_circulars/domain/principal_happens_mixed_feed.dart';
```

DEPOIS:

```dart
import '../../features/principal_circulars/domain/circular_repository.dart';
import '../../features/principal_circulars/domain/principal_happens_mixed_feed.dart';
```

### A.3.b Parametro nomeado de `createSuperadminRouter` (aprox. linha 283-284, versao L03)

ANTES:

```dart
  PrincipalRuntimeContextRepository principalRuntimeContextRepository =
      const UnavailablePrincipalRuntimeContextRepository(),
  ProfileAboutRepository? profileAboutRepository,
```

DEPOIS:

```dart
  PrincipalRuntimeContextRepository principalRuntimeContextRepository =
      const UnavailablePrincipalRuntimeContextRepository(),
  CircularMediaRepository? circularMediaRepository,
  ProfileAboutRepository? profileAboutRepository,
```

### A.3.c Rota `circularCreate` (aprox. linha 4464, versao L03; linha 4391 na baseline L01)

ANTES:

```dart
              child: ProductionCircularComposerHost(
                repository: circularRepository,
                institutionRepository: institutionDirectoryRepository,
                onCancel: () => context.goNamed(SuperadminRoutes.circularsName),
                onDone: () => context.goNamed(SuperadminRoutes.circularsName),
              ),
```

DEPOIS:

```dart
              child: ProductionCircularComposerHost(
                repository: circularRepository,
                institutionRepository: institutionDirectoryRepository,
                mediaRepository: circularMediaRepository,
                onCancel: () => context.goNamed(SuperadminRoutes.circularsName),
                onDone: () => context.goNamed(SuperadminRoutes.circularsName),
              ),
```

### A.3.d Rota `circularEdit` (aprox. linha 4504, versao L03; linha 4431 na baseline L01)

ANTES:

```dart
                child: ProductionCircularComposerHost(
                  repository: circularRepository,
                  institutionRepository: institutionDirectoryRepository,
                  circularId: circularId,
                  onCancel: () => context.goNamed(
```

DEPOIS:

```dart
                child: ProductionCircularComposerHost(
                  repository: circularRepository,
                  institutionRepository: institutionDirectoryRepository,
                  mediaRepository: circularMediaRepository,
                  circularId: circularId,
                  onCancel: () => context.goNamed(
```

## A.4 - `main.dart` (aprox. linha 55-56, versao L03)

ANTES:

```dart
      principalRuntimeContextRepository: authScope.principalRuntimeContextRepository,
      profileAboutRepository: authScope.profileAboutRepository,
```

DEPOIS:

```dart
      principalRuntimeContextRepository: authScope.principalRuntimeContextRepository,
      circularMediaRepository: authScope.circularMediaRepository,
      profileAboutRepository: authScope.profileAboutRepository,
```

Nenhum import novo em `main.dart`: o valor apenas trafega do `authScope` para o
widget.

## A.5 - O que quebra se aplicarem so parte da cadeia

**O codigo nao compila.** Especificamente:

- Aplicar somente A.3 (router): erro de compilacao `Undefined name
  'circularMediaRepository'` nos dois builders, alem de `Undefined class
  'CircularMediaRepository'` se o import A.3.a faltar.
- Aplicar A.3 com o parametro, mas nao A.2: nao quebra a compilacao, mas a
  injecao fica inerte - o router recebe `null` e as duas telas continuam no
  caminho de excecao `'Envio de anexos indisponivel nesta composicao.'`. Este e o
  caso silencioso mais perigoso do conjunto.
- Aplicar A.2 (repasse `circularMediaRepository: widget.circularMediaRepository`)
  sem A.3.b: erro de compilacao `No named parameter with the name
  'circularMediaRepository'` na chamada de `createSuperadminRouter`.
- Aplicar A.2 sem A.1: erro de compilacao em `main.dart`
  (`authScope.circularMediaRepository` nao existe) assim que A.4 for aplicado; se
  A.4 tambem faltar, compila mas a producao nunca recebe o repositorio real.
- Aplicar A.1.b/A.1.c sem A.1.d e A.1.e: o campo existe mas o caminho autorizado
  nunca constroi a instancia; producao permanece fail-closed. `_createUnavailableScope`
  compila mesmo sem A.1.e porque o parametro e opcional - por isso A.1.e e um hunk
  de intencao explicita, nao de compilacao.

## A.6 - `principal_circular_detail_page.dart` (hunk descrito, nao aplicado)

Arquivo:
`apps/superadmin/lib/features/principal_circulars/presentation/principal_circular_detail_page.dart`.

Este arquivo nao e reservado, mas por instrucao apenas descrevemos o hunk.

**Observacao importante:** `PrincipalCircularDetailPage` **nao possui nenhum
chamador em `apps/superadmin/lib`** hoje (a rota `circularDetail` do router usa
`SuperadminCircularDetailPage`, de `features/circulars/`, que e outra tela e nao
usa `PrincipalCircularReader`). Portanto este hunk e independente da cadeia acima
e nao altera nenhuma composicao produtiva no momento; ele prepara a tela de
leitura Principal para quando ela for roteada.

### A.6.a Import novo

ANTES:

```dart
import '../domain/circular_repository.dart';
import 'principal_circular_reader.dart';
```

DEPOIS: sem alteracao. `CircularMediaRepository` ja vem de
`../domain/circular_repository.dart`, que o arquivo importa na linha 7. **Nenhum
import novo e necessario.**

### A.6.b Parametro e campo (linhas 11-24)

ANTES:

```dart
  const PrincipalCircularDetailPage({
    required this.circularId,
    required this.repository,
    required this.responseRepository,
    this.childContextId,
    this.onReturn,
    this.embedded = false,
    super.key,
  });

  final String circularId;
  final String? childContextId;
  final CircularRepository repository;
  final CircularResponseRepository responseRepository;
```

DEPOIS:

```dart
  const PrincipalCircularDetailPage({
    required this.circularId,
    required this.repository,
    required this.responseRepository,
    this.childContextId,
    this.mediaRepository,
    this.onReturn,
    this.embedded = false,
    super.key,
  });

  final String circularId;
  final String? childContextId;
  final CircularRepository repository;
  final CircularResponseRepository responseRepository;

  /// Capacidade de midia repassada ao leitor. Ausente, os anexos permanecem
  /// honestamente fechados em vez de simular uma abertura nao autorizada.
  final CircularMediaRepository? mediaRepository;
```

### A.6.c Construcao do `PrincipalCircularReader` (aprox. linha 229-235)

ANTES:

```dart
    return PrincipalCircularReader(
      key: ValueKey(_generation),
      detail: _detail!,
      initialAnswers: _detail!.initialAnswers,
      onSubmit: _submit,
      embedded: widget.embedded,
    );
```

DEPOIS:

```dart
    return PrincipalCircularReader(
      key: ValueKey(_generation),
      detail: _detail!,
      initialAnswers: _detail!.initialAnswers,
      onSubmit: _submit,
      mediaRepository: widget.mediaRepository,
      embedded: widget.embedded,
    );
```

Aplicar somente A.6.c sem A.6.b quebra a compilacao (`widget.mediaRepository` nao
existe). Aplicar A.6.b sem A.6.c compila, mas o repasse fica inerte.

---

# Injecao B - feed produtivo de Momentos

## Por que e necessaria

Hoje o builder de `/principal-moments` resolve **sempre** para
`_unavailableCompositionRootRoute(context)`, ignorando o `runtimeContext`, de modo
que a tela de Momentos nunca sai do caminho de excecao de composicao indisponivel
mesmo com `SupabasePrincipalMomentsFeedRepository` entregue.

`SupabasePrincipalMomentsFeedRepository`
(`apps/superadmin/lib/features/principal_moments/data/supabase_principal_moments_feed_repository.dart:20`)
declara `implements PrincipalMomentsFeedRepository, PrincipalMomentsWithdrawalRepository`,
entao **uma unica instancia cobre os dois seams** de `PrincipalMomentsPreviewPage`.

## Arquivos a tocar, em ordem

1. `apps/superadmin/lib/core/config/superadmin_auth_scope.dart`
2. `apps/superadmin/lib/app/superadmin_app.dart`
3. `apps/superadmin/lib/app/router/superadmin_router.dart`
4. `apps/superadmin/lib/main.dart`

## B.1 - `superadmin_auth_scope.dart`

### B.1.a Imports novos (junto do bloco `principal_moments_publication`, hoje linhas 40-41)

ANTES:

```dart
import '../../features/principal_moments_publication/data/supabase_moments_publication_repository.dart';
import '../../features/principal_moments_publication/domain/moments_publication.dart';
```

DEPOIS:

```dart
import '../../features/principal_moments/data/supabase_principal_moments_feed_repository.dart';
import '../../features/principal_moments/domain/principal_moments_feed_repository.dart';
import '../../features/principal_moments_publication/data/supabase_moments_publication_repository.dart';
import '../../features/principal_moments_publication/domain/moments_publication.dart';
```

### B.1.b Parametro do construtor (aprox. linha 157-158, versao L03)

ANTES:

```dart
    this.principalMixedFeedRepository,
    this.happensPublicationRepository,
```

DEPOIS:

```dart
    this.principalMixedFeedRepository,
    this.principalMomentsFeedRepository,
    this.happensPublicationRepository,
```

### B.1.c Campo (aprox. linha 209-210, versao L03)

ANTES:

```dart
  final PrincipalMixedFeedRepository? principalMixedFeedRepository;
  final HappensPublicationRepository? happensPublicationRepository;
```

DEPOIS:

```dart
  final PrincipalMixedFeedRepository? principalMixedFeedRepository;

  /// Feed produtivo de Momentos. A mesma instancia atende leitura e retirada,
  /// porque `SupabasePrincipalMomentsFeedRepository` implementa os dois
  /// contratos. Ausente, a rota permanece fail-closed.
  final SupabasePrincipalMomentsFeedRepository? principalMomentsFeedRepository;
  final HappensPublicationRepository? happensPublicationRepository;
```

> Nota de tipo: o campo e tipado com a classe concreta justamente para que uma
> unica instancia possa ser oferecida aos dois seams (`feedRepository` e
> `withdrawalRepository`) sem downcast. Se o coordenador preferir tipagem por
> contrato, sao necessarios **dois** campos, e o import de
> `principal_moments_feed_repository.dart` (B.1.a) passa a ser obrigatorio tambem
> para nomear os dois tipos. A alternativa com dois campos e mais verbosa e permite
> divergirem; recomendamos o campo unico concreto.

### B.1.d Caminho autorizado (aprox. linha 372-373, versao L03)

ANTES:

```dart
      principalMixedFeedRepository: SupabasePrincipalMixedFeedRepository(client),
      happensPublicationRepository: SupabaseHappensPublicationRepository(client),
```

DEPOIS:

```dart
      principalMixedFeedRepository: SupabasePrincipalMixedFeedRepository(client),
      principalMomentsFeedRepository: SupabasePrincipalMomentsFeedRepository(client),
      happensPublicationRepository: SupabaseHappensPublicationRepository(client),
```

### B.1.e Caminho sem sessao, em `_createUnavailableScope` (aprox. linha 441-442, versao L03)

ANTES:

```dart
    principalMixedFeedRepository: null,
    happensPublicationRepository: null,
```

DEPOIS:

```dart
    principalMixedFeedRepository: null,
    principalMomentsFeedRepository: null,
    happensPublicationRepository: null,
```

Este e o padrao `null` de `principalHappensFeedRepository`, exatamente como o
briefing indica.

## B.2 - `superadmin_app.dart`

### B.2.a Import novo

```dart
import '../features/principal_moments/data/supabase_principal_moments_feed_repository.dart';
```

(necessario para nomear `SupabasePrincipalMomentsFeedRepository`; hoje o arquivo
nao importa nada de `features/principal_moments/`. Se o coordenador optar pela
tipagem por contrato, importar
`../features/principal_moments/domain/principal_moments_feed_repository.dart`
em vez disso.)

### B.2.b Parametro do construtor (aprox. linha 145-146, versao L03)

ANTES:

```dart
    this.principalMixedFeedRepository,
    this.happensPublicationRepository,
```

DEPOIS:

```dart
    this.principalMixedFeedRepository,
    this.principalMomentsFeedRepository,
    this.happensPublicationRepository,
```

### B.2.c Campo (aprox. linha 200-201, versao L03)

ANTES:

```dart
  final PrincipalMixedFeedRepository? principalMixedFeedRepository;
  final HappensPublicationRepository? happensPublicationRepository;
```

DEPOIS:

```dart
  final PrincipalMixedFeedRepository? principalMixedFeedRepository;
  final SupabasePrincipalMomentsFeedRepository? principalMomentsFeedRepository;
  final HappensPublicationRepository? happensPublicationRepository;
```

### B.2.d Repasse para o router (aprox. linha 281-282, versao L03)

ANTES:

```dart
      principalMixedFeedRepository: widget.principalMixedFeedRepository,
      happensPublicationRepository: widget.happensPublicationRepository,
```

DEPOIS:

```dart
      principalMixedFeedRepository: widget.principalMixedFeedRepository,
      principalMomentsFeedRepository: widget.principalMomentsFeedRepository,
      happensPublicationRepository: widget.happensPublicationRepository,
```

## B.3 - `superadmin_router.dart`

### B.3.a Imports novos (bloco `principal_moments`, linha 52 na versao L03)

ANTES:

```dart
import '../../features/principal_moments/presentation/principal_moments_preview_page.dart';
```

DEPOIS:

```dart
import '../../features/principal_moments/data/supabase_principal_moments_feed_repository.dart';
import '../../features/principal_moments/domain/principal_moments_feed_repository.dart';
import '../../features/principal_moments/presentation/principal_moments_preview_page.dart';
```

O import de `domain/principal_moments_feed_repository.dart` e obrigatorio: o
builder nomeia `PrincipalMomentsFeedScope`, que nao e reexportado pela pagina.

### B.3.b Parametro nomeado de `createSuperadminRouter` (aprox. linha 286-287, versao L03)

ANTES:

```dart
  PrincipalMixedFeedRepository? principalMixedFeedRepository,
  HappensPublicationRepository? happensPublicationRepository,
```

DEPOIS:

```dart
  PrincipalMixedFeedRepository? principalMixedFeedRepository,
  SupabasePrincipalMomentsFeedRepository? principalMomentsFeedRepository,
  HappensPublicationRepository? happensPublicationRepository,
```

### B.3.c Builder de `/principal-moments` (aprox. linhas 866-872 na versao L03)

Este e o hunk sensivel a colisao. Na versao publicada de L03 o bloco fica **entre**
a rota `principalForYou` (que L03 tornou produtiva com `PrincipalForYouRoutePage`)
e a rota `principalProfile` (que L03 tornou produtiva com
`PrincipalProfileRoutePage`). O contexto abaixo e o texto real dessa versao.

ANTES (versao L03, contexto ampliado para localizacao inequivoca):

```dart
      GoRoute(
        path: SuperadminRoutes.principalMoments,
        name: SuperadminRoutes.principalMomentsName,
        builder: (context, state) => PrincipalRuntimeContextRoute(
          repository: principalRuntimeContextRepository,
          builder: (context, _) => _unavailableCompositionRootRoute(context),
        ),
      ),
      GoRoute(
        path: SuperadminRoutes.principalProfile,
        name: SuperadminRoutes.principalProfileName,
```

DEPOIS:

```dart
      GoRoute(
        path: SuperadminRoutes.principalMoments,
        name: SuperadminRoutes.principalMomentsName,
        builder: (context, state) => PrincipalRuntimeContextRoute(
          repository: principalRuntimeContextRepository,
          builder: (context, runtimeContext) {
            final repository = principalMomentsFeedRepository;
            if (repository == null) return _unavailableCompositionRootRoute(context);
            return PrincipalMomentsPreviewPage(
              embedded: false,
              feedRepository: repository,
              feedScope: PrincipalMomentsFeedScope(
                institutionId: runtimeContext.institutionId,
                unitId: runtimeContext.unitId,
                groupId: runtimeContext.groupId,
              ),
              withdrawalRepository: repository,
              onOpenHappens: () => context.goNamed(SuperadminRoutes.principalHappensName),
              onOpenProfile: () => context.goNamed(SuperadminRoutes.principalProfileName),
              onOpenForYou: () => context.goNamed(SuperadminRoutes.principalForYouName),
              onCreateMoment: () => context.goNamed(SuperadminRoutes.principalMomentsPublishName),
              onPublishNow: () => context.goNamed(SuperadminRoutes.principalNowPublicationName),
              onOpenMessages: () => context.goNamed(
                SuperadminRoutes.conversationsName,
                queryParameters: const {'from': 'principal'},
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: SuperadminRoutes.principalProfile,
        name: SuperadminRoutes.principalProfileName,
```

Notas sobre este hunk:

- O padrao de escopo e copiado literalmente da rota `/principal-now`
  (`SuperadminRoutes.principalNow`), que monta
  `PrincipalNowFeedScope(institutionId: runtimeContext.institutionId, unitId:
  runtimeContext.unitId, groupId: runtimeContext.groupId)` e faz
  `if (repository == null) return _unavailableCompositionRootRoute(context);`.
  `PrincipalMomentsFeedScope` tem exatamente a mesma forma:
  `institutionId` obrigatorio, `unitId` e `groupId` nulaveis.
- Fail-closed duplo: alem do `repository == null` acima,
  `PrincipalRuntimeContextRoute` ja trata o caso de contexto ausente antes de
  chamar o builder.
- `PrincipalMomentsPreviewPage` **nao tem** construtor nomeado `.authorized`
  (diferente de `PrincipalNowPreviewPage.authorized`). Usa-se o construtor padrao.
  A pagina assume `feedRepository` e `feedScope` sempre juntos: `_feedConfigurationInvalid`
  e verdadeiro quando so um dos dois e fornecido. O hunk acima fornece os dois ou
  nenhum.
- `onOpenMessages` aponta para `SuperadminRoutes.conversationsName` com
  `queryParameters: const {'from': 'principal'}`, o mesmo padrao que L03 usa nas
  rotas de Para Voce e Perfil. Se o coordenador preferir nao acoplar a L02, esta
  linha pode ser omitida sem qualquer impacto de compilacao (o parametro e
  opcional).

## B.4 - `main.dart` (aprox. linha 58-59, versao L03)

ANTES:

```dart
      principalMixedFeedRepository: authScope.principalMixedFeedRepository,
      happensPublicationRepository: authScope.happensPublicationRepository,
```

DEPOIS:

```dart
      principalMixedFeedRepository: authScope.principalMixedFeedRepository,
      principalMomentsFeedRepository: authScope.principalMomentsFeedRepository,
      happensPublicationRepository: authScope.happensPublicationRepository,
```

Nenhum import novo em `main.dart`.

## B.5 - O que quebra se aplicarem so parte da cadeia

**O codigo nao compila.** Especificamente:

- Aplicar somente B.3.c sem B.3.b: erro de compilacao `Undefined name
  'principalMomentsFeedRepository'`.
- Aplicar B.3.c/B.3.b sem o import B.3.a: erro de compilacao `Undefined class
  'SupabasePrincipalMomentsFeedRepository'` e `Undefined class
  'PrincipalMomentsFeedScope'`.
- Aplicar B.3 sem B.2: compila, mas a rota recebe `null` e continua caindo em
  `_unavailableCompositionRootRoute` - a injecao fica inerte e a tela permanece
  exatamente como hoje.
- Aplicar B.2.d sem B.3.b: erro de compilacao `No named parameter with the name
  'principalMomentsFeedRepository'` na chamada de `createSuperadminRouter`.
- Aplicar B.2 sem B.1: erro de compilacao em `main.dart` assim que B.4 for
  aplicado (`authScope.principalMomentsFeedRepository` nao existe).
- Aplicar B.1.b/B.1.c sem B.1.d: compila, mas producao nunca recebe a instancia
  real e a tela permanece fail-closed.

---

# Ordem e colisoes

- **Ordem de integracao combinada:** L03, depois L01, depois L02.
- **Base de ancoragem:** todos os hunks acima estao ancorados no estado publicado
  em `origin/codex/e2-r02-l03-perfil-para-voce`, que foi lido com sucesso via
  `git show origin/codex/e2-r02-l03-perfil-para-voce:<caminho>` redirecionado para
  `C:/Users/adrie/AppData/Local/Temp/`, fora do repositorio. Nenhum comando git de
  escrita foi executado.
- **Colisao real em `/principal-moments`:** o builder de Momentos fica cercado
  pelos builders de Para Voce (`SuperadminRoutes.principalForYou`) e Perfil
  (`SuperadminRoutes.principalProfile`), que L03 ja tornou produtivos. Na baseline
  `6c5567a6` esses tres builders sao identicos (todos
  `builder: (context, _) => _unavailableCompositionRootRoute(context)`), o que
  torna o hunk **ambiguo** se aplicado sobre a baseline. Por isso o hunk B.3.c
  acima traz contexto ampliado com a rota `principalProfile` de L03 logo abaixo, e
  **deve ser aplicado sobre o estado publicado de L03**, nao sobre `6c5567a6`.
- **Deslocamento de linhas causado por L03:** L03 adicionou `profileAboutRepository`
  a cadeia inteira e as rotas produtivas de Para Voce e Perfil. Em numeros
  aproximados: `superadmin_router.dart` passa de ~5540 para 5619 linhas; as rotas
  de Circulares deslocam de 4391/4431 (baseline) para 4464/4504 (L03); o builder
  de Momentos desloca de 834 (baseline) para 867 (L03). Os hunks acima usam os
  numeros de L03.
- **Colisao textual entre A e B:** nenhuma. As duas injecoes tocam os mesmos quatro
  arquivos, mas em regioes distintas e adjacentes a ancoras diferentes
  (`principalRuntimeContextRepository` para A, `principalMixedFeedRepository` para
  B). Podem ser aplicadas na mesma passada.
- **L02:** acrescentara `/principal-conversations`. Nao colide com nenhum hunk
  deste documento. A unica interacao e a linha opcional `onOpenMessages` no hunk
  B.3.c, que aponta para `SuperadminRoutes.conversationsName` - uma rota que ja
  existe na baseline e ja e usada por L03; nao depende da entrega de L02.
- **Verificacao pos-aplicacao sugerida ao coordenador:** `flutter analyze` no
  `apps/superadmin` e a suite de `apps/superadmin/test/app/router/`, alem de
  `apps/superadmin/test/features/circulars/presentation/production_circular_attachments_test.dart`
  e dos testes de `principal_moments`. Aplicacao parcial da cadeia e detectada pelo
  analisador em todos os casos listados em A.5 e B.5, exceto os casos "inertes"
  destacados, que sao silenciosos e exigem verificacao de comportamento na tela.

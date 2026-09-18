---
title: "L03 — análise dos conflitos com dev"
source: "Simulação de merge de L00; verificação própria de L03 contra origin/dev d7ce6976b"
status: "analise-para-D00"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Conflitos entre `codex/e2-r02-l03-perfil-para-voce` e `dev`

Medido por mim com `git merge-tree --write-tree --name-only origin/dev HEAD`,
leitura pura: **não integrei `dev` na minha branch e não commitei nada em `dev`**.
Base comum `56eb3f19d`; `origin/dev` em `d7ce6976b`; minha HEAD em `0128ab8e0`.

Cinco arquivos conflitam. A recomendação por arquivo está abaixo, com o motivo.

## Achado material que muda a leitura do movimento de D00

`f5e5d8dfc` moveu as rotas Principal para dentro do `ShellRoute` — confirmei que
`principalNow`, `principalForYou`, `principalMoments` e `principalProfile` estão
dentro dele em `dev`. **Mas o movimento foi apenas estrutural.** Em `dev`, tanto
`/principal-profile` (linha 965) quanto `/principal-for-you` (linha 949) ainda
resolvem para `_unavailableCompositionRootRoute`:

```dart
builder: (context, state) => PrincipalRuntimeContextRoute(
  repository: principalRuntimeContextRepository,
  builder: (context, _) => _unavailableCompositionRootRoute(context),
),
```

Ou seja: em `dev` as duas telas continuam **fail-closed**, agora dentro do
contêiner do hospedeiro. `dev` não tem nenhum dos meus parâmetros
(`profileAboutRepository`, `principalCircularRepository`), nenhuma das minhas
composition roots (`PrincipalProfileRoutePage`, `PrincipalForYouRoutePage`,
`PrincipalProfileEditPage`) e não tem a rota `/principal-profile/edit`.
Verifiquei por grep no arquivo de `dev`: zero ocorrências dos cinco nomes.

Consequência prática: as duas metades são **complementares, não concorrentes**.
D00 resolveu a colocação; falta a composição, que é a minha branch.

## Recomendação por arquivo

### 1. `apps/superadmin/lib/app/router/superadmin_router.dart` — RESOLUÇÃO MISTA

Único conflito que exige julgamento. A resolução correta combina os dois lados:

- **Prevalece `dev`** na *colocação*: os `GoRoute` ficam dentro do `ShellRoute`,
  como `f5e5d8dfc` fez. Não reverter isso.
- **Prevalece a minha branch** no *corpo* de cada builder: trocar
  `builder: (context, _) => _unavailableCompositionRootRoute(context)` pelo
  builder real de cada rota, e acrescentar `embedded: true` em
  `PrincipalProfileRoutePage` e `PrincipalForYouRoutePage`.
- **Só existe na minha branch**, precisa ser acrescentado: o `GoRoute` de
  `SuperadminRoutes.principalProfileEdit`; os parâmetros opcionais
  `profileAboutRepository` e `principalCircularRepository`; os imports das três
  páginas, do adapter, dos dados de Para Você e dos dois contratos; e a
  declaração de capacidade da rota de edição em
  `hasAuthoritativeMutationCapability`, sem a qual `/principal-profile/edit`
  volta a ser inalcançável pela guarda global de mutação.

A composição embutida já está pronta do meu lado: `7ca7ee63a` deu `embedded` às
duas composition roots exatamente para este cenário. O `PrincipalProfileEditPage`
é um `Scaffold` com `AppBar` própria; confirmar visualmente se o hospedeiro
duplica esse chrome e, se duplicar, ele recebe o mesmo parâmetro.

### 2–5. Os quatro arquivos de Para Você — PREVALECE A MINHA BRANCH

`dev` recebeu meu `8c041ed50` como `7271f4a39`. **A versão de `dev` divergiu da
minha: ela é a minha versão antiga.** Confirmei diffando `origin/dev` contra a
minha HEAD arquivo a arquivo. Minha versão é estritamente posterior e mais
segura nos quatro casos:

| Arquivo | O que `dev` tem | O que a minha branch tem a mais |
| --- | --- | --- |
| `data/principal_for_you_communications_adapter.dart` | `scope` **opcional**; injeta `assetPath` de sprite fixo em toda comunicação | `scope` **obrigatório** em `highlights` e `isEligible`; sem asset de estoque |
| `domain/principal_for_you_preview_data.dart` | `assetPath`/`assetIndex` obrigatórios; `contextual` sem atalhos | campos opcionais com padrão vazio; `contextual` carrega os seis atalhos aprovados |
| `presentation/principal_for_you_route_page.dart` | sem `audienceScope` obrigatório, sem `embedded`, sem `onAction` | `audienceScope` obrigatório, `embedded`, `onOpenMessages`, `onOpenActivities` e roteamento real das ações do hub |
| `test/.../principal_for_you_communications_adapter_test.dart` | testa o caminho **sem** escopo | assere que não existe chamada que dispense a avaliação de audiência |

O ponto de segurança é o mesmo nos quatro: em `dev`, o gate de audiência é um
parâmetro opcional — um argumento esquecido o desliga silenciosamente. Na minha
branch ele é obrigatório e o teste que protegia o buraco foi invertido.
**Tomar o lado de `dev` nesses quatro reintroduziria o buraco.**

## Estado da proposta de hospedagem

`propostas/L03-hunks-hospedagem-rotas.md` fica **SUPERADA NA COLOCAÇÃO**: D00 já
moveu as três rotas para dentro do `ShellRoute` e a tabela de linhas daquele
documento não vale mais contra `dev`.

O que **continua válido** e não foi coberto por `f5e5d8dfc`: o `embedded: true`
em cada builder, e a observação sobre o `PrincipalProfileEditPage` — que sequer
existe em `dev`. Ou seja, a proposta deixou de ser "mova as rotas" e virou "o que
colocar dentro das rotas que D00 já hospedou".

## Sobre rodar minhas provas de rota contra `dev`

**Não é possível sem a resolução do conflito, e digo por quê em vez de deixar em
aberto.** Meus 11 testes de rota chamam `createSuperadminRouter` com
`profileAboutRepository` e `principalCircularRepository`, parâmetros que não
existem em `dev`: contra `dev` puro eles não compilam. Também asseram que as
rotas montam composição real, o que em `dev` é falso por construção — lá elas
resolvem para a tela de indisponível.

Portanto o resultado útil não é "as provas passam contra `dev`", e sim: **as
provas passam contra a resolução recomendada acima**, porque é exatamente a
composição que elas exercitam, e a mudança de colocação não as afeta — nenhuma
delas assere ausência de shell. Elas devem ser reexecutadas depois do merge; se
alguma quebrar ali, é achado material do merge, não da minha branch.

## Verificação antes de integrar

Depois de resolver, reexecutar no mínimo:
`test/app/router/principal_profile_for_you_production_routes_test.dart` (11
provas das três rotas), `test/features/principal_profile`,
`test/features/principal_for_you` e `test/features/profile_about`. Na minha
branch esse conjunto está em P=214, F=10, com as 10 sendo o golden drift
pré-existente da base.

## Apêndice — builders resolvidos, prontos para colar

Extraídos da minha HEAD `40294a201` e reindentados para a lista `routes:` do
`ShellRoute` de `dev`, com `embedded: true` já acrescentado nas duas composition
roots. Substituem, em `dev`, os três blocos que hoje resolvem para
`_unavailableCompositionRootRoute` — e o terceiro é novo, porque
`/principal-profile/edit` não existe lá.

A indentação assume o mesmo nível dos `GoRoute` vizinhos dentro do `ShellRoute`
(dez espaços). Confirmar com `dart format` depois de colar.

```dart
          GoRoute(
            path: SuperadminRoutes.principalForYou,
            name: SuperadminRoutes.principalForYouName,
            builder: (context, state) => PrincipalRuntimeContextRoute(
              repository: principalRuntimeContextRepository,
              builder: (context, runtimeContext) {
                if (noticeRepository is UnavailableNoticeRepository) {
                  return _unavailableCompositionRootRoute(context);
                }
                return PrincipalForYouRoutePage(
                  embedded: true,
                  repository: noticeRepository,
                  audienceScope: PrincipalForYouAudienceScope.fromRuntimeContext(runtimeContext),
                  supportingData: PrincipalForYouPreviewData.contextual(
                    id: runtimeContext.membershipId,
                    label: runtimeContext.groupName ?? runtimeContext.unitName ?? runtimeContext.institutionName,
                    family: runtimeContext.institutionName,
                    institution: runtimeContext.institutionName,
                    unit: runtimeContext.unitName,
                    group: runtimeContext.groupName,
                  ),
                  onOpenHappens: () => context.goNamed(SuperadminRoutes.principalHappensName),
                  onOpenNow: () => context.pushNamed(SuperadminRoutes.principalNowName),
                  onOpenMoments: () => context.pushNamed(SuperadminRoutes.principalMomentsName),
                  onOpenAgenda: () => context.goNamed(SuperadminRoutes.agendaName),
                  onOpenProfile: () => context.goNamed(SuperadminRoutes.principalProfileName),
                  onOpenActivities: () => context.goNamed(SuperadminRoutes.activitiesName),
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
            builder: (context, state) => PrincipalRuntimeContextRoute(
              repository: principalRuntimeContextRepository,
              builder: (context, runtimeContext) => PrincipalProfileRoutePage(
                embedded: true,
                runtimeContext: runtimeContext,
                // The Principal projection, never the administrative directory:
                // the actor is authorized on the server by institution, unit and
                // group, not by the Superadmin circulars permission.
                circularRepository: principalCircularRepository,
                aboutRepository: profileAboutRepository,
                happensFeedRepository: principalHappensFeedRepository,
                onOpenCircular: (circularId) => context.goNamed(
                  SuperadminRoutes.circularDetailName,
                  pathParameters: {'circularId': circularId},
                ),
                onOpenEdit: () => context.goNamed(SuperadminRoutes.principalProfileEditName),
                onOpenAgenda: () => context.goNamed(SuperadminRoutes.agendaName),
                onOpenHome: () => context.goNamed(SuperadminRoutes.principalHappensName),
                onOpenForYou: () => context.goNamed(SuperadminRoutes.principalForYouName),
                onOpenMoments: () => context.pushNamed(SuperadminRoutes.principalMomentsName),
                onPublishNow: () => context.goNamed(SuperadminRoutes.principalNowPublicationName),
                onMessage: () => context.goNamed(
                  SuperadminRoutes.conversationsName,
                  queryParameters: const {'from': 'principal'},
                ),
                onOpenMessages: () => context.goNamed(
                  SuperadminRoutes.conversationsName,
                  queryParameters: const {'from': 'principal'},
                ),
              ),
            ),
          ),

          GoRoute(
            path: SuperadminRoutes.principalProfileEdit,
            name: SuperadminRoutes.principalProfileEditName,
            builder: (context, state) => PrincipalRuntimeContextRoute(
              repository: principalRuntimeContextRepository,
              builder: (context, runtimeContext) {
                final repository = profileAboutRepository;
                if (repository == null) return _unavailableCompositionRootRoute(context);
                return PrincipalProfileEditPage(
                  runtimeContext: runtimeContext,
                  repository: repository,
                  onClose: () => context.goNamed(SuperadminRoutes.principalProfileName),
                );
              },
            ),
          ),
```

### O que precisa acompanhar os builders

1. Assinatura de `createSuperadminRouter`, dois parâmetros opcionais:

```dart
  ProfileAboutRepository? profileAboutRepository,
  CircularRepository? principalCircularRepository,
```

2. Imports novos no router:

```dart
import '../../features/principal_circulars/domain/circular_repository.dart';
import '../../features/principal_for_you/data/principal_for_you_communications_adapter.dart';
import '../../features/principal_for_you/domain/principal_for_you_preview_data.dart';
import '../../features/principal_profile/presentation/principal_profile_edit_page.dart';
import '../../features/principal_profile/presentation/principal_profile_route_page.dart';
import '../../features/profile_about/domain/profile_about_repository.dart';
```

3. Constantes em `superadmin_routes.dart`:

```dart
  static const principalProfileEdit = '/principal-profile/edit';
  static const principalProfileEditName = 'principal-profile-edit';
```

4. Capacidade da rota de edição, dentro de `hasAuthoritativeMutationCapability`,
   antes do `return false` final. **Sem isto a rota volta a ser inalcançável**:
   ela termina em `/edit`, então a guarda global de mutação a redireciona para
   `/errors/mutation-capability-unavailable`.

```dart
    // Editing the contextual Perfil is the About command, which
    // save_profile_about authorizes and versions server-side. The route stays
    // closed until a real About repository is composed.
    if (location.startsWith(SuperadminRoutes.principalProfile)) {
      return profileAboutRepository != null;
    }
```

5. Cadeia de injeção, um campo e uma passagem em cada:
   `superadmin_auth_scope.dart` instancia `SupabaseProfileAboutRepository(client)`
   e `SupabaseCircularRepository(client)`; `superadmin_app.dart` e `main.dart`
   apenas repassam. Os dois ficam `null` no escopo indisponível, que é o
   comportamento fail-closed correto.

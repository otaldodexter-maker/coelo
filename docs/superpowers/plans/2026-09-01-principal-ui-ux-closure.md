# Principal UI/UX Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir o chrome duplicado, tornar Momentos imersivo, mover Circulares e elevar o acabamento responsivo das superficies Principal dentro do teto aprovado de quatro horas.

**Architecture:** Manter as superficies existentes dentro de `apps/superadmin` e promover as rotas Coelo (Principal) a rotas proprias fora do `ShellRoute`, eliminando o segundo `SuperadminShell` criado por `operationalPage` sem modificar o shell global de Estruturas. Tratar Agora e Momentos como viewers imersivos; feeds, compositores e Chat usam chrome proprio do Principal. Chat consome o contrato/repository mantido por Comunicacao e nao duplica backend.

**Tech Stack:** Flutter, Dart, GoRouter, `coelo_tokens`, `coelo_ui_core`, Supabase existente e testes `flutter_test`.

## Global Constraints

- Teto total: quatro horas.
- Nunito Sans, laranja semantico `#D63C00`, grafite `#3F4549` e tokens Coelo.
- Larguras-alvo: 375, 768 e 1440 px.
- `/dev` usa fixtures; rotas reais permanecem fail-closed e nunca fazem fallback para fixtures.
- Nenhuma importacao de `coelo_ui_admin` nas composicoes Principal.
- Nenhuma alteracao em `apps/admin`, `apps/site` ou `apps/principal`.
- Nenhuma alteracao em `SuperadminShell`; o cabecalho global pertence a Estruturas.
- Chat Principal consome `ChatRepository`; nao cria outro repository, RPC ou migration.
- Testes novos somente para regressao concreta; nenhuma matriz ampla nova de goldens.
- Os tres rastreadores oficiais sao atualizados somente pelo Coordenador; esta frente envia propostas estruturadas por checkpoint.

---

### Task 1: Shell unico do Principal

**Files:**
- Modify: `apps/superadmin/test/app/router/principal_happens_preview_route_test.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`

**Interfaces:**
- Consumes: `ShellRoute`, `operationalPage` e destinos `principal-*`.
- Produces: rotas top-level Coelo (Principal) com chrome proprio e sem `SuperadminShell` aninhado.

- [ ] **Step 1: Escrever o teste RED**

Adicionar ao teste de rota Acontece verificacoes de que o conteudo continua no
shell persistente, a sidebar existe em 1440 px, e estes elementos administrativos
nao aparecem:

```dart
expect(find.byKey(const Key('superadmin-persistent-shell')), findsNothing);
expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
expect(find.byKey(const Key('principal-global-messages')), findsOneWidget);
expect(find.byKey(const Key('superadmin-mobile-menu')), findsNothing);
```

- [ ] **Step 2: Executar o RED**

Run: `rtk flutter test test/app/router/principal_happens_preview_route_test.dart`

Expected: FAIL porque Acontece ainda esta dentro do shell persistente e do wrapper `operationalPage`.

- [ ] **Step 3: Promover as rotas sem tocar o shell**

Mover Acontece, Para Voce, Perfil e os tres publicadores para o nivel top-level
do router, ao lado de Agora. Remover os builders homonimos de dentro da
`ShellRoute` e construir as paginas diretamente com chrome proprio
(`embedded: false` quando a API oferecer a opcao). Preservar callbacks e usar o
menu Coelo (Principal) como ponto de entrada. Nao alterar `SuperadminShell`.

O conjunto top-level fica explicitamente restrito a estas rotas:

```dart
bool _isPrincipalPreviewLocation(String location) =>
    location.startsWith('/dev/principal-');
```

- [ ] **Step 4: Executar GREEN**

Run: `rtk flutter test test/app/router/principal_happens_preview_route_test.dart test/app/router/principal_for_you_preview_route_test.dart test/app/router/principal_profile_preview_route_test.dart`

Expected: PASS sem excecoes de layout.

### Task 2: Momentos fullscreen como Agora

**Files:**
- Modify: `apps/superadmin/test/app/router/principal_now_preview_route_test.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Modify: `apps/superadmin/lib/features/principal_moments/presentation/principal_moments_preview_page.dart`

**Interfaces:**
- Consumes: rota top-level de Agora e `_closePrincipalViewer(BuildContext)`.
- Produces: rota top-level `devPrincipalMoments` com retorno e foco restaurados.

- [ ] **Step 1: Alterar o teste para RED**

Na abertura de Momentos, exigir:

```dart
expect(find.byType(PrincipalMomentsPreviewPage), findsOneWidget);
expect(find.byKey(const Key('superadmin-persistent-shell')).hitTestable(), findsNothing);
expect(find.byKey(const Key('superadmin-sidebar')).hitTestable(), findsNothing);
expect(find.byKey(const Key('principal-global-dock')), findsNothing);
expect(tester.getRect(find.byKey(const Key('principal-moments-page-view'))), Offset.zero & const Size(768, 1024));
```

Manter o teste existente de Escape e restauracao de foco.

- [ ] **Step 2: Executar o RED**

Run: `rtk flutter test test/app/router/principal_now_preview_route_test.dart`

Expected: FAIL porque Momentos ainda esta dentro da `ShellRoute`.

- [ ] **Step 3: Mover somente a rota viewer**

Mover `GoRoute(devPrincipalMoments)` para o mesmo nivel top-level de
`devPrincipalNow`, construir `PrincipalMomentsPreviewPage(embedded: false, ...)`
e remover a declaracao aninhada. No viewer, remover o `Center > AspectRatio` e a
aside desktop para que o `PageView` preencha a viewport com `BoxFit.cover`; os
controles somam `MediaQuery.viewPaddingOf(context)` sem reduzir a midia. O
publicador de Momentos continua no shell.

- [ ] **Step 4: Executar GREEN**

Run: `rtk flutter test test/app/router/principal_now_preview_route_test.dart test/features/principal_moments/presentation/principal_moments_preview_page_test.dart`

Expected: PASS, inclusive retorno por Escape e foco.

### Task 3: Circulares em Coelo (Principal)

**Files:**
- Modify: `apps/superadmin/test/app/navigation/superadmin_navigation_test.dart`
- Modify: `apps/superadmin/lib/app/navigation/superadmin_navigation.dart`
- Inspect before edits: handoff commit de Circulares da branch `codex/finalizar-tela-comunicacao`

**Interfaces:**
- Consumes: IDs `circulars` e `circular-create` existentes.
- Produces: breadcrumb `principal > circulars > circular-create`.

- [ ] **Step 1: Escrever RED de hierarquia**

```dart
expect(coeloNavigationAncestors('circulars'), {'principal'});
expect(coeloNavigationAncestors('circular-create'), {'principal', 'circulars'});
expect(coeloNavigationAncestors('communication'), isNot(contains('circulars')));
```

- [ ] **Step 2: Executar RED**

Run: `rtk flutter test test/app/navigation/superadmin_navigation_test.dart`

Expected: FAIL porque Circulares ainda pertence a Comunicacao.

- [ ] **Step 3: Mover os mesmos nodes**

Preservar as referencias visuais do commit `f6d44af9` e integrar as acoes de
arquivo canônicas do commit `d22a9b3d`. Nao integrar `393fc7ff`, marcado WIP e
sem wiring/teste confiavel. Remover
`_screen('circulars', ...)` de `communication` e inseri-lo no final da arvore
`principal`, preservando IDs, icones, rotas e capabilities. Reaproveitar telas
Principal existentes em `features/principal_circulars`; nao copiar alteracoes
soltas da outra worktree.

- [ ] **Step 4: Executar GREEN**

Run: `rtk flutter test test/app/navigation/superadmin_navigation_test.dart`

Expected: PASS sem alterar destinos.

### Task 4: Card Publicar agora e polimento focal

**Files:**
- Modify: `apps/superadmin/test/features/principal_happens/presentation/principal_happens_preview_page_test.dart`
- Modify: `apps/superadmin/lib/features/principal_happens/presentation/principal_happens_preview_page.dart`
- Modify: `apps/superadmin/test/features/principal_profile/presentation/principal_profile_preview_page_test.dart`
- Modify: `apps/superadmin/lib/features/principal_profile/domain/principal_profile_preview_data.dart`
- Modify: `apps/superadmin/lib/features/principal_profile/presentation/principal_profile_preview_page.dart`
- Inspect/adjust only if smoke exposes delta: `apps/superadmin/lib/features/principal_for_you/presentation/principal_for_you_preview_page.dart`
- Inspect/adjust only if smoke exposes delta: `apps/superadmin/lib/features/principal_profile/presentation/principal_profile_preview_page.dart`
- Inspect/adjust only if smoke exposes delta: `apps/superadmin/lib/features/principal_happens_publication/presentation/principal_happens_publication_page.dart`
- Inspect/adjust only if smoke exposes delta: `apps/superadmin/lib/features/principal_now_publication/presentation/principal_now_publication_page.dart`
- Inspect/adjust only if smoke exposes delta: `apps/superadmin/lib/features/principal_moments_publication/presentation/principal_moments_publication_page.dart`

**Interfaces:**
- Consumes: `_PublishNowCard`, Coelo tokens e callbacks existentes.
- Produces: card tracejado acessivel com estados `hovered`, `focused` e `pressed`, e Perfil sem seguidores publicos.

- [ ] **Step 1: Escrever RED do card**

Adicionar keys e verificar no teste:

```dart
expect(find.byKey(const Key('principal-happens-publish-now-dashed-border')), findsOneWidget);
expect(find.byKey(const Key('principal-happens-publish-now-action')), findsOneWidget);
```

Enviar hover ao card e exigir que a acao central use `colorScheme.primary`,
mantendo o callback existente.

- [ ] **Step 2: Executar RED**

Run: `rtk flutter test test/features/principal_happens/presentation/principal_happens_preview_page_test.dart`

Expected: FAIL porque o card atual usa borda solida sem os estados aprovados.

- [ ] **Step 3: Implementar o card**

Substituir o `OutlinedButton` por `FocusableActionDetector` + `InkWell`, manter
alvo minimo e semantica de botao e desenhar o contorno com um `CustomPainter`
local que alterna segmentos de quatro pixels e gap de quatro pixels. Resolver
estado visual assim:

```dart
final active = hovered || focused || pressed;
final borderColor = active ? colors.primary : colors.outlineVariant;
final actionColor = active ? colors.primary : colors.surface;
final actionForeground = active ? colors.onPrimary : colors.primary;
```

- [ ] **Step 4: Smoke e refinamento restrito**

Antes do smoke, adicionar RED no Perfil exigindo ausencia de `Seguidores`,
`Seguindo` e `principal-profile-follow`, preservando Mensagem e as abas. Remover
o estado local de acompanhar e trocar as metricas demonstrativas por
`Publicacoes`, `Momentos` e `Circulares`, sem inventar contrato remoto.

Abrir Acontece, Para Voce, Perfil e os tres publicadores em 375, 768 e 1440 px.
Corrigir apenas overflow, espacos, duplicacoes e hierarquia claramente divergentes
da spec 050. Cada bug adicional recebe teste RED no arquivo de teste da propria
feature antes do codigo.

- [ ] **Step 5: Executar GREEN focal**

Run: `rtk flutter test test/features/principal_happens/presentation/principal_happens_preview_page_test.dart test/features/principal_for_you/presentation/principal_for_you_preview_page_test.dart test/features/principal_profile/presentation/principal_profile_preview_page_test.dart test/features/principal_happens_publication/presentation/principal_happens_publication_page_test.dart test/features/principal_now_publication/presentation/principal_now_publication_page_test.dart test/features/principal_moments_publication/presentation/principal_moments_publication_page_test.dart`

Expected: PASS sem excecoes de layout.

### Task 5: Chat contextual funcional do Principal

**Files:**
- Consume after handoff: `apps/superadmin/lib/features/chat/domain/chat_repository.dart`
- Consume after handoff: `apps/superadmin/lib/features/chat/data/development_chat_repository.dart`
- Create: `apps/superadmin/lib/features/principal_chat/application/principal_chat_controller.dart`
- Create: `apps/superadmin/lib/features/principal_chat/presentation/principal_chat_page.dart`
- Create: `apps/superadmin/test/features/principal_chat/application/principal_chat_controller_test.dart`
- Create: `apps/superadmin/test/features/principal_chat/presentation/principal_chat_page_test.dart`
- Create: `apps/superadmin/test/app/router/principal_chat_route_test.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_routes.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`

**Interfaces:**
- Consumes: `ChatRepository.fetchInbox/fetchThread/sendMessage/markRead`, excecoes tipadas e fixture deterministica de Comunicacao.
- Produces: rota `/dev/principal-messages`, controller e UI Principal sem widgets `SuperadminChat*` ou `coelo_ui_admin`.

- [ ] **Step 1: Escrever RED do controller**

Cobrir loading para ready/empty/noResults/offline/failure/unauthorized; abrir
thread e marcar leitura somente apos autorizacao; enviar com chave idempotente
estavel durante retry; reload refaz inbox/thread; unauthorized limpa thread e
composer.

Run: `rtk flutter test test/features/principal_chat/application/principal_chat_controller_test.dart`

Expected: FAIL porque controller ainda nao existe.

- [ ] **Step 2: Implementar controller minimo**

Criar `ChangeNotifier` com repository injetado, estados imutaveis e contador de
request para descartar resposta obsoleta. Mapear `ChatUnauthorizedException`,
`ChatOfflineException` e falha generica sem expor dados anteriores.

- [ ] **Step 3: Escrever RED da pagina e rota**

Exigir em 375/768/1440 px: inbox, thread, composer, loading, vazio, busca sem
resultado, offline/retry, falha, sem permissao sem conteudo e read-only. Provar
que launchers de Acontece/Para Voce/Perfil e a acao Mensagem do Perfil abrem a
mesma rota; o atalho essencial Mensagens de Para Voce tambem abre essa inbox e
os demais atalhos preservam o comportamento atual. Retorno restaura foco, envio
aparece apos resposta normalizada e reload chama repository novamente. Momentos
nao exibe launcher.

- [ ] **Step 4: Implementar UI e wiring**

Usar somente Flutter, `coelo_tokens` e `coelo_ui_core`. Compacto navega
inbox→thread; 768+ usa mestre-detalhe. O botao Perfil/Mensagem abre a inbox e
nao inventa conversationId a partir do perfil. A rota top-level usa a fixture
commitada por Comunicacao; fora de `/dev`, ausencia de repository permanece
fail-closed.

- [ ] **Step 5: Executar GREEN**

Run: `rtk flutter test test/features/principal_chat/application/principal_chat_controller_test.dart test/features/principal_chat/presentation/principal_chat_page_test.dart test/app/router/principal_chat_route_test.dart`

Expected: PASS para UI/local; remoto/E2E continua bloqueado ate os RPCs e o hardening de membership existirem e serem provados.

### Task 6: Evidencia, propostas de rastreadores e checkpoint

**Files:**
- Do not modify: `docs/reviews/coelo-flutter-pendencias.md`
- Do not modify: `docs/reviews/coelo-supabase-pendencias.md`
- Do not modify: `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`

**Interfaces:**
- Consumes: resultados reais dos Tasks 1–4 e inventario remoto ja coletado.
- Produces: checkpoint estruturado para o Coordenador reconciliar Flutter, Supabase local/remoto e E2E.

- [ ] **Step 1: Preparar propostas para os tres rastreadores**

Enviar ao Coordenador action_id/gate, estado anterior/proposto, arquivos,
rotas/repository/RPC/policy/migration, comandos/resultados, distincao `/dev` /
Flutter local / backend local / remoto / E2E, bloqueios, ETA e estado Git. Nao
editar diretamente os tres Markdown e nao promover mock, `/dev` ou
`local-green` a concluido.

- [ ] **Step 2: Verificacao final proporcional**

Run: `rtk dart analyze lib/app/router lib/app/navigation lib/features/principal_shared lib/features/principal_happens lib/features/principal_for_you lib/features/principal_moments lib/features/principal_now lib/features/principal_profile lib/features/principal_chat lib/features/principal_circulars lib/features/principal_happens_publication lib/features/principal_now_publication lib/features/principal_moments_publication`

Run: testes focais listados nos Tasks 1–4.

Run: `rtk git diff --check`

Expected: zero erros, zero testes falhos e diff sem whitespace invalido.

- [ ] **Step 3: Commit e checkpoint coordenado**

Criar commits recuperaveis por bloco coerente e enviar branch, worktree, HEAD,
arquivos, testes, action_ids, bloqueios e ETA para a thread coordenadora.

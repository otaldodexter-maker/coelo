# Principal UI/UX Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir o chrome duplicado, tornar Momentos imersivo, mover Circulares e elevar o acabamento responsivo das superficies Principal dentro do teto aprovado de quatro horas.

**Architecture:** Manter os previews existentes, remover o segundo `SuperadminShell` criado por `operationalPage` e introduzir apenas flags explicitas no host persistente para suprimir chrome administrativo nas rotas Principal. Tratar Agora e Momentos como rotas top-level imersivas; manter feeds e compositores dentro do shell de descoberta `/dev`, mas com o chrome proprio do Principal. Aplicar refinamentos locais sem criar um novo pacote vazio.

**Tech Stack:** Flutter, Dart, GoRouter, `coelo_tokens`, `coelo_ui_core`, Supabase existente e testes `flutter_test`.

## Global Constraints

- Teto total: quatro horas.
- Nunito Sans, laranja semantico `#D63C00`, grafite `#3F4549` e tokens Coelo.
- Larguras-alvo: 375, 768 e 1440 px.
- `/dev` usa fixtures; rotas reais permanecem fail-closed e nunca fazem fallback para fixtures.
- Nenhuma importacao de `coelo_ui_admin` nas composicoes Principal.
- Testes novos somente para regressao concreta; nenhuma matriz ampla nova de goldens.
- Atualizar os tres rastreadores no mesmo turno das correcoes e bloqueios.

---

### Task 1: Shell unico do Principal

**Files:**
- Modify: `apps/superadmin/test/app/router/principal_happens_preview_route_test.dart`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`

**Interfaces:**
- Consumes: `SuperadminShell.host`, `operationalPage` e destinos `principal-*`.
- Produces: `showCompactHeader` e `_isPrincipalShellLocation(String)`.

- [ ] **Step 1: Escrever o teste RED**

Adicionar ao teste de rota Acontece verificacoes de que o conteudo continua no
shell persistente, a sidebar existe em 1440 px, e estes elementos administrativos
nao aparecem:

```dart
expect(find.text('Prévia da experiência do app Principal.'), findsNothing);
expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
expect(find.byKey(const Key('principal-global-messages')), findsOneWidget);
if (width < CoeloBreakpoints.expanded.minWidth) {
  expect(find.byKey(const Key('superadmin-mobile-menu')), findsNothing);
}
```

- [ ] **Step 2: Executar o RED**

Run: `rtk flutter test test/app/router/principal_happens_preview_route_test.dart`

Expected: FAIL porque o shell ainda renderiza divisor/cabecalho, launcher e app bar compacta.

- [ ] **Step 3: Implementar flags minimas**

Permitir que o construtor `SuperadminShell.host` receba:

```dart
this.showCompactHeader = true,

final bool showCompactHeader;
```

No host compacto, usar `appBar: widget.showCompactHeader ? _CompactAppBar(...) : null`
e disponibilizar drawer somente quando o cabecalho estiver visivel. Em
desktop, preservar a sidebar.

No router, identificar as rotas de shell Principal:

```dart
bool _isPrincipalShellLocation(String location) =>
    location.startsWith('/dev/principal-happens') ||
    location.startsWith('/dev/principal-for-you') ||
    location.startsWith('/dev/principal-moments/publish') ||
    location.startsWith('/dev/principal-now/publication') ||
    location.startsWith('/dev/principal-profile');
```

Passar `showCompactHeader: !principalSurface` e
`showChatLauncher: !principalSurface` ao host. Nos builders Principal, remover
o wrapper `operationalPage` e retornar diretamente Acontece, Para Voce, Perfil
e os tres publicadores com seu chrome proprio (`embedded: false` quando a API
oferecer essa opcao). Nao alterar builders administrativos.

- [ ] **Step 4: Executar GREEN**

Run: `rtk flutter test test/app/router/principal_happens_preview_route_test.dart test/app/shell/superadmin_shell_test.dart`

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

Inspecionar primeiro o handoff commitado da frente Comunicacao. Remover
`_screen('circulars', ...)` de `communication` e inseri-lo no final da arvore
`principal`, preservando IDs, icones, rotas e capabilities. Reaproveitar telas
de diretorio/detalhe/composer recebidas quando seus contratos e testes forem
mais completos; nao copiar alteracoes soltas da outra worktree.

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

### Task 5: Evidencia, rastreadores e checkpoint

**Files:**
- Modify: `docs/reviews/coelo-flutter-pendencias.md`
- Modify: `docs/reviews/coelo-supabase-pendencias.md`
- Modify: `docs/reviews/coelo-flutter-integrado-supabase-pendencias.md`

**Interfaces:**
- Consumes: resultados reais dos Tasks 1–4 e inventario remoto ja coletado.
- Produces: progresso separado entre Flutter, Supabase local/remoto e E2E.

- [ ] **Step 1: Atualizar os tres rastreadores**

Registrar arquivos, comandos, resultados, bloqueios remotos de Agora/Momentos e
action_ids afetados. Nao promover mock, `/dev` ou `local-green` a concluido.

- [ ] **Step 2: Verificacao final proporcional**

Run: `rtk dart analyze lib/app/shell lib/app/router lib/app/navigation lib/features/principal_shared lib/features/principal_happens lib/features/principal_for_you lib/features/principal_moments lib/features/principal_now lib/features/principal_profile lib/features/principal_happens_publication lib/features/principal_now_publication lib/features/principal_moments_publication`

Run: testes focais listados nos Tasks 1–4.

Run: `rtk git diff --check`

Expected: zero erros, zero testes falhos e diff sem whitespace invalido.

- [ ] **Step 3: Commit e checkpoint coordenado**

Criar commits recuperaveis por bloco coerente e enviar branch, worktree, HEAD,
arquivos, testes, action_ids, bloqueios e ETA para a thread coordenadora.

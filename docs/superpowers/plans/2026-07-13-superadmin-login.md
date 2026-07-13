---
title: "Superadmin Login Implementation Plan"
source: "docs/superpowers/specs/2026-07-13-superadmin-login-design.md"
status: "approved-for-implementation"
generated_at: "2026-07-13"
---

# Superadmin Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o login responsivo e acessivel do Superadmin, com estados testaveis e shell protegida por `go_router`, sem backend ou segredos no cliente.

**Architecture:** Uma feature local de auth expoe contratos imutaveis, view model e widgets de apresentacao. Um estado minimo de sessao alimenta redirects centralizados no `GoRouter`; `SuperadminApp` possui e descarta router/sessao quando nao forem injetados.

**Tech Stack:** Flutter 3.32+, Dart 3.8+, Material 3, `go_router` 16, `coelo_tokens`, `flutter_test`.

## Global Constraints

- Nao adicionar backend, Supabase Auth, persistencia de sessao ou secrets.
- Nao declarar HEX ou `TextStyle` solto na feature; usar tema e tokens Coelo.
- Manter `ThemeMode.system`, light/dark e alvos interativos de 48 dp.
- Decidir layout por constraints, nunca por tipo de dispositivo.
- Preservar a alteracao preexistente em `packages/coelo_tokens/lib/src/coelo_theme.dart`.
- Escrever e executar o teste falhando antes do codigo de cada comportamento.

## File Map

- Create `apps/superadmin/lib/features/auth/domain/login_request.dart`: request, result e callback de login.
- Create `apps/superadmin/lib/features/auth/presentation/view_models/login_view_model.dart`: estado de apresentacao.
- Create `apps/superadmin/lib/core/guards/superadmin_session.dart`: sessao local minima.
- Create `apps/superadmin/lib/app/router/superadmin_router.dart`: arvore e redirects.
- Modify `apps/superadmin/lib/app/router/superadmin_routes.dart`: names e paths.
- Modify `apps/superadmin/lib/app/superadmin_app.dart`: ciclo de vida e `MaterialApp.router`.
- Create `apps/superadmin/lib/features/auth/presentation/screens/superadmin_login_screen.dart`: tela e controllers.
- Create `apps/superadmin/lib/features/auth/presentation/widgets/login_header.dart`: marca e hierarquia textual.
- Create `apps/superadmin/lib/features/auth/presentation/widgets/login_feedback.dart`: erro geral acessivel.
- Create `apps/superadmin/lib/features/auth/presentation/widgets/login_security_notice.dart`: aviso privado/auditavel.
- Create `apps/superadmin/lib/features/auth/presentation/widgets/login_submit_button.dart`: acao/loading.
- Create `apps/superadmin/lib/features/auth/presentation/widgets/superadmin_login_form.dart`: campos e preferencia.
- Modify `apps/superadmin/lib/main.dart`: path URL strategy.
- Modify `apps/superadmin/pubspec.yaml`: asset oficial do logo.
- Create `apps/superadmin/assets/brand/logo-coelo-orange.png`: copia do asset oficial versionado.
- Create tests under `apps/superadmin/test/features/auth/` and update `apps/superadmin/test/app/superadmin_app_test.dart`.

---

### Task 1: Contratos e estado de apresentacao

**Files:**
- Create: `apps/superadmin/lib/features/auth/domain/login_request.dart`
- Create: `apps/superadmin/lib/features/auth/presentation/view_models/login_view_model.dart`
- Test: `apps/superadmin/test/features/auth/presentation/view_models/login_view_model_test.dart`

**Interfaces:**
- Produces: `LoginRequest`, `LoginResult`, `LoginAction`, `unavailableSuperadminLogin`, `LoginViewModel.submit(LoginRequest) -> Future<bool>`.

- [ ] **Step 1: Write failing unit tests**

Testar estado inicial, alternancias, request encaminhado, loading observado durante um `Completer`, sucesso, falha e excecao convertida para a mensagem segura `Nao foi possivel entrar. Verifique os dados e tente novamente.`.

```dart
final completer = Completer<LoginResult>();
final viewModel = LoginViewModel(login: (request) => completer.future);
final future = viewModel.submit(
  const LoginRequest(email: 'owner@coelo.me', password: 'secret', keepSessionOpen: true),
);
expect(viewModel.isLoading, isTrue);
completer.complete(const LoginResult.success());
expect(await future, isTrue);
expect(viewModel.isLoading, isFalse);
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/features/auth/presentation/view_models/login_view_model_test.dart`
Expected: FAIL because the domain and view model files do not exist.

- [ ] **Step 3: Implement minimal contracts and view model**

```dart
typedef LoginAction = Future<LoginResult> Function(LoginRequest request);

final class LoginRequest {
  const LoginRequest({required this.email, required this.password, required this.keepSessionOpen});
  final String email;
  final String password;
  final bool keepSessionOpen;
}

final class LoginResult {
  const LoginResult._({required this.isSuccess, this.message});
  const LoginResult.success() : this._(isSuccess: true);
  const LoginResult.failure(String message) : this._(isSuccess: false, message: message);
  final bool isSuccess;
  final String? message;
}
```

O view model estende `ChangeNotifier`, notifica cada transicao, impede submit concorrente e nunca inclui a senha em erro/log.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/features/auth/presentation/view_models/login_view_model_test.dart`
Expected: all view model tests PASS.

### Task 2: Sessao local e roteamento declarativo

**Files:**
- Create: `apps/superadmin/lib/core/guards/superadmin_session.dart`
- Create: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_routes.dart`
- Modify: `apps/superadmin/lib/app/superadmin_app.dart`
- Test: `apps/superadmin/test/app/router/superadmin_router_test.dart`
- Modify: `apps/superadmin/test/app/superadmin_app_test.dart`

**Interfaces:**
- Consumes: `LoginAction` from Task 1.
- Produces: `SuperadminSession.signIn()`, `signOut()`, `createSuperadminRouter(...)`, `SuperadminRoutes.login`, `SuperadminRoutes.home`.

- [ ] **Step 1: Write failing router/app tests**

```dart
final session = SuperadminSession();
final router = createSuperadminRouter(session: session, login: (_) async => const LoginResult.success());
await tester.pumpWidget(MaterialApp.router(routerConfig: router));
expect(find.text('Acesse sua conta'), findsOneWidget);
router.go(SuperadminRoutes.home);
await tester.pumpAndSettle();
expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);
```

Adicionar caso autenticado que redireciona `/login` para `/` e teste que `SuperadminApp` usa `MaterialApp.router` com os temas Coelo.

- [ ] **Step 2: Verify RED**

Run: `flutter test test/app/router/superadmin_router_test.dart test/app/superadmin_app_test.dart`
Expected: FAIL because session/router/login screen APIs do not exist and the app still uses legacy routes.

- [ ] **Step 3: Implement session, router and app lifecycle**

```dart
String? redirect(BuildContext context, GoRouterState state) {
  final isOnLogin = state.matchedLocation == SuperadminRoutes.login;
  if (!session.isAuthenticated) return isOnLogin ? null : SuperadminRoutes.login;
  return isOnLogin ? SuperadminRoutes.home : null;
}
```

`SuperadminApp` se torna `StatefulWidget`, cria dependencias nao injetadas em `initState`, usa `MaterialApp.router(routerConfig: _router)` e descarta somente objetos dos quais e owner.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/app/router/superadmin_router_test.dart test/app/superadmin_app_test.dart`
Expected: routing/app tests PASS.

### Task 3: Formulario, feedback e layout responsivo

**Files:**
- Create: `apps/superadmin/lib/features/auth/presentation/screens/superadmin_login_screen.dart`
- Create: `apps/superadmin/lib/features/auth/presentation/widgets/login_header.dart`
- Create: `apps/superadmin/lib/features/auth/presentation/widgets/login_feedback.dart`
- Create: `apps/superadmin/lib/features/auth/presentation/widgets/login_security_notice.dart`
- Create: `apps/superadmin/lib/features/auth/presentation/widgets/login_submit_button.dart`
- Create: `apps/superadmin/lib/features/auth/presentation/widgets/superadmin_login_form.dart`
- Test: `apps/superadmin/test/features/auth/presentation/screens/superadmin_login_screen_test.dart`

**Interfaces:**
- Consumes: `LoginAction`, `LoginRequest`, `LoginViewModel`, `SuperadminSession`.
- Produces: `SuperadminLoginScreen(session:, login:)`.

- [ ] **Step 1: Write failing widget tests**

Cobrir renderizacao inicial, mensagens `Informe seu e-mail.`, `Informe um e-mail valido.` e `Informe sua senha.`, senha oculta/visivel, checkbox, loading com `Entrando...`, falha segura, recuperacao indisponivel e sucesso chamando `session.signIn()`.

```dart
await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
await tester.pump();
expect(find.text('Informe seu e-mail.'), findsOneWidget);
expect(find.text('Informe sua senha.'), findsOneWidget);
```

Adicionar viewport `320x568` com `textScaler: const TextScaler.linear(2)` e capturar `FlutterError` para confirmar ausencia de overflow.

- [ ] **Step 2: Verify RED**

Run: `flutter test test/features/auth/presentation/screens/superadmin_login_screen_test.dart`
Expected: FAIL because presentation files do not exist.

- [ ] **Step 3: Implement minimal accessible presentation**

Usar `SafeArea > LayoutBuilder > SingleChildScrollView > Center > ConstrainedBox(maxWidth: 480)`. O card usa `Card`, os campos usam `TextFormField` tematizado, o checkbox usa `CheckboxListTile`, e o botao usa `FilledButton` com altura minima `CoeloSize.touchMin`. Cores sao obtidas somente de `Theme.of(context).colorScheme` e `CoeloStatusColors`.

```dart
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Informe seu e-mail.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Informe um e-mail valido.';
  }
  return null;
}
```

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/features/auth/presentation/screens/superadmin_login_screen_test.dart`
Expected: all login screen tests PASS without overflow exceptions.

### Task 4: Asset oficial, URL strategy e verificacao integral

**Files:**
- Create: `apps/superadmin/assets/brand/logo-coelo-orange.png`
- Modify: `apps/superadmin/pubspec.yaml`
- Modify: `apps/superadmin/lib/main.dart`
- Modify tests if asset loading reveals a deterministic test binding requirement.

**Interfaces:**
- Consumes: official `assets/brand/logos/png/logo-Coelo-Laranja.png`.
- Produces: packaged `assets/brand/logo-coelo-orange.png` and clean web paths.

- [ ] **Step 1: Add failing asset assertion**

No widget test should substitute the image. Pump the real screen and assert `find.bySemanticsLabel('Coelo')` finds the official image.

- [ ] **Step 2: Verify RED**

Run: `flutter test test/features/auth/presentation/screens/superadmin_login_screen_test.dart`
Expected: FAIL with missing asset/semantic label.

- [ ] **Step 3: Package official asset and enable path URLs**

Copy the official PNG byte-for-byte, declare `assets/brand/logo-coelo-orange.png` in `pubspec.yaml`, and call `usePathUrlStrategy()` before `runApp` in `main.dart`.

- [ ] **Step 4: Verify feature and app**

Run: `flutter test`
Expected: all tests PASS.

Run: `dart analyze`
Expected: `No issues found!`

Run: `dart format --output=none --set-exit-if-changed lib test`
Expected: exit 0 with no files changed.

- [ ] **Step 5: Code review checklist**

Confirmar no diff: somente `GoRouter`, nenhum HEX na feature, nenhum segredo, guard centralizado, validators explicitos, alvos de 48 dp, scroll/text scaling, widgets focados e pendencias de backend documentadas.

- [ ] **Step 6: Commit implementation**

Stage only files owned by this plan; do not stage `packages/coelo_tokens/lib/src/coelo_theme.dart`.

```text
git commit -m "feat(superadmin): add guarded login"
```

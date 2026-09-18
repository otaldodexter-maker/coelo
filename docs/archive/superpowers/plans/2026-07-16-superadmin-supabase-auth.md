# Superadmin Supabase Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Autenticar o Superadmin com Supabase Auth, persistir a sessao somente quando solicitado, restaurar o estado no roteador e oferecer logout basico.

**Architecture:** `main.dart` compoe um auth scope usando configuracao client-safe de `core/config`. O pacote `coelo_auth` encapsula Supabase e um `LocalStorage` condicional; o app converte os resultados em estado de `SuperadminSession`, e o `GoRouter` reage a esse estado sem assumir autorizacao final.

**Tech Stack:** Flutter 3.32+, Dart 3.8+, `supabase_flutter` 2.16.0, `go_router` 16.x, `flutter_test`.

## Global Constraints

- Usar somente `COELO_SUPABASE_URL` e `COELO_SUPABASE_PUBLISHABLE_KEY` para o cliente Supabase.
- Nunca expor `service_role`, secret key ou credencial de servidor.
- Preservar `MaterialApp.router`, `go_router`, componentes atuais e tokens Coelo.
- Nao implementar platform membership, autorizacao final, MFA, RLS ou backend no cliente.
- Persistir a sessao somente quando `keepSessionOpen` for verdadeiro.
- Escrever cada comportamento com ciclo RED-GREEN-REFACTOR antes de alterar producao.
- Preservar alteracoes locais preexistentes e fazer commits apenas com arquivos desta entrega.

---

### Task 1: Storage de sessao condicional no pacote compartilhado

**Files:**
- Create: `packages/coelo_auth/lib/src/conditional_supabase_local_storage.dart`
- Modify: `packages/coelo_auth/lib/coelo_auth.dart`
- Test: `packages/coelo_auth/test/conditional_supabase_local_storage_test.dart`

**Interfaces:**
- Consumes: `LocalStorage` e `SharedPreferencesLocalStorage` de `supabase_flutter`.
- Produces: `CoeloAuthSessionPersistence.setPersistenceEnabled({required bool value})` e `ConditionalSupabaseLocalStorage`.

- [ ] **Step 1: Escrever testes falhos do storage**

Criar um delegate fake em memoria e testar: inicializacao delegada; leitura de sessao restaurada com estado inicial habilitado; gravacao quando habilitado; remocao e bloqueio de gravacao quando desabilitado; nova gravacao depois de reabilitar.

```dart
final storage = ConditionalSupabaseLocalStorage(delegate: delegate);
await storage.setPersistenceEnabled(value: false);
await storage.persistSession('new-session');
expect(delegate.persistedSession, isNull);

await storage.setPersistenceEnabled(value: true);
await storage.persistSession('kept-session');
expect(delegate.persistedSession, 'kept-session');
```

- [ ] **Step 2: Confirmar RED**

Run: `flutter test test/conditional_supabase_local_storage_test.dart`
Workdir: `packages/coelo_auth`
Expected: FAIL porque `ConditionalSupabaseLocalStorage` ainda nao existe.

- [ ] **Step 3: Implementar storage minimo**

```dart
abstract interface class CoeloAuthSessionPersistence {
  Future<void> setPersistenceEnabled({required bool value});
}

final class ConditionalSupabaseLocalStorage extends LocalStorage
    implements CoeloAuthSessionPersistence {
  ConditionalSupabaseLocalStorage({required LocalStorage delegate})
      : _delegate = delegate;

  final LocalStorage _delegate;
  bool _isPersistenceEnabled = true;

  @override
  Future<void> setPersistenceEnabled({required bool value}) async {
    _isPersistenceEnabled = value;
    if (!value) await _delegate.removePersistedSession();
  }

  @override
  Future<void> persistSession(String session) => _isPersistenceEnabled
      ? _delegate.persistSession(session)
      : Future<void>.value();
}
```

Delegar `initialize`, `hasAccessToken`, `accessToken` e
`removePersistedSession`. Exportar o novo arquivo em `coelo_auth.dart`.

- [ ] **Step 4: Confirmar GREEN e refatorar**

Run: `flutter test test/conditional_supabase_local_storage_test.dart`
Workdir: `packages/coelo_auth`
Expected: PASS.

- [ ] **Step 5: Commit isolado**

```text
git add packages/coelo_auth/lib packages/coelo_auth/test/conditional_supabase_local_storage_test.dart
git commit -m "feat(auth): add conditional Supabase session storage"
```

### Task 2: Encaminhar a preferencia ao adapter Supabase e adicionar logout seguro

**Files:**
- Modify: `packages/coelo_auth/lib/src/coelo_auth_gateway.dart`
- Modify: `packages/coelo_auth/lib/src/supabase_coelo_auth_gateway.dart`
- Modify: `packages/coelo_auth/test/coelo_auth_gateway_test.dart`

**Interfaces:**
- Consumes: `CoeloAuthSessionPersistence` da Task 1.
- Produces: `signInWithPassword({required String email, required String password, required bool persistSession})` e `signOut()`.

- [ ] **Step 1: Escrever testes falhos do gateway**

Adicionar uma persistence fake que registra o ultimo valor e testes que
confirmem a configuracao antes da API, sucesso apenas com sessao valida, falha
generica, encaminhamento de `false` e chamada de logout.

```dart
final result = await gateway.signInWithPassword(
  email: 'owner@coelo.me',
  password: 'secret-password',
  persistSession: false,
);
expect(persistence.isEnabled, isFalse);
expect(result.isSuccess, isTrue);
```

- [ ] **Step 2: Confirmar RED**

Run: `flutter test test/coelo_auth_gateway_test.dart`
Workdir: `packages/coelo_auth`
Expected: FAIL porque o contrato ainda nao aceita `persistSession` e o gateway nao recebe persistence.

- [ ] **Step 3: Implementar o contrato e adapter minimos**

Alterar `CoeloAuthGateway` e `UnavailableCoeloAuthGateway` para receber o bool.
Injetar `CoeloAuthSessionPersistence` no `SupabaseCoeloAuthGateway` e executar:

```dart
await _sessionPersistence.setPersistenceEnabled(value: persistSession);
final didAuthenticate = await _api.signInWithPassword(
  email: email,
  password: password,
);
```

Manter mensagens genericas e `signOut` delegado. O `_SupabaseAuthApi` continua
validando `response.session != null && response.user != null`.

- [ ] **Step 4: Confirmar GREEN**

Run: `flutter test test/coelo_auth_gateway_test.dart`
Workdir: `packages/coelo_auth`
Expected: PASS.

- [ ] **Step 5: Commit isolado**

```text
git add packages/coelo_auth/lib packages/coelo_auth/test/coelo_auth_gateway_test.dart
git commit -m "feat(auth): apply login persistence preference"
```

### Task 3: Compor bootstrap, login e fallback no Superadmin

**Files:**
- Create: `apps/superadmin/lib/core/config/superadmin_auth_scope.dart`
- Modify: `apps/superadmin/lib/main.dart`
- Modify: `apps/superadmin/lib/features/auth/domain/coelo_auth_login_action.dart`
- Modify: `apps/superadmin/test/features/auth/domain/coelo_auth_login_action_test.dart`
- Create: `apps/superadmin/test/core/config/superadmin_auth_scope_test.dart`

**Interfaces:**
- Consumes: `ConditionalSupabaseLocalStorage`, `SupabaseCoeloAuthGateway`, `SuperadminAppConfig`.
- Produces: `SuperadminAuthScope { session, login, logout }` e `createSuperadminAuthScope(...)`.

- [ ] **Step 1: Escrever testes falhos da acao de login**

Atualizar o fake gateway para registrar `persistSession` e testar os dois
valores de `LoginRequest.keepSessionOpen`, sucesso e falha segura.

```dart
await login(const LoginRequest(
  email: 'owner@coelo.me',
  password: 'secret-password',
  keepSessionOpen: true,
));
expect(auth.persistSession, isTrue);
```

- [ ] **Step 2: Confirmar RED da acao**

Run: `flutter test test/features/auth/domain/coelo_auth_login_action_test.dart`
Workdir: `apps/superadmin`
Expected: FAIL porque a acao nao encaminha a preferencia.

- [ ] **Step 3: Implementar encaminhamento minimo**

```dart
final result = await auth.signInWithPassword(
  email: request.email,
  password: request.password,
  persistSession: request.keepSessionOpen,
);
```

Preservar a atualizacao imediata de `SuperadminSession` apenas depois de
resultado validado como sucesso.

- [ ] **Step 4: Confirmar GREEN da acao**

Run: `flutter test test/features/auth/domain/coelo_auth_login_action_test.dart`
Workdir: `apps/superadmin`
Expected: PASS.

- [ ] **Step 5: Escrever testes falhos do auth scope**

Testar uma factory injetavel: configuracao ausente cria gateway indisponivel;
configuracao presente usa initializer, cria storage com chave estavel e inicia
`SuperadminSession` com o estado/stream do gateway.

- [ ] **Step 6: Confirmar RED do auth scope**

Run: `flutter test test/core/config/superadmin_auth_scope_test.dart`
Workdir: `apps/superadmin`
Expected: FAIL porque `superadmin_auth_scope.dart` ainda nao existe.

- [ ] **Step 7: Extrair composicao de `main.dart`**

`main.dart` deve ficar reduzido a binding, URL strategy, criacao do scope e
`runApp`. A factory usa:

```dart
final storage = ConditionalSupabaseLocalStorage(
  delegate: SharedPreferencesLocalStorage(
    persistSessionKey: 'coelo.superadmin.auth.session',
  ),
);
await Supabase.initialize(
  url: config.supabaseUrl,
  publishableKey: config.supabasePublishableKey,
  authOptions: FlutterAuthClientOptions(localStorage: storage),
);
```

Em qualquer falha, reportar via `FlutterError` e retornar scope indisponivel.

- [ ] **Step 8: Confirmar GREEN do auth scope**

Run: `flutter test test/core/config/superadmin_auth_scope_test.dart`
Workdir: `apps/superadmin`
Expected: PASS.

- [ ] **Step 9: Commit isolado**

```text
git add apps/superadmin/lib/main.dart apps/superadmin/lib/core/config apps/superadmin/lib/features/auth/domain/coelo_auth_login_action.dart apps/superadmin/test/core/config apps/superadmin/test/features/auth/domain/coelo_auth_login_action_test.dart
git commit -m "feat(superadmin): bootstrap Supabase authentication"
```

### Task 4: Logout reativo e redirect para login

**Files:**
- Create: `apps/superadmin/lib/features/auth/domain/logout_action.dart`
- Modify: `apps/superadmin/lib/app/superadmin_app.dart`
- Modify: `apps/superadmin/lib/app/router/superadmin_router.dart`
- Modify: `apps/superadmin/lib/app/shell/superadmin_shell.dart`
- Modify: `apps/superadmin/test/app/router/superadmin_router_test.dart`
- Create: `apps/superadmin/test/features/auth/domain/logout_action_test.dart`
- Create: `apps/superadmin/test/app/shell/superadmin_shell_test.dart`

**Interfaces:**
- Consumes: `CoeloAuthGateway.signOut()` e `SuperadminSession.signOut()`.
- Produces: `LogoutAction = Future<LogoutResult> Function()` injetada ate a shell.

- [ ] **Step 1: Escrever testes falhos da acao de logout**

Testar sucesso que chama o gateway e limpa a sessao, e excecao que retorna
mensagem generica sem marcar sucesso.

```dart
final result = await logout();
expect(result.isSuccess, isTrue);
expect(auth.didSignOut, isTrue);
expect(session.isAuthenticated, isFalse);
```

- [ ] **Step 2: Confirmar RED da acao**

Run: `flutter test test/features/auth/domain/logout_action_test.dart`
Workdir: `apps/superadmin`
Expected: FAIL porque `LogoutAction` ainda nao existe.

- [ ] **Step 3: Implementar acao minima**

Criar resultado tipado com `success` e `failure`; chamar `auth.signOut()`, depois
`session.signOut()`, capturando `Exception` em mensagem generica.

- [ ] **Step 4: Confirmar GREEN da acao**

Run: `flutter test test/features/auth/domain/logout_action_test.dart`
Workdir: `apps/superadmin`
Expected: PASS.

- [ ] **Step 5: Escrever widget/router tests falhos**

Testar que a shell oferece `IconButton` com tooltip `Sair`, chama a acao, mostra
feedback em falha e que uma sessao encerrada redireciona de `/` para `/login`.

- [ ] **Step 6: Confirmar RED da shell**

Run: `flutter test test/app/shell/superadmin_shell_test.dart test/app/router/superadmin_router_test.dart`
Workdir: `apps/superadmin`
Expected: FAIL porque logout ainda nao e injetado/renderizado.

- [ ] **Step 7: Injetar e renderizar logout basico**

Propagar `LogoutAction` de `SuperadminApp` para router e shell. Usar somente
`IconButton`, `Icons.logout` e cores do tema. Em falha, exibir `SnackBar` com a
mensagem segura; em sucesso, o estado da sessao provoca o redirect existente.

- [ ] **Step 8: Confirmar GREEN da shell e router**

Run: `flutter test test/app/shell/superadmin_shell_test.dart test/app/router/superadmin_router_test.dart`
Workdir: `apps/superadmin`
Expected: PASS.

- [ ] **Step 9: Commit isolado**

```text
git add apps/superadmin/lib/app apps/superadmin/lib/features/auth/domain/logout_action.dart apps/superadmin/test/app apps/superadmin/test/features/auth/domain/logout_action_test.dart
git commit -m "feat(superadmin): add reactive logout"
```

### Task 5: Configuracao local segura, verificacao completa e localhost

**Files:**
- Modify: `.gitignore`
- Modify: `.env.example`
- Modify: `apps/superadmin/lib/core/config/README.md`
- Modify: `packages/coelo_auth/README.md`

**Interfaces:**
- Consumes: os dois nomes de define do bootstrap.
- Produces: instrucoes reproduziveis sem valores reais versionados.

- [ ] **Step 1: Documentar configuracao sem segredo**

Garantir que arquivos `.env` locais continuam ignorados; incluir regra explicita
para `apps/superadmin/config/*.local.json` somente se um exemplo de
`--dart-define-from-file` for criado. Documentar o comando principal com dois
`--dart-define` e registrar que publishable key e publica, mas `service_role` e
secret key sao proibidas.

- [ ] **Step 2: Formatar**

Run: `dart format lib test`
Workdir: `packages/coelo_auth`
Expected: exit 0.

Run: `dart format lib test`
Workdir: `apps/superadmin`
Expected: exit 0.

- [ ] **Step 3: Rodar suites completas**

Run: `flutter test`
Workdir: `packages/coelo_auth`
Expected: todos os testes passam.

Run: `flutter test`
Workdir: `apps/superadmin`
Expected: todos os testes passam.

- [ ] **Step 4: Rodar analise estatica**

Run: `dart analyze`
Workdir: `packages/coelo_auth`
Expected: `No issues found!`.

Run: `dart analyze`
Workdir: `apps/superadmin`
Expected: `No issues found!`.

- [ ] **Step 5: Build web sem credenciais reais**

Run: `flutter build web`
Workdir: `apps/superadmin`
Expected: exit 0; o bundle usa fallback seguro.

- [ ] **Step 6: Iniciar localhost**

Sem credenciais reais, iniciar web-server em `127.0.0.1:8765` e confirmar HTTP
200. Com valores fornecidos localmente, acrescentar exatamente:

```text
--dart-define=COELO_SUPABASE_URL=<url-publica>
--dart-define=COELO_SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

- [ ] **Step 7: Revisar diff e requisitos**

Run: `git diff --check`
Expected: nenhum erro.

Revisar que nenhum valor com prefixo `sb_secret_`, `service_role` ou senha foi
adicionado, e que as mudancas locais preexistentes continuam preservadas.

- [ ] **Step 8: Commit final de documentacao**

```text
git add .gitignore .env.example apps/superadmin/lib/core/config/README.md packages/coelo_auth/README.md
git commit -m "docs(superadmin): document local auth configuration"
```

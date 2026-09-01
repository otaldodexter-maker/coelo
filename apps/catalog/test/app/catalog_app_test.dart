import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_catalog/app/catalog_app.dart';
import 'package:coelo_catalog/auth/catalog_access_gateway.dart';
import 'package:coelo_catalog/presentation/catalog_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the temporarily public catalog without checking access', (tester) async {
    final access = _FakeCatalogAccessGateway([CatalogAccessResult.unauthenticated]);

    await tester.pumpWidget(
      CatalogApp(accessGateway: access, authGateway: _FakeCoeloAuthGateway(), publicAccess: true),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(access.checkCount, 0);
    expect(find.byType(CatalogHomePage), findsOneWidget);
    expect(find.text('Entre no catálogo'), findsNothing);
    expect(find.text('Fundamentos e componentes reais'), findsOneWidget);
  });

  testWidgets('shows the private catalog after server-side access is allowed', (tester) async {
    await tester.pumpWidget(
      CatalogApp(
        accessGateway: _FakeCatalogAccessGateway([CatalogAccessResult.allowed]),
        authGateway: _FakeCoeloAuthGateway(isAuthenticated: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catálogo Coelo'), findsOneWidget);
    expect(find.byType(CatalogHomePage), findsOneWidget);
  });

  testWidgets('does not query access or mount content during password recovery', (tester) async {
    final access = _FakeCatalogAccessGateway([CatalogAccessResult.allowed]);

    await tester.pumpWidget(
      CatalogApp(accessGateway: access, authGateway: _FakeCoeloAuthGateway(isAuthenticated: false)),
    );
    await tester.pumpAndSettle();

    expect(access.checkCount, 0);
    expect(find.text('Entre no catálogo'), findsOneWidget);
    expect(find.byType(CatalogHomePage), findsNothing);
  });

  testWidgets('does not publish allowed when authentication ends during access check', (
    tester,
  ) async {
    final pendingAccess = Completer<CatalogAccessResult>();
    final access = _FakeCatalogAccessGateway([pendingAccess.future]);
    final auth = _FakeCoeloAuthGateway(isAuthenticated: true);

    await tester.pumpWidget(CatalogApp(accessGateway: access, authGateway: auth));
    await tester.pump();
    expect(access.checkCount, 1);

    auth.isAuthenticated = false;
    pendingAccess.complete(CatalogAccessResult.allowed);
    await tester.pumpAndSettle();

    expect(find.text('Entre no catálogo'), findsOneWidget);
    expect(find.byType(CatalogHomePage), findsNothing);
  });

  testWidgets('authenticates locally and checks server-side access again', (tester) async {
    final access = _FakeCatalogAccessGateway([CatalogAccessResult.allowed]);
    final auth = _FakeCoeloAuthGateway(signInResult: const CoeloAuthSignInResult.success());

    await tester.pumpWidget(CatalogApp(accessGateway: access, authGateway: auth));
    await tester.pumpAndSettle();

    expect(find.text('Entre no catálogo'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('catalog-login-email')), 'catalogo@coelo.me');
    await tester.enterText(find.byKey(const Key('catalog-login-password')), 'senha-segura');
    await tester.tap(find.byKey(const Key('catalog-login-submit')));
    await tester.pumpAndSettle();

    expect(auth.email, 'catalogo@coelo.me');
    expect(auth.password, 'senha-segura');
    expect(auth.persistSession, isTrue);
    expect(access.checkCount, 1);
    expect(find.text('Catálogo Coelo'), findsOneWidget);
  });

  testWidgets('does not enter the catalog when authentication fails', (tester) async {
    final auth = _FakeCoeloAuthGateway(
      signInResult: const CoeloAuthSignInResult.failure('Falha segura.'),
    );

    await tester.pumpWidget(
      CatalogApp(
        accessGateway: _FakeCatalogAccessGateway([CatalogAccessResult.unauthenticated]),
        authGateway: auth,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('catalog-login-email')), 'catalogo@coelo.me');
    await tester.enterText(find.byKey(const Key('catalog-login-password')), 'senha-invalida');
    await tester.tap(find.byKey(const Key('catalog-login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Falha segura.'), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);
  });

  testWidgets('fails closed when the authenticated person is denied', (tester) async {
    await tester.pumpWidget(
      CatalogApp(
        accessGateway: _FakeCatalogAccessGateway([CatalogAccessResult.denied]),
        authGateway: _FakeCoeloAuthGateway(isAuthenticated: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);
  });

  testWidgets('fails closed and allows retry when authorization is unavailable', (tester) async {
    final access = _FakeCatalogAccessGateway([
      CatalogAccessResult.unavailable,
      CatalogAccessResult.denied,
    ]);

    await tester.pumpWidget(
      CatalogApp(accessGateway: access, authGateway: _FakeCoeloAuthGateway(isAuthenticated: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível verificar o acesso'), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Tentar novamente'));
    await tester.pumpAndSettle();

    expect(access.checkCount, 2);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
  });

  testWidgets('checks authorization again after an auth state change', (tester) async {
    final access = _FakeCatalogAccessGateway([
      CatalogAccessResult.allowed,
      CatalogAccessResult.unauthenticated,
    ]);
    final auth = _FakeCoeloAuthGateway(isAuthenticated: true);
    addTearDown(auth.close);

    await tester.pumpWidget(CatalogApp(accessGateway: access, authGateway: auth));
    await tester.pumpAndSettle();
    expect(find.text('Catálogo Coelo'), findsOneWidget);

    auth.emitAuthState(false);
    await tester.pumpAndSettle();

    expect(access.checkCount, 1);
    expect(find.text('Entre no catálogo'), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);
  });

  testWidgets('fails closed when the auth state stream emits an error', (tester) async {
    final pendingAccess = Completer<CatalogAccessResult>();
    final access = _FakeCatalogAccessGateway([pendingAccess.future]);
    final auth = _FakeCoeloAuthGateway(isAuthenticated: true);
    addTearDown(auth.close);

    await tester.pumpWidget(CatalogApp(accessGateway: access, authGateway: auth));
    await tester.pump();

    auth.emitAuthError(Exception('stream unavailable'));
    await tester.pump();

    expect(find.text('Não foi possível verificar o acesso'), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);

    pendingAccess.complete(CatalogAccessResult.allowed);
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível verificar o acesso'), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);
  });

  testWidgets('ignores an older access result that completes last', (tester) async {
    final older = Completer<CatalogAccessResult>();
    final newer = Completer<CatalogAccessResult>();
    final access = _FakeCatalogAccessGateway([older.future, newer.future]);
    final auth = _FakeCoeloAuthGateway(isAuthenticated: true);
    addTearDown(auth.close);

    await tester.pumpWidget(CatalogApp(accessGateway: access, authGateway: auth));
    await tester.pump();

    auth.emitAuthState(true);
    await tester.pump();
    newer.complete(CatalogAccessResult.denied);
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);

    older.complete(CatalogAccessResult.allowed);
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);
  });

  testWidgets('revalidates and closes the catalog when the app resumes', (tester) async {
    final resumedAccess = Completer<CatalogAccessResult>();
    final access = _FakeCatalogAccessGateway([CatalogAccessResult.allowed, resumedAccess.future]);

    await tester.pumpWidget(
      CatalogApp(accessGateway: access, authGateway: _FakeCoeloAuthGateway(isAuthenticated: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catálogo Coelo'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(access.checkCount, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);

    resumedAccess.complete(CatalogAccessResult.denied);
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
  });

  testWidgets('periodically revalidates only while access remains allowed', (tester) async {
    final periodicAccess = Completer<CatalogAccessResult>();
    final access = _FakeCatalogAccessGateway([CatalogAccessResult.allowed, periodicAccess.future]);

    await tester.pumpWidget(
      CatalogApp(accessGateway: access, authGateway: _FakeCoeloAuthGateway(isAuthenticated: true)),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(minutes: 5));
    expect(access.checkCount, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    periodicAccess.complete(CatalogAccessResult.denied);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 10));

    expect(access.checkCount, 2);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
  });

  testWidgets('keeps a revoked authenticated session outside the catalog', (tester) async {
    final access = _FakeCatalogAccessGateway([
      CatalogAccessResult.allowed,
      CatalogAccessResult.denied,
    ]);
    final auth = _FakeCoeloAuthGateway(isAuthenticated: true);
    addTearDown(auth.close);

    await tester.pumpWidget(CatalogApp(accessGateway: access, authGateway: auth));
    await tester.pumpAndSettle();

    auth.emitAuthState(true);
    await tester.pumpAndSettle();

    expect(auth.isAuthenticated, isTrue);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);
  });

  testWidgets('restores login with a generic error when sign in throws', (tester) async {
    final auth = _FakeCoeloAuthGateway(signInException: Exception('sensitive failure'));

    await tester.pumpWidget(
      CatalogApp(
        accessGateway: _FakeCatalogAccessGateway([CatalogAccessResult.unauthenticated]),
        authGateway: auth,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('catalog-login-email')), 'catalogo@coelo.me');
    await tester.enterText(find.byKey(const Key('catalog-login-password')), 'senha');
    await tester.tap(find.byKey(const Key('catalog-login-submit')));
    await tester.pumpAndSettle();

    expect(find.text(CoeloAuthSignInResult.genericFailureMessage), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('catalog-login-submit'))).onPressed,
      isNotNull,
    );
    expect(find.text('sensitive failure'), findsNothing);
  });

  testWidgets('signs out and returns to the local catalog login', (tester) async {
    final access = _FakeCatalogAccessGateway([
      CatalogAccessResult.allowed,
      CatalogAccessResult.unauthenticated,
    ]);
    final auth = _FakeCoeloAuthGateway(isAuthenticated: true);
    addTearDown(auth.close);

    await tester.pumpWidget(CatalogApp(accessGateway: access, authGateway: auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    expect(auth.signOutCount, 1);
    expect(find.text('Entre no catálogo'), findsOneWidget);
  });

  testWidgets('keeps content closed when sign out fails and the session remains', (tester) async {
    final access = _FakeCatalogAccessGateway([
      CatalogAccessResult.allowed,
      CatalogAccessResult.allowed,
    ]);
    final auth = _FakeCoeloAuthGateway(
      isAuthenticated: true,
      signOutException: Exception('sign out failed'),
    );
    addTearDown(auth.close);

    await tester.pumpWidget(CatalogApp(accessGateway: access, authGateway: auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();

    expect(auth.signOutCount, 1);
    expect(auth.isAuthenticated, isTrue);
    expect(find.text('Não foi possível sair'), findsOneWidget);
    expect(find.text('Catálogo Coelo'), findsNothing);
  });

  testWidgets('does not publish a pending result after disposal', (tester) async {
    final pendingAccess = Completer<CatalogAccessResult>();

    await tester.pumpWidget(
      CatalogApp(
        accessGateway: _FakeCatalogAccessGateway([pendingAccess.future]),
        authGateway: _FakeCoeloAuthGateway(isAuthenticated: true),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    pendingAccess.complete(CatalogAccessResult.allowed);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Catálogo Coelo'), findsNothing);
  });
}

final class _FakeCatalogAccessGateway implements CatalogAccessGateway {
  _FakeCatalogAccessGateway(this.results);

  final List<FutureOr<CatalogAccessResult>> results;
  var checkCount = 0;

  @override
  Future<CatalogAccessResult> checkAccess() async {
    final index = checkCount < results.length ? checkCount : results.length - 1;
    checkCount++;
    return await results[index];
  }
}

final class _FakeCoeloAuthGateway implements CoeloAuthGateway {
  _FakeCoeloAuthGateway({
    this.signInResult = const CoeloAuthSignInResult.success(),
    this.isAuthenticated = false,
    this.signInException,
    this.signOutException,
  });

  final CoeloAuthSignInResult signInResult;
  final Exception? signInException;
  final Exception? signOutException;
  final _authStateController = StreamController<bool>.broadcast();

  @override
  bool isAuthenticated;

  String? email;
  String? password;
  bool? persistSession;
  var signOutCount = 0;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  Future<void> close() => _authStateController.close();

  void emitAuthState(bool isAuthenticated) {
    this.isAuthenticated = isAuthenticated;
    _authStateController.add(isAuthenticated);
  }

  void emitAuthError(Exception error) {
    _authStateController.addError(error);
  }

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecovery({required String email}) async {
    return const CoeloAuthPasswordRecoveryResult.success();
  }

  @override
  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) async {
    this.email = email;
    this.password = password;
    this.persistSession = persistSession;
    if (signInException case final exception?) {
      throw exception;
    }
    isAuthenticated = signInResult.isSuccess;
    return signInResult;
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    if (signOutException case final exception?) {
      throw exception;
    }
    isAuthenticated = false;
  }
}

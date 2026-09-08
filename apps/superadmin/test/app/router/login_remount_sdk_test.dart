import 'dart:async';
import 'dart:convert';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final firstBootstrap = Completer<Response>();
  final secondBootstrap = Completer<Response>();
  final logoutSessions = <String>[];
  var signIns = 0;
  var bootstraps = 0;
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/token')) {
        signIns++;
        return _response(_session(signIns == 1 ? _sessionA : _sessionB));
      }
      if (request.url.path.endsWith('/superadmin_auth_bootstrap_context')) {
        final response = await (++bootstraps == 1 ? firstBootstrap.future : secondBootstrap.future);
        return Response(
          response.body,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }
      if (request.url.path.endsWith('/logout')) {
        final token = request.headers['Authorization'] ?? request.headers['authorization']!;
        final payload =
            jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))))
                as Map;
        logoutSessions.add(payload['session_id'] as String);
        return _response(<String, Object?>{});
      }
      throw StateError('Unexpected synthetic endpoint: ${request.url.path}');
    }),
  );
  tearDownAll(client.dispose);

  testWidgets(
    'remounting login cannot overlap an owned SDK credential/bootstrap/cleanup operation',
    (tester) async {
      final scope = await tester.runAsync(
        () => createSuperadminAuthScope(
          supabaseUrl: 'https://example.supabase.co',
          supabasePublishableKey: 'publishable-test',
          initializeSupabase:
              ({required localStorage, required publishableKey, required url}) async => client,
          createAuthGateway:
              ({
                required client,
                required sessionPersistence,
                required initialRecoveryAccessToken,
              }) => SupabaseCoeloAuthGateway(client, sessionPersistence: _Persistence()),
        ),
      );
      addTearDown(scope!.session.dispose);
      await tester.pumpWidget(
        SuperadminApp(
          session: scope.session,
          login: scope.login,
          logout: scope.logout,
          requestPasswordRecovery: scope.requestPasswordRecovery,
          resetPassword: scope.resetPassword,
          userPreferencesRepository: InMemoryUserPreferencesRepository(),
        ),
      );
      await tester.pumpAndSettle();
      final router = tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
      final firstLoginElement = tester.element(find.byType(SuperadminLoginScreen));
      await _submit(tester, 'first@invalid.test');
      expect(signIns, 1);
      expect(bootstraps, 1);

      // Browser history/public navigation can replace the ViewModel while A is pending.
      router.go('/forgot-password');
      await tester.pumpAndSettle();
      router.go('/login');
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(SuperadminLoginScreen)), isNot(same(firstLoginElement)));
      await _submit(tester, 'second@invalid.test');

      firstBootstrap.complete(
        _response({
          'ok': false,
          'data': null,
          'error': {'code': 'SAI_PERMISSION_DENIED'},
        }),
      );
      await _pumpUntil(tester, () => logoutSessions.isNotEmpty);
      // Release any second response even on the unfixed path; do not leave dangling work.
      secondBootstrap.complete(_response(_allowed));
      await tester.pump();
      expect(
        logoutSessions,
        isNot(contains(_sessionB)),
        reason: 'A cleanup must never target a second UI attempt',
      );
      expect(
        signIns,
        1,
        reason: 'single-flight belongs to the shared action, not a disposable ViewModel',
      );
      expect(scope.session.isAuthenticated, isFalse);

      // A failed operation releases ownership so a new user attempt can succeed.
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await _pumpUntil(tester, () => scope.session.isAuthenticated);
      await tester.pumpAndSettle();
      expect(signIns, 2);
      expect(bootstraps, 2);
      expect(scope.session.isAuthenticated, isTrue);
      expect(scope.session.sessionId, _sessionB);
      expect(logoutSessions, [_sessionA]);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _submit(WidgetTester tester, String email) async {
  await tester.enterText(find.byKey(const ValueKey('superadmin-login-email')), email);
  await tester.enterText(
    find.byKey(const ValueKey('superadmin-login-password')),
    'synthetic-password',
  );
  await tester.tap(find.text('Entrar'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() completed) async {
  for (var attempt = 0; attempt < 20 && !completed(); attempt++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  expect(completed(), isTrue, reason: 'mock HTTP completion must reach the SDK before assertions');
}

Response _response(Object body) =>
    Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

const _sessionA = '11111111-1111-4111-8111-111111111111';
const _sessionB = '22222222-2222-4222-8222-222222222222';
const _allowed = {
  'ok': true,
  'data': {
    'platform_role_code': 'operations',
    'scope_kind': 'platform',
    'scope_institution_id': null,
    'permission_codes': ['platform.read'],
    'aal': 'aal1',
  },
  'error': null,
};

Map<String, Object?> _session(String sessionId) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  const userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  final token =
      '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': userId, 'session_id': sessionId, 'role': 'authenticated', 'aal': 'aal1', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.synthetic-signature';
  return {
    'access_token': token,
    'refresh_token': 'synthetic-refresh-$sessionId',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'synthetic@invalid.test',
      'app_metadata': <String, Object?>{},
      'user_metadata': <String, Object?>{},
      'created_at': '2026-09-01T00:00:00Z',
    },
  };
}

final class _Persistence implements CoeloAuthSessionPersistence {
  @override
  Future<void> setPersistenceEnabled({required bool value}) async {}
}

import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_login_screen.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Production scope, SDK, actions, forms and router; only HTTP is synthetic.
// This proof does not claim SMTP delivery, server token validity or revocation.
void main() {
  for (final logoutSucceeds in [true, false]) {
    testWidgets(
      'SDK recovery callback through reset form waits for logout: success=$logoutSucceeds',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final requests = <Request>[];
        final logoutRelease = Completer<void>();
        final logoutStarted = Completer<void>();
        final client = (await tester.runAsync(
          () async => SupabaseClient(
            'https://d01-recovery.invalid',
            'd01-synthetic-publishable',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              requests.add(request);
              if (request.method == 'GET' && request.url.path == '/auth/v1/user') {
                return _json(request, _user);
              }
              if (request.method == 'PUT' && request.url.path == '/auth/v1/user') {
                return _json(request, _user);
              }
              if (request.method == 'POST' && request.url.path == '/auth/v1/logout') {
                logoutStarted.complete();
                await logoutRelease.future;
                return logoutSucceeds
                    ? _json(request, <String, Object?>{})
                    : _json(request, {
                        'code': 'unexpected_failure',
                        'msg': 'Synthetic failure',
                      }, 500);
              }
              throw StateError(
                'Unexpected synthetic endpoint: ${request.method} ${request.url.path}',
              );
            }),
          ),
        ))!;
        // SDK initialization and isolate disposal use real asynchronous time.
        addTearDown(() async => tester.runAsync(client.dispose));
        addTearDown(() {
          if (!logoutRelease.isCompleted) logoutRelease.complete();
        });

        final scope = await tester.runAsync(
          () => createSuperadminAuthScope(
            supabaseUrl: 'https://d01-recovery.invalid',
            supabasePublishableKey: 'd01-synthetic-publishable',
            initializeSupabase:
                ({required localStorage, required publishableKey, required url}) async {
                  await localStorage.initialize();
                  return client;
                },
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
        expect(find.byType(SuperadminLoginScreen), findsOneWidget);
        final router =
            tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;

        final token = _token();
        final callback = Uri(
          scheme: 'https',
          host: 'superadmin.example.invalid',
          path: '/reset-password',
          fragment: Uri(
            queryParameters: {
              'type': 'recovery',
              'access_token': token,
              'refresh_token': 'd01-synthetic-recovery-refresh',
              'expires_in': '3600',
              'token_type': 'bearer',
            },
          ).query,
        );
        await tester.runAsync(() => client.auth.getSessionFromUrl(callback));

        await tester.pumpAndSettle();
        expect(scope.session.isPasswordRecovery, isTrue);
        expect(scope.session.isAuthenticated, isFalse);
        expect(scope.session.authContext, isNull);
        expect(router.routeInformationProvider.value.uri.path, '/reset-password');
        expect(find.byType(SuperadminResetPasswordScreen), findsOneWidget);
        expect(requests, hasLength(1));
        expect(requests.single.method, 'GET');

        const newPassword = 'D01SyntheticNewPassword123!';
        await tester.enterText(
          find.byKey(const ValueKey('superadmin-reset-password')),
          newPassword,
        );
        await tester.enterText(
          find.byKey(const ValueKey('superadmin-reset-password-confirmation')),
          newPassword,
        );
        final submit = find.widgetWithText(FilledButton, 'Salvar nova senha');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await _pumpUntil(tester, () => logoutStarted.isCompleted);
        final update = requests.singleWhere((request) => request.method == 'PUT');
        expect(jsonDecode(update.body), {'password': newPassword});
        expect(update.headers['authorization'], 'Bearer $token');
        expect(find.text('Senha atualizada'), findsNothing);
        expect(scope.session.isAuthenticated, isFalse);
        expect(scope.session.authContext, isNull);

        logoutRelease.complete();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));

        await tester.pumpAndSettle();

        expect(find.text('Senha atualizada'), logoutSucceeds ? findsOneWidget : findsNothing);
        // GoTrue removes its local session before awaiting remote revocation,
        // including a 500 response. A failure must not restore credentials.
        expect(client.auth.currentSession, isNull);
        expect(scope.session.isPasswordRecovery, isFalse);
        expect(scope.session.isAuthenticated, isFalse);
        expect(scope.session.authContext, isNull);
        expect(requests.map((request) => '${request.method} ${request.url.path}'), [
          'GET /auth/v1/user',
          'PUT /auth/v1/user',
          'POST /auth/v1/logout',
        ]);
        if (!logoutSucceeds) {
          expect(
            find.text(
              'A senha foi alterada, mas n\u00e3o foi poss\u00edvel confirmar o encerramento da sess\u00e3o.',
            ),
            findsOneWidget,
          );
        }

        final back = find.text('Voltar para entrar');
        await tester.ensureVisible(back);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/login');
        expect(find.byType(SuperadminLoginScreen), findsOneWidget);
        expect(requests.where((request) => request.method == 'PUT'), hasLength(1));
        expect(requests.where((request) => request.url.path.endsWith('/logout')), hasLength(1));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() complete) async {
  for (var attempt = 0; attempt < 30 && !complete(); attempt++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  expect(complete(), isTrue, reason: 'Synthetic HTTP must reach the pending logout.');
}

const _userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _sessionId = '11111111-1111-4111-8111-111111111111';
const _user = <String, Object?>{
  'id': _userId,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'recovery-proof@example.invalid',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
  'created_at': '2026-09-09T00:00:00Z',
};

String _token() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'sub': _userId, 'session_id': _sessionId, 'role': 'authenticated', 'aal': 'aal1', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.'
      'd01-synthetic-signature';
}

Response _json(Request request, Object body, [int statusCode = 200]) => Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json'},
  request: request,
);

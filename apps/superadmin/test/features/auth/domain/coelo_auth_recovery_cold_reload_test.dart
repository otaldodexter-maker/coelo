import 'dart:convert';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final persistRecovery in [true, false]) {
    testWidgets(
      'cold reload never upgrades recovery into normal context: persist=$persistRecovery',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        var bootstrapCalls = 0;
        var firstInitialization = true;
        SuperadminAuthScope? activeScope;
        var sdkInitialized = false;
        addTearDown(() async {
          await tester.runAsync(() async {
            activeScope?.session.dispose();
            if (sdkInitialized) await Supabase.instance.dispose();
          });
        });

        Future<SuperadminAuthScope> createScope() => createSuperadminAuthScope(
          supabaseUrl: 'https://d01-cold-reload.invalid',
          supabasePublishableKey: 'd01-synthetic-publishable',
          appUri: Uri.parse('https://superadmin.example.invalid/reset-password'),
          initializeSupabase:
              ({required url, required publishableKey, required localStorage}) async {
                // Real production storage adapter and SDK lifecycle. Only the
                // platform SharedPreferences backing store is replaced by memory.
                await Supabase.initialize(
                  url: url,
                  publishableKey: publishableKey,
                  debug: false,
                  authOptions: FlutterAuthClientOptions(
                    localStorage: localStorage,
                    autoRefreshToken: false,
                    detectSessionInUri: false,
                  ),
                  httpClient: MockClient((request) async {
                    if (request.method == 'GET' && request.url.path == '/auth/v1/user') {
                      return _json(request, _user);
                    }
                    if (request.method == 'POST' &&
                        request.url.path == '/rest/v1/rpc/superadmin_auth_bootstrap_context') {
                      bootstrapCalls++;
                      // Discriminant for the client: no claim that production would
                      // authorize this recovery token. It must not request bootstrap.
                      return _json(request, {
                        'ok': true,
                        'data': {
                          'platform_role_code': 'operations',
                          'scope_kind': 'platform',
                          'scope_institution_id': null,
                          'permission_codes': ['platform.read'],
                          'aal': 'aal1',
                        },
                        'error': null,
                      });
                    }
                    throw StateError(
                      'Unexpected synthetic request: ${request.method} ${request.url.path}',
                    );
                  }),
                );
                sdkInitialized = true;
                if (firstInitialization) {
                  firstInitialization = false;
                  await (localStorage as CoeloAuthSessionPersistence).setPersistenceEnabled(
                    value: persistRecovery,
                  );
                }
                return Supabase.instance.client;
              },
        );

        activeScope = await tester.runAsync(createScope);
        final firstScope = activeScope!;
        await tester.runAsync(() async {
          await Supabase.instance.client.auth.getSessionFromUrl(_callback());
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pumpWidget(_app(firstScope));
        await tester.pumpAndSettle();
        expect(firstScope.session.isPasswordRecovery, isTrue);
        expect(firstScope.session.isAuthenticated, isFalse);
        expect(find.byType(SuperadminResetPasswordScreen), findsOneWidget);
        expect(bootstrapCalls, 0);
        final wasPersisted = await tester.runAsync(() async {
          final preferences = await SharedPreferences.getInstance();
          return preferences.containsKey('coelo.superadmin.auth.session');
        });
        expect(wasPersisted, isFalse, reason: 'Recovery credentials must stay in memory only.');

        // Cold SDK/scope restart after successful callback URL sanitization.
        // No direct injection of a restored session or authorization is used.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          firstScope.session.dispose();
          activeScope = null;
          await Supabase.instance.dispose();
          sdkInitialized = false;
        });
        activeScope = await tester.runAsync(createScope);
        final restored = activeScope!;
        await tester.pumpWidget(_app(restored));
        await tester.pumpAndSettle();
        final router =
            tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
        router.go('/reset-password');
        await tester.pumpAndSettle();

        expect(
          {
            'bootstrapCalls': bootstrapCalls,
            'authenticated': restored.session.isAuthenticated,
            'hasContext': restored.session.authContext != null,
            'route': router.routeInformationProvider.value.uri.path,
            'resetScreen': find.byType(SuperadminResetPasswordScreen).evaluate().length,
          },
          {
            'bootstrapCalls': 0,
            'authenticated': false,
            'hasContext': false,
            'route': '/reset-password',
            'resetScreen': 1,
          },
          reason:
              'Persisted recovery must remain confined or require a new link, never become normal auth.',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );
  }
}

Widget _app(SuperadminAuthScope scope) => SuperadminApp(
  session: scope.session,
  login: scope.login,
  logout: scope.logout,
  requestPasswordRecovery: scope.requestPasswordRecovery,
  resetPassword: scope.resetPassword,
  userPreferencesRepository: InMemoryUserPreferencesRepository(),
);

const _userId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _user = <String, Object?>{
  'id': _userId,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'cold-recovery@example.invalid',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
  'created_at': '2026-09-09T00:00:00Z',
};

Uri _callback() {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'sub': _userId, 'session_id': '11111111-1111-4111-8111-111111111111', 'role': 'authenticated', 'aal': 'aal1', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.'
      'd01-synthetic-signature';
  return Uri(
    scheme: 'https',
    host: 'superadmin.example.invalid',
    path: '/reset-password',
    fragment: Uri(
      queryParameters: {
        'type': 'recovery',
        'access_token': token,
        'refresh_token': 'd01-synthetic-refresh',
        'expires_in': '3600',
        'token_type': 'bearer',
      },
    ).query,
  );
}

Response _json(Request request, Object body) => Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

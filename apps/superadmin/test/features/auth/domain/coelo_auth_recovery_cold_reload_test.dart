import 'dart:convert';
import 'dart:io';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/app/superadmin_app.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/account/data/user_preferences_repository.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_reset_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final realBackend in [false, true]) {
    testWidgets(
      realBackend
          ? 'cold reload storage failure: backend denies retained recovery after restart'
          : 'cold reload storage failure: retained recovery never gains normal context',
      (tester) async {
        final apiUrl = realBackend
            ? Platform.environment['COELO_D01_LOCAL_SUPABASE_URL']!
            : 'https://d01-cold-failure.invalid';
        final publishableKey = realBackend
            ? Platform.environment['COELO_D01_LOCAL_PUBLISHABLE_KEY']!
            : 'd01-synthetic-publishable';
        final apiUri = Uri.parse(apiUrl);
        if (realBackend) {
          expect(
            apiUri.scheme == 'http' && ['127.0.0.1', 'localhost', '::1'].contains(apiUri.host),
            isTrue,
            reason: 'The real backend fixture accepts loopback HTTP only.',
          );
        }
        final realTransport = realBackend
            ? _LocalBoundaryTransport(
                apiUri,
              IOClient(_DirectHttpOverrides().createHttpClient(null)),
              )
            : null;
        if (realTransport != null) addTearDown(realTransport.close);
        SharedPreferences.setMockInitialValues({});
        final reported = <FlutterErrorDetails>[];
        final previousHandler = FlutterError.onError;
        FlutterError.onError = reported.add;
        addTearDown(() => FlutterError.onError = previousHandler);
        var bootstrapCalls = 0;
        var firstInitialization = true;
        var sdkInitialized = false;
        SuperadminAuthScope? scope;
        late ConditionalSupabaseLocalStorage sdkStorage;
        final failingStorage = _FailOnceRemovalStorage(
          SharedPreferencesLocalStorage(persistSessionKey: 'coelo.superadmin.auth.session'),
          failPermanently: realBackend,
        );
        addTearDown(() async {
          await tester.runAsync(() async {
            scope?.session.dispose();
            if (sdkInitialized) await Supabase.instance.dispose();
          });
        });

        Future<SuperadminAuthScope> createScope() => createSuperadminAuthScope(
          supabaseUrl: apiUrl,
          supabasePublishableKey: publishableKey,
          appUri: Uri.parse('https://superadmin.example.invalid/reset-password'),
          initializeSupabase:
              ({required url, required publishableKey, required localStorage}) async {
                final first = firstInitialization;
                firstInitialization = false;
                // Production adapter and SharedPreferences delegate. Real backend
                // variant keeps disk removal broken across both initializations.
                sdkStorage = ConditionalSupabaseLocalStorage(
                  delegate: first
                      ? failingStorage
                      : realBackend
                      ? _FailOnceRemovalStorage(
                          SharedPreferencesLocalStorage(
                            persistSessionKey: 'coelo.superadmin.auth.session',
                          ),
                          failPermanently: true,
                        )
                      : SharedPreferencesLocalStorage(
                          persistSessionKey: 'coelo.superadmin.auth.session',
                        ),
                );
                await Supabase.initialize(
                  url: url,
                  publishableKey: publishableKey,
                  debug: false,
                  authOptions: FlutterAuthClientOptions(
                    localStorage: sdkStorage,
                    autoRefreshToken: false,
                    detectSessionInUri: false,
                  ),
                  httpClient:
                      realTransport ??
                      MockClient((request) async {
                        if (request.method == 'GET' && request.url.path == '/auth/v1/user') {
                          return _json(request, _user);
                        }
                        if (request.method == 'POST' &&
                            request.url.path == '/rest/v1/rpc/superadmin_auth_bootstrap_context') {
                          bootstrapCalls++;
                          // Deliberately permissive discriminant, never backend proof.
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
                if (first) {
                  // Startup callback before constructing the gateway: real SDK replay
                  // observes recovery whose asynchronous disk write has completed.
                  await Supabase.instance.client.auth.getSessionFromUrl(
                    _callback(
                      accessToken: realBackend
                          ? Platform.environment['COELO_D01_RECOVERY_ACCESS_TOKEN']
                          : null,
                      refreshToken: realBackend
                          ? Platform.environment['COELO_D01_RECOVERY_REFRESH_TOKEN']
                          : null,
                    ),
                  );
                  await Future<void>.delayed(Duration.zero);
                  expect(await sdkStorage.hasAccessToken(), isTrue);
                }
                return Supabase.instance.client;
              },
          createAuthGateway:
              ({
                required client,
                required sessionPersistence,
                required initialRecoveryAccessToken,
              }) => SupabaseCoeloAuthGateway(client, sessionPersistence: sdkStorage),
        );

        scope = await tester.runAsync(createScope);
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        FlutterError.onError = previousHandler;
        expect(failingStorage.removeAttempts, 1);
        expect(reported.length, 1);
        expect(
          reported.single.exceptionAsString().contains('Recovery persistence cleanup failed.'),
          isTrue,
        );
        expect(scope!.session.isAuthenticated, isFalse);
        expect(bootstrapCalls, 0);
        expect(await tester.runAsync(sdkStorage.hasAccessToken), isTrue);

        await tester.runAsync(() async {
          scope!.session.dispose();
          scope = null;
          await Supabase.instance.dispose();
          sdkInitialized = false;
        });
        scope = await tester.runAsync(createScope);
        await tester.pumpWidget(_app(scope!));
        await tester.pumpAndSettle();
        final router =
            tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig! as GoRouter;
        router.go('/reset-password');
        await tester.pumpAndSettle();
        expect(
          {
            'bootstrapCalls': realTransport?.bootstrapCalls ?? bootstrapCalls,
            'authenticated': scope!.session.isAuthenticated,
            'hasContext': scope!.session.authContext != null,
            'route': router.routeInformationProvider.value.uri.path,
          },
          {
            'bootstrapCalls': realBackend ? 1 : 0,
            'authenticated': false,
            'hasContext': false,
            'route': '/reset-password',
          },
          reason:
              'A persisted recovery after failed purge must not become productive auth after cold restart.',
        );
        if (realTransport != null) {
          expect(
            realTransport.deniedWithSessionInvalid,
            isTrue,
            reason: 'The actual RPC must return ok=false, data=null and SAI_SESSION_INVALID.',
          );
          expect(realTransport.logoutCalls, 1);
          expect(realTransport.logoutConfirmed, isTrue);
          expect(Supabase.instance.client.auth.currentSession == null, isTrue);
          expect(
            await tester.runAsync(sdkStorage.hasAccessToken),
            isTrue,
            reason:
                'Disk removal remains broken; backend denial must protect the restored credential.',
          );
          // Fixed, non-sensitive receipt consumed by the local SQL runner.
          // ignore: avoid_print
          print('D01_COLD_STORAGE_REAL_BE_PASS');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
      timeout: const Timeout(Duration(seconds: 90)),
      skip: realBackend
          ? !_realBackendEnvironmentAvailable
          : Platform.environment['COELO_D01_RUN_STORAGE_FAILURE_DIAGNOSTIC'] != 'true',
    );
  }

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

bool get _realBackendEnvironmentAvailable => [
  'COELO_D01_LOCAL_SUPABASE_URL',
  'COELO_D01_LOCAL_PUBLISHABLE_KEY',
  'COELO_D01_RECOVERY_ACCESS_TOKEN',
  'COELO_D01_RECOVERY_REFRESH_TOKEN',
].every((key) => Platform.environment[key]?.isNotEmpty == true);

// This transport only records sanitized outcomes. Every allowed request is
// forwarded to the actual disposable backend; it never fabricates a denial.
final class _DirectHttpOverrides extends HttpOverrides {}

final class _LocalBoundaryTransport extends BaseClient {
  _LocalBoundaryTransport(this.origin, this.delegate);

  final Uri origin;
  final Client delegate;
  int bootstrapCalls = 0;
  int logoutCalls = 0;
  bool deniedWithSessionInvalid = false;
  bool logoutConfirmed = false;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final bootstrap =
        request.method == 'POST' &&
        request.url.path == '/rest/v1/rpc/superadmin_auth_bootstrap_context';
    final logout = request.method == 'POST' && request.url.path == '/auth/v1/logout';
    final user = request.method == 'GET' && request.url.path == '/auth/v1/user';
    if (request.url.origin != origin.origin || (!bootstrap && !logout && !user)) {
      throw StateError('Local backend fixture rejected an unexpected request.');
    }
    request.followRedirects = false;
    try {
      final response = await delegate.send(request);
      final bytes = await response.stream.toBytes();
      if (bootstrap) {
        bootstrapCalls++;
        final body = jsonDecode(utf8.decode(bytes));
        deniedWithSessionInvalid =
            response.statusCode == 200 &&
            body is Map<String, dynamic> &&
            body['ok'] == false &&
            body['data'] == null &&
            body['error'] is Map<String, dynamic> &&
            (body['error'] as Map<String, dynamic>)['code'] == 'SAI_SESSION_INVALID';
      }
      if (logout) {
        logoutCalls++;
        logoutConfirmed = response.statusCode == 200 || response.statusCode == 204;
      }
      return StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    } catch (_) {
      throw StateError('Local backend fixture request could not be confirmed.');
    }
  }

  @override
  void close() => delegate.close();
}

final class _FailOnceRemovalStorage extends LocalStorage {
  _FailOnceRemovalStorage(this.delegate, {this.failPermanently = false});

  final LocalStorage delegate;
  final bool failPermanently;
  int removeAttempts = 0;

  @override
  Future<void> initialize() => delegate.initialize();
  @override
  Future<bool> hasAccessToken() => delegate.hasAccessToken();
  @override
  Future<String?> accessToken() => delegate.accessToken();
  @override
  Future<void> persistSession(String value) => delegate.persistSession(value);
  @override
  Future<void> removePersistedSession() {
    removeAttempts++;
    if (failPermanently || removeAttempts == 1) {
      return Future<void>.error(StateError('Synthetic disk removal failure'));
    }
    return delegate.removePersistedSession();
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

Uri _callback({String? accessToken, String? refreshToken}) {
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
        'access_token': accessToken ?? token,
        'refresh_token': refreshToken ?? 'd01-synthetic-refresh',
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

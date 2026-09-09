import 'dart:async';
import 'dart:convert';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final scenario in ['invalid', 'expired', 'reused']) {
    test('rejected recovery OTP cannot enable password updates: $scenario', () async {
      final requests = <Request>[];
      var consumed = false;
      final transport = MockClient((request) async {
        requests.add(request);
        final isVerify = request.method == 'POST' && request.url.path.endsWith('/verify');
        if (isVerify && scenario == 'reused' && !consumed) {
          consumed = true;
          return Response(
            jsonEncode(_session(1)),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return Response(
          jsonEncode({
            'code': 403,
            'error_code': 'otp_expired',
            'msg': 'Token has expired or is invalid',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });
      SupabaseClient createClient() => SupabaseClient(
        'https://example.supabase.co',
        'publishable-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: transport,
      );
      final tokenHash = 'synthetic-$scenario-recovery-hash';
      if (scenario == 'reused') {
        final firstClient = createClient();
        final first = await firstClient.auth.verifyOTP(
          type: OtpType.recovery,
          tokenHash: tokenHash,
        );
        expect(first.session, isNotNull);
        await firstClient.dispose();
      }
      final client = createClient();
      addTearDown(client.dispose);
      final gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: _Persistence());
      addTearDown(gateway.dispose);
      final states = <CoeloAuthSessionState>[];
      final subscription = gateway.authSessionStateChanges.listen(states.add);
      addTearDown(subscription.cancel);

      await expectLater(
        client.auth.verifyOTP(type: OtpType.recovery, tokenHash: tokenHash),
        throwsA(isA<AuthException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(client.auth.currentSession, isNull);
      expect(gateway.currentSessionState.kind, CoeloAuthSessionKind.signedOut);
      expect(states.where((state) => state.isPasswordRecovery || state.isAuthenticated), isEmpty);
      final reset = await gateway.updatePassword(password: 'must-not-be-sent');
      expect(reset.isSuccess, isFalse);
      expect(reset.message, CoeloAuthPasswordUpdateResult.genericFailureMessage);
      expect(requests, hasLength(scenario == 'reused' ? 2 : 1));
      for (final request in requests) {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/v1/verify');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['token_hash'], tokenHash);
        expect(body['type'], 'recovery');
      }
      expect(requests.where((request) => request.method == 'PUT'), isEmpty);
      expect(requests.where((request) => request.url.path.endsWith('/logout')), isEmpty);
    });
  }

  for (final sameUser in [false, true]) {
    test(
      'external SDK session replacement survives an older recovery response: sameUser=$sameUser',
      () async {
        const sessionB = '22222222-2222-4222-8222-222222222222';
        final userB = sameUser ? _user : {..._user, 'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'};
        final updateStarted = Completer<void>();
        final finishUpdate = Completer<void>();
        final requests = <Request>[];
        final updatedUserIds = <String?>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'publishable-test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            requests.add(request);
            Object body = _session(1);
            if (request.method == 'PUT' && request.url.path.endsWith('/user')) {
              updateStarted.complete();
              await finishUpdate.future;
              body = _user;
            } else if (request.url.path.endsWith('/token')) {
              body = _session(2, sessionId: sessionB, user: userB);
            } else if (request.url.path.endsWith('/logout')) {
              body = <String, Object?>{};
            }
            return Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: _Persistence());
        addTearDown(gateway.dispose);
        final subscription = client.auth.onAuthStateChange.listen((state) {
          if (state.event == AuthChangeEvent.userUpdated) {
            updatedUserIds.add(state.session?.user.id);
          }
        });
        addTearDown(subscription.cancel);
        await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
        await Future<void>.delayed(Duration.zero);
        final recoveryToken = client.auth.currentSession!.accessToken;

        final update = gateway.updatePassword(password: 'synthetic-new-password');
        await updateStarted.future;
        await client.auth.signInWithPassword(
          email: 'synthetic-b@example.invalid',
          password: 'synthetic',
        );
        await Future<void>.delayed(Duration.zero);
        expect(gateway.currentSessionState.sessionId, sessionB);
        expect(client.auth.currentUser?.id, userB['id']);
        finishUpdate.complete();
        final reset = await update;
        await Future<void>.delayed(Duration.zero);
        final updateRequest = requests.singleWhere((r) => r.method == 'PUT');
        expect(updateRequest.url.path, '/auth/v1/user');
        expect(updateRequest.headers['authorization'], 'Bearer $recoveryToken');
        expect(updateRequest.headers['apikey'], 'publishable-test');

        expect(
          {
            'resetSuccess': reset.isSuccess,
            'sessionId': gateway.currentSessionState.sessionId,
            'userId': client.auth.currentUser?.id,
            'logoutCount': requests.where((r) => r.url.path.endsWith('/logout')).length,
            'updatedUserIds': updatedUserIds,
          },
          {
            'resetSuccess': false,
            'sessionId': sessionB,
            'userId': userB['id'],
            'logoutCount': 0,
            'updatedUserIds': <String?>[],
          },
        );
      },
    );
  }

  test('recovery update allows token refresh in the same session', () async {
    final updateStarted = Completer<void>();
    final finishUpdate = Completer<void>();
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co/prefix',
      'publishable-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        Object body = _session(1);
        if (request.method == 'PUT') {
          updateStarted.complete();
          await finishUpdate.future;
          body = _user;
        } else if (request.url.path.endsWith('/token')) {
          body = _session(2);
        } else if (request.url.path.endsWith('/logout')) {
          body = <String, Object?>{};
        }
        return Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: _Persistence());
    addTearDown(gateway.dispose);
    await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
    await Future<void>.delayed(Duration.zero);
    final oldToken = client.auth.currentSession!.accessToken;
    final update = gateway.updatePassword(password: 'synthetic-new-password');
    await updateStarted.future;
    await client.auth.refreshSession();
    await Future<void>.delayed(Duration.zero);
    final refreshedToken = client.auth.currentSession!.accessToken;
    expect(refreshedToken, isNot(oldToken));
    expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
    finishUpdate.complete();
    expect((await update).isSuccess, isTrue);
    expect(client.auth.currentSession, isNull);
    final updateRequest = requests.singleWhere((r) => r.method == 'PUT');
    expect(updateRequest.url.path, '/prefix/auth/v1/user');
    expect(updateRequest.headers['authorization'], 'Bearer $oldToken');
    expect(
      requests.singleWhere((r) => r.url.path.endsWith('/logout')).headers['authorization'],
      'Bearer $refreshedToken',
    );
  });

  for (final scenario in ['denied', 'transport', 'invalid-json', 'list', 'wrong-user']) {
    test('recovery response failure is sanitized without session mutation: $scenario', () async {
      final requests = <Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'PUT') {
            if (scenario == 'transport') throw ClientException('synthetic-private-detail');
            final body = switch (scenario) {
              'invalid-json' => 'synthetic-private-detail',
              'list' => '[]',
              'wrong-user' => jsonEncode({..._user, 'id': 'wrong-user'}),
              _ => jsonEncode({'message': 'synthetic-private-detail'}),
            };
            return Response(
              body,
              scenario == 'denied' ? 403 : 200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          return Response(
            jsonEncode(_session(1)),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: _Persistence());
      addTearDown(gateway.dispose);
      final updated = <AuthState>[];
      final subscription = client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.userUpdated) updated.add(state);
      });
      addTearDown(subscription.cancel);
      await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
      await Future<void>.delayed(Duration.zero);
      final session = client.auth.currentSession;
      final result = await gateway.updatePassword(password: 'synthetic-new-password');
      await Future<void>.delayed(Duration.zero);
      expect(result.isSuccess, isFalse);
      expect(result.message, CoeloAuthPasswordUpdateResult.genericFailureMessage);
      expect(client.auth.currentSession, same(session));
      expect(updated, isEmpty);
      expect(requests.where((r) => r.url.path.endsWith('/logout')), isEmpty);
    });
  }

  test('pending recovery password update excludes a new gateway login', () async {
    final updateStarted = Completer<void>();
    final finishUpdate = Completer<void>();
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        Object body = _session(1);
        if (request.method == 'PUT' && request.url.path.endsWith('/user')) {
          updateStarted.complete();
          await finishUpdate.future;
          body = _user;
        } else if (request.url.path.endsWith('/logout')) {
          body = <String, Object?>{};
        }
        return Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: _Persistence());
    addTearDown(gateway.dispose);
    await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
    await Future<void>.delayed(Duration.zero);

    final update = gateway.updatePassword(password: 'synthetic-new-password');
    await updateStarted.future;
    final login = await gateway.signInWithPassword(
      email: 'synthetic@example.invalid',
      password: 'synthetic',
      persistSession: false,
    );
    finishUpdate.complete();
    final reset = await update;

    expect(login.isSuccess, isFalse);
    expect(requests.where((r) => r.url.path.endsWith('/token')), isEmpty);
    expect(reset.isSuccess, isTrue);
    expect(client.auth.currentSession, isNull);
    final retry = await gateway.signInWithPassword(
      email: 'synthetic@example.invalid',
      password: 'synthetic',
      persistSession: false,
    );
    expect(retry.isSuccess, isTrue);
  });

  test('initial recovery token for A cannot classify pending SDK session B', () async {
    const sessionB = '22222222-2222-4222-8222-222222222222';
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode(_session(1, sessionId: sessionB)),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
    final gateway = SupabaseCoeloAuthGateway(
      client,
      sessionPersistence: _Persistence(),
      initialRecoveryAccessToken: _session(1)['access_token']! as String,
    );
    addTearDown(gateway.dispose);
    expect(gateway.currentSessionState.kind, isNot(CoeloAuthSessionKind.authenticated));
    final state = await gateway.authSessionStateChanges.first;
    expect(state.isPasswordRecovery, isTrue);
    expect(state.sessionId, sessionB);
  });

  test('failed scope initialization releases the gateway without closing the shared SDK', () async {
    final previousErrorHandler = FlutterError.onError;
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(client.dispose);
    late SupabaseCoeloAuthGateway gateway;
    var closed = false;
    final scope = await createSuperadminAuthScope(
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: 'publishable-test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async =>
          client,
      createAuthGateway:
          ({required client, required sessionPersistence, required initialRecoveryAccessToken}) {
            gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: sessionPersistence);
            final subscription = gateway.authSessionStateChanges.listen(
              (_) {},
              onDone: () => closed = true,
            );
            addTearDown(subscription.cancel);
            return gateway;
          },
      createAuthContextGateway: (_) => throw Exception('synthetic initialization failure'),
    );
    addTearDown(scope.session.dispose);
    addTearDown(gateway.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(errors, hasLength(1));
    expect(scope.session.isAuthenticated, isFalse);
    expect(closed, isTrue);
  });

  for (final recovery in [false, true]) {
    test(
      'scope synchronizes preexisting SDK session before bootstrap: recovery=$recovery',
      () async {
        final client = SupabaseClient(
          'https://example.supabase.co',
          'publishable-test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient(
            (request) async => Response(
              jsonEncode(_session(1)),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            ),
          ),
        );
        addTearDown(client.dispose);
        if (recovery) {
          await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
        } else {
          await client.auth.signInWithPassword(
            email: 'synthetic@example.invalid',
            password: 'synthetic',
          );
        }
        final context = _Context();
        final scope = await createSuperadminAuthScope(
          supabaseUrl: 'https://example.supabase.co',
          supabasePublishableKey: 'publishable-test',
          initializeSupabase:
              ({required localStorage, required publishableKey, required url}) async => client,
          createAuthContextGateway: (_) => context,
        );
        addTearDown(scope.session.dispose);
        expect(context.calls, recovery ? 0 : 1);
        expect(scope.session.isPasswordRecovery, recovery);
        expect(scope.session.isAuthenticated, !recovery);
      },
    );
  }

  test('adapter created after recovery never exposes it as productive authentication', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient(
        (request) async => Response(
          jsonEncode(_session(1)),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);
    await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
    final gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: _Persistence());
    addTearDown(gateway.dispose);
    expect(gateway.currentSessionState.kind, isNot(CoeloAuthSessionKind.authenticated));
    await Future<void>.delayed(Duration.zero);
    expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
  });

  test('replacement SDK session clears recovery and cannot update a password', () async {
    var nextSessionId = _sessionId;
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          jsonEncode(_session(1, sessionId: nextSessionId)),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    final gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: _Persistence());
    addTearDown(gateway.dispose);
    await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
    await Future<void>.delayed(Duration.zero);
    expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
    nextSessionId = '22222222-2222-4222-8222-222222222222';
    await client.auth.signInWithPassword(email: 'synthetic@example.invalid', password: 'synthetic');
    await Future<void>.delayed(Duration.zero);
    expect(gateway.currentSessionState.kind, CoeloAuthSessionKind.authenticated);
    expect(gateway.currentSessionState.sessionId, nextSessionId);
    final reset = await gateway.updatePassword(password: 'must-not-be-sent');
    expect(reset.isSuccess, isFalse);
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    expect(requests.where((r) => r.url.path.endsWith('/logout')), isEmpty);
  });

  for (final subscribe in [false, true]) {
    test('SDK recovery remains distinct through refresh; external listener=$subscribe', () async {
      final requests = <Request>[];
      var tokenVersion = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final Object body;
          if (request.url.path.endsWith('/logout')) {
            body = <String, Object?>{};
          } else if (request.url.path.endsWith('/user')) {
            body = _user;
          } else {
            body = _session(++tokenVersion);
          }
          return Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: _Persistence());
      addTearDown(gateway.dispose);
      final states = <CoeloAuthSessionState>[];
      if (subscribe) {
        final subscription = gateway.authSessionStateChanges.listen(states.add);
        addTearDown(subscription.cancel);
      }
      expect(gateway.currentSessionState.kind, CoeloAuthSessionKind.signedOut);
      await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
      await Future<void>.delayed(Duration.zero);
      expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
      expect(gateway.currentSessionState.sessionId, _sessionId);

      await client.auth.refreshSession();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
      expect(gateway.isAuthenticated, isFalse);
      if (subscribe) {
        expect(states.where((s) => s.kind == CoeloAuthSessionKind.authenticated), isEmpty);
        expect(states.last.isPasswordRecovery, isTrue);
      }

      final result = await gateway.updatePassword(password: 'synthetic-password-for-test');
      expect(result.isSuccess, isTrue);
      expect(
        requests.where((r) => r.method == 'PUT' && r.url.path.endsWith('/user')),
        hasLength(1),
      );
      expect(requests.where((r) => r.url.path.endsWith('/logout')), hasLength(1));
      expect(client.auth.currentSession, isNull);
      expect(gateway.currentSessionState.kind, CoeloAuthSessionKind.signedOut);

      await client.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic',
      );
      await Future<void>.delayed(Duration.zero);
      expect(gateway.currentSessionState.kind, CoeloAuthSessionKind.authenticated);
      expect(gateway.currentSessionState.isPasswordRecovery, isFalse);
    });
  }

  test('scope disposal closes only gateway events and leaves the shared SDK usable', () async {
    final requests = <Request>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        return Response(
          jsonEncode(_session(1)),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    late SupabaseCoeloAuthGateway gateway;
    final scope = await createSuperadminAuthScope(
      supabaseUrl: 'https://example.supabase.co',
      supabasePublishableKey: 'publishable-test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async =>
          client,
      createAuthGateway:
          ({required client, required sessionPersistence, required initialRecoveryAccessToken}) {
            gateway = SupabaseCoeloAuthGateway(client, sessionPersistence: sessionPersistence);
            return gateway;
          },
    );
    addTearDown(scope.session.dispose);
    addTearDown(gateway.dispose);
    final closed = Completer<void>();
    final events = <CoeloAuthSessionState>[];
    final subscription = gateway.authSessionStateChanges.listen(
      events.add,
      onDone: closed.complete,
    );
    addTearDown(subscription.cancel);
    await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'synthetic-recovery-hash');
    await Future<void>.delayed(Duration.zero);
    expect(scope.session.isPasswordRecovery, isTrue);
    expect(scope.session.isAuthenticated, isFalse);
    final currentSdkSession = client.auth.currentSession;
    final countBeforeDispose = events.length;
    scope.session.dispose();
    await closed.future.timeout(const Duration(seconds: 2));
    await gateway.dispose();
    expect(client.auth.currentSession, same(currentSdkSession));
    expect(requests.where((r) => r.url.path.endsWith('/logout')), isEmpty);
    await client.auth.verifyOTP(type: OtpType.recovery, tokenHash: 'another-synthetic-hash');
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(countBeforeDispose));
    expect(gateway.currentSessionState.kind, CoeloAuthSessionKind.signedOut);
    expect(client.auth.currentSession, isNotNull);
  });
}

const _sessionId = '11111111-1111-4111-8111-111111111111';
const _user = {
  'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'synthetic@example.invalid',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
  'created_at': '2026-09-01T00:00:00Z',
};

Map<String, Object?> _session(
  int version, {
  String sessionId = _sessionId,
  Map<String, Object?> user = _user,
}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token =
      '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': user['id'], 'session_id': sessionId, 'role': 'authenticated', 'aal': 'aal1', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'test_version': version})}.synthetic-signature';
  return {
    'access_token': token,
    'refresh_token': 'synthetic-refresh-$version',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': user,
  };
}

final class _Persistence implements CoeloAuthSessionPersistence {
  @override
  Future<void> setPersistenceEnabled({required bool value}) async {}
}

final class _Context implements SuperadminAuthContextGateway {
  int calls = 0;
  @override
  Future<SuperadminAuthContext?> bootstrap() async {
    calls++;
    return const SuperadminAuthContext(
      platformRoleCode: 'operations',
      scopeKind: SuperadminAuthScopeKind.platform,
      permissionCodes: {'platform.read'},
      aal: 'aal1',
    );
  }
}

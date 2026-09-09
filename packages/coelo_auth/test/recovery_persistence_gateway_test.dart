import 'dart:convert';
import 'dart:io';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'recovery persistence: gateway created after SDK callback purges on replay',
    () async {
      final fixture = await _SdkFixture.create();
      addTearDown(fixture.close);
      await fixture.recover();
      final persistence = _RecordingPersistence();
      final gateway = fixture.gateway(persistence);

      expect(gateway.currentSessionState.isAuthenticated, isFalse);
      await _settleEvents();

      expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
      expect(persistence.calls, contains(false));
      expect(persistence.enabled, isFalse);
      expect(persistence.persistedSession, isNull);
    },
  );

  test(
    'recovery persistence: matching seed purges when latest SDK replay is refresh',
    () async {
      final fixture = await _SdkFixture.create();
      addTearDown(fixture.close);
      await fixture.recover();
      final initialToken = fixture.client.auth.currentSession!.accessToken;
      fixture.version++;
      await fixture.client.auth.refreshSession();
      expect(
        fixture.client.auth.currentSession!.accessToken,
        isNot(initialToken),
      );
      final persistence = _RecordingPersistence();
      final gateway = fixture.gateway(persistence, initialToken: initialToken);

      expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
      await _settleEvents();

      expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
      expect(persistence.calls, contains(false));
      expect(persistence.persistedSession, isNull);
    },
  );

  test('recovery persistence: seed A preserves normal SDK session B', () async {
    final fixture = await _SdkFixture.create();
    addTearDown(fixture.close);
    fixture.sessionId = _sessionB;
    await fixture.client.auth.signInWithPassword(
      email: 'synthetic@example.invalid',
      password: 'synthetic-password',
    );
    final persistence = _RecordingPersistence();
    final gateway = fixture.gateway(
      persistence,
      initialToken: _token(_sessionA, 1),
    );
    await _settleEvents();

    expect(gateway.currentSessionState.isAuthenticated, isTrue);
    expect(gateway.currentSessionState.sessionId, _sessionB);
    expect(persistence.calls, isEmpty);
    expect(persistence.enabled, isTrue);
    expect(persistence.persistedSession, 'synthetic-existing-session');
  });

  for (final synchronousFailure in [false, true]) {
    test(
      'recovery persistence: cleanup failure remains confined; sync=$synchronousFailure',
      () async {
        final fixture = await _SdkFixture.create();
        addTearDown(fixture.close);
        final persistence = _RecordingPersistence(
          failSynchronously: synchronousFailure,
        );
        final reported = <Object>[];
        final originalErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) => reported.add(details.exception);
        addTearDown(() => FlutterError.onError = originalErrorHandler);
        final gateway = fixture.gateway(persistence);
        final states = <CoeloAuthSessionState>[];
        final subscription = gateway.authSessionStateChanges.listen(
          states.add,
          onError: (Object error) => reported.add(error),
        );
        addTearDown(subscription.cancel);

        await fixture.recover();
        await _settleEvents();

        expect(persistence.calls, contains(false));
        expect(gateway.currentSessionState.isPasswordRecovery, isTrue);
        expect(
          states.where(
            (state) => state.kind == CoeloAuthSessionKind.authenticated,
          ),
          isEmpty,
        );
        expect(
          reported,
          isNotEmpty,
          reason: 'A failed purge cannot be silently certified.',
        );
        expect(reported.join(' '), isNot(contains(_privateFailure)));
        expect(
          fixture.paths.where((path) => path.endsWith('/logout')),
          isEmpty,
        );
        // The failure deliberately leaves disk state: this proves confinement
        // and error handling only, never successful cleanup after cold reload.
        expect(persistence.persistedSession, 'synthetic-existing-session');
      },
    );
  }
}

Future<void> _settleEvents() => Future<void>.delayed(Duration.zero);

const _sessionA = '11111111-1111-4111-8111-111111111111';
const _sessionB = '22222222-2222-4222-8222-222222222222';
const _privateFailure = 'synthetic-storage-private-detail';
const _user = <String, Object?>{
  'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'synthetic@example.invalid',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
  'created_at': '2026-09-09T00:00:00Z',
};

String _token(String sessionId, int version) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'sub': _user['id'], 'session_id': sessionId, 'role': 'authenticated', 'aal': 'aal1', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'version': version})}.'
      'synthetic-signature';
}

final class _RecordingPersistence implements CoeloAuthSessionPersistence {
  _RecordingPersistence({this.failSynchronously});

  final bool? failSynchronously;
  final calls = <bool>[];
  bool enabled = true;
  String? persistedSession = 'synthetic-existing-session';

  @override
  Future<void> setPersistenceEnabled({required bool value}) {
    calls.add(value);
    enabled = value;
    if (failSynchronously == true) throw StateError(_privateFailure);
    if (failSynchronously == false) {
      return Future<void>.error(StateError(_privateFailure));
    }
    if (!value) persistedSession = null;
    return Future<void>.value();
  }
}

// SDK lifecycle is real. A loopback-only HTTP fixture supplies synthetic GoTrue
// responses; no external service, production authorization or browser is tested.
final class _SdkFixture {
  _SdkFixture(this.server);

  final HttpServer server;
  late final SupabaseClient client;
  final paths = <String>[];
  final gateways = <SupabaseCoeloAuthGateway>[];
  String sessionId = _sessionA;
  int version = 1;

  static Future<_SdkFixture> create() async {
    final fixture = _SdkFixture(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    fixture.server.listen((request) async {
      fixture.paths.add(request.uri.path);
      await request.drain<void>();
      final allowed =
          request.method == 'POST' &&
          (request.uri.path == '/auth/v1/verify' ||
              request.uri.path == '/auth/v1/token');
      request.response.statusCode = allowed
          ? HttpStatus.ok
          : HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(
          allowed
              ? {
                  'access_token': _token(fixture.sessionId, fixture.version),
                  'refresh_token': 'synthetic-refresh-${fixture.version}',
                  'expires_in': 3600,
                  'token_type': 'bearer',
                  'user': _user,
                }
              : {'message': 'Unexpected fixture request'},
        ),
      );
      await request.response.close();
    });
    fixture.client = SupabaseClient(
      'http://127.0.0.1:${fixture.server.port}',
      'synthetic-publishable',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    return fixture;
  }

  Future<void> recover() async {
    await client.auth.verifyOTP(
      type: OtpType.recovery,
      tokenHash: 'synthetic-recovery-hash',
    );
    await _settleEvents();
  }

  SupabaseCoeloAuthGateway gateway(
    _RecordingPersistence persistence, {
    String? initialToken,
  }) {
    final gateway = SupabaseCoeloAuthGateway(
      client,
      sessionPersistence: persistence,
      initialRecoveryAccessToken: initialToken,
    );
    gateways.add(gateway);
    return gateway;
  }

  Future<void> close() async {
    for (final gateway in gateways) {
      await gateway.dispose();
    }
    await client.dispose();
    await server.close(force: true);
  }
}

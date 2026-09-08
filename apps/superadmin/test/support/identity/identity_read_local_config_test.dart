import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'identity_read_local_config.dart';

void main() {
  for (final scenario in [
    'users-scoped',
    'users-membership-revoked',
    'models-domain-denied',
    'models-membership-revoked',
  ]) {
    test('accepts only nominal actor for $scenario', () {
      final profile = scenario.startsWith('users') ? 'Users49' : 'Models50';
      final environment = _environment(profile)..['COELO_IDENTITY_LOCAL_SCENARIO'] = scenario;
      if (profile == 'Users49') {
        environment['COELO_IDENTITY_READER_JWT'] = _token(
          _reader(profile)
            ..['sub'] = '91000000-0000-4000-8000-000000000003'
            ..['session_id'] = '92000000-0000-4000-8000-000000000003',
        );
        environment['COELO_IDENTITY_INVALID_SESSION_JWT'] = _token(
          _reader(profile)
            ..['sub'] = '91000000-0000-4000-8000-000000000003'
            ..['session_id'] = '92000000-0000-4000-8000-000000000099',
        );
      }
      environment['COELO_IDENTITY_INITIAL_READER_JWT'] = environment['COELO_IDENTITY_READER_JWT']!;
      final config = IdentityReadLocalConfig(environment, nowSeconds: 1000);
      expect(config.scenario, scenario);
      expect(config.isMembershipRevoked, scenario.endsWith('membership-revoked'));
    });
  }
  test('rejects crossed and unknown scenarios', () {
    for (final scenario in ['models-domain-denied', 'anything']) {
      expect(
        () => IdentityReadLocalConfig(
          _environment('Users49')..['COELO_IDENTITY_LOCAL_SCENARIO'] = scenario,
          nowSeconds: 1000,
        ),
        throwsFormatException,
      );
    }
  });
  test('negative phase requires the identical initial token supplied by operator', () {
    final environment = _environment('Models50')
      ..['COELO_IDENTITY_LOCAL_SCENARIO'] = 'models-membership-revoked';
    expect(() => IdentityReadLocalConfig(environment, nowSeconds: 1000), throwsFormatException);
    environment['COELO_IDENTITY_INITIAL_READER_JWT'] = 'different';
    expect(() => IdentityReadLocalConfig(environment, nowSeconds: 1000), throwsFormatException);
  });
  for (final expiry in [999, 1000, 4601]) {
    test('rejects expired or overlong local token: $expiry', () {
      final environment = _environment('Users49');
      environment['COELO_IDENTITY_READER_JWT'] = _token(_reader('Users49')..['exp'] = expiry);
      expect(() => IdentityReadLocalConfig(environment, nowSeconds: 1000), throwsFormatException);
    });
  }
  test('negative token must retain the nominal actor and absent-session ID', () {
    for (final claim in ['sub', 'session_id', 'role', 'aal']) {
      final environment = _environment('Models50');
      environment['COELO_IDENTITY_INVALID_SESSION_JWT'] = _token(
        _reader('Models50')
          ..['session_id'] = 'f2000000-0000-4000-8000-000000000099'
          ..[claim] = 'wrong',
      );
      expect(() => IdentityReadLocalConfig(environment, nowSeconds: 1000), throwsFormatException);
    }
  });
  test('reader token cannot double as negative-session token', () {
    final environment = _environment('Users49');
    environment['COELO_IDENTITY_INVALID_SESSION_JWT'] = environment['COELO_IDENTITY_READER_JWT']!;
    expect(() => IdentityReadLocalConfig(environment, nowSeconds: 1000), throwsFormatException);
  });
  for (final profile in ['Users49', 'Models50']) {
    test('$profile accepts its nominal loopback seed', () {
      final config = IdentityReadLocalConfig(_environment(profile), nowSeconds: 1000);
      expect(config.profile, profile);
      expect(config.origin.toString(), 'http://127.0.0.1:54381');
      config.validateRequest(
        'POST',
        config.origin.resolve('/rest/v1/rpc/superadmin_auth_bootstrap_context'),
      );
    });
    test('$profile rejects the other vertical RPC', () {
      final config = IdentityReadLocalConfig(_environment(profile), nowSeconds: 1000);
      final other = profile == 'Users49'
          ? 'superadmin_access_profile_models_cursor'
          : 'superadmin_internal_users_list';
      expect(
        () => config.validateRequest('POST', config.origin.resolve('/rest/v1/rpc/$other')),
        throwsFormatException,
      );
    });
    for (final field in ['sub', 'session_id', 'role', 'aal', 'exp']) {
      test('$profile rejects reader claim drift: $field', () {
        final env = _environment(profile);
        final claims = _reader(profile)..[field] = 'invalid';
        env['COELO_IDENTITY_READER_JWT'] = _token(claims);
        expect(() => IdentityReadLocalConfig(env, nowSeconds: 1000), throwsFormatException);
      });
    }
  }
  for (final origin in [
    'https://example.supabase.co',
    'http://localhost:54381',
    'http://127.0.0.1',
    'http://127.0.0.1:80',
    'http://x@127.0.0.1:54381',
    'http://127.0.0.1:54381/path',
    'http://127.0.0.1:54381?x=1',
    'http://127.0.0.1:54381#x',
  ]) {
    test('rejects nonnominal origin $origin', () {
      expect(
        () => IdentityReadLocalConfig(
          _environment('Users49')..['COELO_IDENTITY_LOCAL_URL'] = origin,
          nowSeconds: 1000,
        ),
        throwsFormatException,
      );
    });
  }
  test('requires opt-in and exact base', () {
    for (final mutation in [
      {'COELO_IDENTITY_LOCAL_RUNTIME': '0'},
      {'COELO_IDENTITY_LOCAL_PROFILE': 'Foundation67'},
      {
        'COELO_IDENTITY_LOCAL_ANON_KEY': _token({'role': 'service_role'}),
      },
    ]) {
      expect(
        () => IdentityReadLocalConfig(_environment('Users49')..addAll(mutation), nowSeconds: 1000),
        throwsFormatException,
      );
    }
  });
  test('rejects writes, table reads, redirects and nonnominal query', () {
    final config = IdentityReadLocalConfig(_environment('Users49'), nowSeconds: 1000);
    for (final path in [
      '/rest/v1/platform_roles',
      '/rest/v1/rpc/superadmin_internal_user_update',
      '/rest/v1/rpc/superadmin_internal_users_list?q=1',
    ]) {
      expect(
        () => config.validateRequest('POST', config.origin.resolve(path)),
        throwsFormatException,
      );
    }
    expect(
      () => config.validateRequest(
        'GET',
        config.origin.resolve('/rest/v1/rpc/superadmin_internal_users_list'),
      ),
      throwsFormatException,
    );
    expect(
      () => config.validateRequest(
        'POST',
        Uri.parse('http://127.0.0.1:54382/rest/v1/rpc/superadmin_internal_users_list'),
      ),
      throwsFormatException,
    );
  });
  test('credential errors do not echo input', () {
    const sentinel = 'DO_NOT_ECHO_CREDENTIAL';
    try {
      IdentityReadLocalConfig(
        _environment('Users49')..['COELO_IDENTITY_READER_JWT'] = sentinel,
        nowSeconds: 1000,
      );
      fail('Expected validation error');
    } on FormatException catch (error) {
      expect(error.toString(), isNot(contains(sentinel)));
    }
  });
}

Map<String, String> _environment(String profile) => {
  'COELO_IDENTITY_LOCAL_RUNTIME': '1',
  'COELO_IDENTITY_LOCAL_PROFILE': profile,
  'COELO_IDENTITY_LOCAL_URL': 'http://127.0.0.1:54381',
  'COELO_IDENTITY_LOCAL_ANON_KEY': _token({'role': 'anon'}),
  'COELO_IDENTITY_READER_JWT': _token(_reader(profile)),
  'COELO_IDENTITY_INVALID_SESSION_JWT': _token(
    _reader(profile)
      ..['session_id'] = '${profile == 'Users49' ? 'e2' : 'f2'}000000-0000-4000-8000-000000000099',
  ),
};
Map<String, Object> _reader(String profile) => {
  'sub': '${profile == 'Users49' ? 'e1' : 'f1'}000000-0000-4000-8000-000000000001',
  'session_id': '${profile == 'Users49' ? 'e2' : 'f2'}000000-0000-4000-8000-000000000001',
  'role': 'authenticated',
  'aal': 'aal1',
  'exp': 1500,
};
String _token(Map<String, Object> claims) =>
    'test.${base64Url.encode(utf8.encode(jsonEncode(claims)))}.unsigned';

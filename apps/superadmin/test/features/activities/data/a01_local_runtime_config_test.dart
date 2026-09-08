import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../support/activities/a01_local_runtime_config.dart';

void main() {
  final origin = Uri.parse('http://127.0.0.1:54321');
  for (final rpc in [
    'superadmin_auth_bootstrap_context',
    'superadmin_activity_directory_v2',
    'superadmin_activity_filter_options_v2',
  ]) {
    test('allows only nominal POST read $rpc', () {
      expect(
        () => A01LocalRuntimeConfig.validateReadRequest(
          origin,
          origin.resolve('/rest/v1/rpc/$rpc'),
          'POST',
        ),
        returnsNormally,
      );
    });
  }
  for (final request in [
    (url: 'http://127.0.0.1:54321/rest/v1/rpc/superadmin_activity_directory_v2', method: 'GET'),
    (url: 'http://127.0.0.1:54321/rest/v1/activity_definitions', method: 'POST'),
    (url: 'http://127.0.0.1:54321/rest/v1/rpc/superadmin_activity_save_v2', method: 'POST'),
    (url: 'http://127.0.0.1:54322/rest/v1/rpc/superadmin_activity_directory_v2', method: 'POST'),
    (
      url: 'https://example.supabase.co/rest/v1/rpc/superadmin_activity_directory_v2',
      method: 'POST',
    ),
    (
      url: 'http://127.0.0.1:54321/rest/v1/rpc/superadmin_activity_directory_v2?select=*',
      method: 'POST',
    ),
    (
      url: 'http://127.0.0.1:54321/rest/v1/rpc/superadmin_activity_directory_v2/extra',
      method: 'POST',
    ),
  ]) {
    test('rejects non-nominal request $request', () {
      expect(
        () => A01LocalRuntimeConfig.validateReadRequest(
          origin,
          Uri.parse(request.url),
          request.method,
        ),
        throwsFormatException,
      );
    });
  }
  test('requires explicit local runtime opt-in', () {
    expect(() => A01LocalRuntimeConfig.fromEnvironment({}), throwsFormatException);
  });
  for (final value in [
    '',
    'https://example.supabase.co',
    'http://localhost:54321',
    'http://127.0.0.1',
    'http://127.0.0.1:80',
    'https://127.0.0.1:54321',
    'http://127.0.0.1:54321/rest/v1',
    'http://user:pass@127.0.0.1:54321',
    'http://127.0.0.1:54321?remote=x',
    'http://127.0.0.1:54321#fragment',
  ]) {
    test('rejects unsafe origin $value', () {
      expect(() => A01LocalRuntimeConfig.validateOrigin(value), throwsFormatException);
    });
  }
  test('accepts exact loopback with explicit unprivileged port', () {
    expect(
      A01LocalRuntimeConfig.validateOrigin('http://127.0.0.1:54321/').toString(),
      'http://127.0.0.1:54321',
    );
  });
  test('validates synthetic actor and session without authenticating locally', () {
    final claims = <String, Object?>{
      'sub': A01LocalRuntimeConfig.id(102),
      'session_id': A01LocalRuntimeConfig.id(202),
      'role': 'authenticated',
      'aal': 'aal2',
      'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300,
    };
    String token(Map<String, Object?> value) =>
        'test.${base64Url.encode(utf8.encode(jsonEncode(value)))}.test';
    expect(() => A01LocalRuntimeConfig.validateActorToken(token(claims), 102), returnsNormally);
    for (final mutation in [
      {'sub': A01LocalRuntimeConfig.id(101)},
      {'session_id': A01LocalRuntimeConfig.id(201)},
      {'role': 'service_role'},
      {'aal': 'aal1'},
      {'exp': 1},
    ]) {
      expect(
        () => A01LocalRuntimeConfig.validateActorToken(token({...claims, ...mutation}), 102),
        throwsFormatException,
      );
    }
  });
}
